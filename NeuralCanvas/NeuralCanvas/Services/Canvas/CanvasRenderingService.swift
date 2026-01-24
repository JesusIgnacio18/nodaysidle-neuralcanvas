import Foundation
import Metal
import MetalKit
import CoreGraphics

// MARK: - Canvas Rendering Protocol

/// Protocol for canvas rendering services
protocol CanvasRendering: Sendable {
    func render(
        strokes: [VectorStroke],
        shapes: [RecognizedShape],
        viewport: CGRect,
        scale: CGFloat
    ) async throws -> MTLTexture
}

// MARK: - Canvas Rendering Service

/// Service for rendering canvas content using Metal
final class CanvasRenderingService: @unchecked Sendable {
    // MARK: - Properties

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let renderer: MetalRenderer

    private var textureCache: [String: MTLTexture] = [:]
    private let maxCacheSize = 10

    // MARK: - Initialization

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw RenderingError.deviceNotAvailable
        }
        self.device = device

        guard let commandQueue = device.makeCommandQueue() else {
            throw RenderingError.deviceNotAvailable
        }
        self.commandQueue = commandQueue

        self.renderer = try MetalRenderer(device: device)

        AppLogger.canvasRendering.info("CanvasRenderingService initialized")
    }

    // MARK: - Texture Management

    func createTexture(width: Int, height: Int) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .private

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw RenderingError.textureAllocationFailed(width: width, height: height)
        }

        return texture
    }

    func getOrCreateTexture(key: String, width: Int, height: Int) throws -> MTLTexture {
        if let cached = textureCache[key] {
            if cached.width == width && cached.height == height {
                return cached
            }
        }

        // Evict old textures if cache is full
        if textureCache.count >= maxCacheSize {
            textureCache.removeValue(forKey: textureCache.keys.first!)
        }

        let texture = try createTexture(width: width, height: height)
        textureCache[key] = texture

        return texture
    }

    func clearCache() {
        textureCache.removeAll()
    }

    // MARK: - Rendering

    /// Renders strokes and shapes to a texture
    func renderToTexture(
        strokes: [VectorStroke],
        shapes: [RecognizedShape],
        width: Int,
        height: Int,
        scale: CGFloat,
        offset: CGPoint,
        showGrid: Bool,
        gridSize: Float,
        backgroundColor: CodableColor
    ) throws -> MTLTexture {
        let texture = try createTexture(width: width, height: height)

        // Create render pass descriptor
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: Double(backgroundColor.red),
            green: Double(backgroundColor.green),
            blue: Double(backgroundColor.blue),
            alpha: Double(backgroundColor.alpha)
        )

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            throw RenderingError.commandBufferFailed(underlying: NSError(domain: "Metal", code: -1))
        }

        // Update renderer viewport
        renderer.updateViewport(
            size: CGSize(width: width, height: height),
            scale: Float(scale),
            offset: SIMD2<Float>(Float(offset.x), Float(offset.y))
        )

        renderEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return texture
    }

    /// Creates a CGImage from a Metal texture
    func textureToImage(_ texture: MTLTexture) -> CGImage? {
        let width = texture.width
        let height = texture.height
        let bytesPerRow = width * 4

        var data = [UInt8](repeating: 0, count: bytesPerRow * height)

        let region = MTLRegionMake2D(0, 0, width, height)
        texture.getBytes(&data, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        return context.makeImage()
    }
}

// MARK: - Canvas State

/// Observable state for canvas view
@Observable
final class CanvasState {
    // MARK: - Drawing State

    var strokes: [VectorStroke] = []
    var currentStroke: VectorStroke?
    var recognizedShapes: [RecognizedShape] = []

    // MARK: - Viewport State

    var scale: CGFloat = 1.0
    var offset: CGPoint = .zero
    var rotation: CGFloat = 0

    // MARK: - Display Options

    var showGrid: Bool = true
    var gridSize: CGFloat = 8
    var backgroundColor: CodableColor = .white

    // MARK: - Current Stroke Settings

    var currentStrokeColor: CodableColor = .black  // Black is visible on white canvas
    var currentStrokeWidth: CGFloat = 4.0

    // MARK: - Processing State

    var isProcessing: Bool = false
    var processingProgress: Double = 0

    // MARK: - Selection

    var selectedShapeIds: Set<UUID> = []
    var selectedStrokeIds: Set<UUID> = []

    // MARK: - Methods

    func addStroke(_ stroke: VectorStroke) {
        strokes.append(stroke)
    }

    func startStroke(at point: CGPoint, pressure: CGFloat = 1.0) {
        let strokePoint = StrokePoint(location: point, pressure: pressure, timestamp: CACurrentMediaTime())
        currentStroke = VectorStroke(
            points: [strokePoint],
            width: currentStrokeWidth,
            color: currentStrokeColor
        )
    }

    func continueStroke(to point: CGPoint, pressure: CGFloat = 1.0) {
        guard var stroke = currentStroke else { return }
        let strokePoint = StrokePoint(location: point, pressure: pressure, timestamp: CACurrentMediaTime())
        currentStroke = VectorStroke(
            id: stroke.id,
            points: stroke.points + [strokePoint],
            width: stroke.width,
            color: stroke.color,
            createdAt: stroke.createdAt
        )
    }

    func endStroke() {
        guard let stroke = currentStroke, stroke.isValid else {
            currentStroke = nil
            return
        }
        // Analyze and potentially smooth/recognize the stroke
        let smoothedStroke = recognizeAndSmooth(stroke)
        strokes.append(smoothedStroke)
        currentStroke = nil
    }

    // MARK: - Stroke Recognition & Smoothing

    /// Analyzes a stroke and returns a cleaned-up version if it matches a shape
    private func recognizeAndSmooth(_ stroke: VectorStroke) -> VectorStroke {
        guard stroke.points.count >= 3 else { return stroke }

        let bounds = stroke.bounds
        let startPoint = stroke.points.first!.location.cgPoint
        let endPoint = stroke.points.last!.location.cgPoint

        // Check if it's a line (start and end far apart, points roughly linear)
        if isApproximatelyLine(stroke) {
            return createStraightLine(from: startPoint, to: endPoint, stroke: stroke)
        }

        // Check if closed (start and end close together)
        let closingDistance = hypot(endPoint.x - startPoint.x, endPoint.y - startPoint.y)
        let isClosed = closingDistance < max(bounds.width, bounds.height) * 0.2

        if isClosed {
            // Check if it's a circle/ellipse
            if isApproximatelyCircular(stroke) {
                return createEllipse(from: bounds, stroke: stroke)
            }

            // Check if it's a rectangle
            if hasRectangularCorners(stroke) {
                return createRectangle(from: bounds, stroke: stroke)
            }
        }

        // Not a recognized shape - return original
        return stroke
    }

    private func isApproximatelyLine(_ stroke: VectorStroke) -> Bool {
        guard stroke.points.count >= 2 else { return true }

        let start = stroke.points.first!.location.cgPoint
        let end = stroke.points.last!.location.cgPoint

        let lineLength = hypot(end.x - start.x, end.y - start.y)
        guard lineLength > 20 else { return false } // Too short to straighten

        // Calculate max perpendicular distance from the line
        var maxDeviation: CGFloat = 0
        for point in stroke.points {
            let p = point.location.cgPoint
            // Distance from point to line formula
            let deviation = abs((end.y - start.y) * p.x - (end.x - start.x) * p.y + end.x * start.y - end.y * start.x) / lineLength
            maxDeviation = max(maxDeviation, deviation)
        }

        // If max deviation is less than 10% of line length, consider it a line
        return maxDeviation < lineLength * 0.15
    }

    private func isApproximatelyCircular(_ stroke: VectorStroke) -> Bool {
        let bounds = stroke.bounds
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let avgRadius = (bounds.width + bounds.height) / 4

        guard avgRadius > 10 else { return false } // Too small

        var deviationSum: CGFloat = 0
        for point in stroke.points {
            let p = point.location.cgPoint
            let distance = hypot(p.x - center.x, p.y - center.y)
            deviationSum += abs(distance - avgRadius)
        }

        let avgDeviation = deviationSum / CGFloat(stroke.points.count)
        return avgDeviation < avgRadius * 0.25
    }

    private func hasRectangularCorners(_ stroke: VectorStroke) -> Bool {
        guard stroke.points.count >= 8 else { return false }

        // Count significant direction changes (corners)
        var cornerCount = 0
        let threshold: CGFloat = 0.5 // cos(60°) - fairly sharp corner

        // Sample points to avoid noise
        let step = max(1, stroke.points.count / 20)

        for i in stride(from: step, to: stroke.points.count - step, by: step) {
            let p0 = stroke.points[i - step].location.cgPoint
            let p1 = stroke.points[i].location.cgPoint
            let p2 = stroke.points[min(i + step, stroke.points.count - 1)].location.cgPoint

            let v1 = CGPoint(x: p1.x - p0.x, y: p1.y - p0.y)
            let v2 = CGPoint(x: p2.x - p1.x, y: p2.y - p1.y)

            let len1 = hypot(v1.x, v1.y)
            let len2 = hypot(v2.x, v2.y)

            if len1 > 5 && len2 > 5 {
                let dot = (v1.x * v2.x + v1.y * v2.y) / (len1 * len2)
                if dot < threshold {
                    cornerCount += 1
                }
            }
        }

        return cornerCount >= 3 && cornerCount <= 6
    }

    private func createStraightLine(from start: CGPoint, to end: CGPoint, stroke: VectorStroke) -> VectorStroke {
        let points = [
            StrokePoint(location: start, pressure: 1.0),
            StrokePoint(location: end, pressure: 1.0)
        ]
        return VectorStroke(
            id: stroke.id,
            points: points,
            width: stroke.width,
            color: stroke.color,
            createdAt: stroke.createdAt
        )
    }

    private func createEllipse(from bounds: CGRect, stroke: VectorStroke) -> VectorStroke {
        let centerX = bounds.midX
        let centerY = bounds.midY
        let radiusX = bounds.width / 2
        let radiusY = bounds.height / 2

        let segments = 32
        var points: [StrokePoint] = []

        for i in 0...segments {
            let angle = CGFloat(i) / CGFloat(segments) * 2 * .pi
            let x = centerX + cos(angle) * radiusX
            let y = centerY + sin(angle) * radiusY
            points.append(StrokePoint(location: CGPoint(x: x, y: y), pressure: 1.0))
        }

        return VectorStroke(
            id: stroke.id,
            points: points,
            width: stroke.width,
            color: stroke.color,
            createdAt: stroke.createdAt
        )
    }

    private func createRectangle(from bounds: CGRect, stroke: VectorStroke) -> VectorStroke {
        let points = [
            StrokePoint(location: CGPoint(x: bounds.minX, y: bounds.minY), pressure: 1.0),
            StrokePoint(location: CGPoint(x: bounds.maxX, y: bounds.minY), pressure: 1.0),
            StrokePoint(location: CGPoint(x: bounds.maxX, y: bounds.maxY), pressure: 1.0),
            StrokePoint(location: CGPoint(x: bounds.minX, y: bounds.maxY), pressure: 1.0),
            StrokePoint(location: CGPoint(x: bounds.minX, y: bounds.minY), pressure: 1.0) // Close
        ]
        return VectorStroke(
            id: stroke.id,
            points: points,
            width: stroke.width,
            color: stroke.color,
            createdAt: stroke.createdAt
        )
    }

    func clearAll() {
        strokes.removeAll()
        recognizedShapes.removeAll()
        selectedShapeIds.removeAll()
        selectedStrokeIds.removeAll()
    }

    /// Erases strokes at the given point within the specified radius
    func eraseAt(_ point: CGPoint, radius: CGFloat) {
        strokes.removeAll { stroke in
            // Check if any point of the stroke is within the eraser radius
            for strokePoint in stroke.points {
                let dx = strokePoint.location.x - point.x
                let dy = strokePoint.location.y - point.y
                let distance = sqrt(dx * dx + dy * dy)
                if distance <= radius + stroke.width / 2 {
                    return true // Remove this stroke
                }
            }
            return false
        }
    }

    func resetViewport() {
        scale = 1.0
        offset = .zero
        rotation = 0
    }

    func zoom(by factor: CGFloat, around point: CGPoint) {
        let newScale = max(0.1, min(10.0, scale * factor))
        let scaleDiff = newScale - scale

        // Adjust offset to zoom around the point
        offset.x -= (point.x - offset.x) * scaleDiff / scale
        offset.y -= (point.y - offset.y) * scaleDiff / scale

        scale = newScale
    }

    func pan(by delta: CGPoint) {
        offset.x += delta.x / scale
        offset.y += delta.y / scale
    }

    /// Converts screen coordinates to canvas coordinates
    func screenToCanvas(_ point: CGPoint, viewSize: CGSize) -> CGPoint {
        let centerX = viewSize.width / 2
        let centerY = viewSize.height / 2

        return CGPoint(
            x: (point.x - centerX) / scale + offset.x,
            y: (point.y - centerY) / scale + offset.y
        )
    }

    /// Converts canvas coordinates to screen coordinates
    func canvasToScreen(_ point: CGPoint, viewSize: CGSize) -> CGPoint {
        let centerX = viewSize.width / 2
        let centerY = viewSize.height / 2

        return CGPoint(
            x: (point.x - offset.x) * scale + centerX,
            y: (point.y - offset.y) * scale + centerY
        )
    }
}

// MARK: - Canvas Tool

/// Available canvas tools
enum CanvasTool: String, CaseIterable, Identifiable {
    case pen
    case eraser
    case select
    case pan
    case rectangle
    case ellipse
    case line

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pen: return "Pen"
        case .eraser: return "Eraser"
        case .select: return "Select"
        case .pan: return "Pan"
        case .rectangle: return "Rectangle"
        case .ellipse: return "Ellipse"
        case .line: return "Line"
        }
    }

    var systemImage: String {
        switch self {
        case .pen: return "pencil"
        case .eraser: return "eraser"
        case .select: return "arrow.up.left.and.arrow.down.right"
        case .pan: return "hand.draw"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .line: return "line.diagonal"
        }
    }
}

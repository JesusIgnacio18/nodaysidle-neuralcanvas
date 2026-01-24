import Foundation
import CoreGraphics
import AppKit

// MARK: - Rendering Quality

/// Quality level for progressive rendering
enum RenderingQuality: Int, Sendable, Comparable {
    case preview = 0    // Fast, low-quality preview (100ms target)
    case draft = 1      // Medium quality draft
    case final_ = 2     // Full quality final render

    var name: String {
        switch self {
        case .preview: return "Preview"
        case .draft: return "Draft"
        case .final_: return "Final"
        }
    }

    var targetLatency: TimeInterval {
        switch self {
        case .preview: return 0.100  // 100ms
        case .draft: return 0.300    // 300ms
        case .final_: return 1.000   // 1s max
        }
    }

    var strokeSimplification: Int {
        switch self {
        case .preview: return 4  // Keep every 4th point
        case .draft: return 2    // Keep every 2nd point
        case .final_: return 1   // Keep all points
        }
    }

    var shapePrecision: CGFloat {
        switch self {
        case .preview: return 0.5  // Lower precision for fast rendering
        case .draft: return 0.75
        case .final_: return 1.0
        }
    }

    static func < (lhs: RenderingQuality, rhs: RenderingQuality) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Progressive Rendering Result

/// Result of a progressive rendering pass
struct ProgressiveRenderResult: Sendable {
    let quality: RenderingQuality
    let shapes: [RecognizedShape]
    let renderTime: TimeInterval
    let isComplete: Bool

    var shouldUpgrade: Bool {
        !isComplete && quality < .final_
    }
}

// MARK: - Progressive Rendering Service

/// Service for progressive quality rendering with fast previews
actor ProgressiveRenderingService {
    // MARK: - Properties

    private var currentTask: Task<Void, Never>?
    private var latestResult: ProgressiveRenderResult?

    // MARK: - Initialization

    init() {
        AppLogger.canvasRendering.debug("ProgressiveRenderingService initialized")
    }

    // MARK: - Public Interface

    /// Generates a quick low-fidelity preview from strokes
    func generatePreview(from strokes: [VectorStroke]) -> [RecognizedShape] {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Simplify strokes for fast processing
        let simplifiedStrokes = strokes.map { simplifyStroke($0, factor: RenderingQuality.preview.strokeSimplification) }

        // Generate rough shape outlines
        var previewShapes: [RecognizedShape] = []

        for stroke in simplifiedStrokes where stroke.isValid {
            let bounds = calculateBounds(for: stroke)

            // Determine rough shape type based on stroke characteristics
            let shapeType = inferShapeType(from: stroke)

            let shape = RecognizedShape(
                type: shapeType,
                bounds: bounds,
                confidence: 0.3, // Low confidence for preview
                cornerRadius: nil,
                label: nil
            )
            previewShapes.append(shape)
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        AppLogger.canvasRendering.debug("Preview generation: \(String(format: "%.1f", elapsed * 1000))ms for \(strokes.count) strokes")

        return previewShapes
    }

    /// Starts progressive rendering pipeline
    func startProgressiveRender(
        strokes: [VectorStroke],
        recognizer: SketchRecognitionActor,
        onQualityUpdate: @escaping @Sendable (ProgressiveRenderResult) async -> Void
    ) async {
        // Cancel any existing task
        currentTask?.cancel()

        // Create new progressive rendering task
        let task = Task { [weak self] in
            guard let self = self else { return }

            // Phase 1: Immediate preview (target: <100ms)
            let previewShapes = await self.generatePreview(from: strokes)
            let previewResult = ProgressiveRenderResult(
                quality: .preview,
                shapes: previewShapes,
                renderTime: 0.05,
                isComplete: false
            )
            await onQualityUpdate(previewResult)

            // Check for cancellation
            guard !Task.isCancelled else { return }

            // Phase 2: Draft quality with simplified recognition
            let draftStartTime = CFAbsoluteTimeGetCurrent()
            if let draftShapes = try? await self.runDraftRecognition(strokes: strokes, recognizer: recognizer) {
                let draftResult = ProgressiveRenderResult(
                    quality: .draft,
                    shapes: draftShapes,
                    renderTime: CFAbsoluteTimeGetCurrent() - draftStartTime,
                    isComplete: false
                )
                await onQualityUpdate(draftResult)
            }

            // Check for cancellation
            guard !Task.isCancelled else { return }

            // Phase 3: Full quality recognition
            let finalStartTime = CFAbsoluteTimeGetCurrent()
            if let finalShapes = try? await self.runFullRecognition(strokes: strokes, recognizer: recognizer) {
                let finalResult = ProgressiveRenderResult(
                    quality: .final_,
                    shapes: finalShapes,
                    renderTime: CFAbsoluteTimeGetCurrent() - finalStartTime,
                    isComplete: true
                )
                await onQualityUpdate(finalResult)
                await self.setLatestResult(finalResult)
            }
        }

        currentTask = task
    }

    /// Cancels any in-progress rendering
    func cancelRendering() {
        currentTask?.cancel()
        currentTask = nil
    }

    // MARK: - Private Helpers

    private func setLatestResult(_ result: ProgressiveRenderResult) {
        latestResult = result
    }

    private func simplifyStroke(_ stroke: VectorStroke, factor: Int) -> VectorStroke {
        guard factor > 1 else { return stroke }

        let simplifiedPoints = stride(from: 0, to: stroke.points.count, by: factor).map { stroke.points[$0] }

        // Ensure we include the last point
        var points = simplifiedPoints
        if let lastPoint = stroke.points.last, points.last != lastPoint {
            points.append(lastPoint)
        }

        return VectorStroke(
            id: stroke.id,
            points: points,
            width: stroke.width,
            color: stroke.color,
            createdAt: stroke.createdAt
        )
    }

    private func calculateBounds(for stroke: VectorStroke) -> CGRect {
        guard !stroke.points.isEmpty else {
            return .zero
        }

        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude

        for point in stroke.points {
            minX = min(minX, point.location.x)
            minY = min(minY, point.location.y)
            maxX = max(maxX, point.location.x)
            maxY = max(maxY, point.location.y)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func inferShapeType(from stroke: VectorStroke) -> ShapeType {
        guard stroke.points.count >= 3 else {
            return .line
        }

        let bounds = calculateBounds(for: stroke)

        // Check aspect ratio
        let aspectRatio = bounds.width / max(bounds.height, 1)

        // Check if closed (first and last points are close)
        let first = stroke.points.first!.location
        let last = stroke.points.last!.location
        let closeThreshold = max(bounds.width, bounds.height) * 0.1
        let isClosed = hypot(last.x - first.x, last.y - first.y) < closeThreshold

        if !isClosed {
            // Check if mostly horizontal/vertical for line
            if aspectRatio > 5 || aspectRatio < 0.2 {
                return .line
            }
            return .line
        }

        // Closed shape - check if circular
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        var distanceVariance: CGFloat = 0

        for point in stroke.points {
            let distance = hypot(point.location.x - center.x, point.location.y - center.y)
            let expectedRadius = min(bounds.width, bounds.height) / 2
            distanceVariance += abs(distance - expectedRadius)
        }

        let avgVariance = distanceVariance / CGFloat(stroke.points.count)
        let normalizedVariance = avgVariance / max(bounds.width, bounds.height)

        if normalizedVariance < 0.15 && abs(aspectRatio - 1.0) < 0.3 {
            return .circle
        }

        return .rectangle
    }

    private func runDraftRecognition(strokes: [VectorStroke], recognizer: SketchRecognitionActor) async throws -> [RecognizedShape] {
        // Use simplified strokes for draft
        let draftStrokes = strokes.map { simplifyStroke($0, factor: RenderingQuality.draft.strokeSimplification) }

        // Create a lightweight image for recognition
        guard let image = await createRecognitionImage(from: draftStrokes, scale: 0.5) else {
            return []
        }

        // Run recognition with draft settings
        let result = try await recognizer.processSketch(image: image)
        return result.shapes
    }

    private func runFullRecognition(strokes: [VectorStroke], recognizer: SketchRecognitionActor) async throws -> [RecognizedShape] {
        guard let image = await createRecognitionImage(from: strokes, scale: 1.0) else {
            return []
        }

        let result = try await recognizer.processSketch(image: image)
        return result.shapes
    }

    private func createRecognitionImage(from strokes: [VectorStroke], scale: CGFloat) async -> CGImage? {
        // Calculate bounds
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude

        for stroke in strokes {
            for point in stroke.points {
                minX = min(minX, point.location.x)
                minY = min(minY, point.location.y)
                maxX = max(maxX, point.location.x)
                maxY = max(maxY, point.location.y)
            }
        }

        let padding: CGFloat = 20
        let width = Int((maxX - minX + padding * 2) * scale)
        let height = Int((maxY - minY + padding * 2) * scale)

        guard width > 0 && height > 0 && width < 4096 && height < 4096 else {
            return nil
        }

        // Create bitmap context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        // Fill white background
        context.setFillColor(CGColor.white)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Draw strokes
        context.setStrokeColor(CGColor(gray: 0.2, alpha: 1.0))
        context.setLineWidth(2 * scale)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        for stroke in strokes {
            guard stroke.points.count >= 2 else { continue }

            let offsetX = -minX + padding
            let offsetY = -minY + padding

            context.beginPath()
            let firstPoint = stroke.points[0].location
            context.move(to: CGPoint(
                x: (firstPoint.x + offsetX) * scale,
                y: CGFloat(height) - (firstPoint.y + offsetY) * scale
            ))

            for i in 1..<stroke.points.count {
                let point = stroke.points[i].location
                context.addLine(to: CGPoint(
                    x: (point.x + offsetX) * scale,
                    y: CGFloat(height) - (point.y + offsetY) * scale
                ))
            }

            context.strokePath()
        }

        return context.makeImage()
    }
}

// MARK: - Tile Manager

/// Manages tile-based rendering for large canvases
actor TileManager {
    // MARK: - Types

    struct TileKey: Hashable, Sendable {
        let x: Int
        let y: Int
        let zoomLevel: Int
    }

    struct Tile: Sendable {
        let key: TileKey
        let image: CGImage
        let lastAccessed: Date
    }

    // MARK: - Properties

    private var tileCache: [TileKey: Tile] = [:]
    private let maxCacheSize = 50
    private let tileSize: CGFloat = 256

    // MARK: - Public Interface

    /// Gets visible tile keys for a viewport
    func getVisibleTileKeys(viewport: CGRect, zoomLevel: Int) -> [TileKey] {
        let startX = Int(floor(viewport.minX / tileSize))
        let startY = Int(floor(viewport.minY / tileSize))
        let endX = Int(ceil(viewport.maxX / tileSize))
        let endY = Int(ceil(viewport.maxY / tileSize))

        var keys: [TileKey] = []
        for x in startX...endX {
            for y in startY...endY {
                keys.append(TileKey(x: x, y: y, zoomLevel: zoomLevel))
            }
        }

        return keys
    }

    /// Gets or creates a tile
    func getTile(for key: TileKey) -> Tile? {
        if let tile = tileCache[key] {
            // Update access time
            tileCache[key] = Tile(key: key, image: tile.image, lastAccessed: Date())
            return tile
        }
        return nil
    }

    /// Stores a rendered tile
    func storeTile(_ tile: Tile) {
        // Evict oldest tiles if cache is full
        if tileCache.count >= maxCacheSize {
            evictOldestTiles(count: maxCacheSize / 4)
        }

        tileCache[tile.key] = tile
    }

    /// Clears all cached tiles
    func clearCache() {
        tileCache.removeAll()
        AppLogger.canvasRendering.debug("Tile cache cleared")
    }

    /// Invalidates tiles that intersect with the given rect
    func invalidateTiles(intersecting rect: CGRect, zoomLevel: Int) {
        let keys = getVisibleTileKeys(viewport: rect, zoomLevel: zoomLevel)
        for key in keys {
            tileCache.removeValue(forKey: key)
        }
    }

    // MARK: - Private Helpers

    private func evictOldestTiles(count: Int) {
        let sorted = tileCache.sorted { $0.value.lastAccessed < $1.value.lastAccessed }
        for (key, _) in sorted.prefix(count) {
            tileCache.removeValue(forKey: key)
        }
    }
}

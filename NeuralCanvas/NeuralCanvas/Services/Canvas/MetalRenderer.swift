import Foundation
import Metal
import MetalKit
import simd

// MARK: - Metal Renderer

/// Metal-based renderer for canvas strokes and shapes
final class MetalRenderer: NSObject {
    // MARK: - Properties

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary

    private var strokePipelineState: MTLRenderPipelineState?
    private var shapePipelineState: MTLRenderPipelineState?
    private var gridPipelineState: MTLRenderPipelineState?

    private var uniformsBuffer: MTLBuffer?
    private var gridUniformsBuffer: MTLBuffer?

    private var viewportSize: CGSize = .zero
    private var scale: Float = 1.0
    private var offset: SIMD2<Float> = .zero

    // MARK: - Initialization

    init(device: MTLDevice) throws {
        self.device = device

        guard let commandQueue = device.makeCommandQueue() else {
            throw RenderingError.deviceNotAvailable
        }
        self.commandQueue = commandQueue

        guard let library = device.makeDefaultLibrary() else {
            throw RenderingError.shaderCompilationFailed(shaderName: "default", underlying: NSError(domain: "Metal", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not create default library"]))
        }
        self.library = library

        super.init()

        try setupPipelines()
        setupBuffers()

        AppLogger.canvasRendering.info("MetalRenderer initialized successfully")
    }

    // MARK: - Pipeline Setup

    private func setupPipelines() throws {
        // Stroke pipeline
        let strokeVertexFunction = library.makeFunction(name: "stroke_vertex")
        let strokeFragmentFunction = library.makeFunction(name: "stroke_fragment")

        let strokePipelineDescriptor = MTLRenderPipelineDescriptor()
        strokePipelineDescriptor.vertexFunction = strokeVertexFunction
        strokePipelineDescriptor.fragmentFunction = strokeFragmentFunction
        strokePipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        strokePipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        strokePipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        strokePipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        strokePipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        strokePipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        strokePipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        strokePipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        // Vertex descriptor for strokes
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0

        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD2<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0

        vertexDescriptor.attributes[2].format = .float
        vertexDescriptor.attributes[2].offset = MemoryLayout<SIMD2<Float>>.stride * 2
        vertexDescriptor.attributes[2].bufferIndex = 0

        vertexDescriptor.attributes[3].format = .float4
        // color offset = 32 (SIMD4 requires 16-byte alignment, so there's implicit padding after _padding)
        vertexDescriptor.attributes[3].offset = 32
        vertexDescriptor.attributes[3].bufferIndex = 0

        vertexDescriptor.layouts[0].stride = MemoryLayout<StrokeVertexData>.stride

        strokePipelineDescriptor.vertexDescriptor = vertexDescriptor

        do {
            strokePipelineState = try device.makeRenderPipelineState(descriptor: strokePipelineDescriptor)
        } catch {
            throw RenderingError.pipelineCreationFailed(underlying: error)
        }

        // Shape pipeline
        let shapeVertexFunction = library.makeFunction(name: "shape_vertex")
        let shapeFragmentFunction = library.makeFunction(name: "shape_fragment")

        let shapePipelineDescriptor = MTLRenderPipelineDescriptor()
        shapePipelineDescriptor.vertexFunction = shapeVertexFunction
        shapePipelineDescriptor.fragmentFunction = shapeFragmentFunction
        shapePipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        shapePipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        shapePipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        shapePipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha

        // Vertex descriptor for shapes
        let shapeVertexDescriptor = MTLVertexDescriptor()
        // Position: float2
        shapeVertexDescriptor.attributes[0].format = .float2
        shapeVertexDescriptor.attributes[0].offset = 0
        shapeVertexDescriptor.attributes[0].bufferIndex = 0
        // Color: float4
        shapeVertexDescriptor.attributes[1].format = .float4
        shapeVertexDescriptor.attributes[1].offset = MemoryLayout<SIMD2<Float>>.stride
        shapeVertexDescriptor.attributes[1].bufferIndex = 0
        // Layout
        shapeVertexDescriptor.layouts[0].stride = MemoryLayout<ShapeVertexData>.stride

        shapePipelineDescriptor.vertexDescriptor = shapeVertexDescriptor

        do {
            shapePipelineState = try device.makeRenderPipelineState(descriptor: shapePipelineDescriptor)
        } catch {
            throw RenderingError.pipelineCreationFailed(underlying: error)
        }

        // Grid pipeline
        let gridVertexFunction = library.makeFunction(name: "grid_vertex")
        let gridFragmentFunction = library.makeFunction(name: "grid_fragment")

        let gridPipelineDescriptor = MTLRenderPipelineDescriptor()
        gridPipelineDescriptor.vertexFunction = gridVertexFunction
        gridPipelineDescriptor.fragmentFunction = gridFragmentFunction
        gridPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        gridPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        gridPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        gridPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha

        do {
            gridPipelineState = try device.makeRenderPipelineState(descriptor: gridPipelineDescriptor)
        } catch {
            throw RenderingError.pipelineCreationFailed(underlying: error)
        }

        AppLogger.canvasRendering.debug("Metal pipelines created successfully")
    }

    private func setupBuffers() {
        uniformsBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: .storageModeShared)
        gridUniformsBuffer = device.makeBuffer(length: MemoryLayout<GridUniforms>.stride, options: .storageModeShared)
    }

    // MARK: - Rendering

    func updateViewport(size: CGSize, scale: Float, offset: SIMD2<Float>) {
        self.viewportSize = size
        self.scale = scale
        self.offset = offset
    }

    func render(
        strokes: [VectorStroke],
        shapes: [RecognizedShape],
        showGrid: Bool,
        gridSize: Float,
        renderPassDescriptor: MTLRenderPassDescriptor,
        drawable: CAMetalDrawable
    ) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            AppLogger.canvasRendering.error("Failed to create command buffer")
            return
        }

        // Update uniforms
        updateUniforms()

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            AppLogger.canvasRendering.error("Failed to create render encoder")
            return
        }

        // Draw grid if enabled
        if showGrid {
            drawGrid(encoder: renderEncoder, gridSize: gridSize)
        }

        // Draw shapes
        for shape in shapes {
            drawShape(encoder: renderEncoder, shape: shape)
        }

        // Draw strokes
        if !strokes.isEmpty {
            print("Drawing \(strokes.count) strokes")
        }
        for stroke in strokes {
            print("  Stroke with \(stroke.points.count) points, color: r=\(stroke.color.red), g=\(stroke.color.green), b=\(stroke.color.blue)")
            drawStroke(encoder: renderEncoder, stroke: stroke)
        }

        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func updateUniforms() {
        guard let uniformsBuffer = uniformsBuffer else { return }

        let width = Float(viewportSize.width)
        let height = Float(viewportSize.height)

        // Create orthographic projection matrix
        let projectionMatrix = orthographicProjection(
            left: -width / 2 / scale + offset.x,
            right: width / 2 / scale + offset.x,
            bottom: -height / 2 / scale + offset.y,
            top: height / 2 / scale + offset.y,
            near: -1,
            far: 1
        )

        var uniforms = Uniforms(
            viewProjectionMatrix: projectionMatrix,
            viewportSize: SIMD2<Float>(width, height),
            time: Float(CACurrentMediaTime()),
            scale: scale
        )

        memcpy(uniformsBuffer.contents(), &uniforms, MemoryLayout<Uniforms>.stride)
    }

    private func drawGrid(encoder: MTLRenderCommandEncoder, gridSize: Float) {
        guard let gridPipelineState = gridPipelineState,
              let gridUniformsBuffer = gridUniformsBuffer else { return }

        var gridUniforms = GridUniforms(
            viewProjectionMatrix: simd_float4x4(1),
            viewportSize: SIMD2<Float>(Float(viewportSize.width), Float(viewportSize.height)),
            gridSize: gridSize,
            gridColor: SIMD4<Float>(0.5, 0.5, 0.5, 0.2),
            majorGridColor: SIMD4<Float>(0.5, 0.5, 0.5, 0.4),
            majorGridInterval: 10,
            offset: offset,
            scale: scale
        )

        memcpy(gridUniformsBuffer.contents(), &gridUniforms, MemoryLayout<GridUniforms>.stride)

        encoder.setRenderPipelineState(gridPipelineState)
        encoder.setVertexBuffer(gridUniformsBuffer, offset: 0, index: 0)
        encoder.setFragmentBuffer(gridUniformsBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }

    private func drawStroke(encoder: MTLRenderCommandEncoder, stroke: VectorStroke) {
        guard let strokePipelineState = strokePipelineState,
              let uniformsBuffer = uniformsBuffer,
              stroke.points.count >= 1 else { return }

        // Generate vertex data for stroke
        let vertexData = generateStrokeVertices(stroke: stroke)
        guard !vertexData.isEmpty else { return }

        guard let vertexBuffer = device.makeBuffer(
            bytes: vertexData,
            length: vertexData.count * MemoryLayout<StrokeVertexData>.stride,
            options: .storageModeShared
        ) else { return }

        encoder.setRenderPipelineState(strokePipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(uniformsBuffer, offset: 0, index: 1)
        encoder.setFragmentBuffer(uniformsBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: vertexData.count)
    }

    private func drawShape(encoder: MTLRenderCommandEncoder, shape: RecognizedShape) {
        guard let shapePipelineState = shapePipelineState,
              let uniformsBuffer = uniformsBuffer else { return }

        // Generate vertices based on shape type
        let vertexData = generateShapeVertices(shape: shape)
        guard !vertexData.isEmpty else { return }

        guard let vertexBuffer = device.makeBuffer(
            bytes: vertexData,
            length: vertexData.count * MemoryLayout<ShapeVertexData>.stride,
            options: .storageModeShared
        ) else { return }

        encoder.setRenderPipelineState(shapePipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(uniformsBuffer, offset: 0, index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexData.count)
    }

    // MARK: - Vertex Generation

    private func generateStrokeVertices(stroke: VectorStroke) -> [StrokeVertexData] {
        var vertices: [StrokeVertexData] = []

        let color = SIMD4<Float>(
            Float(stroke.color.red),
            Float(stroke.color.green),
            Float(stroke.color.blue),
            Float(stroke.color.alpha)
        )

        // Handle single point as a small dot
        if stroke.points.count == 1 {
            let p = stroke.points[0]
            let width = Float(stroke.width * p.pressure) / 2.0
            let pos = SIMD2<Float>(Float(p.location.x), Float(p.location.y))
            let normal = SIMD2<Float>(1, 0)

            // Create a small quad for the dot (triangle strip: 4 vertices)
            vertices.append(StrokeVertexData(position: pos + SIMD2(-width, -width), normal: normal, width: width * 2, color: color))
            vertices.append(StrokeVertexData(position: pos + SIMD2(width, -width), normal: -normal, width: width * 2, color: color))
            vertices.append(StrokeVertexData(position: pos + SIMD2(-width, width), normal: normal, width: width * 2, color: color))
            vertices.append(StrokeVertexData(position: pos + SIMD2(width, width), normal: -normal, width: width * 2, color: color))

            return vertices
        }

        // Multi-point stroke rendering
        for i in 0..<stroke.points.count - 1 {
            let p0 = stroke.points[i]
            let p1 = stroke.points[i + 1]

            let pos0 = SIMD2<Float>(Float(p0.location.x), Float(p0.location.y))
            let pos1 = SIMD2<Float>(Float(p1.location.x), Float(p1.location.y))

            let dir = normalize(pos1 - pos0)
            let normal = SIMD2<Float>(-dir.y, dir.x)

            let width0 = Float(stroke.width * p0.pressure)
            let width1 = Float(stroke.width * p1.pressure)

            // Add quad as triangle strip
            vertices.append(StrokeVertexData(position: pos0, normal: normal, width: width0, color: color))
            vertices.append(StrokeVertexData(position: pos0, normal: -normal, width: width0, color: color))
            vertices.append(StrokeVertexData(position: pos1, normal: normal, width: width1, color: color))
            vertices.append(StrokeVertexData(position: pos1, normal: -normal, width: width1, color: color))
        }

        return vertices
    }

    private func generateShapeVertices(shape: RecognizedShape) -> [ShapeVertexData] {
        let bounds = shape.bounds.cgRect
        let color = SIMD4<Float>(0.0, 0.48, 1.0, 0.3) // Default blue with transparency

        switch shape.type {
        case .rectangle, .roundedRectangle, .card, .button, .inputField, .container:
            return generateRectangleVertices(bounds: bounds, color: color)
        case .circle, .ellipse:
            return generateEllipseVertices(bounds: bounds, color: color)
        case .line, .divider:
            return generateLineVertices(bounds: bounds, color: color)
        default:
            return generateRectangleVertices(bounds: bounds, color: color)
        }
    }

    private func generateRectangleVertices(bounds: CGRect, color: SIMD4<Float>) -> [ShapeVertexData] {
        let minX = Float(bounds.minX)
        let maxX = Float(bounds.maxX)
        let minY = Float(bounds.minY)
        let maxY = Float(bounds.maxY)

        return [
            ShapeVertexData(position: SIMD2<Float>(minX, minY), color: color),
            ShapeVertexData(position: SIMD2<Float>(maxX, minY), color: color),
            ShapeVertexData(position: SIMD2<Float>(maxX, maxY), color: color),
            ShapeVertexData(position: SIMD2<Float>(minX, minY), color: color),
            ShapeVertexData(position: SIMD2<Float>(maxX, maxY), color: color),
            ShapeVertexData(position: SIMD2<Float>(minX, maxY), color: color)
        ]
    }

    private func generateEllipseVertices(bounds: CGRect, color: SIMD4<Float>) -> [ShapeVertexData] {
        var vertices: [ShapeVertexData] = []
        let segments = 32

        let centerX = Float(bounds.midX)
        let centerY = Float(bounds.midY)
        let radiusX = Float(bounds.width / 2)
        let radiusY = Float(bounds.height / 2)

        let center = SIMD2<Float>(centerX, centerY)

        for i in 0..<segments {
            let angle1 = Float(i) / Float(segments) * 2 * .pi
            let angle2 = Float(i + 1) / Float(segments) * 2 * .pi

            let p1 = SIMD2<Float>(centerX + cos(angle1) * radiusX, centerY + sin(angle1) * radiusY)
            let p2 = SIMD2<Float>(centerX + cos(angle2) * radiusX, centerY + sin(angle2) * radiusY)

            vertices.append(ShapeVertexData(position: center, color: color))
            vertices.append(ShapeVertexData(position: p1, color: color))
            vertices.append(ShapeVertexData(position: p2, color: color))
        }

        return vertices
    }

    private func generateLineVertices(bounds: CGRect, color: SIMD4<Float>) -> [ShapeVertexData] {
        let thickness: Float = 2.0

        let p1 = SIMD2<Float>(Float(bounds.minX), Float(bounds.midY))
        let p2 = SIMD2<Float>(Float(bounds.maxX), Float(bounds.midY))

        let dir = normalize(p2 - p1)
        let normal = SIMD2<Float>(-dir.y, dir.x) * thickness / 2

        return [
            ShapeVertexData(position: p1 + normal, color: color),
            ShapeVertexData(position: p1 - normal, color: color),
            ShapeVertexData(position: p2 + normal, color: color),
            ShapeVertexData(position: p1 - normal, color: color),
            ShapeVertexData(position: p2 + normal, color: color),
            ShapeVertexData(position: p2 - normal, color: color)
        ]
    }

    // MARK: - Utility

    private func orthographicProjection(left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) -> simd_float4x4 {
        let width = right - left
        let height = top - bottom
        let depth = far - near

        return simd_float4x4(
            SIMD4<Float>(2 / width, 0, 0, 0),
            SIMD4<Float>(0, 2 / height, 0, 0),
            SIMD4<Float>(0, 0, -2 / depth, 0),
            SIMD4<Float>(-(right + left) / width, -(top + bottom) / height, -(far + near) / depth, 1)
        )
    }
}

// MARK: - Data Structures

struct Uniforms {
    var viewProjectionMatrix: simd_float4x4
    var viewportSize: SIMD2<Float>
    var time: Float
    var scale: Float
}

struct GridUniforms {
    var viewProjectionMatrix: simd_float4x4
    var viewportSize: SIMD2<Float>
    var gridSize: Float
    var gridColor: SIMD4<Float>
    var majorGridColor: SIMD4<Float>
    var majorGridInterval: Int32
    var offset: SIMD2<Float>
    var scale: Float
}

struct StrokeVertexData {
    var position: SIMD2<Float>   // 8 bytes (offset 0)
    var normal: SIMD2<Float>     // 8 bytes (offset 8)
    var width: Float             // 4 bytes (offset 16)
    var _padding: Float = 0      // 4 bytes padding to align color (offset 20)
    var color: SIMD4<Float>      // 16 bytes (offset 24)
    // Total: 40 bytes
}

struct ShapeVertexData {
    var position: SIMD2<Float>
    var color: SIMD4<Float>
}

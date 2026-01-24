import SwiftUI
import MetalKit
import AppKit

// MARK: - Metal Canvas View

/// SwiftUI wrapper for MTKView providing Metal-based canvas rendering
struct MetalCanvasView: NSViewRepresentable {
    @Binding var canvasState: CanvasState
    @Binding var selectedTool: CanvasTool
    let onDraw: ((CGPoint, CGFloat) -> Void)?
    let onDrawEnd: (() -> Void)?

    init(
        canvasState: Binding<CanvasState>,
        selectedTool: Binding<CanvasTool> = .constant(.pen),
        onDraw: ((CGPoint, CGFloat) -> Void)? = nil,
        onDrawEnd: (() -> Void)? = nil
    ) {
        self._canvasState = canvasState
        self._selectedTool = selectedTool
        self.onDraw = onDraw
        self.onDrawEnd = onDrawEnd
    }

    func makeNSView(context: Context) -> MTKView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            AppLogger.canvasRendering.error("Metal not available")
            return MTKView()
        }

        let mtkView = CanvasMTKView(frame: .zero, device: device)
        mtkView.delegate = context.coordinator
        mtkView.coordinator = context.coordinator
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.preferredFramesPerSecond = 60
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)

        // Setup gesture recognizers
        setupGestureRecognizers(for: mtkView, coordinator: context.coordinator)

        return mtkView
    }

    func updateNSView(_ mtkView: MTKView, context: Context) {
        context.coordinator.canvasState = canvasState
        context.coordinator.updateClearColor()
        // Update tool on the MTKView
        if let canvasMTKView = mtkView as? CanvasMTKView {
            canvasMTKView.setTool(selectedTool)
        }
        mtkView.setNeedsDisplay(mtkView.bounds)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            canvasState: canvasState,
            onDraw: onDraw,
            onDrawEnd: onDrawEnd
        )
    }

    private func setupGestureRecognizers(for view: MTKView, coordinator: Coordinator) {
        // Pan gesture for canvas panning
        let panGesture = NSPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.handlePan(_:)))
        panGesture.buttonMask = 0x2 // Right mouse button
        view.addGestureRecognizer(panGesture)

        // Magnification gesture for zooming
        let magnifyGesture = NSMagnificationGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleMagnify(_:)))
        view.addGestureRecognizer(magnifyGesture)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MTKViewDelegate {
        var canvasState: CanvasState
        var renderer: MetalRenderer?
        var device: MTLDevice?

        var onDraw: ((CGPoint, CGFloat) -> Void)?
        var onDrawEnd: (() -> Void)?

        private var isDrawing = false
        private var lastDrawTime: CFTimeInterval = 0
        private var targetFrameRate: Int = 60

        init(
            canvasState: CanvasState,
            onDraw: ((CGPoint, CGFloat) -> Void)?,
            onDrawEnd: (() -> Void)?
        ) {
            self.canvasState = canvasState
            self.onDraw = onDraw
            self.onDrawEnd = onDrawEnd
            super.init()
        }

        func setupRenderer(device: MTLDevice) {
            self.device = device
            do {
                self.renderer = try MetalRenderer(device: device)
                print("MetalRenderer created successfully!")
            } catch {
                print("ERROR: Failed to create MetalRenderer: \(error.localizedDescription)")
                AppLogger.canvasRendering.error("Failed to create MetalRenderer: \(error.localizedDescription)")
            }
        }

        func updateClearColor() {
            // Update clear color based on canvas state background
            let bg = canvasState.backgroundColor
            // The MTKView clear color is set in draw method
        }

        // MARK: - MTKViewDelegate

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            renderer?.updateViewport(
                size: size,
                scale: Float(canvasState.scale),
                offset: SIMD2<Float>(Float(canvasState.offset.x), Float(canvasState.offset.y))
            )
        }

        func draw(in view: MTKView) {
            guard let renderer = renderer,
                  let renderPassDescriptor = view.currentRenderPassDescriptor,
                  let drawable = view.currentDrawable else {
                return
            }

            // Set clear color
            let bg = canvasState.backgroundColor
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
                red: Double(bg.red),
                green: Double(bg.green),
                blue: Double(bg.blue),
                alpha: Double(bg.alpha)
            )

            // Update viewport
            renderer.updateViewport(
                size: view.drawableSize,
                scale: Float(canvasState.scale),
                offset: SIMD2<Float>(Float(canvasState.offset.x), Float(canvasState.offset.y))
            )

            // Combine strokes with current stroke if drawing
            var allStrokes = canvasState.strokes
            if let currentStroke = canvasState.currentStroke {
                allStrokes.append(currentStroke)
            }

            // Render
            renderer.render(
                strokes: allStrokes,
                shapes: canvasState.recognizedShapes,
                showGrid: canvasState.showGrid,
                gridSize: Float(canvasState.gridSize),
                renderPassDescriptor: renderPassDescriptor,
                drawable: drawable
            )
        }

        // MARK: - Gesture Handlers

        @objc func handlePan(_ gesture: NSPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)
            canvasState.pan(by: CGPoint(x: translation.x, y: -translation.y))
            gesture.setTranslation(.zero, in: gesture.view)
        }

        @objc func handleMagnify(_ gesture: NSMagnificationGestureRecognizer) {
            guard let view = gesture.view else { return }
            let location = gesture.location(in: view)
            let factor = 1.0 + gesture.magnification
            canvasState.zoom(by: factor, around: location)
            gesture.magnification = 0
        }

        // MARK: - Frame Rate Management

        func setTargetFrameRate(_ rate: Int) {
            targetFrameRate = rate
        }

        func setProcessingMode(_ isProcessing: Bool) {
            // Drop to 30fps during ML processing
            targetFrameRate = isProcessing ? 30 : 60
        }
    }
}

// MARK: - Canvas MTKView

/// Custom MTKView subclass for handling mouse events
final class CanvasMTKView: MTKView {
    weak var coordinator: MetalCanvasView.Coordinator?

    private var isDrawing = false
    private var isErasing = false
    private var isPanning = false
    private var currentTool: CanvasTool = .pen
    private var lastErasePoint: CGPoint = .zero
    private var lastPanPoint: CGPoint = .zero
    private var shapeStartPoint: CGPoint = .zero

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        print("viewDidMoveToWindow called, device: \(device != nil), coordinator: \(coordinator != nil)")
        if let device = device {
            coordinator?.setupRenderer(device: device)
            print("Renderer setup called")
        }
        // Become first responder to receive mouse events
        DispatchQueue.main.async { [weak self] in
            self?.window?.makeFirstResponder(self)
            print("Made first responder: \(self?.window?.firstResponder === self)")
        }
    }

    override func becomeFirstResponder() -> Bool {
        return true
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        // Ensure we're first responder
        window?.makeFirstResponder(self)

        guard let coordinator = coordinator else {
            print("ERROR: mouseDown - No coordinator!")
            return
        }

        let location = convert(event.locationInWindow, from: nil)
        let canvasPoint = coordinator.canvasState.screenToCanvas(location, viewSize: bounds.size)
        let pressure = CGFloat(event.pressure > 0 ? event.pressure : 1.0)

        print("mouseDown at (\(canvasPoint.x), \(canvasPoint.y)), tool: \(currentTool.rawValue)")

        switch currentTool {
        case .pen:
            // Drawing with pen
            isDrawing = true
            isErasing = false
            coordinator.canvasState.startStroke(at: canvasPoint, pressure: pressure)
            coordinator.onDraw?(canvasPoint, pressure)
            print("Started stroke, color: r=\(coordinator.canvasState.currentStrokeColor.red), g=\(coordinator.canvasState.currentStrokeColor.green), b=\(coordinator.canvasState.currentStrokeColor.blue)")

        case .eraser:
            // Erasing mode
            isDrawing = false
            isErasing = true
            lastErasePoint = canvasPoint
            coordinator.canvasState.eraseAt(canvasPoint, radius: coordinator.canvasState.currentStrokeWidth * 2)

        case .pan:
            // Pan handled by gesture recognizer or drag
            isPanning = true
            lastPanPoint = location

        case .select:
            // Selection mode - not implemented yet
            break

        case .rectangle, .ellipse, .line:
            // Shape tools - start drawing shapes
            isDrawing = true
            isErasing = false
            shapeStartPoint = canvasPoint
            // Don't start a stroke for shapes - we'll create the shape on mouseUp
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let coordinator = coordinator else { return }

        let location = convert(event.locationInWindow, from: nil)
        let canvasPoint = coordinator.canvasState.screenToCanvas(location, viewSize: bounds.size)
        let pressure = CGFloat(event.pressure > 0 ? event.pressure : 1.0)

        if isDrawing {
            switch currentTool {
            case .pen:
                // Freehand drawing
                coordinator.canvasState.continueStroke(to: canvasPoint, pressure: pressure)
                coordinator.onDraw?(canvasPoint, pressure)

            case .rectangle, .ellipse, .line:
                // Update preview stroke for shape tools
                updateShapePreview(to: canvasPoint, state: coordinator.canvasState)

            default:
                break
            }
        } else if isErasing {
            // Erase strokes along the path
            coordinator.canvasState.eraseAt(canvasPoint, radius: coordinator.canvasState.currentStrokeWidth * 2)
            lastErasePoint = canvasPoint
        } else if isPanning {
            // Pan the canvas
            let delta = CGPoint(x: location.x - lastPanPoint.x, y: -(location.y - lastPanPoint.y))
            coordinator.canvasState.pan(by: delta)
            lastPanPoint = location
        }
    }

    private func updateShapePreview(to endPoint: CGPoint, state: CanvasState) {
        // Create a preview stroke based on the current shape tool
        switch currentTool {
        case .rectangle:
            state.currentStroke = createRectangleStroke(from: shapeStartPoint, to: endPoint, state: state)
        case .ellipse:
            state.currentStroke = createEllipseStroke(from: shapeStartPoint, to: endPoint, state: state)
        case .line:
            state.currentStroke = createLineStroke(from: shapeStartPoint, to: endPoint, state: state)
        default:
            break
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard let coordinator = coordinator else { return }

        let location = convert(event.locationInWindow, from: nil)
        let canvasPoint = coordinator.canvasState.screenToCanvas(location, viewSize: bounds.size)

        if isDrawing {
            switch currentTool {
            case .pen:
                let strokeCount = coordinator.canvasState.strokes.count
                coordinator.canvasState.endStroke()
                coordinator.onDrawEnd?()
                print("mouseUp: stroke ended, total strokes: \(coordinator.canvasState.strokes.count) (was \(strokeCount))")

            case .rectangle:
                // Create rectangle shape as a closed stroke
                coordinator.canvasState.currentStroke = nil // Clear preview
                let shapeStroke = createRectangleStroke(from: shapeStartPoint, to: canvasPoint, state: coordinator.canvasState)
                coordinator.canvasState.strokes.append(shapeStroke)
                coordinator.onDrawEnd?()
                print("mouseUp: rectangle created")

            case .ellipse:
                // Create ellipse shape as a stroke
                coordinator.canvasState.currentStroke = nil // Clear preview
                let shapeStroke = createEllipseStroke(from: shapeStartPoint, to: canvasPoint, state: coordinator.canvasState)
                coordinator.canvasState.strokes.append(shapeStroke)
                coordinator.onDrawEnd?()
                print("mouseUp: ellipse created")

            case .line:
                // Create line as a simple two-point stroke
                coordinator.canvasState.currentStroke = nil // Clear preview
                let shapeStroke = createLineStroke(from: shapeStartPoint, to: canvasPoint, state: coordinator.canvasState)
                coordinator.canvasState.strokes.append(shapeStroke)
                coordinator.onDrawEnd?()
                print("mouseUp: line created")

            default:
                break
            }
        }

        // Reset all interaction states
        isDrawing = false
        isErasing = false
        isPanning = false
    }

    // MARK: - Shape Creation Helpers

    private func createRectangleStroke(from start: CGPoint, to end: CGPoint, state: CanvasState) -> VectorStroke {
        let minX = min(start.x, end.x)
        let maxX = max(start.x, end.x)
        let minY = min(start.y, end.y)
        let maxY = max(start.y, end.y)

        // Create rectangle points (closed path)
        let points: [StrokePoint] = [
            StrokePoint(location: CGPoint(x: minX, y: minY), pressure: 1.0),
            StrokePoint(location: CGPoint(x: maxX, y: minY), pressure: 1.0),
            StrokePoint(location: CGPoint(x: maxX, y: maxY), pressure: 1.0),
            StrokePoint(location: CGPoint(x: minX, y: maxY), pressure: 1.0),
            StrokePoint(location: CGPoint(x: minX, y: minY), pressure: 1.0) // Close the rectangle
        ]

        return VectorStroke(
            points: points,
            width: state.currentStrokeWidth,
            color: state.currentStrokeColor
        )
    }

    private func createEllipseStroke(from start: CGPoint, to end: CGPoint, state: CanvasState) -> VectorStroke {
        let centerX = (start.x + end.x) / 2
        let centerY = (start.y + end.y) / 2
        let radiusX = abs(end.x - start.x) / 2
        let radiusY = abs(end.y - start.y) / 2

        // Create ellipse with 32 segments
        let segments = 32
        var points: [StrokePoint] = []

        for i in 0...segments {
            let angle = CGFloat(i) / CGFloat(segments) * 2 * .pi
            let x = centerX + cos(angle) * radiusX
            let y = centerY + sin(angle) * radiusY
            points.append(StrokePoint(location: CGPoint(x: x, y: y), pressure: 1.0))
        }

        return VectorStroke(
            points: points,
            width: state.currentStrokeWidth,
            color: state.currentStrokeColor
        )
    }

    private func createLineStroke(from start: CGPoint, to end: CGPoint, state: CanvasState) -> VectorStroke {
        let points: [StrokePoint] = [
            StrokePoint(location: start, pressure: 1.0),
            StrokePoint(location: end, pressure: 1.0)
        ]

        return VectorStroke(
            points: points,
            width: state.currentStrokeWidth,
            color: state.currentStrokeColor
        )
    }

    // MARK: - Scroll Events

    override func scrollWheel(with event: NSEvent) {
        guard let coordinator = coordinator else { return }

        if event.modifierFlags.contains(.command) {
            // Zoom with Command + scroll
            let factor = 1.0 + event.scrollingDeltaY * 0.01
            let location = convert(event.locationInWindow, from: nil)
            coordinator.canvasState.zoom(by: factor, around: location)
        } else {
            // Pan
            coordinator.canvasState.pan(by: CGPoint(x: event.scrollingDeltaX, y: -event.scrollingDeltaY))
        }
    }

    // MARK: - Key Events

    override func keyDown(with event: NSEvent) {
        guard let coordinator = coordinator else {
            super.keyDown(with: event)
            return
        }

        switch event.keyCode {
        case 49: // Space - pan mode
            currentTool = .pan
        case 51: // Delete - clear selection
            // Handle delete
            break
        default:
            super.keyDown(with: event)
        }
    }

    override func keyUp(with event: NSEvent) {
        switch event.keyCode {
        case 49: // Space released
            currentTool = .pen
        default:
            super.keyUp(with: event)
        }
    }

    // MARK: - Tool Management

    func setTool(_ tool: CanvasTool) {
        currentTool = tool
    }
}

// MARK: - Processing Feedback View

/// Shows visual feedback during ML processing
struct ProcessingFeedbackView: View {
    let isProcessing: Bool
    let progress: Double

    @State private var shimmerPhase: CGFloat = 0

    var body: some View {
        if isProcessing {
            VStack(spacing: 8) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 200)

                Text("Processing sketch...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .transition(.opacity.combined(with: .scale))
        }
    }
}

// MARK: - Preview

#Preview {
    MetalCanvasView(canvasState: .constant(CanvasState()))
        .frame(width: 800, height: 600)
}

import SwiftUI
import Foundation

// MARK: - Transition Namespace

/// Environment key for the shared animation namespace
struct AnimationNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var animationNamespace: Namespace.ID? {
        get { self[AnimationNamespaceKey.self] }
        set { self[AnimationNamespaceKey.self] = newValue }
    }
}

// MARK: - View Mode Enum

/// Represents the different view modes in the canvas
enum CanvasViewMode: String, CaseIterable, Identifiable {
    case sketch
    case wireframe
    case split

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sketch: return "Sketch"
        case .wireframe: return "Wireframe"
        case .split: return "Split View"
        }
    }

    var icon: String {
        switch self {
        case .sketch: return "pencil.and.outline"
        case .wireframe: return "rectangle.3.group"
        case .split: return "rectangle.split.2x1"
        }
    }
}

// MARK: - Morphing Canvas Container

/// A container that provides smooth transitions between sketch and wireframe modes
struct MorphingCanvasContainer<SketchContent: View, WireframeContent: View>: View {
    @Binding var viewMode: CanvasViewMode
    let sketchContent: () -> SketchContent
    let wireframeContent: () -> WireframeContent

    @Namespace private var animationNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var animationDuration: Double {
        reduceMotion ? 0 : 0.4
    }

    var body: some View {
        ZStack {
            switch viewMode {
            case .sketch:
                sketchContent()
                    .matchedGeometryEffect(id: "canvas", in: animationNamespace)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))

            case .wireframe:
                wireframeContent()
                    .matchedGeometryEffect(id: "canvas", in: animationNamespace)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))

            case .split:
                HStack(spacing: 1) {
                    sketchContent()
                        .matchedGeometryEffect(id: "sketch-split", in: animationNamespace)
                        .frame(maxWidth: .infinity)

                    Divider()

                    wireframeContent()
                        .matchedGeometryEffect(id: "wireframe-split", in: animationNamespace)
                        .frame(maxWidth: .infinity)
                }
                .transition(.opacity)
            }
        }
        .animation(.spring(duration: animationDuration, bounce: 0.2), value: viewMode)
        .environment(\.animationNamespace, animationNamespace)
    }
}

// MARK: - Indexed Shape Wrapper

/// Wrapper to provide stable identity for shapes in animations
struct IndexedShape: Identifiable {
    let id: Int
    let shape: RecognizedShape

    init(index: Int, shape: RecognizedShape) {
        self.id = index
        self.shape = shape
    }
}

// MARK: - Shape Morphing View

/// Animates recognized shapes appearing and morphing
struct ShapeMorphingView: View {
    let shapes: [RecognizedShape]
    let isVisible: Bool

    @Namespace private var shapeNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var indexedShapes: [IndexedShape] {
        shapes.enumerated().map { IndexedShape(index: $0.offset, shape: $0.element) }
    }

    var body: some View {
        ZStack {
            ForEach(indexedShapes) { indexed in
                ShapeView(shape: indexed.shape)
                    .matchedGeometryEffect(id: indexed.id, in: shapeNamespace)
                    .opacity(isVisible ? 1 : 0)
                    .scaleEffect(isVisible ? 1 : 0.8)
                    .animation(
                        reduceMotion ? .none : .spring(duration: 0.3, bounce: 0.3).delay(Double(indexed.id) * 0.05),
                        value: isVisible
                    )
            }
        }
    }
}

// MARK: - Shape View

/// Individual shape rendering with animation support
struct ShapeView: View {
    let shape: RecognizedShape

    var body: some View {
        Group {
            switch shape.type {
            case .rectangle, .card:
                Rectangle()
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .frame(width: shape.bounds.width, height: shape.bounds.height)

            case .roundedRectangle:
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .frame(width: shape.bounds.width, height: shape.bounds.height)

            case .circle:
                Circle()
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .frame(width: min(shape.bounds.width, shape.bounds.height))

            case .ellipse:
                Ellipse()
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .frame(width: shape.bounds.width, height: shape.bounds.height)

            case .button:
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.accentColor, lineWidth: 2)
                    )
                    .frame(width: shape.bounds.width, height: shape.bounds.height)

            case .inputField:
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.gray.opacity(0.5), lineWidth: 1)
                    )
                    .frame(width: shape.bounds.width, height: shape.bounds.height)

            case .text:
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: shape.bounds.width, height: shape.bounds.height)

            case .line:
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: shape.bounds.width, height: max(shape.bounds.height, 2))

            case .arrow:
                ArrowShape()
                    .stroke(Color.accentColor, lineWidth: 2)
                    .frame(width: shape.bounds.width, height: shape.bounds.height)

            case .image:
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
                    .frame(width: shape.bounds.width, height: shape.bounds.height)

            case .icon:
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        Image(systemName: "star")
                            .foregroundColor(.gray)
                    )
                    .frame(width: min(shape.bounds.width, shape.bounds.height))

            case .divider:
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: shape.bounds.width, height: max(shape.bounds.height, 1))

            case .container:
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    .frame(width: shape.bounds.width, height: shape.bounds.height)

            case .unknown:
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
                    .frame(width: shape.bounds.width, height: shape.bounds.height)
            }
        }
        .position(
            x: shape.bounds.x + shape.bounds.width / 2,
            y: shape.bounds.y + shape.bounds.height / 2
        )
    }
}

// MARK: - Arrow Shape

/// Custom arrow shape for shape rendering
struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Draw arrow from left to right
        let startX = rect.minX
        let endX = rect.maxX
        let midY = rect.midY
        let arrowHeadSize = min(rect.height * 0.4, rect.width * 0.2)

        // Main line
        path.move(to: CGPoint(x: startX, y: midY))
        path.addLine(to: CGPoint(x: endX - arrowHeadSize, y: midY))

        // Arrow head
        path.move(to: CGPoint(x: endX, y: midY))
        path.addLine(to: CGPoint(x: endX - arrowHeadSize, y: midY - arrowHeadSize))
        path.move(to: CGPoint(x: endX, y: midY))
        path.addLine(to: CGPoint(x: endX - arrowHeadSize, y: midY + arrowHeadSize))

        return path
    }
}

// MARK: - Transition Toolbar

/// Toolbar for switching between view modes
struct ViewModeToolbar: View {
    @Binding var viewMode: CanvasViewMode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            ForEach(CanvasViewMode.allCases) { mode in
                Button {
                    withAnimation(reduceMotion ? .none : .spring(duration: 0.3)) {
                        viewMode = mode
                    }
                } label: {
                    Label(mode.label, systemImage: mode.icon)
                        .labelStyle(.iconOnly)
                        .frame(width: 32, height: 24)
                }
                .buttonStyle(.borderless)
                .background(viewMode == mode ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(4)
                .help(mode.label)
            }
        }
        .padding(4)
        .background(.regularMaterial)
        .cornerRadius(8)
    }
}

// MARK: - Progress Transition View

/// Shows progress with smooth transitions
struct ProgressTransitionView: View {
    let progress: Double
    let label: String

    @State private var animatedProgress: Double = 0

    var body: some View {
        VStack(spacing: 12) {
            Text(label)
                .font(.headline)
                .foregroundStyle(.secondary)

            ProgressView(value: animatedProgress)
                .progressViewStyle(.linear)
                .frame(width: 200)

            Text("\(Int(animatedProgress * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeInOut(duration: 0.2)) {
                animatedProgress = newValue
            }
        }
        .onAppear {
            animatedProgress = progress
        }
    }
}

// MARK: - Staggered Appearance Modifier

/// Modifier for staggered appearance animations
struct StaggeredAppearance: ViewModifier {
    let index: Int
    let total: Int
    let isVisible: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var delay: Double {
        guard !reduceMotion else { return 0 }
        return Double(index) * (0.3 / Double(max(total, 1)))
    }

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 10)
            .animation(
                reduceMotion ? .none : .spring(duration: 0.4, bounce: 0.3).delay(delay),
                value: isVisible
            )
    }
}

extension View {
    func staggeredAppearance(index: Int, total: Int, isVisible: Bool) -> some View {
        modifier(StaggeredAppearance(index: index, total: total, isVisible: isVisible))
    }
}

// MARK: - Pulse Animation

/// Pulsing animation for loading states
struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.05 : 1.0)
            .opacity(isPulsing ? 0.8 : 1.0)
            .animation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

extension View {
    func pulseAnimation() -> some View {
        modifier(PulseAnimation())
    }
}

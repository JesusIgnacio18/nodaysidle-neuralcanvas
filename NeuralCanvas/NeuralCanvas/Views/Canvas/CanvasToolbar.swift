import SwiftUI

/// Toolbar for canvas tools and actions
struct CanvasToolbar: View {
    @Binding var selectedTool: CanvasTool
    @Binding var canvasState: CanvasState

    let onUndo: () -> Void
    let onRedo: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            // Tool selection
            ForEach([CanvasTool.pen, .eraser, .select, .pan]) { tool in
                ToolButton(
                    tool: tool,
                    isSelected: selectedTool == tool,
                    action: { selectedTool = tool }
                )
            }

            Divider()
                .frame(height: 24)
                .padding(.horizontal, 8)

            // Shape tools
            ForEach([CanvasTool.rectangle, .ellipse, .line]) { tool in
                ToolButton(
                    tool: tool,
                    isSelected: selectedTool == tool,
                    action: { selectedTool = tool }
                )
            }

            Divider()
                .frame(height: 24)
                .padding(.horizontal, 8)

            // Actions
            Button(action: onUndo) {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("z", modifiers: [.command])
            .help("Undo")

            Button(action: onRedo) {
                Image(systemName: "arrow.uturn.forward")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .help("Redo")

            Divider()
                .frame(height: 24)
                .padding(.horizontal, 8)

            // View controls
            Button {
                canvasState.resetViewport()
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(.borderless)
            .help("Reset View")

            Button {
                canvasState.showGrid.toggle()
            } label: {
                Image(systemName: canvasState.showGrid ? "grid" : "grid.circle")
            }
            .buttonStyle(.borderless)
            .help(canvasState.showGrid ? "Hide Grid" : "Show Grid")

            Spacer()

            // Zoom controls
            HStack(spacing: 4) {
                Button {
                    canvasState.zoom(by: 0.8, around: .zero)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .buttonStyle(.borderless)

                Text("\(Int(canvasState.scale * 100))%")
                    .font(.caption)
                    .frame(width: 50)

                Button {
                    canvasState.zoom(by: 1.25, around: .zero)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .buttonStyle(.borderless)
            }

            Divider()
                .frame(height: 24)
                .padding(.horizontal, 8)

            // Clear button
            Button(role: .destructive, action: onClear) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Clear Canvas")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }
}

// MARK: - Tool Button

struct ToolButton: View {
    let tool: CanvasTool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: tool.systemImage)
                .font(.system(size: 14))
                .frame(width: 28, height: 28)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.borderless)
        .help(tool.displayName)
    }
}

// MARK: - Color Picker Toolbar

struct ColorPickerToolbar: View {
    @Binding var strokeColor: CodableColor
    @Binding var strokeWidth: CGFloat

    private let presetColors: [CodableColor] = [
        .black,
        CodableColor(hex: "#FF3B30")!,
        CodableColor(hex: "#FF9500")!,
        CodableColor(hex: "#FFCC00")!,
        CodableColor(hex: "#34C759")!,
        CodableColor(hex: "#007AFF")!,
        CodableColor(hex: "#5856D6")!,
        CodableColor(hex: "#AF52DE")!
    ]

    var body: some View {
        HStack(spacing: 8) {
            // Preset colors
            ForEach(presetColors, id: \.hexString) { color in
                ColorSwatch(
                    color: color,
                    isSelected: strokeColor.hexString == color.hexString,
                    action: { strokeColor = color }
                )
            }

            Divider()
                .frame(height: 24)
                .padding(.horizontal, 4)

            // Stroke width
            HStack(spacing: 4) {
                Image(systemName: "lineweight")
                    .font(.caption)

                Slider(value: $strokeWidth, in: 1...20, step: 1)
                    .frame(width: 80)

                Text("\(Int(strokeWidth))px")
                    .font(.caption)
                    .frame(width: 35)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.regularMaterial)
    }
}

// MARK: - Color Swatch

struct ColorSwatch: View {
    let color: CodableColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(
                    red: color.red,
                    green: color.green,
                    blue: color.blue,
                    opacity: color.alpha
                ))
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 1)
                        .padding(1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        CanvasToolbar(
            selectedTool: .constant(.pen),
            canvasState: .constant(CanvasState()),
            onUndo: {},
            onRedo: {},
            onClear: {}
        )

        ColorPickerToolbar(
            strokeColor: .constant(.black),
            strokeWidth: .constant(2)
        )
    }
    .frame(width: 600)
}

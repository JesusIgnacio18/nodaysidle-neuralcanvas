import SwiftUI

// MARK: - Style Preview View

/// View for displaying extracted style tokens
struct StylePreviewView: View {
    let style: ExtractedStyle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Color Palette Section
                ColorPalettePreview(colors: style.colorPalette)

                Divider()

                // Typography Section
                TypographyPreview(typography: style.typography)

                Divider()

                // Spacing Section
                SpacingPreview(spacing: style.spacing)

                Divider()

                // Corner Radius Section
                CornerRadiusPreview(cornerRadii: style.cornerRadii)

                Divider()

                // Shadows Section
                ShadowsPreview(shadows: style.shadows)
            }
            .padding()
        }
    }
}

// MARK: - Color Palette Preview

struct ColorPalettePreview: View {
    let colors: ColorPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Color Palette")
                .font(.headline)

            HStack(spacing: 16) {
                StyleColorSwatch(color: colors.primary, label: "Primary")
                StyleColorSwatch(color: colors.secondary, label: "Secondary")
                StyleColorSwatch(color: colors.accent, label: "Accent")
                StyleColorSwatch(color: colors.background, label: "Background")
                StyleColorSwatch(color: colors.surface, label: "Surface")
            }
        }
    }
}

struct StyleColorSwatch: View {
    let color: CodableColor
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(
                    red: color.red,
                    green: color.green,
                    blue: color.blue,
                    opacity: color.alpha
                ))
                .frame(width: 50, height: 50)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                )

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(color.hexString)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
    }
}

// MARK: - Typography Preview

struct TypographyPreview: View {
    let typography: TypographyScale

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Typography Scale")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                TypographySample(size: typography.largeTitle, label: "Large Title")
                TypographySample(size: typography.title1, label: "Title 1")
                TypographySample(size: typography.headline, label: "Headline")
                TypographySample(size: typography.body, label: "Body")
                TypographySample(size: typography.caption1, label: "Caption")
            }
        }
    }
}

struct TypographySample: View {
    let size: CGFloat
    let label: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: size))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(Int(size))pt")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Spacing Preview

struct SpacingPreview: View {
    let spacing: SpacingSystem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spacing System")
                .font(.headline)

            Text("Base Unit: \(Int(spacing.baseUnit))pt")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(spacing.allValues, id: \.self) { value in
                    SpacingSample(size: value)
                }
            }
        }
    }
}

struct SpacingSample: View {
    let size: CGFloat

    var body: some View {
        VStack(spacing: 4) {
            Rectangle()
                .fill(Color.accentColor.opacity(0.3))
                .frame(width: max(4, size), height: max(4, size))
                .overlay(
                    Rectangle()
                        .strokeBorder(Color.accentColor, lineWidth: 1)
                )

            Text("\(Int(size))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

// MARK: - Corner Radius Preview

struct CornerRadiusPreview: View {
    let cornerRadii: CornerRadiusSet

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Corner Radii")
                .font(.headline)

            HStack(spacing: 16) {
                CornerRadiusSample(radius: cornerRadii.small, label: "Small")
                CornerRadiusSample(radius: cornerRadii.medium, label: "Medium")
                CornerRadiusSample(radius: cornerRadii.large, label: "Large")
                CornerRadiusSample(radius: min(cornerRadii.full, 24), label: "Full")
            }
        }
    }
}

struct CornerRadiusSample: View {
    let radius: CGFloat
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: radius)
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .strokeBorder(Color.primary.opacity(0.3), lineWidth: 1)
                )

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("\(Int(radius))pt")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
    }
}

// MARK: - Shadows Preview

struct ShadowsPreview: View {
    let shadows: [ShadowStyle]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shadow Styles")
                .font(.headline)

            HStack(spacing: 24) {
                ForEach(Array(shadows.enumerated()), id: \.offset) { index, shadow in
                    ShadowSample(shadow: shadow, label: "Shadow \(index + 1)")
                }
            }
        }
    }
}

struct ShadowSample: View {
    let shadow: ShadowStyle
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .frame(width: 60, height: 60)
                .shadow(
                    color: Color(
                        red: shadow.color.red,
                        green: shadow.color.green,
                        blue: shadow.color.blue,
                        opacity: shadow.color.alpha
                    ),
                    radius: shadow.blur / 2,
                    x: shadow.offsetX,
                    y: shadow.offsetY
                )

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("blur: \(Int(shadow.blur))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }
}

// MARK: - Combined Style Sheet View

/// Full-page style sheet combining import and preview
struct StyleSheetView: View {
    @State private var extractedStyle: ExtractedStyle?
    @State private var isProcessing = false
    @State private var showImport = true

    var body: some View {
        HSplitView {
            // Import panel
            StyleImportView(
                extractedStyle: $extractedStyle,
                isProcessing: $isProcessing
            )
            .frame(minWidth: 300, idealWidth: 350)

            // Preview panel
            if let style = extractedStyle {
                StylePreviewView(style: style)
                    .frame(minWidth: 400)
            } else {
                ContentUnavailableView(
                    "No Style Extracted",
                    systemImage: "paintpalette",
                    description: Text("Import a screenshot to extract design tokens")
                )
                .frame(minWidth: 400)
            }
        }
    }
}

// MARK: - Previews

#Preview("Style Preview") {
    StylePreviewView(style: .defaultStyle)
        .frame(width: 500, height: 600)
}

#Preview("Style Sheet") {
    StyleSheetView()
        .frame(width: 800, height: 600)
}

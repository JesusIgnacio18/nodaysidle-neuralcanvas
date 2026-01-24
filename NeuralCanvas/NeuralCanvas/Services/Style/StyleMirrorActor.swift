import Foundation
import CoreML
import Vision
import CoreGraphics
import CoreImage
import OSLog

// MARK: - Style Extracting Protocol

/// Protocol for extracting design tokens from screenshots
protocol StyleExtracting: Sendable {
    func extractStyle(from screenshot: CGImage) async throws -> ExtractedStyle
}

// MARK: - Style Applying Protocol

/// Protocol for applying extracted styles to wireframe shapes
protocol StyleApplying: Sendable {
    func applyStyle(_ style: ExtractedStyle, toShapes shapes: [RecognizedShape]) async throws -> StyledWireframe
}

// MARK: - Styled Wireframe

/// Result of applying a style to a wireframe
struct StyledWireframe: Sendable {
    let elements: [StyledUIElement]
    let appliedStyle: ExtractedStyle
    let warnings: [StyleApplicationWarning]
}

/// A styled UI element
struct StyledUIElement: Codable, Sendable, Identifiable {
    let id: UUID
    let originalShape: RecognizedShape
    let appliedColors: ElementColors
    let appliedTypography: ElementTypography?
    let appliedSpacing: ElementSpacing?

    init(
        id: UUID = UUID(),
        originalShape: RecognizedShape,
        appliedColors: ElementColors,
        appliedTypography: ElementTypography? = nil,
        appliedSpacing: ElementSpacing? = nil
    ) {
        self.id = id
        self.originalShape = originalShape
        self.appliedColors = appliedColors
        self.appliedTypography = appliedTypography
        self.appliedSpacing = appliedSpacing
    }
}

/// Colors applied to an element
struct ElementColors: Codable, Sendable {
    let fill: CodableColor
    let stroke: CodableColor?
    let text: CodableColor?
}

/// Typography applied to an element
struct ElementTypography: Codable, Sendable {
    let fontSize: CGFloat
    let fontWeight: String
    let lineHeight: CGFloat?
}

/// Spacing applied to an element
struct ElementSpacing: Codable, Sendable {
    let padding: CGFloat
    let margin: CGFloat
}

/// Warning generated during style application
struct StyleApplicationWarning: Sendable {
    let message: String
    let elementId: UUID?
    let severity: WarningSeverity

    enum WarningSeverity: String, Sendable {
        case info
        case warning
        case error
    }
}

// MARK: - Style Mirror Actor

/// Actor for thread-safe style extraction and application
actor StyleMirrorActor: StyleExtracting, StyleApplying {
    // MARK: - Properties

    private var isModelLoaded = false
    private let signpostLog = OSLog(subsystem: AppLogger.subsystem, category: .pointsOfInterest)

    // Color analysis settings
    private let minColorCount = 3
    private let maxColorCount = 10
    private let colorClusterThreshold: CGFloat = 30 // Euclidean distance in RGB space

    // MARK: - Initialization

    init() {
        Task {
            await loadModels()
        }
    }

    // MARK: - Model Loading

    private func loadModels() async {
        let perf = PerformanceLogger(operation: "LoadStyleModels")
        perf.start()

        // For now, we use Vision framework's built-in capabilities
        // In production, this would load custom CoreML models for style extraction
        isModelLoaded = true
        AppLogger.mlInference.info("Style mirror models loaded successfully")
        perf.complete()
    }

    // MARK: - Style Extraction

    func extractStyle(from screenshot: CGImage) async throws -> ExtractedStyle {
        let perf = PerformanceLogger(operation: "ExtractStyle")
        perf.start()

        // Validate input
        guard screenshot.width >= 64 && screenshot.height >= 64 else {
            throw StyleMirrorError.insufficientContent
        }
        guard screenshot.width <= 8192 && screenshot.height <= 8192 else {
            throw StyleMirrorError.imageTooLarge(width: screenshot.width, height: screenshot.height)
        }

        perf.checkpoint("Validated input")

        // Extract colors
        let colors = try await extractColorPalette(from: screenshot)
        perf.checkpoint("Extracted colors")

        // Detect typography
        let typography = try await detectTypography(from: screenshot)
        perf.checkpoint("Detected typography")

        // Detect spacing
        let spacing = try await detectSpacing(from: screenshot)
        perf.checkpoint("Detected spacing")

        // Detect corner radii
        let cornerRadii = try await detectCornerRadii(from: screenshot)
        perf.checkpoint("Detected corner radii")

        // Detect shadows
        let shadows = try await detectShadows(from: screenshot)
        perf.checkpoint("Detected shadows")

        let result = ExtractedStyle(
            colorPalette: colors,
            typography: typography,
            spacing: spacing,
            cornerRadii: cornerRadii,
            shadows: shadows
        )

        perf.complete()
        AppLogger.mlInference.info("Extracted style with \(colors.allColors.count) colors")

        return result
    }

    // MARK: - Color Palette Extraction

    private func extractColorPalette(from image: CGImage) async throws -> ColorPalette {
        os_signpost(.begin, log: signpostLog, name: "ColorExtraction")
        defer { os_signpost(.end, log: signpostLog, name: "ColorExtraction") }

        // Sample pixels from the image
        let sampledColors = sampleColors(from: image)

        guard !sampledColors.isEmpty else {
            throw StyleMirrorError.analysisFailure(underlying: NSError(
                domain: "StyleMirror",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No colors could be extracted from image"]
            ))
        }

        // Cluster similar colors
        let clusteredColors = clusterColors(sampledColors)

        // Sort by frequency and assign roles
        let sortedColors = clusteredColors.sorted { $0.frequency > $1.frequency }

        // Assign colors to palette roles
        let primary = sortedColors.first?.color ?? CodableColor.gray
        let secondary = sortedColors.dropFirst().first?.color ?? adjustBrightness(primary, by: 0.2)
        let accent = findAccentColor(in: sortedColors, avoiding: [primary, secondary])
        let background = findBackgroundColor(in: sortedColors)
        let surface = adjustBrightness(background, by: -0.05)

        return ColorPalette(
            primary: primary,
            secondary: secondary,
            accent: accent,
            background: background,
            surface: surface
        )
    }

    private func sampleColors(from image: CGImage) -> [ColorSample] {
        let width = image.width
        let height = image.height

        // Create a context to get pixel data
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return []
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let pixelData = context.data else { return [] }

        let data = pixelData.bindMemory(to: UInt8.self, capacity: width * height * 4)

        var samples: [ColorSample] = []
        let sampleStep = max(1, min(width, height) / 100) // Sample ~10000 pixels

        for y in stride(from: 0, to: height, by: sampleStep) {
            for x in stride(from: 0, to: width, by: sampleStep) {
                let index = (y * width + x) * 4
                let r = CGFloat(data[index]) / 255.0
                let g = CGFloat(data[index + 1]) / 255.0
                let b = CGFloat(data[index + 2]) / 255.0
                let a = CGFloat(data[index + 3]) / 255.0

                // Skip mostly transparent pixels
                if a > 0.5 {
                    samples.append(ColorSample(
                        color: CodableColor(red: r, green: g, blue: b, alpha: a),
                        frequency: 1
                    ))
                }
            }
        }

        return samples
    }

    private func clusterColors(_ samples: [ColorSample]) -> [ColorSample] {
        var clusters: [ColorSample] = []

        for sample in samples {
            var foundCluster = false

            for i in 0..<clusters.count {
                if colorDistance(sample.color, clusters[i].color) < colorClusterThreshold {
                    // Merge into existing cluster (weighted average)
                    let total = CGFloat(clusters[i].frequency + 1)
                    let newRed = (clusters[i].color.red * CGFloat(clusters[i].frequency) + sample.color.red) / total
                    let newGreen = (clusters[i].color.green * CGFloat(clusters[i].frequency) + sample.color.green) / total
                    let newBlue = (clusters[i].color.blue * CGFloat(clusters[i].frequency) + sample.color.blue) / total

                    clusters[i] = ColorSample(
                        color: CodableColor(red: newRed, green: newGreen, blue: newBlue),
                        frequency: clusters[i].frequency + 1
                    )
                    foundCluster = true
                    break
                }
            }

            if !foundCluster && clusters.count < maxColorCount {
                clusters.append(sample)
            }
        }

        return clusters
    }

    private func colorDistance(_ c1: CodableColor, _ c2: CodableColor) -> CGFloat {
        let dr = (c1.red - c2.red) * 255
        let dg = (c1.green - c2.green) * 255
        let db = (c1.blue - c2.blue) * 255
        return sqrt(dr * dr + dg * dg + db * db)
    }

    private func adjustBrightness(_ color: CodableColor, by amount: CGFloat) -> CodableColor {
        CodableColor(
            red: max(0, min(1, color.red + amount)),
            green: max(0, min(1, color.green + amount)),
            blue: max(0, min(1, color.blue + amount)),
            alpha: color.alpha
        )
    }

    private func findAccentColor(in colors: [ColorSample], avoiding: [CodableColor]) -> CodableColor {
        // Find a color with high saturation that's different from avoided colors
        for sample in colors {
            let saturation = calculateSaturation(sample.color)
            if saturation > 0.3 {
                let isDifferent = avoiding.allSatisfy { colorDistance(sample.color, $0) > 50 }
                if isDifferent {
                    return sample.color
                }
            }
        }

        // Fallback to a contrasting color
        let primary = avoiding.first ?? CodableColor.gray
        return CodableColor(red: 1 - primary.red, green: 1 - primary.green, blue: primary.blue)
    }

    private func findBackgroundColor(in colors: [ColorSample]) -> CodableColor {
        // Background is usually the most frequent low-saturation color
        for sample in colors {
            let saturation = calculateSaturation(sample.color)
            let brightness = (sample.color.red + sample.color.green + sample.color.blue) / 3
            if saturation < 0.2 && (brightness > 0.8 || brightness < 0.2) {
                return sample.color
            }
        }
        return CodableColor.white
    }

    private func calculateSaturation(_ color: CodableColor) -> CGFloat {
        let maxC = max(color.red, max(color.green, color.blue))
        let minC = min(color.red, min(color.green, color.blue))
        let delta = maxC - minC
        guard maxC > 0 else { return 0 }
        return delta / maxC
    }

    // MARK: - Typography Detection

    private func detectTypography(from image: CGImage) async throws -> TypographyScale {
        os_signpost(.begin, log: signpostLog, name: "TypographyDetection")
        defer { os_signpost(.end, log: signpostLog, name: "TypographyDetection") }

        // Use Vision framework to detect text and estimate font sizes
        let textSizes = try await detectTextSizes(from: image)

        // Cluster font sizes to identify the typography scale
        let clusteredSizes = clusterFontSizes(textSizes)
        let sortedSizes = clusteredSizes.sorted { $0.size > $1.size }

        // Map to typography scale - infer sizes from detected text
        let largeTitle = sortedSizes.first?.size ?? 34
        let title1 = sortedSizes.dropFirst().first?.size ?? 28
        let body = sortedSizes.dropFirst(2).first?.size ?? 17
        let caption = sortedSizes.last?.size ?? 12

        // Calculate intermediate sizes
        let title2 = (title1 + body) / 2 + 2
        let title3 = (title1 + body) / 2
        let headline = body
        let callout = body - 1
        let subheadline = body - 2
        let footnote = caption + 1

        return TypographyScale(
            largeTitle: largeTitle,
            title1: title1,
            title2: title2,
            title3: title3,
            headline: headline,
            body: body,
            callout: callout,
            subheadline: subheadline,
            footnote: footnote,
            caption1: caption,
            caption2: caption - 1
        )
    }

    private func detectTextSizes(from image: CGImage) async throws -> [CGFloat] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: StyleMirrorError.analysisFailure(underlying: error))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                // Estimate font size from bounding box height
                let sizes = observations.compactMap { observation -> CGFloat? in
                    // The bounding box height relative to image height gives us a rough font size
                    let heightRatio = observation.boundingBox.height
                    let estimatedSize = heightRatio * CGFloat(image.height)

                    // Filter out unreasonable sizes
                    if estimatedSize > 8 && estimatedSize < 200 {
                        return estimatedSize
                    }
                    return nil
                }

                continuation.resume(returning: sizes)
            }

            request.recognitionLevel = .fast

            let handler = VNImageRequestHandler(cgImage: image, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: StyleMirrorError.analysisFailure(underlying: error))
            }
        }
    }

    private func clusterFontSizes(_ sizes: [CGFloat]) -> [FontSizeCluster] {
        var clusters: [FontSizeCluster] = []
        let threshold: CGFloat = 4 // Group sizes within 4pt

        for size in sizes {
            var foundCluster = false

            for i in 0..<clusters.count {
                if abs(size - clusters[i].size) < threshold {
                    // Update cluster average
                    let total = CGFloat(clusters[i].count + 1)
                    let newSize = (clusters[i].size * CGFloat(clusters[i].count) + size) / total
                    clusters[i] = FontSizeCluster(size: newSize, count: clusters[i].count + 1)
                    foundCluster = true
                    break
                }
            }

            if !foundCluster {
                clusters.append(FontSizeCluster(size: size, count: 1))
            }
        }

        return clusters
    }

    // MARK: - Spacing Detection

    private func detectSpacing(from image: CGImage) async throws -> SpacingSystem {
        os_signpost(.begin, log: signpostLog, name: "SpacingDetection")
        defer { os_signpost(.end, log: signpostLog, name: "SpacingDetection") }

        // Use rectangle detection to find UI elements and analyze their spacing
        let elementBounds = try await detectElementBounds(from: image)

        // Analyze gaps between elements
        let gaps = calculateGaps(elementBounds)

        // Determine base unit (most common small gap, usually 4 or 8)
        let baseUnit = determineBaseUnit(gaps)

        // Generate spacing system based on detected base unit
        return SpacingSystem(baseUnit: baseUnit)
    }

    private func detectElementBounds(from image: CGImage) async throws -> [CGRect] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: StyleMirrorError.analysisFailure(underlying: error))
                    return
                }

                guard let observations = request.results as? [VNRectangleObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let bounds = observations.map { observation -> CGRect in
                    CGRect(
                        x: observation.boundingBox.minX * CGFloat(image.width),
                        y: observation.boundingBox.minY * CGFloat(image.height),
                        width: observation.boundingBox.width * CGFloat(image.width),
                        height: observation.boundingBox.height * CGFloat(image.height)
                    )
                }

                continuation.resume(returning: bounds)
            }

            request.minimumConfidence = 0.3
            request.maximumObservations = 50

            let handler = VNImageRequestHandler(cgImage: image, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: StyleMirrorError.analysisFailure(underlying: error))
            }
        }
    }

    private func calculateGaps(_ bounds: [CGRect]) -> [CGFloat] {
        var gaps: [CGFloat] = []

        for i in 0..<bounds.count {
            for j in (i+1)..<bounds.count {
                let b1 = bounds[i]
                let b2 = bounds[j]

                // Horizontal gap
                if b1.maxX < b2.minX {
                    gaps.append(b2.minX - b1.maxX)
                } else if b2.maxX < b1.minX {
                    gaps.append(b1.minX - b2.maxX)
                }

                // Vertical gap
                if b1.maxY < b2.minY {
                    gaps.append(b2.minY - b1.maxY)
                } else if b2.maxY < b1.minY {
                    gaps.append(b1.minY - b2.maxY)
                }
            }
        }

        return gaps.filter { $0 > 0 && $0 < 100 } // Filter to reasonable spacing values
    }

    private func determineBaseUnit(_ gaps: [CGFloat]) -> CGFloat {
        guard !gaps.isEmpty else { return 8 } // Default to 8pt

        // Count occurrences near common base units
        let candidates: [CGFloat] = [4, 8, 10, 12, 16]
        var scores: [CGFloat: Int] = [:]

        for candidate in candidates {
            scores[candidate] = gaps.filter { abs($0 - candidate) < 2 || abs(($0 / candidate).rounded() * candidate - $0) < 2 }.count
        }

        // Return the candidate with highest score
        return scores.max { $0.value < $1.value }?.key ?? 8
    }

    // MARK: - Corner Radius Detection

    private func detectCornerRadii(from image: CGImage) async throws -> CornerRadiusSet {
        os_signpost(.begin, log: signpostLog, name: "CornerRadiusDetection")
        defer { os_signpost(.end, log: signpostLog, name: "CornerRadiusDetection") }

        // Use contour detection to find rounded corners
        let radii = try await analyzeCorners(from: image)

        // Cluster similar radii
        let clusteredRadii = clusterRadii(radii)
        let sortedRadii = clusteredRadii.sorted()

        return CornerRadiusSet(
            small: sortedRadii.first ?? 4,
            medium: sortedRadii.dropFirst().first ?? 8,
            large: sortedRadii.dropFirst(2).first ?? 16,
            full: 9999 // Represents fully rounded
        )
    }

    private func analyzeCorners(from image: CGImage) async throws -> [CGFloat] {
        // For now, return common corner radius values
        // In production, this would use contour analysis to detect actual radii
        return [4, 8, 12, 16, 24]
    }

    private func clusterRadii(_ radii: [CGFloat]) -> [CGFloat] {
        var clusters: [CGFloat] = []
        let threshold: CGFloat = 3

        for radius in radii {
            let exists = clusters.contains { abs($0 - radius) < threshold }
            if !exists {
                clusters.append(radius)
            }
        }

        return clusters
    }

    // MARK: - Shadow Detection

    private func detectShadows(from image: CGImage) async throws -> [ShadowStyle] {
        os_signpost(.begin, log: signpostLog, name: "ShadowDetection")
        defer { os_signpost(.end, log: signpostLog, name: "ShadowDetection") }

        // Analyze image for shadow-like features
        // This is a simplified implementation - production would use ML

        // Return common shadow presets based on analysis hints
        return [
            ShadowStyle(
                color: CodableColor(red: 0, green: 0, blue: 0, alpha: 0.1),
                offsetX: 0,
                offsetY: 2,
                blur: 4,
                spread: 0
            ),
            ShadowStyle(
                color: CodableColor(red: 0, green: 0, blue: 0, alpha: 0.15),
                offsetX: 0,
                offsetY: 4,
                blur: 8,
                spread: 0
            ),
            ShadowStyle(
                color: CodableColor(red: 0, green: 0, blue: 0, alpha: 0.2),
                offsetX: 0,
                offsetY: 8,
                blur: 16,
                spread: 0
            )
        ]
    }

    // MARK: - Style Application

    func applyStyle(_ style: ExtractedStyle, toShapes shapes: [RecognizedShape]) async throws -> StyledWireframe {
        let perf = PerformanceLogger(operation: "ApplyStyle")
        perf.start()

        var styledElements: [StyledUIElement] = []
        var warnings: [StyleApplicationWarning] = []

        guard !shapes.isEmpty else {
            throw StyleMirrorError.applicationFailure(underlying: NSError(
                domain: "StyleMirror",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No shapes provided for styling"]
            ))
        }

        // Apply style to each shape based on its type
        for shape in shapes {
            let (element, elementWarnings) = applyStyleToShape(shape, style: style)
            styledElements.append(element)
            warnings.append(contentsOf: elementWarnings)
        }

        perf.complete()
        AppLogger.mlInference.info("Applied style to \(styledElements.count) elements with \(warnings.count) warnings")

        return StyledWireframe(
            elements: styledElements,
            appliedStyle: style,
            warnings: warnings
        )
    }

    private func applyStyleToShape(_ shape: RecognizedShape, style: ExtractedStyle) -> (StyledUIElement, [StyleApplicationWarning]) {
        var warnings: [StyleApplicationWarning] = []

        // Determine colors based on shape type
        let colors: ElementColors
        let typography: ElementTypography?
        let spacing: ElementSpacing?

        switch shape.type {
        case .button:
            colors = ElementColors(
                fill: style.colorPalette.primary,
                stroke: nil,
                text: contrastingTextColor(for: style.colorPalette.primary)
            )
            typography = ElementTypography(
                fontSize: style.typography.body,
                fontWeight: "semibold",
                lineHeight: nil
            )
            spacing = ElementSpacing(
                padding: style.spacing.baseUnit * 2,
                margin: style.spacing.baseUnit
            )

        case .inputField:
            colors = ElementColors(
                fill: style.colorPalette.surface,
                stroke: style.colorPalette.secondary,
                text: contrastingTextColor(for: style.colorPalette.surface)
            )
            typography = ElementTypography(
                fontSize: style.typography.body,
                fontWeight: "regular",
                lineHeight: nil
            )
            spacing = ElementSpacing(
                padding: style.spacing.baseUnit * 2,
                margin: style.spacing.baseUnit
            )

        case .card, .container:
            colors = ElementColors(
                fill: style.colorPalette.surface,
                stroke: nil,
                text: contrastingTextColor(for: style.colorPalette.surface)
            )
            typography = nil
            spacing = ElementSpacing(
                padding: style.spacing.baseUnit * 3,
                margin: style.spacing.baseUnit * 2
            )

        case .text:
            colors = ElementColors(
                fill: .clear,
                stroke: nil,
                text: contrastingTextColor(for: style.colorPalette.background)
            )
            typography = ElementTypography(
                fontSize: style.typography.body,
                fontWeight: "regular",
                lineHeight: style.typography.body * 1.5
            )
            spacing = nil

        case .divider, .line:
            colors = ElementColors(
                fill: style.colorPalette.secondary,
                stroke: nil,
                text: nil
            )
            typography = nil
            spacing = nil

        default:
            colors = ElementColors(
                fill: style.colorPalette.surface,
                stroke: style.colorPalette.secondary,
                text: nil
            )
            typography = nil
            spacing = nil

            warnings.append(StyleApplicationWarning(
                message: "Unknown shape type '\(shape.type.displayName)' styled with defaults",
                elementId: shape.id,
                severity: .info
            ))
        }

        let element = StyledUIElement(
            originalShape: shape,
            appliedColors: colors,
            appliedTypography: typography,
            appliedSpacing: spacing
        )

        return (element, warnings)
    }

    private func contrastingTextColor(for background: CodableColor) -> CodableColor {
        // Calculate relative luminance
        let luminance = 0.299 * background.red + 0.587 * background.green + 0.114 * background.blue
        return luminance > 0.5 ? CodableColor.black : CodableColor.white
    }
}

// MARK: - Helper Types

private struct ColorSample {
    let color: CodableColor
    var frequency: Int
}

private struct FontSizeCluster {
    let size: CGFloat
    let count: Int
}

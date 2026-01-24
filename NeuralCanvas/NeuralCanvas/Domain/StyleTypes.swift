import Foundation
import CoreGraphics

// MARK: - Color Palette

/// A collection of colors extracted from a UI screenshot or defined by a preset
struct ColorPalette: Codable, Hashable, Sendable {
    let primary: CodableColor
    let secondary: CodableColor
    let accent: CodableColor
    let background: CodableColor
    let surface: CodableColor
    let onPrimary: CodableColor
    let onSecondary: CodableColor
    let onBackground: CodableColor
    let onSurface: CodableColor

    init(
        primary: CodableColor,
        secondary: CodableColor,
        accent: CodableColor,
        background: CodableColor,
        surface: CodableColor,
        onPrimary: CodableColor = .white,
        onSecondary: CodableColor = .white,
        onBackground: CodableColor = .black,
        onSurface: CodableColor = .black
    ) {
        self.primary = primary
        self.secondary = secondary
        self.accent = accent
        self.background = background
        self.surface = surface
        self.onPrimary = onPrimary
        self.onSecondary = onSecondary
        self.onBackground = onBackground
        self.onSurface = onSurface
    }

    /// Returns all colors as an array
    var allColors: [CodableColor] {
        [primary, secondary, accent, background, surface, onPrimary, onSecondary, onBackground, onSurface]
    }

    /// Default light theme palette
    static let defaultLight = ColorPalette(
        primary: CodableColor(hex: "#007AFF")!,
        secondary: CodableColor(hex: "#5856D6")!,
        accent: CodableColor(hex: "#FF9500")!,
        background: CodableColor(hex: "#FFFFFF")!,
        surface: CodableColor(hex: "#F2F2F7")!,
        onPrimary: .white,
        onSecondary: .white,
        onBackground: .black,
        onSurface: .black
    )

    /// Default dark theme palette
    static let defaultDark = ColorPalette(
        primary: CodableColor(hex: "#0A84FF")!,
        secondary: CodableColor(hex: "#5E5CE6")!,
        accent: CodableColor(hex: "#FF9F0A")!,
        background: CodableColor(hex: "#000000")!,
        surface: CodableColor(hex: "#1C1C1E")!,
        onPrimary: .white,
        onSecondary: .white,
        onBackground: .white,
        onSurface: .white
    )

    /// Encodes palette to Data
    func encode() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Decodes palette from Data
    static func decode(from data: Data) throws -> ColorPalette {
        try JSONDecoder().decode(ColorPalette.self, from: data)
    }
}

// MARK: - Typography Scale

/// Typography size scale for consistent text hierarchy
struct TypographyScale: Codable, Hashable, Sendable {
    let largeTitle: CGFloat
    let title1: CGFloat
    let title2: CGFloat
    let title3: CGFloat
    let headline: CGFloat
    let body: CGFloat
    let callout: CGFloat
    let subheadline: CGFloat
    let footnote: CGFloat
    let caption1: CGFloat
    let caption2: CGFloat

    init(
        largeTitle: CGFloat = 34,
        title1: CGFloat = 28,
        title2: CGFloat = 22,
        title3: CGFloat = 20,
        headline: CGFloat = 17,
        body: CGFloat = 17,
        callout: CGFloat = 16,
        subheadline: CGFloat = 15,
        footnote: CGFloat = 13,
        caption1: CGFloat = 12,
        caption2: CGFloat = 11
    ) {
        self.largeTitle = largeTitle
        self.title1 = title1
        self.title2 = title2
        self.title3 = title3
        self.headline = headline
        self.body = body
        self.callout = callout
        self.subheadline = subheadline
        self.footnote = footnote
        self.caption1 = caption1
        self.caption2 = caption2
    }

    /// Default macOS typography scale
    static let macOSDefault = TypographyScale()

    /// Compact scale for dense UIs
    static let compact = TypographyScale(
        largeTitle: 28,
        title1: 24,
        title2: 20,
        title3: 18,
        headline: 15,
        body: 14,
        callout: 13,
        subheadline: 12,
        footnote: 11,
        caption1: 10,
        caption2: 9
    )

    /// Returns all sizes as a sorted array (largest to smallest)
    var allSizes: [CGFloat] {
        [largeTitle, title1, title2, title3, headline, body, callout, subheadline, footnote, caption1, caption2]
    }

    /// Encodes scale to Data
    func encode() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Decodes scale from Data
    static func decode(from data: Data) throws -> TypographyScale {
        try JSONDecoder().decode(TypographyScale.self, from: data)
    }
}

// MARK: - Spacing System

/// A spacing system based on a base unit and multipliers
struct SpacingSystem: Codable, Hashable, Sendable {
    let baseUnit: CGFloat
    let xxs: CGFloat
    let xs: CGFloat
    let sm: CGFloat
    let md: CGFloat
    let lg: CGFloat
    let xl: CGFloat
    let xxl: CGFloat

    init(baseUnit: CGFloat = 4) {
        self.baseUnit = baseUnit
        self.xxs = baseUnit * 0.5    // 2
        self.xs = baseUnit           // 4
        self.sm = baseUnit * 2       // 8
        self.md = baseUnit * 4       // 16
        self.lg = baseUnit * 6       // 24
        self.xl = baseUnit * 8       // 32
        self.xxl = baseUnit * 12     // 48
    }

    init(
        baseUnit: CGFloat,
        xxs: CGFloat,
        xs: CGFloat,
        sm: CGFloat,
        md: CGFloat,
        lg: CGFloat,
        xl: CGFloat,
        xxl: CGFloat
    ) {
        self.baseUnit = baseUnit
        self.xxs = xxs
        self.xs = xs
        self.sm = sm
        self.md = md
        self.lg = lg
        self.xl = xl
        self.xxl = xxl
    }

    /// Standard 4pt grid system
    static let standard4pt = SpacingSystem(baseUnit: 4)

    /// 8pt grid system
    static let standard8pt = SpacingSystem(baseUnit: 8)

    /// Returns all spacing values as sorted array
    var allValues: [CGFloat] {
        [xxs, xs, sm, md, lg, xl, xxl].sorted()
    }

    /// Encodes spacing to Data
    func encode() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Decodes spacing from Data
    static func decode(from data: Data) throws -> SpacingSystem {
        try JSONDecoder().decode(SpacingSystem.self, from: data)
    }
}

// MARK: - Shadow Style

/// A shadow configuration for UI elements
struct ShadowStyle: Codable, Hashable, Sendable {
    let color: CodableColor
    let offsetX: CGFloat
    let offsetY: CGFloat
    let blur: CGFloat
    let spread: CGFloat

    init(
        color: CodableColor = CodableColor(red: 0, green: 0, blue: 0, alpha: 0.15),
        offsetX: CGFloat = 0,
        offsetY: CGFloat = 2,
        blur: CGFloat = 4,
        spread: CGFloat = 0
    ) {
        self.color = color
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.blur = blur
        self.spread = spread
    }

    /// No shadow
    static let none = ShadowStyle(color: .clear, offsetX: 0, offsetY: 0, blur: 0, spread: 0)

    /// Subtle elevation shadow
    static let subtle = ShadowStyle(
        color: CodableColor(red: 0, green: 0, blue: 0, alpha: 0.08),
        offsetX: 0,
        offsetY: 1,
        blur: 2,
        spread: 0
    )

    /// Medium elevation shadow
    static let medium = ShadowStyle(
        color: CodableColor(red: 0, green: 0, blue: 0, alpha: 0.12),
        offsetX: 0,
        offsetY: 2,
        blur: 8,
        spread: 0
    )

    /// Large elevation shadow
    static let large = ShadowStyle(
        color: CodableColor(red: 0, green: 0, blue: 0, alpha: 0.16),
        offsetX: 0,
        offsetY: 4,
        blur: 16,
        spread: 0
    )
}

// MARK: - Corner Radius Set

/// Corner radius values for different element types
struct CornerRadiusSet: Codable, Hashable, Sendable {
    let none: CGFloat
    let small: CGFloat
    let medium: CGFloat
    let large: CGFloat
    let full: CGFloat

    init(
        none: CGFloat = 0,
        small: CGFloat = 4,
        medium: CGFloat = 8,
        large: CGFloat = 12,
        full: CGFloat = 9999
    ) {
        self.none = none
        self.small = small
        self.medium = medium
        self.large = large
        self.full = full
    }

    /// Standard corner radius set
    static let standard = CornerRadiusSet()

    /// Rounded style with larger radii
    static let rounded = CornerRadiusSet(
        none: 0,
        small: 8,
        medium: 12,
        large: 16,
        full: 9999
    )

    /// Sharp style with minimal radii
    static let sharp = CornerRadiusSet(
        none: 0,
        small: 2,
        medium: 4,
        large: 6,
        full: 9999
    )
}

// MARK: - Extracted Style

/// Complete style tokens extracted from a UI screenshot
struct ExtractedStyle: Codable, Sendable {
    let colorPalette: ColorPalette
    let typography: TypographyScale
    let spacing: SpacingSystem
    let cornerRadii: CornerRadiusSet
    let shadows: [ShadowStyle]
    let extractedAt: Date
    let sourceImageSize: CodableRect?
    let confidence: Double

    init(
        colorPalette: ColorPalette,
        typography: TypographyScale,
        spacing: SpacingSystem,
        cornerRadii: CornerRadiusSet,
        shadows: [ShadowStyle],
        extractedAt: Date = Date(),
        sourceImageSize: CGRect? = nil,
        confidence: Double = 1.0
    ) {
        self.colorPalette = colorPalette
        self.typography = typography
        self.spacing = spacing
        self.cornerRadii = cornerRadii
        self.shadows = shadows
        self.extractedAt = extractedAt
        self.sourceImageSize = sourceImageSize.map { CodableRect($0) }
        self.confidence = confidence
    }

    /// Default style with standard values
    static let defaultStyle = ExtractedStyle(
        colorPalette: .defaultLight,
        typography: .macOSDefault,
        spacing: .standard4pt,
        cornerRadii: .standard,
        shadows: [.subtle, .medium, .large]
    )

    /// Encodes style to Data
    func encode() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Decodes style from Data
    static func decode(from data: Data) throws -> ExtractedStyle {
        try JSONDecoder().decode(ExtractedStyle.self, from: data)
    }
}

// MARK: - Style Preset Reference

/// Lightweight reference to a StylePreset for storing in Wireframe
struct StylePresetReference: Codable, Hashable, Sendable {
    let presetId: UUID
    let presetName: String
    let appliedAt: Date

    init(presetId: UUID, presetName: String, appliedAt: Date = Date()) {
        self.presetId = presetId
        self.presetName = presetName
        self.appliedAt = appliedAt
    }
}

// MARK: - Style Application Result

/// Result of applying a style to a wireframe
struct StyleApplicationResult: Sendable {
    let success: Bool
    let warnings: [String]
    let appliedElements: Int
    let skippedElements: Int

    init(
        success: Bool,
        warnings: [String] = [],
        appliedElements: Int = 0,
        skippedElements: Int = 0
    ) {
        self.success = success
        self.warnings = warnings
        self.appliedElements = appliedElements
        self.skippedElements = skippedElements
    }

    /// Fully successful application
    static func successful(appliedElements: Int) -> StyleApplicationResult {
        StyleApplicationResult(success: true, appliedElements: appliedElements)
    }

    /// Partial application with warnings
    static func partial(
        appliedElements: Int,
        skippedElements: Int,
        warnings: [String]
    ) -> StyleApplicationResult {
        StyleApplicationResult(
            success: true,
            warnings: warnings,
            appliedElements: appliedElements,
            skippedElements: skippedElements
        )
    }

    /// Failed application
    static func failed(reason: String) -> StyleApplicationResult {
        StyleApplicationResult(success: false, warnings: [reason])
    }
}

import Foundation
import SwiftData

/// A saved style preset containing extracted design tokens
@Model
final class StylePreset {
    // MARK: - Properties

    /// Unique identifier
    var id: UUID

    /// User-provided name for the preset
    var name: String

    /// Serialized ColorPalette as JSON Data
    var colorPaletteData: Data

    /// Serialized TypographyScale as JSON Data
    var typographyData: Data

    /// Serialized SpacingSystem as JSON Data
    var spacingData: Data

    /// Serialized CornerRadiusSet as JSON Data
    var cornerRadiusData: Data

    /// Serialized shadow styles as JSON Data
    var shadowsData: Data

    /// Thumbnail image data for preview (PNG)
    var thumbnailData: Data?

    /// Whether this is a built-in preset (not user-created)
    var isBuiltIn: Bool

    /// When the preset was created
    var createdAt: Date

    /// When the preset was last modified
    var modifiedAt: Date

    /// Optional description of the style
    var styleDescription: String?

    // MARK: - Relationships

    /// The library this preset belongs to
    var library: StyleLibrary?

    // MARK: - Computed Properties

    /// Decodes the color palette
    func getColorPalette() throws -> ColorPalette {
        try ColorPalette.decode(from: colorPaletteData)
    }

    /// Decodes the typography scale
    func getTypography() throws -> TypographyScale {
        try TypographyScale.decode(from: typographyData)
    }

    /// Decodes the spacing system
    func getSpacing() throws -> SpacingSystem {
        try SpacingSystem.decode(from: spacingData)
    }

    /// Decodes the corner radius set
    func getCornerRadii() throws -> CornerRadiusSet {
        try JSONDecoder().decode(CornerRadiusSet.self, from: cornerRadiusData)
    }

    /// Decodes the shadow styles
    func getShadows() throws -> [ShadowStyle] {
        try JSONDecoder().decode([ShadowStyle].self, from: shadowsData)
    }

    /// Creates a full ExtractedStyle from this preset
    func getExtractedStyle() throws -> ExtractedStyle {
        ExtractedStyle(
            colorPalette: try getColorPalette(),
            typography: try getTypography(),
            spacing: try getSpacing(),
            cornerRadii: try getCornerRadii(),
            shadows: try getShadows(),
            extractedAt: createdAt
        )
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        colorPaletteData: Data = Data(),
        typographyData: Data = Data(),
        spacingData: Data = Data(),
        cornerRadiusData: Data = Data(),
        shadowsData: Data = Data(),
        thumbnailData: Data? = nil,
        isBuiltIn: Bool = false,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        styleDescription: String? = nil,
        library: StyleLibrary? = nil
    ) {
        self.id = id
        self.name = name
        self.colorPaletteData = colorPaletteData
        self.typographyData = typographyData
        self.spacingData = spacingData
        self.cornerRadiusData = cornerRadiusData
        self.shadowsData = shadowsData
        self.thumbnailData = thumbnailData
        self.isBuiltIn = isBuiltIn
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.styleDescription = styleDescription
        self.library = library
    }

    // MARK: - Methods

    /// Updates the modification timestamp
    func touch() {
        modifiedAt = Date()
    }

    /// Sets the style data from an ExtractedStyle
    func setStyle(_ style: ExtractedStyle) throws {
        colorPaletteData = try style.colorPalette.encode()
        typographyData = try style.typography.encode()
        spacingData = try style.spacing.encode()
        cornerRadiusData = try JSONEncoder().encode(style.cornerRadii)
        shadowsData = try JSONEncoder().encode(style.shadows)
        touch()
    }

    /// Updates the thumbnail
    func setThumbnail(_ data: Data?) {
        thumbnailData = data
        touch()
    }
}

// MARK: - Convenience Initializers

extension StylePreset {
    /// Creates a preset from an ExtractedStyle
    static func fromExtractedStyle(
        _ style: ExtractedStyle,
        name: String,
        thumbnail: Data? = nil,
        library: StyleLibrary? = nil
    ) throws -> StylePreset {
        let preset = StylePreset(
            name: name,
            thumbnailData: thumbnail,
            library: library
        )
        try preset.setStyle(style)
        return preset
    }

    /// Creates a built-in default light preset
    static func defaultLight(library: StyleLibrary? = nil) throws -> StylePreset {
        try fromExtractedStyle(
            ExtractedStyle(
                colorPalette: .defaultLight,
                typography: .macOSDefault,
                spacing: .standard4pt,
                cornerRadii: .standard,
                shadows: [.subtle, .medium, .large]
            ),
            name: "Default Light",
            library: library
        )
    }

    /// Creates a built-in default dark preset
    static func defaultDark(library: StyleLibrary? = nil) throws -> StylePreset {
        try fromExtractedStyle(
            ExtractedStyle(
                colorPalette: .defaultDark,
                typography: .macOSDefault,
                spacing: .standard4pt,
                cornerRadii: .standard,
                shadows: [.subtle, .medium, .large]
            ),
            name: "Default Dark",
            library: library
        )
    }
}

// MARK: - Identifiable Conformance

extension StylePreset: Identifiable {}

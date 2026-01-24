import Foundation
import SwiftData

/// A collection of style presets, optionally synced via CloudKit
@Model
final class StyleLibrary {
    // MARK: - Properties

    /// Unique identifier
    var id: UUID

    /// User-provided name for the library
    var name: String

    /// Whether CloudKit sync is enabled for this library
    var isSyncEnabled: Bool

    /// When the library was created
    var createdAt: Date

    /// When the library was last modified
    var modifiedAt: Date

    /// Optional description of the library
    var libraryDescription: String?

    // MARK: - Relationships

    /// Style presets in this library
    @Relationship(deleteRule: .cascade, inverse: \StylePreset.library)
    var presets: [StylePreset]

    // MARK: - Computed Properties

    /// Number of presets in the library
    var presetCount: Int {
        presets.count
    }

    /// Built-in presets (not user-created)
    var builtInPresets: [StylePreset] {
        presets.filter(\.isBuiltIn)
    }

    /// User-created presets
    var userPresets: [StylePreset] {
        presets.filter { !$0.isBuiltIn }
    }

    /// Most recently modified preset
    var latestPreset: StylePreset? {
        presets.sorted { $0.modifiedAt > $1.modifiedAt }.first
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        isSyncEnabled: Bool = false,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        libraryDescription: String? = nil,
        presets: [StylePreset] = []
    ) {
        self.id = id
        self.name = name
        self.isSyncEnabled = isSyncEnabled
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.libraryDescription = libraryDescription
        self.presets = presets
    }

    // MARK: - Methods

    /// Updates the modification timestamp
    func touch() {
        modifiedAt = Date()
    }

    /// Adds a preset to the library
    func addPreset(_ preset: StylePreset) {
        presets.append(preset)
        touch()
    }

    /// Removes a preset from the library
    func removePreset(_ preset: StylePreset) {
        presets.removeAll { $0.id == preset.id }
        touch()
    }

    /// Finds a preset by ID
    func preset(withId id: UUID) -> StylePreset? {
        presets.first { $0.id == id }
    }

    /// Finds presets matching a search query
    func search(query: String) -> [StylePreset] {
        let lowercased = query.lowercased()
        return presets.filter {
            $0.name.lowercased().contains(lowercased) ||
            ($0.styleDescription?.lowercased().contains(lowercased) ?? false)
        }
    }
}

// MARK: - Convenience Initializers

extension StyleLibrary {
    /// Creates a new library with default presets
    static func withDefaults(name: String = "My Styles") throws -> StyleLibrary {
        let library = StyleLibrary(name: name)
        let lightPreset = try StylePreset.defaultLight(library: library)
        let darkPreset = try StylePreset.defaultDark(library: library)
        library.presets = [lightPreset, darkPreset]
        return library
    }

    /// Creates an empty library
    static func empty(name: String = "My Styles") -> StyleLibrary {
        StyleLibrary(name: name)
    }
}

// MARK: - Identifiable Conformance

extension StyleLibrary: Identifiable {}

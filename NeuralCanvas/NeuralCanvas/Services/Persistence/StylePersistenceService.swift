import Foundation
import SwiftData

// MARK: - Style Persisting Protocol

/// Protocol defining style preset and library persistence operations
/// Note: MainActor-isolated because SwiftData @Model classes aren't Sendable
@MainActor
protocol StylePersisting {
    /// Saves a style preset
    func save(_ preset: StylePreset) async throws

    /// Saves a style library
    func save(_ library: StyleLibrary) async throws

    /// Fetches all style libraries
    func fetchAllLibraries() async throws -> [StyleLibrary]

    /// Fetches all presets (across all libraries)
    func fetchAllPresets() async throws -> [StylePreset]

    /// Fetches presets in a specific library
    func fetchPresets(in library: StyleLibrary) async throws -> [StylePreset]

    /// Fetches a preset by ID
    func fetchPreset(byId id: UUID) async throws -> StylePreset?

    /// Fetches a library by ID
    func fetchLibrary(byId id: UUID) async throws -> StyleLibrary?

    /// Deletes a preset
    func delete(_ preset: StylePreset) async throws

    /// Deletes a library (cascades to presets)
    func delete(_ library: StyleLibrary) async throws

    /// Creates a preset from an extracted style
    func createPreset(
        from style: ExtractedStyle,
        name: String,
        thumbnail: Data?,
        in library: StyleLibrary
    ) async throws -> StylePreset

    /// Creates a new library
    func createLibrary(name: String, withDefaults: Bool) async throws -> StyleLibrary
}

// MARK: - Style Persistence Service

/// Service for managing style preset and library persistence
@MainActor
final class StylePersistenceService: StylePersisting {
    // MARK: - Properties

    private let modelContainer: ModelContainer

    private var mainContext: ModelContext {
        modelContainer.mainContext
    }

    // MARK: - Initialization

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        AppLogger.persistence.debug("StylePersistenceService initialized")
    }

    // MARK: - StylePersisting Implementation

    func save(_ preset: StylePreset) async throws {
        do {
            preset.touch()
            mainContext.insert(preset)
            try mainContext.save()
            AppLogger.persistence.info("Saved style preset: \(preset.name)")
        } catch {
            AppLogger.persistence.error("Failed to save preset: \(error.localizedDescription)")
            throw PersistenceError.saveFailed(underlying: error)
        }
    }

    func save(_ library: StyleLibrary) async throws {
        do {
            library.touch()
            mainContext.insert(library)
            try mainContext.save()
            AppLogger.persistence.info("Saved style library: \(library.name)")
        } catch {
            AppLogger.persistence.error("Failed to save library: \(error.localizedDescription)")
            throw PersistenceError.saveFailed(underlying: error)
        }
    }

    func fetchAllLibraries() async throws -> [StyleLibrary] {
        do {
            var descriptor = FetchDescriptor<StyleLibrary>(
                sortBy: [SortDescriptor(\.name)]
            )
            descriptor.includePendingChanges = true

            let libraries = try mainContext.fetch(descriptor)
            AppLogger.persistence.debug("Fetched \(libraries.count) style libraries")
            return libraries
        } catch {
            AppLogger.persistence.error("Failed to fetch libraries: \(error.localizedDescription)")
            throw PersistenceError.fetchFailed(underlying: error)
        }
    }

    func fetchAllPresets() async throws -> [StylePreset] {
        do {
            var descriptor = FetchDescriptor<StylePreset>(
                sortBy: [SortDescriptor(\.name)]
            )
            descriptor.includePendingChanges = true

            let presets = try mainContext.fetch(descriptor)
            AppLogger.persistence.debug("Fetched \(presets.count) style presets")
            return presets
        } catch {
            AppLogger.persistence.error("Failed to fetch presets: \(error.localizedDescription)")
            throw PersistenceError.fetchFailed(underlying: error)
        }
    }

    func fetchPresets(in library: StyleLibrary) async throws -> [StylePreset] {
        let libraryId = library.id
        let predicate = #Predicate<StylePreset> { preset in
            preset.library?.id == libraryId
        }

        do {
            var descriptor = FetchDescriptor<StylePreset>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.name)]
            )
            descriptor.includePendingChanges = true

            let presets = try mainContext.fetch(descriptor)
            AppLogger.persistence.debug("Fetched \(presets.count) presets for library: \(library.name)")
            return presets
        } catch {
            AppLogger.persistence.error("Failed to fetch presets for library: \(error.localizedDescription)")
            throw PersistenceError.fetchFailed(underlying: error)
        }
    }

    func fetchPreset(byId id: UUID) async throws -> StylePreset? {
        let predicate = #Predicate<StylePreset> { preset in
            preset.id == id
        }

        do {
            let descriptor = FetchDescriptor<StylePreset>(predicate: predicate)
            return try mainContext.fetch(descriptor).first
        } catch {
            AppLogger.persistence.error("Failed to fetch preset by ID: \(error.localizedDescription)")
            throw PersistenceError.fetchFailed(underlying: error)
        }
    }

    func fetchLibrary(byId id: UUID) async throws -> StyleLibrary? {
        let predicate = #Predicate<StyleLibrary> { library in
            library.id == id
        }

        do {
            let descriptor = FetchDescriptor<StyleLibrary>(predicate: predicate)
            return try mainContext.fetch(descriptor).first
        } catch {
            AppLogger.persistence.error("Failed to fetch library by ID: \(error.localizedDescription)")
            throw PersistenceError.fetchFailed(underlying: error)
        }
    }

    func delete(_ preset: StylePreset) async throws {
        do {
            mainContext.delete(preset)
            try mainContext.save()
            AppLogger.persistence.info("Deleted style preset: \(preset.name)")
        } catch {
            AppLogger.persistence.error("Failed to delete preset: \(error.localizedDescription)")
            throw PersistenceError.deleteFailed(underlying: error)
        }
    }

    func delete(_ library: StyleLibrary) async throws {
        do {
            mainContext.delete(library)
            try mainContext.save()
            AppLogger.persistence.info("Deleted style library: \(library.name)")
        } catch {
            AppLogger.persistence.error("Failed to delete library: \(error.localizedDescription)")
            throw PersistenceError.deleteFailed(underlying: error)
        }
    }

    func createPreset(
        from style: ExtractedStyle,
        name: String,
        thumbnail: Data?,
        in library: StyleLibrary
    ) async throws -> StylePreset {
        do {
            let preset = try StylePreset.fromExtractedStyle(
                style,
                name: name,
                thumbnail: thumbnail,
                library: library
            )
            library.addPreset(preset)
            mainContext.insert(preset)
            try mainContext.save()

            AppLogger.persistence.info("Created style preset: \(name) in library: \(library.name)")
            return preset
        } catch {
            AppLogger.persistence.error("Failed to create preset: \(error.localizedDescription)")
            throw PersistenceError.saveFailed(underlying: error)
        }
    }

    func createLibrary(name: String, withDefaults: Bool = false) async throws -> StyleLibrary {
        do {
            let library: StyleLibrary
            if withDefaults {
                library = try StyleLibrary.withDefaults(name: name)
            } else {
                library = StyleLibrary.empty(name: name)
            }

            mainContext.insert(library)
            try mainContext.save()

            AppLogger.persistence.info("Created style library: \(name) (withDefaults: \(withDefaults))")
            return library
        } catch {
            AppLogger.persistence.error("Failed to create library: \(error.localizedDescription)")
            throw PersistenceError.saveFailed(underlying: error)
        }
    }
}

// MARK: - Search and Filter Extension

extension StylePersistenceService {
    /// Searches presets by name
    func searchPresets(query: String) async throws -> [StylePreset] {
        let lowercasedQuery = query.lowercased()
        let predicate = #Predicate<StylePreset> { preset in
            preset.name.localizedStandardContains(lowercasedQuery)
        }

        do {
            let descriptor = FetchDescriptor<StylePreset>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.name)]
            )
            return try mainContext.fetch(descriptor)
        } catch {
            throw PersistenceError.fetchFailed(underlying: error)
        }
    }

    /// Fetches only built-in presets
    func fetchBuiltInPresets() async throws -> [StylePreset] {
        let predicate = #Predicate<StylePreset> { preset in
            preset.isBuiltIn == true
        }

        do {
            let descriptor = FetchDescriptor<StylePreset>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.name)]
            )
            return try mainContext.fetch(descriptor)
        } catch {
            throw PersistenceError.fetchFailed(underlying: error)
        }
    }

    /// Fetches only user-created presets
    func fetchUserPresets() async throws -> [StylePreset] {
        let predicate = #Predicate<StylePreset> { preset in
            preset.isBuiltIn == false
        }

        do {
            let descriptor = FetchDescriptor<StylePreset>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
            )
            return try mainContext.fetch(descriptor)
        } catch {
            throw PersistenceError.fetchFailed(underlying: error)
        }
    }
}

// MARK: - Thumbnail Management

extension StylePersistenceService {
    /// Updates the thumbnail for a preset
    func updateThumbnail(_ thumbnailData: Data?, for preset: StylePreset) async throws {
        preset.setThumbnail(thumbnailData)

        do {
            try mainContext.save()
            AppLogger.persistence.info("Updated thumbnail for preset: \(preset.name)")
        } catch {
            throw PersistenceError.saveFailed(underlying: error)
        }
    }

    /// Clears thumbnails for all presets (memory optimization)
    func clearAllThumbnails() async throws {
        let presets = try await fetchAllPresets()
        for preset in presets {
            preset.thumbnailData = nil
        }

        do {
            try mainContext.save()
            AppLogger.persistence.info("Cleared thumbnails for \(presets.count) presets")
        } catch {
            throw PersistenceError.saveFailed(underlying: error)
        }
    }
}

// MARK: - Default Library Management

extension StylePersistenceService {
    /// Ensures a default library exists, creating one if needed
    func ensureDefaultLibrary() async throws -> StyleLibrary {
        let libraries = try await fetchAllLibraries()

        if let defaultLibrary = libraries.first {
            return defaultLibrary
        }

        // Create default library with built-in presets
        return try await createLibrary(name: "My Styles", withDefaults: true)
    }

    /// Initializes the style system with default content
    func initializeDefaults() async throws {
        let libraries = try await fetchAllLibraries()

        if libraries.isEmpty {
            _ = try await createLibrary(name: "My Styles", withDefaults: true)
            AppLogger.persistence.info("Initialized default style library")
        }
    }
}

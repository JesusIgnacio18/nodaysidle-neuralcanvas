import Foundation
import SwiftData

// MARK: - Persistence Manager

/// Centralized manager for all persistence operations
@MainActor
@Observable
final class PersistenceManager {
    // MARK: - Singleton

    /// Shared instance for app-wide persistence
    static var shared: PersistenceManager!

    // MARK: - Services

    private(set) var projectService: ProjectPersistenceService
    private(set) var sketchService: SketchPersistenceService
    private(set) var styleService: StylePersistenceService
    private(set) var cloudKitService: CloudKitSyncService

    // MARK: - Properties

    private let modelContainer: ModelContainer
    private(set) var isInitialized = false
    private(set) var lastError: PersistenceError?

    /// Observable flag for pending changes
    private(set) var hasPendingChanges = false

    // MARK: - Initialization

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.projectService = ProjectPersistenceService(modelContainer: modelContainer)
        self.sketchService = SketchPersistenceService(modelContainer: modelContainer)
        self.styleService = StylePersistenceService(modelContainer: modelContainer)
        self.cloudKitService = CloudKitSyncService(modelContainer: modelContainer)

        AppLogger.persistence.info("PersistenceManager initialized")
    }

    /// Configures the shared instance
    static func configure(with modelContainer: ModelContainer) {
        shared = PersistenceManager(modelContainer: modelContainer)
    }

    // MARK: - Lifecycle

    /// Initializes the persistence layer with default data
    func initialize() async {
        guard !isInitialized else { return }

        do {
            // Ensure default style library exists
            try await styleService.initializeDefaults()

            // Validate data integrity
            let mainContext = modelContainer.mainContext
            let isValid = try DataIntegrityValidator.validateAll(in: mainContext)

            if !isValid {
                AppLogger.persistence.warning("Data integrity issues detected during initialization")
            }

            isInitialized = true
            AppLogger.persistence.info("PersistenceManager initialization complete")

        } catch {
            lastError = error as? PersistenceError ?? .saveFailed(underlying: error)
            AppLogger.persistence.error("PersistenceManager initialization failed: \(error.localizedDescription)")
        }
    }

    /// Saves all pending changes
    func saveAllChanges() async throws {
        do {
            try modelContainer.mainContext.save()
            hasPendingChanges = false
            AppLogger.persistence.debug("All changes saved")
        } catch {
            lastError = .saveFailed(underlying: error)
            throw lastError!
        }
    }

    /// Marks that there are pending changes
    func markPendingChanges() {
        hasPendingChanges = true
    }

    // MARK: - Convenience Methods

    /// Creates a new project with an initial sketch
    func createProjectWithSketch(name: String) async throws -> (Project, Sketch) {
        let project = try await projectService.createProject(name: name)
        let sketch = try await sketchService.createSketch(in: project)
        return (project, sketch)
    }

    /// Duplicates a project with all its contents
    func duplicateProject(_ project: Project, newName: String? = nil) async throws -> Project {
        let duplicateName = newName ?? "\(project.name) Copy"
        let newProject = try await projectService.createProject(name: duplicateName)

        // Duplicate sketches
        for sketch in project.sketches {
            let newSketch = try await sketchService.createSketch(in: newProject, name: sketch.name)
            if let canvasData = try? sketch.getCanvasData() {
                try await sketchService.updateCanvasData(canvasData, for: newSketch)
            }
        }

        return newProject
    }

    /// Exports a style preset to another library
    func movePreset(_ preset: StylePreset, to library: StyleLibrary) async throws {
        let oldLibrary = preset.library
        oldLibrary?.removePreset(preset)
        library.addPreset(preset)
        try await saveAllChanges()
    }

    // MARK: - Cleanup

    /// Removes all data (for testing or reset)
    func deleteAllData() async throws {
        let mainContext = modelContainer.mainContext

        try mainContext.delete(model: Project.self)
        try mainContext.delete(model: Sketch.self)
        try mainContext.delete(model: Wireframe.self)
        try mainContext.delete(model: StylePreset.self)
        try mainContext.delete(model: StyleLibrary.self)

        try mainContext.save()

        AppLogger.persistence.warning("All data deleted")
    }

    /// Compacts the database (removes deleted records)
    func compactDatabase() async throws {
        // SwiftData handles compaction automatically
        // This is a placeholder for any manual optimization if needed
        try await saveAllChanges()
        AppLogger.persistence.info("Database compacted")
    }
}

// MARK: - Auto-Save Support

extension PersistenceManager {
    /// Starts auto-save timer
    func startAutoSave(interval: TimeInterval = 30) -> Task<Void, Never> {
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))

                if let self = self, self.hasPendingChanges {
                    do {
                        try await self.saveAllChanges()
                        AppLogger.persistence.debug("Auto-save completed")
                    } catch {
                        AppLogger.persistence.error("Auto-save failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

// MARK: - Statistics

extension PersistenceManager {
    /// Returns storage statistics
    func getStorageStatistics() async throws -> StorageStatistics {
        let mainContext = modelContainer.mainContext

        let projectCount = try mainContext.fetchCount(FetchDescriptor<Project>())
        let sketchCount = try mainContext.fetchCount(FetchDescriptor<Sketch>())
        let wireframeCount = try mainContext.fetchCount(FetchDescriptor<Wireframe>())
        let presetCount = try mainContext.fetchCount(FetchDescriptor<StylePreset>())
        let libraryCount = try mainContext.fetchCount(FetchDescriptor<StyleLibrary>())

        // Calculate total canvas data size
        let sketches = try mainContext.fetch(FetchDescriptor<Sketch>())
        let totalCanvasSize = sketches.reduce(0) { $0 + $1.canvasData.count }

        // Calculate total thumbnail size
        let presets = try mainContext.fetch(FetchDescriptor<StylePreset>())
        let totalThumbnailSize = presets.reduce(0) { $0 + ($1.thumbnailData?.count ?? 0) }

        return StorageStatistics(
            projectCount: projectCount,
            sketchCount: sketchCount,
            wireframeCount: wireframeCount,
            presetCount: presetCount,
            libraryCount: libraryCount,
            totalCanvasDataBytes: totalCanvasSize,
            totalThumbnailBytes: totalThumbnailSize
        )
    }
}

// MARK: - Storage Statistics

/// Statistics about stored data
struct StorageStatistics: Sendable {
    let projectCount: Int
    let sketchCount: Int
    let wireframeCount: Int
    let presetCount: Int
    let libraryCount: Int
    let totalCanvasDataBytes: Int
    let totalThumbnailBytes: Int

    var totalBytes: Int {
        totalCanvasDataBytes + totalThumbnailBytes
    }

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file)
    }

    var formattedCanvasSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalCanvasDataBytes), countStyle: .file)
    }

    var formattedThumbnailSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalThumbnailBytes), countStyle: .file)
    }
}

// MARK: - Memory Pressure Handling

extension PersistenceManager {
    /// Responds to memory pressure by clearing caches
    func handleMemoryPressure() async {
        do {
            // Clear all thumbnails to free memory
            try await styleService.clearAllThumbnails()

            // Force save any pending changes
            try await saveAllChanges()

            AppLogger.persistence.info("Responded to memory pressure")
        } catch {
            AppLogger.persistence.error("Failed to handle memory pressure: \(error.localizedDescription)")
        }
    }

    /// Registers for memory pressure notifications
    func registerForMemoryPressure() {
        // Note: On macOS, use DispatchSource.makeMemoryPressureSource
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)

        source.setEventHandler { [weak self] in
            Task { @MainActor in
                await self?.handleMemoryPressure()
            }
        }

        source.resume()
        AppLogger.persistence.debug("Registered for memory pressure notifications")
    }
}

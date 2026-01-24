import Foundation
import SwiftData

// MARK: - Sketch Persisting Protocol

/// Protocol defining sketch persistence operations
/// Note: MainActor-isolated because SwiftData @Model classes aren't Sendable
@MainActor
protocol SketchPersisting {
    /// Saves a sketch to the persistent store
    func save(_ sketch: Sketch) async throws

    /// Fetches all sketches for a project
    func fetchAll(for project: Project) async throws -> [Sketch]

    /// Fetches a single sketch by ID
    func fetch(byId id: UUID) async throws -> Sketch?

    /// Deletes a sketch
    func delete(_ sketch: Sketch) async throws

    /// Creates a new sketch in a project
    func createSketch(in project: Project, name: String?) async throws -> Sketch

    /// Updates canvas data for a sketch
    func updateCanvasData(_ data: CanvasData, for sketch: Sketch) async throws
}

// MARK: - Sketch Persistence Service

/// Service for managing sketch persistence using SwiftData
@MainActor
final class SketchPersistenceService: SketchPersisting {
    // MARK: - Properties

    private let modelContainer: ModelContainer

    /// Main context for UI operations
    private var mainContext: ModelContext {
        modelContainer.mainContext
    }

    // MARK: - Initialization

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        AppLogger.persistence.debug("SketchPersistenceService initialized")
    }

    // MARK: - SketchPersisting Implementation

    func save(_ sketch: Sketch) async throws {
        do {
            sketch.touch()
            mainContext.insert(sketch)
            try mainContext.save()
            AppLogger.persistence.info("Saved sketch: \(sketch.displayName)")
        } catch {
            AppLogger.persistence.error("Failed to save sketch: \(error.localizedDescription)")
            throw PersistenceError.saveFailed(underlying: error)
        }
    }

    func fetchAll(for project: Project) async throws -> [Sketch] {
        let projectId = project.id
        let predicate = #Predicate<Sketch> { sketch in
            sketch.project?.id == projectId
        }

        do {
            var descriptor = FetchDescriptor<Sketch>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            descriptor.includePendingChanges = true

            let sketches = try mainContext.fetch(descriptor)
            AppLogger.persistence.debug("Fetched \(sketches.count) sketches for project")
            return sketches
        } catch {
            AppLogger.persistence.error("Failed to fetch sketches: \(error.localizedDescription)")
            throw PersistenceError.fetchFailed(underlying: error)
        }
    }

    func fetch(byId id: UUID) async throws -> Sketch? {
        let predicate = #Predicate<Sketch> { sketch in
            sketch.id == id
        }

        do {
            let descriptor = FetchDescriptor<Sketch>(predicate: predicate)
            let sketches = try mainContext.fetch(descriptor)
            return sketches.first
        } catch {
            AppLogger.persistence.error("Failed to fetch sketch by ID: \(error.localizedDescription)")
            throw PersistenceError.fetchFailed(underlying: error)
        }
    }

    func delete(_ sketch: Sketch) async throws {
        do {
            mainContext.delete(sketch)
            try mainContext.save()
            AppLogger.persistence.info("Deleted sketch: \(sketch.displayName)")
        } catch {
            AppLogger.persistence.error("Failed to delete sketch: \(error.localizedDescription)")
            throw PersistenceError.deleteFailed(underlying: error)
        }
    }

    func createSketch(in project: Project, name: String? = nil) async throws -> Sketch {
        let sketch = Sketch.newSketch(name: name, in: project)
        project.addSketch(sketch)
        mainContext.insert(sketch)

        do {
            try mainContext.save()
            AppLogger.persistence.info("Created sketch: \(sketch.displayName) in project: \(project.name)")
            return sketch
        } catch {
            AppLogger.persistence.error("Failed to create sketch: \(error.localizedDescription)")
            throw PersistenceError.saveFailed(underlying: error)
        }
    }

    func updateCanvasData(_ data: CanvasData, for sketch: Sketch) async throws {
        do {
            try sketch.setCanvasData(data)
            try mainContext.save()
            AppLogger.persistence.info("Updated canvas data for sketch: \(sketch.displayName)")
        } catch {
            AppLogger.persistence.error("Failed to update canvas data: \(error.localizedDescription)")
            throw PersistenceError.saveFailed(underlying: error)
        }
    }
}

// MARK: - Canvas Data Validation

extension SketchPersistenceService {
    /// Validates canvas data integrity
    func validateCanvasData(for sketch: Sketch) throws -> Bool {
        guard !sketch.canvasData.isEmpty else {
            return true // Empty is valid
        }

        do {
            _ = try sketch.getCanvasData()
            return true
        } catch {
            AppLogger.persistence.error("Canvas data validation failed: \(error.localizedDescription)")
            throw PersistenceError.dataCorrupted(entity: "Sketch")
        }
    }

    /// Attempts to recover corrupted canvas data
    func recoverCanvasData(for sketch: Sketch) async throws {
        // If canvas data is corrupted, reset to empty
        sketch.canvasData = Data()
        sketch.touch()

        do {
            try mainContext.save()
            AppLogger.persistence.warning("Recovered sketch by resetting canvas data: \(sketch.displayName)")
        } catch {
            throw PersistenceError.saveFailed(underlying: error)
        }
    }
}

// MARK: - Background Operations

extension SketchPersistenceService {
    /// Saves canvas data in background for large sketches
    func saveCanvasDataInBackground(_ data: CanvasData, sketchId: UUID) async throws {
        let backgroundContext = ModelContext(modelContainer)
        backgroundContext.autosaveEnabled = false

        do {
            let predicate = #Predicate<Sketch> { sketch in
                sketch.id == sketchId
            }
            let descriptor = FetchDescriptor<Sketch>(predicate: predicate)

            guard let sketch = try backgroundContext.fetch(descriptor).first else {
                throw PersistenceError.fetchFailed(underlying: NSError(
                    domain: "SketchPersistence",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Sketch not found"]
                ))
            }

            try sketch.setCanvasData(data)
            try backgroundContext.save()

            AppLogger.persistence.info("Saved canvas data in background for sketch ID: \(sketchId)")
        } catch let error as PersistenceError {
            throw error
        } catch {
            AppLogger.persistence.error("Background save failed: \(error.localizedDescription)")
            throw PersistenceError.saveFailed(underlying: error)
        }
    }

    /// Calculates the storage size of a sketch's canvas data
    func calculateStorageSize(for sketch: Sketch) -> Int {
        sketch.canvasData.count
    }

    /// Estimates the storage size for canvas data
    func estimateStorageSize(for data: CanvasData) throws -> Int {
        try data.encode().count
    }
}

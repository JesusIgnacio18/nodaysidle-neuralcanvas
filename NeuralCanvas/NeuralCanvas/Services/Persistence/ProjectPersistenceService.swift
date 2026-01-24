import Foundation
import SwiftData

// MARK: - Project Persisting Protocol

/// Protocol defining project persistence operations
/// Note: MainActor-isolated because SwiftData @Model classes aren't Sendable
@MainActor
protocol ProjectPersisting {
    /// Saves a project to the persistent store
    func save(_ project: Project) async throws

    /// Fetches all projects
    func fetchAll() async throws -> [Project]

    /// Fetches projects matching a predicate
    func fetch(matching predicate: Predicate<Project>?) async throws -> [Project]

    /// Fetches a single project by ID
    func fetch(byId id: UUID) async throws -> Project?

    /// Deletes a project (cascades to sketches and wireframes)
    func delete(_ project: Project) async throws

    /// Deletes multiple projects
    func delete(_ projects: [Project]) async throws

    /// Creates a new project
    func createProject(name: String) async throws -> Project
}

// MARK: - Project Persistence Service

/// Service for managing project persistence using SwiftData
@MainActor
final class ProjectPersistenceService: ProjectPersisting {
    // MARK: - Properties

    private let modelContainer: ModelContainer

    /// Main context for UI operations
    private var mainContext: ModelContext {
        modelContainer.mainContext
    }

    // MARK: - Initialization

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        AppLogger.persistence.debug("ProjectPersistenceService initialized")
    }

    // MARK: - ProjectPersisting Implementation

    func save(_ project: Project) async throws {
        do {
            project.touch()
            mainContext.insert(project)
            try mainContext.save()
            AppLogger.persistence.info("Saved project: \(project.name)")
        } catch {
            AppLogger.persistence.error("Failed to save project: \(error.localizedDescription)")
            throw PersistenceError.saveFailed(underlying: error)
        }
    }

    func fetchAll() async throws -> [Project] {
        try await fetch(matching: nil)
    }

    func fetch(matching predicate: Predicate<Project>?) async throws -> [Project] {
        do {
            var descriptor = FetchDescriptor<Project>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
            )
            descriptor.includePendingChanges = true

            let projects = try mainContext.fetch(descriptor)
            AppLogger.persistence.debug("Fetched \(projects.count) projects")
            return projects
        } catch {
            AppLogger.persistence.error("Failed to fetch projects: \(error.localizedDescription)")
            throw PersistenceError.fetchFailed(underlying: error)
        }
    }

    func fetch(byId id: UUID) async throws -> Project? {
        let predicate = #Predicate<Project> { project in
            project.id == id
        }
        let projects = try await fetch(matching: predicate)
        return projects.first
    }

    func delete(_ project: Project) async throws {
        do {
            mainContext.delete(project)
            try mainContext.save()
            AppLogger.persistence.info("Deleted project: \(project.name)")
        } catch {
            AppLogger.persistence.error("Failed to delete project: \(error.localizedDescription)")
            throw PersistenceError.deleteFailed(underlying: error)
        }
    }

    func delete(_ projects: [Project]) async throws {
        do {
            for project in projects {
                mainContext.delete(project)
            }
            try mainContext.save()
            AppLogger.persistence.info("Deleted \(projects.count) projects")
        } catch {
            AppLogger.persistence.error("Failed to delete projects: \(error.localizedDescription)")
            throw PersistenceError.deleteFailed(underlying: error)
        }
    }

    func createProject(name: String) async throws -> Project {
        let project = Project(name: name)
        try await save(project)
        return project
    }
}

// MARK: - Background Operations Extension

extension ProjectPersistenceService {
    /// Performs a heavy save operation on a background context
    func saveInBackground(_ project: Project) async throws {
        let backgroundContext = ModelContext(modelContainer)
        backgroundContext.autosaveEnabled = false

        do {
            // We need to refetch in background context since models aren't Sendable
            let projectId = project.id
            let projectName = project.name
            let projectCreatedAt = project.createdAt
            let projectModifiedAt = Date()
            let selectedStylePresetId = project.selectedStylePresetId

            // Fetch or create the project in background context
            let predicate = #Predicate<Project> { p in
                p.id == projectId
            }
            let descriptor = FetchDescriptor<Project>(predicate: predicate)

            if let existingProject = try backgroundContext.fetch(descriptor).first {
                existingProject.name = projectName
                existingProject.modifiedAt = projectModifiedAt
                existingProject.selectedStylePresetId = selectedStylePresetId
            } else {
                let newProject = Project(
                    id: projectId,
                    name: projectName,
                    createdAt: projectCreatedAt,
                    modifiedAt: projectModifiedAt,
                    selectedStylePresetId: selectedStylePresetId
                )
                backgroundContext.insert(newProject)
            }

            try backgroundContext.save()
            AppLogger.persistence.info("Saved project in background: \(projectName)")
        } catch {
            AppLogger.persistence.error("Background save failed: \(error.localizedDescription)")
            throw PersistenceError.saveFailed(underlying: error)
        }
    }

    /// Performs a batch delete operation on a background context
    func deleteAllInBackground() async throws {
        let backgroundContext = ModelContext(modelContainer)
        backgroundContext.autosaveEnabled = false

        do {
            try backgroundContext.delete(model: Project.self)
            try backgroundContext.save()
            AppLogger.persistence.info("Deleted all projects in background")
        } catch {
            AppLogger.persistence.error("Background batch delete failed: \(error.localizedDescription)")
            throw PersistenceError.deleteFailed(underlying: error)
        }
    }
}

// MARK: - Search Extension

extension ProjectPersistenceService {
    /// Searches projects by name
    func search(query: String) async throws -> [Project] {
        let lowercasedQuery = query.lowercased()
        let predicate = #Predicate<Project> { project in
            project.name.localizedStandardContains(lowercasedQuery)
        }
        return try await fetch(matching: predicate)
    }

    /// Fetches projects created within a date range
    func fetch(from startDate: Date, to endDate: Date) async throws -> [Project] {
        let predicate = #Predicate<Project> { project in
            project.createdAt >= startDate && project.createdAt <= endDate
        }
        return try await fetch(matching: predicate)
    }

    /// Fetches recent projects (modified within last N days)
    func fetchRecent(days: Int = 7) async throws -> [Project] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = #Predicate<Project> { project in
            project.modifiedAt >= cutoffDate
        }
        return try await fetch(matching: predicate)
    }
}

import Foundation
import SwiftData

// MARK: - Schema Version 1

/// Initial schema version for NeuralCanvas
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [
            Project.self,
            Sketch.self,
            Wireframe.self,
            StylePreset.self,
            StyleLibrary.self
        ]
    }
}

// MARK: - Schema Migration Plan

/// Migration plan for NeuralCanvas database schema
enum NeuralCanvasMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        // No migrations yet - this is the initial version
        // Future migrations will be added here as the schema evolves
        []
    }
}

// MARK: - Migration Helpers

/// Utility functions for schema migration
enum MigrationUtility {
    /// Current schema version number
    static let currentVersion = 1

    /// Checks if migration is needed
    static func isMigrationRequired(from version: Int) -> Bool {
        version < currentVersion
    }

    /// Gets the migration path from one version to another
    static func migrationPath(from sourceVersion: Int, to targetVersion: Int) -> [Int] {
        guard sourceVersion < targetVersion else { return [] }
        return Array((sourceVersion + 1)...targetVersion)
    }

    /// Logs migration info
    static func logMigrationStart(from sourceVersion: Int) {
        AppLogger.persistence.info("Starting migration from version \(sourceVersion) to \(currentVersion)")
    }

    /// Logs migration completion
    static func logMigrationComplete(from sourceVersion: Int) {
        AppLogger.persistence.info("Migration complete from version \(sourceVersion) to \(currentVersion)")
    }
}

// MARK: - Future Migration Stage Examples
/*
 To add a migration in the future, follow this pattern:

 // Schema V2 with new field
 enum SchemaV2: VersionedSchema {
     static var versionIdentifier: Schema.Version {
         Schema.Version(2, 0, 0)
     }

     static var models: [any PersistentModel.Type] {
         [Project.self, Sketch.self, Wireframe.self, StylePreset.self, StyleLibrary.self]
     }
 }

 // Then add to NeuralCanvasMigrationPlan:
 static var schemas: [any VersionedSchema.Type] {
     [SchemaV1.self, SchemaV2.self]
 }

 static var stages: [MigrationStage] {
     [migrateV1toV2]
 }

 // Define the migration stage:
 static let migrateV1toV2 = MigrationStage.custom(
     fromVersion: SchemaV1.self,
     toVersion: SchemaV2.self,
     willMigrate: { context in
         // Pre-migration logic if needed
     },
     didMigrate: { context in
         // Post-migration logic
         // Example: Set default values for new fields
         let projects = try context.fetch(FetchDescriptor<Project>())
         for project in projects {
             // project.newField = defaultValue
         }
         try context.save()
     }
 )
 */

// MARK: - Model Container Configuration

/// Creates a properly configured ModelContainer with migration support
enum ModelContainerConfiguration {
    /// Creates the default model container for the app
    static func createDefault() throws -> ModelContainer {
        let schema = Schema(SchemaV1.models)

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        return try ModelContainer(
            for: schema,
            migrationPlan: NeuralCanvasMigrationPlan.self,
            configurations: [configuration]
        )
    }

    /// Creates an in-memory container for testing
    static func createInMemory() throws -> ModelContainer {
        let schema = Schema(SchemaV1.models)

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }

    /// Creates a container with a custom URL for testing
    static func create(at url: URL) throws -> ModelContainer {
        let schema = Schema(SchemaV1.models)

        let configuration = ModelConfiguration(
            schema: schema,
            url: url,
            allowsSave: true
        )

        return try ModelContainer(
            for: schema,
            migrationPlan: NeuralCanvasMigrationPlan.self,
            configurations: [configuration]
        )
    }
}

// MARK: - Data Integrity Validation

/// Utilities for validating data integrity after migration
enum DataIntegrityValidator {
    /// Validates all projects have valid relationships
    static func validateProjects(in context: ModelContext) throws -> Bool {
        let descriptor = FetchDescriptor<Project>()
        let projects = try context.fetch(descriptor)

        for project in projects {
            // Validate sketches relationship
            for sketch in project.sketches {
                guard sketch.project?.id == project.id else {
                    AppLogger.persistence.error("Sketch \(sketch.id) has incorrect project reference")
                    return false
                }
            }

            // Validate wireframes relationship
            for wireframe in project.wireframes {
                guard wireframe.project?.id == project.id else {
                    AppLogger.persistence.error("Wireframe \(wireframe.id) has incorrect project reference")
                    return false
                }
            }
        }

        AppLogger.persistence.info("Project integrity validation passed for \(projects.count) projects")
        return true
    }

    /// Validates all style presets have valid data
    static func validateStylePresets(in context: ModelContext) throws -> Bool {
        let descriptor = FetchDescriptor<StylePreset>()
        let presets = try context.fetch(descriptor)

        for preset in presets {
            // Validate style data can be decoded
            do {
                _ = try preset.getExtractedStyle()
            } catch {
                AppLogger.persistence.error("Preset \(preset.name) has invalid style data: \(error)")
                return false
            }
        }

        AppLogger.persistence.info("Style preset validation passed for \(presets.count) presets")
        return true
    }

    /// Validates all sketch canvas data
    static func validateSketchData(in context: ModelContext) throws -> Bool {
        let descriptor = FetchDescriptor<Sketch>()
        let sketches = try context.fetch(descriptor)

        for sketch in sketches where !sketch.canvasData.isEmpty {
            do {
                _ = try sketch.getCanvasData()
            } catch {
                AppLogger.persistence.error("Sketch \(sketch.id) has invalid canvas data: \(error)")
                return false
            }
        }

        AppLogger.persistence.info("Sketch data validation passed for \(sketches.count) sketches")
        return true
    }

    /// Runs all validation checks
    static func validateAll(in context: ModelContext) throws -> Bool {
        try validateProjects(in: context) &&
        validateStylePresets(in: context) &&
        validateSketchData(in: context)
    }
}

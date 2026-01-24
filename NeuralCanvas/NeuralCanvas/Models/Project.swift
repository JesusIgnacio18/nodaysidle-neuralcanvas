import Foundation
import SwiftData

/// A NeuralCanvas project containing sketches and wireframes
@Model
final class Project {
    // MARK: - Properties

    /// Unique identifier
    var id: UUID

    /// User-provided project name
    var name: String

    /// When the project was created
    var createdAt: Date

    /// When the project was last modified
    var modifiedAt: Date

    // MARK: - Relationships

    /// Sketches belonging to this project
    @Relationship(deleteRule: .cascade, inverse: \Sketch.project)
    var sketches: [Sketch]

    /// Wireframes generated in this project
    @Relationship(deleteRule: .cascade, inverse: \Wireframe.project)
    var wireframes: [Wireframe]

    /// The currently selected style preset ID (stored as UUID)
    var selectedStylePresetId: UUID?

    // MARK: - Computed Properties

    /// Total count of sketches in this project
    var sketchCount: Int {
        sketches.count
    }

    /// Total count of wireframes in this project
    var wireframeCount: Int {
        wireframes.count
    }

    /// The most recent sketch, if any
    var latestSketch: Sketch? {
        sketches.sorted { $0.createdAt > $1.createdAt }.first
    }

    /// The most recent wireframe, if any
    var latestWireframe: Wireframe? {
        wireframes.sorted { $0.createdAt > $1.createdAt }.first
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        sketches: [Sketch] = [],
        wireframes: [Wireframe] = [],
        selectedStylePresetId: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.sketches = sketches
        self.wireframes = wireframes
        self.selectedStylePresetId = selectedStylePresetId
    }

    // MARK: - Methods

    /// Updates the modification timestamp
    func touch() {
        modifiedAt = Date()
    }

    /// Adds a new sketch to the project
    func addSketch(_ sketch: Sketch) {
        sketches.append(sketch)
        touch()
    }

    /// Adds a new wireframe to the project
    func addWireframe(_ wireframe: Wireframe) {
        wireframes.append(wireframe)
        touch()
    }

    /// Removes a sketch from the project
    func removeSketch(_ sketch: Sketch) {
        sketches.removeAll { $0.id == sketch.id }
        touch()
    }

    /// Removes a wireframe from the project
    func removeWireframe(_ wireframe: Wireframe) {
        wireframes.removeAll { $0.id == wireframe.id }
        touch()
    }
}

// MARK: - Convenience Initializers

extension Project {
    /// Creates a new empty project with a default name
    static func newProject(name: String = "Untitled Project") -> Project {
        Project(name: name)
    }
}

// MARK: - Identifiable Conformance

extension Project: Identifiable {}

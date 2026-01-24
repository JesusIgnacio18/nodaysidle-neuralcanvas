import Foundation
import SwiftData

/// A hand-drawn sketch that can be converted to a wireframe
@Model
final class Sketch {
    // MARK: - Properties

    /// Unique identifier
    var id: UUID

    /// Serialized canvas data (strokes, shapes) as JSON Data
    var canvasData: Data

    /// When the sketch was created
    var createdAt: Date

    /// When the sketch was last modified
    var modifiedAt: Date

    /// Optional user-provided name
    var name: String?

    /// Whether the sketch has been processed into a wireframe
    var isProcessed: Bool

    // MARK: - Relationships

    /// The project this sketch belongs to
    var project: Project?

    /// The wireframe generated from this sketch, if any
    @Relationship(deleteRule: .nullify, inverse: \Wireframe.sourceSketch)
    var generatedWireframe: Wireframe?

    // MARK: - Computed Properties

    /// Display name (uses name if set, otherwise a generated name)
    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return "Sketch \(formatter.string(from: createdAt))"
    }

    /// Decodes the canvas data to CanvasData object
    func getCanvasData() throws -> CanvasData {
        try CanvasData.decode(from: canvasData)
    }

    /// Whether the sketch has any strokes
    var hasContent: Bool {
        !canvasData.isEmpty && canvasData.count > 2 // Empty JSON is "{}"
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        canvasData: Data = Data(),
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        name: String? = nil,
        isProcessed: Bool = false,
        project: Project? = nil
    ) {
        self.id = id
        self.canvasData = canvasData
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.name = name
        self.isProcessed = isProcessed
        self.project = project
    }

    // MARK: - Methods

    /// Updates the modification timestamp
    func touch() {
        modifiedAt = Date()
    }

    /// Updates the canvas data from a CanvasData object
    func setCanvasData(_ data: CanvasData) throws {
        canvasData = try data.encode()
        touch()
    }

    /// Marks the sketch as processed
    func markProcessed(wireframe: Wireframe) {
        isProcessed = true
        generatedWireframe = wireframe
        touch()
    }

    /// Clears all canvas data
    func clear() {
        canvasData = Data()
        touch()
    }
}

// MARK: - Convenience Initializers

extension Sketch {
    /// Creates a new empty sketch
    static func newSketch(name: String? = nil, in project: Project? = nil) -> Sketch {
        Sketch(name: name, project: project)
    }

    /// Creates a sketch with initial canvas data
    static func withCanvasData(_ data: CanvasData, name: String? = nil, in project: Project? = nil) throws -> Sketch {
        let sketch = Sketch(name: name, project: project)
        try sketch.setCanvasData(data)
        return sketch
    }
}

// MARK: - Identifiable Conformance

extension Sketch: Identifiable {}

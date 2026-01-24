import Foundation
import SwiftData

/// A processed wireframe generated from a sketch
@Model
final class Wireframe {
    // MARK: - Properties

    /// Unique identifier
    var id: UUID

    /// Serialized vector data (shapes, elements) as JSON Data
    var vectorData: Data

    /// Serialized recognized shapes as JSON Data
    var recognizedShapesData: Data

    /// When the wireframe was created
    var createdAt: Date

    /// When the wireframe was last modified
    var modifiedAt: Date

    /// Optional user-provided name
    var name: String?

    /// Confidence score from the recognition (0.0 to 1.0)
    var confidence: Double

    /// Serialized applied style reference as JSON Data
    var appliedStyleData: Data?

    // MARK: - Relationships

    /// The project this wireframe belongs to
    var project: Project?

    /// The source sketch this wireframe was generated from
    var sourceSketch: Sketch?

    // MARK: - Computed Properties

    /// Display name (uses name if set, otherwise a generated name)
    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return "Wireframe \(formatter.string(from: createdAt))"
    }

    /// Decodes the recognized shapes from data
    func getRecognizedShapes() throws -> [RecognizedShape] {
        guard !recognizedShapesData.isEmpty else { return [] }
        return try JSONDecoder().decode([RecognizedShape].self, from: recognizedShapesData)
    }

    /// Decodes the applied style reference
    func getAppliedStyle() throws -> StylePresetReference? {
        guard let data = appliedStyleData else { return nil }
        return try JSONDecoder().decode(StylePresetReference.self, from: data)
    }

    /// Whether a style has been applied to this wireframe
    var hasAppliedStyle: Bool {
        appliedStyleData != nil
    }

    /// The number of recognized shapes
    var shapeCount: Int {
        (try? getRecognizedShapes().count) ?? 0
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        vectorData: Data = Data(),
        recognizedShapesData: Data = Data(),
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        name: String? = nil,
        confidence: Double = 0.0,
        appliedStyleData: Data? = nil,
        project: Project? = nil,
        sourceSketch: Sketch? = nil
    ) {
        self.id = id
        self.vectorData = vectorData
        self.recognizedShapesData = recognizedShapesData
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.name = name
        self.confidence = confidence
        self.appliedStyleData = appliedStyleData
        self.project = project
        self.sourceSketch = sourceSketch
    }

    // MARK: - Methods

    /// Updates the modification timestamp
    func touch() {
        modifiedAt = Date()
    }

    /// Updates the recognized shapes
    func setRecognizedShapes(_ shapes: [RecognizedShape]) throws {
        recognizedShapesData = try JSONEncoder().encode(shapes)
        touch()
    }

    /// Applies a style preset to this wireframe
    func applyStyle(presetId: UUID, presetName: String) throws {
        let reference = StylePresetReference(presetId: presetId, presetName: presetName)
        appliedStyleData = try JSONEncoder().encode(reference)
        touch()
    }

    /// Removes the applied style
    func removeStyle() {
        appliedStyleData = nil
        touch()
    }
}

// MARK: - Convenience Initializers

extension Wireframe {
    /// Creates a wireframe from recognized sketch data
    static func fromRecognition(
        shapes: [RecognizedShape],
        confidence: Double,
        sourceSketch: Sketch? = nil,
        project: Project? = nil
    ) throws -> Wireframe {
        let wireframe = Wireframe(
            confidence: confidence,
            project: project,
            sourceSketch: sourceSketch
        )
        try wireframe.setRecognizedShapes(shapes)
        return wireframe
    }
}

// MARK: - Identifiable Conformance

extension Wireframe: Identifiable {}

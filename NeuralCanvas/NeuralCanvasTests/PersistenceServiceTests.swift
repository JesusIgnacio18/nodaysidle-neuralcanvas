import XCTest
import SwiftData
@testable import NeuralCanvas

/// Unit tests for persistence services
@MainActor
final class PersistenceServiceTests: XCTestCase {

    var modelContainer: ModelContainer!

    override func setUp() async throws {
        try await super.setUp()

        // Create in-memory container for test isolation
        let schema = Schema([
            Project.self,
            Sketch.self,
            Wireframe.self,
            StylePreset.self,
            StyleLibrary.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        modelContainer = try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
    }

    override func tearDown() async throws {
        modelContainer = nil
        try await super.tearDown()
    }

    // MARK: - Project Persistence Tests

    func testCreateProject() async throws {
        let service = ProjectPersistenceService(modelContainer: modelContainer)

        let project = try await service.createProject(name: "Test Project")

        XCTAssertEqual(project.name, "Test Project")
        XCTAssertNotNil(project.createdAt)
        XCTAssertNotNil(project.modifiedAt)
    }

    func testFetchAllProjects() async throws {
        let service = ProjectPersistenceService(modelContainer: modelContainer)

        // Create multiple projects
        _ = try await service.createProject(name: "Project 1")
        _ = try await service.createProject(name: "Project 2")
        _ = try await service.createProject(name: "Project 3")

        let projects = try await service.fetchAll()
        XCTAssertEqual(projects.count, 3)
    }

    func testFetchProjectById() async throws {
        let service = ProjectPersistenceService(modelContainer: modelContainer)

        let createdProject = try await service.createProject(name: "Specific Project")
        let fetchedProject = try await service.fetch(byId: createdProject.id)

        XCTAssertNotNil(fetchedProject)
        XCTAssertEqual(fetchedProject?.name, "Specific Project")
    }

    func testDeleteProject() async throws {
        let service = ProjectPersistenceService(modelContainer: modelContainer)

        let project = try await service.createProject(name: "To Delete")
        let projectId = project.id

        try await service.delete(project)

        let fetchedProject = try await service.fetch(byId: projectId)
        XCTAssertNil(fetchedProject)
    }

    func testProjectModifiedAtUpdates() async throws {
        let service = ProjectPersistenceService(modelContainer: modelContainer)

        let project = try await service.createProject(name: "Test")
        let originalModifiedAt = project.modifiedAt

        // Wait a bit
        try await Task.sleep(for: .milliseconds(10))

        // Update the project
        project.touch()
        try await service.save(project)

        XCTAssertGreaterThan(project.modifiedAt, originalModifiedAt)
    }

    // MARK: - Sketch Persistence Tests

    func testCreateSketch() async throws {
        let projectService = ProjectPersistenceService(modelContainer: modelContainer)
        let sketchService = SketchPersistenceService(modelContainer: modelContainer)

        let project = try await projectService.createProject(name: "Test Project")
        let sketch = try await sketchService.createSketch(in: project)

        XCTAssertNotNil(sketch)
        XCTAssertEqual(sketch.project?.id, project.id)
    }

    func testFetchSketchesInProject() async throws {
        let projectService = ProjectPersistenceService(modelContainer: modelContainer)
        let sketchService = SketchPersistenceService(modelContainer: modelContainer)

        let project = try await projectService.createProject(name: "Test Project")
        _ = try await sketchService.createSketch(in: project)
        _ = try await sketchService.createSketch(in: project)

        let sketches = try await sketchService.fetchAll(for: project)
        XCTAssertEqual(sketches.count, 2)
    }

    func testSketchCanvasDataSerialization() async throws {
        let projectService = ProjectPersistenceService(modelContainer: modelContainer)
        let sketchService = SketchPersistenceService(modelContainer: modelContainer)

        let project = try await projectService.createProject(name: "Test Project")
        let sketch = try await sketchService.createSketch(in: project)

        // Create canvas data
        let strokes = [
            VectorStroke(
                points: [
                    StrokePoint(location: CGPoint(x: 0, y: 0)),
                    StrokePoint(location: CGPoint(x: 100, y: 100))
                ],
                width: 2.0,
                color: .black
            )
        ]

        // Save canvas data using CanvasData wrapper
        let canvasData = CanvasData(strokes: strokes, recognizedShapes: [])
        try await sketchService.updateCanvasData(canvasData, for: sketch)

        // Verify data was saved
        XCTAssertFalse(sketch.canvasData.isEmpty)

        // Retrieve and verify
        let savedCanvasData = try sketch.getCanvasData()
        XCTAssertEqual(savedCanvasData.strokes.count, 1)
        XCTAssertEqual(savedCanvasData.strokes.first?.points.count, 2)
    }

    // MARK: - Style Preset Persistence Tests

    func testCreateStyleLibrary() async throws {
        let service = StylePersistenceService(modelContainer: modelContainer)

        let library = try await service.createLibrary(name: "My Styles", withDefaults: false)

        XCTAssertEqual(library.name, "My Styles")
        XCTAssertTrue(library.presets.isEmpty)
    }

    func testCreateStyleLibraryWithDefaults() async throws {
        let service = StylePersistenceService(modelContainer: modelContainer)

        let library = try await service.createLibrary(name: "Default Styles", withDefaults: true)

        XCTAssertEqual(library.name, "Default Styles")
        XCTAssertFalse(library.presets.isEmpty)
    }

    func testFetchAllLibraries() async throws {
        let service = StylePersistenceService(modelContainer: modelContainer)

        _ = try await service.createLibrary(name: "Library 1", withDefaults: false)
        _ = try await service.createLibrary(name: "Library 2", withDefaults: false)

        let libraries = try await service.fetchAllLibraries()
        XCTAssertEqual(libraries.count, 2)
    }

    func testCreatePresetFromExtractedStyle() async throws {
        let service = StylePersistenceService(modelContainer: modelContainer)

        let library = try await service.createLibrary(name: "Test Library", withDefaults: false)
        let style = ExtractedStyle.defaultStyle

        let preset = try await service.createPreset(
            from: style,
            name: "Extracted Style",
            thumbnail: nil,
            in: library
        )

        XCTAssertEqual(preset.name, "Extracted Style")
        XCTAssertEqual(preset.library?.id, library.id)

        // Verify style data is preserved
        let savedPalette = try preset.getColorPalette()
        XCTAssertEqual(savedPalette.primary.hexString, style.colorPalette.primary.hexString)
    }

    func testDeleteStylePreset() async throws {
        let service = StylePersistenceService(modelContainer: modelContainer)

        let library = try await service.createLibrary(name: "Test Library", withDefaults: true)
        guard let preset = library.presets.first else {
            XCTFail("Expected library to have presets")
            return
        }

        let presetId = preset.id
        try await service.delete(preset)

        let fetchedPreset = try await service.fetchPreset(byId: presetId)
        XCTAssertNil(fetchedPreset)
    }

    func testSearchPresets() async throws {
        let service = StylePersistenceService(modelContainer: modelContainer)

        let library = try await service.createLibrary(name: "Test Library", withDefaults: false)

        let style = ExtractedStyle.defaultStyle
        _ = try await service.createPreset(from: style, name: "Modern Light", thumbnail: nil, in: library)
        _ = try await service.createPreset(from: style, name: "Modern Dark", thumbnail: nil, in: library)
        _ = try await service.createPreset(from: style, name: "Classic Blue", thumbnail: nil, in: library)

        let results = try await service.searchPresets(query: "Modern")
        XCTAssertEqual(results.count, 2)
    }

    // MARK: - Data Integrity Tests

    func testCascadeDeleteProject() async throws {
        let projectService = ProjectPersistenceService(modelContainer: modelContainer)
        let sketchService = SketchPersistenceService(modelContainer: modelContainer)

        let project = try await projectService.createProject(name: "Test Project")
        let sketch = try await sketchService.createSketch(in: project)
        let sketchId = sketch.id

        // Delete project should cascade to sketches
        try await projectService.delete(project)

        let fetchedSketch = try await sketchService.fetch(byId: sketchId)
        XCTAssertNil(fetchedSketch)
    }

    // MARK: - Sequential Project Creation Tests

    func testSequentialProjectCreation() async throws {
        let service = ProjectPersistenceService(modelContainer: modelContainer)

        // Create multiple projects sequentially (not concurrently to avoid Sendable issues)
        _ = try await service.createProject(name: "Sequential 1")
        _ = try await service.createProject(name: "Sequential 2")
        _ = try await service.createProject(name: "Sequential 3")

        let allProjects = try await service.fetchAll()
        XCTAssertEqual(allProjects.count, 3)
    }
}

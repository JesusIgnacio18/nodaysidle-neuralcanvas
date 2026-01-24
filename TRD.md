# Technical Requirements Document

## 🧭 System Context
NeuralCanvas is a native macOS 15+ application targeting Apple Silicon Macs that transforms hand-drawn sketches into high-fidelity UI wireframes using on-device ML via CoreML and the M4 Neural Engine. The app follows a local-first architecture with SwiftUI 6 frontend, SwiftData persistence, and optional CloudKit sync. All ML inference runs locally ensuring complete data privacy. No server backend required.

## 🔌 API Contracts
### SketchRecognitionActor
- **Method:** async
- **Path:** internal://SketchRecognitionActor/processSketch
- **Auth:** none (local actor)
- **Request:** func processSketch(_ image: CGImage, canvasSize: CGSize) async throws -> RecognizedSketch
- **Response:** RecognizedSketch { strokes: [VectorStroke], shapes: [RecognizedShape], confidence: Double, processingTime: Duration }
- **Errors:**
- SketchRecognitionError.modelNotLoaded
- SketchRecognitionError.inferenceFailure(underlying: Error)
- SketchRecognitionError.invalidInput
- SketchRecognitionError.cancelled

### StyleMirrorActor
- **Method:** async
- **Path:** internal://StyleMirrorActor/extractStyleFromScreenshot
- **Auth:** none (local actor)
- **Request:** func extractStyle(from screenshot: CGImage) async throws -> ExtractedStyle
- **Response:** ExtractedStyle { colors: ColorPalette, typography: TypographyScale, spacing: SpacingSystem, cornerRadii: [CGFloat], shadows: [ShadowStyle] }
- **Errors:**
- StyleMirrorError.modelNotLoaded
- StyleMirrorError.analysisFailure(underlying: Error)
- StyleMirrorError.insufficientContent
- StyleMirrorError.unsupportedImageFormat

### StyleMirrorActor
- **Method:** async
- **Path:** internal://StyleMirrorActor/applyStyleToWireframe
- **Auth:** none (local actor)
- **Request:** func applyStyle(_ style: ExtractedStyle, to wireframe: Wireframe) async throws -> StyledWireframe
- **Response:** StyledWireframe { elements: [StyledUIElement], appliedStyle: ExtractedStyle, warnings: [StyleApplicationWarning] }
- **Errors:**
- StyleMirrorError.incompatibleStyle
- StyleMirrorError.applicationFailure(underlying: Error)

### CanvasRenderingService
- **Method:** sync/async
- **Path:** internal://CanvasRenderingService/render
- **Auth:** none (local service)
- **Request:** func render(strokes: [VectorStroke], shapes: [RecognizedShape], viewport: CGRect, scale: CGFloat) -> MTLTexture
- **Response:** MTLTexture ready for display in MTKView
- **Errors:**
- RenderingError.deviceNotAvailable
- RenderingError.shaderCompilationFailed
- RenderingError.textureAllocationFailed

### ExportService
- **Method:** async
- **Path:** internal://ExportService/export
- **Auth:** none (local service)
- **Request:** func export(wireframe: Wireframe, format: ExportFormat, options: ExportOptions) async throws -> Data
- **Response:** Data containing exported file content (SVG/PDF/PNG)
- **Errors:**
- ExportError.unsupportedFormat
- ExportError.renderingFailed
- ExportError.insufficientMemory

### ProjectPersistenceService
- **Method:** async
- **Path:** internal://ProjectPersistenceService/operations
- **Auth:** none (local service)
- **Request:** func save(_ project: Project) async throws; func fetch(predicate: Predicate<Project>?) async throws -> [Project]; func delete(_ project: Project) async throws
- **Response:** Void for mutations, [Project] for queries
- **Errors:**
- PersistenceError.saveFailed(underlying: Error)
- PersistenceError.fetchFailed(underlying: Error)
- PersistenceError.migrationRequired

## 🧱 Modules
### SketchRecognitionModule
- **Responsibilities:**
- Load and manage CoreML sketch recognition model
- Preprocess canvas input using Vision framework
- Run real-time inference on Neural Engine
- Convert ML output to vector strokes and recognized shapes
- Maintain model warm state for low-latency processing
- **Interfaces:**
- protocol SketchRecognizing { func processSketch(_ image: CGImage, canvasSize: CGSize) async throws -> RecognizedSketch }
- actor SketchRecognitionActor: SketchRecognizing
- **Depends on:**
- CoreML
- Vision
- CoreGraphics

### StyleMirrorModule
- **Responsibilities:**
- Extract design tokens from screenshot images
- Identify color palettes using CoreML image analysis
- Detect typography patterns and spacing systems
- Apply extracted styles to wireframe elements
- Manage style preset library
- **Interfaces:**
- protocol StyleExtracting { func extractStyle(from screenshot: CGImage) async throws -> ExtractedStyle }
- protocol StyleApplying { func applyStyle(_ style: ExtractedStyle, to wireframe: Wireframe) async throws -> StyledWireframe }
- actor StyleMirrorActor: StyleExtracting, StyleApplying
- **Depends on:**
- CoreML
- Vision
- CoreGraphics
- SketchRecognitionModule

### CanvasModule
- **Responsibilities:**
- Render real-time drawing input at 60fps
- Display vector strokes with Metal shaders
- Handle touch/pencil input events
- Manage viewport transformations (pan, zoom)
- Provide visual feedback during ML processing
- **Interfaces:**
- protocol CanvasRendering { func render(strokes: [VectorStroke], shapes: [RecognizedShape], viewport: CGRect, scale: CGFloat) -> MTLTexture }
- class CanvasRenderingService: CanvasRendering
- struct CanvasView: View
- **Depends on:**
- Metal
- MetalKit
- SwiftUI

### ExportModule
- **Responsibilities:**
- Convert wireframes to SVG format
- Generate PDF documents with vector graphics
- Export raster images at configurable resolutions
- Preserve style information in exported formats
- **Interfaces:**
- protocol Exporting { func export(wireframe: Wireframe, format: ExportFormat, options: ExportOptions) async throws -> Data }
- class ExportService: Exporting
- enum ExportFormat { case svg, pdf, png, jpeg }
- **Depends on:**
- CoreGraphics
- PDFKit
- UniformTypeIdentifiers

### PersistenceModule
- **Responsibilities:**
- Manage SwiftData ModelContainer lifecycle
- Perform CRUD operations on projects and wireframes
- Handle schema migrations
- Coordinate background context operations
- Optional CloudKit sync configuration
- **Interfaces:**
- protocol ProjectPersisting { func save(_ project: Project) async throws; func fetch(predicate: Predicate<Project>?) async throws -> [Project] }
- class ProjectPersistenceService: ProjectPersisting
- **Depends on:**
- SwiftData
- CloudKit

### AppShellModule
- **Responsibilities:**
- Coordinate NavigationSplitView layout
- Manage window lifecycle and NSWindow customization
- Handle MenuBarExtra quick-capture
- Present Settings scene
- Inject environment dependencies
- **Interfaces:**
- struct NeuralCanvasApp: App
- struct MainWorkspaceView: View
- struct SidebarView: View
- struct SettingsView: View
- **Depends on:**
- SwiftUI
- CanvasModule
- PersistenceModule

## 🗃 Data Model Notes
- @Model class Project { var id: UUID; var name: String; var createdAt: Date; var modifiedAt: Date; @Relationship(deleteRule: .cascade) var sketches: [Sketch]; @Relationship(deleteRule: .cascade) var wireframes: [Wireframe]; var selectedStylePreset: StylePreset? }
- @Model class Sketch { var id: UUID; var canvasData: Data; var createdAt: Date; var project: Project? }
- @Model class Wireframe { var id: UUID; var vectorData: Data; var recognizedShapes: [RecognizedShapeData]; var appliedStyle: StylePresetReference?; var createdAt: Date; var sketch: Sketch?; var project: Project? }
- @Model class StylePreset { var id: UUID; var name: String; var colorPaletteData: Data; var typographyData: Data; var spacingData: Data; var sourceScreenshotThumbnail: Data?; var isBuiltIn: Bool; var library: StyleLibrary? }
- @Model class StyleLibrary { var id: UUID; var name: String; @Relationship(deleteRule: .cascade) var presets: [StylePreset]; var isSyncEnabled: Bool }
- Use Codable structs for complex nested data stored as Data blobs: VectorStroke, RecognizedShape, ColorPalette, TypographyScale, SpacingSystem
- SwiftData schema version starts at 1, increment with VersionedSchema for migrations

## 🔐 Validation & Security
- Validate image dimensions before ML processing (min 64x64, max 8192x8192)
- Sanitize file names during export to prevent path traversal
- Validate CoreML model checksums on first load
- Ensure all file operations use app sandbox containers
- No network calls for core functionality - verify no accidental URLSession usage
- Validate imported screenshots are valid image formats before processing
- Memory limit checks before loading large canvas data
- Input validation on all user-provided text fields (project names, style names)

## 🧯 Error Handling Strategy
Use Swift typed throws with domain-specific error enums (SketchRecognitionError, StyleMirrorError, ExportError, PersistenceError, RenderingError). Surface errors to UI via @Observable error state with localized descriptions. Implement automatic retry with exponential backoff for transient failures (memory pressure). Log errors with OSLog for diagnostics. Present user-facing alerts only for actionable errors; silently recover from transient issues where possible.

## 🔭 Observability
- **Logging:** OSLog with subsystem 'com.neuralcanvas.app' and categories: ml-inference, canvas-rendering, persistence, export, ui-events. Log ML inference timing, memory usage peaks, and export durations at .debug level. Log errors at .error level with context.
- **Tracing:** Use os_signpost for performance instrumentation of ML inference pipeline, canvas rendering frames, and export operations. Integrate with Instruments for profiling Neural Engine utilization and Metal GPU timeline.
- **Metrics:**
- sketch_recognition_latency_ms (histogram)
- style_extraction_latency_ms (histogram)
- canvas_frame_time_ms (histogram, target < 16.67ms)
- memory_usage_bytes (gauge)
- model_load_time_ms (histogram)
- export_duration_ms (histogram by format)
- projects_count (gauge)
- wireframes_per_session (counter)

## ⚡ Performance Notes
- Preload CoreML models at app launch in background Task to avoid cold-start latency
- Use MLComputeUnits.all to leverage Neural Engine on M4 chips
- Implement progressive rendering: show low-fidelity preview within 100ms, full quality within 500ms
- Use MTLHeap for efficient Metal texture allocation and reuse
- Batch multiple small strokes into single inference calls where possible
- Implement canvas tile-based rendering for large wireframes
- Use SwiftData background ModelContext for heavy fetch/save operations
- Lazy load style library thumbnails using AsyncImage pattern
- Target 60fps canvas rendering; drop to 30fps during active ML inference if needed
- Use @MainActor sparingly; keep ML actors off main thread

## 🧪 Testing Strategy
### Unit
- SketchRecognitionActorTests: test stroke recognition accuracy with fixture images
- StyleMirrorActorTests: test color extraction, typography detection with known screenshots
- ExportServiceTests: validate SVG/PDF output structure and content
- VectorStroke parsing and serialization tests
- ColorPalette extraction algorithm tests
- SwiftData model relationship integrity tests
### Integration
- Full pipeline test: sketch input -> recognition -> style application -> export
- SwiftData persistence round-trip tests with complex project graphs
- CoreML model loading and inference integration
- Metal rendering pipeline with various viewport configurations
- CloudKit sync conflict resolution (when enabled)
### E2E
- XCUITest: Complete user flow from new project to exported wireframe
- XCUITest: Style Mirror flow - import screenshot, apply to wireframe
- XCUITest: Settings modifications persist across app restart
- XCUITest: MenuBarExtra quick-capture creates new sketch in current project
- Performance test: sketch-to-wireframe under 500ms on M4
- Memory test: stay under 500MB during continuous inference

## 🚀 Rollout Plan
- Phase 1: Core canvas and sketch recognition - internal dogfooding
- Phase 2: Style Mirror feature - TestFlight beta with 100 users
- Phase 3: Export functionality and polish - expanded TestFlight beta
- Phase 4: Mac App Store submission with basic feature set
- Phase 5: Post-launch iteration based on user feedback
- Phase 6: Optional CloudKit sync for style libraries
- Direct notarized download available from Phase 3 onward

## ❓ Open Questions
- Should Style Mirror support extracting styles from Figma/Sketch file imports in addition to screenshots?
- What is the acceptable bundle size increase for higher-accuracy CoreML models vs quantized versions?
- Should we support iPad via Mac Catalyst or keep macOS-exclusive for optimal UX?
- How granular should the style extraction be - component-level or screen-level tokens?
- Should we implement undo/redo at the stroke level or wireframe snapshot level?
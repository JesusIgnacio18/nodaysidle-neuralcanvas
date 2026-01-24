# Tasks Plan — NeuralCanvas

## 📌 Global Assumptions
- Developer has Apple Silicon Mac with macOS 15+ installed
- Developer has Xcode 16+ with Swift 6 support
- CoreML models will need to be trained or sourced separately
- Developer has Apple Developer Program membership for notarization and App Store submission
- CloudKit functionality requires iCloud developer account setup
- Metal shaders require GPU debugging tools in Xcode

## ⚠️ Risks
- [object Object]
- [object Object]
- [object Object]
- [object Object]
- [object Object]

## 🧩 Epics
## Project Foundation & Architecture
**Goal:** Establish the core app structure, build system, and foundational modules

### ✅ Create Xcode project with SwiftUI 6 App lifecycle (S)

Initialize macOS 15+ project with SwiftUI App protocol, configure deployment target for Apple Silicon, set up basic Info.plist with required permissions

**Acceptance Criteria**
- Project builds and runs on macOS 15+
- App launches with empty window
- Bundle identifier set to com.neuralcanvas.app
- Minimum deployment target is macOS 15.0

**Dependencies**
_None_
### ✅ Configure SwiftData ModelContainer and schema (M)

Set up SwiftData with @Model classes for Project, Sketch, Wireframe, StylePreset, and StyleLibrary. Configure ModelContainer in App struct with schema versioning

**Acceptance Criteria**
- All @Model classes compile without errors
- @Relationship attributes configured with proper delete rules
- ModelContainer initializes successfully at app launch
- VersionedSchema set to version 1

**Dependencies**
- Create Xcode project with SwiftUI 6 App lifecycle
### ✅ Implement OSLog logging infrastructure (S)

Create logging utilities with subsystem 'com.neuralcanvas.app' and categories: ml-inference, canvas-rendering, persistence, export, ui-events

**Acceptance Criteria**
- Logger instances created for each category
- Log levels properly configured (.debug, .info, .error)
- Logs visible in Console.app with proper filtering
- Helper functions for common logging patterns

**Dependencies**
- Create Xcode project with SwiftUI 6 App lifecycle
### ✅ Define domain error types (S)

Create typed error enums: SketchRecognitionError, StyleMirrorError, ExportError, PersistenceError, RenderingError with LocalizedError conformance

**Acceptance Criteria**
- All error cases from TRD defined
- LocalizedError provides user-facing descriptions
- Errors include underlying error wrapping where specified
- Unit tests verify error descriptions

**Dependencies**
- Create Xcode project with SwiftUI 6 App lifecycle
### ✅ Create Codable value types for vector data (M)

Implement VectorStroke, RecognizedShape, ColorPalette, TypographyScale, SpacingSystem, ShadowStyle as Codable structs for serialization to Data blobs

**Acceptance Criteria**
- All structs conform to Codable
- Round-trip encoding/decoding preserves all data
- CGFloat and CGPoint properly encoded
- Unit tests for serialization

**Dependencies**
- Create Xcode project with SwiftUI 6 App lifecycle

## App Shell & Navigation
**Goal:** Build the main application UI structure with NavigationSplitView and window management

### ✅ Implement NavigationSplitView main layout (M)

Create MainWorkspaceView with three-column NavigationSplitView: sidebar for project list, content for canvas, detail for properties panel

**Acceptance Criteria**
- NavigationSplitView renders with three columns
- Column widths have sensible defaults
- Columns can be collapsed/expanded
- Responds to window resizing gracefully

**Dependencies**
- Configure SwiftData ModelContainer and schema
### ✅ Build SidebarView with project list (M)

Create SidebarView showing list of projects from SwiftData, with selection binding, add/delete functionality

**Acceptance Criteria**
- Projects fetched via @Query macro
- Selection updates NavigationSplitView content
- Add button creates new project
- Swipe-to-delete removes project
- Empty state shown when no projects

**Dependencies**
- Implement NavigationSplitView main layout
### ✅ Configure NSWindow customization for premium feel (S)

Customize window appearance: titlebar transparency, .ultraThinMaterial background, full-size content view, custom window buttons positioning

**Acceptance Criteria**
- Window uses .ultraThinMaterial where appropriate
- Titlebar is transparent with content underneath
- Window has proper minimum size constraints
- Traffic light buttons properly positioned

**Dependencies**
- Implement NavigationSplitView main layout
### ✅ Implement Settings scene (M)

Create SettingsView with Settings scene, including tabs for General, Canvas, Export, and Style Library preferences using @AppStorage

**Acceptance Criteria**
- Settings opens via Cmd+, shortcut
- Preferences persist via @AppStorage
- Tab navigation works correctly
- Settings window has proper size

**Dependencies**
- Implement NavigationSplitView main layout
### ✅ Add MenuBarExtra for quick-capture (M)

Implement MenuBarExtra with quick-capture button that creates new sketch in current project, shows recent projects menu

**Acceptance Criteria**
- Menu bar icon visible when app running
- Quick-capture creates sketch in active project
- Recent projects listed for quick access
- Quit option available in menu

**Dependencies**
- Build SidebarView with project list
### ✅ Set up main menu bar commands (S)

Configure CommandMenu and CommandGroup for File (New Project, New Sketch, Export), Edit (Undo, Redo), View (Zoom controls)

**Acceptance Criteria**
- All menu items have keyboard shortcuts
- Menu items enabled/disabled based on context
- Standard Edit menu commands work
- Export submenu shows format options

**Dependencies**
- Implement NavigationSplitView main layout

## Canvas Rendering Module
**Goal:** Build high-performance Metal-based canvas for drawing and displaying wireframes at 60fps

### ✅ Set up Metal device and command queue (S)

Initialize MTLDevice, MTLCommandQueue, and configure MTLHeap for texture allocation. Handle device unavailable errors gracefully

**Acceptance Criteria**
- Metal device acquired successfully
- Command queue created
- MTLHeap configured with appropriate size
- Graceful error handling if Metal unavailable

**Dependencies**
- Define domain error types
### ✅ Create Metal shader pipeline for stroke rendering (L)

Write Metal shaders for rendering anti-aliased vector strokes with variable width, compile into MTLRenderPipelineState

**Acceptance Criteria**
- Vertex and fragment shaders compile
- Pipeline state created successfully
- Strokes render with anti-aliasing
- Variable stroke width supported

**Dependencies**
- Set up Metal device and command queue
### ✅ Implement CanvasView with MTKView (M)

Create SwiftUI CanvasView wrapping MTKView via NSViewRepresentable, configure for 60fps rendering with proper display link

**Acceptance Criteria**
- MTKView embedded in SwiftUI correctly
- Renders at 60fps when content changes
- Pauses rendering when idle
- Handles view resizing

**Dependencies**
- Create Metal shader pipeline for stroke rendering
### ✅ Handle drawing input events (M)

Capture mouse/trackpad events in canvas, convert to stroke points with pressure sensitivity, accumulate into VectorStroke objects

**Acceptance Criteria**
- Mouse down/drag/up captured correctly
- Points converted to canvas coordinates
- Pressure data captured when available
- Strokes accumulated during drag

**Dependencies**
- Implement CanvasView with MTKView
### ✅ Implement viewport transformations (M)

Add pan and zoom support to canvas using gesture recognizers, maintain transform matrix, clamp zoom to reasonable bounds

**Acceptance Criteria**
- Two-finger pan scrolls canvas
- Pinch gesture zooms canvas
- Zoom clamped between 10% and 1000%
- Zoom centers on gesture point
- Transform persists during session

**Dependencies**
- Handle drawing input events
### ✅ Implement tile-based rendering for large canvases (L)

Divide large wireframes into tiles, render only visible tiles, cache rendered tiles for reuse

**Acceptance Criteria**
- Canvas divided into fixed-size tiles
- Only visible tiles rendered
- Tile cache with LRU eviction
- Smooth scrolling with tile loading

**Dependencies**
- Implement viewport transformations
### ✅ Add visual feedback during ML processing (S)

Show shimmer/pulse animation on strokes being processed, progress indicator for longer operations

**Acceptance Criteria**
- Strokes animate while processing
- Animation uses PhaseAnimator
- Progress indicator for operations > 200ms
- Feedback clears when processing complete

**Dependencies**
- Implement CanvasView with MTKView
### ✅ Implement CanvasRenderingService (M)

Create service conforming to CanvasRendering protocol, orchestrate Metal rendering of strokes and shapes, return MTLTexture

**Acceptance Criteria**
- Service conforms to CanvasRendering protocol
- Renders VectorStroke array to texture
- Renders RecognizedShape array to texture
- Handles viewport and scale parameters

**Dependencies**
- Create Metal shader pipeline for stroke rendering

## Sketch Recognition Module
**Goal:** Implement CoreML-based sketch recognition with real-time inference on Neural Engine

### ✅ Create or obtain CoreML sketch recognition model (L)

Source or train a CoreML model for sketch-to-shape recognition, convert to .mlpackage format, add to Xcode project

**Acceptance Criteria**
- Model file added to project
- Model compiles without errors
- Model input/output shapes documented
- Model size acceptable for bundle

**Dependencies**
_None_
### ✅ Implement model loading with checksum validation (M)

Load CoreML model at app launch with background Task, validate model checksum, handle loading failures gracefully

**Acceptance Criteria**
- Model loads in background Task
- Checksum validated before use
- Loading failure shows user alert
- Model warm state maintained

**Dependencies**
- Create or obtain CoreML sketch recognition model
### ✅ Create SketchRecognitionActor (M)

Implement actor conforming to SketchRecognizing protocol, manage model lifecycle, ensure thread safety

**Acceptance Criteria**
- Actor isolates model access
- processSketch method is async throws
- Model reference held strongly
- Actor off main thread

**Dependencies**
- Implement model loading with checksum validation
### ✅ Implement image preprocessing with Vision framework (M)

Preprocess CGImage input for model: resize, normalize, convert color space using VNImageRequestHandler

**Acceptance Criteria**
- Image resized to model input size
- Pixel values normalized correctly
- Color space converted as needed
- Input validation (64x64 to 8192x8192)

**Dependencies**
- Create SketchRecognitionActor
### ✅ Run inference with Neural Engine preference (M)

Configure MLPredictionOptions with MLComputeUnits.all to prefer Neural Engine, execute prediction, handle cancellation

**Acceptance Criteria**
- MLComputeUnits.all specified
- Prediction runs asynchronously
- Task cancellation supported
- Inference timing logged

**Dependencies**
- Implement image preprocessing with Vision framework
### ✅ Convert model output to RecognizedSketch (M)

Parse model output tensors into VectorStroke and RecognizedShape arrays, calculate confidence scores

**Acceptance Criteria**
- Output tensors correctly parsed
- VectorStroke objects created with points
- RecognizedShape objects created with bounds
- Confidence score calculated

**Dependencies**
- Run inference with Neural Engine preference
### ✅ Implement stroke batching for efficiency (M)

Batch multiple small strokes into single inference calls when drawn in quick succession, debounce processing

**Acceptance Criteria**
- Strokes batched within 100ms window
- Batch sent when user pauses drawing
- Batching improves throughput
- Individual stroke still works

**Dependencies**
- Convert model output to RecognizedSketch
### ✅ Add os_signpost instrumentation for ML pipeline (S)

Instrument preprocessing, inference, and postprocessing with os_signpost for Instruments profiling

**Acceptance Criteria**
- Signposts visible in Instruments
- Preprocessing phase marked
- Inference phase marked
- Postprocessing phase marked

**Dependencies**
- Convert model output to RecognizedSketch

## Style Mirror Module
**Goal:** Extract design tokens from screenshots and apply them to wireframes

### ✅ Create or obtain CoreML style extraction model (L)

Source or train a CoreML model for extracting colors, typography hints, and spacing from UI screenshots

**Acceptance Criteria**
- Model file added to project
- Model compiles without errors
- Model extracts color regions
- Model identifies text areas

**Dependencies**
_None_
### ✅ Implement StyleMirrorActor (M)

Create actor conforming to StyleExtracting and StyleApplying protocols, manage style model lifecycle

**Acceptance Criteria**
- Actor isolates style processing
- Both protocols implemented
- Async throws methods defined
- Actor off main thread

**Dependencies**
- Create or obtain CoreML style extraction model
### ✅ Implement color palette extraction (L)

Extract dominant colors from screenshot using CoreML and Vision, cluster into ColorPalette with primary/secondary/accent

**Acceptance Criteria**
- Dominant colors identified
- Colors clustered meaningfully
- ColorPalette struct populated
- Handles various image types

**Dependencies**
- Implement StyleMirrorActor
### ✅ Implement typography detection (L)

Detect text regions and infer font sizes for typography scale using Vision text recognition

**Acceptance Criteria**
- Text regions detected in image
- Font sizes estimated from bounds
- TypographyScale struct populated
- Handles multiple text sizes

**Dependencies**
- Implement StyleMirrorActor
### ✅ Implement spacing system detection (M)

Analyze element positioning to infer spacing system values (4pt, 8pt, 16pt grid)

**Acceptance Criteria**
- Element bounds analyzed
- Common spacing values identified
- SpacingSystem struct populated
- Grid pattern detected if present

**Dependencies**
- Implement StyleMirrorActor
### ✅ Implement corner radius and shadow detection (M)

Detect corner radii and shadow styles from screenshot analysis

**Acceptance Criteria**
- Corner radii estimated from shapes
- Shadow presence detected
- ShadowStyle struct populated
- Common values aggregated

**Dependencies**
- Implement StyleMirrorActor
### ✅ Implement style application to wireframes (L)

Apply ExtractedStyle to Wireframe elements, mapping colors to element types, applying typography scale

**Acceptance Criteria**
- Colors applied to elements by type
- Typography scale applied to text
- Spacing adjustments applied
- Warnings generated for incompatibilities

**Dependencies**
- Implement corner radius and shadow detection
### ✅ Build screenshot import UI (M)

Create drag-and-drop zone and file picker for importing screenshots to Style Mirror, validate image formats

**Acceptance Criteria**
- Drag-and-drop accepts images
- File picker filters to images
- Invalid formats show error
- Preview of imported image shown

**Dependencies**
- Implement StyleMirrorActor
### ✅ Build style preview UI (M)

Show extracted style tokens visually: color swatches, typography samples, spacing visualization

**Acceptance Criteria**
- Color swatches displayed
- Typography preview with sizes
- Spacing values shown
- Before/after wireframe preview

**Dependencies**
- Implement style application to wireframes

## Persistence Module
**Goal:** Implement robust project and wireframe persistence with SwiftData

### ✅ Implement ProjectPersistenceService (M)

Create service conforming to ProjectPersisting protocol with save, fetch, and delete operations using SwiftData

**Acceptance Criteria**
- Service conforms to protocol
- Save persists project to store
- Fetch retrieves with predicates
- Delete removes with cascade

**Dependencies**
- Configure SwiftData ModelContainer and schema
### ✅ Implement background context operations (M)

Use background ModelContext for heavy operations to keep UI responsive

**Acceptance Criteria**
- Background context created correctly
- Heavy saves use background context
- Main context updated after background work
- No main thread blocking

**Dependencies**
- Implement ProjectPersistenceService
### ✅ Implement canvas data serialization (M)

Serialize/deserialize canvas strokes and shapes to Data for Sketch.canvasData and Wireframe.vectorData

**Acceptance Criteria**
- VectorStroke array serializes to Data
- Data deserializes back correctly
- Large canvas data handles efficiently
- Corruption detection with validation

**Dependencies**
- Create Codable value types for vector data
- Implement ProjectPersistenceService
### ✅ Implement style preset persistence (M)

Save and load StylePreset with serialized color, typography, and spacing data

**Acceptance Criteria**
- StylePreset saves to SwiftData
- All style data serializes correctly
- Thumbnail data stored efficiently
- Built-in presets distinguished from user

**Dependencies**
- Implement ProjectPersistenceService
### ✅ Add schema migration support (M)

Set up VersionedSchema and SchemaMigrationPlan for future schema changes

**Acceptance Criteria**
- VersionedSchema defined for v1
- Migration plan structure in place
- Test migration with sample data
- Documentation for adding migrations

**Dependencies**
- Implement ProjectPersistenceService
### ✅ Configure optional CloudKit sync (L)

Add CloudKit container configuration for optional style library sync, handle sync conflicts

**Acceptance Criteria**
- CloudKit container configured
- Sync toggle in settings
- StyleLibrary syncs when enabled
- Conflict resolution handles duplicates

**Dependencies**
- Implement style preset persistence

## Export Module
**Goal:** Export wireframes to SVG, PDF, and PNG formats

### ✅ Implement ExportService (S)

Create service conforming to Exporting protocol with format-agnostic export entry point

**Acceptance Criteria**
- Service conforms to protocol
- export method dispatches by format
- ExportOptions respected
- Errors thrown for failures

**Dependencies**
- Define domain error types
### ✅ Implement SVG export (L)

Convert wireframe vector data to SVG XML format with proper viewBox, paths, and styles

**Acceptance Criteria**
- Valid SVG XML generated
- VectorStrokes become path elements
- Shapes rendered correctly
- Styles embedded in SVG

**Dependencies**
- Implement ExportService
### ✅ Implement PDF export (L)

Generate PDF document from wireframe using PDFKit and CoreGraphics, preserve vector quality

**Acceptance Criteria**
- Valid PDF generated
- Vector graphics preserved
- Page size matches canvas
- Multiple pages for large canvases

**Dependencies**
- Implement ExportService
### ✅ Implement PNG/JPEG export (M)

Render wireframe to raster image at configurable resolution using CGContext

**Acceptance Criteria**
- PNG export works at multiple DPIs
- JPEG export with quality setting
- Resolution options: 1x, 2x, 3x
- Large exports handle memory

**Dependencies**
- Implement ExportService
### ✅ Build export UI with format picker (M)

Create export sheet with format selection, options configuration, and save panel integration

**Acceptance Criteria**
- Export sheet shows all formats
- Format-specific options shown
- NSSavePanel used for destination
- Progress shown for large exports

**Dependencies**
- Implement PNG/JPEG export
### ✅ Validate file names during export (S)

Sanitize user-provided file names to prevent path traversal and invalid characters

**Acceptance Criteria**
- Path traversal sequences removed
- Invalid characters replaced
- File extension enforced for format
- Maximum length enforced

**Dependencies**
- Implement ExportService

## Progressive Rendering & Performance
**Goal:** Achieve target latencies with progressive rendering and optimizations

### ✅ Implement low-fidelity preview pipeline (L)

Generate quick low-resolution preview within 100ms while full recognition processes

**Acceptance Criteria**
- Preview appears within 100ms
- Preview shows rough shape outlines
- Preview replaced by full quality
- Smooth transition between states

**Dependencies**
- Convert model output to RecognizedSketch
- Implement CanvasView with MTKView
### ✅ Implement frame rate management (M)

Drop canvas to 30fps during active ML inference, return to 60fps when idle

**Acceptance Criteria**
- 60fps maintained when idle
- 30fps during ML processing
- Transition is smooth
- No visual stuttering

**Dependencies**
- Implement CanvasView with MTKView
- Run inference with Neural Engine preference
### ✅ Add performance metrics collection (M)

Collect and log performance metrics: inference latency, frame time, memory usage

**Acceptance Criteria**
- Latency histograms recorded
- Frame time tracked
- Memory usage monitored
- Metrics logged with OSLog

**Dependencies**
- Implement OSLog logging infrastructure
### ✅ Implement memory pressure handling (M)

Monitor memory usage, implement cleanup on memory warnings, retry with backoff after memory errors

**Acceptance Criteria**
- Memory warnings detected
- Caches cleared on pressure
- Operations retry after cleanup
- Stay under 500MB target

**Dependencies**
- Add performance metrics collection
### ✅ Lazy load style library thumbnails (S)

Load StylePreset thumbnails on-demand using AsyncImage pattern to reduce memory footprint

**Acceptance Criteria**
- Thumbnails load lazily
- Placeholder shown while loading
- Memory released when off-screen
- Smooth scrolling in library

**Dependencies**
- Implement style preset persistence

## Error Handling & User Feedback
**Goal:** Implement robust error handling with appropriate user feedback

### ✅ Create @Observable error state manager (S)

Implement observable class to hold current error state, provide localized descriptions for display

**Acceptance Criteria**
- ErrorManager uses @Observable
- Current error exposed as optional
- Localized descriptions available
- Error auto-clears after display

**Dependencies**
- Define domain error types
### ✅ Implement error alert presentation (M)

Show SwiftUI alerts for actionable errors with appropriate actions (retry, dismiss, help)

**Acceptance Criteria**
- Alerts appear for actionable errors
- Retry action available where appropriate
- Help action links to relevant docs
- Alerts dismiss properly

**Dependencies**
- Create @Observable error state manager
### ✅ Implement silent recovery for transient errors (M)

Automatically retry transient failures (memory pressure, temporary unavailability) without user intervention

**Acceptance Criteria**
- Transient errors identified
- Retry with exponential backoff
- Maximum retry count enforced
- User notified only if recovery fails

**Dependencies**
- Create @Observable error state manager
### ✅ Add input validation with user feedback (M)

Validate user inputs (project names, style names, image dimensions) with inline error messages

**Acceptance Criteria**
- Empty names rejected with message
- Image dimension limits enforced
- Validation happens on input
- Clear error messages shown

**Dependencies**
- Create @Observable error state manager

## Testing Infrastructure
**Goal:** Establish comprehensive test coverage with unit, integration, and E2E tests

### ✅ Set up XCTest target with fixtures (S)

Create test target, add fixture images for sketch recognition and style extraction tests

**Acceptance Criteria**
- Test target created and runs
- Fixture images added to bundle
- Fixtures accessible in tests
- Test utilities for common setup

**Dependencies**
- Create Xcode project with SwiftUI 6 App lifecycle
### ✅ Write SketchRecognitionActor unit tests (M)

Test stroke recognition accuracy with fixture images, error handling, cancellation

**Acceptance Criteria**
- Tests for valid input recognition
- Tests for error cases
- Tests for cancellation
- Accuracy threshold assertions

**Dependencies**
- Convert model output to RecognizedSketch
- Set up XCTest target with fixtures
### ✅ Write StyleMirrorActor unit tests (M)

Test color extraction and typography detection with known screenshots

**Acceptance Criteria**
- Tests for color extraction
- Tests for typography detection
- Tests for style application
- Known-good screenshot fixtures

**Dependencies**
- Implement style application to wireframes
- Set up XCTest target with fixtures
### ✅ Write ExportService unit tests (M)

Validate SVG/PDF output structure and content correctness

**Acceptance Criteria**
- SVG structure validated
- PDF structure validated
- Round-trip export/import
- Edge cases covered

**Dependencies**
- Implement PDF export
- Set up XCTest target with fixtures
### ✅ Write SwiftData persistence tests (M)

Test CRUD operations, relationship integrity, serialization round-trips

**Acceptance Criteria**
- Create/read/update/delete tested
- Relationships cascade correctly
- Data serialization round-trips
- In-memory store for test isolation

**Dependencies**
- Implement canvas data serialization
- Set up XCTest target with fixtures
### ✅ Write full pipeline integration test (L)

Test complete flow: sketch input -> recognition -> style application -> export

**Acceptance Criteria**
- End-to-end flow completes
- Output matches expected
- Timing within targets
- No memory leaks

**Dependencies**
- Write ExportService unit tests
- Write SketchRecognitionActor unit tests
### ✅ Set up XCUITest target (M)

Create UI test target with accessibility identifiers on key elements

**Acceptance Criteria**
- UI test target created
- Accessibility identifiers added
- App launches in test mode
- Screenshot capture works

**Dependencies**
- Build SidebarView with project list
### ✅ Write E2E test for new project to export flow (L)

XCUITest covering: create project -> draw sketch -> wait for wireframe -> export

**Acceptance Criteria**
- Full user flow automated
- Assertions on each step
- Export file created
- Test runs reliably

**Dependencies**
- Set up XCUITest target
- Build export UI with format picker
### ✅ Write performance test for sketch-to-wireframe (M)

XCTest performance test asserting < 500ms sketch-to-wireframe on M4

**Acceptance Criteria**
- Measure block used
- Baseline established
- 500ms threshold asserted
- Multiple iterations averaged

**Dependencies**
- Write full pipeline integration test

## Polish & App Store Readiness
**Goal:** Final polish, documentation, and App Store submission preparation

### ✅ Add matchedGeometryEffect transitions (M)

Implement smooth transitions between sketch and wireframe views using matchedGeometryEffect

**Acceptance Criteria**
- Transition animates smoothly
- Elements morph between states
- No animation glitches
- Respects reduce motion setting

**Dependencies**
- Implement CanvasView with MTKView
### ✅ Implement undo/redo for wireframe editing (L)

Add undo/redo stack for wireframe modifications at the snapshot level

**Acceptance Criteria**
- Cmd+Z triggers undo
- Cmd+Shift+Z triggers redo
- Reasonable stack depth
- Memory managed properly

**Dependencies**
- Implement CanvasView with MTKView
### ✅ Add onboarding flow for first launch (M)

Create first-launch onboarding showing key features: drawing, Style Mirror, export

**Acceptance Criteria**
- Onboarding shows on first launch
- Three-step walkthrough
- Can be skipped
- Doesn't show again

**Dependencies**
- Build export UI with format picker
### ✅ Create app icon and assets (M)

Design app icon at all required sizes, add to asset catalog

**Acceptance Criteria**
- Icon at all macOS sizes
- Asset catalog configured
- Icon visible in Dock
- Icon visible in Finder

**Dependencies**
_None_
### ✅ Write App Store metadata (M)

Prepare app name, subtitle, description, keywords, screenshots for App Store Connect

**Acceptance Criteria**
- Name and subtitle finalized
- Description written
- Keywords optimized
- Screenshots captured

**Dependencies**
- Write E2E test for new project to export flow
### ✅ Configure app notarization (M)

Set up notarization workflow for direct download distribution outside App Store

**Acceptance Criteria**
- Developer ID certificate configured
- Notarization script works
- Stapling completes
- App opens without Gatekeeper warning

**Dependencies**
- Create Xcode project with SwiftUI 6 App lifecycle
### ✅ Final sandbox audit (M)

Verify all file operations use sandbox containers, no unauthorized network calls

**Acceptance Criteria**
- All file ops in sandbox
- No URLSession in core code
- Entitlements minimal
- Security review complete

**Dependencies**
- Write full pipeline integration test

## ❓ Open Questions
- Should Style Mirror support extracting styles from Figma/Sketch file imports in addition to screenshots?
- What is the acceptable bundle size increase for higher-accuracy CoreML models vs quantized versions?
- Should we support iPad via Mac Catalyst or keep macOS-exclusive for optimal UX?
- How granular should the style extraction be - component-level or screen-level tokens?
- Should we implement undo/redo at the stroke level or wireframe snapshot level?
- What is the sourcing strategy for CoreML models - train custom, use existing, or partner with ML provider?
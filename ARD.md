# Architecture Requirements Document

## 🧱 System Overview
NeuralCanvas is a native macOS application that transforms hand-drawn sketches into high-fidelity UI wireframes using on-device machine learning. The app follows a local-first architecture with all ML inference running on the M4 Neural Engine via CoreML, ensuring complete data privacy. The architecture centers around a reactive SwiftUI 6 interface backed by SwiftData persistence, with optional CloudKit synchronization for style libraries across devices.

## 🏗 Architecture Style
Local-first native macOS application with reactive UI layer, on-device ML inference engine, and persistent document-based storage. Single-process architecture with structured concurrency for parallelized sketch processing and real-time canvas rendering.

## 🎨 Frontend Architecture
- **Framework:** SwiftUI 6 with .ultraThinMaterial and .regularMaterial styling, NSWindow customization for borderless premium appearance, Menu bar quick-capture integration, and Settings scene for preferences
- **State Management:** Observation framework (@Observable) for reactive state propagation, @Environment for dependency injection, @Bindable for two-way bindings in forms and canvas interactions
- **Routing:** NavigationSplitView for main workspace with sidebar project navigation, WindowGroup for primary canvas, MenuBarExtra for quick-capture, Settings scene for preferences panel
- **Build Tooling:** Xcode 16+ with Swift 6 language mode, CoreML model compilation via coremlcompiler, Metal shader precompilation, asset catalog for bundled style presets

## 🧠 Backend Architecture
- **Approach:** No server backend required. All processing occurs on-device using Swift 6 structured concurrency (async/await, TaskGroups, actors) for parallelized ML inference and image processing pipelines
- **API Style:** No network API. Internal service communication via Swift protocols and async/await, with actor isolation for thread-safe ML model access
- **Services:**
- SketchRecognitionService: CoreML-powered actor for real-time sketch-to-vector conversion with Vision framework preprocessing
- StyleMirrorService: Extracts design tokens (colors, spacing, typography) from screenshots using CoreML image analysis
- CanvasRenderingService: Metal shader pipeline for real-time drawing feedback and visual effects at 60fps
- ExportService: Converts vector wireframes to SVG, PDF, and raster formats using CoreGraphics and PDFKit
- ProjectPersistenceService: SwiftData ModelContainer management with background context for heavy operations

## 🗄 Data Layer
- **Primary Store:** SwiftData with local SQLite storage for projects, sketches, wireframes, and style libraries. ModelContainer configured with autosave and undo support
- **Relationships:** Project contains multiple Sketches and Wireframes (one-to-many). StyleLibrary contains StylePresets (one-to-many). Wireframe references optional StylePreset (many-to-one optional)
- **Migrations:** SwiftData schema versioning with lightweight migrations. VersionedSchema conformance for future model evolution without data loss

## ☁️ Infrastructure
- **Hosting:** Fully local macOS application distributed via Mac App Store and direct notarized download. No server infrastructure required
- **Scaling Strategy:** Single-user desktop application. Performance scaling via Neural Engine utilization, Metal GPU acceleration, and TaskGroup parallelization for batch operations
- **CI/CD:** Xcode Cloud for automated builds, TestFlight for beta distribution, fastlane for App Store submission automation, XCTest for unit and UI testing

## ⚖️ Key Trade-offs
- Privacy over features: All ML runs on-device, sacrificing potential cloud model improvements for complete data privacy
- Bundle size over download speed: Embedding CoreML models increases app size but eliminates runtime downloads and network dependencies
- macOS exclusivity over reach: Native SwiftUI 6 and Metal enable premium UX but limit to Apple Silicon Mac users only
- Local-first over collaboration: SwiftData with optional CloudKit sync prioritizes offline capability over real-time multi-user editing
- Simplicity over extensibility: Direct CoreML integration rather than plugin architecture keeps codebase maintainable but limits third-party model integration

## 📐 Non-Functional Requirements
- macOS 15+ (Sequoia) minimum deployment target with Apple Silicon requirement
- Sketch-to-wireframe conversion latency under 500ms on M4 Neural Engine
- Memory footprint under 500MB during active ML inference
- 60fps canvas rendering using Metal shaders and matchedGeometryEffect animations
- Zero network calls for core sketch recognition and Style Mirror functionality
- App bundle size optimized with CoreML model quantization while maintaining 95%+ recognition accuracy
- Accessibility support via VoiceOver, keyboard navigation, and Dynamic Type in UI controls
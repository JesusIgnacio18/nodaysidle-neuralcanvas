# NeuralCanvas

## 🎯 Product Vision
A privacy-first macOS design tool that empowers developers and designers to transform rough hand-drawn sketches into polished UI wireframes instantly using on-device machine learning, eliminating the gap between ideation and implementation.

## ❓ Problem Statement
Designers and developers waste significant time manually converting rough sketches into digital wireframes. Existing tools either require cloud processing (risking IP exposure) or produce low-quality results. There is no solution that combines real-time sketch-to-wireframe conversion with design system matching while keeping all processing local and private.

## 🎯 Goals
- Enable real-time conversion of hand-drawn sketches to high-fidelity vector wireframes
- Keep all ML processing on-device using M4 Neural Engine for complete privacy
- Allow users to match existing design systems via Style Mirror feature
- Deliver a premium native macOS experience with fluid animations
- Support local-first architecture with optional CloudKit sync

## 🚫 Non-Goals
- Server-side processing or cloud-based ML inference
- Cross-platform support (iOS, Windows, Linux)
- Full design tool replacement (Figma, Sketch)
- Code generation from wireframes
- Collaborative real-time editing

## 👥 Target Users
- Product designers rapidly prototyping UI concepts
- Indie developers sketching app interfaces
- UX researchers creating quick mockups during user interviews
- Design agencies maintaining consistent client design systems
- Developers who think visually but lack design tool proficiency

## 🧩 Core Features
- Real-time sketch recognition and vector conversion using CoreML
- Style Mirror: extract design systems from existing app screenshots
- Canvas with pressure-sensitive drawing support
- Component library with auto-detected UI elements (buttons, inputs, cards)
- Export to SVG, PDF, and standard image formats
- Menu bar quick-capture for instant sketch conversion
- Settings scene for model preferences and style presets
- SwiftData persistence for projects and style libraries

## ⚙️ Non-Functional Requirements
- macOS 15+ (Sequoia) minimum target
- Sketch-to-wireframe conversion under 500ms on M4 hardware
- Zero network calls for core functionality
- Memory footprint under 500MB during active inference
- Native SwiftUI 6 interface with .ultraThinMaterial and .regularMaterial styling
- Smooth 60fps animations using matchedGeometryEffect and PhaseAnimator
- NSWindow customization for premium borderless appearance

## 📊 Success Metrics
- Sketch recognition accuracy above 95% for common UI elements
- Time from sketch to exportable wireframe under 2 seconds
- User retention rate of 40% after 30 days
- App Store rating of 4.5+ stars
- Style Mirror matching accuracy rated satisfactory by 80% of users

## 📌 Assumptions
- Users have Apple Silicon Macs (M1 or later, optimized for M4)
- CoreML models can be bundled within reasonable app size limits
- Users prefer privacy over cloud-based feature enhancements
- Hand-drawn sketches follow loosely conventional UI patterns
- Metal shaders will provide sufficient performance for visual effects

## ❓ Open Questions
- What is the maximum acceptable app bundle size with embedded ML models?
- Should Style Mirror support multiple design systems per project?
- How should the app handle non-UI sketches or ambiguous drawings?
- What CloudKit sync granularity is appropriate for style libraries?
- Should TimelineView be used for real-time drawing feedback or processing indicators?
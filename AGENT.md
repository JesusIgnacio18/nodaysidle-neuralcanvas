# Agent Prompts — NeuralCanvas

## 🧭 Global Rules

### ✅ Do
- Use SwiftUI 6 with @Observable macro for state management
- Use SwiftData for all persistence with @Model classes
- Use Swift 6 structured concurrency (async/await, actors)
- Target macOS 15+ with Apple Silicon optimization
- Use OSLog for all logging with subsystem 'com.neuralcanvas.app'

### ❌ Don’t
- Do not create any backend server - this is local-first
- Do not use UIKit or AppKit directly except for NSWindow customization
- Do not use any third-party dependencies for core functionality
- Do not use Combine - prefer async/await and Observation
- Do not store sensitive data outside sandbox containers

## 🧩 Task Prompts
## Project Foundation & Data Models

**Context**
Initialize the NeuralCanvas macOS app with SwiftUI 6, SwiftData persistence, and core domain types for sketch-to-wireframe processing

### Universal Agent Prompt
```
ROLE: Expert Swift macOS Engineer

GOAL: Create Xcode project with SwiftData models and domain types

CONTEXT: Initialize the NeuralCanvas macOS app with SwiftUI 6, SwiftData persistence, and core domain types for sketch-to-wireframe processing

FILES TO CREATE:
- NeuralCanvas/NeuralCanvasApp.swift
- NeuralCanvas/Models/Project.swift
- NeuralCanvas/Models/Sketch.swift
- NeuralCanvas/Models/Wireframe.swift
- NeuralCanvas/Models/StylePreset.swift
- NeuralCanvas/Domain/VectorTypes.swift
- NeuralCanvas/Domain/Errors.swift
- NeuralCanvas/Utilities/Logger.swift

FILES TO MODIFY:
_None_

DETAILED STEPS:
1. Create macOS 15+ SwiftUI App with bundle ID com.neuralcanvas.app, configure Info.plist with camera and file access permissions
2. Define @Model classes: Project (id, name, createdAt, sketches relationship), Sketch (id, name, canvasData, wireframe relationship), Wireframe (id, vectorData, appliedStyle), StylePreset (id, name, colorPalette, typography, spacing, thumbnail)
3. Create Codable structs: VectorStroke (points, width, color), RecognizedShape (type, bounds, confidence), ColorPalette, TypographyScale, SpacingSystem, ShadowStyle
4. Define error enums with LocalizedError: SketchRecognitionError, StyleMirrorError, ExportError, PersistenceError, RenderingError
5. Set up OSLog with Logger instances for categories: ml-inference, canvas-rendering, persistence, export, ui-events

VALIDATION:
xcodebuild -scheme NeuralCanvas -destination 'platform=macOS' build
```
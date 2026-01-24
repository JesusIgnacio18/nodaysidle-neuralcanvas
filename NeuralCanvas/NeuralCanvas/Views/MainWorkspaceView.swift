import SwiftUI
import SwiftData

/// Main workspace view with three-column NavigationSplitView layout
struct MainWorkspaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState: AppState?
    @Query(sort: \Project.modifiedAt, order: .reverse) private var projects: [Project]

    @State private var selectedProject: Project?
    @State private var selectedSketch: Sketch?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showStyleImport = false
    @State private var extractedStyle: ExtractedStyle?
    @State private var isProcessingStyle = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar - Project List
            SidebarView(
                selectedProject: $selectedProject,
                selectedSketch: $selectedSketch
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 350)
        } content: {
            // Content - Canvas Area
            CanvasAreaView(
                project: selectedProject,
                selectedSketch: $selectedSketch
            )
            .navigationSplitViewColumnWidth(min: 400, ideal: 600, max: .infinity)
        } detail: {
            // Detail - Properties Panel
            PropertiesPanelView(
                project: selectedProject,
                sketch: selectedSketch
            )
            .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            // Select first project if none selected
            if selectedProject == nil, let firstProject = projects.first {
                selectedProject = firstProject
            }
        }
        .onChange(of: projects) { _, newProjects in
            // Handle project deletion
            if let selected = selectedProject, !newProjects.contains(where: { $0.id == selected.id }) {
                selectedProject = newProjects.first
                selectedSketch = nil
            }
        }
        .onChange(of: appState?.shouldImportStyle) { _, shouldImport in
            if shouldImport == true {
                showStyleImport = true
                appState?.shouldImportStyle = false
            }
        }
        .sheet(isPresented: $showStyleImport) {
            StyleImportSheet(
                extractedStyle: $extractedStyle,
                isProcessing: $isProcessingStyle
            )
        }
    }
}

// MARK: - Style Import Sheet

struct StyleImportSheet: View {
    @Binding var extractedStyle: ExtractedStyle?
    @Binding var isProcessing: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Import Style from Image")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            // Style import view
            StyleImportView(
                extractedStyle: $extractedStyle,
                isProcessing: $isProcessing
            )

            // Show extracted style preview
            if let style = extractedStyle {
                Divider()
                ExtractedStylePreview(style: style)
                    .padding()
            }
        }
        .frame(width: 500, height: 600)
    }
}

// MARK: - Extracted Style Preview

struct ExtractedStylePreview: View {
    let style: ExtractedStyle

    private var paletteColors: [CodableColor] {
        [
            style.colorPalette.primary,
            style.colorPalette.secondary,
            style.colorPalette.accent,
            style.colorPalette.background,
            style.colorPalette.surface
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Extracted Colors")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack(spacing: 8) {
                ForEach(Array(paletteColors.enumerated()), id: \.offset) { _, color in
                    Circle()
                        .fill(Color(red: Double(color.red), green: Double(color.green), blue: Double(color.blue)))
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
                }
            }

            Text("Style extracted successfully!")
                .font(.caption)
                .foregroundStyle(.green)
        }
    }
}

// MARK: - Canvas Area View

/// Main canvas area showing the current sketch or placeholder
struct CanvasAreaView: View {
    let project: Project?
    @Binding var selectedSketch: Sketch?

    var body: some View {
        Group {
            if let project = project {
                if let sketch = selectedSketch {
                    SketchCanvasView(sketch: sketch)
                } else if let latestSketch = project.latestSketch {
                    SketchCanvasView(sketch: latestSketch)
                        .onAppear {
                            selectedSketch = latestSketch
                        }
                } else {
                    EmptyCanvasView(project: project)
                }
            } else {
                NoProjectSelectedView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Sketch Canvas View

/// Canvas view for drawing and displaying sketches using Metal
struct SketchCanvasView: View {
    let sketch: Sketch

    @State private var canvasState = CanvasState()
    @State private var selectedTool: CanvasTool = .pen
    @State private var viewMode: CanvasViewMode = .sketch
    @State private var showShapes = false
    @State private var undoManager = UndoRedoManager()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar with view mode selector
            HStack {
                CanvasToolbar(
                    selectedTool: $selectedTool,
                    canvasState: $canvasState,
                    onUndo: handleUndo,
                    onRedo: handleRedo,
                    onClear: handleClear
                )

                Spacer()

                ViewModeToolbar(viewMode: $viewMode)
            }
            .padding(.horizontal, 8)

            // Color picker - bind directly to canvasState
            ColorPickerToolbar(
                strokeColor: Binding(
                    get: { canvasState.currentStrokeColor },
                    set: { canvasState.currentStrokeColor = $0 }
                ),
                strokeWidth: Binding(
                    get: { canvasState.currentStrokeWidth },
                    set: { canvasState.currentStrokeWidth = $0 }
                )
            )

            Divider()

            // Morphing canvas container with transitions
            MorphingCanvasContainer(viewMode: $viewMode) {
                // Sketch view
                ZStack {
                    MetalCanvasView(
                        canvasState: $canvasState,
                        selectedTool: $selectedTool,
                        onDraw: { _, _ in },
                        onDrawEnd: handleDrawEnd
                    )

                    // Processing indicator
                    if canvasState.isProcessing {
                        ProcessingFeedbackView(
                            isProcessing: canvasState.isProcessing,
                            progress: canvasState.processingProgress
                        )
                    }
                }
            } wireframeContent: {
                // Wireframe view with shape morphing
                ZStack {
                    Color(nsColor: .controlBackgroundColor)

                    ShapeMorphingView(
                        shapes: canvasState.recognizedShapes,
                        isVisible: showShapes
                    )
                }
                .onAppear {
                    withAnimation(reduceMotion ? .none : .spring(duration: 0.5)) {
                        showShapes = true
                    }
                }
                .onDisappear {
                    showShapes = false
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            loadSketchData()
        }
        .onChange(of: sketch.id) { _, _ in
            loadSketchData()
            showShapes = false
        }
    }

    private func loadSketchData() {
        // Load existing canvas data from sketch
        if let data = try? sketch.getCanvasData() {
            canvasState.strokes = data.strokes
            canvasState.recognizedShapes = data.recognizedShapes
        }
    }

    private func saveCanvasData() {
        let data = CanvasData(
            strokes: canvasState.strokes,
            recognizedShapes: canvasState.recognizedShapes
        )
        try? sketch.setCanvasData(data)
    }

    private func handleUndo() {
        // Push current state before undoing if this is the first undo
        if undoManager.undoCount == 0 && !canvasState.strokes.isEmpty {
            undoManager.pushSnapshot(strokes: canvasState.strokes, shapes: canvasState.recognizedShapes)
        }

        if let snapshot = undoManager.undo(
            currentStrokes: canvasState.strokes,
            currentShapes: canvasState.recognizedShapes
        ) {
            canvasState.restore(from: snapshot)
            saveCanvasData()
        }
    }

    private func handleRedo() {
        if let snapshot = undoManager.redo(
            currentStrokes: canvasState.strokes,
            currentShapes: canvasState.recognizedShapes
        ) {
            canvasState.restore(from: snapshot)
            saveCanvasData()
        }
    }

    private func handleClear() {
        // Save current state before clearing
        undoManager.pushSnapshot(strokes: canvasState.strokes, shapes: canvasState.recognizedShapes)
        canvasState.clearAll()
        saveCanvasData()
    }

    private func handleDrawEnd() {
        // Save snapshot for undo before saving
        undoManager.pushSnapshot(strokes: canvasState.strokes, shapes: canvasState.recognizedShapes)
        saveCanvasData()
    }
}

// MARK: - Empty Canvas View

/// Shown when a project has no sketches
struct EmptyCanvasView: View {
    let project: Project
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "scribble.variable")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Sketches Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Create a new sketch to start designing")
                .font(.body)
                .foregroundStyle(.secondary)

            Button(action: createNewSketch) {
                Label("New Sketch", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func createNewSketch() {
        let sketch = Sketch.newSketch(in: project)
        modelContext.insert(sketch)
        project.addSketch(sketch)
        AppLogger.uiEvents.info("Created new sketch in project: \(project.name)")
    }
}

// MARK: - No Project Selected View

/// Shown when no project is selected
struct NoProjectSelectedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Project Selected")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Select a project from the sidebar or create a new one")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    MainWorkspaceView()
        .modelContainer(for: [Project.self, Sketch.self, Wireframe.self, StylePreset.self, StyleLibrary.self], inMemory: true)
}

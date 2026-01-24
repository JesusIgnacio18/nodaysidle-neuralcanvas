import SwiftUI
import SwiftData

/// NeuralCanvas - Transform hand-drawn sketches into polished UI wireframes
@main
struct NeuralCanvasApp: App {
    // MARK: - SwiftData Configuration

    /// Shared model container for all SwiftData models
    var modelContainer: ModelContainer

    // MARK: - App State

    @State private var appState = AppState()

    // MARK: - Initialization

    init() {
        // Configure SwiftData schema with all model types
        let schema = Schema([
            Project.self,
            Sketch.self,
            Wireframe.self,
            StylePreset.self,
            StyleLibrary.self
        ])

        // Configure model container with schema versioning
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            AppLogger.general.info("SwiftData ModelContainer initialized successfully")
        } catch {
            AppLogger.general.error("Failed to initialize ModelContainer: \(error.localizedDescription)")
            // Create in-memory fallback container
            do {
                let fallbackConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true
                )
                modelContainer = try ModelContainer(
                    for: schema,
                    configurations: [fallbackConfig]
                )
                AppLogger.general.warning("Using in-memory fallback storage")
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }

    // MARK: - App Body

    var body: some Scene {
        // Main application window
        WindowGroup {
            MainWorkspaceView()
                .frame(minWidth: 900, minHeight: 600)
                .premiumWindowStyle()
                .environment(appState)
                .withOnboarding()
        }
        .modelContainer(modelContainer)
        .windowStyle(.automatic)
        .windowResizability(.contentMinSize)
        .commands {
            AppCommands(appState: appState)
        }

        // Settings window
        Settings {
            AppSettingsView()
        }

        // Menu bar extra for quick capture
        MenuBarExtra("NeuralCanvas", systemImage: "pencil.and.outline") {
            MenuBarContentView()
                .modelContainer(modelContainer)
                .environment(appState)
        }
        .menuBarExtraStyle(.menu)
    }
}

// MARK: - App State

/// Observable app state for cross-view communication
@Observable
final class AppState {
    var shouldCreateNewProject = false
    var shouldCreateNewSketch = false
    var shouldExportWireframe = false
    var shouldImportStyle = false
    var zoomLevel: Double = 1.0

    func triggerNewProject() {
        shouldCreateNewProject = true
    }

    func triggerNewSketch() {
        shouldCreateNewSketch = true
    }

    func triggerExport() {
        shouldExportWireframe = true
    }

    func triggerImportStyle() {
        shouldImportStyle = true
    }

    func zoomIn() {
        zoomLevel = min(10.0, zoomLevel * 1.25)
    }

    func zoomOut() {
        zoomLevel = max(0.1, zoomLevel / 1.25)
    }

    func zoomToFit() {
        zoomLevel = 1.0
    }
}

// MARK: - App Commands

/// Menu bar commands for the application
struct AppCommands: Commands {
    let appState: AppState

    var body: some Commands {
        // File menu
        CommandGroup(replacing: .newItem) {
            Button("New Project") {
                appState.triggerNewProject()
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button("New Sketch") {
                appState.triggerNewSketch()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Divider()

            Menu("Export") {
                Button("Export as SVG...") {
                    appState.triggerExport()
                }
                .keyboardShortcut("e", modifiers: [.command])

                Button("Export as PDF...") {
                    appState.triggerExport()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Button("Export as PNG...") {
                    appState.triggerExport()
                }

                Button("Export as JPEG...") {
                    appState.triggerExport()
                }
            }

            Divider()

            Button("Import Style from Image...") {
                appState.triggerImportStyle()
            }
            .keyboardShortcut("i", modifiers: [.command])
        }

        // View menu
        CommandGroup(after: .toolbar) {
            Divider()

            Button("Zoom In") {
                appState.zoomIn()
            }
            .keyboardShortcut("+", modifiers: [.command])

            Button("Zoom Out") {
                appState.zoomOut()
            }
            .keyboardShortcut("-", modifiers: [.command])

            Button("Zoom to Fit") {
                appState.zoomToFit()
            }
            .keyboardShortcut("0", modifiers: [.command])

            Divider()
        }
    }
}

// MARK: - Menu Bar Content View

/// Content for the menu bar extra
struct MenuBarContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \Project.modifiedAt, order: .reverse) private var recentProjects: [Project]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Quick capture
            Button {
                createQuickSketch()
            } label: {
                Label("Quick Capture", systemImage: "plus.circle")
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Divider()

            // Recent projects
            if recentProjects.isEmpty {
                Text("No Recent Projects")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                Text("Recent Projects")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 4)

                ForEach(recentProjects.prefix(5)) { project in
                    Button {
                        openProject(project)
                    } label: {
                        Label(project.name, systemImage: "folder")
                    }
                }
            }

            Divider()

            // New project
            Button {
                appState.triggerNewProject()
            } label: {
                Label("New Project...", systemImage: "folder.badge.plus")
            }

            Divider()

            // Quit
            Button("Quit NeuralCanvas") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
    }

    private func createQuickSketch() {
        // Create sketch in most recent project or create new project
        if let project = recentProjects.first {
            let sketch = Sketch.newSketch(in: project)
            modelContext.insert(sketch)
            project.addSketch(sketch)
            AppLogger.uiEvents.info("Quick capture: Created sketch in \(project.name)")
        } else {
            let project = Project(name: "Quick Capture")
            modelContext.insert(project)
            let sketch = Sketch.newSketch(in: project)
            modelContext.insert(sketch)
            project.addSketch(sketch)
            AppLogger.uiEvents.info("Quick capture: Created new project with sketch")
        }
    }

    private func openProject(_ project: Project) {
        // Touch project to update modified date
        project.touch()
        AppLogger.uiEvents.info("Opening project from menu bar: \(project.name)")
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let newProject = Notification.Name("com.neuralcanvas.newProject")
    static let newSketch = Notification.Name("com.neuralcanvas.newSketch")
    static let exportWireframe = Notification.Name("com.neuralcanvas.exportWireframe")
}

// MARK: - Preview

#Preview {
    MainWorkspaceView()
        .modelContainer(for: [Project.self, Sketch.self, Wireframe.self, StylePreset.self, StyleLibrary.self], inMemory: true)
        .environment(AppState())
}

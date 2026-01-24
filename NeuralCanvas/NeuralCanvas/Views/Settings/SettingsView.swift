import SwiftUI

/// Settings view with multiple tabs for app preferences
struct AppSettingsView: View {
    private enum SettingsTab: String, Hashable {
        case general = "General"
        case canvas = "Canvas"
        case export = "Export"
        case styleLibrary = "Style Library"
    }

    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(SettingsTab.general)

            CanvasSettingsView()
                .tabItem {
                    Label("Canvas", systemImage: "square.grid.3x3")
                }
                .tag(SettingsTab.canvas)

            ExportSettingsView()
                .tabItem {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .tag(SettingsTab.export)

            StyleLibrarySettingsView()
                .tabItem {
                    Label("Style Library", systemImage: "paintpalette")
                }
                .tag(SettingsTab.styleLibrary)
        }
        .frame(width: 500, height: 350)
        .padding()
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @AppStorage("autoSaveEnabled") private var autoSaveEnabled = true
    @AppStorage("autoSaveInterval") private var autoSaveInterval = 60
    @AppStorage("showWelcomeOnLaunch") private var showWelcomeOnLaunch = true
    @AppStorage("confirmBeforeDelete") private var confirmBeforeDelete = true

    var body: some View {
        Form {
            Section {
                Toggle("Auto-save projects", isOn: $autoSaveEnabled)

                if autoSaveEnabled {
                    Picker("Auto-save interval", selection: $autoSaveInterval) {
                        Text("30 seconds").tag(30)
                        Text("1 minute").tag(60)
                        Text("2 minutes").tag(120)
                        Text("5 minutes").tag(300)
                    }
                }
            } header: {
                Text("Saving")
            }

            Section {
                Toggle("Show welcome screen on launch", isOn: $showWelcomeOnLaunch)
                Toggle("Confirm before deleting projects", isOn: $confirmBeforeDelete)
            } header: {
                Text("Behavior")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Canvas Settings

struct CanvasSettingsView: View {
    @AppStorage("canvasGridEnabled") private var canvasGridEnabled = true
    @AppStorage("canvasGridSize") private var canvasGridSize = 8
    @AppStorage("snapToGrid") private var snapToGrid = true
    @AppStorage("showRulers") private var showRulers = false
    @AppStorage("defaultCanvasWidth") private var defaultCanvasWidth = 1920
    @AppStorage("defaultCanvasHeight") private var defaultCanvasHeight = 1080
    @AppStorage("strokeSmoothing") private var strokeSmoothing = 0.5

    var body: some View {
        Form {
            Section {
                Toggle("Show grid", isOn: $canvasGridEnabled)

                if canvasGridEnabled {
                    Picker("Grid size", selection: $canvasGridSize) {
                        Text("4px").tag(4)
                        Text("8px").tag(8)
                        Text("16px").tag(16)
                        Text("32px").tag(32)
                    }

                    Toggle("Snap to grid", isOn: $snapToGrid)
                }

                Toggle("Show rulers", isOn: $showRulers)
            } header: {
                Text("Grid & Guides")
            }

            Section {
                HStack {
                    Text("Default size")
                    Spacer()
                    TextField("Width", value: $defaultCanvasWidth, format: .number)
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                    Text("×")
                    TextField("Height", value: $defaultCanvasHeight, format: .number)
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                    Text("px")
                }
            } header: {
                Text("Canvas Size")
            }

            Section {
                HStack {
                    Text("Stroke smoothing")
                    Slider(value: $strokeSmoothing, in: 0...1)
                    Text(String(format: "%.0f%%", strokeSmoothing * 100))
                        .frame(width: 40)
                }
            } header: {
                Text("Drawing")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Export Settings

struct ExportSettingsView: View {
    @AppStorage("defaultExportFormat") private var defaultExportFormat = "svg"
    @AppStorage("defaultExportScale") private var defaultExportScale = 2
    @AppStorage("includeMetadata") private var includeMetadata = true
    @AppStorage("jpegQuality") private var jpegQuality = 0.9

    var body: some View {
        Form {
            Section {
                Picker("Default format", selection: $defaultExportFormat) {
                    Text("SVG").tag("svg")
                    Text("PDF").tag("pdf")
                    Text("PNG").tag("png")
                    Text("JPEG").tag("jpeg")
                }

                Picker("Default scale", selection: $defaultExportScale) {
                    Text("1x").tag(1)
                    Text("2x").tag(2)
                    Text("3x").tag(3)
                }
            } header: {
                Text("Format")
            }

            Section {
                Toggle("Include metadata in exported files", isOn: $includeMetadata)

                HStack {
                    Text("JPEG quality")
                    Slider(value: $jpegQuality, in: 0.1...1.0)
                    Text(String(format: "%.0f%%", jpegQuality * 100))
                        .frame(width: 40)
                }
            } header: {
                Text("Options")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Style Library Settings

struct StyleLibrarySettingsView: View {
    @AppStorage("syncStyleLibrary") private var syncStyleLibrary = false
    @AppStorage("autoExtractStyles") private var autoExtractStyles = true

    var body: some View {
        Form {
            Section {
                Toggle("Sync style library with iCloud", isOn: $syncStyleLibrary)

                if syncStyleLibrary {
                    Text("Your style presets will sync across all your devices signed into iCloud.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Sync")
            }

            Section {
                Toggle("Auto-extract styles from imported screenshots", isOn: $autoExtractStyles)

                Text("When enabled, NeuralCanvas will automatically analyze imported screenshots and extract color palettes, typography, and spacing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Style Extraction")
            }

            Section {
                Button("Reset to Default Styles") {
                    // Will be implemented in Style Mirror module
                }
                .foregroundStyle(.red)
            } header: {
                Text("Reset")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Preview

#Preview {
    AppSettingsView()
}

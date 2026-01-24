import SwiftUI
import SwiftData

/// Properties panel showing details for selected project or sketch
struct PropertiesPanelView: View {
    let project: Project?
    let sketch: Sketch?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let sketch = sketch {
                    SketchPropertiesSection(sketch: sketch)
                } else if let project = project {
                    ProjectPropertiesSection(project: project)
                } else {
                    NoSelectionView()
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Sketch Properties Section

struct SketchPropertiesSection: View {
    @Bindable var sketch: Sketch
    @State private var isEditingName = false
    @State private var editedName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "scribble")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Sketch Properties")
                    .font(.headline)
            }

            Divider()

            // Name
            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if isEditingName {
                    HStack {
                        TextField("Sketch Name", text: $editedName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(saveName)

                        Button("Save") {
                            saveName()
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    HStack {
                        Text(sketch.displayName)
                            .font(.body)
                        Spacer()
                        Button {
                            editedName = sketch.name ?? ""
                            isEditingName = true
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            // Created date
            VStack(alignment: .leading, spacing: 4) {
                Text("Created")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(sketch.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.body)
            }

            // Modified date
            VStack(alignment: .leading, spacing: 4) {
                Text("Modified")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(sketch.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.body)
            }

            // Status
            VStack(alignment: .leading, spacing: 4) {
                Text("Status")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Circle()
                        .fill(sketch.isProcessed ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(sketch.isProcessed ? "Processed" : "Draft")
                        .font(.body)
                }
            }

            Divider()

            // Wireframe info
            if let wireframe = sketch.generatedWireframe {
                WireframeInfoSection(wireframe: wireframe)
            } else {
                Text("No wireframe generated yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func saveName() {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        sketch.name = trimmed.isEmpty ? nil : trimmed
        isEditingName = false
    }
}

// MARK: - Wireframe Info Section

struct WireframeInfoSection: View {
    let wireframe: Wireframe

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Generated Wireframe")
                .font(.subheadline)
                .fontWeight(.semibold)

            HStack {
                Label("\(wireframe.shapeCount) shapes", systemImage: "rectangle.3.group")
                Spacer()
                Label(String(format: "%.0f%% confidence", wireframe.confidence * 100), systemImage: "checkmark.seal")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if wireframe.hasAppliedStyle {
                if let styleRef = try? wireframe.getAppliedStyle() {
                    Label("Style: \(styleRef.presetName)", systemImage: "paintpalette")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color.accentColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Project Properties Section

struct ProjectPropertiesSection: View {
    @Bindable var project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "folder")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Project Properties")
                    .font(.headline)
            }

            Divider()

            // Name
            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(project.name)
                    .font(.body)
            }

            // Stats
            VStack(alignment: .leading, spacing: 4) {
                Text("Contents")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 16) {
                    Label("\(project.sketchCount) sketches", systemImage: "scribble")
                    Label("\(project.wireframeCount) wireframes", systemImage: "rectangle.3.group")
                }
                .font(.caption)
            }

            // Created date
            VStack(alignment: .leading, spacing: 4) {
                Text("Created")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(project.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.body)
            }

            // Modified date
            VStack(alignment: .leading, spacing: 4) {
                Text("Modified")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(project.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.body)
            }

            Divider()

            // Style preset
            VStack(alignment: .leading, spacing: 8) {
                Text("Style Preset")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if project.selectedStylePresetId != nil {
                    Text("Custom preset selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Default style")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Change Style...") {
                    // Will open style picker in future task
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}

// MARK: - No Selection View

struct NoSelectionView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sidebar.right")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("No Selection")
                .font(.headline)

            Text("Select a project or sketch to view its properties")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Preview

#Preview {
    PropertiesPanelView(project: nil, sketch: nil)
        .frame(width: 300, height: 500)
}

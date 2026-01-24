import SwiftUI
import SwiftData

/// Sidebar view showing project list with CRUD operations
struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.modifiedAt, order: .reverse) private var projects: [Project]

    @Binding var selectedProject: Project?
    @Binding var selectedSketch: Sketch?

    @State private var isShowingNewProjectSheet = false
    @State private var searchText = ""

    private var filteredProjects: [Project] {
        if searchText.isEmpty {
            return projects
        }
        return projects.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search projects", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.regularMaterial)

            Divider()

            // Project list
            if filteredProjects.isEmpty {
                EmptyProjectListView(searchText: searchText)
            } else {
                List(selection: $selectedProject) {
                    ForEach(filteredProjects) { project in
                        ProjectRowView(
                            project: project,
                            isSelected: selectedProject?.id == project.id
                        )
                        .tag(project)
                        .contextMenu {
                            projectContextMenu(for: project)
                        }
                    }
                    .onDelete(perform: deleteProjects)
                }
                .listStyle(.sidebar)
            }
        }
        .safeAreaInset(edge: .bottom) {
            // Bottom toolbar
            HStack {
                Button(action: { isShowingNewProjectSheet = true }) {
                    Label("New Project", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .help("Create a new project")

                Spacer()

                Text("\(projects.count) project\(projects.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial)
        }
        .navigationTitle("Projects")
        .sheet(isPresented: $isShowingNewProjectSheet) {
            NewProjectSheet(onCreated: { project in
                selectedProject = project
                selectedSketch = nil
            })
        }
        .onChange(of: selectedProject) { oldValue, newValue in
            if newValue != oldValue {
                selectedSketch = newValue?.latestSketch
                AppLogger.uiEvents.info("Selected project: \(newValue?.name ?? "none")")
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func projectContextMenu(for project: Project) -> some View {
        Button {
            createNewSketch(in: project)
        } label: {
            Label("New Sketch", systemImage: "plus")
        }

        Divider()

        Button {
            duplicateProject(project)
        } label: {
            Label("Duplicate", systemImage: "plus.square.on.square")
        }

        Divider()

        Button(role: .destructive) {
            deleteProject(project)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Actions

    private func createNewSketch(in project: Project) {
        let sketch = Sketch.newSketch(in: project)
        modelContext.insert(sketch)
        project.addSketch(sketch)
        selectedProject = project
        selectedSketch = sketch
        AppLogger.uiEvents.info("Created new sketch in project: \(project.name)")
    }

    private func duplicateProject(_ project: Project) {
        let newProject = Project(name: "\(project.name) Copy")
        modelContext.insert(newProject)
        selectedProject = newProject
        AppLogger.uiEvents.info("Duplicated project: \(project.name)")
    }

    private func deleteProject(_ project: Project) {
        if selectedProject?.id == project.id {
            selectedProject = projects.first { $0.id != project.id }
            selectedSketch = nil
        }
        modelContext.delete(project)
        AppLogger.uiEvents.info("Deleted project: \(project.name)")
    }

    private func deleteProjects(at offsets: IndexSet) {
        for index in offsets {
            let project = filteredProjects[index]
            deleteProject(project)
        }
    }
}

// MARK: - Project Row View

struct ProjectRowView: View {
    let project: Project
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Project icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: "folder.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label("\(project.sketchCount)", systemImage: "scribble")
                    Label("\(project.wireframeCount)", systemImage: "rectangle.3.group")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Modified date
            Text(project.modifiedAt.formatted(.relative(presentation: .named)))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Empty Project List View

struct EmptyProjectListView: View {
    let searchText: String
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            if searchText.isEmpty {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)

                Text("No Projects")
                    .font(.headline)

                Text("Create your first project to get started")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)

                Text("No Results")
                    .font(.headline)

                Text("No projects match '\(searchText)'")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - New Project Sheet

struct NewProjectSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var projectName = ""
    @FocusState private var isNameFieldFocused: Bool

    let onCreated: (Project) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("New Project")
                .font(.headline)

            TextField("Project Name", text: $projectName)
                .textFieldStyle(.roundedBorder)
                .focused($isNameFieldFocused)
                .onSubmit(createProject)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    createProject()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
        .onAppear {
            isNameFieldFocused = true
        }
    }

    private func createProject() {
        let name = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let project = Project(name: name)
        modelContext.insert(project)
        AppLogger.uiEvents.info("Created new project: \(name)")
        onCreated(project)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    SidebarView(selectedProject: .constant(nil), selectedSketch: .constant(nil))
        .modelContainer(for: [Project.self, Sketch.self, Wireframe.self], inMemory: true)
        .frame(width: 280)
}

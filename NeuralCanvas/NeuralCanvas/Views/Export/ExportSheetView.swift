import SwiftUI
import UniformTypeIdentifiers

// MARK: - Export Sheet View

/// Sheet for configuring and executing wireframe export
struct ExportSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let wireframe: Wireframe
    let exportService: ExportService

    @State private var selectedFormat: ExportFormat = .png
    @State private var scale: CGFloat = 2.0
    @State private var jpegQuality: CGFloat = 0.85
    @State private var includeBackground = true
    @State private var cropToContent = false
    @State private var isExporting = false
    @State private var exportError: ExportError?
    @State private var showErrorAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Export Wireframe")
                    .font(.headline)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // Content
            Form {
                // Format selection
                Section {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases) { format in
                            Text(format.rawValue)
                                .tag(format)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(selectedFormat.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Export Format")
                }

                // Format-specific options
                Section {
                    if !selectedFormat.isVector {
                        // Scale options for raster formats
                        Picker("Resolution", selection: $scale) {
                            Text("1x").tag(CGFloat(1.0))
                            Text("2x").tag(CGFloat(2.0))
                            Text("3x").tag(CGFloat(3.0))
                        }
                        .pickerStyle(.segmented)

                        if selectedFormat == .jpeg {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Quality")
                                    Spacer()
                                    Text("\(Int(jpegQuality * 100))%")
                                        .foregroundStyle(.secondary)
                                }
                                Slider(value: $jpegQuality, in: 0.1...1.0, step: 0.05)
                            }
                        }
                    }

                    Toggle("Include Background", isOn: $includeBackground)
                    Toggle("Crop to Content", isOn: $cropToContent)
                } header: {
                    Text("Options")
                }

                // Preview info
                Section {
                    HStack {
                        Text("Shapes")
                        Spacer()
                        Text("\(wireframe.shapeCount)")
                            .foregroundStyle(.secondary)
                    }

                    if let style = try? wireframe.getAppliedStyle() {
                        HStack {
                            Text("Applied Style")
                            Spacer()
                            Text(style.presetName)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Wireframe Info")
                }
            }
            .formStyle(.grouped)

            Divider()

            // Footer
            HStack {
                if isExporting {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Exporting...")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Export...") {
                    performExport()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExporting)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 400)
        .alert("Export Error", isPresented: $showErrorAlert, presenting: exportError) { _ in
            Button("OK") { }
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    private func performExport() {
        isExporting = true

        Task {
            do {
                let options = ExportOptions(
                    format: selectedFormat,
                    scale: scale,
                    jpegQuality: jpegQuality,
                    includeBackground: includeBackground,
                    cropToContent: cropToContent
                )

                let data = try await exportService.export(wireframe: wireframe, options: options)

                // Show save panel
                await MainActor.run {
                    showSavePanel(data: data, format: selectedFormat)
                }
            } catch let error as ExportError {
                await MainActor.run {
                    exportError = error
                    showErrorAlert = true
                    isExporting = false
                }
            } catch {
                await MainActor.run {
                    exportError = .renderingFailed(underlying: error)
                    showErrorAlert = true
                    isExporting = false
                }
            }
        }
    }

    private func showSavePanel(data: Data, format: ExportFormat) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.utType]
        panel.nameFieldStringValue = "\(wireframe.displayName).\(format.fileExtension)"
        panel.canCreateDirectories = true

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try data.write(to: url)
                    AppLogger.export.info("Exported wireframe to: \(url.path)")
                    dismiss()
                } catch {
                    exportError = .fileWriteFailed(path: url.path, underlying: error)
                    showErrorAlert = true
                }
            }
            isExporting = false
        }
    }
}

// MARK: - Quick Export Button

/// Toolbar button for quick export access
struct ExportToolbarButton: View {
    let wireframe: Wireframe?

    @State private var showExportSheet = false

    var body: some View {
        Button {
            showExportSheet = true
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
        .disabled(wireframe == nil)
        .help("Export wireframe")
        .sheet(isPresented: $showExportSheet) {
            if let wireframe = wireframe {
                ExportSheetView(
                    wireframe: wireframe,
                    exportService: ExportService()
                )
            }
        }
    }
}

// MARK: - Export Format Picker

/// Standalone picker for export format
struct ExportFormatPicker: View {
    @Binding var selection: ExportFormat

    var body: some View {
        Menu {
            ForEach(ExportFormat.allCases) { format in
                Button {
                    selection = format
                } label: {
                    HStack {
                        Text(format.rawValue)
                        if selection == format {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: formatIcon(for: selection))
                Text(selection.rawValue)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
        }
    }

    private func formatIcon(for format: ExportFormat) -> String {
        switch format {
        case .svg: return "curlybraces"
        case .pdf: return "doc.richtext"
        case .png: return "photo"
        case .jpeg: return "photo.fill"
        }
    }
}

// MARK: - Preview

#Preview("Export Sheet") {
    ExportSheetView(
        wireframe: Wireframe(confidence: 0.9),
        exportService: ExportService()
    )
}

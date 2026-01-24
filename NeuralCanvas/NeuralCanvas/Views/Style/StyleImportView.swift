import SwiftUI
import UniformTypeIdentifiers

// MARK: - Style Import View

/// View for importing screenshots to extract design tokens
struct StyleImportView: View {
    @Binding var extractedStyle: ExtractedStyle?
    @Binding var isProcessing: Bool

    @State private var importedImage: NSImage?
    @State private var isDragging = false
    @State private var errorMessage: String?
    @State private var showFilePicker = false

    private let styleMirror = StyleMirrorActor()

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Import Screenshot")
                .font(.headline)

            Text("Drop a screenshot or select a file to extract design tokens")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Drop zone
            DropZoneView(
                isDragging: $isDragging,
                importedImage: importedImage,
                onDrop: handleDrop
            )
            .frame(height: 200)

            // Action buttons
            HStack(spacing: 16) {
                Button("Select File...") {
                    showFilePicker = true
                }
                .buttonStyle(.bordered)

                if importedImage != nil {
                    Button("Extract Style") {
                        Task {
                            await extractStyle()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isProcessing)
                }
            }

            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // Processing indicator
            if isProcessing {
                ProgressView("Extracting design tokens...")
                    .progressViewStyle(.linear)
            }

            Spacer()
        }
        .padding()
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.png, .jpeg, .heic, .tiff],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    // MARK: - Drop Handling

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                if let data = data, let image = NSImage(data: data) {
                    DispatchQueue.main.async {
                        self.importedImage = image
                        self.errorMessage = nil
                    }
                } else {
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to load image"
                    }
                }
            }
            return true
        }
        return false
    }

    // MARK: - File Import Handling

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Security scoped access
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Cannot access file"
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            if let image = NSImage(contentsOf: url) {
                importedImage = image
                errorMessage = nil
            } else {
                errorMessage = "Failed to load image file"
            }

        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Style Extraction

    private func extractStyle() async {
        guard let nsImage = importedImage,
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            errorMessage = "Invalid image"
            return
        }

        isProcessing = true
        errorMessage = nil

        do {
            let style = try await styleMirror.extractStyle(from: cgImage)
            await MainActor.run {
                extractedStyle = style
                isProcessing = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isProcessing = false
            }
        }
    }
}

// MARK: - Drop Zone View

struct DropZoneView: View {
    @Binding var isDragging: Bool
    let importedImage: NSImage?
    let onDrop: ([NSItemProvider]) -> Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isDragging ? Color.accentColor : Color.secondary.opacity(0.5),
                    style: StrokeStyle(lineWidth: 2, dash: isDragging ? [] : [8, 4])
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isDragging ? Color.accentColor.opacity(0.1) : Color.clear)
                )

            if let image = importedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(8)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)

                    Text("Drop screenshot here")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onDrop(of: [.image], isTargeted: $isDragging, perform: onDrop)
    }
}

// MARK: - Preview

#Preview {
    StyleImportView(
        extractedStyle: .constant(nil),
        isProcessing: .constant(false)
    )
    .frame(width: 400, height: 400)
}

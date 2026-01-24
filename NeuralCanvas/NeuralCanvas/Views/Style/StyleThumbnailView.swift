import SwiftUI

// MARK: - Style Thumbnail View

/// Lazy-loading thumbnail view for style presets
struct StyleThumbnailView: View {
    let preset: StylePreset

    @State private var loadedImage: NSImage?
    @State private var isLoading = false
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        Group {
            if let image = loadedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                ProgressView()
                    .scaleEffect(0.5)
            } else {
                // Placeholder with color preview
                colorPlaceholder
            }
        }
        .onAppear {
            loadThumbnail()
        }
        .onDisappear {
            // Cancel loading and release memory when off-screen
            loadTask?.cancel()
            loadTask = nil
            loadedImage = nil
        }
    }

    private var colorPlaceholder: some View {
        GeometryReader { geometry in
            ZStack {
                // Background from style
                Rectangle()
                    .fill(preset.backgroundColor)

                // Color swatches preview
                HStack(spacing: 2) {
                    ForEach(preset.previewColors.prefix(4), id: \.self) { color in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color)
                            .frame(width: geometry.size.width / 5, height: geometry.size.height / 3)
                    }
                }
            }
        }
    }

    private func loadThumbnail() {
        guard !isLoading, loadedImage == nil else { return }

        // Check if thumbnail data exists
        guard let thumbnailData = preset.thumbnailData else {
            return
        }

        isLoading = true

        loadTask = Task.detached(priority: .userInitiated) { [thumbnailData] in
            // Load image in background
            if let image = NSImage(data: thumbnailData) {
                await MainActor.run {
                    self.loadedImage = image
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - StylePreset Extensions for Thumbnail

extension StylePreset {
    /// Background color from the style
    var backgroundColor: Color {
        guard let palette = try? getColorPalette() else {
            return Color.gray.opacity(0.1)
        }
        return Color(
            red: palette.background.red,
            green: palette.background.green,
            blue: palette.background.blue,
            opacity: palette.background.alpha
        )
    }

    /// Preview colors for placeholder
    var previewColors: [Color] {
        guard let palette = try? getColorPalette() else {
            return [.blue, .purple, .orange, .green]
        }

        return [
            Color(red: palette.primary.red, green: palette.primary.green, blue: palette.primary.blue),
            Color(red: palette.secondary.red, green: palette.secondary.green, blue: palette.secondary.blue),
            Color(red: palette.accent.red, green: palette.accent.green, blue: palette.accent.blue),
            Color(red: palette.surface.red, green: palette.surface.green, blue: palette.surface.blue)
        ]
    }
}

// MARK: - Style Preset Card View

/// Card view for displaying a style preset in a grid
struct StylePresetCardView: View {
    let preset: StylePreset
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                // Thumbnail
                StyleThumbnailView(preset: preset)
                    .frame(height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isSelected ? Color.accentColor : Color.clear,
                                lineWidth: 2
                            )
                    )

                // Name
                Text(preset.name)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? .primary : .secondary)

                // Built-in badge
                if preset.isBuiltIn {
                    Text("Built-in")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Style Library Grid View

/// Grid view for browsing style presets in a library
struct StyleLibraryGridView: View {
    let library: StyleLibrary
    @Binding var selectedPreset: StylePreset?

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(library.presets) { preset in
                    StylePresetCardView(
                        preset: preset,
                        isSelected: selectedPreset?.id == preset.id,
                        onSelect: {
                            selectedPreset = preset
                        }
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - Async Thumbnail Loader

/// Utility for batch loading thumbnails
actor ThumbnailLoader {
    private var loadedThumbnails: [UUID: NSImage] = [:]
    private var loadingTasks: [UUID: Task<NSImage?, Never>] = [:]
    private let maxCacheSize = 50

    /// Loads a thumbnail for a preset
    func loadThumbnail(for preset: StylePreset) async -> NSImage? {
        let id = preset.id

        // Check cache
        if let cached = loadedThumbnails[id] {
            return cached
        }

        // Check if already loading
        if let existingTask = loadingTasks[id] {
            return await existingTask.value
        }

        // Start loading - capture thumbnail data to avoid sending preset across actor boundary
        let thumbnailData = preset.thumbnailData
        let task = Task<NSImage?, Never> { [weak self, thumbnailData] in
            guard let thumbnailData = thumbnailData,
                  let image = NSImage(data: thumbnailData) else {
                return nil
            }

            await self?.cacheImage(image, for: id)
            return image
        }

        loadingTasks[id] = task
        let result = await task.value
        loadingTasks.removeValue(forKey: id)

        return result
    }

    private func cacheImage(_ image: NSImage, for id: UUID) {
        // Evict old items if cache is full
        if loadedThumbnails.count >= maxCacheSize {
            let toRemove = loadedThumbnails.count - maxCacheSize + 10
            for key in loadedThumbnails.keys.prefix(toRemove) {
                loadedThumbnails.removeValue(forKey: key)
            }
        }

        loadedThumbnails[id] = image
    }

    /// Clears the thumbnail cache
    func clearCache() {
        loadedThumbnails.removeAll()
        for task in loadingTasks.values {
            task.cancel()
        }
        loadingTasks.removeAll()
    }

    /// Preloads thumbnails for visible presets
    func preloadThumbnails(for presets: [StylePreset]) async {
        for preset in presets.prefix(20) {
            _ = await loadThumbnail(for: preset)
        }
    }
}

// MARK: - Preview

#Preview("Style Thumbnail") {
    HStack {
        StyleThumbnailView(preset: StylePreset.previewPreset())
            .frame(width: 100, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))

        StylePresetCardView(
            preset: StylePreset.previewPreset(),
            isSelected: false,
            onSelect: {}
        )
        .frame(width: 140)

        StylePresetCardView(
            preset: StylePreset.previewPreset(),
            isSelected: true,
            onSelect: {}
        )
        .frame(width: 140)
    }
    .padding()
}

// MARK: - Preview Helpers

extension StylePreset {
    /// Creates a preview preset for SwiftUI previews
    static func previewPreset() -> StylePreset {
        StylePreset(
            id: UUID(),
            name: "Modern UI",
            colorPaletteData: (try? JSONEncoder().encode(ColorPalette.defaultLight)) ?? Data(),
            typographyData: (try? JSONEncoder().encode(TypographyScale.macOSDefault)) ?? Data(),
            spacingData: (try? JSONEncoder().encode(SpacingSystem.standard4pt)) ?? Data(),
            cornerRadiusData: (try? JSONEncoder().encode(CornerRadiusSet.standard)) ?? Data(),
            shadowsData: (try? JSONEncoder().encode([ShadowStyle]())) ?? Data(),
            isBuiltIn: true,
            createdAt: Date(),
            modifiedAt: Date(),
            styleDescription: "A modern UI style",
            library: nil
        )
    }
}

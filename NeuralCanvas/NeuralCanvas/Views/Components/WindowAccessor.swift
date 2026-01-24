import SwiftUI
import AppKit

/// Provides access to the underlying NSWindow for customization
struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.callback(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            self.callback(nsView.window)
        }
    }
}

// MARK: - Window Styling Modifier

/// Modifier to apply premium window styling
struct PremiumWindowStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(WindowAccessor { window in
                guard let window = window else { return }
                configureWindow(window)
            })
    }

    private func configureWindow(_ window: NSWindow) {
        // Titlebar styling
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden

        // Window styling
        window.styleMask.insert(.fullSizeContentView)
        // NOTE: Disabled to allow canvas drawing - window can be moved via title bar area
        window.isMovableByWindowBackground = false

        // Material background
        window.backgroundColor = .clear

        // Minimum size
        window.minSize = NSSize(width: 900, height: 600)

        // Traffic light positioning
        if let closeButton = window.standardWindowButton(.closeButton) {
            closeButton.setFrameOrigin(NSPoint(x: 12, y: closeButton.frame.origin.y))
        }
        if let miniaturizeButton = window.standardWindowButton(.miniaturizeButton) {
            miniaturizeButton.setFrameOrigin(NSPoint(x: 32, y: miniaturizeButton.frame.origin.y))
        }
        if let zoomButton = window.standardWindowButton(.zoomButton) {
            zoomButton.setFrameOrigin(NSPoint(x: 52, y: zoomButton.frame.origin.y))
        }
    }
}

extension View {
    /// Applies premium window styling
    func premiumWindowStyle() -> some View {
        modifier(PremiumWindowStyle())
    }
}

// MARK: - Visual Effect View

/// NSVisualEffectView wrapper for SwiftUI
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    init(
        material: NSVisualEffectView.Material = .sidebar,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    ) {
        self.material = material
        self.blendingMode = blendingMode
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Toolbar Style Modifier

/// Applies toolbar styling to a view
struct ToolbarStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(VisualEffectView(material: .titlebar, blendingMode: .withinWindow))
    }
}

extension View {
    /// Applies toolbar background styling
    func toolbarStyle() -> some View {
        modifier(ToolbarStyleModifier())
    }
}

import SwiftUI

/// Main window layout from the Figma Micro App design: a fixed sidebar on the
/// left, a toolbar row spanning the remaining width, and below it the
/// controller workspace next to a fixed-width context inspector.
struct ContentView: View {
    @Bindable var store: AppStore
    @Bindable var runtime: AppRuntime

    var body: some View {
        // Microkit: settings moved to their own window (`SettingsWindowController`).
        workspace
            .ignoresSafeArea()
            .background(FMTheme.canvas)
            .background(FocusDismissMonitor())
            .background(WindowChromeConfigurator())
            .alert("Microkit", isPresented: Binding(
                get: { runtime.errorMessage != nil },
                set: { if !$0 { runtime.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {
                    runtime.errorMessage = nil
                }
            } message: {
                Text(runtime.errorMessage ?? "Unknown error")
            }
    }

    /// The regular three-column workspace layout. The design widths (275 /
    /// 208) are minimums; both side columns can be dragged wider via the
    /// split dividers.
    private var workspace: some View {
        HSplitView {
            AppSidebarView(store: store, runtime: runtime)
                .frame(minWidth: FMTheme.sidebarWidth, idealWidth: FMTheme.sidebarWidth, maxWidth: 440)

            VStack(spacing: 0) {
                WorkspaceToolbar(store: store)

                FMSectionDivider()

                if store.mode.isMicrokitScreen {
                    MicrokitModeView(store: store)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HSplitView {
                        ControllerCanvasView(store: store)
                            .frame(minWidth: 480, maxWidth: .infinity)
                            .layoutPriority(1)

                        InspectorView(store: store)
                            .frame(minWidth: FMTheme.inspectorWidth, idealWidth: FMTheme.inspectorWidth, maxWidth: 420)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .layoutPriority(1)
        }
    }
}

/// Keeps macOS text focus predictable across the custom split-view chrome.
/// SwiftUI does not expose a window-wide "click outside" focus hook, so this
/// tiny AppKit view watches mouse-down events in its own window only.
private struct FocusDismissMonitor: NSViewRepresentable {
    func makeNSView(context: Context) -> FocusDismissMonitorView {
        FocusDismissMonitorView()
    }

    func updateNSView(_ nsView: FocusDismissMonitorView, context: Context) {}
}

private final class FocusDismissMonitorView: NSView {
    private var mouseMonitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        installMonitorIfNeeded()

        guard let window else { return }
        DispatchQueue.main.async { [weak window] in
            window?.initialFirstResponder = nil
            if Self.isTextInput(window?.firstResponder as? NSView) {
                window?.makeFirstResponder(nil)
            }
        }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil, let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
            self.mouseMonitor = nil
        }
        super.viewWillMove(toWindow: newWindow)
    }

    private func installMonitorIfNeeded() {
        guard mouseMonitor == nil else { return }
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self, let window = self.window, event.window === window else {
                return event
            }

            let hitView = window.contentView?.hitTest(event.locationInWindow)
            if !Self.isTextInput(hitView) {
                window.makeFirstResponder(nil)
            }
            return event
        }
    }

    private static func isTextInput(_ view: NSView?) -> Bool {
        var candidate = view
        while let current = candidate {
            if current is NSTextField || current is NSTextView {
                return true
            }
            candidate = current.superview
        }
        return false
    }
}

/// The hidden-title-bar style alone still lays content out below the title
/// bar. Full-size content plus a transparent title bar lets the sidebar and
/// toolbar reach the very top of the window, as in the design, with the
/// traffic lights floating over the sidebar's reserved 52 pt strip.
private struct WindowChromeConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        Task { @MainActor in
            // A hidden title bar still contributes its ~28 pt safe-area inset.
            // Without cancelling it, SwiftUI lays the 52 pt design toolbar
            // below that inset and the visible header becomes roughly 80 pt.
            // The inset only appears once the window has laid out, so poll
            // until it does, then cancel it with a matching negative inset.
            for _ in 0..<60 {
                if let window = view.window {
                    window.styleMask.insert(.fullSizeContentView)
                    window.titlebarAppearsTransparent = true
                    window.titleVisibility = .hidden
                    Self.useRegularTrafficLights(in: window)

                    if let contentView = window.contentView {
                        let inset = contentView.bounds.height - window.contentLayoutRect.height
                        if inset > 0.5 {
                            contentView.additionalSafeAreaInsets = NSEdgeInsets(
                                top: -inset, left: 0, bottom: 0, right: 0
                            )
                            return
                        }
                    }
                }
                try? await Task.sleep(for: .milliseconds(30))
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    /// Hidden/full-size title bars default to the 12 pt small window controls.
    /// Restore the regular 14 pt native controls used by standard Finder windows
    /// while keeping the system buttons, actions, hover states, and accessibility.
    private static func useRegularTrafficLights(in window: NSWindow) {
        let buttonTypes: [NSWindow.ButtonType] = [
            .closeButton,
            .miniaturizeButton,
            .zoomButton
        ]

        for type in buttonTypes {
            guard let button = window.standardWindowButton(type) else { continue }
            let center = NSPoint(x: button.frame.midX, y: button.frame.midY)
            button.controlSize = .regular
            button.setFrameSize(NSSize(width: 14, height: 14))
            button.setFrameOrigin(NSPoint(x: center.x - 7, y: center.y - 7))
        }
    }
}

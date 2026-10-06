import SwiftUI

/// Settings, mirroring the sidebar + content structure of the app itself. The
/// left rail carries the page navigation (with the top 52 pt clear for the
/// traffic lights); the content column hosts the selected page.
/// Microkit: hosted in its own fixed-size window (`SettingsWindowController`)
/// instead of replacing the main workspace, so the "Back to app" row is gone.
struct SettingsView: View {
    @Bindable var runtime: AppRuntime
    @Bindable var store: AppStore
    /// Closes the settings window (Escape).
    let close: () -> Void
    @AppStorage(KeyboardLayoutPreference.storageKey)
    private var keyboardLayout = KeyboardLayoutPreference.automatic.rawValue
    @State private var recordedShortcutChord: KeyChord?
    @State private var shortcutWarning: String?

    static let windowSize = CGSize(width: 760, height: 600)
    private static let railWidth: CGFloat = 180
    private static let contentWidth: CGFloat = 620

    var body: some View {
        HStack(spacing: 0) {
            navigationRail
                .frame(width: Self.railWidth)

            Divider()

            settingsContent
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .background(FMTheme.canvas)
        .onExitCommand(perform: close)
        .onAppear {
            runtime.refreshLaunchAtLoginState()
            recordedShortcutChord = runtime.globalShortcut.chord
        }
    }

    // MARK: - Navigation rail

    private var navigationRail: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: FMTheme.toolbarHeight)

            VStack(spacing: 2) {
                ForEach(SettingsPage.allCases) { page in
                    SettingsPageRow(
                        page: page,
                        isSelected: store.settingsPage == page
                    ) {
                        store.settingsPage = page
                    }
                }
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .background(FMTheme.controlSurface)
    }

    // MARK: - Content

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Microkit: 24 (was 40) so the General page fits the smaller window.
            Color.clear
                .frame(height: 24)

            Group {
                switch store.settingsPage {
                case .general: generalForm
                case .keyboard: keyboardForm
                case .about: AboutSettingsPage()
                }
            }
        }
        .frame(maxWidth: Self.contentWidth, alignment: .leading)
        .frame(maxWidth: .infinity)
    }

    // MARK: General

    private var generalForm: some View {
        Form {
            Section("General") {
                Toggle(
                    "Launch at Login",
                    isOn: Binding(
                        get: { runtime.launchAtLoginEnabled },
                        set: { runtime.setLaunchAtLogin(enabled: $0) }
                    )
                )
                Text("Keep Microkit running after login so the global \(runtime.globalShortcut.chord.displayName) shortcut is ready.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle(
                    "Hide Dock icon when the window is closed",
                    isOn: Binding(
                        get: { runtime.hideDockIconWhenClosed },
                        set: { runtime.setHideDockIconWhenClosed($0) }
                    )
                )
                Text("Closing the window removes Microkit from the Dock; it keeps running in the menu bar. Reopen it anytime from the menu bar icon.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Global shortcut") {
                LabeledContent("Open Figma") {
                    ShortcutRecorderField(
                        chord: $recordedShortcutChord,
                        onRecord: updateGlobalShortcut
                    )
                    .frame(width: 230)
                }

                if let shortcutWarning {
                    Label(shortcutWarning, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if runtime.globalShortcut != .default {
                    Button("Reset to \(GlobalShortcut.default.chord.displayName)") {
                        apply(shortcut: .default)
                    }
                }

                Text("Launches or activates Figma from anywhere while Microkit is running, even with its window closed. The Figma key on the controller fires the same shortcut, so changing it here rewrites that key on every layer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Controller lighting") {
                Toggle("Dim at night", isOn: $store.nightDimmingEnabled)

                if store.nightDimmingEnabled {
                    LabeledContent("Night hours") {
                        HStack(spacing: 6) {
                            hourPicker(selection: $store.nightStartHour)
                            Text("–")
                                .foregroundStyle(.secondary)
                            hourPicker(selection: $store.nightEndHour)
                        }
                    }

                    LabeledContent("Night brightness") {
                        FMSlider(value: $store.nightLightingBrightness, range: 0.05...1.0)
                            .frame(width: 230)
                    }
                }

                Text("Brightness always follows the presets configured in the Lights mode of the main window; night dimming is the only scale applied on top.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.automatic) // Microkit: the smaller window can scroll
    }

    private func hourPicker(selection: Binding<Int>) -> some View {
        Picker("", selection: selection) {
            ForEach(0..<24, id: \.self) { hour in
                Text(String(format: "%d:00", hour)).tag(hour)
            }
        }
        .labelsHidden()
        .frame(width: 82)
    }

    private func updateGlobalShortcut(chord: KeyChord, keyCode: UInt16) {
        apply(shortcut: GlobalShortcut(chord: chord, macKeyCode: UInt32(keyCode)))
    }

    private func apply(shortcut: GlobalShortcut) {
        guard shortcut.isValid else {
            shortcutWarning = shortcut.chord.modifiers.isEmpty
                ? "Add at least one modifier (⌃⌥⇧⌘) — a bare key cannot be a global shortcut."
                : "This key cannot be written to the controller. Choose a different one."
            recordedShortcutChord = runtime.globalShortcut.chord
            return
        }
        guard runtime.setGlobalShortcut(shortcut) else {
            recordedShortcutChord = runtime.globalShortcut.chord
            return
        }
        shortcutWarning = nil
        recordedShortcutChord = shortcut.chord
        store.globalShortcutDidChange()
    }

    // MARK: Keyboard

    private var keyboardForm: some View {
        Form {
            Section("Controller keyboard layout") {
                Picker("Shortcut layout", selection: $keyboardLayout) {
                    ForEach(KeyboardLayoutResolver.availableChoices) { choice in
                        Text(choice.title).tag(choice.preference.rawValue)
                    }
                }

                LabeledContent(
                    "Current macOS input source",
                    value: KeyboardLayoutResolver.currentInputSourceName
                )

                LabeledContent(
                    "Effective shortcut layout",
                    value: KeyboardLayoutResolver.effectiveShortcutLayoutName(for: keyboardLayout)
                )

                Text("Automatic follows the active macOS input source. You can instead lock the controller to any keyboard layout enabled in System Settings. After changing either layout, press Apply to rewrite the physical HID key positions. Microkit targets Figma’s Generic shortcut set; this selection describes the physical macOS keyboard used to produce it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.automatic) // Microkit: the smaller window can scroll
        .onChange(of: keyboardLayout) { _, _ in
            store.keyboardLayoutDidChange()
        }
    }

}

// MARK: - Pages

enum SettingsPage: String, CaseIterable, Identifiable {
    case general
    case keyboard
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .keyboard: "Keyboard"
        case .about: "About"
        }
    }

}

/// Navigation row in the settings rail, styled like the sidebar rows.
private struct SettingsPageRow: View {
    let page: SettingsPage
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(page.title)
                    .font(FMTheme.body)
                    .foregroundStyle(FMTheme.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(
                isSelected ? FMTheme.hoverFill : (isHovered ? FMTheme.hoverFill.opacity(0.6) : .clear),
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.10), value: isHovered)
    }
}

// MARK: - About page

private struct AboutSettingsPage: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.top, 12)
                    .padding(.bottom, 24)

                VStack(alignment: .leading, spacing: 14) {
                    aboutCard(
                        title: "Support & privacy",
                        symbol: "questionmark.circle"
                    ) {
                        Text("Microkit collects no data. Everything stays on your Mac; the only network request downloads keyboard layouts from usevia.app.")
                    }

                    aboutCard(
                        title: "Artwork",
                        symbol: "paintpalette"
                    ) {
                        Text("The on-screen keycap textures, controller renders, and shortcut icons come from the “Work Louder x Figma” Figma Community file by Robert Culver, published under the Creative Commons Attribution 4.0 license.")
                        Link(
                            "Work Louder x Figma on Figma Community ↗",
                            destination: URL(string: "https://www.figma.com/community/file/1384624700163384062/work-louder-x-figma")!
                        )
                        .font(FMTheme.caption)
                    }

                    aboutCard(
                        title: "Trademarks",
                        symbol: "checkmark.seal"
                    ) {
                        Text("The keycap icons shown in this app — including the Figma logo key — reproduce the printed keycaps of the physical Figma Creator Micro, so the preview matches the real device. Figma and the Figma logo are trademarks of Figma, Inc. Creator Micro and Work Louder are trademarks of Work Louder. They are used here solely to identify the hardware this app configures.")
                        Text("Microkit is an independent, community-made app. It is not affiliated with, endorsed by, or sponsored by Figma, Inc. or Work Louder.")
                    }

                    aboutCard(
                        title: "Built on",
                        symbol: "wrench.and.screwdriver"
                    ) {
                        Text("The controller is configured through the VIA protocol implemented by the open-source QMK firmware and VIA projects — thanks to both communities for making keyboards like the Creator Micro configurable.")
                        HStack(spacing: 16) {
                            Link("QMK ↗", destination: URL(string: "https://qmk.fm")!)
                            Link("VIA ↗", destination: URL(string: "https://usevia.app")!)
                        }
                        .font(FMTheme.caption)
                    }

                    aboutCard(
                        title: "License",
                        symbol: "doc.text"
                    ) {
                        Text("Microkit builds on MicroMap by Martin Málek (MIT License): its workspace, Figma shortcut catalog, lighting presets and Figma integration. Bundled artwork is licensed separately under CC BY 4.0. See ThirdParty/ in the source repository.")
                        Link("MicroMap on GitHub ↗", destination: URL(string: "https://github.com/hello-malek/micromap")!)
                            .font(FMTheme.caption)
                        Text("MicroMap © 2026 Martin Málek")
                            .foregroundStyle(FMTheme.textSecondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .scrollIndicators(.never)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            Text("Microkit")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(FMTheme.textPrimary)

            Text("Configurator for the Work Louder Creator Micro")
                .font(FMTheme.body)
                .foregroundStyle(FMTheme.textSecondary)

            Text("Version \(SettingsView.versionString)")
                .font(FMTheme.caption)
                .foregroundStyle(FMTheme.textSecondary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
    }

    private func aboutCard(
        title: String,
        symbol: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(FMTheme.captionEmphasized)
                .foregroundStyle(FMTheme.textSecondary)

            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .font(FMTheme.caption)
            .foregroundStyle(FMTheme.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(FMTheme.controlSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

extension SettingsView {
    /// Version from the app bundle; "dev" when running outside a built bundle.
    static var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        switch (version, build) {
        case let (version?, build?): return "\(version) (\(build))"
        case let (version?, nil): return version
        default: return "dev"
        }
    }
}

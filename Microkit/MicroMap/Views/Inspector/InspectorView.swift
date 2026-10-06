import AppKit
import SwiftUI

/// Right-hand context panel. In Actions mode it inspects the selected key,
/// dial, or scroller (or shows the drag-and-drop hint when nothing is
/// selected); in Lights mode it edits the selected lighting target.
struct InspectorView: View {
    @Bindable var store: AppStore

    var body: some View {
        Group {
            switch store.mode {
            case .actions:
                actionsInspector
            case .lights:
                LightsInspectorView(store: store)
            default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(FMTheme.panel)
    }

    @ViewBuilder
    private var actionsInspector: some View {
        if let slot = store.selectedSlot {
            if slot.kind == .key {
                KeyInspectorView(store: store, slot: slot)
            } else if let encoder = EncoderKind(slotID: slot.id) {
                EncoderInspectorView(store: store, encoder: encoder)
            }
        } else {
            EmptyInspectorView()
        }
    }
}

// MARK: - Shared building blocks

/// Panel header: 12 pt padding, headline title, optional caption subtitle.
private struct InspectorHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(FMTheme.headline)
                .foregroundStyle(FMTheme.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(FMTheme.caption)
                    .foregroundStyle(FMTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
}

private struct InspectorSection<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(FMTheme.caption)
                .foregroundStyle(FMTheme.textSecondary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
}

/// White value chip used for assigned shortcuts and selected keycap colors.
private struct ValueChipBackground: ViewModifier {
    var isProminent = true

    func body(content: Content) -> some View {
        content
            .padding(6)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isProminent ? FMTheme.controlSurface : FMTheme.fieldFill)
                    .shadow(color: .black.opacity(isProminent ? 0.04 : 0), radius: 3, x: 1, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(isProminent ? FMTheme.chipBorder : .clear, lineWidth: 1)
            )
    }
}

/// Light accent ring marking the slot that receives click-to-assign.
private struct ActiveSlotRing: ViewModifier {
    let isActive: Bool
    var isDropTargeted = false

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isDropTargeted ? FMTheme.accent.opacity(0.10) : .clear)
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(
                        FMTheme.accent.opacity(isDropTargeted ? 1 : 0.65),
                        lineWidth: isDropTargeted ? 2.5 : (isActive ? 1.5 : 0)
                    )
            }
    }
}

/// One assignable shortcut slot: shows the assigned action with its chord and
/// a trash button, or an "Unassigned" placeholder. The whole field accepts a
/// dropped action from the sidebar catalog.
private struct ShortcutFieldView: View {
    @Bindable var store: AppStore
    let slotID: String
    var isLocked = false
    @State private var isDropTargeted = false

    private var action: FigmaAction? { store.action(for: slotID) }

    /// The slot clicks in the action list assign to. With three encoder
    /// inputs on screen, the active one carries a light accent ring.
    private var isActive: Bool { store.selectedSlotID == slotID }

    var body: some View {
        HStack(spacing: 6) {
            if let action {
                HStack(spacing: 8) {
                    Text(action.title)
                        .font(FMTheme.chip)
                        .foregroundStyle(FMTheme.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if let chord = action.chord {
                        KeycapStrip(chord: chord, compact: true)
                    }
                }
                .modifier(ValueChipBackground())
                .modifier(ActiveSlotRing(isActive: isActive, isDropTargeted: isDropTargeted))
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .onTapGesture {
                    store.selectedSlotID = slotID
                }
                .dropDestination(for: String.self) { items, _ in
                    acceptDrop(items)
                } isTargeted: {
                    isDropTargeted = $0 && !isLocked
                }

                if !isLocked {
                    Button {
                        store.clearAssignment(for: slotID)
                    } label: {
                        FigmaAssetImage(fileName: "trash.svg", template: true)
                            .foregroundStyle(FMTheme.textSecondary)
                            .frame(width: 16, height: 16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Remove this shortcut")
                }
            } else {
                // Clicking an empty slot starts assignment: the slot becomes
                // the selection and focus jumps to the sidebar search field.
                Button {
                    store.beginAssignment(for: slotID)
                } label: {
                    HStack(spacing: 8) {
                        FigmaAssetImage(fileName: "unassigned.svg", template: true)
                            .foregroundStyle(FMTheme.textSecondary)
                            .frame(width: 16, height: 16)
                        Text("Unassigned")
                            .font(FMTheme.chip)
                            .foregroundStyle(FMTheme.textSecondary)
                        Spacer(minLength: 0)
                    }
                    .modifier(ValueChipBackground(isProminent: false))
                    .modifier(ActiveSlotRing(isActive: isActive, isDropTargeted: isDropTargeted))
                    .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isLocked)
                .help("Assign a shortcut: pick an action in the list on the left")
                .dropDestination(for: String.self) { items, _ in
                    acceptDrop(items)
                } isTargeted: {
                    isDropTargeted = $0 && !isLocked
                }
            }
        }
        .animation(.easeOut(duration: 0.12), value: isDropTargeted)
    }

    private func acceptDrop(_ items: [String]) -> Bool {
            guard !isLocked, let actionID = items.first, !actionID.isEmpty else { return false }
            store.assign(actionID: actionID, to: slotID)
            return store.action(for: slotID)?.id == actionID
    }
}

// MARK: - Key inspector

private struct KeyInspectorView: View {
    @Bindable var store: AppStore
    let slot: ControllerSlot

    private var title: String {
        if slot.isFigmaButton { return "Figma Key" }
        if slot.isLayerSwitch { return "Smiley Key" }
        let number = slot.id.replacingOccurrences(of: "key-", with: "")
        return "Key \(number)"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                InspectorHeader(title: title)
                FMSectionDivider()

                if slot.isLayerSwitch {
                    InspectorSection(label: "Firmware action") {
                        Text("The Smiley key switches to the next layer. It is reserved by the firmware and cannot be remapped.")
                            .font(FMTheme.caption)
                            .foregroundStyle(FMTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    InspectorSection(label: "Shortcut") {
                        ShortcutFieldView(store: store, slotID: slot.id, isLocked: slot.isFigmaButton)
                        if slot.isFigmaButton {
                            Text("Opens Figma on every layer.")
                                .font(FMTheme.caption)
                                .foregroundStyle(FMTheme.textSecondary)
                        }
                    }

                    if slot.isUserAssignable {
                        FMSectionDivider()
                        keycapColorSection
                    }
                }
            }
        }
        .scrollIndicators(.never)
    }

    @ViewBuilder
    private var keycapColorSection: some View {
        InspectorSection(label: "Keycap color") {
            if store.keycapGlyphAction(for: slot.id) != nil {
                // Keys with a printed glyph always sit on a black cap.
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.figmaCharcoal)
                        .frame(width: 16, height: 16)
                    Text("Black")
                        .font(FMTheme.chip)
                        .foregroundStyle(FMTheme.textPrimary)
                    Spacer(minLength: 0)
                }
                .modifier(ValueChipBackground())
            } else {
                ForEach(KeycapColor.allCases) { color in
                    KeycapColorRow(store: store, slotID: slot.id, color: color)
                }
            }
        }
    }
}

/// Selectable physical keycap color. The set is a real inventory: a color
/// that has hit its limit renders with a slashed swatch and cannot be chosen.
private struct KeycapColorRow: View {
    @Bindable var store: AppStore
    let slotID: String
    let color: KeycapColor

    private var isSelected: Bool { store.keycapColors[slotID] == color }
    private var isAvailable: Bool { store.canUseKeycapColor(color, for: slotID) }

    var body: some View {
        Button {
            store.setKeycapColor(color, for: slotID)
        } label: {
            HStack(spacing: 8) {
                swatch
                Text(color.title)
                    .font(FMTheme.chip)
                    .foregroundStyle(isAvailable ? FMTheme.textPrimary : FMTheme.textSecondary)
                Spacer(minLength: 0)
                if isSelected {
                    FigmaAssetImage(fileName: "checkmark.svg", template: true)
                        .foregroundStyle(FMTheme.textPrimary)
                        .frame(width: 16, height: 16)
                        .accessibilityHidden(true)
                }
            }
            .modifier(ValueChipBackground(isProminent: isSelected))
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .help(
            isAvailable
                ? "Use a \(color.title.lowercased()) keycap (\(store.keycapColorCount(color))/\(color.inventoryLimit) used)"
                : "All \(color.inventoryLimit) \(color.title.lowercased()) keycaps are in use"
        )
    }

    @ViewBuilder
    private var swatch: some View {
        if isAvailable {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color.swatch)
                .frame(width: 16, height: 16)
        } else {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color.swatch.opacity(0.35))
                .frame(width: 16, height: 16)
                .overlay {
                    Rectangle()
                        .fill(.white)
                        .frame(width: 20, height: 1)
                        .rotationEffect(.degrees(-45))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
        }
    }
}

// MARK: - Encoder inspector

private enum EncoderKind {
    case scroller
    case dial

    init?(slotID: String) {
        if slotID.hasPrefix("encoder-a-") {
            self = .scroller
        } else if slotID.hasPrefix("encoder-b-") {
            self = .dial
        } else {
            return nil
        }
    }

    var title: String {
        switch self {
        case .scroller: "Scroller"
        case .dial: "Dial"
        }
    }

    var prefix: String {
        switch self {
        case .scroller: "encoder-a"
        case .dial: "encoder-b"
        }
    }

    /// Section labels in rotation order: counterclockwise, press, clockwise.
    /// The scroller is a vertical wheel, so its directions read up/down.
    var sections: [(label: String, slotSuffix: String)] {
        switch self {
        case .scroller:
            [("Up shortcut", "left"), ("Click shortcut", "press"), ("Down shortcut", "right")]
        case .dial:
            [("Left shortcut", "left"), ("Press shortcut", "press"), ("Right shortcut", "right")]
        }
    }
}

private struct EncoderInspectorView: View {
    @Bindable var store: AppStore
    let encoder: EncoderKind

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                InspectorHeader(title: encoder.title)
                FMSectionDivider()

                ForEach(encoder.sections, id: \.slotSuffix) { section in
                    InspectorSection(label: section.label) {
                        ShortcutFieldView(store: store, slotID: "\(encoder.prefix)-\(section.slotSuffix)")
                    }
                    if section.slotSuffix != encoder.sections.last?.slotSuffix {
                        FMSectionDivider()
                    }
                }
            }
        }
        .scrollIndicators(.never)
    }
}

// MARK: - Empty state

private struct EmptyInspectorView: View {
    var body: some View {
        VStack(spacing: 12) {
            FigmaAssetImage(fileName: "drag-and-drop.svg", template: true)
                .foregroundStyle(FMTheme.textSecondary)
                .frame(width: 32, height: 32)
            Text("Drag and drop actions from the list onto your desired keys.")
                .font(FMTheme.caption)
                .foregroundStyle(FMTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.top, 64)
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

// MARK: - Lights inspector

private struct LightsInspectorView: View {
    @Bindable var store: AppStore

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                InspectorHeader(
                    title: header.title,
                    subtitle: header.subtitle
                )
                FMSectionDivider()

                switch store.selectedLightingTarget {
                case .perimeterActiveFigma:
                    LightingZoneSections(config: store.lightingConfiguration.inFigma) {
                        store.setFigmaLighting($0)
                    }
                case .perimeterOtherApps:
                    LightingZoneSections(config: store.lightingConfiguration.outsideFigma) {
                        store.setAmbientLighting($0)
                    }
                case .keyCaps:
                    keyLightingScope
                    FMSectionDivider()
                    LightingZoneSections(config: store.lightingConfiguration.keysInFigma) {
                        store.setKeyLighting($0)
                    }
                }
            }
        }
        .scrollIndicators(.never)
    }

    /// The key-caps copy depends on the "Only use in Figma" scope toggle, so
    /// that one target overrides the enum's static title/subtitle here.
    private var header: (title: String, subtitle: String) {
        let target = store.selectedLightingTarget
        guard target == .keyCaps else {
            return (target.inspectorTitle, target.subtitle)
        }
        return store.lightingConfiguration.onlyUseKeyLightingInFigma
            ? ("Keys - Active Figma", "Figma app is in focus")
            : ("Keys - All Apps", "Key lighting is available in every app")
    }

    private var keyLightingScope: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(
                "Only use in Figma",
                isOn: Binding(
                    get: { store.lightingConfiguration.onlyUseKeyLightingInFigma },
                    set: { store.setOnlyUseKeyLightingInFigma($0) }
                )
            )
            .toggleStyle(.switch)
            .controlSize(.mini)

            Text("Turn off to keep this key lighting active in every app.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
}

/// Style, brightness, speed, and color sections for one lighting zone.
/// Adjustments preview on the hardware immediately (see AppStore.previewLighting).
private struct LightingZoneSections<Preset: LightingZonePreset>: View {
    let config: LightingZoneConfig<Preset>
    let onChange: (LightingZoneConfig<Preset>) -> Void

    var body: some View {
        VStack(spacing: 0) {
            InspectorSection(label: "Lighting style") {
                stylePicker
            }

            if !config.preset.isOff {
                FMSectionDivider()
                InspectorSection(label: "Brightness") {
                    slider(\.brightness, in: 0.05...1.0)
                }

                if config.preset.isAnimated {
                    FMSectionDivider()
                    InspectorSection(label: "Speed") {
                        slider(\.speed, in: 0.0...1.0)
                    }
                }

                if config.preset.usesColor {
                    FMSectionDivider()
                    InspectorSection(label: "Color") {
                        colorRow
                    }
                } else {
                    FMSectionDivider()
                    InspectorSection(label: "Color") {
                        Text("Colors come from the effect itself.")
                            .font(FMTheme.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private var stylePicker: some View {
        Menu {
            ForEach(Array(Preset.allCases)) { preset in
                Button {
                    var updated = config
                    updated.preset = preset
                    onChange(updated)
                } label: {
                    if preset == config.preset {
                        Label(preset.title, systemImage: "checkmark")
                    } else {
                        Text(preset.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(config.preset.title)
                    .font(FMTheme.chip)
                    .foregroundStyle(FMTheme.textPrimary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(FMTheme.textPrimary)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(FMTheme.fieldFill)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
    }

    private func slider(
        _ keyPath: WritableKeyPath<LightingZoneConfig<Preset>, Double>,
        in range: ClosedRange<Double>
    ) -> some View {
        FMSlider(
            value: Binding(
                get: { config[keyPath: keyPath] },
                set: { newValue in
                    var updated = config
                    updated[keyPath: keyPath] = newValue
                    onChange(updated)
                }
            ),
            range: range
        )
    }

    private var colorRow: some View {
        HStack(spacing: 8) {
            ColorPicker("Color", selection: colorBinding, supportsOpacity: false)
                .labelsHidden()

            Text(hexString)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(FMTheme.textPrimary)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(FMTheme.fieldFill)
                )

            Spacer(minLength: 0)
        }
    }

    private var hexString: String {
        let color = NSColor(
            hue: config.hue,
            saturation: config.saturation,
            brightness: 1,
            alpha: 1
        ).usingColorSpace(.sRGB) ?? .white
        return String(
            format: "#%02X%02X%02X",
            Int((color.redComponent * 255).rounded()),
            Int((color.greenComponent * 255).rounded()),
            Int((color.blueComponent * 255).rounded())
        )
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(hue: config.hue, saturation: config.saturation, brightness: 1) },
            set: { newColor in
                let resolved = NSColor(newColor).usingColorSpace(.deviceRGB) ?? .white
                var updated = config
                updated.hue = Double(resolved.hueComponent)
                updated.saturation = Double(resolved.saturationComponent)
                onChange(updated)
            }
        )
    }
}

import SwiftUI

/// Center workspace: the rendered controller on the canvas backdrop with the
/// floating layers/apply bar at the bottom. Clicking empty canvas clears the
/// selection, which shows the drag-and-drop hint in the inspector.
struct ControllerCanvasView: View {
    @Bindable var store: AppStore
    @Environment(DeviceStore.self) private var devices
    @State private var showApplyConfirmation = false

    var body: some View {
        ZStack {
            FMTheme.canvas
                .contentShape(Rectangle())
                .onTapGesture {
                    store.selectedSlotID = nil
                }

            controllerBoard

            VStack(spacing: 8) {
                Spacer()

                statusNotice

                FloatingApplyBar(store: store, showApplyConfirmation: $showApplyConfirmation)
            }
            .padding(.bottom, 16)
            .animation(.easeOut(duration: 0.18), value: store.toast?.id)
            .animation(.easeOut(duration: 0.18), value: isHardwareConnected)
            .animation(.easeOut(duration: 0.18), value: store.isLoadingDeviceLayout)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: store.device.state) {
            if !isHardwareConnected {
                store.selectedSlotID = nil
            }
        }
        .alert("Apply all layouts to controller?", isPresented: $showApplyConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Apply") {
                store.applyAllLayersToController()
            }
        } message: {
            Text("This writes mapped shortcuts from all four layouts to the Creator Micro’s onboard memory. Firmware is not changed.")
        }
        .alert("Existing controller shortcuts", isPresented: $store.showsInitialDeviceImportChoice) {
            Button("Import shortcuts") {
                store.importInitialDeviceShortcuts()
            }
            Button("Start fresh", role: .destructive) {
                store.startWithFreshDeviceLayout()
            }
        } message: {
            Text("This is the first time this controller has been connected. Import its current mappings into Microkit, or clear user-assignable keys and encoders to start fresh. Some shortcuts from the original configuration may not have a named action, but importing keeps them in Custom.")
        }
    }

    private var isHardwareConnected: Bool {
        store.isDeviceConnected
    }

    private var controllerBoard: some View {
        controllerHardware
            .saturation(isHardwareConnected ? 1 : 0.18)
            .opacity(isHardwareConnected ? 1 : 0.48)
            .allowsHitTesting(isHardwareConnected)
            .accessibilityHidden(!isHardwareConnected)
            .animation(.easeInOut(duration: 0.18), value: isHardwareConnected)
            .frame(width: 520, height: 499)
            .shadow(color: .black.opacity(0.12), radius: 24, y: 14)
    }

    private var controllerHardware: some View {
        ZStack {
            FigmaAssetImage(fileName: "micro-bg.png")
                .frame(width: 520, height: 499)
                .accessibilityHidden(true)

            LayerIndicatorLights(layer: store.currentLayer)
                // Measured against the baked housings in micro-bg.png: their
                // centers sit at (362.7, 336.3), (376.8, 336.3), (391.0,
                // 336.3) pt — a level row with 14.1 pt spacing.
                .offset(x: 117, y: 87)

            VStack(spacing: 3) {
                HStack(alignment: .center, spacing: 3) {
                    EncoderView(name: "Scroller", prefix: "encoder-a", assetName: "Btn=Scroller.png", store: store)
                    ControllerKeyView(slot: ControllerSlot.keys[0], store: store)
                    ControllerKeyView(slot: ControllerSlot.keys[1], store: store)
                    EncoderView(name: "Dial", prefix: "encoder-b", assetName: "Btn=Dial.png", store: store)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.fixed(74), spacing: 3), count: 4), spacing: 3) {
                    ForEach(Array(ControllerSlot.keys.dropFirst(2))) { slot in
                        ControllerKeyView(slot: slot, store: store)
                    }
                }
            }
            .frame(width: 305)
            .padding(.top, 59)
            .padding(.bottom, 67)
        }
    }

    @ViewBuilder
    private var statusNotice: some View {
        if !isHardwareConnected {
            disconnectedNotice
                .accessibilityLabel("Connect your Figma Creator Micro. Plug it in over USB and Microkit connects automatically.")
        } else if store.isLoadingDeviceLayout {
            loadingNotice("Loading layout from device…")
                .accessibilityLabel("Loading layout from device")
        } else if let toast = store.toast {
            Text(toast.message)
                .font(FMTheme.body)
                .foregroundStyle(FMTheme.toastText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: true, vertical: true)
                .padding(.horizontal, 20)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(FMTheme.toastBackground)
                        .shadow(color: .black.opacity(0.28), radius: 5, y: 2)
                )
                .id(toast.id)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .accessibilityLabel(toast.message)
        }
    }

    /// What a first-time user — including App Review without the hardware —
    /// sees: what to connect, and that no further setup step exists.
    private var disconnectedNotice: some View {
        HStack(spacing: 10) {
            DeviceConnectionLoader()

            VStack(alignment: .leading, spacing: 2) {
                Text("Connect your Figma Creator Micro")
                    .font(FMTheme.body)
                    .foregroundStyle(FMTheme.toastText)
                Text("Plug it in over USB and Microkit connects automatically. You can explore actions and prepare mappings meanwhile.")
                    .font(FMTheme.caption)
                    .foregroundStyle(FMTheme.toastText.opacity(0.7))
                Button("Try the demo Micro Pad", action: addDemoKeyboard)
                    .buttonStyle(.link)
                    .font(FMTheme.caption)
                    .padding(.top, 2)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 430)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(FMTheme.toastBackground)
                .shadow(color: .black.opacity(0.28), radius: 5, y: 2)
        )
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .accessibilityElement(children: .combine)
    }

    private func addDemoKeyboard() {
        Task { await devices.addDemo() }
    }

    private func loadingNotice(_ message: String) -> some View {
        HStack(spacing: 10) {
            DeviceConnectionLoader()

            Text(message)
                .font(FMTheme.body)
                .foregroundStyle(FMTheme.toastText)
        }
        .fixedSize(horizontal: true, vertical: true)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(FMTheme.toastBackground)
                .shadow(color: .black.opacity(0.28), radius: 5, y: 2)
        )
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .accessibilityElement(children: .combine)
    }
}

/// A high-contrast connection animation designed for the snackbar's fixed
/// dark surface. The two offset arcs read as a small device handshake rather
/// than a generic system progress indicator.
private struct DeviceConnectionLoader: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation = 0.0
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.18), lineWidth: 2)

            Circle()
                .trim(from: 0.04, to: 0.48)
                .stroke(
                    AngularGradient(
                        colors: [.white.opacity(0.25), .white],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 2.4, lineCap: .round)
                )
                .rotationEffect(.degrees(rotation))

            Circle()
                .trim(from: 0.60, to: 0.78)
                .stroke(.white.opacity(0.62), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-rotation * 0.72))

            Circle()
                .fill(.white)
                .frame(width: 4, height: 4)
                .scaleEffect(pulse ? 1.25 : 0.72)
                .opacity(pulse ? 1 : 0.5)
        }
        .frame(width: 22, height: 22)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.05).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 0.58).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .accessibilityHidden(true)
    }
}

/// Floating bar under the controller. Actions mode selects the edited layer
/// and writes all layouts; Lights mode applies the lighting presets, which
/// are layer-independent.
private struct FloatingApplyBar: View {
    @Bindable var store: AppStore
    @Binding var showApplyConfirmation: Bool
    @State private var hoveredLayer: Int?
    @State private var isApplyHovered = false

    var body: some View {
        HStack(spacing: 4) {
            switch store.mode {
            case .actions:
                HStack(spacing: 8) {
                    Text("Layers:")
                        .font(FMTheme.body)
                        .foregroundStyle(FMTheme.textPrimary)
                    layerPicker
                }
                .padding(.leading, 12)
                .padding(.vertical, 4)
            case .lights:
                Text("Lights are applied to all layers")
                    .font(FMTheme.body)
                    .foregroundStyle(FMTheme.textPrimary)
                    .padding(.leading, 12)
                    .padding(.vertical, 8)
            default:
                EmptyView()
            }

            Rectangle()
                .fill(FMTheme.separator)
                .frame(width: 1)

            applyButton
                .padding(4)
        }
        .fixedSize()
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(FMTheme.controlSurface)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 1)
        )
    }

    private var layerPicker: some View {
        HStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { layer in
                Button {
                    store.currentLayer = layer
                } label: {
                    Text("L\(layer)")
                        .font(FMTheme.captionEmphasized)
                        .foregroundStyle(store.currentLayer == layer ? FMTheme.accent : FMTheme.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(
                                    store.currentLayer == layer
                                        ? FMTheme.controlSurface
                                        : (hoveredLayer == layer ? FMTheme.hoverFill : .clear)
                                )
                                .shadow(
                                    color: store.currentLayer == layer ? .black.opacity(0.25) : .clear,
                                    radius: 1,
                                    y: 1
                                )
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hoveredLayer = $0 ? layer : nil }
                .animation(.easeOut(duration: 0.10), value: hoveredLayer)
                .help("Edit layer L\(layer)")
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(FMTheme.canvas)
        )
    }

    private var applyButton: some View {
        Button {
            switch store.mode {
            case .actions:
                showApplyConfirmation = true
            case .lights:
                store.applyLightingToController()
            default:
                break
            }
        } label: {
            Group {
                if store.isApplying {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Apply changes")
                        .font(FMTheme.body)
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(FMTheme.accent.opacity(isApplyHovered && isApplyEnabled ? 0.86 : 1))
            )
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isApplyEnabled)
        .onHover { isApplyHovered = $0 }
        .animation(.easeOut(duration: 0.10), value: isApplyHovered)
        .opacity(store.device.state == .disconnected ? 0.5 : 1)
        .help(
            store.mode == .actions
                ? "Write all four layouts to the controller"
                : "Apply the configured lighting presets now"
        )
    }

    private var isApplyEnabled: Bool {
        !store.isApplying && store.device.state != .disconnected
    }
}

private struct LayerIndicatorLights: View {
    let layer: Int

    var body: some View {
        ZStack {
            ForEach(1...3, id: \.self) { light in
                indicator(isActive: light == layer)
                    // The three photographed LED housings sit in a level row
                    // 14 pt apart (measured in micro-bg.png).
                    .offset(x: CGFloat(light - 2) * 14)
            }
        }
        .frame(width: 39, height: 18)
        .animation(.easeInOut(duration: 0.18), value: layer)
        .accessibilityHidden(true)
    }

    private func indicator(isActive: Bool) -> some View {
        ZStack {
            if isActive {
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(activeColor.opacity(0.82))
                    .frame(width: 9, height: 12)
                    .blur(radius: 3.5)
            }

            RoundedRectangle(cornerRadius: 2.2, style: .continuous)
                .fill(isActive ? activeGradient : inactiveGradient)
                .frame(width: 7, height: 10)
                .overlay {
                    RoundedRectangle(cornerRadius: 2.2, style: .continuous)
                        .stroke(.white.opacity(isActive ? 0.62 : 0.18), lineWidth: 0.65)
                }
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 1.2, style: .continuous)
                        .fill(.white.opacity(isActive ? 0.72 : 0.20))
                        .frame(width: 3.5, height: 4)
                        .blur(radius: 0.35)
                        .padding(1)
                }
                .shadow(color: isActive ? activeColor.opacity(0.72) : .black.opacity(0.18), radius: isActive ? 2.4 : 0.7, y: 0.5)
        }
        .frame(width: 9, height: 12)
        .rotationEffect(.degrees(-27))
    }

    private var activeGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 220 / 255, green: 245 / 255, blue: 145 / 255),
                activeColor,
                Color(red: 132 / 255, green: 177 / 255, blue: 61 / 255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var inactiveGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 132 / 255, green: 145 / 255, blue: 113 / 255).opacity(0.76),
                Color(red: 62 / 255, green: 70 / 255, blue: 54 / 255).opacity(0.88)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var activeColor: Color {
        Color(red: 181 / 255, green: 221 / 255, blue: 91 / 255)
    }
}

private struct ControllerKeyView: View {
    let slot: ControllerSlot
    @Bindable var store: AppStore
    @State private var isDropTargeted = false

    private var action: FigmaAction? { store.action(for: slot.id) }
    private var keycapGlyphAction: FigmaAction? { store.keycapGlyphAction(for: slot.id) }
    private var isSelected: Bool { slot.isUserAssignable && store.selectedSlotID == slot.id }
    private var appearance: FigmaKeyAppearance { store.keycapAppearance(for: slot.id) }

    var body: some View {
        Button {
            store.selectOrActivate(slot)
        } label: {
            ZStack {
                FigmaKeySurface(appearance: appearance)

                if let keycapGlyphAction, appearance.supportsPrintedIcon {
                    // Microkit: the Figma black key carries its Tool Icon at 80% of the key's width.
                    ActionGlyph(action: keycapGlyphAction, size: 74 * 0.8 / ActionGlyph.toolIconScale)
                }
            }
            .frame(width: 74, height: 75)
            .contentShape(keyShape)
        }
        .buttonStyle(.plain)
        .overlay {
            ZStack {
                keyShape
                    .fill(isDropTargeted ? FMTheme.accent.opacity(0.16) : .clear)
                if isDropTargeted || isSelected {
                    keyShape
                        .strokeBorder(
                            FMTheme.accent,
                            lineWidth: isDropTargeted ? 4 : 3
                        )
                }
            }
        }
        .shadow(color: .black.opacity(0.30), radius: 5, y: 4)
        .help(helpText)
        .dropDestination(for: String.self) { items, _ in
            guard slot.isUserAssignable else { return false }
            guard let actionID = items.first, !actionID.isEmpty else { return false }
            store.assign(actionID: actionID, to: slot.id)
            return store.action(for: slot.id)?.id == actionID
        } isTargeted: {
            isDropTargeted = $0 && slot.isUserAssignable
        }
        .animation(.easeOut(duration: 0.12), value: isDropTargeted)
    }

    private var helpText: String {
        if slot.isLayerSwitch { return "Smiley: switch to the next layer" }
        if slot.isFigmaButton { return "Open Figma · global on L0–L3" }
        return action.map { "\(slot.label): \($0.title)" } ?? slot.label
    }

    // Microkit: follows the Figma key base, corner 24 on a 100 pt key.
    private var keyShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 24 * 0.74)
    }
}

private struct EncoderView: View {
    let name: String
    let prefix: String
    let assetName: String
    @Bindable var store: AppStore
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                store.selectedSlotID = "\(prefix)-press"
            } label: {
                FigmaAssetImage(fileName: assetName)
                    .frame(width: 74, height: isDial ? 74 : 61)
                    .rotationEffect(.degrees(isDial ? 45 : 0))
                    .contentShape(controlShape)
            }
            .buttonStyle(.plain)
            .overlay {
                ZStack {
                    controlShape
                        .fill(isDropTargeted ? FMTheme.accent.opacity(0.16) : .clear)
                    if isSelected || isDropTargeted {
                        controlShape
                            .stroke(FMTheme.accent, lineWidth: isDropTargeted ? 4 : 3)
                    }
                }
            }
            .shadow(color: .black.opacity(0.18), radius: 4, y: 3)
            .help("Select \(name); assign Left, Press, and Right in the panel on the right")
            .dropDestination(for: String.self) { items, _ in
                guard let actionID = items.first, !actionID.isEmpty else { return false }
                store.assign(actionID: actionID, to: "\(prefix)-press")
                return true
            } isTargeted: {
                isDropTargeted = $0
            }
            .animation(.easeOut(duration: 0.12), value: isDropTargeted)
        }
        .frame(width: 74, height: 75)
    }

    private var isSelected: Bool {
        store.selectedSlotID?.hasPrefix("\(prefix)-") == true
    }

    private var isDial: Bool {
        prefix == "encoder-b"
    }

    private var controlShape: AnyShape {
        if isDial {
            AnyShape(Circle())
        } else {
            AnyShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        }
    }
}

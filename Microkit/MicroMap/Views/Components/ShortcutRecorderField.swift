import AppKit
import SwiftUI

/// Click-to-focus field that records a keyboard chord. Used by the custom
/// shortcut sheet and the global shortcut setting. `onRecord` additionally
/// delivers the macOS virtual key code of the recorded key, which Carbon
/// hotkey registration needs.
struct ShortcutRecorderField: View {
    @Binding var chord: KeyChord?
    var fallbackLabel: String?
    var onRecord: ((KeyChord, UInt16) -> Void)?
    @State private var isFocused = false

    var body: some View {
        ZStack {
            ShortcutRecorderRepresentable(
                chord: $chord,
                isFocused: $isFocused,
                onRecord: onRecord
            )

            Group {
                if let chord {
                    KeycapStrip(chord: chord, compact: false)
                } else if let fallbackLabel {
                    HStack(spacing: 7) {
                        Image(systemName: "keyboard")
                        Text(fallbackLabel)
                            .font(.body.monospaced())
                    }
                    .foregroundStyle(FMTheme.textPrimary)
                } else {
                    HStack(spacing: 7) {
                        Image(systemName: "keyboard")
                        Text("Click and press shortcut")
                    }
                    .font(FMTheme.body)
                    .foregroundStyle(FMTheme.textSecondary)
                }
            }
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, minHeight: 46)
        .background(FMTheme.fieldFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isFocused ? FMTheme.accent : FMTheme.separator, lineWidth: isFocused ? 2 : 1)
        }
        .animation(.easeOut(duration: 0.1), value: isFocused)
    }
}

private struct ShortcutRecorderRepresentable: NSViewRepresentable {
    @Binding var chord: KeyChord?
    @Binding var isFocused: Bool
    var onRecord: ((KeyChord, UInt16) -> Void)?

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        configure(view)
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        configure(nsView)
    }

    private func configure(_ view: ShortcutRecorderNSView) {
        view.onChord = { newChord, keyCode in
            chord = newChord
            onRecord?(newChord, keyCode)
        }
        view.onFocusChanged = { isFocused = $0 }
    }
}

private final class ShortcutRecorderNSView: NSView {
    var onChord: ((KeyChord, UInt16) -> Void)?
    var onFocusChanged: ((Bool) -> Void)?

    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { false }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result { onFocusChanged?(true) }
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result { onFocusChanged?(false) }
        return result
    }

    override func keyDown(with event: NSEvent) {
        guard !event.isARepeat, let chord = Self.chord(from: event) else {
            NSSound.beep()
            return
        }
        onChord?(chord, event.keyCode)
    }

    private static func chord(from event: NSEvent) -> KeyChord? {
        let key: String
        if let specialKey = QMKKeycodeEncoder.specialKeyName(forMacKeyCode: event.keyCode) {
            key = specialKey
        } else {
            guard let characters = event.charactersIgnoringModifiers,
                  let character = characters.first,
                  !character.isWhitespace
            else { return nil }
            key = String(character).uppercased()
        }

        var modifiers: [KeyModifier] = []
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.control) { modifiers.append(.control) }
        if flags.contains(.option) { modifiers.append(.option) }
        if flags.contains(.shift) { modifiers.append(.shift) }
        if flags.contains(.command) { modifiers.append(.command) }
        return KeyChord(modifiers: modifiers, key: key)
    }
}

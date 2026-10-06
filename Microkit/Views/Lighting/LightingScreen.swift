import MicrokitCore
import SwiftUI

/// The definition's custom menus (usually lighting), rendered as a native form.
struct LightingScreen: View {
    let session: KeyboardSession

    var body: some View {
        if session.lightingPages.isEmpty {
            ContentUnavailableView("No lighting settings", systemImage: "lightbulb.slash",
                                   description: Text("This keyboard's definition has no lighting or custom menus."))
        } else {
            Form {
                if session.music?.isRunning == true {
                    Section {
                        Label("Music mode is driving the lights. Stop it in Music to change them here.", systemImage: "waveform")
                    }
                }
                ForEach(session.lightingPages) { page in
                    ForEach(page.sections) { section in
                        Section(section.title) {
                            ForEach(visibleControls(section)) { control in
                                MenuControlRow(session: session, control: control)
                            }
                        }
                    }
                }
                Section {
                    Text("Changes apply immediately and are saved to the keyboard a moment later.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .disabled(session.isEditable == false || session.music?.isRunning == true)
        }
    }

    private func visibleControls(_ section: MenuSection) -> [MenuControl] {
        let variables = session.lightingVariables
        return section.controls.filter { control in
            control.showIf.map { ShowIfExpression.evaluate($0, values: variables) } ?? true
        }
    }
}

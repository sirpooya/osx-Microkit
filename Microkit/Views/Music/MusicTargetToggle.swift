import SwiftUI

/// Whether music mode drives one light zone.
struct MusicTargetToggle: View {
    @Bindable var music: MusicController
    let title: String
    @State private var isOn = true

    var body: some View {
        Toggle(title, isOn: $isOn)
            .onAppear { isOn = !music.disabledTargets.contains(title) }
            .onChange(of: isOn) {
                if isOn { music.disabledTargets.remove(title) } else { music.disabledTargets.insert(title) }
            }
    }
}

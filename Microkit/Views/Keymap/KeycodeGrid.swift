import MicrokitCore
import SwiftUI

struct KeycodeGrid: View {
    let session: KeyboardSession
    let options: [KeycodeOption]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: Theme.Picker.cellSize, maximum: Theme.Picker.cellSize), spacing: Theme.Picker.cellSpacing)],
                  alignment: .leading, spacing: Theme.Picker.cellSpacing) {
            ForEach(options) { option in
                KeycodeButton(session: session, option: option)
            }
        }
    }
}

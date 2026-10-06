import SwiftUI

struct NoKeyboardView: View {
    @Environment(DeviceStore.self) private var store

    var body: some View {
        ContentUnavailableView {
            Label {
                Text("Plug in a keyboard")
            } icon: {
                Image("WorkLouderMark")
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 48, height: 48)
            }
        } description: {
            Text("Microkit works with Work Louder boards and any other keyboard that supports VIA. Connect one with a USB cable.")
        } actions: {
            Button("Try the Demo Micro Pad", action: addDemo)
                .buttonStyle(.borderedProminent)
        }
    }

    private func addDemo() {
        Task { await store.addDemo() }
    }
}

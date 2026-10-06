import MicrokitCore
import SwiftUI

/// Category list on the left, keycodes on the right, search across everything.
struct KeycodePickerView: View {
    let session: KeyboardSession
    let catalog: KeycodeCatalog
    @State private var categoryID = "basic"
    @State private var query = ""

    static let advancedID = "advanced"

    var body: some View {
        HStack(spacing: 0) {
            List(selection: $categoryID) {
                ForEach(catalog.categories) { category in
                    Label(category.title, systemImage: category.symbol)
                        .tag(category.id)
                }
                Label("Advanced", systemImage: "slider.horizontal.3")
                    .tag(Self.advancedID)
            }
            .listStyle(.sidebar)
            .frame(width: Theme.Picker.categoryWidth)

            Divider()

            VStack(spacing: 0) {
                TextField("Search keycodes", text: $query, prompt: Text("Search keycodes (e.g. volume, ⌘, layer 2, F13)"))
                    .textFieldStyle(.roundedBorder)
                    .padding(12)
                content
            }
        }
        .disabled(session.selection == nil || session.isEditable == false)
    }

    @ViewBuilder
    private var content: some View {
        if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            let results = catalog.search(query)
            if results.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                ScrollView {
                    KeycodeGrid(session: session, options: results)
                        .padding([.horizontal, .bottom], 12)
                }
            }
        } else if categoryID == Self.advancedID {
            ScrollView {
                AdvancedKeycodeBuilder(session: session)
                    .padding(16)
            }
        } else if let category = catalog.categories.first(where: { $0.id == categoryID }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(category.sections) { section in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(section.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            KeycodeGrid(session: session, options: section.options)
                        }
                    }
                }
                .padding([.horizontal, .bottom], 12)
            }
        }
    }
}

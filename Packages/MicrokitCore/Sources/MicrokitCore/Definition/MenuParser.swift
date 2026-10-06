/// Turns a compiled definition's `menus` into pages, sections and controls.
enum MenuParser {
    static func pages(from menus: [JSONValue]) -> [MenuPage] {
        menus.compactMap { menu in
            guard let object = menu.object, let content = object["content"]?.array else { return nil }
            let title = object["label"]?.string ?? "Settings"
            var sections: [MenuSection] = []
            var loose: [MenuControl] = []
            for item in content {
                if item["type"] != nil {
                    if let control = control(from: item) { loose.append(control) }
                } else if let sectionContent = item["content"]?.array {
                    let controls = sectionContent.compactMap(control(from:))
                    if !controls.isEmpty {
                        sections.append(MenuSection(title: item["label"]?.string ?? title, controls: controls))
                    }
                }
            }
            if !loose.isEmpty {
                sections.insert(MenuSection(title: title, controls: loose), at: 0)
            }
            return sections.isEmpty ? nil : MenuPage(title: title, sections: sections)
        }
    }

    static func control(from item: JSONValue) -> MenuControl? {
        guard let type = item["type"]?.string,
              let content = item["content"]?.array,
              let name = content.first?.string else { return nil }
        let path = content.dropFirst().compactMap { $0.int.map { UInt8(clamping: $0) } }
        guard !path.isEmpty else { return nil }
        let options = item["options"]?.array ?? []
        let kind: MenuControl.Kind
        switch type {
        case "range":
            kind = .range(min: options.first?.int ?? 0, max: options.count > 1 ? options[1].int ?? 255 : 255)
        case "dropdown":
            let choices = options.enumerated().map { index, option in
                if let pair = option.array, let label = pair.first?.string {
                    return MenuChoice(label: label, value: pair.count > 1 ? pair[1].int ?? index : index)
                }
                return MenuChoice(label: option.string ?? "\(index)", value: index)
            }
            kind = .dropdown(choices)
        case "toggle":
            kind = .toggle(off: options.first?.int ?? 0, on: options.count > 1 ? options[1].int ?? 1 : 1)
        case "color":
            kind = .color
        default:
            kind = .unsupported(type)
        }
        return MenuControl(valueName: name, label: item["label"]?.string ?? name, kind: kind, path: path, showIf: item["showIf"]?.string)
    }
}

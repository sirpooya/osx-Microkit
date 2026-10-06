import Foundation

enum ShortcutCatalog {
    static func load() -> [FigmaAction] {
        guard let url = (Bundle.main.url(forResource: "figma-shortcuts", withExtension: "json", subdirectory: "MicroMap")
                    ?? Bundle.main.url(forResource: "figma-shortcuts", withExtension: "json")),
              let data = try? Data(contentsOf: url),
              let actions = try? JSONDecoder().decode([FigmaAction].self, from: data)
        else {
            return []
        }
        return actions
    }
}

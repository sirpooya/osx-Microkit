import Foundation

public enum DefinitionError: Error, LocalizedError, Equatable {
    /// A source definition from the-via/keyboards (KLE `keymap`), not the compiled form.
    case uncompiledDefinition
    case invalid(String)

    public var errorDescription: String? {
        switch self {
        case .uncompiledDefinition:
            "This is a source definition. Microkit reads the compiled form that usevia.app serves (layouts with a \"keys\" list)."
        case .invalid(let reason):
            "The keyboard definition could not be read: \(reason)"
        }
    }
}

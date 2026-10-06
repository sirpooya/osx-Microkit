import Foundation

/// A compiled VIA v3 keyboard definition, as served at
/// `https://usevia.app/definitions/v3/<vendorProductId>.json`.
public struct KeyboardDefinition: Codable, Hashable, Sendable {
    public let name: String
    /// `vendorID << 16 | productID`.
    public let vendorProductId: UInt32
    public let firmwareVersion: Int?
    public let matrix: KeyboardMatrix
    public let layouts: KeyboardLayout
    public let menus: [JSONValue]?
    public let customKeycodes: [CustomKeycode]?
    /// Built-in keycode modules, for example `qmk_rgblight_keycodes`.
    public let keycodes: [String]?

    public var vendorID: UInt16 { UInt16(vendorProductId >> 16) }
    public var productID: UInt16 { UInt16(vendorProductId & 0xFFFF) }

    /// Highest encoder index used by any key, plus one.
    public var encoderCount: Int {
        (layouts.allKeys.compactMap(\.ei).max() ?? -1) + 1
    }

    public var lightingPages: [MenuPage] {
        MenuParser.pages(from: menus ?? [])
    }

    public static func vendorProductID(vendorID: UInt16, productID: UInt16) -> UInt32 {
        UInt32(vendorID) << 16 | UInt32(productID)
    }

    public static func decode(_ data: Data) throws -> KeyboardDefinition {
        let json: JSONValue
        do {
            json = try JSONDecoder().decode(JSONValue.self, from: data)
        } catch {
            throw DefinitionError.invalid("not JSON")
        }
        if json["layouts"]?["keymap"] != nil, json["layouts"]?["keys"] == nil {
            throw DefinitionError.uncompiledDefinition
        }
        do {
            return try JSONDecoder().decode(KeyboardDefinition.self, from: data)
        } catch let DecodingError.keyNotFound(key, _) {
            throw DefinitionError.invalid("missing \"\(key.stringValue)\"")
        } catch let DecodingError.typeMismatch(_, context) {
            throw DefinitionError.invalid("unexpected value at \(context.codingPath.map(\.stringValue).joined(separator: "."))")
        } catch {
            throw DefinitionError.invalid(error.localizedDescription)
        }
    }
}

import Foundation

enum ControllerSpecialSlot {
    static let figma = "key-11"
    static let layerSwitch = "key-14"
    static let openFigmaAction = "system-open-figma"
    static let layerRange = 0..<4
}

enum ControllerLayerNaming {
    static func name(for firmwareLayer: Int) -> String {
        "Layer \(firmwareLayer)"
    }
}

enum ControllerSlotKind: String, Codable, Hashable {
    case key
    case encoderLeft
    case encoderPress
    case encoderRight
}

struct ControllerSlot: Identifiable, Hashable {
    let id: String
    let label: String
    let kind: ControllerSlotKind
    let row: Int?
    let column: Int?
    let encoderIndex: Int?
    let clockwise: Bool?

    var isFigmaButton: Bool { id == ControllerSpecialSlot.figma }
    var isLayerSwitch: Bool { id == ControllerSpecialSlot.layerSwitch }
    var isUserAssignable: Bool { !isFigmaButton && !isLayerSwitch }

    static let keys: [ControllerSlot] = [
        (0, 1), (0, 2),
        (1, 0), (1, 1), (1, 2), (1, 3),
        (2, 0), (2, 1), (2, 2), (2, 3),
        (3, 0), (3, 1), (3, 2), (3, 3)
    ].enumerated().map { index, coordinate in
            let number = index + 1
            return ControllerSlot(
                id: "key-\(number)",
                label: "K\(number)",
                kind: .key,
                row: coordinate.0,
                column: coordinate.1,
                encoderIndex: nil,
                clockwise: nil
            )
    }

    static let encoderSlots: [ControllerSlot] = [
        // The vertical scroller's physical up direction is VIA clockwise;
        // unlike the dial, its visual direction is inverted by its mounting.
        ControllerSlot(id: "encoder-a-left", label: "Scroller · Left", kind: .encoderLeft, row: nil, column: nil, encoderIndex: 0, clockwise: true),
        ControllerSlot(id: "encoder-a-press", label: "Scroller · Press", kind: .encoderPress, row: 0, column: 0, encoderIndex: 0, clockwise: nil),
        ControllerSlot(id: "encoder-a-right", label: "Scroller · Right", kind: .encoderRight, row: nil, column: nil, encoderIndex: 0, clockwise: false),
        ControllerSlot(id: "encoder-b-left", label: "Dial · Left", kind: .encoderLeft, row: nil, column: nil, encoderIndex: 1, clockwise: false),
        ControllerSlot(id: "encoder-b-press", label: "Dial · Press", kind: .encoderPress, row: 0, column: 3, encoderIndex: 1, clockwise: nil),
        ControllerSlot(id: "encoder-b-right", label: "Dial · Right", kind: .encoderRight, row: nil, column: nil, encoderIndex: 1, clockwise: true)
    ]

    static let all = encoderSlots + keys
}

struct LayerAssignments: Codable, Equatable {
    var layers: [Int: [String: String]] = [:]

    func actionID(for slotID: String, layer: Int) -> String? {
        layers[layer]?[slotID]
    }

    mutating func assign(actionID: String, to slotID: String, layer: Int) {
        guard slotID != ControllerSpecialSlot.layerSwitch else { return }
        if slotID == ControllerSpecialSlot.figma {
            assignOpenFigmaToEveryLayer()
            return
        }
        layers[layer, default: [:]][slotID] = actionID
    }

    mutating func clear(slotID: String, layer: Int) {
        guard slotID != ControllerSpecialSlot.figma,
              slotID != ControllerSpecialSlot.layerSwitch else { return }
        layers[layer]?[slotID] = nil
    }

    
    mutating func enforceSpecialAssignments() {
        for layer in ControllerSpecialSlot.layerRange {
            layers[layer, default: [:]][ControllerSpecialSlot.layerSwitch] = nil
            layers[layer, default: [:]][ControllerSpecialSlot.figma] = ControllerSpecialSlot.openFigmaAction
        }
    }

    private mutating func assignOpenFigmaToEveryLayer() {
        for layer in ControllerSpecialSlot.layerRange {
            layers[layer, default: [:]][ControllerSpecialSlot.figma] = ControllerSpecialSlot.openFigmaAction
        }
    }
}

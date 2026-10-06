import Foundation
import Testing
@testable import MicrokitCore

enum Fixtures {
    static func creatorMicro() throws -> KeyboardDefinition {
        let url = try #require(Bundle.module.url(forResource: "creator-micro", withExtension: "json", subdirectory: "Fixtures"))
        return try KeyboardDefinition.decode(Data(contentsOf: url))
    }
}

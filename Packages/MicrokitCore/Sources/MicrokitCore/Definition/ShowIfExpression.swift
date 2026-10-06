import Foundation

/// Evaluates VIA menu `showIf` strings such as
/// `{id_qmk_rgb_matrix_effect} != 0 && {id_qmk_rgb_matrix_effect} != 24`.
/// Grammar: `||`, `&&`, comparisons (`== != < <= > >=`), `!`, parentheses, numbers and `{name}`.
/// Unknown names read as 0. A string that does not parse shows the control.
public enum ShowIfExpression {
    public static func evaluate(_ expression: String, values: [String: Int]) -> Bool {
        var parser = Parser(tokens: tokenize(expression), values: values)
        guard let result = parser.parseOr(), parser.isAtEnd else { return true }
        return result != 0
    }

    enum Token: Equatable {
        case number(Int)
        case name(String)
        case op(String)
        case open, close
    }

    static func tokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        var index = text.startIndex
        func peek(_ offset: Int = 0) -> Character? {
            guard let i = text.index(index, offsetBy: offset, limitedBy: text.endIndex), i < text.endIndex else { return nil }
            return text[i]
        }
        while let char = peek() {
            if char.isWhitespace {
                index = text.index(after: index)
            } else if char == "{" {
                let start = text.index(after: index)
                guard let end = text[start...].firstIndex(of: "}") else { return tokens }
                tokens.append(.name(String(text[start..<end]).trimmingCharacters(in: .whitespaces)))
                index = text.index(after: end)
            } else if char.isNumber {
                var digits = ""
                while let d = peek(), d.isNumber {
                    digits.append(d)
                    index = text.index(after: index)
                }
                tokens.append(.number(Int(digits) ?? 0))
            } else if char == "(" {
                tokens.append(.open)
                index = text.index(after: index)
            } else if char == ")" {
                tokens.append(.close)
                index = text.index(after: index)
            } else {
                let pair = String([char, peek(1) ?? " "])
                if ["&&", "||", "==", "!=", "<=", ">="].contains(pair) {
                    tokens.append(.op(pair))
                    index = text.index(index, offsetBy: 2)
                } else {
                    tokens.append(.op(String(char)))
                    index = text.index(after: index)
                }
            }
        }
        return tokens
    }

    struct Parser {
        let tokens: [Token]
        let values: [String: Int]
        var position = 0

        init(tokens: [Token], values: [String: Int]) {
            self.tokens = tokens
            self.values = values
        }

        var isAtEnd: Bool { position == tokens.count }

        mutating func parseOr() -> Int? {
            guard var left = parseAnd() else { return nil }
            while position < tokens.count, tokens[position] == .op("||") {
                position += 1
                guard let right = parseAnd() else { return nil }
                left = (left != 0 || right != 0) ? 1 : 0
            }
            return left
        }

        mutating func parseAnd() -> Int? {
            guard var left = parseComparison() else { return nil }
            while position < tokens.count, tokens[position] == .op("&&") {
                position += 1
                guard let right = parseComparison() else { return nil }
                left = (left != 0 && right != 0) ? 1 : 0
            }
            return left
        }

        mutating func parseComparison() -> Int? {
            guard let left = parseUnary() else { return nil }
            guard position < tokens.count, case .op(let op) = tokens[position], ["==", "!=", "<", "<=", ">", ">="].contains(op) else {
                return left
            }
            position += 1
            guard let right = parseUnary() else { return nil }
            let result: Bool = switch op {
            case "==": left == right
            case "!=": left != right
            case "<": left < right
            case "<=": left <= right
            case ">": left > right
            default: left >= right
            }
            return result ? 1 : 0
        }

        mutating func parseUnary() -> Int? {
            if position < tokens.count, tokens[position] == .op("!") {
                position += 1
                guard let value = parseUnary() else { return nil }
                return value == 0 ? 1 : 0
            }
            return parsePrimary()
        }

        mutating func parsePrimary() -> Int? {
            guard position < tokens.count else { return nil }
            let token = tokens[position]
            position += 1
            switch token {
            case .number(let value):
                return value
            case .name(let name):
                return values[name] ?? 0
            case .open:
                guard let value = parseOr(), position < tokens.count, tokens[position] == .close else { return nil }
                position += 1
                return value
            default:
                return nil
            }
        }
    }
}

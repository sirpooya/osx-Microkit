import Testing
@testable import MicrokitCore

struct ShowIfExpressionTests {
    @Test(arguments: [
        ("{id_effect} != 0", ["id_effect": 0], false),
        ("{id_effect} != 0", ["id_effect": 5], true),
        ("{id_effect} != 0 && {id_effect} != 24", ["id_effect": 24], false),
        ("{id_effect} == 1 || {id_effect} == 2", ["id_effect": 2], true),
        ("!({id_a} > 3)", ["id_a": 4], false),
        ("{id_a} >= 3 && ({id_b} < 2 || {id_b} == 9)", ["id_a": 3, "id_b": 9], true),
        ("{id_missing} == 0", [:], true),
        ("{id_a} ==", ["id_a": 1], true),
    ])
    func evaluates(expression: String, values: [String: Int], expected: Bool) {
        #expect(ShowIfExpression.evaluate(expression, values: values) == expected)
    }
}

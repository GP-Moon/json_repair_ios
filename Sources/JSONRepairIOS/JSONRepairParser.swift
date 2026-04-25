import Foundation

struct JSONRepairParser {
    private enum Context {
        case topLevel
        case objectKey
        case objectValue
        case array
    }

    private let characters: [Character]
    private var index: Int = 0

    init(input: String) {
        characters = Array(input)
    }

    mutating func parseTopLevel() -> JSONValue? {
        moveToFirstTopLevelValue()
        skipTrivia()

        var values: [JSONValue] = []
        while index < characters.count {
            guard let value = parseValue(context: .topLevel) else {
                index += 1
                continue
            }
            values.append(value)
            skipTrivia()
            if current == "," || current == ";" {
                index += 1
                skipTrivia()
                continue
            }

            if !moveToNextTopLevelValue() {
                break
            }
        }

        if values.count == 1 {
            return values[0]
        }
        if !values.isEmpty {
            return .array(values)
        }
        return nil
    }

    private mutating func parseValue(context: Context) -> JSONValue? {
        skipTrivia()
        guard let char = current else {
            return nil
        }

        switch char {
        case "{":
            return parseObject()
        case "[":
            return parseArray()
        case "(":
            index += 1
            let value = parseValue(context: context)
            skipTrivia()
            if current == ")" {
                index += 1
            }
            return value
        case "\"", "'", "“":
            return .string(parseQuotedString(openingDelimiter: char, context: context))
        case "-", ".", "+":
            return parseNumberOrBareString(context: context)
        default:
            if char.isNumber {
                return parseNumberOrBareString(context: context)
            }
            if let literal = parseLiteralIfPresent() {
                return literal
            }
            if context == .topLevel, !isBareValueStart(char) {
                moveToFirstTopLevelValue()
                return parseValue(context: context)
            }
            return parseBareStringValue(context: context)
        }
    }

    private mutating func parseObject() -> JSONValue {
        consume("{")
        var object = JSONObject()

        while index < characters.count {
            skipTrivia()
            consumeSeparators()
            skipTrivia()

            if current == "}" {
                index += 1
                break
            }
            if current == "]" {
                break
            }
            if current == ":" {
                index += 1
                continue
            }

            let keyStart = index
            let key = parseObjectKey()
            if key.isEmpty, index == keyStart {
                index += 1
                continue
            }

            skipTrivia()
            if current == ":" {
                index += 1
            }

            skipTrivia()
            let value: JSONValue
            if current == nil || current == "," || current == "}" {
                value = .string("")
            } else {
                let valueStart = index
                value = parseValue(context: .objectValue) ?? .string("")
                if index == valueStart {
                    index += 1
                }
            }

            object[key] = value
            skipTrivia()

            if current == "," || current == ";" {
                index += 1
                continue
            }
            if current == "}" {
                index += 1
                break
            }
        }

        return .object(object)
    }

    private mutating func parseObjectKey() -> String {
        skipTrivia()
        guard let char = current else {
            return ""
        }

        if isQuote(char) {
            return parseQuotedString(openingDelimiter: char, context: .objectKey)
        }

        let start = index
        while let char = current {
            if char == ":" || char == "," || char == "}" || char == "]" || char.isNewline {
                break
            }
            index += 1
        }

        let key = String(characters[start..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
        return key.trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”"))
    }

    private mutating func parseArray() -> JSONValue {
        consume("[")
        var array: [JSONValue] = []

        while index < characters.count {
            skipTrivia()
            consumeSeparators()
            skipTrivia()

            if current == "]" {
                index += 1
                break
            }
            if current == "}" {
                break
            }
            if consumeEllipsisIfPresent() {
                continue
            }

            let valueStart = index
            let value = parseArrayValue()
            if let value {
                array.append(value)
            }
            if index == valueStart {
                index += 1
            }

            skipTrivia()
            if current == "," || current == ";" {
                index += 1
                continue
            }
            if current == "]" {
                index += 1
                break
            }
        }

        return .array(array)
    }

    private mutating func parseArrayValue() -> JSONValue? {
        guard let char = current else {
            return nil
        }

        if isQuote(char), quotedStringIsFollowedByColon(openingDelimiter: char) {
            let key = parseQuotedString(openingDelimiter: char, context: .objectKey)
            skipTrivia()
            if current == ":" {
                index += 1
            }
            let value = parseValue(context: .objectValue) ?? .string("")
            var object = JSONObject()
            object[key] = value
            return .object(object)
        }

        return parseValue(context: .array)
    }

    private mutating func parseQuotedString(openingDelimiter: Character, context: Context) -> String {
        let closingDelimiter: Character = openingDelimiter == "“" ? "”" : openingDelimiter
        consume(openingDelimiter)

        var result = ""
        while let char = current {
            if char == "\\" {
                index += 1
                guard let escaped = current else {
                    result.append("\\")
                    break
                }
                result.append(parseEscapedCharacter(escaped))
                continue
            }

            if char == closingDelimiter {
                if quoteTerminatesString(context: context) {
                    index += 1
                    return result
                }
                result.append(char)
                index += 1
                continue
            }

            result.append(char)
            index += 1
        }

        return result
    }

    private mutating func parseEscapedCharacter(_ escaped: Character) -> Character {
        index += 1
        switch escaped {
        case "\"":
            return "\""
        case "'":
            return "'"
        case "\\":
            return "\\"
        case "/":
            return "/"
        case "b":
            return "\u{0008}"
        case "f":
            return "\u{000c}"
        case "n":
            return "\n"
        case "r":
            return "\r"
        case "t":
            return "\t"
        case "u", "x":
            let width = escaped == "u" ? 4 : 2
            if let scalar = consumeHexScalar(width: width) {
                return Character(scalar)
            }
            return escaped
        default:
            return escaped
        }
    }

    private mutating func consumeHexScalar(width: Int) -> UnicodeScalar? {
        guard index + width <= characters.count else {
            return nil
        }

        let hex = String(characters[index..<index + width])
        guard hex.allSatisfy({ $0.isHexDigit }), let value = UInt32(hex, radix: 16), let scalar = UnicodeScalar(value) else {
            return nil
        }
        index += width
        return scalar
    }

    private mutating func parseNumberOrBareString(context: Context) -> JSONValue {
        let start = index
        var sawNumberCharacter = false
        while let char = current {
            if char.isNumber || char == "-" || char == "+" || char == "." || char == "e" || char == "E" || char == "_" {
                sawNumberCharacter = true
                index += 1
                continue
            }
            break
        }

        let token = String(characters[start..<index]).replacingOccurrences(of: "_", with: "")
        if sawNumberCharacter, let normalized = normalizeNumberLiteral(token) {
            return .number(normalized)
        }

        index = start
        return parseBareStringValue(context: context)
    }

    private mutating func parseBareStringValue(context: Context) -> JSONValue {
        let start = index
        while let char = current {
            if char == "," || char == "}" || char == "]" || char == ")" {
                break
            }
            if startsComment(at: index) {
                break
            }
            if context == .objectValue, startsObjectMemberAfterWhitespace(at: index) {
                break
            }
            index += 1
        }

        let token = String(characters[start..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
        if token.isEmpty {
            return .string("")
        }
        return valueFromBareToken(token)
    }

    private func valueFromBareToken(_ token: String) -> JSONValue {
        let lowered = token.lowercased()
        if ["true", "tru", "tr"].contains(lowered) {
            return .bool(true)
        }
        if ["false", "fals", "fal", "fa"].contains(lowered) {
            return .bool(false)
        }
        if ["null", "nul", "none", "nil"].contains(lowered) {
            return .null
        }
        if let normalized = normalizeNumberLiteral(token) {
            return .number(normalized)
        }
        return .string(token.trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”")))
    }

    private mutating func parseLiteralIfPresent() -> JSONValue? {
        if consumeLiteral(["true", "tru", "tr"], terminatorRequired: true) {
            return .bool(true)
        }
        if consumeLiteral(["false", "fals", "fal", "fa"], terminatorRequired: true) {
            return .bool(false)
        }
        if consumeLiteral(["null", "nul", "none", "nil"], terminatorRequired: true) {
            return .null
        }
        return nil
    }

    private mutating func consumeLiteral(_ literals: [String], terminatorRequired: Bool) -> Bool {
        let lowercased = String(characters[index..<characters.count]).lowercased()
        for literal in literals.sorted(by: { $0.count > $1.count }) {
            guard lowercased.hasPrefix(literal) else {
                continue
            }
            let nextIndex = index + literal.count
            if terminatorRequired, nextIndex < characters.count, !isValueTerminator(characters[nextIndex]) {
                continue
            }
            index = nextIndex
            return true
        }
        return false
    }

    private func normalizeNumberLiteral(_ token: String) -> String? {
        var value = token.trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = value.last, ["-", "+", ".", "e", "E"].contains(last) {
            value.removeLast()
        }
        if value.hasPrefix("+") {
            value.removeFirst()
        }
        if value.hasPrefix(".") {
            value = "0" + value
        }
        if value.hasPrefix("-.") {
            value = "-0" + value.dropFirst()
        }

        guard !value.isEmpty else {
            return nil
        }

        let pattern = #"^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$"#
        guard value.range(of: pattern, options: .regularExpression) != nil else {
            return nil
        }
        return value
    }

    private mutating func skipTrivia() {
        var didSkip = true
        while didSkip {
            didSkip = false
            while let char = current, char.isWhitespace {
                index += 1
                didSkip = true
            }
            if skipComment() {
                didSkip = true
            }
        }
    }

    private mutating func skipComment() -> Bool {
        if current == "#" {
            skipLineComment()
            return true
        }
        guard current == "/", peek() != nil else {
            return false
        }
        if peek() == "/" {
            index += 2
            skipLineComment()
            return true
        }
        if peek() == "*" {
            index += 2
            while index < characters.count {
                if current == "*", peek() == "/" {
                    index += 2
                    return true
                }
                index += 1
            }
            return true
        }
        return false
    }

    private mutating func skipLineComment() {
        while let char = current, !char.isNewline {
            index += 1
        }
    }

    private mutating func consumeSeparators() {
        while current == "," || current == ";" {
            index += 1
            skipTrivia()
        }
    }

    private mutating func consumeEllipsisIfPresent() -> Bool {
        guard current == ".", peek() == ".", peek(2) == "." else {
            return false
        }
        index += 3
        return true
    }

    private mutating func consume(_ character: Character) {
        if current == character {
            index += 1
        }
    }

    private func quotedStringIsFollowedByColon(openingDelimiter: Character) -> Bool {
        let closingDelimiter: Character = openingDelimiter == "“" ? "”" : openingDelimiter
        var probe = index + 1
        while probe < characters.count {
            if characters[probe] == "\\" {
                probe += 2
                continue
            }
            if characters[probe] == closingDelimiter {
                probe += 1
                while probe < characters.count, characters[probe].isWhitespace {
                    probe += 1
                }
                return probe < characters.count && characters[probe] == ":"
            }
            probe += 1
        }
        return false
    }

    private func quoteTerminatesString(context: Context) -> Bool {
        var probe = index + 1
        while probe < characters.count, characters[probe].isWhitespace {
            probe += 1
        }

        guard probe < characters.count else {
            return true
        }

        let next = characters[probe]
        switch context {
        case .objectKey:
            return next == ":" || next == "," || next == "}" || next == "]"
        case .objectValue, .array:
            if next == "," || next == "}" || next == "]" || next == ")" {
                return true
            }
            if context == .objectValue, startsObjectMemberAt(probe) {
                return true
            }
            if isQuote(next), startsObjectMemberAt(probe) {
                return true
            }
            if isQuote(next), context == .objectValue {
                return true
            }
            return false
        case .topLevel:
            return isValueTerminator(next)
        }
    }

    private mutating func moveToFirstTopLevelValue() {
        skipTrivia()
        guard index < characters.count, !isLikelyValueStart(characters[index]) else {
            return
        }
        if let bracketIndex = characters[index...].firstIndex(where: { $0 == "{" || $0 == "[" }) {
            index = bracketIndex
        }
    }

    private mutating func moveToNextTopLevelValue() -> Bool {
        skipTrivia()
        while index < characters.count {
            if isLikelyValueStart(characters[index]) {
                return true
            }
            index += 1
        }
        return false
    }

    private func startsObjectMemberAfterWhitespace(at position: Int) -> Bool {
        guard position < characters.count, characters[position].isWhitespace else {
            return false
        }
        var probe = position
        while probe < characters.count, characters[probe].isWhitespace {
            probe += 1
        }
        return startsObjectMemberAt(probe)
    }

    private func startsObjectMemberAt(_ position: Int) -> Bool {
        guard position < characters.count else {
            return false
        }

        var probe = position
        if isQuote(characters[probe]) {
            let quote = characters[probe]
            let closing: Character = quote == "“" ? "”" : quote
            probe += 1
            while probe < characters.count {
                if characters[probe] == "\\" {
                    probe += 2
                    continue
                }
                if characters[probe] == closing {
                    probe += 1
                    break
                }
                probe += 1
            }
        } else {
            guard characters[probe].isLetter || characters[probe] == "_" else {
                return false
            }
            while probe < characters.count {
                let char = characters[probe]
                if char.isLetter || char.isNumber || char == "_" || char == "-" {
                    probe += 1
                    continue
                }
                break
            }
        }

        while probe < characters.count, characters[probe].isWhitespace {
            probe += 1
        }
        return probe < characters.count && characters[probe] == ":"
    }

    private func startsComment(at position: Int) -> Bool {
        guard position < characters.count else {
            return false
        }
        if characters[position] == "#" {
            return true
        }
        guard characters[position] == "/", position + 1 < characters.count else {
            return false
        }
        return characters[position + 1] == "/" || characters[position + 1] == "*"
    }

    private func isLikelyValueStart(_ char: Character) -> Bool {
        char == "{"
            || char == "["
            || char == "("
            || isQuote(char)
            || char == "-"
            || char == "+"
            || char == "."
            || char.isNumber
            || char == "t"
            || char == "T"
            || char == "f"
            || char == "F"
            || char == "n"
            || char == "N"
    }

    private func isBareValueStart(_ char: Character) -> Bool {
        char.isLetter || char.isNumber || char == "_" || char == "-" || char == "." || char == "+"
    }

    private func isQuote(_ char: Character) -> Bool {
        char == "\"" || char == "'" || char == "“" || char == "”"
    }

    private func isValueTerminator(_ char: Character) -> Bool {
        char.isWhitespace || char == "," || char == "}" || char == "]" || char == ")" || char == ";"
    }

    private var current: Character? {
        guard index < characters.count else {
            return nil
        }
        return characters[index]
    }

    private func peek(_ offset: Int = 1) -> Character? {
        let target = index + offset
        guard target < characters.count else {
            return nil
        }
        return characters[target]
    }
}

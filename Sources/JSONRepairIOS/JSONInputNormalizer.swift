import Foundation

enum JSONInputNormalizer {
    static func normalize(_ input: String) -> String {
        var text = input
        if text.hasPrefix("\u{feff}") {
            text.removeFirst()
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        text = extractMarkdownFence(from: text) ?? text
        text = extractJSONP(from: text) ?? text
        return text
    }

    private static func extractMarkdownFence(from input: String) -> String? {
        guard let opening = input.range(of: "```") else {
            return nil
        }
        let afterOpening = opening.upperBound
        guard let closing = input[afterOpening...].range(of: "```") else {
            return nil
        }

        var content = String(input[afterOpening..<closing.lowerBound])
        if let newline = content.firstIndex(where: { $0.isNewline }) {
            let firstLine = content[..<newline].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if firstLine.isEmpty || firstLine == "json" || firstLine == "jsonc" || firstLine == "javascript" {
                content = String(content[content.index(after: newline)...])
            }
        }

        if content.contains("{") || content.contains("[") {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private static func extractJSONP(from input: String) -> String? {
        guard let open = input.firstIndex(of: "("), input.hasSuffix(")") else {
            return nil
        }

        let prefix = input[..<open].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prefix.isEmpty, prefix.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." }) else {
            return nil
        }

        let bodyStart = input.index(after: open)
        let bodyEnd = input.index(before: input.endIndex)
        let body = String(input[bodyStart..<bodyEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard body.first == "{" || body.first == "[" else {
            return nil
        }
        return body
    }
}

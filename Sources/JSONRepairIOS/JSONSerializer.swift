import Foundation

enum JSONSerializer {
    static func serialize(_ value: JSONValue, prettyPrinted: Bool, sortKeys: Bool) -> String {
        serialize(value, prettyPrinted: prettyPrinted, sortKeys: sortKeys, indentation: 0)
    }

    private static func serialize(
        _ value: JSONValue,
        prettyPrinted: Bool,
        sortKeys: Bool,
        indentation: Int
    ) -> String {
        switch value {
        case let .object(object):
            return serializeObject(object, prettyPrinted: prettyPrinted, sortKeys: sortKeys, indentation: indentation)
        case let .array(array):
            return serializeArray(array, prettyPrinted: prettyPrinted, sortKeys: sortKeys, indentation: indentation)
        case let .string(string):
            return "\"\(escape(string))\""
        case let .number(number):
            return number.isEmpty ? "0" : number
        case let .bool(value):
            return value ? "true" : "false"
        case .null:
            return "null"
        }
    }

    private static func serializeObject(
        _ object: JSONObject,
        prettyPrinted: Bool,
        sortKeys: Bool,
        indentation: Int
    ) -> String {
        let entries = sortKeys ? object.entries.sorted { $0.key < $1.key } : object.entries
        guard !entries.isEmpty else {
            return "{}"
        }

        if prettyPrinted {
            let childIndent = String(repeating: " ", count: indentation + 2)
            let currentIndent = String(repeating: " ", count: indentation)
            let body = entries.map { entry in
                "\(childIndent)\"\(escape(entry.key))\": \(serialize(entry.value, prettyPrinted: true, sortKeys: sortKeys, indentation: indentation + 2))"
            }.joined(separator: ",\n")
            return "{\n\(body)\n\(currentIndent)}"
        }

        let body = entries.map { entry in
            "\"\(escape(entry.key))\":\(serialize(entry.value, prettyPrinted: false, sortKeys: sortKeys, indentation: indentation))"
        }.joined(separator: ",")
        return "{\(body)}"
    }

    private static func serializeArray(
        _ array: [JSONValue],
        prettyPrinted: Bool,
        sortKeys: Bool,
        indentation: Int
    ) -> String {
        guard !array.isEmpty else {
            return "[]"
        }

        if prettyPrinted {
            let childIndent = String(repeating: " ", count: indentation + 2)
            let currentIndent = String(repeating: " ", count: indentation)
            let body = array.map { value in
                "\(childIndent)\(serialize(value, prettyPrinted: true, sortKeys: sortKeys, indentation: indentation + 2))"
            }.joined(separator: ",\n")
            return "[\n\(body)\n\(currentIndent)]"
        }

        return "[\(array.map { serialize($0, prettyPrinted: false, sortKeys: sortKeys, indentation: indentation) }.joined(separator: ","))]"
    }

    private static func escape(_ input: String) -> String {
        var output = ""
        output.reserveCapacity(input.count + 8)

        for scalar in input.unicodeScalars {
            switch scalar.value {
            case 0x22:
                output += "\\\""
            case 0x5c:
                output += "\\\\"
            case 0x08:
                output += "\\b"
            case 0x0c:
                output += "\\f"
            case 0x0a:
                output += "\\n"
            case 0x0d:
                output += "\\r"
            case 0x09:
                output += "\\t"
            case 0x00...0x1f:
                output += String(format: "\\u%04x", scalar.value)
            default:
                output.unicodeScalars.append(scalar)
            }
        }

        return output
    }
}

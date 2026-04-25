import Foundation

public enum JSONValue: Equatable, Sendable {
    case object(JSONObject)
    case array([JSONValue])
    case string(String)
    case number(String)
    case bool(Bool)
    case null

    public var object: JSONObject? {
        guard case let .object(value) = self else { return nil }
        return value
    }

    public var array: [JSONValue]? {
        guard case let .array(value) = self else { return nil }
        return value
    }

    public var string: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }

    public var bool: Bool? {
        guard case let .bool(value) = self else { return nil }
        return value
    }

    public var isNull: Bool {
        if case .null = self {
            return true
        }
        return false
    }
}

public struct JSONObject: Equatable, Sendable {
    public struct Entry: Equatable, Sendable {
        public var key: String
        public var value: JSONValue

        public init(key: String, value: JSONValue) {
            self.key = key
            self.value = value
        }
    }

    public private(set) var entries: [Entry]

    public init(entries: [Entry] = []) {
        self.entries = entries
    }

    public subscript(key: String) -> JSONValue? {
        get {
            entries.first(where: { $0.key == key })?.value
        }
        set {
            if let index = entries.firstIndex(where: { $0.key == key }) {
                if let newValue {
                    entries[index].value = newValue
                } else {
                    entries.remove(at: index)
                }
            } else if let newValue {
                entries.append(Entry(key: key, value: newValue))
            }
        }
    }

    public var dictionary: [String: JSONValue] {
        Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.value) })
    }
}

extension JSONValue {
    init(foundationValue value: Any) throws {
        switch value {
        case let dictionary as [String: Any]:
            var object = JSONObject()
            for key in dictionary.keys.sorted() {
                if let value = dictionary[key] {
                    object[key] = try JSONValue(foundationValue: value)
                }
            }
            self = .object(object)
        case let array as [Any]:
            self = .array(try array.map { try JSONValue(foundationValue: $0) })
        case let string as String:
            self = .string(string)
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                self = .bool(number.boolValue)
            } else {
                self = .number(number.stringValue)
            }
        case _ as NSNull:
            self = .null
        default:
            throw JSONRepairError.unsupportedFoundationValue(String(describing: type(of: value)))
        }
    }
}

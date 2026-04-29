import Foundation

public enum JSONRepairError: Error, Equatable, Sendable {
    case unrepairableInput
    case unsupportedFoundationValue(String)
    case serializationFailed
}

public struct JSONRepairOptions: Equatable, Sendable {
    public var skipValidation: Bool
    public var prettyPrinted: Bool
    public var sortKeys: Bool
    public var collapseRedundantArrayWrappersOnDecode: Bool

    public init(
        skipValidation: Bool = false,
        prettyPrinted: Bool = false,
        sortKeys: Bool = false,
        collapseRedundantArrayWrappersOnDecode: Bool = true
    ) {
        self.skipValidation = skipValidation
        self.prettyPrinted = prettyPrinted
        self.sortKeys = sortKeys
        self.collapseRedundantArrayWrappersOnDecode = collapseRedundantArrayWrappersOnDecode
    }
}

public enum JSONRepair {
    public static func repair(
        _ input: String,
        options: JSONRepairOptions = JSONRepairOptions()
    ) throws -> String {
        let value = try loads(input, options: options)
        return JSONSerializer.serialize(value, prettyPrinted: options.prettyPrinted, sortKeys: options.sortKeys)
    }

    public static func loads(
        _ input: String,
        options: JSONRepairOptions = JSONRepairOptions()
    ) throws -> JSONValue {
        if !options.skipValidation, let value = tryStrictJSON(input) {
            return value
        }

        var parser = JSONRepairParser(input: JSONInputNormalizer.normalize(input))
        guard let value = parser.parseTopLevel() else {
            throw JSONRepairError.unrepairableInput
        }
        return value
    }

    public static func decode<T: Decodable>(
        _ type: T.Type,
        from input: String,
        options: JSONRepairOptions = JSONRepairOptions(),
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> T {
        let value = try loads(input, options: options)
        let repaired = JSONSerializer.serialize(value, prettyPrinted: options.prettyPrinted, sortKeys: options.sortKeys)
        guard let data = repaired.data(using: .utf8) else {
            throw JSONRepairError.serializationFailed
        }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            guard options.collapseRedundantArrayWrappersOnDecode else {
                throw error
            }
            return try decodeWithCollapsedArrayWrappers(
                type,
                from: value,
                options: options,
                decoder: decoder,
                originalError: error
            )
        }
    }

    private static func decodeWithCollapsedArrayWrappers<T: Decodable>(
        _ type: T.Type,
        from value: JSONValue,
        options: JSONRepairOptions,
        decoder: JSONDecoder,
        originalError: Error
    ) throws -> T {
        let candidates = collapsedArrayWrapperCandidates(from: value)
        var lastError = originalError

        for candidate in candidates where candidate != value {
            let encoded = JSONSerializer.serialize(candidate, prettyPrinted: options.prettyPrinted, sortKeys: options.sortKeys)
            guard let data = encoded.data(using: .utf8) else {
                throw JSONRepairError.serializationFailed
            }
            do {
                return try decoder.decode(type, from: data)
            } catch {
                lastError = error
            }
        }

        throw lastError
    }

    private static func collapsedArrayWrapperCandidates(from value: JSONValue) -> [JSONValue] {
        var candidates: [JSONValue] = []
        appendUnique(collapseRootArrayWrappers(value), to: &candidates)
        appendUnique(collapseNestedArrayWrappers(value), to: &candidates)
        appendUnique(collapseNestedArrayWrappers(collapseRootArrayWrappers(value)), to: &candidates)
        return candidates
    }

    private static func appendUnique(_ value: JSONValue, to values: inout [JSONValue]) {
        guard !values.contains(value) else {
            return
        }
        values.append(value)
    }

    private static func collapseRootArrayWrappers(_ value: JSONValue) -> JSONValue {
        var current = value
        while case let .array(values) = current, values.count == 1 {
            current = values[0]
        }
        return current
    }

    private static func collapseNestedArrayWrappers(_ value: JSONValue) -> JSONValue {
        switch value {
        case let .object(object):
            var normalized = JSONObject()
            for entry in object.entries {
                normalized[entry.key] = collapseNestedArrayWrappers(entry.value)
            }
            return .object(normalized)
        case let .array(values):
            let normalizedValues = values.map(collapseNestedArrayWrappers)
            if normalizedValues.count == 1,
               case .array = normalizedValues[0] {
                return collapseNestedArrayWrappers(normalizedValues[0])
            }
            return .array(normalizedValues)
        case .string, .number, .bool, .null:
            return value
        }
    }

    private static func tryStrictJSON(_ input: String) -> JSONValue? {
        guard let data = input.data(using: .utf8) else {
            return nil
        }
        do {
            let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            return try JSONValue(foundationValue: object)
        } catch {
            return nil
        }
    }
}

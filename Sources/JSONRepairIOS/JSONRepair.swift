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

    public init(
        skipValidation: Bool = false,
        prettyPrinted: Bool = false,
        sortKeys: Bool = false
    ) {
        self.skipValidation = skipValidation
        self.prettyPrinted = prettyPrinted
        self.sortKeys = sortKeys
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
        let repaired = try repair(input, options: options)
        guard let data = repaired.data(using: .utf8) else {
            throw JSONRepairError.serializationFailed
        }
        return try decoder.decode(type, from: data)
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

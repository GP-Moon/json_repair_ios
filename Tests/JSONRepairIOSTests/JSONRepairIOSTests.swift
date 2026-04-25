import XCTest
@testable import JSONRepairIOS

final class JSONRepairIOSTests: XCTestCase {
    func testRepairsCommonLLMObject() throws {
        let repaired = try JSONRepair.repair(#"{"users":[{"name":"Ada","role":"admin",}],"ok":tru"#)
        XCTAssertEqual(repaired, #"{"users":[{"name":"Ada","role":"admin"}],"ok":true}"#)
    }

    func testRepairsSingleQuotesUnquotedKeysAndTrailingCommas() throws {
        let repaired = try JSONRepair.repair("{name: 'Ada', age: 30, active: True, notes: None,}")
        XCTAssertEqual(repaired, #"{"name":"Ada","age":30,"active":true,"notes":null}"#)
    }

    func testRepairsMissingCommasBetweenObjectMembers() throws {
        let repaired = try JSONRepair.repair(#"{name: "Ada" role: "admin" score: .5}"#)
        XCTAssertEqual(repaired, #"{"name":"Ada","role":"admin","score":0.5}"#)
    }

    func testRepairsMarkdownFencedJSON() throws {
        let input = """
        The result is:
        ```json
        {
          // produced by a model
          title: "统一码",
          tags: ["swift", "json", ...],
        }
        ```
        """

        let repaired = try JSONRepair.repair(input)
        XCTAssertEqual(repaired, #"{"title":"统一码","tags":["swift","json"]}"#)
    }

    func testRepairsJSONP() throws {
        let repaired = try JSONRepair.repair("callback({ok: true, count: 2,})")
        XCTAssertEqual(repaired, #"{"ok":true,"count":2}"#)
    }

    func testRepairsCommentsAndBareStringValues() throws {
        let input = """
        {
          # one line comment
          city: San Francisco,
          /* block comment */
          state: CA
        }
        """

        let repaired = try JSONRepair.repair(input)
        XCTAssertEqual(repaired, #"{"city":"San Francisco","state":"CA"}"#)
    }

    func testHandlesUnescapedQuotesInsideStrings() throws {
        let repaired = try JSONRepair.repair(#"{message: "He said "hello" today"}"#)
        XCTAssertEqual(repaired, #"{"message":"He said \"hello\" today"}"#)
    }

    func testLoadsReturnsInspectableValue() throws {
        let value = try JSONRepair.loads("{items: [1, 2, false]}")
        let object = try XCTUnwrap(value.object)
        let items = try XCTUnwrap(object["items"]?.array)

        XCTAssertEqual(items, [.number("1"), .number("2"), .bool(false)])
    }

    func testDecodesTypedPayload() throws {
        struct Payload: Decodable, Equatable {
            var name: String
            var enabled: Bool
        }

        let decoded = try JSONRepair.decode(Payload.self, from: "{name: 'Pokebot', enabled: fals}")
        XCTAssertEqual(decoded, Payload(name: "Pokebot", enabled: false))
    }

    func testPrettyPrintsWhenRequested() throws {
        let repaired = try JSONRepair.repair("{b:2,a:1}", options: JSONRepairOptions(prettyPrinted: true, sortKeys: true))
        XCTAssertEqual(
            repaired,
            """
            {
              "a": 1,
              "b": 2
            }
            """
        )
    }
}

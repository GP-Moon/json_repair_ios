# json_repair_ios

`json_repair_ios` is a small Swift package for repairing malformed JSON commonly produced by LLMs before decoding it on Apple platforms.

It is inspired by the MIT-licensed Python project [`mangiucugna/json_repair`](https://github.com/mangiucugna/json_repair), with a native Swift implementation and no runtime dependencies.

## What It Repairs

- Missing quotes around object keys and bare string values
- Single-quoted strings and curly quotes
- Trailing commas and missing commas between object members
- Truncated `true`, `false`, and `null` literals
- JavaScript/Python-style booleans and nulls (`True`, `False`, `None`)
- Line comments, block comments, and `#` comments
- Markdown fenced JSON blocks and JSONP wrappers
- Stray ellipsis entries in arrays
- Unclosed arrays, objects, and strings when a valid repair is possible

This package is intentionally heuristic. It is designed as a fallback for model output, not as a replacement for strict validation of trusted protocols.

## Installation

Add the package with Swift Package Manager:

```swift
.package(url: "https://github.com/GP-Moon/json_repair_ios.git", branch: "main")
```

Then add the product:

```swift
.product(name: "JSONRepairIOS", package: "json_repair_ios")
```

## Usage

```swift
import JSONRepairIOS

let badJSON = #"{"users":[{"name":"Ada","role":"admin",}],"ok":tru"#
let repaired = try JSONRepair.repair(badJSON)
// {"users":[{"name":"Ada","role":"admin"}],"ok":true}
```

Decode directly into a `Decodable` type:

```swift
struct Payload: Decodable {
    let name: String
    let enabled: Bool
}

let payload = try JSONRepair.decode(Payload.self, from: "{name: 'Pokebot', enabled: True}")
```

Inspect the repaired value without serializing:

```swift
let value = try JSONRepair.loads("{items: [1, 2, false]}")
```

## API

- `JSONRepair.repair(_:options:) -> String`
- `JSONRepair.loads(_:options:) -> JSONValue`
- `JSONRepair.decode(_:from:options:decoder:) -> Decodable`

`JSONRepairOptions` supports:

- `skipValidation`: skip the strict `JSONSerialization` fast path and go straight to repair.
- `prettyPrinted`: emit formatted JSON.
- `sortKeys`: serialize object keys alphabetically.

## Requirements

- Swift 5.9+
- iOS 17+
- macOS 14+

## Development

```bash
swift build
swift test
```

## License

MIT. See [LICENSE](LICENSE).

# AP Filter Design

## Goal

Build a structured query filter for WiFi access points. Users can type queries like `band:5G AND rssi:>-60` to filter the AP list by band, RSSI, SSID, and channel. The filter parses the query string, evaluates conditions against each AP, and returns matching APs.

The scope is backend-only for this phase: query parser, filter engine, and unit tests. No UI changes. User-activated state and merge mode are deferred to a future phase.

## Non-Goals

- Do not build a query input UI or modify existing search bar.
- Do not implement user-activated AP state or preserveActivated mode.
- Do not add new external dependencies.
- Do not modify `BandChartViewModel` rendering logic.
- Do not add new localization strings.

## Existing Context

Current filtering in `BandChartViewModel` is text-based: a plain substring match against SSID and BSSID, plus band toggles and hidden-SSID toggle. The new filter replaces the substring logic with structured query evaluation while preserving the existing band/hidden toggles as orthogonal concerns.

```
WiFiNetwork (raw scan data)
  -> APFilterService.filter(aps:query:)
    -> APFilterQueryParser.parse(query) -> FilterCondition tree
    -> evaluate each AP against condition
  -> [WiFiNetwork] matching APs
```

## Query Syntax

### Grammar

```
condition     -> orExpr
orExpr        -> andExpr ("OR" andExpr)*
andExpr       -> unary ("AND" unary)*
unary         -> "NOT" unary | primary
primary       -> "(" condition ")" | fieldCondition
fieldCondition -> field comparator value
```

### Fields

| Field    | Syntax Examples         | Description                           |
|----------|------------------------|---------------------------------------|
| `band`   | `band:5G`, `band:2.4G`, `band:6G` | Alias mapping: 2.4G -> band24GHz, 5G -> band5GHz, 6G -> band6GHz |
| `rssi`   | `rssi:-50`, `rssi:>-60`, `rssi:>=-70` | Numerical comparison on dBm value |
| `ssid`   | `ssid:MyNetwork`       | Case-insensitive substring match      |
| `channel`| `channel:36`, `channel:>=100` | Numerical comparison on channel number |

### Comparators

| Symbol | Meaning     |
|--------|-------------|
| `:`    | equals      |
| `>`    | greater than|
| `<`    | less than   |
| `>=`   | greater or equal |
| `<=`   | less or equal |

### Operators

- `AND` — both conditions must be true (default when omitted between adjacent conditions)
- `OR` — at least one condition must be true
- `NOT` — negates the following condition
- Parentheses `()` — override precedence

### Precedence

1. Parentheses (highest)
2. `NOT`
3. `AND`
4. `OR` (lowest)

### Examples

```
band:5G AND rssi:>-60
(band:5G OR band:6G) AND rssi:>=-50
ssid:Office AND NOT channel:36
rssi:>-50 OR (band:2.4G AND channel:1)
```

## Data Model

```swift
// Filter condition tree
enum FilterCondition: Sendable {
    case field(FieldFilter)
    case and([FilterCondition])
    case or([FilterCondition])
    case not(FilterCondition)
}

struct FieldFilter: Sendable {
    let field: FilterField
    let comparator: Comparator
    let value: FilterValue
}

enum FilterField: String, Sendable {
    case band, rssi, ssid, channel
}

enum Comparator: Sendable {
    case eq, gt, lt, gte, lte
}

enum FilterValue: Sendable {
    case string(String)
    case integer(Int)
    case band(ChannelBand)
}
```

## Service Layer

### APFilterQueryParser

Responsible for tokenizing and parsing query strings into `FilterCondition` trees.

```swift
struct APFilterQueryParser {
    func parse(_ query: String) throws -> FilterCondition
}
```

Error type:

```swift
enum FilterParseError: Error, Equatable {
    case unexpectedToken(String, position: Int)
    case expectedField(position: Int)
    case expectedValue(position: Int)
    case unexpectedEOF(position: Int)
    case invalidBand(String, position: Int)
    case invalidNumber(String, position: Int)
    case emptyQuery
}
```

### APFilterService

Coordinates parsing and evaluation.

```swift
struct APFilterService {
    let parser: APFilterQueryParser

    func filter(aps: [WiFiNetwork], query: String) throws -> [WiFiNetwork]

    func evaluate(_ ap: WiFiNetwork, condition: FilterCondition) -> Bool
}
```

Evaluation logic:

1. Parse query string into `FilterCondition` tree
2. For each AP: evaluate against the condition tree
3. If matches: include in result
4. Else: exclude
5. Result = matching APs only

### Field Evaluation Rules

- **band**: Parse value as band alias (2.4G/5G/6G), compare against `network.channel.band`
- **rssi**: Parse value as integer, apply comparator against `network.rssi`
- **ssid**: Parse value as string, case-insensitive contains match against `network.ssid`
- **channel**: Parse value as integer, apply comparator against `network.channel.channelNumber`

## Integration Point

`ScannerViewModel` will call `APFilterService` when the global filter query changes. The integration is deferred to a future phase — this spec only defines the service contract.

## Testing

Add `APFilterServiceTests.swift` to the `WiFiLensTests` target.

### Parser Tests

- Parse single field condition: `band:5G` -> `.field(FieldFilter(field: .band, comparator: .eq, value: .band(.band5GHz)))`
- Parse AND combination: `band:5G AND rssi:>-60`
- Parse OR combination: `band:5G OR band:6G`
- Parse NOT: `NOT ssid:guest`
- Parse nested parentheses: `(band:5G OR band:6G) AND rssi:>-60`
- Parse all comparators: `:`, `>`, `<`, `>=`, `<=`
- Parse band aliases: `2.4G`, `5G`, `6G`
- Error: empty query -> `.emptyQuery`
- Error: invalid band alias -> `.invalidBand`
- Error: missing value -> `.expectedValue`
- Error: unexpected token -> `.unexpectedToken`

### Evaluation Tests

- Band match: AP on 5GHz matches `band:5G`, AP on 2.4GHz does not
- RSSI comparison: AP with RSSI -55 matches `rssi:>-60`, does not match `rssi:>-50`
- SSID substring: AP with SSID "Office-5G" matches `ssid:Office`, does not match `ssid:Home`
- Channel comparison: AP on channel 36 matches `channel:36`, does not match `channel:>=100`
- AND logic: both conditions must be true
- OR logic: at least one condition must be true
- NOT logic: negates the condition
- Parentheses: override precedence correctly

### Service Integration Tests

- Filter returns only matching APs
- Empty query returns all APs
- Invalid query throws `FilterParseError`
- No APs match: returns empty array
- All APs match: returns all APs

If new test files are added, update `project.pbxproj` so they are included in the `WiFiLensTests` target sources and scheme metadata, following `AGENTS.md`.

## File Structure

```
WiFiLens/Sources/WiFiLens/Filter/
  APFilterQueryParser.swift      # Tokenizer + recursive descent parser
  APFilterService.swift          # Service coordinating parse + evaluate
  FilterCondition.swift          # FilterCondition, FieldFilter, FilterValue models
  FilterParseError.swift         # Error types

WiFiLens/Tests/WiFiLensTests/
  APFilterServiceTests.swift     # All filter tests
```

## Implementation Notes

- All new types are `Sendable` for Swift 6 concurrency safety.
- Parser is a hand-written recursive descent parser — no external dependencies.
- Band alias mapping: `"2.4G"` -> `.band24GHz`, `"5G"` -> `.band5GHz`, `"6G"` -> `.band6GHz`. Also accept `"24"`, `"5"`, `"6"` for consistency with existing `ChannelBand.id`.
- RSSI values are negative integers (dBm). Comparisons use standard integer ordering.
- SSID matching is case-insensitive and uses `String.contains()`.
- Channel values are positive integers.
- The parser skips whitespace between tokens.
- Unquoted string values are supported for SSID (e.g., `ssid:Office Network`). Quoted strings with spaces are also supported: `ssid:"Office Network"`.

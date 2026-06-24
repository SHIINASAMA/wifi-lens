import Testing
@testable import WiFi_Lens

struct FilterConditionTests {
    @Test func fieldFilterCreation() {
        let filter = FieldFilter(
            field: .band,
            comparator: .eq,
            value: .band(.band5GHz)
        )
        #expect(filter.field == .band)
        #expect(filter.comparator == .eq)
    }

    @Test func andConditionCreation() {
        let a = FilterCondition.field(FieldFilter(field: .band, comparator: .eq, value: .band(.band5GHz)))
        let b = FilterCondition.field(FieldFilter(field: .rssi, comparator: .gt, value: .integer(-60)))
        let and = FilterCondition.and([a, b])
        if case .and(let children) = and {
            #expect(children.count == 2)
        } else {
            Issue.record("Expected .and case")
        }
    }

    @Test func orConditionCreation() {
        let a = FilterCondition.field(FieldFilter(field: .band, comparator: .eq, value: .band(.band5GHz)))
        let b = FilterCondition.field(FieldFilter(field: .band, comparator: .eq, value: .band(.band6GHz)))
        let or = FilterCondition.or([a, b])
        if case .or(let children) = or {
            #expect(children.count == 2)
        } else {
            Issue.record("Expected .or case")
        }
    }

    @Test func notConditionCreation() {
        let inner = FilterCondition.field(FieldFilter(field: .ssid, comparator: .eq, value: .string("guest")))
        let not = FilterCondition.not(inner)
        if case .not(let child) = not {
            if case .field(let filter) = child {
                #expect(filter.value == .string("guest"))
            }
        } else {
            Issue.record("Expected .not case")
        }
    }
}

struct TokenizerTests {
    @Test func tokenizeSimpleQuery() {
        let tokens = APFilterQueryParser.Tokenizer.tokenize("band:5G")
        #expect(tokens == [.field("band"), .colon, .value("5G")])
    }

    @Test func tokenizeWithAND() {
        let tokens = APFilterQueryParser.Tokenizer.tokenize("band:5G AND rssi:>-60")
        #expect(tokens == [
            .field("band"), .colon, .value("5G"),
            .and,
            .field("rssi"), .colon, .gt, .value("-60")
        ])
    }

    @Test func tokenizeWithOR() {
        let tokens = APFilterQueryParser.Tokenizer.tokenize("band:5G OR band:6G")
        #expect(tokens == [
            .field("band"), .colon, .value("5G"),
            .or,
            .field("band"), .colon, .value("6G")
        ])
    }

    @Test func tokenizeWithNOT() {
        let tokens = APFilterQueryParser.Tokenizer.tokenize("NOT ssid:guest")
        #expect(tokens == [.not, .field("ssid"), .colon, .value("guest")])
    }

    @Test func tokenizeWithParentheses() {
        let tokens = APFilterQueryParser.Tokenizer.tokenize("(band:5G)")
        #expect(tokens == [.lparen, .field("band"), .colon, .value("5G"), .rparen])
    }

    @Test func tokenizeGte() {
        let tokens = APFilterQueryParser.Tokenizer.tokenize("rssi:>=-60")
        #expect(tokens == [.field("rssi"), .colon, .gte, .value("-60")])
    }

    @Test func tokenizeLte() {
        let tokens = APFilterQueryParser.Tokenizer.tokenize("rssi:<=-60")
        #expect(tokens == [.field("rssi"), .colon, .lte, .value("-60")])
    }

    @Test func tokenizeQuotedString() {
        let tokens = APFilterQueryParser.Tokenizer.tokenize("ssid:\"Office Network\"")
        #expect(tokens == [.field("ssid"), .colon, .value("Office Network")])
    }
}

struct FilterParseErrorTests {
    @Test func errorEquality() {
        let a = FilterParseError.emptyQuery
        let b = FilterParseError.emptyQuery
        #expect(a == b)
    }

    @Test func errorPositionTracking() {
        let error = FilterParseError.unexpectedToken("foo", position: 5)
        if case .unexpectedToken(_, let pos) = error {
            #expect(pos == 5)
        } else {
            Issue.record("Expected unexpectedToken case")
        }
    }

    @Test func invalidBandError() {
        let error = FilterParseError.invalidBand("7G", position: 0)
        if case .invalidBand(let band, _) = error {
            #expect(band == "7G")
        } else {
            Issue.record("Expected invalidBand case")
        }
    }
}

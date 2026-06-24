/// Hand-written recursive descent parser for AP filter queries.
struct APFilterQueryParser {

    // MARK: - Tokenizer

    enum Token: Equatable, Sendable {
        case field(String)
        case value(String)
        case colon
        case gt
        case lt
        case gte
        case lte
        case and
        case or
        case not
        case lparen
        case rparen
    }

    struct Tokenizer {
        static func tokenize(_ input: String) -> [Token] {
            var tokens: [Token] = []
            var i = input.startIndex
            while i < input.endIndex {
                let ch = input[i]
                if ch.isWhitespace {
                    i = input.index(after: i)
                    continue
                }
                switch ch {
                case ":":
                    tokens.append(.colon)
                    i = input.index(after: i)
                case "(":
                    tokens.append(.lparen)
                    i = input.index(after: i)
                case ")":
                    tokens.append(.rparen)
                    i = input.index(after: i)
                case ">":
                    let next = input.index(after: i)
                    if next < input.endIndex && input[next] == "=" {
                        tokens.append(.gte)
                        i = input.index(after: next)
                    } else {
                        tokens.append(.gt)
                        i = input.index(after: i)
                    }
                case "<":
                    let next = input.index(after: i)
                    if next < input.endIndex && input[next] == "=" {
                        tokens.append(.lte)
                        i = input.index(after: next)
                    } else {
                        tokens.append(.lt)
                        i = input.index(after: i)
                    }
                case "\"":
                    let start = input.index(after: i)
                    var end = start
                    while end < input.endIndex && input[end] != "\"" {
                        end = input.index(after: end)
                    }
                    let str = String(input[start..<end])
                    tokens.append(.value(str))
                    i = end < input.endIndex ? input.index(after: end) : end
                default:
                    let start = i
                    while i < input.endIndex && (input[i].isLetter || input[i].isNumber || input[i] == "." || input[i] == "_" || input[i] == "-") {
                        i = input.index(after: i)
                    }
                    let word = String(input[start..<i])
                    switch word {
                    case "AND": tokens.append(.and)
                    case "OR": tokens.append(.or)
                    case "NOT": tokens.append(.not)
                    default:
                        var j = i
                        while j < input.endIndex && input[j].isWhitespace {
                            j = input.index(after: j)
                        }
                        if j < input.endIndex && input[j] == ":" {
                            tokens.append(.field(word))
                        } else {
                            tokens.append(.value(word))
                        }
                    }
                }
            }
            return tokens
        }
    }
}

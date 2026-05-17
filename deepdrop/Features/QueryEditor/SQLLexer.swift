//
//  SQLLexer.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import Foundation

enum SQLTokenKind: Equatable {
    case word(String)
    case semicolon
    case whitespace
    case lineComment
    case blockComment
    case singleQuotedString
    case doubleQuotedIdentifier
    case dollarQuotedString(tag: String?)
    case symbol(Character)
    case unknown
}

struct SQLToken: Equatable {
    var kind: SQLTokenKind
    var range: Range<String.Index>
}

enum SQLLexer {
    static func tokenize(_ sql: String) -> [SQLToken] {
        var tokens: [SQLToken] = []
        var index = sql.startIndex

        while index < sql.endIndex {
            let start = index
            let character = sql[index]

            if character.isWhitespace {
                index = consumeWhitespace(in: sql, from: index)
                tokens.append(SQLToken(kind: .whitespace, range: start..<index))
            } else if character == "-", sql.nextIndex(after: index).map({ sql[$0] == "-" }) == true {
                index = consumeLineComment(in: sql, from: index)
                tokens.append(SQLToken(kind: .lineComment, range: start..<index))
            } else if character == "/", sql.nextIndex(after: index).map({ sql[$0] == "*" }) == true {
                index = consumeBlockComment(in: sql, from: index)
                tokens.append(SQLToken(kind: .blockComment, range: start..<index))
            } else if character == "'" {
                index = consumeSingleQuotedString(in: sql, from: index)
                tokens.append(SQLToken(kind: .singleQuotedString, range: start..<index))
            } else if character == "\"" {
                index = consumeDoubleQuotedIdentifier(in: sql, from: index)
                tokens.append(SQLToken(kind: .doubleQuotedIdentifier, range: start..<index))
            } else if character == "$", let delimiter = dollarQuoteDelimiter(in: sql, at: index) {
                index = consumeDollarQuotedString(in: sql, from: index, delimiter: delimiter)
                let tag = delimiter.count > 2 ? String(delimiter.dropFirst().dropLast()) : nil
                tokens.append(SQLToken(kind: .dollarQuotedString(tag: tag), range: start..<index))
            } else if character == ";" {
                index = sql.index(after: index)
                tokens.append(SQLToken(kind: .semicolon, range: start..<index))
            } else if character.isSQLWordStart {
                index = consumeWord(in: sql, from: index)
                tokens.append(SQLToken(kind: .word(String(sql[start..<index])), range: start..<index))
            } else {
                index = sql.index(after: index)
                tokens.append(SQLToken(kind: .symbol(character), range: start..<index))
            }
        }

        return tokens
    }

    private static func consumeWhitespace(in sql: String, from index: String.Index) -> String.Index {
        var current = index
        while current < sql.endIndex, sql[current].isWhitespace {
            current = sql.index(after: current)
        }
        return current
    }

    private static func consumeLineComment(in sql: String, from index: String.Index) -> String.Index {
        var current = sql.index(index, offsetBy: 2)
        while current < sql.endIndex, sql[current] != "\n", sql[current] != "\r" {
            current = sql.index(after: current)
        }
        return current
    }

    private static func consumeBlockComment(in sql: String, from index: String.Index) -> String.Index {
        var current = sql.index(index, offsetBy: 2)
        while current < sql.endIndex {
            if sql[current] == "*", sql.nextIndex(after: current).map({ sql[$0] == "/" }) == true {
                return sql.index(current, offsetBy: 2)
            }
            current = sql.index(after: current)
        }
        return current
    }

    private static func consumeSingleQuotedString(in sql: String, from index: String.Index) -> String.Index {
        var current = sql.index(after: index)
        while current < sql.endIndex {
            if sql[current] == "'" {
                if sql.nextIndex(after: current).map({ sql[$0] == "'" }) == true {
                    current = sql.index(current, offsetBy: 2)
                } else {
                    return sql.index(after: current)
                }
            } else {
                current = sql.index(after: current)
            }
        }
        return current
    }

    private static func consumeDoubleQuotedIdentifier(in sql: String, from index: String.Index) -> String.Index {
        var current = sql.index(after: index)
        while current < sql.endIndex {
            if sql[current] == "\"" {
                if sql.nextIndex(after: current).map({ sql[$0] == "\"" }) == true {
                    current = sql.index(current, offsetBy: 2)
                } else {
                    return sql.index(after: current)
                }
            } else {
                current = sql.index(after: current)
            }
        }
        return current
    }

    private static func consumeDollarQuotedString(
        in sql: String,
        from index: String.Index,
        delimiter: String
    ) -> String.Index {
        let contentStart = sql.index(index, offsetBy: delimiter.count)
        guard let closingRange = sql.range(of: delimiter, range: contentStart..<sql.endIndex) else {
            return sql.endIndex
        }
        return closingRange.upperBound
    }

    private static func dollarQuoteDelimiter(in sql: String, at index: String.Index) -> String? {
        var current = sql.index(after: index)
        while current < sql.endIndex, sql[current] != "$" {
            guard sql[current].isSQLDollarQuoteTag else {
                return nil
            }
            current = sql.index(after: current)
        }

        guard current < sql.endIndex else {
            return nil
        }

        return String(sql[index...current])
    }

    private static func consumeWord(in sql: String, from index: String.Index) -> String.Index {
        var current = index
        while current < sql.endIndex, sql[current].isSQLWordPart {
            current = sql.index(after: current)
        }
        return current
    }
}

private extension String {
    func nextIndex(after index: String.Index) -> String.Index? {
        let next = self.index(after: index)
        return next < endIndex ? next : nil
    }
}

private extension Character {
    var isSQLWordStart: Bool {
        isLetter || self == "_"
    }

    var isSQLWordPart: Bool {
        isLetter || isNumber || self == "_"
    }

    var isSQLDollarQuoteTag: Bool {
        isLetter || isNumber || self == "_"
    }
}

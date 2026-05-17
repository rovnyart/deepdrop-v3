//
//  SQLStatementDetector.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import Foundation

struct SQLStatement: Equatable {
    var text: String
    var range: Range<String.Index>
    var lineRange: ClosedRange<Int>
    var isMultiline: Bool
    var classification: SQLStatementClassification
}

enum SQLStatementDetector {
    static func statement(
        in sql: String,
        selectedRange: NSRange,
        cursorLocation: Int
    ) -> SQLStatement? {
        if selectedRange.length > 0, let range = Range(selectedRange, in: sql) {
            return makeStatement(in: sql, range: range)
        }

        guard !sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let cursorIndex = stringIndex(in: sql, utf16Offset: cursorLocation)
        let segments = statementSegments(in: sql)
        if let exactSegment = segments.first(where: { $0.lowerBound <= cursorIndex && cursorIndex < $0.upperBound }),
           let statement = makeStatement(in: sql, range: exactSegment) {
            return statement
        }

        return segments
            .reversed()
            .lazy
            .filter { $0.lowerBound <= cursorIndex }
            .compactMap { makeStatement(in: sql, range: $0) }
            .first
    }

    private static func statementSegments(in sql: String) -> [Range<String.Index>] {
        let tokens = SQLLexer.tokenize(sql)
        var segments: [Range<String.Index>] = []
        var lowerBound = sql.startIndex

        for token in tokens {
            if token.kind == .semicolon || token.isBlankLineSeparator(in: sql) {
                segments.append(lowerBound..<token.range.lowerBound)
                lowerBound = token.range.upperBound
            }
        }

        segments.append(lowerBound..<sql.endIndex)
        return segments
    }

    private static func makeStatement(in sql: String, range: Range<String.Index>) -> SQLStatement? {
        let trimmedRange = trimWhitespace(in: sql, range: range)
        guard trimmedRange.lowerBound < trimmedRange.upperBound else {
            return nil
        }

        let text = String(sql[trimmedRange])
        let lineRange = lineRange(in: sql, range: trimmedRange)
        return SQLStatement(
            text: text,
            range: trimmedRange,
            lineRange: lineRange,
            isMultiline: lineRange.lowerBound != lineRange.upperBound,
            classification: SQLStatementClassifier.classify(text)
        )
    }

    private static func trimWhitespace(in sql: String, range: Range<String.Index>) -> Range<String.Index> {
        var lowerBound = range.lowerBound
        var upperBound = range.upperBound

        while lowerBound < upperBound, sql[lowerBound].isWhitespace {
            lowerBound = sql.index(after: lowerBound)
        }

        while lowerBound < upperBound {
            let previous = sql.index(before: upperBound)
            if sql[previous].isWhitespace {
                upperBound = previous
            } else {
                break
            }
        }

        return lowerBound..<upperBound
    }

    private static func lineRange(in sql: String, range: Range<String.Index>) -> ClosedRange<Int> {
        let startLine = lineNumber(in: sql, at: range.lowerBound)
        let endLine = lineNumber(in: sql, at: range.upperBound)
        return startLine...endLine
    }

    private static func lineNumber(in sql: String, at index: String.Index) -> Int {
        var line = 1
        var current = sql.startIndex
        while current < index, current < sql.endIndex {
            if sql[current] == "\n" {
                line += 1
            }
            current = sql.index(after: current)
        }
        return line
    }

    private static func stringIndex(in sql: String, utf16Offset: Int) -> String.Index {
        let boundedOffset = max(0, min(utf16Offset, sql.utf16.count))
        return String.Index(utf16Offset: boundedOffset, in: sql)
    }
}

private extension SQLToken {
    func isBlankLineSeparator(in sql: String) -> Bool {
        guard kind == .whitespace else {
            return false
        }

        let text = String(sql[range])
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        return text.range(of: #"\n[ \t]*\n"#, options: .regularExpression) != nil
    }
}

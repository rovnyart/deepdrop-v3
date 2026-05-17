//
//  SQLSyntaxHighlighter.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import AppKit

enum SQLSyntaxHighlighter {
    private static let keywords: Set<String> = [
        "select", "from", "where", "join", "left", "right", "inner", "outer", "full", "on",
        "group", "by", "order", "having", "limit", "offset", "with", "as", "distinct",
        "insert", "into", "values", "update", "set", "delete", "returning", "merge",
        "create", "alter", "drop", "truncate", "table", "view", "materialized", "index",
        "function", "schema", "database", "primary", "foreign", "key", "references",
        "null", "not", "and", "or", "is", "in", "exists", "case", "when", "then", "else", "end",
        "true", "false", "explain", "analyze", "begin", "commit", "rollback"
    ]

    static func highlight(_ textStorage: NSTextStorage, font: NSFont) {
        let fullRange = NSRange(location: 0, length: textStorage.length)
        guard fullRange.length > 0 else {
            return
        }

        let baseColor = NSColor.labelColor
        textStorage.setAttributes([
            .font: font,
            .foregroundColor: baseColor
        ], range: fullRange)

        let source = textStorage.string as NSString
        highlightComments(in: textStorage, source: source)
        highlightStrings(in: textStorage, source: source)
        highlightKeywords(in: textStorage, source: source)
    }

    private static func highlightComments(in textStorage: NSTextStorage, source: NSString) {
        let patterns = [
            #"--[^\n\r]*"#,
            #"/\*[\s\S]*?\*/"#
        ]

        apply(patterns: patterns, color: .secondaryLabelColor, in: textStorage, source: source)
    }

    private static func highlightStrings(in textStorage: NSTextStorage, source: NSString) {
        let patterns = [
            #"'(?:''|[^'])*'"#,
            #""(?:""|[^"])*""#,
            #"\$[A-Za-z_][A-Za-z0-9_]*\$[\s\S]*?\$[A-Za-z_][A-Za-z0-9_]*\$"#,
            #"\$\$[\s\S]*?\$\$"#
        ]

        apply(patterns: patterns, color: .systemGreen, in: textStorage, source: source)
    }

    private static func highlightKeywords(in textStorage: NSTextStorage, source: NSString) {
        let pattern = #"\b[A-Za-z_][A-Za-z0-9_]*\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return
        }

        let range = NSRange(location: 0, length: source.length)
        regex.enumerateMatches(in: source as String, range: range) { match, _, _ in
            guard let matchRange = match?.range else {
                return
            }

            let word = source.substring(with: matchRange).lowercased()
            if keywords.contains(word) {
                textStorage.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: matchRange)
            }
        }
    }

    private static func apply(
        patterns: [String],
        color: NSColor,
        in textStorage: NSTextStorage,
        source: NSString
    ) {
        let fullRange = NSRange(location: 0, length: source.length)
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                continue
            }

            regex.enumerateMatches(in: source as String, range: fullRange) { match, _, _ in
                guard let matchRange = match?.range else {
                    return
                }

                textStorage.addAttribute(.foregroundColor, value: color, range: matchRange)
            }
        }
    }
}

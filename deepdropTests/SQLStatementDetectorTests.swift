//
//  SQLStatementDetectorTests.swift
//  deepdropTests
//
//  Created by Codex on 17.05.2026.
//

import Foundation
import Testing
@testable import deepdrop

struct SQLStatementDetectorTests {
    @Test func semicolonsSplitStatements() {
        let sql = "select 1; select 2;"
        let statement = SQLStatementDetector.statement(in: sql, selectedRange: emptySelection(at: 12), cursorLocation: 12)

        #expect(statement?.text == "select 2")
    }

    @Test func semicolonInsideStringDoesNotSplit() {
        let sql = "select ';' as value; select 2;"
        let statement = SQLStatementDetector.statement(in: sql, selectedRange: emptySelection(at: 10), cursorLocation: 10)

        #expect(statement?.text == "select ';' as value")
    }

    @Test func semicolonInsideDollarQuoteDoesNotSplit() {
        let sql = "select $$one;two$$; select 2;"
        let statement = SQLStatementDetector.statement(in: sql, selectedRange: emptySelection(at: 12), cursorLocation: 12)

        #expect(statement?.text == "select $$one;two$$")
    }

    @Test func selectionTakesPrecedence() {
        let sql = "select 1;\nselect 2;"
        let selection = NSRange(location: 10, length: 8)
        let statement = SQLStatementDetector.statement(in: sql, selectedRange: selection, cursorLocation: 0)

        #expect(statement?.text == "select 2")
    }

    @Test func multilineStatementIsMarkedMultiline() {
        let sql = "select *\nfrom users\nwhere id = 1;"
        let statement = SQLStatementDetector.statement(in: sql, selectedRange: emptySelection(at: 2), cursorLocation: 2)

        #expect(statement?.isMultiline == true)
        #expect(statement?.lineRange == 1...3)
    }

    @Test func classifierIgnoresLeadingComments() {
        let sql = "-- explain\nupdate users set name = 'A';"
        let statement = SQLStatementDetector.statement(in: sql, selectedRange: emptySelection(at: sql.count - 2), cursorLocation: sql.count - 2)

        #expect(statement?.classification == .mutation)
    }

    @Test func blankLinesSplitStatementsWithoutSemicolon() {
        let sql = "select 1\n\n\nselect *\nfrom users\nwhere id is null;"
        let secondStatementCursor = sql.range(of: "from users")!.lowerBound.utf16Offset(in: sql)
        let statement = SQLStatementDetector.statement(
            in: sql,
            selectedRange: emptySelection(at: secondStatementCursor),
            cursorLocation: secondStatementCursor
        )

        #expect(statement?.text == "select *\nfrom users\nwhere id is null")
    }

    @Test func cursorAfterTrailingSemicolonUsesPreviousStatement() {
        let sql = "select *\nfrom users\nwhere name = '';"
        let statement = SQLStatementDetector.statement(
            in: sql,
            selectedRange: emptySelection(at: sql.count),
            cursorLocation: sql.count
        )

        #expect(statement?.text == "select *\nfrom users\nwhere name = ''")
    }

    @Test func cursorInWhitespaceAfterSemicolonUsesPreviousStatement() {
        let sql = "select 1;   \n\nselect 2"
        let cursor = "select 1; ".count
        let statement = SQLStatementDetector.statement(
            in: sql,
            selectedRange: emptySelection(at: cursor),
            cursorLocation: cursor
        )

        #expect(statement?.text == "select 1")
    }

    private func emptySelection(at location: Int) -> NSRange {
        NSRange(location: location, length: 0)
    }
}

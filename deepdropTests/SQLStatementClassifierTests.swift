//
//  SQLStatementClassifierTests.swift
//  deepdropTests
//
//  Created by Codex on 17.05.2026.
//

import Testing
@testable import deepdrop

struct SQLStatementClassifierTests {
    @Test func classifiesReadOnlyStatements() {
        #expect(SQLStatementClassifier.classify("select * from users") == .readOnly)
        #expect(SQLStatementClassifier.classify("with users as (select 1) select * from users") == .readOnly)
        #expect(SQLStatementClassifier.classify("show search_path") == .readOnly)
    }

    @Test func classifiesMutationStatements() {
        #expect(SQLStatementClassifier.classify("insert into users default values") == .mutation)
        #expect(SQLStatementClassifier.classify("update users set name = 'A'") == .mutation)
        #expect(SQLStatementClassifier.classify("delete from users") == .mutation)
    }

    @Test func classifiesSchemaAndAdminStatements() {
        #expect(SQLStatementClassifier.classify("create table users(id int)") == .schemaChange)
        #expect(SQLStatementClassifier.classify("drop table users") == .schemaChange)
        #expect(SQLStatementClassifier.classify("vacuum analyze users") == .admin)
    }

    @Test func unknownStatementIsUnknown() {
        #expect(SQLStatementClassifier.classify("do $$ begin raise notice 'x'; end $$") == .unknown)
    }
}

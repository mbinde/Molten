//
//  LogbookModelTests.swift
//  Molten
//
//  Tests for LogbookModel with multiple project associations and date fields
//

import Testing
import Foundation
@testable import Molten

@Suite("LogbookModel Tests")
struct LogbookModelTests {

    @Test("LogbookModel initializes with multiple project IDs")
    func testMultipleProjectIds() {
        let projectId1 = UUID()
        let projectId2 = UUID()
        let projectId3 = UUID()

        let log = LogbookModel(
            title: "Test Marble",
            basedOnProjectIds: [projectId1, projectId2, projectId3],
            status: .completed
        )

        #expect(log.basedOnProjectIds.count == 3)
        #expect(log.basedOnProjectIds.contains(projectId1))
        #expect(log.basedOnProjectIds.contains(projectId2))
        #expect(log.basedOnProjectIds.contains(projectId3))
    }

    @Test("LogbookModel initializes with empty project IDs array by default")
    func testEmptyProjectIdsDefault() {
        let log = LogbookModel(
            title: "Test Piece",
            status: .inProgress
        )

        #expect(log.basedOnProjectIds.isEmpty)
    }

    @Test("LogbookModel stores start and completion dates separately")
    func testSeparateStartCompletionDates() {
        let startDate = Date()
        let completionDate = Date().addingTimeInterval(3600 * 24 * 7) // 7 days later

        let log = LogbookModel(
            title: "Week-long Project",
            startDate: startDate,
            completionDate: completionDate,
            status: .completed
        )

        #expect(log.startDate != nil)
        #expect(log.completionDate != nil)
        #expect(log.startDate! < log.completionDate!)
    }

    @Test("LogbookModel can have start date without completion date")
    func testStartDateOnly() {
        let startDate = Date()

        let log = LogbookModel(
            title: "In Progress Project",
            startDate: startDate,
            completionDate: nil,
            status: .inProgress
        )

        #expect(log.startDate != nil)
        #expect(log.completionDate == nil)
    }

    @Test("LogbookModel can have completion date without start date")
    func testCompletionDateOnly() {
        let completionDate = Date()

        let log = LogbookModel(
            title: "Completed Without Start Date",
            startDate: nil,
            completionDate: completionDate,
            status: .completed
        )

        #expect(log.startDate == nil)
        #expect(log.completionDate != nil)
    }

    @Test("LogbookModel defaults COE to numeric value")
    func testCOENumericValue() {
        let log = LogbookModel(
            title: "Test Piece",
            coe: "96",
            status: .completed
        )

        #expect(log.coe == "96")
        // Verify it's a valid COE number
        #expect(["33", "90", "96", "104"].contains(log.coe))
    }

    @Test("LogbookModel is Codable")
    func testCodable() throws {
        let projectId1 = UUID()
        let projectId2 = UUID()

        let original = LogbookModel(
            title: "Codable Test",
            startDate: Date(),
            completionDate: Date().addingTimeInterval(3600),
            basedOnProjectIds: [projectId1, projectId2],
            tags: ["test", "codable"],
            coe: "96",
            status: .completed
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LogbookModel.self, from: data)

        #expect(decoded.title == original.title)
        #expect(decoded.basedOnProjectIds.count == 2)
        #expect(decoded.basedOnProjectIds.contains(projectId1))
        #expect(decoded.basedOnProjectIds.contains(projectId2))
        #expect(decoded.coe == original.coe)
        #expect(decoded.status == original.status)
    }

    @Test("LogbookModel is Hashable")
    func testHashable() {
        let log1 = LogbookModel(
            id: UUID(),
            title: "Test 1",
            status: .completed
        )

        let log2 = LogbookModel(
            id: log1.id,
            title: "Test 1",
            status: .completed
        )

        let log3 = LogbookModel(
            id: UUID(),
            title: "Test 2",
            status: .completed
        )

        #expect(log1.hashValue == log2.hashValue)
        #expect(log1.hashValue != log3.hashValue)

        let set: Set<LogbookModel> = [log1, log2, log3]
        #expect(set.count == 2) // log1 and log2 are the same
    }
}

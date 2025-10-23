//
//  MockLogbookRepositoryTests.swift
//  Molten
//
//  Tests for MockLogbookRepository with new date range logic
//

import Testing
import Foundation
@testable import Molten

@Suite("MockLogbookRepository Tests")
struct MockLogbookRepositoryTests {

    @Test("Create and retrieve log with multiple project IDs")
    func testCreateAndRetrieveWithMultipleProjects() async throws {
        let repository = MockLogbookRepository()
        let projectId1 = UUID()
        let projectId2 = UUID()

        let log = LogbookModel(
            title: "Multi-Project Log",
            basedOnProjectIds: [projectId1, projectId2],
            status: .completed
        )

        let created = try await repository.createLog(log)
        let retrieved = try await repository.getLog(id: created.id)

        #expect(retrieved != nil)
        #expect(retrieved?.basedOnProjectIds.count == 2)
        #expect(retrieved?.basedOnProjectIds.contains(projectId1) == true)
        #expect(retrieved?.basedOnProjectIds.contains(projectId2) == true)
    }

    @Test("Date range query includes logs with start date in range")
    func testDateRangeWithStartDate() async throws {
        let repository = MockLogbookRepository()

        let startDate = Date()
        let log = LogbookModel(
            title: "Started Log",
            startDate: startDate,
            completionDate: nil,
            status: .inProgress
        )

        _ = try await repository.createLog(log)

        let rangeStart = startDate.addingTimeInterval(-3600)
        let rangeEnd = startDate.addingTimeInterval(3600)
        let results = try await repository.getLogsByDateRange(start: rangeStart, end: rangeEnd)

        #expect(results.count == 1)
        #expect(results.first?.title == "Started Log")
    }

    @Test("Date range query includes logs with completion date in range")
    func testDateRangeWithCompletionDate() async throws {
        let repository = MockLogbookRepository()

        let completionDate = Date()
        let log = LogbookModel(
            title: "Completed Log",
            startDate: nil,
            completionDate: completionDate,
            status: .completed
        )

        _ = try await repository.createLog(log)

        let rangeStart = completionDate.addingTimeInterval(-3600)
        let rangeEnd = completionDate.addingTimeInterval(3600)
        let results = try await repository.getLogsByDateRange(start: rangeStart, end: rangeEnd)

        #expect(results.count == 1)
        #expect(results.first?.title == "Completed Log")
    }

    @Test("Date range query includes logs with either date in range")
    func testDateRangeWithBothDates() async throws {
        let repository = MockLogbookRepository()

        let baseDate = Date()
        let startDate = baseDate.addingTimeInterval(-3600 * 24 * 7) // 7 days ago
        let completionDate = baseDate // Today

        let log = LogbookModel(
            title: "Week-long Project",
            startDate: startDate,
            completionDate: completionDate,
            status: .completed
        )

        _ = try await repository.createLog(log)

        // Query for range that includes completion date but not start date
        let rangeStart = baseDate.addingTimeInterval(-3600)
        let rangeEnd = baseDate.addingTimeInterval(3600)
        let results = try await repository.getLogsByDateRange(start: rangeStart, end: rangeEnd)

        #expect(results.count == 1)
        #expect(results.first?.title == "Week-long Project")
    }

    @Test("Date range query excludes logs outside range")
    func testDateRangeExcludesOutsideRange() async throws {
        let repository = MockLogbookRepository()

        let oldDate = Date().addingTimeInterval(-3600 * 24 * 30) // 30 days ago
        let log = LogbookModel(
            title: "Old Log",
            startDate: oldDate,
            completionDate: oldDate,
            status: .completed
        )

        _ = try await repository.createLog(log)

        // Query for recent dates
        let rangeStart = Date().addingTimeInterval(-3600 * 24) // 1 day ago
        let rangeEnd = Date()
        let results = try await repository.getLogsByDateRange(start: rangeStart, end: rangeEnd)

        #expect(results.isEmpty)
    }

    @Test("Date range query uses created date when start and completion are nil")
    func testDateRangeUsesCreatedDateFallback() async throws {
        let repository = MockLogbookRepository()

        let log = LogbookModel(
            title: "No Dates Set",
            startDate: nil,
            completionDate: nil,
            status: .inProgress
        )

        let created = try await repository.createLog(log)

        // Query for range around creation time
        let rangeStart = created.dateCreated.addingTimeInterval(-60)
        let rangeEnd = created.dateCreated.addingTimeInterval(60)
        let results = try await repository.getLogsByDateRange(start: rangeStart, end: rangeEnd)

        #expect(results.count == 1)
        #expect(results.first?.title == "No Dates Set")
    }

    @Test("Date range query sorts by completion, then start, then created")
    func testDateRangeSortOrder() async throws {
        let repository = MockLogbookRepository()

        let baseDate = Date()

        // Log 1: Has completion date (most recent)
        let log1 = LogbookModel(
            title: "Recently Completed",
            startDate: baseDate.addingTimeInterval(-7200),
            completionDate: baseDate,
            status: .completed
        )

        // Log 2: Has only start date (middle)
        let log2 = LogbookModel(
            title: "In Progress",
            startDate: baseDate.addingTimeInterval(-3600),
            completionDate: nil,
            status: .inProgress
        )

        // Log 3: Has neither (falls back to created date, oldest)
        let log3 = LogbookModel(
            title: "No Dates",
            startDate: nil,
            completionDate: nil,
            status: .inProgress
        )

        _ = try await repository.createLog(log3)
        await Task.yield() // Small delay to ensure different creation times
        _ = try await repository.createLog(log2)
        await Task.yield()
        _ = try await repository.createLog(log1)

        let rangeStart = baseDate.addingTimeInterval(-10000)
        let rangeEnd = baseDate.addingTimeInterval(1000)
        let results = try await repository.getLogsByDateRange(start: rangeStart, end: rangeEnd)

        #expect(results.count == 3)
        #expect(results[0].title == "Recently Completed") // Has most recent completion date
        #expect(results[1].title == "In Progress") // Has start date
        #expect(results[2].title == "No Dates") // Falls back to created date
    }

    @Test("Update log with new project IDs")
    func testUpdateLogProjectIds() async throws {
        let repository = MockLogbookRepository()
        let projectId1 = UUID()
        let projectId2 = UUID()
        let projectId3 = UUID()

        var log = LogbookModel(
            title: "Evolving Project",
            basedOnProjectIds: [projectId1],
            status: .inProgress
        )

        let created = try await repository.createLog(log)

        // Update to add more project IDs
        log = LogbookModel(
            id: created.id,
            title: created.title,
            dateCreated: created.dateCreated,
            dateModified: Date(),
            basedOnProjectIds: [projectId1, projectId2, projectId3],
            status: .completed
        )

        try await repository.updateLog(log)
        let updated = try await repository.getLog(id: created.id)

        #expect(updated?.basedOnProjectIds.count == 3)
        #expect(updated?.basedOnProjectIds.contains(projectId1) == true)
        #expect(updated?.basedOnProjectIds.contains(projectId2) == true)
        #expect(updated?.basedOnProjectIds.contains(projectId3) == true)
    }

    @Test("Delete log removes it from repository")
    func testDeleteLog() async throws {
        let repository = MockLogbookRepository()

        let log = LogbookModel(
            title: "To Be Deleted",
            status: .broken
        )

        let created = try await repository.createLog(log)
        let beforeDelete = try await repository.getLog(id: created.id)
        #expect(beforeDelete != nil)

        try await repository.deleteLog(id: created.id)
        let afterDelete = try await repository.getLog(id: created.id)
        #expect(afterDelete == nil)
    }

    @Test("Get logs by status filters correctly")
    func testGetLogsByStatus() async throws {
        let repository = MockLogbookRepository()

        _ = try await repository.createLog(LogbookModel(title: "In Progress", status: .inProgress))
        _ = try await repository.createLog(LogbookModel(title: "Completed 1", status: .completed))
        _ = try await repository.createLog(LogbookModel(title: "Completed 2", status: .completed))
        _ = try await repository.createLog(LogbookModel(title: "Sold", status: .sold))

        let completedLogs = try await repository.getLogs(status: .completed)
        #expect(completedLogs.count == 2)

        let soldLogs = try await repository.getLogs(status: .sold)
        #expect(soldLogs.count == 1)

        let allLogs = try await repository.getLogs(status: nil)
        #expect(allLogs.count == 4)
    }
}

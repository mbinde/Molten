//
//  ProjectLogRepositoryTests.swift
//  Flameworker
//
//  Tests for ProjectLogRepository implementations (Mock and Core Data)
//

#if canImport(Testing)
import Testing
import Foundation
@testable import Molten

@Suite("ProjectLogRepository Tests")
struct ProjectLogRepositoryTests {

    // MARK: - Test Helpers

    func createTestLog(
        id: UUID = UUID(),
        title: String = "Test Log",
        projectDate: Date? = Date(),
        status: ProjectStatus = .inProgress,
        basedOnPlanId: UUID? = nil,
        tags: [String] = ["test"],
        notes: String? = "Test notes",
        pricePoint: Decimal? = nil,
        saleDate: Date? = nil
    ) -> ProjectLogModel {
        return ProjectLogModel(
            id: id,
            title: title,
            projectDate: projectDate,
            basedOnPlanId: basedOnPlanId,
            tags: tags,
            notes: notes,
            pricePoint: pricePoint,
            saleDate: saleDate,
            status: status
        )
    }

    // MARK: - CRUD Operations Tests

    @Test("Create log successfully")
    func testCreateLog() async throws {
        let repository = MockProjectLogRepository()
        let log = createTestLog(title: "New Log")

        let created = try await repository.createLog(log)

        #expect(created.id == log.id)
        #expect(created.title == "New Log")
        #expect(await repository.getLogCount() == 1)
    }

    @Test("Get log by ID")
    func testGetLogById() async throws {
        let repository = MockProjectLogRepository()
        let log1 = createTestLog(title: "Log 1")
        let log2 = createTestLog(title: "Log 2")

        _ = try await repository.createLog(log1)
        _ = try await repository.createLog(log2)

        let fetched = try await repository.getLog(id: log1.id)

        #expect(fetched?.id == log1.id)
        #expect(fetched?.title == "Log 1")
    }

    @Test("Get non-existent log returns nil")
    func testGetNonExistentLog() async throws {
        let repository = MockProjectLogRepository()

        let fetched = try await repository.getLog(id: UUID())

        #expect(fetched == nil)
    }

    @Test("Get all logs")
    func testGetAllLogs() async throws {
        let repository = MockProjectLogRepository()

        let log1 = createTestLog(title: "Log 1")
        let log2 = createTestLog(title: "Log 2")
        let log3 = createTestLog(title: "Log 3")

        _ = try await repository.createLog(log1)
        _ = try await repository.createLog(log2)
        _ = try await repository.createLog(log3)

        let allLogs = try await repository.getAllLogs()

        #expect(allLogs.count == 3)
        #expect(allLogs.contains { $0.title == "Log 1" })
        #expect(allLogs.contains { $0.title == "Log 2" })
        #expect(allLogs.contains { $0.title == "Log 3" })
    }

    @Test("Get logs by status")
    func testGetLogsByStatus() async throws {
        let repository = MockProjectLogRepository()

        let inProgress = createTestLog(title: "In Progress", status: .inProgress)
        let completed = createTestLog(title: "Completed", status: .completed)
        let sold = createTestLog(title: "Sold", status: .sold)

        _ = try await repository.createLog(inProgress)
        _ = try await repository.createLog(completed)
        _ = try await repository.createLog(sold)

        let inProgressLogs = try await repository.getLogs(status: .inProgress)
        let completedLogs = try await repository.getLogs(status: .completed)
        let soldLogs = try await repository.getLogs(status: .sold)

        #expect(inProgressLogs.count == 1)
        #expect(inProgressLogs.first?.title == "In Progress")
        #expect(completedLogs.count == 1)
        #expect(completedLogs.first?.title == "Completed")
        #expect(soldLogs.count == 1)
        #expect(soldLogs.first?.title == "Sold")
    }

    @Test("Get logs with nil status returns all")
    func testGetLogsNilStatus() async throws {
        let repository = MockProjectLogRepository()

        let log1 = createTestLog(title: "Log 1", status: .inProgress)
        let log2 = createTestLog(title: "Log 2", status: .sold)

        _ = try await repository.createLog(log1)
        _ = try await repository.createLog(log2)

        let allLogs = try await repository.getLogs(status: nil)

        #expect(allLogs.count == 2)
    }

    @Test("Update log")
    func testUpdateLog() async throws {
        let repository = MockProjectLogRepository()
        let log = createTestLog(title: "Original Title")
        _ = try await repository.createLog(log)

        let updatedLog = ProjectLogModel(
            id: log.id,
            title: "Updated Title",
            notes: "Updated notes",
            status: .completed
        )

        try await repository.updateLog(updatedLog)

        let fetched = try await repository.getLog(id: log.id)
        #expect(fetched?.title == "Updated Title")
        #expect(fetched?.notes == "Updated notes")
        #expect(fetched?.status == .completed)
    }

    @Test("Update non-existent log throws error")
    func testUpdateNonExistentLog() async throws {
        let repository = MockProjectLogRepository()
        let log = createTestLog()

        await #expect(throws: ProjectRepositoryError.logNotFound) {
            try await repository.updateLog(log)
        }
    }

    @Test("Delete log successfully")
    func testDeleteLog() async throws {
        let repository = MockProjectLogRepository()
        let log = createTestLog()
        _ = try await repository.createLog(log)

        #expect(await repository.getLogCount() == 1)

        try await repository.deleteLog(id: log.id)

        #expect(await repository.getLogCount() == 0)
        let fetched = try await repository.getLog(id: log.id)
        #expect(fetched == nil)
    }

    @Test("Delete non-existent log throws error")
    func testDeleteNonExistentLog() async throws {
        let repository = MockProjectLogRepository()

        await #expect(throws: ProjectRepositoryError.logNotFound) {
            try await repository.deleteLog(id: UUID())
        }
    }

    // MARK: - Business Queries Tests

    @Test("Get logs by date range")
    func testGetLogsByDateRange() async throws {
        let repository = MockProjectLogRepository()

        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!

        let log1 = createTestLog(title: "Log 1", projectDate: threeDaysAgo)
        let log2 = createTestLog(title: "Log 2", projectDate: yesterday)
        let log3 = createTestLog(title: "Log 3", projectDate: today)

        _ = try await repository.createLog(log1)
        _ = try await repository.createLog(log2)
        _ = try await repository.createLog(log3)

        let results = try await repository.getLogsByDateRange(start: twoDaysAgo, end: today)

        #expect(results.count == 2)
        #expect(results.contains { $0.title == "Log 2" })
        #expect(results.contains { $0.title == "Log 3" })
    }

    @Test("Get logs by date range with exact boundaries")
    func testGetLogsByDateRangeExactBoundaries() async throws {
        let repository = MockProjectLogRepository()

        let calendar = Calendar.current
        let startDate = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let midDate = calendar.date(from: DateComponents(year: 2024, month: 1, day: 15))!
        let endDate = calendar.date(from: DateComponents(year: 2024, month: 1, day: 31))!

        let before = createTestLog(
            title: "Before",
            projectDate: calendar.date(byAdding: .day, value: -1, to: startDate)!
        )
        let atStart = createTestLog(title: "At Start", projectDate: startDate)
        let inMiddle = createTestLog(title: "In Middle", projectDate: midDate)
        let atEnd = createTestLog(title: "At End", projectDate: endDate)
        let after = createTestLog(
            title: "After",
            projectDate: calendar.date(byAdding: .day, value: 1, to: endDate)!
        )

        _ = try await repository.createLog(before)
        _ = try await repository.createLog(atStart)
        _ = try await repository.createLog(inMiddle)
        _ = try await repository.createLog(atEnd)
        _ = try await repository.createLog(after)

        let results = try await repository.getLogsByDateRange(start: startDate, end: endDate)

        #expect(results.count == 3)
        #expect(results.contains { $0.title == "At Start" })
        #expect(results.contains { $0.title == "In Middle" })
        #expect(results.contains { $0.title == "At End" })
    }

    @Test("Get logs by date range excludes nil dates")
    func testGetLogsByDateRangeExcludesNilDates() async throws {
        let repository = MockProjectLogRepository()

        let logWithDate = createTestLog(title: "With Date", projectDate: Date())
        let logWithoutDate = createTestLog(title: "Without Date", projectDate: nil)

        _ = try await repository.createLog(logWithDate)
        _ = try await repository.createLog(logWithoutDate)

        let results = try await repository.getLogsByDateRange(
            start: Date(timeIntervalSinceNow: -86400),
            end: Date(timeIntervalSinceNow: 86400)
        )

        #expect(results.count == 1)
        #expect(results.first?.title == "With Date")
    }

    @Test("Get sold logs")
    func testGetSoldLogs() async throws {
        let repository = MockProjectLogRepository()

        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let inProgress = createTestLog(title: "In Progress", status: .inProgress)
        let sold1 = createTestLog(
            title: "Sold 1",
            status: .sold,
            pricePoint: 150.00,
            saleDate: yesterday
        )
        let sold2 = createTestLog(
            title: "Sold 2",
            status: .sold,
            pricePoint: 200.00,
            saleDate: today
        )

        _ = try await repository.createLog(inProgress)
        _ = try await repository.createLog(sold1)
        _ = try await repository.createLog(sold2)

        let soldLogs = try await repository.getSoldLogs()

        #expect(soldLogs.count == 2)
        #expect(soldLogs.allSatisfy { $0.status == .sold })
        // Should be sorted by sale date descending (most recent first)
        #expect(soldLogs.first?.title == "Sold 2")
        #expect(soldLogs.last?.title == "Sold 1")
    }

    @Test("Get sold logs without sale date uses dateCreated")
    func testGetSoldLogsWithoutSaleDateSorting() async throws {
        let repository = MockProjectLogRepository()

        let log1 = createTestLog(title: "Sold 1", status: .sold, saleDate: nil)
        _ = try await repository.createLog(log1)

        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds

        let log2 = createTestLog(title: "Sold 2", status: .sold, saleDate: Date())
        _ = try await repository.createLog(log2)

        try await Task.sleep(nanoseconds: 10_000_000)

        let log3 = createTestLog(title: "Sold 3", status: .sold, saleDate: nil)
        _ = try await repository.createLog(log3)

        let soldLogs = try await repository.getSoldLogs()

        #expect(soldLogs.count == 3)
        // Log with sale date should be first
        #expect(soldLogs[0].title == "Sold 2")
    }

    @Test("Get total revenue")
    func testGetTotalRevenue() async throws {
        let repository = MockProjectLogRepository()

        let sold1 = createTestLog(title: "Sold 1", status: .sold, pricePoint: 150.00)
        let sold2 = createTestLog(title: "Sold 2", status: .sold, pricePoint: 200.00)
        let sold3 = createTestLog(title: "Sold 3", status: .sold, pricePoint: 75.50)
        let notSold = createTestLog(title: "Not Sold", status: .completed, pricePoint: 100.00)

        _ = try await repository.createLog(sold1)
        _ = try await repository.createLog(sold2)
        _ = try await repository.createLog(sold3)
        _ = try await repository.createLog(notSold)

        let totalRevenue = try await repository.getTotalRevenue()

        #expect(totalRevenue == 425.50)
    }

    @Test("Get total revenue with no sold items")
    func testGetTotalRevenueNoSales() async throws {
        let repository = MockProjectLogRepository()

        let log = createTestLog(title: "Not Sold", status: .completed)
        _ = try await repository.createLog(log)

        let totalRevenue = try await repository.getTotalRevenue()

        #expect(totalRevenue == 0)
    }

    @Test("Get total revenue handles nil prices")
    func testGetTotalRevenueNilPrices() async throws {
        let repository = MockProjectLogRepository()

        let sold1 = createTestLog(title: "Sold 1", status: .sold, pricePoint: 100.00)
        let sold2 = createTestLog(title: "Sold 2", status: .sold, pricePoint: nil)

        _ = try await repository.createLog(sold1)
        _ = try await repository.createLog(sold2)

        let totalRevenue = try await repository.getTotalRevenue()

        #expect(totalRevenue == 100.00)
    }

    // MARK: - Complex Scenarios

    @Test("Log with all fields populated")
    func testLogWithAllFields() async throws {
        let repository = MockProjectLogRepository()

        let log = ProjectLogModel(
            title: "Complete Log",
            projectDate: Date(),
            basedOnPlanId: UUID(),
            tags: ["advanced", "sculpture", "color"],
            notes: "A comprehensive test log",
            techniquesUsed: ["lampworking", "fuming"],
            hoursSpent: 12.5,
            glassItems: [
                ProjectGlassItem(
                    naturalKey: "be-clear-000",
                    quantity: 3,
                    unit: "rods",
                    notes: "Main structure"
                )
            ],
            pricePoint: 350.00,
            saleDate: Date(),
            buyerInfo: "John Doe",
            status: .sold
        )

        _ = try await repository.createLog(log)
        let fetched = try await repository.getLog(id: log.id)

        #expect(fetched?.title == "Complete Log")
        #expect(fetched?.tags.count == 3)
        #expect(fetched?.status == .sold)
        #expect(fetched?.pricePoint == 350.00)
        #expect(fetched?.buyerInfo == "John Doe")
        #expect(fetched?.glassItems.count == 1)
        #expect(fetched?.techniquesUsed?.count == 2)
        #expect(fetched?.hoursSpent == 12.5)
    }

    @Test("Reset clears all logs")
    func testReset() async throws {
        let repository = MockProjectLogRepository()

        _ = try await repository.createLog(createTestLog(title: "Log 1"))
        _ = try await repository.createLog(createTestLog(title: "Log 2"))
        _ = try await repository.createLog(createTestLog(title: "Log 3"))

        #expect(await repository.getLogCount() == 3)

        await repository.reset()

        #expect(await repository.getLogCount() == 0)
        let allLogs = try await repository.getAllLogs()
        #expect(allLogs.isEmpty)
    }
}
#endif

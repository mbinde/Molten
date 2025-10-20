//
//  CoreDataProjectLogRepositoryTests.swift
//  Flameworker
//
//  Tests for CoreDataProjectLogRepository with isolated test context
//

#if canImport(Testing)
import Testing
import Foundation
import CoreData
@testable import Flameworker

@Suite("CoreDataProjectLogRepository Tests")
struct CoreDataProjectLogRepositoryTests {

    // MARK: - Test Helpers

    func createTestContext() -> NSManagedObjectContext {
        let controller = PersistenceController.createTestController()
        return controller.container.viewContext
    }

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

    @Test("Core Data: Create log successfully")
    func testCreateLog() async throws {
        let context = createTestContext()
        let repository = CoreDataProjectLogRepository(context: context)
        let log = createTestLog(title: "New Log")

        let created = try await repository.createLog(log)

        #expect(created.id == log.id)
        #expect(created.title == "New Log")
    }

    @Test("Core Data: Get log by ID")
    func testGetLogById() async throws {
        let context = createTestContext()
        let repository = CoreDataProjectLogRepository(context: context)
        let log = createTestLog(title: "Test Log")

        _ = try await repository.createLog(log)
        let fetched = try await repository.getLog(id: log.id)

        #expect(fetched?.id == log.id)
        #expect(fetched?.title == "Test Log")
    }

    @Test("Core Data: Get non-existent log returns nil")
    func testGetNonExistentLog() async throws {
        let context = createTestContext()
        let repository = CoreDataProjectLogRepository(context: context)

        let fetched = try await repository.getLog(id: UUID())

        #expect(fetched == nil)
    }

    @Test("Core Data: Get all logs")
    func testGetAllLogs() async throws {
        let context = createTestContext()
        let repository = CoreDataProjectLogRepository(context: context)

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

    @Test("Core Data: Get logs by status")
    func testGetLogsByStatus() async throws {
        let context = createTestContext()
        let repository = CoreDataProjectLogRepository(context: context)

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

    @Test("Core Data: Get logs with nil status returns all")
    func testGetLogsNilStatus() async throws {
        let context = createTestContext()
        let repository = CoreDataProjectLogRepository(context: context)

        let log1 = createTestLog(title: "Log 1", status: .inProgress)
        let log2 = createTestLog(title: "Log 2", status: .sold)

        _ = try await repository.createLog(log1)
        _ = try await repository.createLog(log2)

        let allLogs = try await repository.getLogs(status: nil)

        #expect(allLogs.count == 2)
    }

    @Test("Core Data: Update log")
    func testUpdateLog() async throws {
        let context = createTestContext()
        let repository = CoreDataProjectLogRepository(context: context)
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

    @Test("Core Data: Update non-existent log throws error")
    func testUpdateNonExistentLog() async throws {
        let context = createTestContext()
        let repository = CoreDataProjectLogRepository(context: context)
        let log = createTestLog()

        await #expect(throws: ProjectRepositoryError.logNotFound) {
            try await repository.updateLog(log)
        }
    }

    @Test("Core Data: Delete log successfully")
    func testDeleteLog() async throws {
        let context = createTestContext()
        let repository = CoreDataProjectLogRepository(context: context)
        let log = createTestLog()
        _ = try await repository.createLog(log)

        try await repository.deleteLog(id: log.id)

        let fetched = try await repository.getLog(id: log.id)
        #expect(fetched == nil)
    }

    @Test("Core Data: Delete non-existent log throws error")
    func testDeleteNonExistentLog() async throws {
        let context = createTestContext()
        let repository = CoreDataProjectLogRepository(context: context)

        await #expect(throws: ProjectRepositoryError.logNotFound) {
            try await repository.deleteLog(id: UUID())
        }
    }

    // MARK: - Business Queries Tests

    @Test("Core Data: Get logs by date range")
    func testGetLogsByDateRange() async throws {
        let context = createTestContext()
        let repository = CoreDataProjectLogRepository(context: context)

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

    @Test("Core Data: Get sold logs")
    func testGetSoldLogs() async throws {
        let context = createTestContext()
        let repository = CoreDataProjectLogRepository(context: context)

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

    @Test("Core Data: Get total revenue")
    func testGetTotalRevenue() async throws {
        let context = createTestContext()
        let repository = CoreDataProjectLogRepository(context: context)

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

    @Test("Core Data: Get total revenue with no sold items")
    func testGetTotalRevenueNoSales() async throws {
        let context = createTestContext()
        let repository = CoreDataProjectLogRepository(context: context)

        let log = createTestLog(title: "Not Sold", status: .completed)
        _ = try await repository.createLog(log)

        let totalRevenue = try await repository.getTotalRevenue()

        #expect(totalRevenue == 0)
    }

    // MARK: - Complex Scenarios

    @Test("Core Data: Log with all fields populated")
    func testLogWithAllFields() async throws {
        let context = createTestContext()
        let repository = CoreDataProjectLogRepository(context: context)

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

    @Test("Core Data: JSON encoding/decoding for arrays")
    func testArrayEncodingDecoding() async throws {
        let context = createTestContext()
        let repository = CoreDataProjectLogRepository(context: context)

        let log = ProjectLogModel(
            title: "Test Encoding",
            tags: ["tag1", "tag2", "tag3"],
            techniquesUsed: ["technique1", "technique2"],
            glassItems: [
                ProjectGlassItem(naturalKey: "item1", quantity: 1.0, unit: "rods"),
                ProjectGlassItem(naturalKey: "item2", quantity: 2.5, unit: "tubes")
            ],
            status: .inProgress
        )

        _ = try await repository.createLog(log)
        let fetched = try await repository.getLog(id: log.id)

        #expect(fetched?.tags == ["tag1", "tag2", "tag3"])
        #expect(fetched?.techniquesUsed == ["technique1", "technique2"])
        #expect(fetched?.glassItems.count == 2)
        #expect(fetched?.glassItems.first?.naturalKey == "item1")
        #expect(fetched?.glassItems.last?.quantity == 2.5)
    }

    @Test("Core Data: Persistence across context operations")
    func testPersistenceAcrossOperations() async throws {
        let controller = PersistenceController.createTestController()
        let context1 = controller.container.viewContext
        let repository1 = CoreDataProjectLogRepository(context: context1)

        let log = createTestLog(title: "Persistent Log")
        _ = try await repository1.createLog(log)

        // Create a new repository with the same context
        let repository2 = CoreDataProjectLogRepository(context: context1)
        let fetched = try await repository2.getLog(id: log.id)

        #expect(fetched?.title == "Persistent Log")
    }
}
#endif

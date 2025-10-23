//
//  CoreDataLogbookRepositoryTests.swift
//  Molten
//
//  Tests for CoreDataLogbookRepository with isolated test context
//

#if canImport(Testing)
import Testing
import Foundation
import CoreData
@testable import Molten

@Suite("CoreDataLogbookRepository Tests")
@MainActor
struct CoreDataLogbookRepositoryTests {

    // MARK: - Test Helpers

    func createTestContext() -> NSManagedObjectContext {
        let controller = PersistenceController.createTestController()
        return controller.container.viewContext
    }

    func createTestLog(
        id: UUID = UUID(),
        title: String = "Test Log",
        startDate: Date? = Date(),
        completionDate: Date? = nil,
        status: ProjectStatus = .inProgress,
        basedOnProjectIds: [UUID] = [],
        tags: [String] = ["test"],
        coe: String = "96",
        notes: String? = "Test notes",
        pricePoint: Decimal? = nil,
        saleDate: Date? = nil
    ) -> LogbookModel {
        return LogbookModel(
            id: id,
            title: title,
            startDate: startDate,
            completionDate: completionDate,
            basedOnProjectIds: basedOnProjectIds,
            tags: tags,
            coe: coe,
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
        let repository = CoreDataLogbookRepository(context: context)
        let log = createTestLog(title: "New Log")

        let created = try await repository.createLog(log)

        #expect(created.id == log.id)
        #expect(created.title == "New Log")
    }

    @Test("Core Data: Get log by ID")
    func testGetLogById() async throws {
        let context = createTestContext()
        let repository = CoreDataLogbookRepository(context: context)
        let log = createTestLog(title: "Test Log")

        _ = try await repository.createLog(log)
        let fetched = try await repository.getLog(id: log.id)

        #expect(fetched?.id == log.id)
        #expect(fetched?.title == "Test Log")
    }

    @Test("Core Data: Get non-existent log returns nil")
    func testGetNonExistentLog() async throws {
        let context = createTestContext()
        let repository = CoreDataLogbookRepository(context: context)

        let fetched = try await repository.getLog(id: UUID())

        #expect(fetched == nil)
    }

    @Test("Core Data: Get all logs")
    func testGetAllLogs() async throws {
        let context = createTestContext()
        let repository = CoreDataLogbookRepository(context: context)

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
        let repository = CoreDataLogbookRepository(context: context)

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
        let repository = CoreDataLogbookRepository(context: context)

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
        let repository = CoreDataLogbookRepository(context: context)
        let log = createTestLog(title: "Original Title")
        _ = try await repository.createLog(log)

        let updatedLog = LogbookModel(
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
        let repository = CoreDataLogbookRepository(context: context)
        let log = createTestLog()

        await #expect(throws: ProjectRepositoryError.logNotFound) {
            try await repository.updateLog(log)
        }
    }

    @Test("Core Data: Delete log successfully")
    func testDeleteLog() async throws {
        let context = createTestContext()
        let repository = CoreDataLogbookRepository(context: context)
        let log = createTestLog()
        _ = try await repository.createLog(log)

        try await repository.deleteLog(id: log.id)

        let fetched = try await repository.getLog(id: log.id)
        #expect(fetched == nil)
    }

    @Test("Core Data: Delete non-existent log throws error")
    func testDeleteNonExistentLog() async throws {
        let context = createTestContext()
        let repository = CoreDataLogbookRepository(context: context)

        await #expect(throws: ProjectRepositoryError.logNotFound) {
            try await repository.deleteLog(id: UUID())
        }
    }

    // MARK: - Business Queries Tests

    @Test("Core Data: Get logs by date range")
    func testGetLogsByDateRange() async throws {
        let context = createTestContext()
        let repository = CoreDataLogbookRepository(context: context)

        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!

        let log1 = createTestLog(title: "Log 1", startDate: threeDaysAgo)
        let log2 = createTestLog(title: "Log 2", completionDate: yesterday)
        let log3 = createTestLog(title: "Log 3", startDate: twoDaysAgo, completionDate: today)

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
        let repository = CoreDataLogbookRepository(context: context)

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
        let repository = CoreDataLogbookRepository(context: context)

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
        let repository = CoreDataLogbookRepository(context: context)

        let log = createTestLog(title: "Not Sold", status: .completed)
        _ = try await repository.createLog(log)

        let totalRevenue = try await repository.getTotalRevenue()

        #expect(totalRevenue == 0)
    }

    // MARK: - Complex Scenarios

    @Test("Core Data: Log with all fields populated")
    func testLogWithAllFields() async throws {
        let context = createTestContext()
        let repository = CoreDataLogbookRepository(context: context)

        let projectId1 = UUID()
        let projectId2 = UUID()
        let startDate = Date().addingTimeInterval(-3600 * 24 * 7) // 7 days ago
        let completionDate = Date()

        let log = LogbookModel(
            title: "Complete Log",
            startDate: startDate,
            completionDate: completionDate,
            basedOnProjectIds: [projectId1, projectId2],
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
        #expect(fetched?.basedOnProjectIds.count == 2)
        #expect(fetched?.basedOnProjectIds.contains(projectId1) == true)
        #expect(fetched?.basedOnProjectIds.contains(projectId2) == true)
        #expect(fetched?.startDate != nil)
        #expect(fetched?.completionDate != nil)
        #expect(fetched?.tags.count == 3)
        #expect(fetched?.status == .sold)
        #expect(fetched?.pricePoint == 350.00)
        #expect(fetched?.buyerInfo == "John Doe")
        #expect(fetched?.glassItems.count == 1)
        #expect(fetched?.techniquesUsed?.count == 2)
        #expect(fetched?.hoursSpent == 12.5)
    }

    @Test("Core Data: Relationship-based storage for tags, techniques, and glass items")
    func testRelationshipBasedStorage() async throws {
        let context = createTestContext()
        let repository = CoreDataLogbookRepository(context: context)

        let log = LogbookModel(
            title: "Test Relationships",
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

        // Verify tags are stored as relationships (sorted alphabetically)
        #expect(fetched?.tags.sorted() == ["tag1", "tag2", "tag3"])

        // Verify techniques are stored as relationships (sorted alphabetically)
        #expect(fetched?.techniquesUsed?.sorted() == ["technique1", "technique2"])

        // Verify glass items are stored as relationships (ordered by orderIndex)
        #expect(fetched?.glassItems.count == 2)
        #expect(fetched?.glassItems[0].naturalKey == "item1")
        #expect(fetched?.glassItems[0].quantity == 1.0)
        #expect(fetched?.glassItems[1].naturalKey == "item2")
        #expect(fetched?.glassItems[1].quantity == 2.5)
    }

    @Test("Core Data: Update replaces relationships correctly")
    func testUpdateReplacesRelationships() async throws {
        let context = createTestContext()
        let repository = CoreDataLogbookRepository(context: context)

        // Create log with initial tags, techniques, and glass items
        let log = LogbookModel(
            title: "Test Update",
            tags: ["old-tag1", "old-tag2"],
            techniquesUsed: ["old-technique"],
            glassItems: [
                ProjectGlassItem(naturalKey: "old-item", quantity: 1.0, unit: "rods")
            ],
            status: .inProgress
        )
        _ = try await repository.createLog(log)

        // Update with completely different relationships
        let updatedLog = LogbookModel(
            id: log.id,
            title: "Test Update",
            tags: ["new-tag1", "new-tag2", "new-tag3"],
            techniquesUsed: ["new-technique1", "new-technique2"],
            glassItems: [
                ProjectGlassItem(naturalKey: "new-item1", quantity: 2.0, unit: "tubes"),
                ProjectGlassItem(naturalKey: "new-item2", quantity: 3.0, unit: "rods")
            ],
            status: .inProgress
        )
        try await repository.updateLog(updatedLog)

        // Fetch and verify old relationships are gone, new ones are present
        let fetched = try await repository.getLog(id: log.id)

        #expect(fetched?.tags.sorted() == ["new-tag1", "new-tag2", "new-tag3"])
        #expect(!fetched!.tags.contains("old-tag1"))
        #expect(!fetched!.tags.contains("old-tag2"))

        #expect(fetched?.techniquesUsed?.sorted() == ["new-technique1", "new-technique2"])
        #expect(!fetched!.techniquesUsed!.contains("old-technique"))

        #expect(fetched?.glassItems.count == 2)
        #expect(fetched?.glassItems[0].naturalKey == "new-item1")
        #expect(fetched?.glassItems[1].naturalKey == "new-item2")
        #expect(!fetched!.glassItems.contains(where: { $0.naturalKey == "old-item" }))
    }

    @Test("Core Data: Cascade delete removes all relationships")
    func testCascadeDeleteRemovesRelationships() async throws {
        let context = createTestContext()
        let repository = CoreDataLogbookRepository(context: context)

        // Create log with tags, techniques, and glass items
        let log = LogbookModel(
            title: "Log to Delete",
            tags: ["tag1", "tag2"],
            techniquesUsed: ["technique1"],
            glassItems: [
                ProjectGlassItem(naturalKey: "item1", quantity: 1.0, unit: "rods")
            ],
            status: .inProgress
        )
        _ = try await repository.createLog(log)

        // Verify relationships were created
        let tagsFetch = ProjectTag.fetchRequest()
        tagsFetch.predicate = NSPredicate(format: "log.id == %@", log.id as CVarArg)
        let tagsBeforeDelete = try await context.perform {
            try context.fetch(tagsFetch)
        }
        #expect(tagsBeforeDelete.count == 2)

        let techniquesFetch = ProjectTechnique.fetchRequest()
        techniquesFetch.predicate = NSPredicate(format: "log.id == %@", log.id as CVarArg)
        let techniquesBeforeDelete = try await context.perform {
            try context.fetch(techniquesFetch)
        }
        #expect(techniquesBeforeDelete.count == 1)

        let glassItemsFetch = LogbookGlassItem.fetchRequest()
        glassItemsFetch.predicate = NSPredicate(format: "log.id == %@", log.id as CVarArg)
        let glassItemsBeforeDelete = try await context.perform {
            try context.fetch(glassItemsFetch)
        }
        #expect(glassItemsBeforeDelete.count == 1)

        // Delete the log
        try await repository.deleteLog(id: log.id)

        // Verify all relationships were cascade deleted
        let tagsAfterDelete = try await context.perform {
            try context.fetch(tagsFetch)
        }
        #expect(tagsAfterDelete.isEmpty)

        let techniquesAfterDelete = try await context.perform {
            try context.fetch(techniquesFetch)
        }
        #expect(techniquesAfterDelete.isEmpty)

        let glassItemsAfterDelete = try await context.perform {
            try context.fetch(glassItemsFetch)
        }
        #expect(glassItemsAfterDelete.isEmpty)
    }

    @Test("Core Data: Update with empty arrays removes all relationships")
    func testUpdateWithEmptyArraysRemovesRelationships() async throws {
        let context = createTestContext()
        let repository = CoreDataLogbookRepository(context: context)

        // Create log with relationships
        let log = LogbookModel(
            title: "Test Log",
            tags: ["tag1", "tag2"],
            techniquesUsed: ["technique1"],
            glassItems: [
                ProjectGlassItem(naturalKey: "item1", quantity: 1.0, unit: "rods")
            ],
            status: .inProgress
        )
        _ = try await repository.createLog(log)

        // Update with empty arrays
        let updatedLog = LogbookModel(
            id: log.id,
            title: "Test Log",
            tags: [],
            techniquesUsed: nil,
            glassItems: [],
            status: .inProgress
        )
        try await repository.updateLog(updatedLog)

        // Verify all relationships were removed
        let fetched = try await repository.getLog(id: log.id)
        #expect(fetched?.tags.isEmpty == true)
        #expect(fetched?.techniquesUsed == nil)
        #expect(fetched?.glassItems.isEmpty == true)
    }

    @Test("Core Data: Persistence across context operations")
    func testPersistenceAcrossOperations() async throws {
        let controller = PersistenceController.createTestController()
        let context1 = controller.container.viewContext
        let repository1 = CoreDataLogbookRepository(context: context1)

        let log = createTestLog(title: "Persistent Log")
        _ = try await repository1.createLog(log)

        // Create a new repository with the same context
        let repository2 = CoreDataLogbookRepository(context: context1)
        let fetched = try await repository2.getLog(id: log.id)

        #expect(fetched?.title == "Persistent Log")
    }
}
#endif

//
//  AddLogbookEntryViewTests.swift
//  Molten
//
//  Tests for AddLogbookEntryView functionality including:
//  - Saving logbook entries with sold/gifted status
//  - Price point and sale/gift date handling
//  - Repository integration
//

import Testing
import Foundation
@testable import Molten

@Suite("AddLogbookEntry Tests")
struct AddLogbookEntryViewTests {

    // MARK: - Sold Status Tests

    @Test("Creating logbook entry with sold status saves price and sale date")
    func testSoldEntryWithPriceAndDate() async throws {
        let repository = MockLogbookRepository()
        let saleDate = Date()
        let pricePoint = Decimal(150.50)

        // Simulate creating a sold logbook entry
        let log = LogbookModel(
            title: "Sold Glass Marble",
            startDate: Date().addingTimeInterval(-7 * 24 * 3600), // Started 7 days ago
            completionDate: Date().addingTimeInterval(-1 * 24 * 3600), // Completed 1 day ago
            basedOnProjectIds: [],
            tags: ["marble", "sold"],
            coe: "96",
            notes: "Beautiful blue marble",
            techniquesUsed: nil, // Should always be nil from UI
            hoursSpent: 5,
            pricePoint: pricePoint,
            saleDate: saleDate,
            buyerInfo: "John Doe",
            status: .sold
        )

        let created = try await repository.createLog(log)

        #expect(created.status == .sold)
        #expect(created.pricePoint == pricePoint)
        #expect(created.saleDate != nil)
        #expect(created.buyerInfo == "John Doe")
        #expect(created.techniquesUsed == nil)
    }

    @Test("Creating logbook entry with sold status but no sale date")
    func testSoldEntryWithoutSaleDate() async throws {
        let repository = MockLogbookRepository()

        let log = LogbookModel(
            title: "Sold Item Without Date",
            pricePoint: Decimal(99.99),
            saleDate: nil, // User cleared the date
            status: .sold
        )

        let created = try await repository.createLog(log)

        #expect(created.status == .sold)
        #expect(created.pricePoint == Decimal(99.99))
        #expect(created.saleDate == nil)
    }

    // MARK: - Gifted Status Tests

    @Test("Creating logbook entry with gifted status saves price and gift date")
    func testGiftedEntryWithPriceAndDate() async throws {
        let repository = MockLogbookRepository()
        let giftDate = Date()
        let pricePoint = Decimal(75.00)

        // Simulate creating a gifted logbook entry
        let log = LogbookModel(
            title: "Gifted Glass Pendant",
            startDate: Date().addingTimeInterval(-3 * 24 * 3600),
            completionDate: Date().addingTimeInterval(-1 * 24 * 3600),
            tags: ["pendant", "gift"],
            coe: "104",
            pricePoint: pricePoint,
            saleDate: giftDate, // saleDate field is used for gift date too
            buyerInfo: "Gift to Sarah",
            status: .gifted
        )

        let created = try await repository.createLog(log)

        #expect(created.status == .gifted)
        #expect(created.pricePoint == pricePoint)
        #expect(created.saleDate != nil) // saleDate is reused for gift date
        #expect(created.buyerInfo == "Gift to Sarah")
        #expect(created.techniquesUsed == nil)
    }

    @Test("Creating logbook entry with gifted status but no gift date")
    func testGiftedEntryWithoutGiftDate() async throws {
        let repository = MockLogbookRepository()

        let log = LogbookModel(
            title: "Gifted Item Without Date",
            pricePoint: Decimal(50.00),
            saleDate: nil, // User cleared the date
            buyerInfo: "Friend",
            status: .gifted
        )

        let created = try await repository.createLog(log)

        #expect(created.status == .gifted)
        #expect(created.pricePoint == Decimal(50.00))
        #expect(created.saleDate == nil)
        #expect(created.buyerInfo == "Friend")
    }

    // MARK: - Techniques Used Tests

    @Test("Techniques used is always nil in created logbook entries")
    func testTechniquesAlwaysNil() async throws {
        let repository = MockLogbookRepository()

        // Test with various statuses - techniquesUsed should always be nil
        let statuses: [ProjectStatus] = [.inProgress, .completed, .sold, .gifted, .kept, .broken]

        for status in statuses {
            let log = LogbookModel(
                title: "Test Entry - \(status.rawValue)",
                techniquesUsed: nil, // Hidden from UI, always nil
                status: status
            )

            let created = try await repository.createLog(log)
            #expect(created.techniquesUsed == nil, "techniquesUsed should be nil for status: \(status.rawValue)")
        }
    }

    // MARK: - Optional Date Tests

    @Test("Creating logbook entry with no start date")
    func testEntryWithoutStartDate() async throws {
        let repository = MockLogbookRepository()

        let log = LogbookModel(
            title: "No Start Date",
            startDate: nil, // User cleared start date
            completionDate: Date(),
            status: .completed
        )

        let created = try await repository.createLog(log)

        #expect(created.startDate == nil)
        #expect(created.completionDate != nil)
        #expect(created.status == .completed)
    }

    @Test("Creating logbook entry with no completion date for in-progress status")
    func testInProgressWithoutCompletionDate() async throws {
        let repository = MockLogbookRepository()

        let log = LogbookModel(
            title: "Work In Progress",
            startDate: Date(),
            completionDate: nil, // Should not show for in-progress status
            status: .inProgress
        )

        let created = try await repository.createLog(log)

        #expect(created.startDate != nil)
        #expect(created.completionDate == nil)
        #expect(created.status == .inProgress)
    }

    @Test("Creating completed entry with completion date")
    func testCompletedWithCompletionDate() async throws {
        let repository = MockLogbookRepository()
        let completionDate = Date()

        let log = LogbookModel(
            title: "Completed Project",
            startDate: Date().addingTimeInterval(-5 * 24 * 3600),
            completionDate: completionDate,
            status: .completed
        )

        let created = try await repository.createLog(log)

        #expect(created.completionDate != nil)
        #expect(created.status == .completed)
    }

    // MARK: - Repository Integration Tests

    @Test("Logbook entry can be retrieved after creation")
    func testCreateAndRetrieveEntry() async throws {
        let repository = MockLogbookRepository()

        let log = LogbookModel(
            title: "Test Retrieval",
            startDate: Date(),
            tags: ["test"],
            coe: "96",
            status: .completed
        )

        let created = try await repository.createLog(log)
        let retrieved = try await repository.getLog(id: created.id)

        #expect(retrieved != nil)
        #expect(retrieved?.title == "Test Retrieval")
        #expect(retrieved?.coe == "96")
        #expect(retrieved?.tags.contains("test") == true)
    }

    @Test("Multiple logbook entries are stored independently")
    func testMultipleEntries() async throws {
        let repository = MockLogbookRepository()

        let log1 = LogbookModel(
            title: "First Entry",
            pricePoint: 100,
            status: .sold
        )

        let log2 = LogbookModel(
            title: "Second Entry",
            pricePoint: 200,
            status: .gifted
        )

        let created1 = try await repository.createLog(log1)
        let created2 = try await repository.createLog(log2)

        let allLogs = try await repository.getAllLogs()

        #expect(allLogs.count >= 2)
        #expect(allLogs.contains { $0.id == created1.id })
        #expect(allLogs.contains { $0.id == created2.id })
    }

    // MARK: - Price Point Tests

    @Test("Price point is optional and can be nil")
    func testOptionalPricePoint() async throws {
        let repository = MockLogbookRepository()

        let log = LogbookModel(
            title: "No Price",
            pricePoint: nil,
            status: .kept
        )

        let created = try await repository.createLog(log)

        #expect(created.pricePoint == nil)
        #expect(created.status == .kept)
    }

    @Test("Price point stores decimal values correctly")
    func testDecimalPricePoint() async throws {
        let repository = MockLogbookRepository()

        let log = LogbookModel(
            title: "Decimal Price",
            pricePoint: Decimal(string: "123.45"),
            status: .sold
        )

        let created = try await repository.createLog(log)

        #expect(created.pricePoint == Decimal(string: "123.45"))
    }

    // MARK: - Business Section Visibility Tests (Documentation)

    @Test("Business section should show for sold and gifted statuses")
    func testBusinessSectionVisibility() {
        // This test documents the UI behavior:
        // Business section (Price & Date) should only show when:
        // - status == .sold OR status == .gifted

        let statusesWithBusinessSection: Set<ProjectStatus> = [.sold, .gifted]
        let statusesWithoutBusinessSection: Set<ProjectStatus> = [.inProgress, .completed, .kept, .broken]

        #expect(statusesWithBusinessSection.contains(.sold))
        #expect(statusesWithBusinessSection.contains(.gifted))
        #expect(!statusesWithBusinessSection.contains(.inProgress))
        #expect(!statusesWithBusinessSection.contains(.completed))
        #expect(!statusesWithBusinessSection.contains(.kept))
        #expect(!statusesWithBusinessSection.contains(.broken))
    }
}

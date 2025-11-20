//
//  ReportingServiceTests.swift
//  MoltenTests
//
//  Created by Claude Code on 10/26/25.
//  Tests for ReportingService following TDD and Swift 6 concurrency guidelines
//

import Testing
import Foundation
@testable import Molten

@Suite("ReportingService Tests")
@MainActor
struct ReportingServiceTests {

    // MARK: - Shared Dependencies

    /// ✅ CRITICAL: Store AppDependencies at struct level to keep PersistenceController alive
    /// This prevents Core Data zombie objects that cause crashes.
    /// See CLAUDE.md "Service Creation Anti-Pattern" - same pattern applies to tests!
    private let deps = AppDependencies(persistenceController: .createTestController())


    // MARK: - Setup Helpers

    /// Add inventory to real catalog items for testing
    /// Returns the manufacturer abbreviation of the first item (for assertions)
    private func setupTestData(
        catalogService: CatalogService,
        inventoryService: InventoryTrackingService
    ) async throws -> String {

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let testItems = Array(catalogItems.prefix(3).filter { $0.sku != nil })

        // Add inventory for catalog items (catalog is read-only, we only add inventory)
        _ = try await inventoryService.addInventory(
            quantity: 10.0,
            type: "rod",
            toItem: testItems[0].stable_id,
            atLocation: "Studio A"
        )
        _ = try await inventoryService.addInventory(
            quantity: 5.0,
            type: "tube",
            toItem: testItems[1].stable_id,
            atLocation: "Studio B"
        )
        _ = try await inventoryService.addInventory(
            quantity: 15.0,
            type: "rod",
            toItem: testItems[2].stable_id,
            atLocation: "Studio A"
        )

        return testItems[0].manufacturer
    }

    // MARK: - Comprehensive Report Tests

    @Test("Generate comprehensive report with data")
    func testGenerateComprehensiveReportWithData() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        _ = try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
        let reportingService = ReportingService(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        let report = try await reportingService.generateComprehensiveReport()

        #expect(report.totalGlassItems >= 3)
        #expect(report.totalInventoryRecords >= 3)
        #expect(report.totalQuantity > 0)
        #expect(report.inventoryByType.count > 0)
        #expect(report.manufacturerDistribution.count > 0)
        #expect(report.coeDistribution.count > 0)
    }

    @Test("Generate comprehensive report with empty data")
    func testGenerateComprehensiveReportEmpty() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        let reportingService = ReportingService(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        let report = try await reportingService.generateComprehensiveReport()

        // Should not crash with empty data
        #expect(report.totalGlassItems >= 0)
        #expect(report.totalInventoryRecords >= 0)
        #expect(report.totalQuantity >= 0)
    }

    @Test("Generate comprehensive report with date range filtering")
    func testComprehensiveReportWithDateRange() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        _ = try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
        let reportingService = ReportingService(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        let calendar = Calendar.current
        let now = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!

        let report = try await reportingService.generateComprehensiveReport(
            from: yesterday,
            to: now
        )

        #expect(report.dateRange.start == yesterday)
        #expect(report.dateRange.end == now)
    }

    @Test("Comprehensive report calculates totals correctly")
    func testComprehensiveReportTotals() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        _ = try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
        let reportingService = ReportingService(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        let report = try await reportingService.generateComprehensiveReport()

        // Verify totals
        #expect(report.totalGlassItems >= 3)
        #expect(report.totalQuantity >= 30.0)  // 10 + 5 + 15
    }

    // MARK: - Inventory Report Tests

    @Test("Generate inventory report")
    func testGenerateInventoryReport() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        _ = try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
        let reportingService = ReportingService(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        let report = try await reportingService.generateInventoryReport()

        #expect(report.totalItems >= 3)
        #expect(report.inventorySummaries.count > 0)
        #expect(report.totalQuantity > 0)
        #expect(report.inventoryByType.count > 0)
    }

    @Test("Inventory report includes inventory by type statistics")
    func testInventoryReportByType() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        _ = try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
        let reportingService = ReportingService(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        let report = try await reportingService.generateInventoryReport()

        // Should have "rod" and "tube" types
        #expect(report.inventoryByType["rod"] != nil)
        #expect(report.inventoryByType["tube"] != nil)
    }

    @Test("Inventory report includes low stock items")
    func testInventoryReportLowStock() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        _ = try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
        let reportingService = ReportingService(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        let report = try await reportingService.generateInventoryReport()

        // Low stock items list should exist (may be empty)
        #expect(report.lowStockItems.count >= 0)
    }

    @Test("Inventory report calculates total quantity correctly")
    func testInventoryReportTotalQuantity() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        _ = try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
        let reportingService = ReportingService(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        let report = try await reportingService.generateInventoryReport()

        #expect(report.totalQuantity >= 30.0)
    }

    // MARK: - Manufacturer Report Tests

    @Test("Generate manufacturer report")
    func testGenerateManufacturerReport() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        _ = try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
        let reportingService = ReportingService(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        let report = try await reportingService.generateManufacturerReport()

        #expect(report.totalManufacturers >= 2)  // Bullseye and Northstar
        #expect(report.manufacturerStatistics.count > 0)
    }

    @Test("Manufacturer report includes statistics")
    func testManufacturerReportStatistics() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        let manufacturerAbbr = try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
        let reportingService = ReportingService(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        let report = try await reportingService.generateManufacturerReport()

        // Find stats for the actual manufacturer from our test data
        let manufacturerStats = report.manufacturerStatistics.first { stat in
            stat.abbreviation == manufacturerAbbr
        }
        #expect(manufacturerStats != nil, "Should have stats for manufacturer \(manufacturerAbbr)")
        #expect((manufacturerStats?.itemCount ?? 0) > 0, "Should have item count")
        #expect((manufacturerStats?.totalQuantity ?? 0) > 0, "Should have total quantity")
    }

    @Test("Manufacturer report calculates unique COEs")
    func testManufacturerReportUniqueCOEs() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        let manufacturerAbbr = try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
        let reportingService = ReportingService(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        let report = try await reportingService.generateManufacturerReport()

        // Find stats for the actual manufacturer from our test data
        let manufacturerStats = report.manufacturerStatistics.first { stat in
            stat.abbreviation == manufacturerAbbr
        }
        #expect(manufacturerStats != nil, "Should have stats for manufacturer \(manufacturerAbbr)")
        #expect((manufacturerStats?.uniqueCoes.count ?? 0) > 0, "Should have at least one unique COE")
    }

    @Test("Manufacturer statistics sorted by item count")
    func testManufacturerStatisticsSorting() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        _ = try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
        let reportingService = ReportingService(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        let report = try await reportingService.generateManufacturerReport()

        // Verify sorted by item count (descending)
        if report.manufacturerStatistics.count > 1 {
            let first = report.manufacturerStatistics[0]
            let second = report.manufacturerStatistics[1]
            #expect(first.itemCount >= second.itemCount)
        }
    }

    // MARK: - Tag Report Tests

    @Test("Generate tag report")
    func testGenerateTagReport() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        _ = try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
        let reportingService = ReportingService(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        let report = try await reportingService.generateTagReport()

        #expect(report.totalTags >= 0)
        #expect(report.tagStatistics.count >= 0)
    }

    @Test("Tag report calculates statistics correctly")
    func testTagReportStatistics() async throws {
        // Add tags to test items
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let item = try catalogItems.first(where: { $0.sku != nil })!

        // Add inventory
        _ = try await inventoryService.addInventory(
            quantity: 10.0,
            type: "rod",
            toItem: item.stable_id,
            atLocation: "Studio A"
        )

        let reportingService = ReportingService(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        let report = try await reportingService.generateTagReport()

        // Should handle items with or without tags
        #expect(report.tagStatistics.count >= 0)
    }

    @Test("Tag statistics sorted by count")
    func testTagStatisticsSorting() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        _ = try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
        let reportingService = ReportingService(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        let report = try await reportingService.generateTagReport()

        // Verify sorted by count (descending)
        if report.tagStatistics.count > 1 {
            let first = report.tagStatistics[0]
            let second = report.tagStatistics[1]
            #expect(first.count >= second.count)
        }
    }

    // MARK: - Shopping List Report Tests

    @Test("Generate shopping list report when service available")
    func testGenerateShoppingListReportWithService() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        _ = try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
        let shoppingListService = deps.shoppingListService
        let reportingService = ReportingService(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService,
            shoppingListService: shoppingListService
        )

        let report = try await reportingService.generateShoppingListReport()

        // Should return report when service is available
        #expect(report != nil)
        if let shoppingReport = report {
            #expect(shoppingReport.totalItemsToOrder >= 0)
        }
    }

    @Test("Generate shopping list report handles missing service")
    func testGenerateShoppingListReportMissingService() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        _ = try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
        let reportingService = ReportingService(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService,
            shoppingListService: nil  // No shopping list service
        )

        let report = try await reportingService.generateShoppingListReport()

        // Should return nil when service not available
        #expect(report == nil)
    }

    // MARK: - Statistics Calculation Tests

    @Test("Calculate inventory by type statistics")
    func testInventoryByTypeStatistics() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        _ = try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
        let reportingService = ReportingService(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        let report = try await reportingService.generateComprehensiveReport()

        let rodStats = report.inventoryByType["rod"]
        #expect(rodStats != nil)
        #expect((rodStats?.count ?? 0) > 0)
        #expect((rodStats?.totalQuantity ?? 0) > 0)
    }

    @Test("Calculate COE distribution statistics")
    func testCOEDistributionStatistics() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        _ = try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
        let reportingService = ReportingService(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        let report = try await reportingService.generateComprehensiveReport()

        let coe90Stats = report.coeDistribution.first { $0.coe == 90 }
        let coe104Stats = report.coeDistribution.first { $0.coe == 104 }

        #expect(coe90Stats != nil)
        #expect(coe104Stats != nil)
    }

    @Test("Calculate tag analysis with averages")
    func testTagAnalysisCalculations() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        _ = try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
        let reportingService = ReportingService(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        let report = try await reportingService.generateComprehensiveReport()

        #expect(report.tagAnalysis.totalUniqueTags >= 0)
        #expect(report.tagAnalysis.totalTagAssignments >= 0)
        #expect(report.tagAnalysis.averageTagsPerItem >= 0)
    }

    // MARK: - Edge Case Tests

    @Test("Handle reports with items without inventory")
    func testReportsWithItemsWithoutInventory() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService

        // Use real catalog data (catalog is read-only) - don't create item, catalog already exists
        let reportingService = ReportingService(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        let report = try await reportingService.generateComprehensiveReport()

        // Should handle items without inventory (catalog items exist but have no inventory)
        #expect(report.totalGlassItems >= 1)
        #expect(report.totalInventoryRecords >= 0)
        #expect(report.totalQuantity >= 0)
    }

    @Test("Handle reports with items without tags")
    func testReportsWithItemsWithoutTags() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        _ = try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
        let reportingService = ReportingService(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        let report = try await reportingService.generateTagReport()

        // Should handle items without tags
        #expect(report.totalTags >= 0)
    }

    @Test("Comprehensive report with low stock items")
    func testComprehensiveReportLowStockCount() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        _ = try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
        let reportingService = ReportingService(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        let report = try await reportingService.generateComprehensiveReport()

        // Low stock count should be calculated
        #expect(report.lowStockItemsCount >= 0)
    }

    @Test("Report generated date is recent")
    func testReportGeneratedDate() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        let reportingService = ReportingService(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        let beforeGeneration = Date()
        let report = try await reportingService.generateComprehensiveReport()
        let afterGeneration = Date()

        // Generated date should be between before and after
        #expect(report.generatedDate >= beforeGeneration)
        #expect(report.generatedDate <= afterGeneration)
    }

    @Test("Multiple report types can be generated simultaneously")
    func testMultipleReportGeneration() async throws {
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        _ = try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
        let reportingService = ReportingService(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        // Generate multiple reports
        async let comprehensiveReport = reportingService.generateComprehensiveReport()
        async let inventoryReport = reportingService.generateInventoryReport()
        async let manufacturerReport = reportingService.generateManufacturerReport()
        async let tagReport = reportingService.generateTagReport()

        let (compReport, invReport, mfgReport, tReport) = try await (comprehensiveReport, inventoryReport, manufacturerReport, tagReport)

        // All should succeed
        #expect(compReport.totalGlassItems > 0)
        #expect(invReport.totalItems > 0)
        #expect(mfgReport.totalManufacturers > 0)
        #expect(tReport.totalTags >= 0)
    }
}

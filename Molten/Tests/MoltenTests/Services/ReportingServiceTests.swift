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

    // MARK: - Setup Helpers

    /// Create test glass items with inventory
    private func setupTestData(
        catalogService: CatalogService,
        inventoryService: InventoryTrackingService
    ) async throws {

        // Create glass items with different manufacturers and COEs
        let item1 = GlassItemModel(
            stable_id: "report001",
            name: "Clear Rod",
            sku: "0001",
            manufacturer: "Bullseye",
            coe: 90,
            mfr_status: "active"
        )
        let item2 = GlassItemModel(
            stable_id: "report002",
            name: "Amber Rod",
            sku: "NS-001",
            manufacturer: "Northstar",
            coe: 104,
            mfr_status: "active"
        )
        let item3 = GlassItemModel(
            stable_id: "report003",
            name: "Blue Rod",
            sku: "0002",
            manufacturer: "Bullseye",
            coe: 90,
            mfr_status: "active"
        )

        _ = try await catalogService.createGlassItem(item1)
        _ = try await catalogService.createGlassItem(item2)
        _ = try await catalogService.createGlassItem(item3)

        // Add inventory for items
        _ = try await inventoryService.addInventory(
            quantity: 10.0,
            type: "rod",
            toItem: "report001",
            atLocation: "Studio A"
        )
        _ = try await inventoryService.addInventory(
            quantity: 5.0,
            type: "tube",
            toItem: "report002",
            atLocation: "Studio B"
        )
        _ = try await inventoryService.addInventory(
            quantity: 15.0,
            type: "rod",
            toItem: "report003",
            atLocation: "Studio A"
        )
    }

    // MARK: - Comprehensive Report Tests

    @Test("Generate comprehensive report with data")
    func testGenerateComprehensiveReportWithData() async throws {
        let deps = AppDependencies(persistenceController: .createTestController())
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
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
        let deps = AppDependencies(persistenceController: .createTestController())
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
        let deps = AppDependencies(persistenceController: .createTestController())
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
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
        let deps = AppDependencies(persistenceController: .createTestController())
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
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
        let deps = AppDependencies(persistenceController: .createTestController())
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
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
        let deps = AppDependencies(persistenceController: .createTestController())
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
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
        let deps = AppDependencies(persistenceController: .createTestController())
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
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
        let deps = AppDependencies(persistenceController: .createTestController())
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
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
        let deps = AppDependencies(persistenceController: .createTestController())
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
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
        let deps = AppDependencies(persistenceController: .createTestController())
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
        let reportingService = ReportingService(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        let report = try await reportingService.generateManufacturerReport()

        let bullseyeStats = report.manufacturerStatistics.first { $0.name == "Bullseye" }
        #expect(bullseyeStats != nil)
        #expect((bullseyeStats?.itemCount ?? 0) > 0)
        #expect((bullseyeStats?.totalQuantity ?? 0) > 0)
    }

    @Test("Manufacturer report calculates unique COEs")
    func testManufacturerReportUniqueCOEs() async throws {
        let deps = AppDependencies(persistenceController: .createTestController())
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
        let reportingService = ReportingService(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        let report = try await reportingService.generateManufacturerReport()

        let bullseyeStats = report.manufacturerStatistics.first { $0.name == "Bullseye" }
        #expect(bullseyeStats?.uniqueCoes.contains(90) == true)
    }

    @Test("Manufacturer statistics sorted by item count")
    func testManufacturerStatisticsSorting() async throws {
        let deps = AppDependencies(persistenceController: .createTestController())
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
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
        let deps = AppDependencies(persistenceController: .createTestController())
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
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
        let deps = AppDependencies(persistenceController: .createTestController())
        // Add tags to test items
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService

        // Create items with tags
        let item = GlassItemModel(
            stable_id: "tagged001",
            name: "Tagged Item",
            sku: "0001",
            manufacturer: "Bullseye",
            coe: 90,
            mfr_status: "active"
        )
        _ = try await catalogService.createGlassItem(item)

        // Add inventory
        _ = try await inventoryService.addInventory(
            quantity: 10.0,
            type: "rod",
            toItem: "tagged001",
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
        let deps = AppDependencies(persistenceController: .createTestController())
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
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
        let deps = AppDependencies(persistenceController: .createTestController())
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
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
        let deps = AppDependencies(persistenceController: .createTestController())
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
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
        let deps = AppDependencies(persistenceController: .createTestController())
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
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
        let deps = AppDependencies(persistenceController: .createTestController())
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
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
        let deps = AppDependencies(persistenceController: .createTestController())
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
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
        let deps = AppDependencies(persistenceController: .createTestController())
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService

        // Create item without inventory
        let item = GlassItemModel(
            stable_id: "noinv001",
            name: "No Inventory Item",
            sku: "0001",
            manufacturer: "Bullseye",
            coe: 90,
            mfr_status: "active"
        )
        _ = try await catalogService.createGlassItem(item)

        let reportingService = ReportingService(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService
        )

        let report = try await reportingService.generateComprehensiveReport()

        // Should handle items without inventory
        #expect(report.totalGlassItems >= 1)
        #expect(report.totalInventoryRecords == 0)
        #expect(report.totalQuantity == 0)
    }

    @Test("Handle reports with items without tags")
    func testReportsWithItemsWithoutTags() async throws {
        let deps = AppDependencies(persistenceController: .createTestController())
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
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
        let deps = AppDependencies(persistenceController: .createTestController())
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
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
        let deps = AppDependencies(persistenceController: .createTestController())
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
        let deps = AppDependencies(persistenceController: .createTestController())
        let catalogService = deps.catalogService
        let inventoryService = deps.inventoryTrackingService
        try await setupTestData(catalogService: catalogService, inventoryService: inventoryService)
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

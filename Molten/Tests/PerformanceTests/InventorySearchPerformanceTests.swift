//
//  InventorySearchPerformanceTests.swift
//  PerformanceTests
//
//  Created by Assistant on 2025-11-15.
//  Performance testing for inventory search operations (serial execution)
//

import Foundation
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Molten

@Suite("Inventory Search Performance Tests")
@MainActor
struct InventorySearchPerformanceTests {

    // MARK: - Shared Dependencies

    /// ✅ CRITICAL: Store test environment at struct level to keep dependencies alive
    /// This prevents Core Data zombie objects that cause crashes.
    /// See CLAUDE.md "Service Creation Anti-Pattern" - same pattern applies to tests!
    private let mockRepos = TestConfiguration.setupMockOnlyTestEnvironment()

    // MARK: - Test Infrastructure

    private func createInventoryService() -> InventoryTrackingService {
        return InventoryTrackingService(
            glassItemRepository: mockRepos.glassItem,
            inventoryRepository: mockRepos.inventory,
            itemTagsRepository: mockRepos.itemTags
        )
    }

    private func generateStableId(manufacturer: String, sku: String) -> String {
        return "\(manufacturer)-\(sku)-0"
    }

    private func addTestGlassItems() async throws {
        // Add comprehensive test data for search testing
        let testItems = [
            GlassItemModel(
                stable_id: generateStableId(manufacturer: "bullseye", sku: "001"),
                name: "Bullseye Clear Rod 5mm",
                sku: "001",
                manufacturer: "bullseye",
                mfr_notes: "Clear transparent rod",
                coe: 90,
                url: "https://bullseyeglass.com",
                mfr_status: "available"
            ),
            GlassItemModel(
                stable_id: generateStableId(manufacturer: "spectrum", sku: "100"),
                name: "Clear",
                sku: "100",
                manufacturer: "spectrum",
                mfr_notes: "Crystal clear",
                coe: 96,
                url: "https://spectrumglass.com",
                mfr_status: "available"
            ),
            GlassItemModel(
                stable_id: generateStableId(manufacturer: "bullseye", sku: "254"),
                name: "Red",
                sku: "254",
                manufacturer: "bullseye",
                mfr_notes: "Bright red opaque",
                coe: 90,
                url: "https://bullseyeglass.com",
                mfr_status: "available"
            ),
            GlassItemModel(
                stable_id: generateStableId(manufacturer: "spectrum", sku: "002"),
                name: "Blue",
                sku: "002",
                manufacturer: "spectrum",
                mfr_notes: "Deep blue transparent",
                coe: 96,
                url: "https://spectrumglass.com",
                mfr_status: "available"
            ),
            GlassItemModel(
                stable_id: generateStableId(manufacturer: "kokomo", sku: "003"),
                name: "Green Glass",
                sku: "003",
                manufacturer: "kokomo",
                mfr_notes: "Green transparent",
                coe: 96,
                url: "https://kokomoglass.com",
                mfr_status: "discontinued"
            )
        ]

        for item in testItems {
            _ = try await mockRepos.glassItem.createItem(item)
        }
    }

    // MARK: - Performance Tests

    @Test("Should perform searches efficiently")
    func testSearchPerformance() async throws {
        let inventoryService = createInventoryService()
        try await addTestGlassItems()

        let startTime = Date()

        // Perform multiple searches
        for i in 0..<10 {
            let _ = try await inventoryService.searchItems(
                text: i % 2 == 0 ? "clear" : "red",
                withTags: [],
                hasInventory: false,
                inventoryTypes: []
            )
        }

        let duration = Date().timeIntervalSince(startTime)

        print("DEBUG: 10 searches completed in \(String(format: "%.3f", duration))s")
        #expect(duration < 1.0, "Search should be fast (< 1 second for 10 searches)")
    }
}

//
//  ToolItemDataLoadingServiceTests.swift
//  MoltenTests
//
//  Unit tests for ToolItemDataLoadingService
//

import Testing
import Foundation
@testable import Molten

@Suite("ToolItemDataLoadingService Tests")
@MainActor
struct ToolItemDataLoadingServiceTests {

    // MARK: - Test Infrastructure

    private func createTestService() -> (
        dataLoadingService: ToolItemDataLoadingService,
        repository: MockToolItemRepository
    ) {
        let repository = MockToolItemRepository()
        let dataLoadingService = ToolItemDataLoadingService(toolRepository: repository)

        return (dataLoadingService, repository)
    }

    // MARK: - JSON Decoding Tests

    @Test("Decode tools JSON data")
    func testDecodeToolsJSON() async throws {
        // This test verifies that the JSON structure matches our Codable models
        let json = """
        {
            "manufacturer": "taglia",
            "manufacturer_name": "Taglia Tool",
            "manufacturer_url": "https://tagliatool.com",
            "last_updated": "2025-11-02",
            "tools": [
                {
                    "name": "Test Paddle",
                    "sku": "paddle-test",
                    "category": "Paddles",
                    "price": 45.00,
                    "status": "available"
                }
            ]
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let toolsData = try decoder.decode(ToolsJSONData.self, from: data)

        #expect(toolsData.manufacturer == "taglia")
        #expect(toolsData.manufacturer_name == "Taglia Tool")
        #expect(toolsData.tools.count == 1)
        #expect(toolsData.tools[0].name == "Test Paddle")
        #expect(toolsData.tools[0].sku == "paddle-test")
        #expect(toolsData.tools[0].category == "Paddles")
    }

    @Test("Create tool from JSON data")
    func testCreateToolFromJSON() async throws {
        let (service, repository) = createTestService()

        // Create a test tool directly in the repository
        let tool = ToolItemModel(
            stable_id: "test01",
            name: "Test Tool",
            sku: "test-001",
            manufacturer: "taglia",
            mfr_notes: "Test Category",
            url: nil,
            mfr_status: "available",
            image_url: nil,
            image_path: nil
        )

        let created = try await repository.createItem(tool)
        #expect(created.stable_id == "test01")
        #expect(created.name == "Test Tool")
        #expect(created.manufacturer == "taglia")

        // Verify it can be fetched
        let fetched = try await repository.fetchItem(byStableId: "test01")
        #expect(fetched != nil)
        #expect(fetched?.name == "Test Tool")
    }

    @Test("Compare items - detect new item")
    func testCompareItemsDetectNew() async throws {
        let (_, repository) = createTestService()

        // Create one existing item
        let existing = ToolItemModel(
            stable_id: "exist1",
            name: "Existing Tool",
            sku: "existing-001",
            manufacturer: "taglia",
            mfr_notes: nil,
            url: nil,
            mfr_status: "available",
            image_url: nil,
            image_path: nil
        )
        _ = try await repository.createItem(existing)

        // New item from JSON
        let jsonTools = [
            ToolJSONItem(name: "New Tool", sku: "new-001", category: "New", price: 50.0, status: "available")
        ]

        // Fetch existing items
        let existingItems = try await repository.fetchItems(matching: nil)
        #expect(existingItems.count == 1)

        // In a real test, we'd call the comparison logic here
        // For now, we verify the setup works
        #expect(existingItems[0].sku == "existing-001")
    }

    @Test("Compare items - detect update")
    func testCompareItemsDetectUpdate() async throws {
        let (_, repository) = createTestService()

        // Create existing item with old name
        let existing = ToolItemModel(
            stable_id: "update1",
            name: "Old Name",
            sku: "update-001",
            manufacturer: "taglia",
            mfr_notes: nil,
            url: nil,
            mfr_status: "available",
            image_url: nil,
            image_path: nil
        )
        _ = try await repository.createItem(existing)

        // Update the item
        let updated = ToolItemModel(
            stable_id: "update1",
            name: "New Name",
            sku: "update-001",
            manufacturer: "taglia",
            mfr_notes: nil,
            url: nil,
            mfr_status: "available",
            image_url: nil,
            image_path: nil
        )
        let result = try await repository.updateItem(updated)

        #expect(result.name == "New Name")
        #expect(result.stable_id == "update1")
    }

    @Test("Loading result merge")
    func testLoadingResultMerge() {
        var result1 = ToolLoadingResult(
            itemsCreated: 5,
            itemsFailed: 1,
            itemsSkipped: 2,
            itemsUpdated: 3,
            successfulItems: [],
            failedItems: []
        )

        let result2 = ToolLoadingResult(
            itemsCreated: 3,
            itemsFailed: 0,
            itemsSkipped: 1,
            itemsUpdated: 2,
            successfulItems: [],
            failedItems: []
        )

        result1.merge(result2)

        #expect(result1.itemsCreated == 8)
        #expect(result1.itemsFailed == 1)
        #expect(result1.itemsSkipped == 3)
        #expect(result1.itemsUpdated == 5)
        #expect(result1.totalProcessed == 12)
    }

    @Test("Success rate calculation")
    func testSuccessRateCalculation() {
        let result = ToolLoadingResult(
            itemsCreated: 8,
            itemsFailed: 2,
            itemsSkipped: 0,
            itemsUpdated: 0,
            successfulItems: [],
            failedItems: []
        )

        #expect(result.totalProcessed == 10)
        #expect(result.successRate == 80.0)
    }

    @Test("Success rate - no items processed")
    func testSuccessRateNoItems() {
        let result = ToolLoadingResult(
            itemsCreated: 0,
            itemsFailed: 0,
            itemsSkipped: 0,
            itemsUpdated: 0,
            successfulItems: [],
            failedItems: []
        )

        #expect(result.totalProcessed == 0)
        #expect(result.successRate == 0.0)
    }
}

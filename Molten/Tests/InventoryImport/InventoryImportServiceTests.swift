//
//  InventoryImportServiceTests.swift
//  MoltenTests
//
//  Tests for InventoryImportService with all four import modes
//

import Testing
import Foundation
import CryptoKit
@testable import Molten

@Suite("Inventory Import Service Tests", .serialized)
@MainActor
struct InventoryImportServiceTests {

    // MARK: - Shared Dependencies

    /// ✅ CRITICAL: Store AppDependencies at struct level to keep PersistenceController alive
    /// This prevents Core Data zombie objects that cause crashes.
    /// See CLAUDE.md "Service Creation Anti-Pattern" - same pattern applies to tests!
    private let deps = AppDependencies(persistenceController: .createTestController())

    /// Service instance using shared dependencies (PersistenceController stays alive)
    private var testService: InventoryImportService {
        InventoryImportService(
            catalogService: deps.catalogService,
            inventoryTrackingService: deps.inventoryTrackingService,
            storageLocationRepository: deps.storageLocationRepository
        )
    }

    // MARK: - Test Setup Helpers

    /// Create a test JSON file with sample inventory data
    func createTestImportFile(items: [ImportItem]) throws -> URL {
        let importData = InventoryImportData(
            version: "1.0",
            generated: Date(),
            items: items
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(importData)

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test_import_\(UUID().uuidString).json")
        try jsonData.write(to: fileURL)

        return fileURL
    }

    /// Create test import items (using stable_ids that match populateTestCatalog)
    func createTestItems() -> [ImportItem] {
        return [
            ImportItem(
                code: generateStableId(manufacturer: "bullseye", sku: "BU-001"),
                name: "Bullseye Clear",
                manufacturer: "Bullseye",
                type: "rod",
                quantity: 10,
                location: "Shelf A"
            ),
            ImportItem(
                code: generateStableId(manufacturer: "spectrum", sku: "SP-96"),
                name: "Spectrum Clear",
                manufacturer: "Spectrum",
                type: "rod",
                quantity: 5,
                location: "Shelf B"
            ),
            ImportItem(
                code: generateStableId(manufacturer: "cim", sku: "CIM-874"),
                name: "CIM Intense Black",
                manufacturer: "CiM",
                type: "stringer",
                quantity: 3,
                location: nil
            )
        ]
    }

    /// Add test glass items to catalog directly to the repository for testing
    /// This ensures the items are available to all services sharing the same repository
    /// Idempotent: only creates items if they don't already exist
    func populateTestCatalog() async throws {
        let glassItemRepo = deps.glassItemRepository

        // Create test glass items that match our import data
        let item1 = GlassItemModel(
            stable_id: generateStableId(manufacturer: "bullseye", sku: "BU-001"),
            name: "Bullseye Clear",
            sku: "BU-001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        // Only create if doesn't already exist (idempotent)
        do {
            _ = try await glassItemRepo.createItem(item1)
        } catch {
            // Ignore duplicate errors - item already exists from previous test
        }

        let item2 = GlassItemModel(
            stable_id: generateStableId(manufacturer: "spectrum", sku: "SP-96"),
            name: "Spectrum Clear",
            sku: "SP-96",
            manufacturer: "spectrum",
            coe: 96,
            mfr_status: "available"
        )
        // Only create if doesn't already exist (idempotent)
        do {
            _ = try await glassItemRepo.createItem(item2)
        } catch {
            // Ignore duplicate errors - item already exists from previous test
        }

        let item3 = GlassItemModel(
            stable_id: generateStableId(manufacturer: "cim", sku: "CIM-874"),
            name: "CIM Intense Black",
            sku: "CIM-874",
            manufacturer: "cim",
            coe: 104,
            mfr_status: "available"
        )
        // Only create if doesn't already exist (idempotent)
        do {
            _ = try await glassItemRepo.createItem(item3)
        } catch {
            // Ignore duplicate errors - item already exists from previous test
        }
    }

    // MARK: - Import Mode Enum Tests

    @Test("Import mode enum has all cases")
    func testImportModeEnum() {
        #expect(InventoryImportMode.allCases.count == 4)
        #expect(InventoryImportMode.allCases.contains(.eraseAndReplace))
        #expect(InventoryImportMode.allCases.contains(.addNewOnly))
        #expect(InventoryImportMode.allCases.contains(.addAndIncrease))
        #expect(InventoryImportMode.allCases.contains(.askPerItem))
    }

    @Test("Import mode has display properties")
    func testImportModeDisplayProperties() {
        let mode = InventoryImportMode.eraseAndReplace
        #expect(!mode.displayName.isEmpty)
        #expect(!mode.description.isEmpty)
        #expect(!mode.icon.isEmpty)
    }

    // MARK: - Preview Tests

    @Test("Preview import shows correct item count")
    func testPreviewImport() async throws {
        try await populateTestCatalog()

        let service = testService
        let items = createTestItems()
        let fileURL = try createTestImportFile(items: items)

        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        let preview = try await service.previewImport(from: fileURL)

        #expect(preview.itemCount == 3)
        #expect(preview.version == "1.0")
        #expect(preview.manufacturerBreakdown.count > 0)
    }

    @Test("Preview import shows manufacturer breakdown")
    func testPreviewManufacturerBreakdown() async throws {
        
        try await populateTestCatalog()

        let service = testService
        let items = createTestItems()
        let fileURL = try createTestImportFile(items: items)

        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        let preview = try await service.previewImport(from: fileURL)

        // Should have breakdown by manufacturer
        let bullseyeCount = preview.manufacturerBreakdown.first { $0.manufacturer == "Bullseye" }?.count
        #expect(bullseyeCount == 1)
    }

    // MARK: - Erase and Replace Mode Tests

    @Test("Erase and replace mode deletes existing inventory")
    func testEraseAndReplaceDeletesExisting() async throws {
        
        try await populateTestCatalog()

        let inventoryRepo = deps.inventoryRepository

        // Add existing inventory
        let bullseyeStableId = generateStableId(manufacturer: "bullseye", sku: "BU-001")
        let existingInventory = InventoryModel(
            id: UUID(),
            item_stable_id: bullseyeStableId,
            type: "rod",
            quantity: 100.0,
            date_added: Date(),
            date_modified: Date()
        )
        _ = try await inventoryRepo.createInventory(existingInventory)

        // Verify existing inventory exists
        let beforeCount = try await inventoryRepo.fetchInventory(matching: nil).count
        #expect(beforeCount == 1)

        // Import with erase mode
        let service = testService
        let items = createTestItems()
        let fileURL = try createTestImportFile(items: items)

        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        let result = try await service.importInventory(from: fileURL, mode: .eraseAndReplace)

        // All items should be imported (old deleted, new added)
        #expect(result.successCount == 3)
        #expect(result.skippedCount == 0)

        // Should have exactly 3 items now (old one deleted)
        let afterInventory = try await inventoryRepo.fetchInventory(matching: nil)
        #expect(afterInventory.count == 3)

        // Old quantity should be gone, replaced with import quantity
        let bullseyeInventory = try await inventoryRepo.fetchInventory(forItem: bullseyeStableId, type: "rod")
        #expect(bullseyeInventory.first?.quantity == 10.0)
    }

    // MARK: - Add New Only Mode Tests

    @Test("Add new only mode skips existing items")
    func testAddNewOnlySkipsExisting() async throws {
        
        try await populateTestCatalog()

        let inventoryRepo = deps.inventoryRepository

        // Add one existing inventory item
        let bullseyeStableId = generateStableId(manufacturer: "bullseye", sku: "BU-001")
        let existingInventory = InventoryModel(
            id: UUID(),
            item_stable_id: bullseyeStableId,
            type: "rod",
            quantity: 100.0,
            date_added: Date(),
            date_modified: Date()
        )
        _ = try await inventoryRepo.createInventory(existingInventory)

        // Import with add new only mode
        let service = testService
        let items = createTestItems()
        let fileURL = try createTestImportFile(items: items)

        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        let result = try await service.importInventory(from: fileURL, mode: .addNewOnly)

        // Should import 2 new items, skip 1 existing
        #expect(result.successCount == 2)
        #expect(result.skippedCount == 1)

        // Existing item quantity should be unchanged
        let bullseyeInventory = try await inventoryRepo.fetchInventory(forItem: bullseyeStableId, type: "rod")
        #expect(bullseyeInventory.first?.quantity == 100.0)

        // New items should be added
        let spectrumStableId = generateStableId(manufacturer: "spectrum", sku: "SP-96")
        let spectrumInventory = try await inventoryRepo.fetchInventory(forItem: spectrumStableId, type: "rod")
        #expect(spectrumInventory.first?.quantity == 5.0)
    }

    @Test("Add new only mode imports all items when none exist")
    func testAddNewOnlyImportsAllWhenEmpty() async throws {
        
        try await populateTestCatalog()

        // No existing inventory

        let service = testService
        let items = createTestItems()
        let fileURL = try createTestImportFile(items: items)

        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        let result = try await service.importInventory(from: fileURL, mode: .addNewOnly)

        // All items should be imported
        #expect(result.successCount == 3)
        #expect(result.skippedCount == 0)
    }

    // MARK: - Add and Increase Mode Tests

    @Test("Add and increase mode increases existing quantities")
    func testAddAndIncreaseModeIncreasesQuantities() async throws {
        
        try await populateTestCatalog()

        let inventoryRepo = deps.inventoryRepository

        // Add existing inventory with quantity 100
        let bullseyeStableId = generateStableId(manufacturer: "bullseye", sku: "BU-001")
        let existingInventory = InventoryModel(
            id: UUID(),
            item_stable_id: bullseyeStableId,
            type: "rod",
            quantity: 100.0,
            date_added: Date(),
            date_modified: Date()
        )
        _ = try await inventoryRepo.createInventory(existingInventory)

        // Import with add and increase mode (import has quantity 10)
        let service = testService
        let items = createTestItems()
        let fileURL = try createTestImportFile(items: items)

        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        let result = try await service.importInventory(from: fileURL, mode: .addAndIncrease)

        // All items should be imported (1 increased, 2 added)
        #expect(result.successCount == 3)
        #expect(result.skippedCount == 0)

        // Existing item should have quantity increased (100 + 10 = 110)
        let bullseyeInventory = try await inventoryRepo.fetchInventory(forItem: bullseyeStableId, type: "rod")
        #expect(bullseyeInventory.first?.quantity == 110.0)

        // New items should be added with import quantity
        let spectrumStableId = generateStableId(manufacturer: "spectrum", sku: "SP-96")
        let spectrumInventory = try await inventoryRepo.fetchInventory(forItem: spectrumStableId, type: "rod")
        #expect(spectrumInventory.first?.quantity == 5.0)
    }

    @Test("Add and increase mode adds new items")
    func testAddAndIncreaseModeAddsNewItems() async throws {
        
        try await populateTestCatalog()

        // No existing inventory

        let service = testService
        let items = createTestItems()
        let fileURL = try createTestImportFile(items: items)

        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        let result = try await service.importInventory(from: fileURL, mode: .addAndIncrease)

        // All items should be imported as new
        #expect(result.successCount == 3)
        #expect(result.skippedCount == 0)
    }

    // MARK: - Interactive Ask Per Item Mode Tests

    @Test("Ask per item mode calls delegate for conflicts")
    func testAskPerItemModeCallsDelegate() async throws {
        
        try await populateTestCatalog()

        let inventoryRepo = deps.inventoryRepository

        // Add existing inventory
        let bullseyeStableId = generateStableId(manufacturer: "bullseye", sku: "BU-001")
        let existingInventory = InventoryModel(
            id: UUID(),
            item_stable_id: bullseyeStableId,
            type: "rod",
            quantity: 100.0,
            date_added: Date(),
            date_modified: Date()
        )
        _ = try await inventoryRepo.createInventory(existingInventory)

        // Create service and set mock delegate
        let service = testService
        let mockDelegate = MockImportDelegate(action: .skip)
        service.delegate = mockDelegate

        let items = createTestItems()
        let fileURL = try createTestImportFile(items: items)

        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        let result = try await service.importInventory(from: fileURL, mode: .askPerItem)

        // Delegate should have been called for the existing item
        #expect(mockDelegate.callCount == 1)

        // Should skip the conflicting item and add the 2 new ones
        #expect(result.successCount == 2)
        #expect(result.skippedCount == 1)
    }

    @Test("Ask per item mode replace action works")
    func testAskPerItemModeReplaceAction() async throws {
        
        try await populateTestCatalog()

        let inventoryRepo = deps.inventoryRepository

        // Add existing inventory
        let bullseyeStableId = generateStableId(manufacturer: "bullseye", sku: "BU-001")
        let existingInventory = InventoryModel(
            id: UUID(),
            item_stable_id: bullseyeStableId,
            type: "rod",
            quantity: 100.0,
            date_added: Date(),
            date_modified: Date()
        )
        _ = try await inventoryRepo.createInventory(existingInventory)

        // Create service with delegate that chooses replace
        let service = testService
        let mockDelegate = MockImportDelegate(action: .replace)
        service.delegate = mockDelegate

        let items = createTestItems()
        let fileURL = try createTestImportFile(items: items)

        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        let result = try await service.importInventory(from: fileURL, mode: .askPerItem)

        // All items should be imported
        #expect(result.successCount == 3)
        #expect(result.skippedCount == 0)

        // Existing item should be replaced with import quantity
        let bullseyeInventory = try await inventoryRepo.fetchInventory(forItem: bullseyeStableId, type: "rod")
        #expect(bullseyeInventory.first?.quantity == 10.0)
    }

    @Test("Ask per item mode increase action works")
    func testAskPerItemModeIncreaseAction() async throws {
        
        try await populateTestCatalog()

        let inventoryRepo = deps.inventoryRepository

        // Add existing inventory
        let bullseyeStableId = generateStableId(manufacturer: "bullseye", sku: "BU-001")
        let existingInventory = InventoryModel(
            id: UUID(),
            item_stable_id: bullseyeStableId,
            type: "rod",
            quantity: 100.0,
            date_added: Date(),
            date_modified: Date()
        )
        _ = try await inventoryRepo.createInventory(existingInventory)

        // Create service with delegate that chooses increase
        let service = testService
        let mockDelegate = MockImportDelegate(action: .increase)
        service.delegate = mockDelegate

        let items = createTestItems()
        let fileURL = try createTestImportFile(items: items)

        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        let result = try await service.importInventory(from: fileURL, mode: .askPerItem)

        // All items should be imported
        #expect(result.successCount == 3)
        #expect(result.skippedCount == 0)

        // Existing item should have increased quantity (100 + 10 = 110)
        let bullseyeInventory = try await inventoryRepo.fetchInventory(forItem: bullseyeStableId, type: "rod")
        #expect(bullseyeInventory.first?.quantity == 110.0)
    }

    // MARK: - Error Handling Tests

    @Test("Import fails with invalid JSON")
    func testImportFailsWithInvalidJSON() async throws {
        

        let service = testService

        // Create invalid JSON file
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("invalid.json")
        try "invalid json".write(to: fileURL, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        await #expect(throws: InventoryImportError.self) {
            try await service.importInventory(from: fileURL, mode: .addNewOnly)
        }
    }

    @Test("Import handles item not found error")
    func testImportHandlesItemNotFound() async throws {
        
        // Don't populate catalog - items won't be found

        let service = testService
        let items = createTestItems()
        let fileURL = try createTestImportFile(items: items)

        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        let result = try await service.importInventory(from: fileURL, mode: .addNewOnly)

        // All items should fail (not found in catalog)
        #expect(result.successCount == 0)
        #expect(result.failedItems.count == 3)
    }

    @Test("populateTestCatalog creates items that can be found by stable_id")
    func testPopulateCatalogWorks() async throws {
        
        try await populateTestCatalog()

        // Try to fetch the items we just created using the shared repository
        let glassItemRepo = deps.glassItemRepository
        let bullseyeId = generateStableId(manufacturer: "bullseye", sku: "BU-001")
        let spectrumId = generateStableId(manufacturer: "spectrum", sku: "SP-96")
        let cimId = generateStableId(manufacturer: "cim", sku: "CIM-874")

        let item1 = try await glassItemRepo.fetchItem(byStableId: bullseyeId)
        let item2 = try await glassItemRepo.fetchItem(byStableId: spectrumId)
        let item3 = try await glassItemRepo.fetchItem(byStableId: cimId)

        #expect(item1 != nil, "Bullseye item should be found")
        #expect(item2 != nil, "Spectrum item should be found")
        #expect(item3 != nil, "CIM item should be found")
    }
}

// MARK: - Mock Delegate

@MainActor
class MockImportDelegate: InventoryImportDelegate {
    let action: ImportItemAction
    var callCount = 0

    init(action: ImportItemAction) {
        self.action = action
    }

    func shouldImportItem(_ item: ImportItem, existing: InventoryModel) async -> ImportItemAction {
        callCount += 1
        return action
    }
}

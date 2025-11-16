//
//  CatalogServiceIntegrationTests.swift
//  RepositoryTests
//
//  Integration tests for CatalogService with actual Core Data persistence
//

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import Foundation
@testable import Molten

@Suite("CatalogService Integration Tests", .serialized)
@MainActor
struct CatalogServiceIntegrationTests {

    // MARK: - Shared Dependencies

    /// ✅ CRITICAL: Store AppDependencies at struct level to keep PersistenceController alive
    /// This prevents Core Data zombie objects that cause crashes.
    /// See CLAUDE.md "Service Creation Anti-Pattern" - same pattern applies to tests!
    private let deps = AppDependencies(persistenceController: .createTestController())

    // MARK: - Test Setup

    private func createTestService() async -> (CatalogService, PersistenceController) {
        let testController = PersistenceController.createTestController()

        let service = deps.catalogService
        return (service, testController)
    }

    // MARK: - Basic CRUD Integration Tests

    @Test("CatalogService can create and retrieve glass items with Core Data")
    func testCreateAndRetrieveGlassItems() async throws {
        let (service, _) = await createTestService()

        // Create test glass item
        let glassItem = GlassItemModel(
            stable_id: "test-bullseye-001",
            name: "Clear Rod",
            sku: "001",
            manufacturer: "Bullseye",
            coe: 90,
            mfr_status: "available"
        )

        // Create via service
        let created = try await service.createGlassItem(glassItem)

        // Retrieve all items
        let items = try await service.getGlassItemsLightweight()

        #expect(items.count == 1)
        #expect(items.first?.name == "Clear Rod")
        #expect(items.first?.manufacturer == "Bullseye")
        #expect(created.glassItem.stable_id == "test-bullseye-001")
    }

    @Test("CatalogService integrates glass items with inventory tracking")
    func testGlassItemWithInventoryIntegration() async throws {
        let (service, _) = await createTestService()
        let inventoryService = deps.inventoryTrackingService

        // Create glass item with initial inventory
        let glassItem = GlassItemModel(
            stable_id: "test-item-001",
            name: "Test Glass",
            sku: "001",
            manufacturer: "TestMfr",
            coe: 96,
            mfr_status: "available"
        )

        let inventory = InventoryModel(
            item_stable_id: "test-item-001",
            type: "rod",
            quantity: 10.0
        )

        // Create item with initial inventory
        let created = try await service.createGlassItem(glassItem, initialInventory: [inventory])

        // Verify inventory was created
        #expect(created.totalQuantity == 10.0)
        #expect(created.inventory.count == 1)
        #expect(created.inventory.first?.type == "rod")
    }

    // MARK: - Update and Delete Tests

    @Test("CatalogService updates persist to Core Data")
    func testUpdatePersistence() async throws {
        let (service, _) = await createTestService()

        // Create initial item
        let original = GlassItemModel(
            stable_id: "update-test-001",
            name: "Original Name",
            sku: "001",
            manufacturer: "Bullseye",
            coe: 90,
            mfr_status: "available"
        )

        try await service.createGlassItem(original)

        // Update item
        let updated = GlassItemModel(
            stable_id: "update-test-001",
            name: "Updated Name",
            sku: "001",
            manufacturer: "Bullseye",
            coe: 90,
            mfr_status: "discontinued"
        )

        let result = try await service.updateGlassItem(
            stableId: "update-test-001",
            updatedGlassItem: updated
        )

        // Verify update persisted
        #expect(result.glassItem.name == "Updated Name")
        #expect(result.glassItem.mfr_status == "discontinued")

        let retrieved = try await service.getGlassItemByNaturalKey("update-test-001")
        #expect(retrieved?.glassItem.name == "Updated Name")
    }

    @Test("CatalogService deletes cascade correctly")
    func testDeleteCascade() async throws {
        // Use single AppDependencies instance for both services
        let service = deps.catalogService
        let inventoryService = deps.inventoryTrackingService

        // Create item with inventory
        let glassItem = GlassItemModel(
            stable_id: "delete-test-001",
            name: "To Delete",
            sku: "001",
            manufacturer: "Bullseye",
            coe: 90,
            mfr_status: "available"
        )

        try await service.createGlassItem(glassItem)

        // Add inventory
        try await inventoryService.addInventory(
            quantity: 5.0,
            type: "rod",
            toItem: "delete-test-001"
        )

        // Delete glass item
        try await service.deleteGlassItem(stableId: "delete-test-001")

        // Verify item deleted
        let retrieved = try await service.getGlassItemByNaturalKey("delete-test-001")
        #expect(retrieved == nil)
    }
}

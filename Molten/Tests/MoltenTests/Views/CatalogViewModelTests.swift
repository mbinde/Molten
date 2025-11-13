//
//  CatalogViewModelTests.swift
//  MoltenTests
//
//  Created by Assistant on 11/11/25.
//  Tests for CatalogViewModel filtering logic
//

import Foundation
import Testing
@testable import Molten

@Suite("CatalogViewModel Tests - Filter Computation")
@MainActor
struct CatalogViewModelTests {

    // MARK: - Test Lifecycle

    init() {
        // Configure for testing with mocks
        RepositoryFactory.configureForTesting()
    }

    // MARK: - Helper Methods

    /// Create test glass item
    func createGlassItem(manufacturer: String, sku: String, name: String, coe: Int32 = 90) -> CompleteInventoryItemModel {
        let stableId = "\(manufacturer)-\(sku)-glass"
        let glassItem = GlassItemModel(
            stable_id: stableId,
            name: name,
            sku: sku,
            manufacturer: manufacturer,
            mfr_notes: nil,
            coe: coe,
            url: nil,
            mfr_status: "available",
            image_url: nil,
            image_path: nil
        )
        let catalogItem = UnifiedCatalogItem(glassItem: glassItem)
        return CompleteInventoryItemModel(
            catalogItem: catalogItem,
            inventory: [],
            tags: [],
            userTags: []
        )
    }

    /// Create test tool item
    func createToolItem(manufacturer: String, sku: String, name: String) -> CompleteInventoryItemModel {
        let stableId = "\(manufacturer)-\(sku)-tool"
        let toolItem = ToolItemModel(
            stable_id: stableId,
            name: name,
            sku: sku,
            manufacturer: manufacturer,
            mfr_notes: nil,
            url: nil,
            mfr_status: "available",
            image_url: nil,
            image_path: nil
        )
        let catalogItem = UnifiedCatalogItem(toolItem: toolItem)
        return CompleteInventoryItemModel(
            catalogItem: catalogItem,
            inventory: [],
            tags: [],
            userTags: []
        )
    }

    /// Create test coating item
    func createCoatingItem(manufacturer: String, sku: String, name: String) -> CompleteInventoryItemModel {
        let stableId = "\(manufacturer)-\(sku)-coating"
        let coatingItem = CoatingItemModel(
            stable_id: stableId,
            name: name,
            sku: sku,
            manufacturer: manufacturer,
            mfr_notes: nil,
            url: nil,
            mfr_status: "available",
            image_url: nil,
            image_path: nil
        )
        let catalogItem = UnifiedCatalogItem(coatingItem: coatingItem)
        return CompleteInventoryItemModel(
            catalogItem: catalogItem,
            inventory: [],
            tags: [],
            userTags: []
        )
    }

    // MARK: - Product Type Filter Tests

    @Test("Product type filter should affect manufacturer filter options")
    func testProductTypeFilterAffectsManufacturerOptions() async throws {
        // Given: Items with different product types
        // - Bullseye makes glass
        // - Ennion makes tools (no glass)
        let items = [
            createGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear Rod"),
            createGlassItem(manufacturer: "bullseye", sku: "002", name: "Red Rod"),
            createToolItem(manufacturer: "ennion", sku: "T01", name: "Glass Cutter"),
            createToolItem(manufacturer: "ennion", sku: "T02", name: "Reamer")
        ]

        let catalogService = RepositoryFactory.createCatalogService()

        let viewModel = CatalogViewModel(
            catalogService: catalogService
        )

        // Simulate loaded items
        viewModel.items = items

        // When: Filtering by product type "glass"
        viewModel.selectedProductTypes = ["glass"]

        // Then: Only manufacturers with glass products should appear
        let manufacturerOptions = viewModel.manufacturerCounts.keys

        #expect(manufacturerOptions.contains("bullseye"), "Bullseye should appear (has glass)")
        #expect(!manufacturerOptions.contains("ennion"), "Ennion should NOT appear (no glass, only tools)")
    }

    @Test("Product type filter should affect COE filter options")
    func testProductTypeFilterAffectsCOEOptions() async throws {
        // Given: Items with different product types and COEs
        // - Glass items have COE 90 and COE 96
        // - Tool items have no COE
        let items = [
            createGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear Rod COE 90", coe: 90),
            createGlassItem(manufacturer: "bullseye", sku: "002", name: "Red Rod COE 96", coe: 96),
            createToolItem(manufacturer: "ennion", sku: "T01", name: "Glass Cutter")
        ]

        let catalogService = RepositoryFactory.createCatalogService()

        let viewModel = CatalogViewModel(
            catalogService: catalogService
        )

        viewModel.items = items

        // When: Filtering by product type "tool"
        viewModel.selectedProductTypes = ["tool"]

        // Then: No COE options should appear (tools don't have COE)
        let coeOptions = viewModel.coeCounts.keys

        #expect(coeOptions.isEmpty, "No COE options should appear for tools")
    }

    @Test("Product type filter should affect tag filter options")
    func testProductTypeFilterAffectsTagOptions() async throws {
        // Given: Items with different product types and tags
        let glassItem = createGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear Rod")
        let glassWithTags = CompleteInventoryItemModel(
            catalogItem: glassItem.catalogItem,
            inventory: [],
            tags: ["transparent", "coe90"],
            userTags: []
        )

        let toolItem = createToolItem(manufacturer: "ennion", sku: "T01", name: "Glass Cutter")
        let toolWithTags = CompleteInventoryItemModel(
            catalogItem: toolItem.catalogItem,
            inventory: [],
            tags: ["cutting", "precision"],
            userTags: []
        )

        let items = [glassWithTags, toolWithTags]

        let catalogService = RepositoryFactory.createCatalogService()

        let viewModel = CatalogViewModel(
            catalogService: catalogService
        )

        viewModel.items = items

        // When: Filtering by product type "glass"
        viewModel.selectedProductTypes = ["glass"]

        // Then: Only glass-related tags should appear
        let tagOptions = viewModel.tagCounts.keys

        #expect(tagOptions.contains("transparent"), "Glass tags should appear")
        #expect(tagOptions.contains("coe90"), "Glass tags should appear")
        #expect(!tagOptions.contains("cutting"), "Tool tags should NOT appear")
        #expect(!tagOptions.contains("precision"), "Tool tags should NOT appear")
    }

    @Test("Multiple product types selected should show union of options")
    func testMultipleProductTypesShowUnion() async throws {
        // Given: Items of multiple types
        let items = [
            createGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear Rod"),
            createToolItem(manufacturer: "ennion", sku: "T01", name: "Glass Cutter"),
            createCoatingItem(manufacturer: "glassalchemist", sku: "C01", name: "Reducer")
        ]

        let catalogService = RepositoryFactory.createCatalogService()

        let viewModel = CatalogViewModel(
            catalogService: catalogService
        )

        viewModel.items = items

        // When: Selecting both "glass" and "tool" types
        viewModel.selectedProductTypes = ["glass", "tool"]

        // Then: Should show manufacturers for both glass and tools, but not coatings
        let manufacturerOptions = viewModel.manufacturerCounts.keys

        #expect(manufacturerOptions.contains("bullseye"), "Glass manufacturer should appear")
        #expect(manufacturerOptions.contains("ennion"), "Tool manufacturer should appear")
        #expect(!manufacturerOptions.contains("glassalchemist"), "Coating manufacturer should NOT appear")
    }

    @Test("Clearing product type filter should show all options")
    func testClearingProductTypeFilterShowsAll() async throws {
        // Given: Items of different types
        let items = [
            createGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear Rod"),
            createToolItem(manufacturer: "ennion", sku: "T01", name: "Glass Cutter")
        ]

        let catalogService = RepositoryFactory.createCatalogService()

        let viewModel = CatalogViewModel(
            catalogService: catalogService
        )

        viewModel.items = items

        // When: First filtering by "glass", then clearing
        viewModel.selectedProductTypes = ["glass"]
        let filteredManufacturers = viewModel.manufacturerCounts.keys

        #expect(!filteredManufacturers.contains("ennion"), "Ennion should not appear when filtered")

        // Clear filter
        viewModel.selectedProductTypes = []
        let allManufacturers = viewModel.manufacturerCounts.keys

        // Then: All manufacturers should appear
        #expect(allManufacturers.contains("bullseye"), "Bullseye should appear")
        #expect(allManufacturers.contains("ennion"), "Ennion should appear when unfiltered")
    }
}

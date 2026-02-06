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

    // Note: AppDependencies.shared automatically detects test environment and uses mocks

    // MARK: - Setup/Teardown

    init() {
        // Clean UserDefaults before each test suite to prevent pollution
        // These filters are loaded from UserDefaults by CatalogViewModel init()
        // Keys must match CatalogViewModel's static key constants
        UserDefaults.standard.removeObject(forKey: "catalog.selectedProductTypes")
        UserDefaults.standard.removeObject(forKey: "catalog.selectedCOEs")
        UserDefaults.standard.removeObject(forKey: "catalog.selectedManufacturers")
        UserDefaults.standard.removeObject(forKey: "catalog.selectedTags")
        UserDefaults.standard.removeObject(forKey: "catalog.searchTitlesOnly")
        UserDefaults.standard.removeObject(forKey: "catalog.sortOption")
        UserDefaults.standard.synchronize()
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
    func createCoatingItem(manufacturer: String, sku: String, name: String, tags: String? = nil) -> CompleteInventoryItemModel {
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
            image_path: nil,
            tags: tags
        )
        let catalogItem = UnifiedCatalogItem(coatingItem: coatingItem)
        // Include inline tags from catalog item
        let parsedTags = catalogItem.inlineTags ?? []
        return CompleteInventoryItemModel(
            catalogItem: catalogItem,
            inventory: [],
            tags: parsedTags,
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

        let viewModel = CatalogViewModel(
            catalogService: AppDependencies.shared.catalogService
        )

        // Simulate loaded items and trigger filter computation
        viewModel.items = items
        viewModel.applyFilters()  // Must call after setting items to compute counts
        viewModel.applyFilters()  // Must call after setting items to compute counts

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

        let viewModel = CatalogViewModel(
            catalogService: AppDependencies.shared.catalogService
        )

        viewModel.items = items
        viewModel.applyFilters()  // Must call after setting items to compute counts

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

        let viewModel = CatalogViewModel(
            catalogService: AppDependencies.shared.catalogService
        )

        viewModel.items = items
        viewModel.applyFilters()  // Must call after setting items to compute counts

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

        let viewModel = CatalogViewModel(
            catalogService: AppDependencies.shared.catalogService
        )

        viewModel.items = items
        viewModel.applyFilters()  // Must call after setting items to compute counts

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

        let viewModel = CatalogViewModel(
            catalogService: AppDependencies.shared.catalogService
        )

        viewModel.items = items
        viewModel.applyFilters()  // Must call after setting items to compute counts

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

    // MARK: - COE Filter with Non-Glass Items Tests

    @Test("COE filter should not filter out coatings")
    func testCOEFilterDoesNotFilterOutCoatings() async throws {
        // Given: Glass items with COE and coating items (no COE)
        let items = [
            createGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear Rod COE 90", coe: 90),
            createGlassItem(manufacturer: "bullseye", sku: "002", name: "Red Rod COE 96", coe: 96),
            createCoatingItem(manufacturer: "glassalchemist", sku: "C01", name: "Gold Luster"),
            createCoatingItem(manufacturer: "glassalchemist", sku: "C02", name: "Silver Luster")
        ]

        let viewModel = CatalogViewModel(
            catalogService: AppDependencies.shared.catalogService
        )

        viewModel.items = items
        viewModel.applyFilters()  // Must call after setting items to compute counts

        // When: Applying COE filter for COE 90
        viewModel.selectedCOEs = [90]
        viewModel.applyFilters()

        // Then: Should include COE 90 glass AND all coatings (coatings pass through COE filter)
        let filteredNames = viewModel.filteredItems.map { $0.catalogItem.name }

        #expect(filteredNames.contains("Clear Rod COE 90"), "COE 90 glass should be included")
        #expect(!filteredNames.contains("Red Rod COE 96"), "COE 96 glass should be excluded")
        #expect(filteredNames.contains("Gold Luster"), "Coatings should pass through COE filter")
        #expect(filteredNames.contains("Silver Luster"), "Coatings should pass through COE filter")
    }

    @Test("COE filter should not filter out tools")
    func testCOEFilterDoesNotFilterOutTools() async throws {
        // Given: Glass items with COE and tool items (no COE)
        let items = [
            createGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear Rod COE 90", coe: 90),
            createToolItem(manufacturer: "ennion", sku: "T01", name: "Glass Cutter"),
            createToolItem(manufacturer: "ennion", sku: "T02", name: "Reamer")
        ]

        let viewModel = CatalogViewModel(
            catalogService: AppDependencies.shared.catalogService
        )

        viewModel.items = items
        viewModel.applyFilters()  // Must call after setting items to compute counts

        // When: Applying COE filter for COE 90
        viewModel.selectedCOEs = [90]
        viewModel.applyFilters()

        // Then: Should include COE 90 glass AND all tools (tools pass through COE filter)
        let filteredNames = viewModel.filteredItems.map { $0.catalogItem.name }

        #expect(filteredNames.contains("Clear Rod COE 90"), "COE 90 glass should be included")
        #expect(filteredNames.contains("Glass Cutter"), "Tools should pass through COE filter")
        #expect(filteredNames.contains("Reamer"), "Tools should pass through COE filter")
    }

    @Test("Combined product type and COE filter works correctly")
    func testCombinedProductTypeAndCOEFilter() async throws {
        // Given: Mixed items
        let items = [
            createGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear Rod COE 90", coe: 90),
            createGlassItem(manufacturer: "bullseye", sku: "002", name: "Red Rod COE 96", coe: 96),
            createCoatingItem(manufacturer: "glassalchemist", sku: "C01", name: "Gold Luster")
        ]

        let viewModel = CatalogViewModel(
            catalogService: AppDependencies.shared.catalogService
        )

        viewModel.items = items
        viewModel.applyFilters()  // Must call after setting items to compute counts

        // When: Filtering by product type "coating" AND COE 90
        viewModel.selectedProductTypes = ["coating"]
        viewModel.selectedCOEs = [90]
        viewModel.applyFilters()

        // Then: Should only show coatings (product type filter applied first)
        let filteredNames = viewModel.filteredItems.map { $0.catalogItem.name }

        #expect(filteredNames.count == 1, "Should only have 1 item")
        #expect(filteredNames.contains("Gold Luster"), "Only coating should remain")
        #expect(!filteredNames.contains("Clear Rod COE 90"), "Glass should be filtered out by product type")
    }

    @Test("Filtering coatings only should show all coatings regardless of COE setting")
    func testCoatingsOnlyFilterIgnoresCOE() async throws {
        // Given: Coatings and glass with different COEs
        let items = [
            createGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear Rod COE 90", coe: 90),
            createCoatingItem(manufacturer: "glassalchemist", sku: "C01", name: "Gold Luster"),
            createCoatingItem(manufacturer: "glassalchemist", sku: "C02", name: "Silver Luster"),
            createCoatingItem(manufacturer: "glassalchemist", sku: "C03", name: "Copper Luster")
        ]

        let viewModel = CatalogViewModel(
            catalogService: AppDependencies.shared.catalogService
        )

        viewModel.items = items
        viewModel.applyFilters()  // Must call after setting items to compute counts

        // When: Filtering by product type "coating" with a COE filter active
        viewModel.selectedProductTypes = ["coating"]
        viewModel.selectedCOEs = [90]  // This shouldn't affect coatings
        viewModel.applyFilters()

        // Then: All 3 coatings should appear
        let filteredItems = viewModel.filteredItems

        #expect(filteredItems.count == 3, "All 3 coatings should appear")
        #expect(filteredItems.allSatisfy { $0.catalogItem.itemType == .coating }, "All items should be coatings")
    }

    // MARK: - Coating Inline Tags Tests

    @Test("Coating inline tags should be parsed from quoted string")
    func testCoatingInlineTagsParsing() async throws {
        // Given: A coating with inline tags in SQLite format
        let coating = createCoatingItem(
            manufacturer: "glassalchemist",
            sku: "C01",
            name: "Gold Luster",
            tags: "\"metallic\", \"opaque\", \"gold\""
        )

        // Then: Tags should be parsed correctly
        #expect(coating.tags.contains("metallic"), "Should contain 'metallic' tag")
        #expect(coating.tags.contains("opaque"), "Should contain 'opaque' tag")
        #expect(coating.tags.contains("gold"), "Should contain 'gold' tag")
        #expect(coating.tags.count == 3, "Should have exactly 3 tags")
    }

    @Test("Coating with no tags should have empty tags array")
    func testCoatingWithNoTags() async throws {
        // Given: A coating without tags
        let coating = createCoatingItem(
            manufacturer: "glassalchemist",
            sku: "C02",
            name: "Clear Reducer"
        )

        // Then: Tags should be empty
        #expect(coating.tags.isEmpty, "Tags should be empty when none provided")
    }

    @Test("Coating tags should be available for tag filtering")
    func testCoatingTagsAvailableForFiltering() async throws {
        // Given: Coatings with different tags
        let items = [
            createCoatingItem(manufacturer: "ga", sku: "C01", name: "Gold Luster", tags: "\"metallic\", \"gold\""),
            createCoatingItem(manufacturer: "ga", sku: "C02", name: "Silver Luster", tags: "\"metallic\", \"silver\""),
            createCoatingItem(manufacturer: "ga", sku: "C03", name: "Matte Black", tags: "\"matte\", \"black\"")
        ]

        let viewModel = CatalogViewModel(
            catalogService: AppDependencies.shared.catalogService
        )

        viewModel.items = items
        viewModel.applyFilters()  // Must call after setting items to compute counts

        // When: Filtering by product type "coating"
        viewModel.selectedProductTypes = ["coating"]
        viewModel.applyFilters()

        // Then: Tag counts should reflect coating tags
        let tagCounts = viewModel.tagCounts

        #expect(tagCounts["metallic"] == 2, "Should have 2 items with 'metallic' tag")
        #expect(tagCounts["gold"] == 1, "Should have 1 item with 'gold' tag")
        #expect(tagCounts["matte"] == 1, "Should have 1 item with 'matte' tag")
    }

    @Test("Coating tag filter should work correctly")
    func testCoatingTagFilterWorks() async throws {
        // Given: Coatings with different tags
        let items = [
            createCoatingItem(manufacturer: "ga", sku: "C01", name: "Gold Luster", tags: "\"metallic\", \"gold\""),
            createCoatingItem(manufacturer: "ga", sku: "C02", name: "Silver Luster", tags: "\"metallic\", \"silver\""),
            createCoatingItem(manufacturer: "ga", sku: "C03", name: "Matte Black", tags: "\"matte\", \"black\"")
        ]

        let viewModel = CatalogViewModel(
            catalogService: AppDependencies.shared.catalogService
        )

        viewModel.items = items
        viewModel.applyFilters()  // Must call after setting items to compute counts

        // When: Filtering by "metallic" tag
        viewModel.selectedTags = ["metallic"]
        viewModel.applyFilters()

        // Then: Should show only metallic coatings
        let filteredNames = viewModel.filteredItems.map { $0.catalogItem.name }

        #expect(filteredNames.count == 2, "Should have 2 metallic coatings")
        #expect(filteredNames.contains("Gold Luster"), "Gold Luster should be included")
        #expect(filteredNames.contains("Silver Luster"), "Silver Luster should be included")
        #expect(!filteredNames.contains("Matte Black"), "Matte Black should not be included")
    }
}

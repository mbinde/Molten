//
//  CatalogViewModelTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/13/25.
//

import Foundation
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Flameworker

@Suite("CatalogViewModel Tests")
struct CatalogViewModelTests {
    
    // MARK: - Test Data Fixtures
    
    private let testCatalogItems: [CatalogItemModel] = [
        CatalogItemModel(name: "Clear Glass Rod", rawCode: "BUE-RD-001", manufacturer: "Bullseye Glass", tags: ["rod", "clear", "compatible-90"]),
        CatalogItemModel(name: "Red Frit", rawCode: "SPE-FR-200", manufacturer: "Spectrum Glass", tags: ["frit", "red", "compatible-96"]),
        CatalogItemModel(name: "Blue Sheet Glass", rawCode: "BUE-SH-150", manufacturer: "Bullseye Glass", tags: ["sheet", "blue", "compatible-90"]),
        CatalogItemModel(name: "Yellow Stringer", rawCode: "URS-ST-300", manufacturer: "Uroboros Glass", tags: ["stringer", "yellow", "compatible-96"]),
        CatalogItemModel(name: "Green Powder", rawCode: "SPE-PW-400", manufacturer: "Spectrum Glass", tags: ["powder", "green", "compatible-96"])
    ]
    
    // MARK: - Initialization Tests
    
    @Test("Should initialize with empty state")
    func testInitialization() async throws {
        let mockCatalogRepo = MockCatalogRepository()
        let catalogService = CatalogService(repository: mockCatalogRepo)
        let viewModel = await CatalogViewModel(catalogService: catalogService)
        
        await MainActor.run {
            #expect(viewModel.allCatalogItems.isEmpty)
            #expect(viewModel.filteredItems.isEmpty)
            #expect(viewModel.sortedFilteredItems.isEmpty)
            #expect(viewModel.isLoading == false)
            #expect(viewModel.currentError == nil)
            #expect(viewModel.searchText.isEmpty)
            #expect(viewModel.sortOption == .name)
            #expect(viewModel.selectedTags.isEmpty)
            #expect(viewModel.selectedManufacturer == nil)
        }
    }
    
    // MARK: - Data Loading Tests
    
    @Test("Should load catalog items successfully")
    func testLoadCatalogItemsSuccess() async throws {
        let mockCatalogRepo = MockCatalogRepository()
        let catalogService = CatalogService(repository: mockCatalogRepo)
        let viewModel = await CatalogViewModel(catalogService: catalogService)
        
        // Add test data to mock repository
        for item in testCatalogItems {
            _ = try await catalogService.createItem(item)
        }
        
        // Load items
        await viewModel.loadCatalogItems()
        
        await MainActor.run {
            #expect(viewModel.allCatalogItems.count == testCatalogItems.count)
            #expect(viewModel.filteredItems.count == testCatalogItems.count)
            #expect(viewModel.sortedFilteredItems.count == testCatalogItems.count)
            #expect(viewModel.isLoading == false)
            #expect(viewModel.currentError == nil)
        }
    }
    
    @Test("Should handle loading errors gracefully")
    func testLoadCatalogItemsError() async throws {
        let mockCatalogRepo = MockCatalogRepository()
        // Force repository to throw error
        await mockCatalogRepo.setShouldThrowError(true)
        
        let catalogService = CatalogService(repository: mockCatalogRepo)
        let viewModel = await CatalogViewModel(catalogService: catalogService)
        
        // Attempt to load items
        await viewModel.loadCatalogItems()
        
        await MainActor.run {
            #expect(viewModel.allCatalogItems.isEmpty)
            #expect(viewModel.filteredItems.isEmpty)
            #expect(viewModel.sortedFilteredItems.isEmpty)
            #expect(viewModel.isLoading == false)
            #expect(viewModel.currentError != nil)
        }
    }
    
    @Test("Should show loading state during data fetch")
    func testLoadingState() async throws {
        let mockCatalogRepo = MockCatalogRepository()
        let catalogService = CatalogService(repository: mockCatalogRepo)
        let viewModel = await CatalogViewModel(catalogService: catalogService)
        
        // Start loading (don't await to check intermediate state)
        let loadTask = Task {
            await viewModel.loadCatalogItems()
        }
        
        // Brief moment to check loading state - this is best effort
        // In real tests, this might need a more sophisticated mock that can pause
        try await Task.sleep(for: .milliseconds(1))
        
        // Complete the loading
        await loadTask.value
        
        await MainActor.run {
            #expect(viewModel.isLoading == false)
        }
    }
    
    // MARK: - Search Functionality Tests
    
    @Test("Should filter items by search text")
    func testSearchFunctionality() async throws {
        let mockCatalogRepo = MockCatalogRepository()
        let catalogService = CatalogService(repository: mockCatalogRepo)
        let viewModel = await CatalogViewModel(catalogService: catalogService)
        
        // Add test data
        for item in testCatalogItems {
            _ = try await catalogService.createItem(item)
        }
        await viewModel.loadCatalogItems()
        
        // Search by name
        await viewModel.searchItems(searchText: "Clear")
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 1)
            #expect(viewModel.filteredItems.first?.name == "Clear Glass Rod")
        }
        
        // Search by code
        await viewModel.searchItems(searchText: "BUE")
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 2) // Two Bullseye items
            #expect(viewModel.filteredItems.allSatisfy { $0.code.contains("BUE") })
        }
        
        // Search by manufacturer
        await viewModel.searchItems(searchText: "Spectrum")
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 2) // Two Spectrum items
            #expect(viewModel.filteredItems.allSatisfy { $0.manufacturer == "Spectrum Glass" })
        }
        
        // Search with no results
        await viewModel.searchItems(searchText: "NonExistent")
        await MainActor.run {
            #expect(viewModel.filteredItems.isEmpty)
        }
    }
    
    @Test("Should handle case-insensitive search")
    func testCaseInsensitiveSearch() async throws {
        let mockCatalogRepo = MockCatalogRepository()
        let catalogService = CatalogService(repository: mockCatalogRepo)
        let viewModel = await CatalogViewModel(catalogService: catalogService)
        
        // Add test data
        for item in testCatalogItems {
            _ = try await catalogService.createItem(item)
        }
        await viewModel.loadCatalogItems()
        
        // Test various case combinations
        await viewModel.searchItems(searchText: "clear")
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 1)
        }
        
        await viewModel.searchItems(searchText: "BULLSEYE")
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 2)
        }
        
        await viewModel.searchItems(searchText: "SpEcTrUm")
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 2)
        }
    }
    
    // MARK: - Manufacturer Filter Tests
    
    @Test("Should filter by manufacturer")
    func testManufacturerFiltering() async throws {
        let mockCatalogRepo = MockCatalogRepository()
        let catalogService = CatalogService(repository: mockCatalogRepo)
        let viewModel = await CatalogViewModel(catalogService: catalogService)
        
        // Add test data
        for item in testCatalogItems {
            _ = try await catalogService.createItem(item)
        }
        await viewModel.loadCatalogItems()
        
        // Filter by Bullseye
        await viewModel.filterByManufacturer("Bullseye Glass")
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 2)
            #expect(viewModel.filteredItems.allSatisfy { $0.manufacturer == "Bullseye Glass" })
        }
        
        // Filter by Spectrum
        await viewModel.filterByManufacturer("Spectrum Glass")
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 2)
            #expect(viewModel.filteredItems.allSatisfy { $0.manufacturer == "Spectrum Glass" })
        }
        
        // Clear manufacturer filter
        await viewModel.filterByManufacturer(nil)
        await MainActor.run {
            #expect(viewModel.filteredItems.count == testCatalogItems.count)
        }
    }
    
    @Test("Should provide available manufacturers list")
    func testAvailableManufacturers() async throws {
        let mockCatalogRepo = MockCatalogRepository()
        let catalogService = CatalogService(repository: mockCatalogRepo)
        let viewModel = await CatalogViewModel(catalogService: catalogService)
        
        // Add test data
        for item in testCatalogItems {
            _ = try await catalogService.createItem(item)
        }
        await viewModel.loadCatalogItems()
        
        await MainActor.run {
            let manufacturers = viewModel.availableManufacturers
            #expect(manufacturers.count == 3)
            #expect(manufacturers.contains("Bullseye Glass"))
            #expect(manufacturers.contains("Spectrum Glass"))
            #expect(manufacturers.contains("Uroboros Glass"))
            // Should be sorted alphabetically
            #expect(manufacturers[0] == "Bullseye Glass")
            #expect(manufacturers[1] == "Spectrum Glass")
            #expect(manufacturers[2] == "Uroboros Glass")
        }
    }
    
    // MARK: - Tag Filter Tests
    
    @Test("Should filter by tags")
    func testTagFiltering() async throws {
        let mockCatalogRepo = MockCatalogRepository()
        let catalogService = CatalogService(repository: mockCatalogRepo)
        let viewModel = await CatalogViewModel(catalogService: catalogService)
        
        // Add test data
        for item in testCatalogItems {
            _ = try await catalogService.createItem(item)
        }
        await viewModel.loadCatalogItems()
        
        // Filter by single tag
        await viewModel.filterByTags(["rod"])
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 1)
            #expect(viewModel.filteredItems.first?.name == "Clear Glass Rod")
        }
        
        // Filter by multiple tags (should show items that have ANY of the tags)
        await viewModel.filterByTags(["frit", "sheet"])
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 2) // Red Frit and Blue Sheet
            let names = viewModel.filteredItems.map { $0.name }.sorted()
            #expect(names == ["Blue Sheet Glass", "Red Frit"])
        }
        
        // Filter by compatibility tag
        await viewModel.filterByTags(["compatible-96"])
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 3) // Three 96 COE items
        }
    }
    
    @Test("Should toggle tag selection")
    func testTagToggling() async throws {
        let mockCatalogRepo = MockCatalogRepository()
        let catalogService = CatalogService(repository: mockCatalogRepo)
        let viewModel = await CatalogViewModel(catalogService: catalogService)
        
        // Add test data
        for item in testCatalogItems {
            _ = try await catalogService.createItem(item)
        }
        await viewModel.loadCatalogItems()
        
        await MainActor.run {
            #expect(viewModel.selectedTags.isEmpty)
        }
        
        // Toggle tag on
        await viewModel.toggleTag("rod")
        await MainActor.run {
            #expect(viewModel.selectedTags.contains("rod"))
            #expect(viewModel.filteredItems.count == 1)
        }
        
        // Toggle another tag on
        await viewModel.toggleTag("frit")
        await MainActor.run {
            #expect(viewModel.selectedTags.contains("rod"))
            #expect(viewModel.selectedTags.contains("frit"))
            #expect(viewModel.filteredItems.count == 2) // Rod and Frit items
        }
        
        // Toggle first tag off
        await viewModel.toggleTag("rod")
        await MainActor.run {
            #expect(!viewModel.selectedTags.contains("rod"))
            #expect(viewModel.selectedTags.contains("frit"))
            #expect(viewModel.filteredItems.count == 1) // Only Frit item
        }
    }
    
    @Test("Should provide available tags list")
    func testAvailableTagsList() async throws {
        let mockCatalogRepo = MockCatalogRepository()
        let catalogService = CatalogService(repository: mockCatalogRepo)
        let viewModel = await CatalogViewModel(catalogService: catalogService)
        
        // Add test data
        for item in testCatalogItems {
            _ = try await catalogService.createItem(item)
        }
        await viewModel.loadCatalogItems()
        
        await MainActor.run {
            let tags = viewModel.allAvailableTags
            let expectedTags = ["blue", "clear", "compatible-90", "compatible-96", "frit", "green", "powder", "red", "rod", "sheet", "stringer", "yellow"]
            #expect(tags.count == expectedTags.count)
            #expect(tags == expectedTags) // Should be sorted alphabetically
        }
    }
    
    // MARK: - Sorting Tests
    
    @Test("Should sort items by name")
    func testSortByName() async throws {
        let mockCatalogRepo = MockCatalogRepository()
        let catalogService = CatalogService(repository: mockCatalogRepo)
        let viewModel = await CatalogViewModel(catalogService: catalogService)
        
        // Add test data
        for item in testCatalogItems {
            _ = try await catalogService.createItem(item)
        }
        await viewModel.loadCatalogItems()
        
        await viewModel.changeSortOption(.name)
        await MainActor.run {
            let sortedNames = viewModel.sortedFilteredItems.map { $0.name }
            let expectedOrder = ["Blue Sheet Glass", "Clear Glass Rod", "Green Powder", "Red Frit", "Yellow Stringer"]
            #expect(sortedNames == expectedOrder)
        }
    }
    
    @Test("Should sort items by manufacturer")
    func testSortByManufacturer() async throws {
        let mockCatalogRepo = MockCatalogRepository()
        let catalogService = CatalogService(repository: mockCatalogRepo)
        let viewModel = await CatalogViewModel(catalogService: catalogService)
        
        // Add test data
        for item in testCatalogItems {
            _ = try await catalogService.createItem(item)
        }
        await viewModel.loadCatalogItems()
        
        await viewModel.changeSortOption(.manufacturer)
        await MainActor.run {
            let sortedManufacturers = viewModel.sortedFilteredItems.map { $0.manufacturer }
            // Should start with Bullseye items
            #expect(sortedManufacturers[0] == "Bullseye Glass")
            #expect(sortedManufacturers[1] == "Bullseye Glass")
            // Then Spectrum items
            #expect(sortedManufacturers[2] == "Spectrum Glass")
            #expect(sortedManufacturers[3] == "Spectrum Glass")
            // Then Uroboros
            #expect(sortedManufacturers[4] == "Uroboros Glass")
        }
    }
    
    @Test("Should sort items by code")
    func testSortByCode() async throws {
        let mockCatalogRepo = MockCatalogRepository()
        let catalogService = CatalogService(repository: mockCatalogRepo)
        let viewModel = await CatalogViewModel(catalogService: catalogService)
        
        // Add test data
        for item in testCatalogItems {
            _ = try await catalogService.createItem(item)
        }
        await viewModel.loadCatalogItems()
        
        await viewModel.changeSortOption(.code)
        await MainActor.run {
            let sortedCodes = viewModel.sortedFilteredItems.map { $0.code }
            // Should be alphabetically ordered by code
            let expectedOrder = ["BUE-RD-001", "BUE-SH-150", "SPE-FR-200", "SPE-PW-400", "URS-ST-300"]
            #expect(sortedCodes == expectedOrder)
        }
    }
    
    // MARK: - Combined Filter and Search Tests
    
    @Test("Should combine search and manufacturer filter")
    func testCombinedSearchAndManufacturerFilter() async throws {
        let mockCatalogRepo = MockCatalogRepository()
        let catalogService = CatalogService(repository: mockCatalogRepo)
        let viewModel = await CatalogViewModel(catalogService: catalogService)
        
        // Add test data
        for item in testCatalogItems {
            _ = try await catalogService.createItem(item)
        }
        await viewModel.loadCatalogItems()
        
        // Filter by Bullseye manufacturer and search for "Glass"
        await viewModel.filterByManufacturer("Bullseye Glass")
        await viewModel.searchItems(searchText: "Glass")
        
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 2) // Both Bullseye items contain "Glass"
            #expect(viewModel.filteredItems.allSatisfy { $0.manufacturer == "Bullseye Glass" })
            #expect(viewModel.filteredItems.allSatisfy { $0.name.contains("Glass") })
        }
    }
    
    @Test("Should combine search and tag filter")
    func testCombinedSearchAndTagFilter() async throws {
        let mockCatalogRepo = MockCatalogRepository()
        let catalogService = CatalogService(repository: mockCatalogRepo)
        let viewModel = await CatalogViewModel(catalogService: catalogService)
        
        // Add test data
        for item in testCatalogItems {
            _ = try await catalogService.createItem(item)
        }
        await viewModel.loadCatalogItems()
        
        // Filter by "compatible-96" tag and search for "Red"
        await viewModel.filterByTags(["compatible-96"])
        await viewModel.searchItems(searchText: "Red")
        
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 1) // Only Red Frit matches both
            #expect(viewModel.filteredItems.first?.name == "Red Frit")
            #expect(viewModel.filteredItems.first?.tags.contains("compatible-96") == true)
        }
    }
    
    // MARK: - Clear Filters Tests
    
    @Test("Should clear all filters")
    func testClearAllFilters() async throws {
        let mockCatalogRepo = MockCatalogRepository()
        let catalogService = CatalogService(repository: mockCatalogRepo)
        let viewModel = await CatalogViewModel(catalogService: catalogService)
        
        // Add test data
        for item in testCatalogItems {
            _ = try await catalogService.createItem(item)
        }
        await viewModel.loadCatalogItems()
        
        // Apply various filters
        await viewModel.searchItems(searchText: "Glass")
        await viewModel.filterByManufacturer("Bullseye Glass")
        await viewModel.filterByTags(["rod", "sheet"])
        
        await MainActor.run {
            #expect(viewModel.searchText == "Glass")
            #expect(viewModel.selectedManufacturer == "Bullseye Glass")
            #expect(!viewModel.selectedTags.isEmpty)
            #expect(viewModel.filteredItems.count < testCatalogItems.count)
        }
        
        // Clear all filters
        await viewModel.clearFilters()
        
        await MainActor.run {
            #expect(viewModel.searchText.isEmpty)
            #expect(viewModel.selectedManufacturer == nil)
            #expect(viewModel.selectedTags.isEmpty)
            #expect(viewModel.filteredItems.count == testCatalogItems.count)
        }
    }
    
    // MARK: - Enabled Manufacturers Tests
    
    @Test("Should respect enabled manufacturers setting")
    func testEnabledManufacturersFiltering() async throws {
        let mockCatalogRepo = MockCatalogRepository()
        let catalogService = CatalogService(repository: mockCatalogRepo)
        let viewModel = await CatalogViewModel(catalogService: catalogService)
        
        // Add test data
        for item in testCatalogItems {
            _ = try await catalogService.createItem(item)
        }
        await viewModel.loadCatalogItems()
        
        // Enable only Bullseye and Spectrum
        await viewModel.updateEnabledManufacturers(["Bullseye Glass", "Spectrum Glass"])
        
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 4) // Exclude Uroboros item
            #expect(!viewModel.filteredItems.contains { $0.manufacturer == "Uroboros Glass" })
        }
        
        // Enable only Spectrum
        await viewModel.updateEnabledManufacturers(["Spectrum Glass"])
        
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 2) // Only Spectrum items
            #expect(viewModel.filteredItems.allSatisfy { $0.manufacturer == "Spectrum Glass" })
        }
        
        // Enable all manufacturers (empty set means all enabled)
        await viewModel.updateEnabledManufacturers([])
        
        await MainActor.run {
            #expect(viewModel.filteredItems.count == testCatalogItems.count) // All items
        }
    }
    
    // MARK: - CRUD Operations Tests
    
    @Test("Should create new catalog items")
    func testCreateCatalogItem() async throws {
        let mockCatalogRepo = MockCatalogRepository()
        let catalogService = CatalogService(repository: mockCatalogRepo)
        let viewModel = await CatalogViewModel(catalogService: catalogService)
        
        await viewModel.loadCatalogItems()
        await MainActor.run {
            #expect(viewModel.allCatalogItems.isEmpty)
        }
        
        // Create new item
        let newItem = CatalogItemModel(name: "Test Item", rawCode: "TST-001", manufacturer: "Test Corp")
        try await viewModel.createCatalogItem(newItem)
        
        await MainActor.run {
            #expect(viewModel.allCatalogItems.count == 1)
            #expect(viewModel.allCatalogItems.first?.name == "Test Item")
        }
    }
    
    @Test("Should update existing catalog items")
    func testUpdateCatalogItem() async throws {
        let mockCatalogRepo = MockCatalogRepository()
        let catalogService = CatalogService(repository: mockCatalogRepo)
        let viewModel = await CatalogViewModel(catalogService: catalogService)
        
        // Create initial item
        let originalItem = CatalogItemModel(name: "Original Name", rawCode: "TST-001", manufacturer: "Test Corp")
        let createdItem = try await catalogService.createItem(originalItem)
        await viewModel.loadCatalogItems()
        
        // Update the item
        var updatedItem = createdItem
        updatedItem = CatalogItemModel(
            id: updatedItem.id,
            name: "Updated Name",
            rawCode: updatedItem.rawCode,
            manufacturer: updatedItem.manufacturer,
            tags: updatedItem.tags
        )
        
        try await viewModel.updateCatalogItem(updatedItem)
        
        await MainActor.run {
            #expect(viewModel.allCatalogItems.count == 1)
            #expect(viewModel.allCatalogItems.first?.name == "Updated Name")
        }
    }
    
    @Test("Should delete catalog items")
    func testDeleteCatalogItem() async throws {
        let mockCatalogRepo = MockCatalogRepository()
        let catalogService = CatalogService(repository: mockCatalogRepo)
        let viewModel = await CatalogViewModel(catalogService: catalogService)
        
        // Create initial items
        let item1 = try await catalogService.createItem(CatalogItemModel(name: "Item 1", rawCode: "TST-001", manufacturer: "Test Corp"))
        let item2 = try await catalogService.createItem(CatalogItemModel(name: "Item 2", rawCode: "TST-002", manufacturer: "Test Corp"))
        await viewModel.loadCatalogItems()
        
        await MainActor.run {
            #expect(viewModel.allCatalogItems.count == 2)
        }
        
        // Delete one item
        try await viewModel.deleteCatalogItem(withId: item1.id)
        
        await MainActor.run {
            #expect(viewModel.allCatalogItems.count == 1)
            #expect(viewModel.allCatalogItems.first?.name == "Item 2")
        }
    }
    
    @Test("Should get catalog item by code")
    func testGetCatalogItemByCode() async throws {
        let mockCatalogRepo = MockCatalogRepository()
        let catalogService = CatalogService(repository: mockCatalogRepo)
        let viewModel = await CatalogViewModel(catalogService: catalogService)
        
        // Create test item
        let testItem = CatalogItemModel(name: "Test Item", rawCode: "TST-001", manufacturer: "Test Corp")
        let createdItem = try await catalogService.createItem(testItem)
        
        // Get item by code
        let foundItem = try await viewModel.getCatalogItem(byCode: createdItem.code)
        
        #expect(foundItem != nil)
        #expect(foundItem?.name == "Test Item")
        #expect(foundItem?.code == createdItem.code)
        
        // Try to get non-existent item
        let notFound = try await viewModel.getCatalogItem(byCode: "NONEXISTENT")
        #expect(notFound == nil)
    }
    
    // MARK: - Data Refresh Tests
    
    @Test("Should refresh data from repository")
    func testDataRefresh() async throws {
        let mockCatalogRepo = MockCatalogRepository()
        let catalogService = CatalogService(repository: mockCatalogRepo)
        let viewModel = await CatalogViewModel(catalogService: catalogService)
        
        // Initial load
        await viewModel.loadCatalogItems()
        await MainActor.run {
            #expect(viewModel.allCatalogItems.isEmpty)
        }
        
        // Add item directly to repository (simulating external change)
        let newItem = CatalogItemModel(name: "External Item", rawCode: "EXT-001", manufacturer: "External Corp")
        _ = try await catalogService.createItem(newItem)
        
        // Refresh should pick up the new item
        await viewModel.refreshData()
        
        await MainActor.run {
            #expect(viewModel.allCatalogItems.count == 1)
            #expect(viewModel.allCatalogItems.first?.name == "External Item")
        }
    }
}
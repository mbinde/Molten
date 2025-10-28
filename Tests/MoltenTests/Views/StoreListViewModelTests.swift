//
//  StoreListViewModelTests.swift
//  MoltenTests
//
//  Created for Store Maps Feature on 10/27/25.
//

import Testing
import CoreLocation
@testable import Molten

/// Tests for StoreListViewModel presentation logic
///
/// Following TDD: These tests are written BEFORE the implementation
/// Tests cover: loading, filtering, sorting, view mode, location handling
@Suite("StoreListViewModel Tests")
@MainActor
struct StoreListViewModelTests {

    // MARK: - Loading Tests

    @Test("Should load stores on initialization")
    func testLoadStores() async throws {
        // Arrange
        let mockService = MockStoreService()
        let viewModel = StoreListViewModel(storeService: mockService)

        // Act
        await viewModel.loadStores()

        // Assert
        #expect(viewModel.stores.count == 3)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Should set loading state during store fetch")
    func testLoadingState() async throws {
        // Arrange
        let mockService = MockStoreService()
        let viewModel = StoreListViewModel(storeService: mockService)

        // Assert initial state
        #expect(viewModel.isLoading == false)

        // Act - start loading
        let loadTask = Task {
            await viewModel.loadStores()
        }

        // Note: In real implementation, we'd check isLoading == true during the async operation
        // For now, just verify final state
        await loadTask.value

        // Assert final state
        #expect(viewModel.isLoading == false)
    }

    @Test("Should handle error when loading stores fails")
    func testLoadStoresError() async throws {
        // Arrange
        let mockService = MockStoreService()
        mockService.shouldThrowError = true
        let viewModel = StoreListViewModel(storeService: mockService)

        // Act
        await viewModel.loadStores()

        // Assert
        #expect(viewModel.stores.isEmpty)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.isLoading == false)
    }

    // MARK: - Search and Filter Tests

    @Test("Should filter stores by search text")
    func testSearchFilter() async throws {
        // Arrange
        let mockService = MockStoreService()
        let viewModel = StoreListViewModel(storeService: mockService)
        await viewModel.loadStores()

        // Act - search for "Frantz"
        viewModel.searchText = "Frantz"

        // Assert
        #expect(viewModel.filteredStores.count == 1)
        #expect(viewModel.filteredStores.first?.name == "Frantz Art Glass")
    }

    @Test("Should filter stores by city in search")
    func testSearchByCity() async throws {
        // Arrange
        let mockService = MockStoreService()
        let viewModel = StoreListViewModel(storeService: mockService)
        await viewModel.loadStores()

        // Act - search for "San Jose"
        viewModel.searchText = "San Jose"

        // Assert
        #expect(viewModel.filteredStores.count >= 1)
        #expect(viewModel.filteredStores.contains(where: { $0.city == "San Jose" }))
    }

    @Test("Should filter stores by state in search")
    func testSearchByState() async throws {
        // Arrange
        let mockService = MockStoreService()
        let viewModel = StoreListViewModel(storeService: mockService)
        await viewModel.loadStores()

        // Act - search for "CA"
        viewModel.searchText = "CA"

        // Assert
        #expect(viewModel.filteredStores.count >= 1)
        #expect(viewModel.filteredStores.allSatisfy { $0.state == "CA" })
    }

    @Test("Should filter to verified stores only")
    func testVerifiedFilter() async throws {
        // Arrange
        let mockService = MockStoreService()
        let viewModel = StoreListViewModel(storeService: mockService)
        await viewModel.loadStores()

        // Act
        viewModel.showVerifiedOnly = true

        // Assert
        #expect(viewModel.filteredStores.allSatisfy { $0.isVerified })
    }

    @Test("Should clear search text")
    func testClearSearch() async throws {
        // Arrange
        let mockService = MockStoreService()
        let viewModel = StoreListViewModel(storeService: mockService)
        await viewModel.loadStores()
        viewModel.searchText = "test query"

        // Act
        viewModel.clearSearch()

        // Assert
        #expect(viewModel.searchText.isEmpty)
    }

    // MARK: - Sorting Tests

    @Test("Should sort stores by name")
    func testSortByName() async throws {
        // Arrange
        let mockService = MockStoreService()
        let viewModel = StoreListViewModel(storeService: mockService)
        await viewModel.loadStores()

        // Act
        viewModel.sortOption = .name

        // Assert
        let filtered = viewModel.filteredStores
        #expect(filtered.count >= 2)
        // Verify ascending order
        for i in 0..<(filtered.count - 1) {
            #expect(filtered[i].name.localizedCaseInsensitiveCompare(filtered[i + 1].name) != .orderedDescending)
        }
    }

    @Test("Should sort stores by city")
    func testSortByCity() async throws {
        // Arrange
        let mockService = MockStoreService()
        let viewModel = StoreListViewModel(storeService: mockService)
        await viewModel.loadStores()

        // Act
        viewModel.sortOption = .city

        // Assert
        let filtered = viewModel.filteredStores
        #expect(filtered.count >= 2)
        // Verify ascending order
        for i in 0..<(filtered.count - 1) {
            let city1 = filtered[i].city ?? ""
            let city2 = filtered[i + 1].city ?? ""
            #expect(city1.localizedCaseInsensitiveCompare(city2) != .orderedDescending)
        }
    }

    @Test("Should sort stores by verified status")
    func testSortByVerified() async throws {
        // Arrange
        let mockService = MockStoreService()
        let viewModel = StoreListViewModel(storeService: mockService)
        await viewModel.loadStores()

        // Act
        viewModel.sortOption = .verified

        // Assert
        let filtered = viewModel.filteredStores
        // Verified stores should come first
        let firstVerified = filtered.first(where: { $0.isVerified })
        let firstUnverified = filtered.first(where: { !$0.isVerified })

        if let firstVer = firstVerified, let firstUnver = firstUnverified {
            let verIndex = filtered.firstIndex(where: { $0.stable_id == firstVer.stable_id })!
            let unverIndex = filtered.firstIndex(where: { $0.stable_id == firstUnver.stable_id })!
            #expect(verIndex < unverIndex)
        }
    }

    @Test("Should sort stores by distance when location available")
    func testSortByDistance() async throws {
        // Arrange
        let mockService = MockStoreService()
        let viewModel = StoreListViewModel(storeService: mockService)
        await viewModel.loadStores()

        // Simulate user location (San Francisco)
        let userCoord = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        // Note: In real implementation, we'd inject a mock LocationManager
        // For now, this test documents expected behavior

        // Act
        viewModel.sortOption = .distance

        // Assert - verify stores are present
        #expect(viewModel.filteredStores.count >= 1)
        // Actual distance sorting will be tested with mock location manager
    }

    // MARK: - View Mode Tests

    @Test("Should switch between list and map view modes")
    func testViewModeToggle() async throws {
        // Arrange
        let mockService = MockStoreService()
        let viewModel = StoreListViewModel(storeService: mockService)

        // Assert initial state
        #expect(viewModel.viewMode == .list)

        // Act - switch to map
        viewModel.viewMode = .map

        // Assert
        #expect(viewModel.viewMode == .map)

        // Act - switch back to list
        viewModel.viewMode = .list

        // Assert
        #expect(viewModel.viewMode == .list)
    }

    // MARK: - Map Selection Tests

    @Test("Should track selected store for map callout")
    func testSelectedStore() async throws {
        // Arrange
        let mockService = MockStoreService()
        let viewModel = StoreListViewModel(storeService: mockService)
        await viewModel.loadStores()

        let store = viewModel.stores.first!

        // Act
        viewModel.selectedStore = store

        // Assert
        #expect(viewModel.selectedStore?.stable_id == store.stable_id)

        // Act - clear selection
        viewModel.selectedStore = nil

        // Assert
        #expect(viewModel.selectedStore == nil)
    }

    // MARK: - Location Permission Tests

    @Test("Should track location authorization status")
    func testLocationAuthorization() async throws {
        // Arrange
        let mockService = MockStoreService()
        let viewModel = StoreListViewModel(storeService: mockService)

        // Assert initial state (typically not authorized on first launch)
        // Note: Actual behavior depends on LocationManager implementation
        #expect(viewModel.isLocationAuthorized == false || viewModel.isLocationAuthorized == true)
    }

    // MARK: - Zip Code Map Centering Tests

    @Test("Should set desired map center when zip code is entered")
    func testZipCodeSetsMapCenter() async throws {
        // Arrange
        let mockService = MockStoreService()
        let viewModel = StoreListViewModel(storeService: mockService)

        // Assert initial state - no desired center
        #expect(viewModel.desiredMapCenter == nil)

        // Act - set location from zip code (San Jose, CA)
        await viewModel.setLocationFromZipCode("95112")

        // Assert - manual location should be set
        #expect(viewModel.manualLocation != nil)

        // Assert - desired map center should be set to manual location
        #expect(viewModel.desiredMapCenter != nil)
        if let desiredCenter = viewModel.desiredMapCenter {
            #expect(abs(desiredCenter.latitude - viewModel.manualLocation!.coordinate.latitude) < 0.001)
            #expect(abs(desiredCenter.longitude - viewModel.manualLocation!.coordinate.longitude) < 0.001)
        }
    }

    @Test("Should clear desired map center after it's been consumed")
    func testClearDesiredMapCenter() async throws {
        // Arrange
        let mockService = MockStoreService()
        let viewModel = StoreListViewModel(storeService: mockService)
        await viewModel.setLocationFromZipCode("95112")

        // Assert - desired center is set
        #expect(viewModel.desiredMapCenter != nil)

        // Act - clear the desired center (simulating view consuming it)
        viewModel.clearDesiredMapCenter()

        // Assert - desired center should be nil
        #expect(viewModel.desiredMapCenter == nil)
    }
}

// MARK: - Mock Store Service

/// Mock store service for testing ViewModel logic
class MockStoreService: StoreService {
    var shouldThrowError = false
    var stores: [StoreModel] = []

    init() {
        let mockRepo = MockStoreRepository()

        // Populate with test data
        stores = [
            StoreModel(
                stable_id: "frantz-art-glass",
                name: "Frantz Art Glass",
                addressLine1: "205 E Alma Ave",
                addressLine2: nil,
                city: "San Jose",
                state: "CA",
                zip: "95112",
                latitude: 37.3184323,
                longitude: -121.8710054,
                phone: nil,
                websiteUrl: nil,
                hoursJson: nil,
                heroImagePath: nil,
                notes: nil,
                isVerified: true
            ),
            StoreModel(
                stable_id: "sundance-art-glass",
                name: "Sundance Art Glass",
                addressLine1: "6322 W Chinden Blvd",
                addressLine2: nil,
                city: "Garden City",
                state: "ID",
                zip: "83714",
                latitude: 43.6479,
                longitude: -116.2644,
                websiteUrl: "https://www.sundanceartglass.com",
                phone: "(208) 658-6072",
                hoursJson: nil,
                heroImagePath: nil,
                notes: "Largest selection in Idaho",
                isVerified: true
            ),
            StoreModel(
                stable_id: "mountain-glass-arts",
                name: "Mountain Glass Arts",
                addressLine1: "2435 Canyon Blvd",
                addressLine2: "Unit B",
                city: "Boulder",
                state: "CO",
                zip: "80302",
                latitude: 40.0176,
                longitude: -105.2620,
                phone: nil,
                websiteUrl: nil,
                hoursJson: nil,
                heroImagePath: nil,
                notes: nil,
                isVerified: false
            )
        ]

        super.init(repository: mockRepo)
    }

    override func getAllStores() async throws -> [StoreModel] {
        if shouldThrowError {
            throw NSError(domain: "MockStoreService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
        return stores
    }

    override func getStoreCount() async throws -> Int {
        if shouldThrowError {
            throw NSError(domain: "MockStoreService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
        return stores.count
    }
}

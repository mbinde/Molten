//
//  StoreServiceTests.swift
//  FlameworkerTests
//
//  Created for Store Feature on 10/26/25.
//  Tests for StoreService business logic using mock repositories
//

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import Foundation
import CoreLocation
@testable import Molten

@Suite("StoreService Unit Tests")
@MainActor
struct StoreServiceTests {

    // MARK: - Helper Methods

    private func createTestService() -> (service: StoreService, repo: MockStoreRepository) {
        let storeRepo = MockStoreRepository()
        let service = StoreService(repository: storeRepo)
        return (service: service, repo: storeRepo)
    }

    private func createTestStore(
        id: String,
        name: String,
        city: String? = nil,
        state: String? = nil,
        latitude: Double = 0.0,
        longitude: Double = 0.0,
        isVerified: Bool = false
    ) -> StoreModel {
        return StoreModel(
            stable_id: id,
            name: name,
            addressLine1: "123 Main St",
            city: city,
            state: state,
            zip: "12345",
            latitude: latitude,
            longitude: longitude,
            websiteUrl: "https://example.com",
            phone: "555-1234",
            notes: "Test store",
            isVerified: isVerified
        )
    }

    // MARK: - Basic CRUD Tests

    @Test("Get all stores returns empty list initially")
    func testGetAllStoresEmpty() async throws {
        let (service, _) = createTestService()

        let stores = try await service.getAllStores()

        #expect(stores.isEmpty)
    }

    @Test("Get all stores returns created stores sorted by name")
    func testGetAllStoresSorted() async throws {
        let (service, repo) = createTestService()

        // Create stores out of order
        let store1 = createTestStore(id: "store-c", name: "Charlie's Glass")
        let store2 = createTestStore(id: "store-a", name: "Alice's Glass")
        let store3 = createTestStore(id: "store-b", name: "Bob's Glass")

        _ = try await repo.createStore(store1)
        _ = try await repo.createStore(store2)
        _ = try await repo.createStore(store3)

        let stores = try await service.getAllStores()

        #expect(stores.count == 3)
        #expect(stores[0].name == "Alice's Glass")
        #expect(stores[1].name == "Bob's Glass")
        #expect(stores[2].name == "Charlie's Glass")
    }

    @Test("Get store by ID returns correct store")
    func testGetStoreById() async throws {
        let (service, repo) = createTestService()

        let testStore = createTestStore(id: "test-store", name: "Test Store")
        _ = try await repo.createStore(testStore)

        let retrieved = try await service.getStore(byId: "test-store")

        #expect(retrieved != nil)
        #expect(retrieved?.name == "Test Store")
        #expect(retrieved?.stable_id == "test-store")
    }

    @Test("Get store by ID returns nil for non-existent store")
    func testGetStoreByIdNotFound() async throws {
        let (service, _) = createTestService()

        let retrieved = try await service.getStore(byId: "non-existent")

        #expect(retrieved == nil)
    }

    @Test("Create store succeeds with valid data")
    func testCreateStoreValid() async throws {
        let (service, repo) = createTestService()

        let newStore = createTestStore(id: "new-store", name: "New Store")
        let created = try await service.createStore(newStore)

        #expect(created.stable_id == "new-store")
        #expect(created.name == "New Store")

        // Verify it was added to repository
        let count = try await repo.getStoreCount()
        #expect(count == 1)
    }

    @Test("Delete store removes it from repository")
    func testDeleteStore() async throws {
        let (service, repo) = createTestService()

        let store = createTestStore(id: "to-delete", name: "Delete Me")
        _ = try await repo.createStore(store)

        try await service.deleteStore(byId: "to-delete")

        let retrieved = try await service.getStore(byId: "to-delete")
        #expect(retrieved == nil)
    }

    // MARK: - Search Tests

    @Test("Search stores by name returns matching stores")
    func testSearchStoresByName() async throws {
        let (service, repo) = createTestService()

        let store1 = createTestStore(id: "glass-1", name: "Frantz Art Glass")
        let store2 = createTestStore(id: "glass-2", name: "Sundance Art Glass")
        let store3 = createTestStore(id: "tools-1", name: "Mountain Tools")

        _ = try await repo.createStore(store1)
        _ = try await repo.createStore(store2)
        _ = try await repo.createStore(store3)

        let results = try await service.searchStores(searchText: "glass")

        #expect(results.count == 2)
        #expect(results.contains { $0.name.contains("Glass") })
    }

    @Test("Search stores with empty text returns no stores")
    func testSearchStoresEmptyText() async throws {
        let (service, repo) = createTestService()

        let store1 = createTestStore(id: "store-1", name: "Store 1")
        let store2 = createTestStore(id: "store-2", name: "Store 2")

        _ = try await repo.createStore(store1)
        _ = try await repo.createStore(store2)

        // Empty search returns empty results (use getAllStores for all stores)
        let results = try await service.searchStores(searchText: "")

        #expect(results.isEmpty)
    }

    // MARK: - Filtering Tests

    @Test("Get stores in city returns only matching stores")
    func testGetStoresByCity() async throws {
        let (service, repo) = createTestService()

        let store1 = createTestStore(id: "seattle-1", name: "Seattle Store", city: "Seattle", state: "WA")
        let store2 = createTestStore(id: "seattle-2", name: "Another Seattle Store", city: "Seattle", state: "WA")
        let store3 = createTestStore(id: "portland-1", name: "Portland Store", city: "Portland", state: "OR")

        _ = try await repo.createStore(store1)
        _ = try await repo.createStore(store2)
        _ = try await repo.createStore(store3)

        let results = try await service.getStores(inCity: "Seattle")

        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.city == "Seattle" })
    }

    @Test("Get stores in state returns only matching stores")
    func testGetStoresByState() async throws {
        let (service, repo) = createTestService()

        let store1 = createTestStore(id: "wa-1", name: "WA Store 1", city: "Seattle", state: "WA")
        let store2 = createTestStore(id: "wa-2", name: "WA Store 2", city: "Tacoma", state: "WA")
        let store3 = createTestStore(id: "or-1", name: "OR Store", city: "Portland", state: "OR")

        _ = try await repo.createStore(store1)
        _ = try await repo.createStore(store2)
        _ = try await repo.createStore(store3)

        let results = try await service.getStores(inState: "WA")

        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.state == "WA" })
    }

    @Test("Get verified stores only returns verified stores")
    func testGetVerifiedStoresOnly() async throws {
        let (service, repo) = createTestService()

        let store1 = createTestStore(id: "verified-1", name: "Verified Store", isVerified: true)
        let store2 = createTestStore(id: "unverified-1", name: "Unverified Store", isVerified: false)
        let store3 = createTestStore(id: "verified-2", name: "Another Verified", isVerified: true)

        _ = try await repo.createStore(store1)
        _ = try await repo.createStore(store2)
        _ = try await repo.createStore(store3)

        let results = try await service.getVerifiedStores()

        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.isVerified })
    }

    @Test("Get stores with location only returns stores with valid coordinates")
    func testGetStoresWithLocationOnly() async throws {
        let (service, repo) = createTestService()

        let store1 = createTestStore(id: "with-location", name: "Has Location", latitude: 47.6062, longitude: -122.3321)
        let store2 = createTestStore(id: "no-location", name: "No Location", latitude: 0.0, longitude: 0.0)

        _ = try await repo.createStore(store1)
        _ = try await repo.createStore(store2)

        let results = try await service.getStoresWithLocation()

        #expect(results.count == 1)
        #expect(results[0].stable_id == "with-location")
    }

    // MARK: - Location-Based Tests

    @Test("Get stores nearby returns stores within radius")
    func testGetStoresNearby() async throws {
        let (service, repo) = createTestService()

        // Seattle coordinates
        let seattleCoord = CLLocationCoordinate2D(latitude: 47.6062, longitude: -122.3321)

        // Store in Seattle (should be included)
        let nearbyStore = createTestStore(
            id: "nearby",
            name: "Nearby Store",
            latitude: 47.6100,
            longitude: -122.3350
        )

        // Store far away (should be excluded with small radius)
        let farStore = createTestStore(
            id: "far",
            name: "Far Store",
            latitude: 40.7128,
            longitude: -74.0060  // New York
        )

        _ = try await repo.createStore(nearbyStore)
        _ = try await repo.createStore(farStore)

        // Search within 10km radius
        let results = try await service.getStores(near: seattleCoord, radiusMeters: 10000)

        #expect(results.count == 1)
        #expect(results[0].stable_id == "nearby")
    }

    @Test("Get stores sorted by distance")
    func testGetStoresSortedByDistance() async throws {
        let (service, repo) = createTestService()

        let seattleCoord = CLLocationCoordinate2D(latitude: 47.6062, longitude: -122.3321)

        let nearStore = createTestStore(
            id: "near",
            name: "Near Store",
            latitude: 47.6100,
            longitude: -122.3350
        )

        let farStore = createTestStore(
            id: "far",
            name: "Far Store",
            latitude: 47.7000,
            longitude: -122.4000
        )

        _ = try await repo.createStore(nearStore)
        _ = try await repo.createStore(farStore)

        let results = try await service.getStoresSortedByDistance(from: seattleCoord)

        #expect(results.count == 2)
        #expect(results[0].store.stable_id == "near")
        #expect(results[1].store.stable_id == "far")
    }

    // MARK: - Discovery Tests

    @Test("Get distinct cities returns unique city names")
    func testGetDistinctCities() async throws {
        let (service, repo) = createTestService()

        let store1 = createTestStore(id: "seattle-1", name: "Seattle 1", city: "Seattle")
        let store2 = createTestStore(id: "seattle-2", name: "Seattle 2", city: "Seattle")
        let store3 = createTestStore(id: "portland-1", name: "Portland 1", city: "Portland")

        _ = try await repo.createStore(store1)
        _ = try await repo.createStore(store2)
        _ = try await repo.createStore(store3)

        let cities = try await service.getDistinctCities()

        #expect(cities.count == 2)
        #expect(cities.contains("Seattle"))
        #expect(cities.contains("Portland"))
    }

    @Test("Get distinct states returns unique state names")
    func testGetDistinctStates() async throws {
        let (service, repo) = createTestService()

        let store1 = createTestStore(id: "wa-1", name: "WA 1", state: "WA")
        let store2 = createTestStore(id: "wa-2", name: "WA 2", state: "WA")
        let store3 = createTestStore(id: "or-1", name: "OR 1", state: "OR")

        _ = try await repo.createStore(store1)
        _ = try await repo.createStore(store2)
        _ = try await repo.createStore(store3)

        let states = try await service.getDistinctStates()

        #expect(states.count == 2)
        #expect(states.contains("WA"))
        #expect(states.contains("OR"))
    }

    @Test("Get cities with prefix for autocomplete")
    func testGetCitiesWithPrefix() async throws {
        let (service, repo) = createTestService()

        let store1 = createTestStore(id: "seattle-1", name: "Store 1", city: "Seattle")
        let store2 = createTestStore(id: "san-fran-1", name: "Store 2", city: "San Francisco")
        let store3 = createTestStore(id: "portland-1", name: "Store 3", city: "Portland")

        _ = try await repo.createStore(store1)
        _ = try await repo.createStore(store2)
        _ = try await repo.createStore(store3)

        let results = try await service.getCities(withPrefix: "S")

        #expect(results.count == 2)
        #expect(results.contains("Seattle"))
        #expect(results.contains("San Francisco"))
    }

    @Test("Get states with prefix for autocomplete")
    func testGetStatesWithPrefix() async throws {
        let (service, repo) = createTestService()

        let store1 = createTestStore(id: "wa-1", name: "Store 1", state: "WA")
        let store2 = createTestStore(id: "wi-1", name: "Store 2", state: "WI")
        let store3 = createTestStore(id: "or-1", name: "Store 3", state: "OR")

        _ = try await repo.createStore(store1)
        _ = try await repo.createStore(store2)
        _ = try await repo.createStore(store3)

        let results = try await service.getStates(withPrefix: "W")

        #expect(results.count == 2)
        #expect(results.contains("WA"))
        #expect(results.contains("WI"))
    }

    // MARK: - Statistics Tests

    @Test("Get store count returns correct value")
    func testGetStoreCount() async throws {
        let (service, repo) = createTestService()

        let store1 = createTestStore(id: "count-1", name: "Store 1")
        let store2 = createTestStore(id: "count-2", name: "Store 2")

        _ = try await repo.createStore(store1)
        _ = try await repo.createStore(store2)

        let count = try await service.getStoreCount()

        #expect(count == 2)
    }

    @Test("Get verified store count returns correct value")
    func testGetVerifiedStoreCount() async throws {
        let (service, repo) = createTestService()

        let store1 = createTestStore(id: "verified-1", name: "Verified 1", isVerified: true)
        let store2 = createTestStore(id: "unverified-1", name: "Unverified 1", isVerified: false)
        let store3 = createTestStore(id: "verified-2", name: "Verified 2", isVerified: true)

        _ = try await repo.createStore(store1)
        _ = try await repo.createStore(store2)
        _ = try await repo.createStore(store3)

        let count = try await service.getVerifiedStoreCount()

        #expect(count == 2)
    }

    @Test("Get store count by state returns breakdown")
    func testGetStoreCountByState() async throws {
        let (service, repo) = createTestService()

        let store1 = createTestStore(id: "wa-1", name: "WA 1", state: "WA")
        let store2 = createTestStore(id: "wa-2", name: "WA 2", state: "WA")
        let store3 = createTestStore(id: "or-1", name: "OR 1", state: "OR")

        _ = try await repo.createStore(store1)
        _ = try await repo.createStore(store2)
        _ = try await repo.createStore(store3)

        let breakdown = try await service.getStoreCountByState()

        #expect(breakdown["WA"] == 2)
        #expect(breakdown["OR"] == 1)
    }

    @Test("Get store count by city returns breakdown")
    func testGetStoreCountByCity() async throws {
        let (service, repo) = createTestService()

        let store1 = createTestStore(id: "seattle-1", name: "Seattle 1", city: "Seattle")
        let store2 = createTestStore(id: "seattle-2", name: "Seattle 2", city: "Seattle")
        let store3 = createTestStore(id: "portland-1", name: "Portland 1", city: "Portland")

        _ = try await repo.createStore(store1)
        _ = try await repo.createStore(store2)
        _ = try await repo.createStore(store3)

        let breakdown = try await service.getStoreCountByCity()

        #expect(breakdown["Seattle"] == 2)
        #expect(breakdown["Portland"] == 1)
    }

    // MARK: - Data Loading Tests

    @Test("Load stores from JSON data succeeds")
    func testLoadStoresFromJSON() async throws {
        let (service, _) = createTestService()

        // Create sample JSON data with all required fields
        let jsonString = """
        {
            "version": "1.0",
            "generated": "2025-10-26T00:00:00Z",
            "store_count": 1,
            "stores": [
                {
                    "stable_id": "test-store",
                    "name": "Test Store",
                    "address_line1": "123 Main St",
                    "city": "Seattle",
                    "state": "WA",
                    "zip": "98101",
                    "latitude": 47.6062,
                    "longitude": -122.3321,
                    "is_verified": true
                }
            ]
        }
        """
        let jsonData = jsonString.data(using: .utf8)!

        let count = try await service.loadStoresFromJSON(jsonData)

        #expect(count == 1)

        let stores = try await service.getAllStores()
        #expect(stores.count == 1)
        #expect(stores[0].name == "Test Store")
    }

    @Test("Export stores to JSON succeeds")
    func testExportStoresToJSON() async throws {
        let (service, repo) = createTestService()

        let store = createTestStore(
            id: "export-test",
            name: "Export Test Store",
            city: "Seattle",
            state: "WA"
        )
        _ = try await repo.createStore(store)

        let jsonData = try await service.exportStoresToJSON()

        #expect(!jsonData.isEmpty)

        // Verify JSON is valid by decoding (WrappedStoresData handles snake_case conversion)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WrappedStoresData.self, from: jsonData)

        #expect(decoded.stores.count == 1)
        #expect(decoded.stores[0].name == "Export Test Store")
    }

    // MARK: - Update Operations Tests

    @Test("Update store succeeds")
    func testUpdateStore() async throws {
        let (service, repo) = createTestService()

        let original = createTestStore(id: "update-test", name: "Original Name")
        _ = try await repo.createStore(original)

        let updated = StoreModel(
            stable_id: "update-test",
            name: "Updated Name",
            addressLine1: "456 New St",
            city: "Portland",
            state: "OR",
            isVerified: true
        )

        let result = try await service.updateStore(updated)

        #expect(result.name == "Updated Name")
        #expect(result.city == "Portland")
        #expect(result.isVerified == true)
    }
}

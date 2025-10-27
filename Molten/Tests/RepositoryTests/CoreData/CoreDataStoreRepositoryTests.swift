//
//  CoreDataStoreRepositoryTests.swift
//  Molten
//
//  Created for Store Feature on 10/26/25.
//
// Target: RepositoryTests

#if canImport(Testing)
import Testing
import Foundation
import CoreData
import CoreLocation
@testable import Molten

/// Tests for CoreDataStoreRepository to verify Core Data operations work correctly
@Suite("CoreDataStoreRepository Tests")
@MainActor
struct CoreDataStoreRepositoryTests {

    let testController: PersistenceController
    let repository: CoreDataStoreRepository

    init() async throws {
        // Create isolated test container
        testController = PersistenceController.createTestController()

        // Create repository with test container
        repository = CoreDataStoreRepository(storePersistentContainer: testController.container)
    }

    // MARK: - Helper Methods

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

    // MARK: - Core Data Entity Structure Tests

    @Test("Store entity has all required attributes")
    func testStoreEntityAttributes() async throws {
        let context = testController.container.viewContext

        guard let entity = NSEntityDescription.entity(forEntityName: "Store", in: context) else {
            Issue.record("Store entity not found")
            return
        }

        // Verify entity has expected attributes
        let attributes = entity.attributesByName.keys
        #expect(attributes.contains("stable_id"))
        #expect(attributes.contains("name"))
        #expect(attributes.contains("addressLine1"))
        #expect(attributes.contains("addressLine2"))
        #expect(attributes.contains("city"))
        #expect(attributes.contains("state"))
        #expect(attributes.contains("zip"))
        #expect(attributes.contains("latitude"))
        #expect(attributes.contains("longitude"))
        #expect(attributes.contains("websiteUrl"))
        #expect(attributes.contains("phone"))
        #expect(attributes.contains("hoursJson"))
        #expect(attributes.contains("heroImagePath"))
        #expect(attributes.contains("notes"))
        #expect(attributes.contains("isVerified"))
    }

    // MARK: - CRUD Operations

    @Test("Create store succeeds")
    func testCreateStore() async throws {
        let store = createTestStore(id: "test-store", name: "Test Store")

        let created = try await repository.createStore(store)

        #expect(created.stable_id == "test-store")
        #expect(created.name == "Test Store")
    }

    @Test("Fetch store by ID returns correct store")
    func testFetchStoreById() async throws {
        let store = createTestStore(id: "fetch-test", name: "Fetch Test Store")
        _ = try await repository.createStore(store)

        let fetched = try await repository.fetchStore(byId: "fetch-test")

        #expect(fetched != nil)
        #expect(fetched?.name == "Fetch Test Store")
    }

    @Test("Fetch store by ID returns nil for non-existent store")
    func testFetchStoreByIdNotFound() async throws {
        let fetched = try await repository.fetchStore(byId: "non-existent")

        #expect(fetched == nil)
    }

    @Test("Fetch all stores returns all created stores")
    func testFetchAllStores() async throws {
        let store1 = createTestStore(id: "store-1", name: "Store 1")
        let store2 = createTestStore(id: "store-2", name: "Store 2")

        _ = try await repository.createStore(store1)
        _ = try await repository.createStore(store2)

        let stores = try await repository.fetchAllStores()

        #expect(stores.count == 2)
    }

    @Test("Update store succeeds")
    func testUpdateStore() async throws {
        let original = createTestStore(id: "update-test", name: "Original Name")
        _ = try await repository.createStore(original)

        let updated = StoreModel(
            stable_id: "update-test",
            name: "Updated Name",
            addressLine1: "456 New St",
            city: "Portland",
            state: "OR",
            isVerified: true
        )

        let result = try await repository.updateStore(updated)

        #expect(result.name == "Updated Name")
        #expect(result.city == "Portland")
        #expect(result.isVerified == true)
    }

    @Test("Delete store removes it")
    func testDeleteStore() async throws {
        let store = createTestStore(id: "delete-test", name: "Delete Me")
        let created = try await repository.createStore(store)

        try await repository.deleteStore(created)

        let fetched = try await repository.fetchStore(byId: "delete-test")
        #expect(fetched == nil)
    }

    @Test("Delete store by ID removes it")
    func testDeleteStoreById() async throws {
        let store = createTestStore(id: "delete-by-id", name: "Delete By ID")
        _ = try await repository.createStore(store)

        try await repository.deleteStore(byId: "delete-by-id")

        let fetched = try await repository.fetchStore(byId: "delete-by-id")
        #expect(fetched == nil)
    }

    @Test("Delete all stores removes everything")
    func testDeleteAllStores() async throws {
        let store1 = createTestStore(id: "store-1", name: "Store 1")
        let store2 = createTestStore(id: "store-2", name: "Store 2")

        _ = try await repository.createStore(store1)
        _ = try await repository.createStore(store2)

        try await repository.deleteAllStores()

        let stores = try await repository.fetchAllStores()
        #expect(stores.isEmpty)
    }

    // MARK: - Search & Query Operations

    @Test("Search stores by name")
    func testSearchStoresByName() async throws {
        let store1 = createTestStore(id: "glass-1", name: "Frantz Art Glass")
        let store2 = createTestStore(id: "glass-2", name: "Sundance Art Glass")
        let store3 = createTestStore(id: "tools-1", name: "Mountain Tools")

        _ = try await repository.createStore(store1)
        _ = try await repository.createStore(store2)
        _ = try await repository.createStore(store3)

        let results = try await repository.searchStores(matching: "glass")

        #expect(results.count == 2)
    }

    @Test("Fetch stores in city")
    func testFetchStoresInCity() async throws {
        let store1 = createTestStore(id: "seattle-1", name: "Seattle Store 1", city: "Seattle")
        let store2 = createTestStore(id: "seattle-2", name: "Seattle Store 2", city: "Seattle")
        let store3 = createTestStore(id: "portland-1", name: "Portland Store", city: "Portland")

        _ = try await repository.createStore(store1)
        _ = try await repository.createStore(store2)
        _ = try await repository.createStore(store3)

        let results = try await repository.fetchStores(inCity: "Seattle")

        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.city == "Seattle" })
    }

    @Test("Fetch stores in state")
    func testFetchStoresInState() async throws {
        let store1 = createTestStore(id: "wa-1", name: "WA Store 1", state: "WA")
        let store2 = createTestStore(id: "wa-2", name: "WA Store 2", state: "WA")
        let store3 = createTestStore(id: "or-1", name: "OR Store", state: "OR")

        _ = try await repository.createStore(store1)
        _ = try await repository.createStore(store2)
        _ = try await repository.createStore(store3)

        let results = try await repository.fetchStores(inState: "WA")

        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.state == "WA" })
    }

    @Test("Fetch verified stores only")
    func testFetchVerifiedStores() async throws {
        let store1 = createTestStore(id: "verified-1", name: "Verified 1", isVerified: true)
        let store2 = createTestStore(id: "unverified-1", name: "Unverified 1", isVerified: false)
        let store3 = createTestStore(id: "verified-2", name: "Verified 2", isVerified: true)

        _ = try await repository.createStore(store1)
        _ = try await repository.createStore(store2)
        _ = try await repository.createStore(store3)

        let results = try await repository.fetchVerifiedStores()

        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.isVerified })
    }

    @Test("Fetch stores with location")
    func testFetchStoresWithLocation() async throws {
        let store1 = createTestStore(id: "with-location", name: "Has Location", latitude: 47.6062, longitude: -122.3321)
        let store2 = createTestStore(id: "no-location", name: "No Location", latitude: 0.0, longitude: 0.0)

        _ = try await repository.createStore(store1)
        _ = try await repository.createStore(store2)

        let results = try await repository.fetchStoresWithLocation()

        #expect(results.count == 1)
        #expect(results[0].stable_id == "with-location")
    }

    @Test("Fetch stores near coordinate within radius")
    func testFetchStoresNearCoordinate() async throws {
        // Seattle coordinates
        let seattleCoord = CLLocationCoordinate2D(latitude: 47.6062, longitude: -122.3321)

        // Store very close to Seattle (within 1km)
        let nearbyStore = createTestStore(
            id: "nearby",
            name: "Nearby Store",
            latitude: 47.6100,
            longitude: -122.3350
        )

        // Store far away
        let farStore = createTestStore(
            id: "far",
            name: "Far Store",
            latitude: 40.7128,
            longitude: -74.0060  // New York
        )

        _ = try await repository.createStore(nearbyStore)
        _ = try await repository.createStore(farStore)

        // Search within 5km radius
        let results = try await repository.fetchStores(near: seattleCoord, radiusMeters: 5000)

        #expect(results.count == 1)
        #expect(results[0].stable_id == "nearby")
    }

    // MARK: - Discovery Operations

    @Test("Get distinct cities")
    func testGetDistinctCities() async throws {
        let store1 = createTestStore(id: "seattle-1", name: "Seattle 1", city: "Seattle")
        let store2 = createTestStore(id: "seattle-2", name: "Seattle 2", city: "Seattle")
        let store3 = createTestStore(id: "portland-1", name: "Portland 1", city: "Portland")

        _ = try await repository.createStore(store1)
        _ = try await repository.createStore(store2)
        _ = try await repository.createStore(store3)

        let cities = try await repository.getDistinctCities()

        #expect(cities.count == 2)
        #expect(cities.contains("Seattle"))
        #expect(cities.contains("Portland"))
    }

    @Test("Get distinct states")
    func testGetDistinctStates() async throws {
        let store1 = createTestStore(id: "wa-1", name: "WA 1", state: "WA")
        let store2 = createTestStore(id: "wa-2", name: "WA 2", state: "WA")
        let store3 = createTestStore(id: "or-1", name: "OR 1", state: "OR")

        _ = try await repository.createStore(store1)
        _ = try await repository.createStore(store2)
        _ = try await repository.createStore(store3)

        let states = try await repository.getDistinctStates()

        #expect(states.count == 2)
        #expect(states.contains("WA"))
        #expect(states.contains("OR"))
    }

    @Test("Get cities with prefix")
    func testGetCitiesWithPrefix() async throws {
        let store1 = createTestStore(id: "seattle-1", name: "Store 1", city: "Seattle")
        let store2 = createTestStore(id: "san-fran-1", name: "Store 2", city: "San Francisco")
        let store3 = createTestStore(id: "portland-1", name: "Store 3", city: "Portland")

        _ = try await repository.createStore(store1)
        _ = try await repository.createStore(store2)
        _ = try await repository.createStore(store3)

        let results = try await repository.getCities(withPrefix: "S")

        #expect(results.count == 2)
        #expect(results.contains("Seattle"))
        #expect(results.contains("San Francisco"))
    }

    @Test("Get states with prefix")
    func testGetStatesWithPrefix() async throws {
        let store1 = createTestStore(id: "wa-1", name: "Store 1", state: "WA")
        let store2 = createTestStore(id: "wi-1", name: "Store 2", state: "WI")
        let store3 = createTestStore(id: "or-1", name: "Store 3", state: "OR")

        _ = try await repository.createStore(store1)
        _ = try await repository.createStore(store2)
        _ = try await repository.createStore(store3)

        let results = try await repository.getStates(withPrefix: "W")

        #expect(results.count == 2)
        #expect(results.contains("WA"))
        #expect(results.contains("WI"))
    }

    @Test("Get store count by state")
    func testGetStoreCountByState() async throws {
        let store1 = createTestStore(id: "wa-1", name: "WA 1", state: "WA")
        let store2 = createTestStore(id: "wa-2", name: "WA 2", state: "WA")
        let store3 = createTestStore(id: "or-1", name: "OR 1", state: "OR")

        _ = try await repository.createStore(store1)
        _ = try await repository.createStore(store2)
        _ = try await repository.createStore(store3)

        let counts = try await repository.getStoreCountByState()

        #expect(counts["WA"] == 2)
        #expect(counts["OR"] == 1)
    }

    @Test("Get store count by city")
    func testGetStoreCountByCity() async throws {
        let store1 = createTestStore(id: "seattle-1", name: "Seattle 1", city: "Seattle")
        let store2 = createTestStore(id: "seattle-2", name: "Seattle 2", city: "Seattle")
        let store3 = createTestStore(id: "portland-1", name: "Portland 1", city: "Portland")

        _ = try await repository.createStore(store1)
        _ = try await repository.createStore(store2)
        _ = try await repository.createStore(store3)

        let counts = try await repository.getStoreCountByCity()

        #expect(counts["Seattle"] == 2)
        #expect(counts["Portland"] == 1)
    }

    // MARK: - JSON Data Loading Tests

    @Test("Load stores from JSON data")
    func testLoadStoresFromJSON() async throws {
        let jsonString = """
        {
            "version": "1.0",
            "store_count": 2,
            "stores": [
                {
                    "stable_id": "store-1",
                    "name": "Test Store 1",
                    "address_line1": "123 Main St",
                    "city": "Seattle",
                    "state": "WA",
                    "zip": "98101",
                    "latitude": 47.6062,
                    "longitude": -122.3321,
                    "website_url": "https://example.com",
                    "phone": "555-1234",
                    "is_verified": true
                },
                {
                    "stable_id": "store-2",
                    "name": "Test Store 2",
                    "city": "Portland",
                    "state": "OR",
                    "latitude": 45.5051,
                    "longitude": -122.6750,
                    "is_verified": false
                }
            ]
        }
        """

        let jsonData = jsonString.data(using: .utf8)!
        let count = try await repository.loadStoresFromJSON(jsonData)

        #expect(count == 2)

        let stores = try await repository.fetchAllStores()
        #expect(stores.count == 2)
    }

    @Test("Export stores to JSON")
    func testExportStoresToJSON() async throws {
        let store = createTestStore(
            id: "export-test",
            name: "Export Test Store",
            city: "Seattle",
            state: "WA"
        )
        _ = try await repository.createStore(store)

        let jsonData = try await repository.exportStoresToJSON()

        #expect(!jsonData.isEmpty)

        // Verify JSON is valid
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(WrappedStoresData.self, from: jsonData)

        #expect(decoded.stores.count == 1)
        #expect(decoded.stores[0].name == "Export Test Store")
    }

    // MARK: - Statistics Operations

    @Test("Get store count")
    func testGetStoreCount() async throws {
        let store1 = createTestStore(id: "count-1", name: "Store 1")
        let store2 = createTestStore(id: "count-2", name: "Store 2")

        _ = try await repository.createStore(store1)
        _ = try await repository.createStore(store2)

        let count = try await repository.getStoreCount()

        #expect(count == 2)
    }

    @Test("Get verified store count")
    func testGetVerifiedStoreCount() async throws {
        let store1 = createTestStore(id: "verified-1", name: "Verified 1", isVerified: true)
        let store2 = createTestStore(id: "unverified-1", name: "Unverified 1", isVerified: false)
        let store3 = createTestStore(id: "verified-2", name: "Verified 2", isVerified: true)

        _ = try await repository.createStore(store1)
        _ = try await repository.createStore(store2)
        _ = try await repository.createStore(store3)

        let count = try await repository.getVerifiedStoreCount()

        #expect(count == 2)
    }

    @Test("Get stores with location count")
    func testGetStoresWithLocationCount() async throws {
        let store1 = createTestStore(id: "with-loc-1", name: "Has Location 1", latitude: 47.6062, longitude: -122.3321)
        let store2 = createTestStore(id: "no-loc-1", name: "No Location 1", latitude: 0.0, longitude: 0.0)
        let store3 = createTestStore(id: "with-loc-2", name: "Has Location 2", latitude: 45.5051, longitude: -122.6750)

        _ = try await repository.createStore(store1)
        _ = try await repository.createStore(store2)
        _ = try await repository.createStore(store3)

        let count = try await repository.getStoresWithLocationCount()

        #expect(count == 2)
    }

    @Test("Store exists check returns true for existing store")
    func testStoreExistsTrue() async throws {
        let store = createTestStore(id: "exists-test", name: "Exists Test")
        _ = try await repository.createStore(store)

        let exists = try await repository.storeExists(withId: "exists-test")

        #expect(exists == true)
    }

    @Test("Store exists check returns false for non-existent store")
    func testStoreExistsFalse() async throws {
        let exists = try await repository.storeExists(withId: "non-existent")

        #expect(exists == false)
    }

    // MARK: - Batch Operations

    @Test("Create multiple stores in batch")
    func testCreateStoresBatch() async throws {
        let stores = [
            createTestStore(id: "batch-1", name: "Batch 1"),
            createTestStore(id: "batch-2", name: "Batch 2"),
            createTestStore(id: "batch-3", name: "Batch 3")
        ]

        let created = try await repository.createStores(stores)

        #expect(created.count == 3)

        let allStores = try await repository.fetchAllStores()
        #expect(allStores.count == 3)
    }

    // MARK: - Data Persistence Tests

    @Test("Created stores persist across context saves")
    func testDataPersistence() async throws {
        let store = createTestStore(id: "persist-test", name: "Persistence Test")
        _ = try await repository.createStore(store)

        // Force save context
        try await testController.container.viewContext.perform {
            try testController.container.viewContext.save()
        }

        // Create new repository instance to force fresh fetch
        let newRepository = CoreDataStoreRepository(storePersistentContainer: testController.container)
        let fetched = try await newRepository.fetchStore(byId: "persist-test")

        #expect(fetched != nil)
        #expect(fetched?.name == "Persistence Test")
    }
}

#endif

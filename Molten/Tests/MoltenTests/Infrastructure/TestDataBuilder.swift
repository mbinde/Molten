//
//  TestDataBuilder.swift
//  MoltenTests
//
//  Created by Assistant on 10/27/25.
//  Fluent API for building test data scenarios for UI and integration tests
//

import Foundation
import CryptoKit
@testable import Molten

/// Fluent builder for creating test data scenarios
///
/// **Usage Example:**
/// ```swift
/// let builder = await TestDataBuilder()
///     .withScenario(.inventoryWithLowStock)
///     .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear")
///     .withInventory(for: "bullseye-001-0", quantity: 2.0, type: "rod")
///     .withTags(for: "bullseye-001-0", tags: ["transparent", "coe90"])
///     .build()
///
/// // Access the built services
/// let catalogService = builder.catalogService
/// ```
@MainActor
class TestDataBuilder {

    // MARK: - Properties

    private var glassItemRepo: MockGlassItemRepository
    private var coatingItemRepo: MockCoatingItemRepository
    private var toolItemRepo: MockToolItemRepository
    private var inventoryRepo: MockInventoryRepository
    private var locationRepo: MockStorageLocationRepository
    private var itemTagsRepo: MockItemTagsRepository
    private var userTagsRepo: MockUserTagsRepository
    private var itemMinimumRepo: MockItemMinimumRepository
    private var shoppingListRepo: MockShoppingListRepository

    // Services (lazily created)
    private var _catalogService: CatalogService?
    private var _inventoryTrackingService: InventoryTrackingService?
    private var _shoppingListService: ShoppingListService?

    // Data to be built
    private var glassItems: [GlassItemModel] = []
    private var inventoryItems: [InventoryModel] = []
    private var tagAssignments: [(itemKey: String, tags: [String])] = []
    private var locations: [StorageLocationModel] = []
    private var itemMinimums: [(stableId: String, minimum: Double)] = []

    // MARK: - Initialization

    init() {
        // Create fresh mock repositories
        self.glassItemRepo = MockGlassItemRepository()
        self.coatingItemRepo = MockCoatingItemRepository()
        self.toolItemRepo = MockToolItemRepository()
        self.inventoryRepo = MockInventoryRepository()
        self.locationRepo = MockStorageLocationRepository()
        self.itemTagsRepo = MockItemTagsRepository()
        self.userTagsRepo = MockUserTagsRepository()
        self.itemMinimumRepo = MockItemMinimumRepository()
        self.shoppingListRepo = MockShoppingListRepository()

        // Configure for reliable testing
        glassItemRepo.simulateLatency = false
        glassItemRepo.shouldRandomlyFail = false
        glassItemRepo.suppressVerboseLogging = true

        // Clear any existing data
        glassItemRepo.clearAllData()
        inventoryRepo.clearAllData()
        locationRepo.clearAllData()
        itemTagsRepo.clearAllData()
        itemMinimumRepo.clearAllData()
    }

    // MARK: - Predefined Scenarios

    enum Scenario {
        case empty
        case basicCatalog
        case inventoryWithLowStock
        case fullCatalogWithInventory
        case shoppingListScenario
        case multiManufacturer
        case discontinued
    }

    /// Load a predefined test scenario
    @discardableResult
    func withScenario(_ scenario: Scenario) -> TestDataBuilder {
        switch scenario {
        case .empty:
            // No data added
            break

        case .basicCatalog:
            // Just a few glass items, no inventory
            glassItems.append(contentsOf: [
                createGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90),
                createGlassItem(manufacturer: "bullseye", sku: "254", name: "Red", coe: 90),
                createGlassItem(manufacturer: "spectrum", sku: "100", name: "Clear", coe: 96)
            ])

        case .inventoryWithLowStock:
            // Items with low stock quantities
            let item1 = createGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            let item2 = createGlassItem(manufacturer: "spectrum", sku: "002", name: "Blue", coe: 96)
            glassItems.append(contentsOf: [item1, item2])

            inventoryItems.append(InventoryModel(
                item_stable_id: item1.stable_id,
                type: "rod",
                quantity: 2.0  // Low stock
            ))
            inventoryItems.append(InventoryModel(
                item_stable_id: item2.stable_id,
                type: "sheet",
                quantity: 1.0  // Low stock
            ))

            itemMinimums.append((item1.stable_id, 5.0))
            itemMinimums.append((item2.stable_id, 5.0))

        case .fullCatalogWithInventory:
            // Use standard test data from TestDataSetup
            glassItems.append(contentsOf: TestDataSetup.createStandardTestGlassItems())
            inventoryItems.append(contentsOf: TestDataSetup.createStandardTestInventory())
            tagAssignments.append(contentsOf: TestDataSetup.createStandardTestTags())

        case .shoppingListScenario:
            // Items with minimums for shopping list testing
            let items = [
                createGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90),
                createGlassItem(manufacturer: "bullseye", sku: "254", name: "Red", coe: 90)
            ]
            glassItems.append(contentsOf: items)

            for item in items {
                itemMinimums.append((item.stable_id, 5.0))
                inventoryItems.append(InventoryModel(
                    item_stable_id: item.stable_id,
                    type: "rod",
                    quantity: 2.0  // Below minimum
                ))
            }

        case .multiManufacturer:
            // Items from multiple manufacturers for filter testing
            glassItems.append(contentsOf: [
                createGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90),
                createGlassItem(manufacturer: "spectrum", sku: "002", name: "Blue", coe: 96),
                createGlassItem(manufacturer: "kokomo", sku: "003", name: "Green", coe: 96),
                createGlassItem(manufacturer: "cim", sku: "874", name: "Adamantium", coe: 104)
            ])

        case .discontinued:
            // Mix of available and discontinued items
            glassItems.append(contentsOf: [
                createGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90, status: "available"),
                createGlassItem(manufacturer: "bullseye", sku: "old", name: "Old Blue", coe: 90, status: "discontinued")
            ])
        }

        return self
    }

    // MARK: - Builder Methods

    /// Add a custom glass item
    @discardableResult
    func withGlassItem(
        manufacturer: String,
        sku: String,
        name: String,
        coe: Int32 = 96,
        status: String = "available",
        notes: String? = nil
    ) -> TestDataBuilder {
        let item = createGlassItem(
            manufacturer: manufacturer,
            sku: sku,
            name: name,
            coe: coe,
            status: status,
            notes: notes
        )
        glassItems.append(item)
        return self
    }

    /// Add inventory for an item (by stable_id)
    @discardableResult
    func withInventory(
        for stableId: String,
        quantity: Double,
        type: String = "rod",
        location: String? = nil
    ) -> TestDataBuilder {
        let inventory = InventoryModel(
            item_stable_id: stableId,
            type: type,
            quantity: quantity,
            location: location
        )
        inventoryItems.append(inventory)
        return self
    }

    /// Add inventory by manufacturer and SKU (convenience method)
    @discardableResult
    func withInventory(
        manufacturer: String,
        sku: String,
        quantity: Double,
        type: String = "rod",
        location: String? = nil
    ) -> TestDataBuilder {
        let stableId = generateStableId(manufacturer: manufacturer, sku: sku)
        return withInventory(for: stableId, quantity: quantity, type: type, location: location)
    }

    /// Add tags for an item
    @discardableResult
    func withTags(for stableId: String, tags: [String]) -> TestDataBuilder {
        tagAssignments.append((stableId, tags))
        return self
    }

    /// Add tags by manufacturer and SKU (convenience method)
    @discardableResult
    func withTags(manufacturer: String, sku: String, tags: [String]) -> TestDataBuilder {
        let stableId = generateStableId(manufacturer: manufacturer, sku: sku)
        return withTags(for: stableId, tags: tags)
    }

    /// Add a location
    /// Note: Currently disabled - LocationModel requires inventory_id
    @discardableResult
    func withLocation(id: String? = nil, name: String, description: String? = nil) -> TestDataBuilder {
        // TODO: Fix LocationModel API mismatch
        // let location = LocationModel(id: id, name: name, description: description)
        // locations.append(location)
        return self
    }

    /// Set minimum quantity for an item
    @discardableResult
    func withMinimum(for stableId: String, minimum: Double) -> TestDataBuilder {
        itemMinimums.append((stableId, minimum))
        return self
    }

    /// Set minimum by manufacturer and SKU (convenience method)
    @discardableResult
    func withMinimum(manufacturer: String, sku: String, minimum: Double) -> TestDataBuilder {
        let stableId = generateStableId(manufacturer: manufacturer, sku: sku)
        return withMinimum(for: stableId, minimum: minimum)
    }

    // MARK: - Build

    /// Build the test data and populate repositories
    @discardableResult
    func build() async throws -> TestDataBuilder {
        // Create glass items
        if !glassItems.isEmpty {
            _ = try await glassItemRepo.createItems(glassItems)
        }

        // Create inventory
        for item in inventoryItems {
            _ = try await inventoryRepo.createInventory(item)
        }

        // Create locations
        // TODO: Fix LocationModel API mismatch
        // for location in locations {
        //     _ = try await locationRepo.createLocation(location)
        // }

        // Assign tags
        for (itemKey, tags) in tagAssignments {
            for tag in tags {
                try await itemTagsRepo.addTag(tag, toItem: itemKey)
            }
        }

        // Set minimums
        for (stableId, minimumQty) in itemMinimums {
            // Default to "rod" type and "Test Store" for minimums
            // This matches the shoppingListScenario which creates rods
            _ = try await itemMinimumRepo.setMinimumQuantity(
                minimumQty,
                forItem: stableId,
                type: "rod",
                store: "Test Store"
            )
        }

        return self
    }

    // MARK: - Service Access

    /// Get or create catalog service
    var catalogService: CatalogService {
        if let service = _catalogService {
            return service
        }

        let service = CatalogService(
            glassItemRepository: glassItemRepo,
            coatingItemRepository: coatingItemRepo,
            toolItemRepository: toolItemRepo,
            inventoryTrackingService: inventoryTrackingService,
            itemMinimumRepository: itemMinimumRepo,
            itemTagsRepository: itemTagsRepo,
            userTagsRepository: userTagsRepo,
            ratingService: AppDependencies.shared.ratingService
        )

        _catalogService = service
        return service
    }

    /// Get or create inventory tracking service
    var inventoryTrackingService: InventoryTrackingService {
        if let service = _inventoryTrackingService {
            return service
        }

        let service = InventoryTrackingService(
            glassItemRepository: glassItemRepo,
            coatingItemRepository: coatingItemRepo,
            toolItemRepository: toolItemRepo,
            inventoryRepository: inventoryRepo,
            itemTagsRepository: itemTagsRepo
        )

        _inventoryTrackingService = service
        return service
    }

    /// Get or create shopping list service
    var shoppingListService: ShoppingListService {
        if let service = _shoppingListService {
            return service
        }

        let service = ShoppingListService(
            itemMinimumRepository: itemMinimumRepo,
            shoppingListRepository: shoppingListRepo,
            inventoryRepository: inventoryRepo,
            glassItemRepository: glassItemRepo,
            coatingItemRepository: coatingItemRepo,
            toolItemRepository: toolItemRepo,
            itemTagsRepository: itemTagsRepo,
            userTagsRepository: userTagsRepo
        )

        _shoppingListService = service
        return service
    }

    // MARK: - Repository Access (for advanced scenarios)

    var repositories: (
        glassItem: MockGlassItemRepository,
        coatingItem: MockCoatingItemRepository,
        toolItem: MockToolItemRepository,
        inventory: MockInventoryRepository,
        location: MockStorageLocationRepository,
        itemTags: MockItemTagsRepository,
        userTags: MockUserTagsRepository,
        itemMinimum: MockItemMinimumRepository,
        shoppingList: MockShoppingListRepository
    ) {
        return (
            glassItemRepo,
            coatingItemRepo,
            toolItemRepo,
            inventoryRepo,
            locationRepo,
            itemTagsRepo,
            userTagsRepo,
            itemMinimumRepo,
            shoppingListRepo
        )
    }

    // MARK: - Helper Methods

    private func createGlassItem(
        manufacturer: String,
        sku: String,
        name: String,
        coe: Int32,
        status: String = "available",
        notes: String? = nil
    ) -> GlassItemModel {
        let stableId = generateStableId(manufacturer: manufacturer, sku: sku)
        return GlassItemModel(
            stable_id: stableId,
            name: name,
            sku: sku,
            manufacturer: manufacturer,
            mfr_notes: notes ?? "Test item",
            coe: coe,
            url: nil,
            mfr_status: status
        )
    }
}

// MARK: - Convenience Extensions for Testing

extension TestDataBuilder {
    /// Quick setup for ViewModel tests
    static func forViewModelTest(scenario: Scenario = .fullCatalogWithInventory) async throws -> TestDataBuilder {
        return try await TestDataBuilder()
            .withScenario(scenario)
            .build()
    }

    /// Quick setup for UI tests (with environment variable check)
    static func forUITest(scenario: Scenario) async throws -> TestDataBuilder {
        // Only use in UI testing context
        guard ProcessInfo.processInfo.arguments.contains("--uitesting") else {
            fatalError("forUITest() should only be called in UI testing context")
        }

        return try await TestDataBuilder()
            .withScenario(scenario)
            .build()
    }
}

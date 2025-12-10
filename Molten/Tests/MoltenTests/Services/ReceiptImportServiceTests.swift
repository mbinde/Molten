//
//  ReceiptImportServiceTests.swift
//  MoltenTests
//
//  Comprehensive tests for ReceiptImportService covering:
//  - PurchaseRecord deduplication (all 3 strategies)
//  - StorageLocation matching (finding unlinked locations, date sorting)
//  - StorageLocation splitting (priced/unpriced separation)
//  - Import operations (add new, match existing, partial match handling)
//

import Testing
import Foundation
@testable import Molten

@Suite("ReceiptImportService Tests", .serialized)
@MainActor
struct ReceiptImportServiceTests {

    // MARK: - Dependencies

    private let mockPurchaseRecordRepository = MockPurchaseRecordRepository()
    private let mockStorageLocationRepository = MockStorageLocationRepository()
    private let mockInventoryRepository = MockInventoryRepository()
    private let mockConsumptionRepository = MockInventoryConsumptionRecordRepository()

    private var service: ReceiptImportService {
        ReceiptImportService(
            purchaseRecordRepository: mockPurchaseRecordRepository,
            storageLocationRepository: mockStorageLocationRepository,
            inventoryRepository: mockInventoryRepository,
            consumptionRepository: mockConsumptionRepository
        )
    }

    // MARK: - Setup/Teardown

    init() {
        // Clear all mock data before each test suite run
        mockPurchaseRecordRepository.clearAllData()
        mockStorageLocationRepository.clearAllData()
        mockInventoryRepository.clearAllData()
        mockConsumptionRepository.clearAllData()
    }
}

// MARK: - PurchaseRecord Deduplication Tests

@Suite("PurchaseRecord Deduplication", .serialized)
@MainActor
struct PurchaseRecordDeduplicationTests {

    private let mockPurchaseRecordRepository = MockPurchaseRecordRepository()
    private let mockStorageLocationRepository = MockStorageLocationRepository()
    private let mockInventoryRepository = MockInventoryRepository()
    private let mockConsumptionRepository = MockInventoryConsumptionRecordRepository()

    private var service: ReceiptImportService {
        ReceiptImportService(
            purchaseRecordRepository: mockPurchaseRecordRepository,
            storageLocationRepository: mockStorageLocationRepository,
            inventoryRepository: mockInventoryRepository,
            consumptionRepository: mockConsumptionRepository
        )
    }

    @Test("Strategy 1: Match by email receipt ID")
    func testMatchByEmailReceiptId() async throws {
        // Setup: Create existing record with email receipt ID
        let existingRecord = PurchaseRecordModel(
            id: UUID(),
            supplier: "Test Supplier",
            datePurchased: Date(),
            emailReceiptId: "receipt-123",
            senderEmail: nil,
            orderNumber: nil
        )
        _ = try await mockPurchaseRecordRepository.createRecord(existingRecord)

        // Test: Find by email receipt ID
        let found = try await service.findExistingPurchaseRecord(
            emailReceiptId: "receipt-123",
            orderNumber: nil,
            supplier: "Test Supplier",
            senderEmail: nil,
            orderDate: Date(),
            total: nil
        )

        #expect(found != nil)
        #expect(found?.emailReceiptId == "receipt-123")
    }

    @Test("Strategy 1: No match when email receipt ID differs")
    func testNoMatchDifferentEmailReceiptId() async throws {
        // Setup: Create existing record with email receipt ID
        let existingRecord = PurchaseRecordModel(
            id: UUID(),
            supplier: "Test Supplier",
            datePurchased: Date(),
            emailReceiptId: "receipt-123",
            senderEmail: nil,
            orderNumber: nil
        )
        _ = try await mockPurchaseRecordRepository.createRecord(existingRecord)

        // Test: Different email receipt ID should not match
        let found = try await service.findExistingPurchaseRecord(
            emailReceiptId: "receipt-456",
            orderNumber: nil,
            supplier: "Test Supplier",
            senderEmail: nil,
            orderDate: Date(),
            total: nil
        )

        #expect(found == nil)
    }

    @Test("Strategy 2: Match by order number + supplier + date")
    func testMatchByOrderNumberSupplierDate() async throws {
        let orderDate = Date()

        // Setup: Create existing record with order number
        let existingRecord = PurchaseRecordModel(
            id: UUID(),
            supplier: "Bullseye Glass",
            datePurchased: orderDate,
            emailReceiptId: nil,
            senderEmail: nil,
            orderNumber: "ORD-2024-001"
        )
        _ = try await mockPurchaseRecordRepository.createRecord(existingRecord)

        // Test: Find by order number + supplier + same day
        let found = try await service.findExistingPurchaseRecord(
            emailReceiptId: nil,
            orderNumber: "ORD-2024-001",
            supplier: "Bullseye Glass",
            senderEmail: nil,
            orderDate: orderDate,
            total: nil
        )

        #expect(found != nil)
        #expect(found?.orderNumber == "ORD-2024-001")
    }

    @Test("Strategy 2: No match when supplier differs")
    func testNoMatchDifferentSupplier() async throws {
        let orderDate = Date()

        // Setup: Create existing record
        let existingRecord = PurchaseRecordModel(
            id: UUID(),
            supplier: "Bullseye Glass",
            datePurchased: orderDate,
            emailReceiptId: nil,
            senderEmail: nil,
            orderNumber: "ORD-2024-001"
        )
        _ = try await mockPurchaseRecordRepository.createRecord(existingRecord)

        // Test: Different supplier should not match
        let found = try await service.findExistingPurchaseRecord(
            emailReceiptId: nil,
            orderNumber: "ORD-2024-001",
            supplier: "Spectrum Glass",
            senderEmail: nil,
            orderDate: orderDate,
            total: nil
        )

        #expect(found == nil)
    }

    @Test("Strategy 3: Match by sender email + date")
    func testMatchBySenderEmailDate() async throws {
        let orderDate = Date()

        // Setup: Create existing record with sender email
        let existingRecord = PurchaseRecordModel(
            id: UUID(),
            supplier: "Test Supplier",
            datePurchased: orderDate,
            emailReceiptId: nil,
            senderEmail: "orders@bullseyeglass.com",
            orderNumber: nil
        )
        _ = try await mockPurchaseRecordRepository.createRecord(existingRecord)

        // Test: Find by sender email + same day
        let found = try await service.findExistingPurchaseRecord(
            emailReceiptId: nil,
            orderNumber: nil,
            supplier: "Test Supplier",
            senderEmail: "orders@bullseyeglass.com",
            orderDate: orderDate,
            total: nil
        )

        #expect(found != nil)
        #expect(found?.senderEmail == "orders@bullseyeglass.com")
    }

    @Test("Strategy 3: Match by sender email + date + approximate total")
    func testMatchBySenderEmailDateTotal() async throws {
        let orderDate = Date()

        // Setup: Create existing record with total
        let existingRecord = PurchaseRecordModel(
            id: UUID(),
            supplier: "Test Supplier",
            datePurchased: orderDate,
            subtotal: Decimal(100.00),
            emailReceiptId: nil,
            senderEmail: "orders@bullseyeglass.com",
            orderNumber: nil
        )
        _ = try await mockPurchaseRecordRepository.createRecord(existingRecord)

        // Test: Find by sender email + date + approximate total (within 1%)
        let found = try await service.findExistingPurchaseRecord(
            emailReceiptId: nil,
            orderNumber: nil,
            supplier: "Test Supplier",
            senderEmail: "orders@bullseyeglass.com",
            orderDate: orderDate,
            total: Decimal(100.50) // Within 1% tolerance
        )

        #expect(found != nil)
    }

    @Test("Returns nil when no match found")
    func testNoMatchReturnsNil() async throws {
        // No setup - empty repository

        let found = try await service.findExistingPurchaseRecord(
            emailReceiptId: "nonexistent",
            orderNumber: "nonexistent",
            supplier: "Unknown",
            senderEmail: "unknown@example.com",
            orderDate: Date(),
            total: Decimal(50.00)
        )

        #expect(found == nil)
    }

    @Test("Email receipt ID takes precedence over other strategies")
    func testEmailReceiptIdPrecedence() async throws {
        let orderDate = Date()

        // Setup: Create two records - one with email ID, one with order number
        let recordWithEmailId = PurchaseRecordModel(
            id: UUID(),
            supplier: "Bullseye Glass",
            datePurchased: orderDate,
            emailReceiptId: "receipt-123",
            senderEmail: "orders@bullseyeglass.com",
            orderNumber: "ORD-001"
        )
        let recordWithOrderNumber = PurchaseRecordModel(
            id: UUID(),
            supplier: "Bullseye Glass",
            datePurchased: orderDate,
            emailReceiptId: nil,
            senderEmail: "orders@bullseyeglass.com",
            orderNumber: "ORD-002"
        )
        _ = try await mockPurchaseRecordRepository.createRecord(recordWithEmailId)
        _ = try await mockPurchaseRecordRepository.createRecord(recordWithOrderNumber)

        // Test: Email receipt ID should be matched first
        let found = try await service.findExistingPurchaseRecord(
            emailReceiptId: "receipt-123",
            orderNumber: "ORD-002",
            supplier: "Bullseye Glass",
            senderEmail: "orders@bullseyeglass.com",
            orderDate: orderDate,
            total: nil
        )

        #expect(found?.emailReceiptId == "receipt-123")
    }
}

// MARK: - StorageLocation Matching Tests

@Suite("StorageLocation Matching", .serialized)
@MainActor
struct StorageLocationMatchingTests {

    private let mockPurchaseRecordRepository = MockPurchaseRecordRepository()
    private let mockStorageLocationRepository = MockStorageLocationRepository()
    private let mockInventoryRepository = MockInventoryRepository()
    private let mockConsumptionRepository = MockInventoryConsumptionRecordRepository()

    private var service: ReceiptImportService {
        ReceiptImportService(
            purchaseRecordRepository: mockPurchaseRecordRepository,
            storageLocationRepository: mockStorageLocationRepository,
            inventoryRepository: mockInventoryRepository,
            consumptionRepository: mockConsumptionRepository
        )
    }

    @Test("Returns empty result when no inventory exists")
    func testNoInventoryReturnsEmpty() async throws {
        let result = try await service.findMatchingLocations(
            itemStableId: "bullseye-001-0",
            orderDate: Date(),
            requestedQuantity: 5.0
        )

        #expect(result.availableQuantity == 0)
        #expect(result.requestedQuantity == 5.0)
        #expect(result.matchingLocations.isEmpty)
        #expect(result.isFullMatch == false)
        #expect(result.shortfall == 5.0)
    }

    @Test("Finds unlinked locations for existing inventory")
    func testFindsUnlinkedLocations() async throws {
        let inventoryId = UUID()
        let orderDate = Date()

        // Setup: Create inventory and unlinked storage locations
        let inventory = InventoryModel(
            id: inventoryId,
            item_stable_id: "bullseye-001-0",
            type: "rod",
            quantity: 10.0,
            date_added: orderDate,
            date_modified: orderDate
        )
        _ = try await mockInventoryRepository.createInventory(inventory)

        let location = StorageLocationModel(
            id: UUID(),
            inventoryId: inventoryId,
            locationName: "Shelf A",
            quantity: 10.0,
            dateAdded: orderDate,
            dateModified: orderDate,
            purchaseRecordItemId: nil // Unlinked
        )
        _ = try await mockStorageLocationRepository.createLocation(location)

        // Test
        let result = try await service.findMatchingLocations(
            itemStableId: "bullseye-001-0",
            orderDate: orderDate,
            requestedQuantity: 5.0
        )

        #expect(result.availableQuantity == 10.0)
        #expect(result.requestedQuantity == 5.0)
        #expect(result.matchingLocations.count == 1)
        #expect(result.isFullMatch == true)
        #expect(result.shortfall == 0)
    }

    @Test("Excludes already linked locations")
    func testExcludesLinkedLocations() async throws {
        let inventoryId = UUID()
        let orderDate = Date()
        let purchaseItemId = UUID()

        // Setup: Create inventory
        let inventory = InventoryModel(
            id: inventoryId,
            item_stable_id: "bullseye-001-0",
            type: "rod",
            quantity: 15.0,
            date_added: orderDate,
            date_modified: orderDate
        )
        _ = try await mockInventoryRepository.createInventory(inventory)

        // Create one linked and one unlinked location
        let linkedLocation = StorageLocationModel(
            id: UUID(),
            inventoryId: inventoryId,
            locationName: "Shelf A",
            quantity: 10.0,
            dateAdded: orderDate,
            dateModified: orderDate,
            purchaseRecordItemId: purchaseItemId // Already linked
        )
        let unlinkedLocation = StorageLocationModel(
            id: UUID(),
            inventoryId: inventoryId,
            locationName: "Shelf B",
            quantity: 5.0,
            dateAdded: orderDate,
            dateModified: orderDate,
            purchaseRecordItemId: nil // Unlinked
        )
        _ = try await mockStorageLocationRepository.createLocation(linkedLocation)
        _ = try await mockStorageLocationRepository.createLocation(unlinkedLocation)

        // Test
        let result = try await service.findMatchingLocations(
            itemStableId: "bullseye-001-0",
            orderDate: orderDate,
            requestedQuantity: 5.0
        )

        // Should only find unlinked location
        #expect(result.availableQuantity == 5.0)
        #expect(result.matchingLocations.count == 1)
        #expect(result.matchingLocations.first?.locationName == "Shelf B")
    }

    @Test("Sorts locations by closeness to order date")
    func testSortsByClosenessToOrderDate() async throws {
        let inventoryId = UUID()
        let orderDate = Date()

        // Setup: Create inventory
        let inventory = InventoryModel(
            id: inventoryId,
            item_stable_id: "bullseye-001-0",
            type: "rod",
            quantity: 30.0,
            date_added: orderDate,
            date_modified: orderDate
        )
        _ = try await mockInventoryRepository.createInventory(inventory)

        // Create locations with different dates
        let farPast = orderDate.addingTimeInterval(-86400 * 30) // 30 days before
        let nearPast = orderDate.addingTimeInterval(-86400) // 1 day before
        let nearFuture = orderDate.addingTimeInterval(86400) // 1 day after

        let locations = [
            StorageLocationModel(
                id: UUID(),
                inventoryId: inventoryId,
                locationName: "Far Past",
                quantity: 10.0,
                dateAdded: farPast,
                dateModified: farPast
            ),
            StorageLocationModel(
                id: UUID(),
                inventoryId: inventoryId,
                locationName: "Near Past",
                quantity: 10.0,
                dateAdded: nearPast,
                dateModified: nearPast
            ),
            StorageLocationModel(
                id: UUID(),
                inventoryId: inventoryId,
                locationName: "Near Future",
                quantity: 10.0,
                dateAdded: nearFuture,
                dateModified: nearFuture
            )
        ]

        for location in locations {
            _ = try await mockStorageLocationRepository.createLocation(location)
        }

        // Test
        let result = try await service.findMatchingLocations(
            itemStableId: "bullseye-001-0",
            orderDate: orderDate,
            requestedQuantity: 30.0
        )

        #expect(result.matchingLocations.count == 3)
        // Near Past and Near Future should be first (both 1 day away)
        // Far Past should be last (30 days away)
        #expect(result.matchingLocations.last?.locationName == "Far Past")
    }

    @Test("Calculates shortfall correctly for partial match")
    func testCalculatesShortfall() async throws {
        let inventoryId = UUID()
        let orderDate = Date()

        // Setup: Create inventory with less than requested
        let inventory = InventoryModel(
            id: inventoryId,
            item_stable_id: "bullseye-001-0",
            type: "rod",
            quantity: 3.0,
            date_added: orderDate,
            date_modified: orderDate
        )
        _ = try await mockInventoryRepository.createInventory(inventory)

        let location = StorageLocationModel(
            id: UUID(),
            inventoryId: inventoryId,
            locationName: "Shelf A",
            quantity: 3.0,
            dateAdded: orderDate,
            dateModified: orderDate
        )
        _ = try await mockStorageLocationRepository.createLocation(location)

        // Test: Request more than available
        let result = try await service.findMatchingLocations(
            itemStableId: "bullseye-001-0",
            orderDate: orderDate,
            requestedQuantity: 5.0
        )

        #expect(result.availableQuantity == 3.0)
        #expect(result.requestedQuantity == 5.0)
        #expect(result.isFullMatch == false)
        #expect(result.shortfall == 2.0)
    }
}

// MARK: - StorageLocation Splitting Tests

@Suite("StorageLocation Splitting", .serialized)
@MainActor
struct StorageLocationSplittingTests {

    private let mockPurchaseRecordRepository = MockPurchaseRecordRepository()
    private let mockStorageLocationRepository = MockStorageLocationRepository()
    private let mockInventoryRepository = MockInventoryRepository()
    private let mockConsumptionRepository = MockInventoryConsumptionRecordRepository()

    private var service: ReceiptImportService {
        ReceiptImportService(
            purchaseRecordRepository: mockPurchaseRecordRepository,
            storageLocationRepository: mockStorageLocationRepository,
            inventoryRepository: mockInventoryRepository,
            consumptionRepository: mockConsumptionRepository
        )
    }

    @Test("Links entire location when quantity matches exactly")
    func testLinksEntireLocationExactMatch() async throws {
        let inventoryId = UUID()
        let locationId = UUID()
        let purchaseItemId = UUID()
        let orderDate = Date()

        // Setup
        let location = StorageLocationModel(
            id: locationId,
            inventoryId: inventoryId,
            locationName: "Shelf A",
            quantity: 5.0,
            dateAdded: orderDate,
            dateModified: orderDate
        )
        _ = try await mockStorageLocationRepository.createLocation(location)

        let matchResult = InventoryMatchResult(
            availableQuantity: 5.0,
            requestedQuantity: 5.0,
            matchingLocations: [location]
        )

        // Test
        let linkedLocations = try await service.linkAndSplitLocations(
            matchResult: matchResult,
            purchaseRecordItemId: purchaseItemId,
            unitPrice: Decimal(10.00),
            currency: "USD"
        )

        #expect(linkedLocations.count == 1)
        #expect(linkedLocations.first?.quantity == 5.0)
        #expect(linkedLocations.first?.purchaseRecordItemId == purchaseItemId)
        #expect(linkedLocations.first?.unitPrice == Decimal(10.00))
        #expect(linkedLocations.first?.currency == "USD")
    }

    @Test("Links entire location when quantity is less than requested")
    func testLinksEntireLocationWhenLess() async throws {
        let inventoryId = UUID()
        let locationId = UUID()
        let purchaseItemId = UUID()
        let orderDate = Date()

        // Setup: Location has 3, we want 5
        let location = StorageLocationModel(
            id: locationId,
            inventoryId: inventoryId,
            locationName: "Shelf A",
            quantity: 3.0,
            dateAdded: orderDate,
            dateModified: orderDate
        )
        _ = try await mockStorageLocationRepository.createLocation(location)

        let matchResult = InventoryMatchResult(
            availableQuantity: 3.0,
            requestedQuantity: 5.0,
            matchingLocations: [location]
        )

        // Test
        let linkedLocations = try await service.linkAndSplitLocations(
            matchResult: matchResult,
            purchaseRecordItemId: purchaseItemId,
            unitPrice: Decimal(10.00),
            currency: "USD"
        )

        #expect(linkedLocations.count == 1)
        #expect(linkedLocations.first?.quantity == 3.0)
        #expect(linkedLocations.first?.purchaseRecordItemId == purchaseItemId)
    }

    @Test("Splits location when quantity exceeds requested")
    func testSplitsLocationWhenExceeds() async throws {
        let inventoryId = UUID()
        let locationId = UUID()
        let purchaseItemId = UUID()
        let orderDate = Date()

        // Setup: Location has 10, we only want 3
        let location = StorageLocationModel(
            id: locationId,
            inventoryId: inventoryId,
            locationName: "Shelf A",
            quantity: 10.0,
            dateAdded: orderDate,
            dateModified: orderDate
        )
        _ = try await mockStorageLocationRepository.createLocation(location)

        let matchResult = InventoryMatchResult(
            availableQuantity: 10.0,
            requestedQuantity: 3.0,
            matchingLocations: [location]
        )

        // Test
        let linkedLocations = try await service.linkAndSplitLocations(
            matchResult: matchResult,
            purchaseRecordItemId: purchaseItemId,
            unitPrice: Decimal(10.00),
            currency: "USD"
        )

        // Should create new linked location with quantity 3
        #expect(linkedLocations.count == 1)
        #expect(linkedLocations.first?.quantity == 3.0)
        #expect(linkedLocations.first?.purchaseRecordItemId == purchaseItemId)

        // Original location should be updated to 7 (unlinked)
        let updatedOriginal = try await mockStorageLocationRepository.fetchLocation(byId: locationId)
        #expect(updatedOriginal?.quantity == 7.0)
        #expect(updatedOriginal?.purchaseRecordItemId == nil)
    }

    @Test("Split preserves original dateAdded on new record")
    func testSplitPreservesDateAdded() async throws {
        let inventoryId = UUID()
        let locationId = UUID()
        let purchaseItemId = UUID()
        let originalDate = Date().addingTimeInterval(-86400 * 7) // 7 days ago

        // Setup
        let location = StorageLocationModel(
            id: locationId,
            inventoryId: inventoryId,
            locationName: "Shelf A",
            quantity: 10.0,
            dateAdded: originalDate,
            dateModified: originalDate
        )
        _ = try await mockStorageLocationRepository.createLocation(location)

        let matchResult = InventoryMatchResult(
            availableQuantity: 10.0,
            requestedQuantity: 3.0,
            matchingLocations: [location]
        )

        // Test
        let linkedLocations = try await service.linkAndSplitLocations(
            matchResult: matchResult,
            purchaseRecordItemId: purchaseItemId,
            unitPrice: nil,
            currency: nil
        )

        // New linked location should inherit original dateAdded
        #expect(linkedLocations.first?.dateAdded == originalDate)
    }

    @Test("Splits across multiple locations")
    func testSplitsAcrossMultipleLocations() async throws {
        let inventoryId = UUID()
        let purchaseItemId = UUID()
        let orderDate = Date()

        // Setup: Two locations with 3 and 4 each, we want 5
        let location1 = StorageLocationModel(
            id: UUID(),
            inventoryId: inventoryId,
            locationName: "Shelf A",
            quantity: 3.0,
            dateAdded: orderDate,
            dateModified: orderDate
        )
        let location2 = StorageLocationModel(
            id: UUID(),
            inventoryId: inventoryId,
            locationName: "Shelf B",
            quantity: 4.0,
            dateAdded: orderDate.addingTimeInterval(3600), // 1 hour later
            dateModified: orderDate
        )
        _ = try await mockStorageLocationRepository.createLocation(location1)
        _ = try await mockStorageLocationRepository.createLocation(location2)

        let matchResult = InventoryMatchResult(
            availableQuantity: 7.0,
            requestedQuantity: 5.0,
            matchingLocations: [location1, location2] // Sorted by closeness
        )

        // Test
        let linkedLocations = try await service.linkAndSplitLocations(
            matchResult: matchResult,
            purchaseRecordItemId: purchaseItemId,
            unitPrice: Decimal(10.00),
            currency: "USD"
        )

        // Should link all of location1 (3) and split 2 from location2
        #expect(linkedLocations.count == 2)

        let totalLinked = linkedLocations.reduce(0.0) { $0 + $1.quantity }
        #expect(totalLinked == 5.0)

        // All linked locations should have purchase info
        for loc in linkedLocations {
            #expect(loc.purchaseRecordItemId == purchaseItemId)
            #expect(loc.unitPrice == Decimal(10.00))
        }
    }

    @Test("Split clears container count on both records")
    func testSplitClearsContainerCount() async throws {
        let inventoryId = UUID()
        let locationId = UUID()
        let purchaseItemId = UUID()
        let orderDate = Date()

        // Setup: Location with container count
        let location = StorageLocationModel(
            id: locationId,
            inventoryId: inventoryId,
            locationName: "Shelf A",
            quantity: 10.0,
            containerCount: 5,
            dateAdded: orderDate,
            dateModified: orderDate
        )
        _ = try await mockStorageLocationRepository.createLocation(location)

        let matchResult = InventoryMatchResult(
            availableQuantity: 10.0,
            requestedQuantity: 3.0,
            matchingLocations: [location]
        )

        // Test
        let linkedLocations = try await service.linkAndSplitLocations(
            matchResult: matchResult,
            purchaseRecordItemId: purchaseItemId,
            unitPrice: nil,
            currency: nil
        )

        // New linked location should not have container count
        #expect(linkedLocations.first?.containerCount == nil)

        // Original should also have container count cleared
        let updatedOriginal = try await mockStorageLocationRepository.fetchLocation(byId: locationId)
        #expect(updatedOriginal?.containerCount == nil)
    }
}

// MARK: - Import as New Inventory Tests

@Suite("Import as New Inventory", .serialized)
@MainActor
struct ImportAsNewInventoryTests {

    private let mockPurchaseRecordRepository = MockPurchaseRecordRepository()
    private let mockStorageLocationRepository = MockStorageLocationRepository()
    private let mockInventoryRepository = MockInventoryRepository()
    private let mockConsumptionRepository = MockInventoryConsumptionRecordRepository()

    private var service: ReceiptImportService {
        ReceiptImportService(
            purchaseRecordRepository: mockPurchaseRecordRepository,
            storageLocationRepository: mockStorageLocationRepository,
            inventoryRepository: mockInventoryRepository,
            consumptionRepository: mockConsumptionRepository
        )
    }

    @Test("Creates new inventory and storage location")
    func testCreatesNewInventoryAndLocation() async throws {
        let purchaseItemId = UUID()

        // Test: Import new item
        let storageLocation = try await service.importAsNewInventory(
            itemStableId: "bullseye-001-0",
            itemType: "rod",
            quantity: 5.0,
            purchaseRecordItemId: purchaseItemId,
            unitPrice: Decimal(12.50),
            currency: "USD",
            locationName: "Shelf A"
        )

        #expect(storageLocation.quantity == 5.0)
        #expect(storageLocation.purchaseRecordItemId == purchaseItemId)
        #expect(storageLocation.unitPrice == Decimal(12.50))
        #expect(storageLocation.currency == "USD")
        #expect(storageLocation.locationName == "Shelf A")

        // Verify inventory was created
        let inventories = try await mockInventoryRepository.fetchInventory(forItem: "bullseye-001-0", type: "rod")
        #expect(inventories.count == 1)

        // BUG CHECK: Verify inventory quantity is set correctly (not 0)
        #expect(inventories.first?.quantity == 5.0, "Inventory quantity should match imported quantity, not be 0")
    }

    @Test("Uses existing inventory record if present")
    func testUsesExistingInventory() async throws {
        let existingInventoryId = UUID()
        let purchaseItemId = UUID()

        // Setup: Create existing inventory with 10 units
        let existingInventory = InventoryModel(
            id: existingInventoryId,
            item_stable_id: "bullseye-001-0",
            type: "rod",
            quantity: 10.0,
            date_added: Date(),
            date_modified: Date()
        )
        _ = try await mockInventoryRepository.createInventory(existingInventory)

        // Test: Import should use existing inventory and add quantity
        let storageLocation = try await service.importAsNewInventory(
            itemStableId: "bullseye-001-0",
            itemType: "rod",
            quantity: 5.0,
            purchaseRecordItemId: purchaseItemId,
            unitPrice: nil,
            currency: nil
        )

        #expect(storageLocation.inventoryId == existingInventoryId)

        // Should not create new inventory record
        let inventories = try await mockInventoryRepository.fetchInventory(forItem: "bullseye-001-0", type: "rod")
        #expect(inventories.count == 1)

        // Quantity should be updated: 10 (existing) + 5 (imported) = 15
        #expect(inventories.first?.quantity == 15.0, "Inventory quantity should be sum of existing + imported")
    }

    @Test("Creates storage location with purchase link")
    func testCreatesStorageLocationWithPurchaseLink() async throws {
        let purchaseItemId = UUID()

        let storageLocation = try await service.importAsNewInventory(
            itemStableId: "bullseye-002-0",
            itemType: "sheet",
            quantity: 2.0,
            purchaseRecordItemId: purchaseItemId,
            unitPrice: Decimal(45.00),
            currency: "USD"
        )

        #expect(storageLocation.purchaseRecordItemId == purchaseItemId)
        #expect(storageLocation.unitPrice == Decimal(45.00))
        #expect(storageLocation.currency == "USD")
    }
}

// MARK: - Record as Consumed Tests

@Suite("Record as Consumed", .serialized)
@MainActor
struct RecordAsConsumedTests {

    private let mockPurchaseRecordRepository = MockPurchaseRecordRepository()
    private let mockStorageLocationRepository = MockStorageLocationRepository()
    private let mockInventoryRepository = MockInventoryRepository()
    private let mockConsumptionRepository = MockInventoryConsumptionRecordRepository()

    private var service: ReceiptImportService {
        ReceiptImportService(
            purchaseRecordRepository: mockPurchaseRecordRepository,
            storageLocationRepository: mockStorageLocationRepository,
            inventoryRepository: mockInventoryRepository,
            consumptionRepository: mockConsumptionRepository
        )
    }

    @Test("Creates consumption record for shortfall")
    func testCreatesConsumptionRecord() async throws {
        let locationId = UUID()
        let inventoryId = UUID()

        // Setup
        let location = StorageLocationModel(
            id: locationId,
            inventoryId: inventoryId,
            locationName: "Shelf A",
            quantity: 3.0,
            dateAdded: Date(),
            dateModified: Date()
        )

        let matchResult = InventoryMatchResult(
            availableQuantity: 3.0,
            requestedQuantity: 5.0,
            matchingLocations: [location]
        )

        // Test
        try await service.recordAsConsumed(
            matchResult: matchResult,
            unitPrice: Decimal(10.00),
            currency: "USD"
        )

        // Verify consumption record created
        let records = mockConsumptionRepository.allRecords
        #expect(records.count == 1)
        #expect(records.first?.quantity == 2.0) // Shortfall
        #expect(records.first?.unitPrice == Decimal(10.00))
        #expect(records.first?.currency == "USD")
    }

    @Test("Does not create consumption record when no shortfall")
    func testNoConsumptionWhenNoShortfall() async throws {
        let locationId = UUID()
        let inventoryId = UUID()

        let location = StorageLocationModel(
            id: locationId,
            inventoryId: inventoryId,
            locationName: "Shelf A",
            quantity: 10.0,
            dateAdded: Date(),
            dateModified: Date()
        )

        let matchResult = InventoryMatchResult(
            availableQuantity: 10.0,
            requestedQuantity: 5.0,
            matchingLocations: [location]
        )

        // Test
        try await service.recordAsConsumed(
            matchResult: matchResult,
            unitPrice: Decimal(10.00),
            currency: "USD"
        )

        // No consumption record should be created
        let records = mockConsumptionRepository.allRecords
        #expect(records.isEmpty)
    }

    @Test("Does not create consumption record when no matching locations")
    func testNoConsumptionWhenNoLocations() async throws {
        let matchResult = InventoryMatchResult(
            availableQuantity: 0,
            requestedQuantity: 5.0,
            matchingLocations: []
        )

        // Test
        try await service.recordAsConsumed(
            matchResult: matchResult,
            unitPrice: Decimal(10.00),
            currency: "USD"
        )

        // No consumption record should be created (no location to attach to)
        let records = mockConsumptionRepository.allRecords
        #expect(records.isEmpty)
    }
}

// MARK: - InventoryMatchResult Tests

@Suite("InventoryMatchResult Computed Properties")
struct InventoryMatchResultTests {

    @Test("isFullMatch returns true when available >= requested")
    func testIsFullMatch() {
        let result = InventoryMatchResult(
            availableQuantity: 10.0,
            requestedQuantity: 5.0,
            matchingLocations: []
        )

        #expect(result.isFullMatch == true)
    }

    @Test("isFullMatch returns true for exact match")
    func testIsFullMatchExact() {
        let result = InventoryMatchResult(
            availableQuantity: 5.0,
            requestedQuantity: 5.0,
            matchingLocations: []
        )

        #expect(result.isFullMatch == true)
    }

    @Test("isFullMatch returns false when available < requested")
    func testIsNotFullMatch() {
        let result = InventoryMatchResult(
            availableQuantity: 3.0,
            requestedQuantity: 5.0,
            matchingLocations: []
        )

        #expect(result.isFullMatch == false)
    }

    @Test("shortfall calculates correctly")
    func testShortfall() {
        let result = InventoryMatchResult(
            availableQuantity: 3.0,
            requestedQuantity: 5.0,
            matchingLocations: []
        )

        #expect(result.shortfall == 2.0)
    }

    @Test("shortfall is zero when no shortfall")
    func testNoShortfall() {
        let result = InventoryMatchResult(
            availableQuantity: 10.0,
            requestedQuantity: 5.0,
            matchingLocations: []
        )

        #expect(result.shortfall == 0)
    }
}

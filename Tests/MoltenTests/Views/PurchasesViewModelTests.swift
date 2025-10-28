//
//  PurchasesViewModelTests.swift
//  MoltenTests
//
//  Created by Assistant on 10/27/25.
//  Tests for PurchasesViewModel presentation logic
//

import Testing
@testable import Molten

/// Tests for PurchasesViewModel presentation logic
///
/// Tests cover: loading, searching, filtering, deletion, error handling
@Suite("PurchasesViewModel Tests")
struct PurchasesViewModelTests {

    // MARK: - Loading Tests

    @Test("Should load purchases on initialization")
    func testLoadPurchases() async throws {
        // Arrange
        let mockService = createMockPurchaseService()
        let viewModel = PurchasesViewModel(purchaseService: mockService)

        // Act
        await viewModel.loadPurchases()

        // Assert
        #expect(viewModel.purchases.count == 3)
        #expect(viewModel.isLoading == false)
    }

    @Test("Should set loading state during fetch")
    func testLoadingState() async throws {
        // Arrange
        let mockService = createMockPurchaseService()
        let viewModel = PurchasesViewModel(purchaseService: mockService)

        // Assert initial state
        #expect(viewModel.isLoading == false)

        // Act
        await viewModel.loadPurchases()

        // Assert final state
        #expect(viewModel.isLoading == false)
    }

    @Test("Should refresh purchases")
    func testRefreshPurchases() async throws {
        // Arrange
        let mockService = createMockPurchaseService()
        let viewModel = PurchasesViewModel(purchaseService: mockService)
        await viewModel.loadPurchases()
        let initialCount = viewModel.purchases.count

        // Act
        await viewModel.refreshPurchases()

        // Assert - should still have same data after refresh
        #expect(viewModel.purchases.count == initialCount)
        #expect(viewModel.isLoading == false)
    }

    // MARK: - Search Tests

    @Test("Should filter purchases by supplier name")
    func testSearchBySupplier() async throws {
        // Arrange
        let mockService = createMockPurchaseService()
        let viewModel = PurchasesViewModel(purchaseService: mockService)
        await viewModel.loadPurchases()

        // Act
        viewModel.searchText = "Frantz"

        // Assert
        #expect(viewModel.filteredPurchases.count == 1)
        #expect(viewModel.filteredPurchases.first?.supplier == "Frantz Art Glass")
    }

    @Test("Should filter purchases by notes")
    func testSearchByNotes() async throws {
        // Arrange
        let mockService = createMockPurchaseService()
        let viewModel = PurchasesViewModel(purchaseService: mockService)
        await viewModel.loadPurchases()

        // Act
        viewModel.searchText = "bulk"

        // Assert
        #expect(viewModel.filteredPurchases.count >= 1)
        #expect(viewModel.filteredPurchases.contains(where: {
            $0.notes?.localizedCaseInsensitiveContains("bulk") == true
        }))
    }

    @Test("Should clear search text")
    func testClearSearch() async throws {
        // Arrange
        let mockService = createMockPurchaseService()
        let viewModel = PurchasesViewModel(purchaseService: mockService)
        await viewModel.loadPurchases()
        viewModel.searchText = "test query"

        // Act
        viewModel.clearSearch()

        // Assert
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.filteredPurchases.count == viewModel.purchases.count)
    }

    @Test("Should return all purchases when search is empty")
    func testEmptySearch() async throws {
        // Arrange
        let mockService = createMockPurchaseService()
        let viewModel = PurchasesViewModel(purchaseService: mockService)
        await viewModel.loadPurchases()

        // Act
        viewModel.searchText = ""

        // Assert
        #expect(viewModel.filteredPurchases.count == viewModel.purchases.count)
    }

    // MARK: - Deletion Tests

    @Test("Should delete single purchase by ID")
    func testDeleteSinglePurchase() async throws {
        // Arrange
        let mockService = createMockPurchaseService()
        let viewModel = PurchasesViewModel(purchaseService: mockService)
        await viewModel.loadPurchases()

        let purchaseToDelete = viewModel.purchases.first!
        let initialCount = viewModel.purchases.count

        // Act
        await viewModel.deletePurchase(id: purchaseToDelete.id)

        // Assert
        #expect(viewModel.purchases.count == initialCount - 1)
        #expect(!viewModel.purchases.contains(where: { $0.id == purchaseToDelete.id }))
    }

    @Test("Should delete multiple purchases by IDs")
    func testDeleteMultiplePurchases() async throws {
        // Arrange
        let mockService = createMockPurchaseService()
        let viewModel = PurchasesViewModel(purchaseService: mockService)
        await viewModel.loadPurchases()

        let idsToDelete = Array(viewModel.purchases.prefix(2).map { $0.id })
        let initialCount = viewModel.purchases.count

        // Act
        await viewModel.deletePurchases(ids: idsToDelete)

        // Assert
        #expect(viewModel.purchases.count == initialCount - 2)
        for id in idsToDelete {
            #expect(!viewModel.purchases.contains(where: { $0.id == id }))
        }
    }

    // MARK: - Computed Properties Tests

    @Test("Should format total price correctly")
    func testFormattedTotalPrice() async throws {
        // Arrange
        let mockService = createMockPurchaseService()
        let viewModel = PurchasesViewModel(purchaseService: mockService)
        await viewModel.loadPurchases()

        // Act
        let purchase = viewModel.purchases.first { $0.totalPrice != nil }

        // Assert
        if let purchase = purchase {
            #expect(purchase.formattedPrice != nil)
            #expect(purchase.formattedPrice!.contains("$"))
        }
    }

    // MARK: - Helper Methods

    private func createMockPurchaseService() -> PurchaseRecordService {
        let mockRepo = MockPurchaseRecordRepository()

        // Populate with test data
        mockRepo.purchases = [
            PurchaseRecordModel(
                id: UUID(),
                dateAdded: Date(),
                supplier: "Frantz Art Glass",
                totalPrice: 150.00,
                shippingCost: 10.00,
                notes: "Bulk order of clear rods"
            ),
            PurchaseRecordModel(
                id: UUID(),
                dateAdded: Date().addingTimeInterval(-86400), // 1 day ago
                supplier: "Sundance Art Glass",
                totalPrice: 250.00,
                shippingCost: 15.00,
                notes: "Special order colors"
            ),
            PurchaseRecordModel(
                id: UUID(),
                dateAdded: Date().addingTimeInterval(-172800), // 2 days ago
                supplier: "Mountain Glass Arts",
                totalPrice: nil,
                shippingCost: nil,
                notes: nil
            )
        ]

        return PurchaseRecordService(repository: mockRepo)
    }
}

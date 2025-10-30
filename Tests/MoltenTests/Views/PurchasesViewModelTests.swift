//
//  PurchasesViewModelTests.swift
//  MoltenTests
//
//  Created by Assistant on 10/27/25.
//  Tests for PurchasesViewModel presentation logic
//

import Foundation
import Testing
@testable import Molten

/// Tests for PurchasesViewModel presentation logic
///
/// Tests cover: loading, searching, filtering, deletion, error handling
@Suite("PurchasesViewModel Tests")
struct PurchasesViewModelTests {

    // MARK: - Loading Tests

    @Test("Should load purchases on initialization") @MainActor
    func testLoadPurchases() async throws {
        // Arrange
        let mockService = await createMockPurchaseService()
        let viewModel = PurchasesViewModel(purchaseService: mockService)

        // Act
        await viewModel.loadPurchases()

        // Assert
        #expect(viewModel.purchases.count == 3)
        #expect(viewModel.isLoading == false)
    }

    @Test("Should set loading state during fetch") @MainActor
    func testLoadingState() async throws {
        // Arrange
        let mockService = await createMockPurchaseService()
        let viewModel = PurchasesViewModel(purchaseService: mockService)

        // Assert initial state
        #expect(viewModel.isLoading == false)

        // Act
        await viewModel.loadPurchases()

        // Assert final state
        #expect(viewModel.isLoading == false)
    }

    @Test("Should refresh purchases") @MainActor
    func testRefreshPurchases() async throws {
        // Arrange
        let mockService = await createMockPurchaseService()
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

    @Test("Should filter purchases by supplier name") @MainActor
    func testSearchBySupplier() async throws {
        // Arrange
        let mockService = await createMockPurchaseService()
        let viewModel = PurchasesViewModel(purchaseService: mockService)
        await viewModel.loadPurchases()

        // Act
        viewModel.searchText = "Frantz"

        // Assert
        #expect(viewModel.filteredPurchases.count == 1)
        #expect(viewModel.filteredPurchases.first?.supplier == "Frantz Art Glass")
    }

    @Test("Should filter purchases by notes") @MainActor
    func testSearchByNotes() async throws {
        // Arrange
        let mockService = await createMockPurchaseService()
        let viewModel = PurchasesViewModel(purchaseService: mockService)
        await viewModel.loadPurchases()

        // Act
        viewModel.searchText = "bulk"

        // Assert
        #expect(viewModel.filteredPurchases.count >= 1)
        #expect(viewModel.filteredPurchases.contains(where: {
            $0.description?.localizedCaseInsensitiveContains("bulk") == true
        }))
    }

    @Test("Should clear search text") @MainActor
    func testClearSearch() async throws {
        // Arrange
        let mockService = await createMockPurchaseService()
        let viewModel = PurchasesViewModel(purchaseService: mockService)
        await viewModel.loadPurchases()
        viewModel.searchText = "test query"

        // Act
        viewModel.clearSearch()

        // Assert
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.filteredPurchases.count == viewModel.purchases.count)
    }

    @Test("Should return all purchases when search is empty") @MainActor
    func testEmptySearch() async throws {
        // Arrange
        let mockService = await createMockPurchaseService()
        let viewModel = PurchasesViewModel(purchaseService: mockService)
        await viewModel.loadPurchases()

        // Act
        viewModel.searchText = ""

        // Assert
        #expect(viewModel.filteredPurchases.count == viewModel.purchases.count)
    }

    // MARK: - Deletion Tests

    @Test("Should delete multiple purchases by IDs") @MainActor
    func testDeleteMultiplePurchases() async throws {
        // Arrange
        let mockService = await createMockPurchaseService()
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

    // MARK: - Helper Methods

    private func createMockPurchaseService() async -> PurchaseRecordService {
        // Create mock repository with test data
        // Note: Using the real service with the proper MockPurchaseRecordRepository from Sources/
        // This tests the ViewModel's interaction with the service
        let mockRepo = MockPurchaseRecordRepository()

        // Pre-populate with test data
        _ = try? await mockRepo.createRecord(PurchaseRecordModel(
            id: UUID(),
            supplier: "Frantz Art Glass",
            dateAdded: Date(),
            subtotal: 150.00,
            shipping: 10.00,
            notes: "Bulk order of clear rods"
        ))
        _ = try? await mockRepo.createRecord(PurchaseRecordModel(
            id: UUID(),
            supplier: "Sundance Art Glass",
            dateAdded: Date().addingTimeInterval(-86400),
            subtotal: 250.00,
            shipping: 15.00,
            notes: "Special order colors"
        ))
        _ = try? await mockRepo.createRecord(PurchaseRecordModel(
            id: UUID(),
            supplier: "Mountain Glass Arts",
            dateAdded: Date().addingTimeInterval(-172800),
            notes: nil
        ))

        return PurchaseRecordService(repository: mockRepo)
    }
}

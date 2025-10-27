//
//  PurchasesViewModelTests.swift
//  MoltenTests
//
//  Created by Assistant on 10/27/25.
//  TDD tests for PurchasesViewModel - Protocol-based testability
//

import Foundation
import Testing
@testable import Molten

@Suite("PurchasesViewModel Tests - Protocol-Based Design")
@MainActor
struct PurchasesViewModelTests {

    // MARK: - Mock-Based Tests (Protocol-Based Design)

    @Test("Mock: Should initialize with empty state")
    func testMockEmptyState() async throws {
        // Arrange & Act
        let viewModel = MockPurchasesViewModel(scenario: .empty)

        // Assert
        #expect(viewModel.purchases.isEmpty)
        #expect(viewModel.filteredPurchases.isEmpty)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.hasData)
    }

    @Test("Mock: Should initialize with loaded data")
    func testMockLoadedState() async throws {
        // Arrange & Act
        let viewModel = MockPurchasesViewModel(scenario: .loaded)

        // Assert
        #expect(viewModel.purchases.count == 3)
        #expect(viewModel.filteredPurchases.count == 3)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.hasData)
    }

    @Test("Mock: Should initialize with loading state")
    func testMockLoadingState() async throws {
        // Arrange & Act
        let viewModel = MockPurchasesViewModel(scenario: .loading)

        // Assert
        #expect(viewModel.isLoading)
        #expect(!viewModel.hasData)
    }

    @Test("Mock: Should initialize with error state")
    func testMockErrorState() async throws {
        // Arrange & Act
        let viewModel = MockPurchasesViewModel(scenario: .error)

        // Assert
        #expect(viewModel.hasError)
        #expect(viewModel.errorMessage == "Failed to load purchases")
        #expect(!viewModel.hasData)
    }

    @Test("Mock: Should initialize with filtered scenario")
    func testMockFilteredState() async throws {
        // Arrange & Act
        let viewModel = MockPurchasesViewModel(scenario: .filtered)

        // Assert
        #expect(viewModel.purchases.count == 3)
        #expect(viewModel.filteredPurchases.count == 1)
        #expect(viewModel.searchText == "Glass")
    }

    @Test("Mock: Should search purchases correctly")
    func testMockSearchPurchases() async throws {
        // Arrange
        let viewModel = MockPurchasesViewModel(scenario: .loaded)

        // Act
        viewModel.searchPurchases(text: "Glass")

        // Assert
        #expect(viewModel.searchPurchasesCalled)
        #expect(viewModel.searchText == "Glass")
        #expect(viewModel.filteredPurchases.count >= 1)
        #expect(viewModel.filteredPurchases.allSatisfy { $0.supplier.contains("Glass") })
    }

    @Test("Mock: Should clear search correctly")
    func testMockClearSearch() async throws {
        // Arrange
        let viewModel = MockPurchasesViewModel(scenario: .filtered)
        #expect(viewModel.searchText == "Glass")
        #expect(viewModel.filteredPurchases.count == 1)

        // Act
        viewModel.clearSearch()

        // Assert
        #expect(viewModel.clearSearchCalled)
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.filteredPurchases.count == 3)
    }

    @Test("Mock: Should track load and refresh operations")
    func testMockLoadAndRefresh() async throws {
        // Arrange
        let viewModel = MockPurchasesViewModel(scenario: .empty)

        // Act
        await viewModel.loadPurchases()
        await viewModel.refreshPurchases()

        // Assert
        #expect(viewModel.loadPurchasesCalled)
        #expect(viewModel.refreshPurchasesCalled)
    }

    @Test("Mock: Should delete purchases correctly")
    func testMockDeletePurchases() async throws {
        // Arrange
        let viewModel = MockPurchasesViewModel(scenario: .loaded)
        let initialCount = viewModel.purchases.count
        let firstPurchaseId = viewModel.purchases.first!.id

        // Act
        await viewModel.deletePurchases(ids: [firstPurchaseId])

        // Assert
        #expect(viewModel.deletePurchasesCalled)
        #expect(viewModel.purchases.count == initialCount - 1)
        #expect(!viewModel.purchases.contains { $0.id == firstPurchaseId })
    }

    @Test("Mock: Should compute filtered count correctly")
    func testMockFilteredCount() async throws {
        // Arrange
        let viewModel = MockPurchasesViewModel(scenario: .loaded)

        // Assert
        #expect(viewModel.filteredPurchasesCount == 3)

        // Act - filter with specific search that matches only one
        viewModel.searchPurchases(text: "Supply")

        // Assert after filtering (only "Glass Supply Co" contains "Supply")
        #expect(viewModel.filteredPurchasesCount == 1)
        #expect(viewModel.filteredPurchases.first?.supplier.contains("Supply") == true)
    }

    // MARK: - Integration Tests (Real Service)

    @Test("Integration: Should load purchases from service")
    func testLoadPurchasesIntegration() async throws {
        // Arrange
        let mockRepo = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: mockRepo)
        let viewModel = PurchasesViewModel(purchaseService: service)

        // Add test data
        let purchase1 = PurchaseRecordModel(
            supplier: "Test Supplier 1",
            dateAdded: Date(),
            subtotal: 100.0,
            currency: "USD",
            notes: "Test notes"
        )
        _ = try await mockRepo.createRecord(purchase1)

        // Act
        await viewModel.loadPurchases()

        // Assert
        #expect(viewModel.purchases.count >= 1)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.hasData)
    }

    @Test("Integration: Should filter purchases by search text")
    func testSearchFilterIntegration() async throws {
        // Arrange
        let mockRepo = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: mockRepo)
        let viewModel = PurchasesViewModel(purchaseService: service)

        // Add test data with different suppliers
        let purchase1 = PurchaseRecordModel(supplier: "Glass Supply Co", dateAdded: Date(), subtotal: 100.0, currency: "USD", notes: nil)
        let purchase2 = PurchaseRecordModel(supplier: "Art Store", dateAdded: Date(), subtotal: 50.0, currency: "USD", notes: nil)
        _ = try await mockRepo.createRecord(purchase1)
        _ = try await mockRepo.createRecord(purchase2)

        await viewModel.loadPurchases()

        // Act
        viewModel.searchPurchases(text: "Glass")

        // Assert
        #expect(viewModel.filteredPurchases.count >= 1)
        #expect(viewModel.filteredPurchases.allSatisfy { $0.supplier.contains("Glass") })
    }

    @Test("Integration: Should delete purchases and refresh")
    func testDeletePurchasesIntegration() async throws {
        // Arrange
        let mockRepo = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: mockRepo)
        let viewModel = PurchasesViewModel(purchaseService: service)

        // Add test data
        let purchase = PurchaseRecordModel(supplier: "Test", dateAdded: Date(), subtotal: 100.0, currency: "USD", notes: nil)
        let savedPurchase = try await mockRepo.createRecord(purchase)

        await viewModel.loadPurchases()
        let initialCount = viewModel.purchases.count

        // Act
        await viewModel.deletePurchases(ids: [savedPurchase.id])

        // Assert
        #expect(viewModel.purchases.count == initialCount - 1)
        #expect(!viewModel.purchases.contains { $0.id == savedPurchase.id })
    }

    @Test("Integration: Should sort purchases by date (newest first)")
    func testSortPurchasesByDateIntegration() async throws {
        // Arrange
        let mockRepo = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: mockRepo)
        let viewModel = PurchasesViewModel(purchaseService: service)

        // Add purchases with different dates
        let oldPurchase = PurchaseRecordModel(
            supplier: "Old",
            dateAdded: Date().addingTimeInterval(-86400 * 7),
            subtotal: 100.0,
            currency: "USD",
            notes: nil
        )
        let newPurchase = PurchaseRecordModel(
            supplier: "New",
            dateAdded: Date(),
            subtotal: 50.0,
            currency: "USD",
            notes: nil
        )
        _ = try await mockRepo.createRecord(oldPurchase)
        _ = try await mockRepo.createRecord(newPurchase)

        // Act
        await viewModel.loadPurchases()

        // Assert
        #expect(viewModel.purchases.count >= 2)
        // Newest should be first
        #expect(viewModel.purchases.first?.supplier == "New")
    }

    @Test("Integration: Should clear search and show all purchases")
    func testClearSearchIntegration() async throws {
        // Arrange
        let mockRepo = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: mockRepo)
        let viewModel = PurchasesViewModel(purchaseService: service)

        // Add test data
        let purchase1 = PurchaseRecordModel(supplier: "Glass Supply Co", dateAdded: Date(), subtotal: 100.0, currency: "USD", notes: nil)
        let purchase2 = PurchaseRecordModel(supplier: "Art Store", dateAdded: Date(), subtotal: 50.0, currency: "USD", notes: nil)
        _ = try await mockRepo.createRecord(purchase1)
        _ = try await mockRepo.createRecord(purchase2)

        await viewModel.loadPurchases()
        viewModel.searchPurchases(text: "Glass")
        let filteredCount = viewModel.filteredPurchases.count

        // Act
        viewModel.clearSearch()

        // Assert
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.filteredPurchases.count > filteredCount)
        #expect(viewModel.filteredPurchases.count == viewModel.purchases.count)
    }
}

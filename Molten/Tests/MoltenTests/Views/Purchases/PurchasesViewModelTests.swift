//
//  PurchasesViewModelTests.swift
//  MoltenTests
//
//  Tests for PurchasesViewModel following TDD and Swift 6 concurrency guidelines
//

import Testing
import Foundation
@testable import Molten

@Suite("PurchasesViewModel Tests")
@MainActor
struct PurchasesViewModelTests {

    // MARK: - Shared Dependencies

    /// ✅ CRITICAL: Store AppDependencies at struct level to keep PersistenceController alive
    private let deps = AppDependencies(persistenceController: .createTestController())

    // MARK: - Helper Methods

    private func createViewModel() -> PurchasesViewModel {
        return PurchasesViewModel(purchaseService: deps.purchaseRecordService)
    }

    private func createSamplePurchase(
        supplier: String = "Test Supplier",
        subtotal: Decimal = Decimal(100.00),
        notes: String? = nil
    ) -> PurchaseRecordModel {
        return PurchaseRecordModel(
            id: UUID(),
            supplier: supplier,
            datePurchased: Date(),
            subtotal: subtotal,
            notes: notes,
            items: []
        )
    }

    // MARK: - Initialization Tests

    @Test("Initial state is empty and not loading")
    func testInitialState() async throws {
        let viewModel = createViewModel()

        #expect(viewModel.purchases.isEmpty)
        #expect(viewModel.filteredPurchases.isEmpty)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.searchText.isEmpty)
    }

    @Test("hasData returns false when no purchases")
    func testHasDataEmptyState() async throws {
        let viewModel = createViewModel()

        #expect(!viewModel.hasData)
    }

    @Test("hasError returns false when no error")
    func testHasErrorNoError() async throws {
        let viewModel = createViewModel()

        #expect(!viewModel.hasError)
    }

    // MARK: - Loading Tests

    @Test("loadPurchases fetches data from service")
    func testLoadPurchasesFetchesData() async throws {
        let service = deps.purchaseRecordService
        let viewModel = createViewModel()

        // Create a purchase first
        let purchase = createSamplePurchase(supplier: "Glass Supply Co", subtotal: Decimal(150.00))
        _ = try await service.createRecord(purchase)

        // Load purchases
        await viewModel.loadPurchases()

        #expect(!viewModel.isLoading)
        #expect(viewModel.purchases.contains { $0.id == purchase.id })
        #expect(viewModel.filteredPurchases.contains { $0.id == purchase.id })
    }

    @Test("loadPurchases sorts by date descending")
    func testLoadPurchasesSortsByDateDescending() async throws {
        let service = deps.purchaseRecordService
        let viewModel = createViewModel()

        // Create purchases with different dates
        let oldPurchase = PurchaseRecordModel(
            id: UUID(),
            supplier: "Old Supplier",
            datePurchased: Date().addingTimeInterval(-86400 * 7), // 7 days ago
            subtotal: Decimal(100.00),
            notes: nil,
            items: []
        )
        let newPurchase = PurchaseRecordModel(
            id: UUID(),
            supplier: "New Supplier",
            datePurchased: Date(),
            subtotal: Decimal(200.00),
            notes: nil,
            items: []
        )

        _ = try await service.createRecord(oldPurchase)
        _ = try await service.createRecord(newPurchase)

        await viewModel.loadPurchases()

        // Most recent should come first
        if viewModel.purchases.count >= 2 {
            let firstPurchase = viewModel.purchases.first { $0.id == newPurchase.id || $0.id == oldPurchase.id }
            #expect(firstPurchase?.id == newPurchase.id)
        }
    }

    @Test("hasData returns true after loading purchases")
    func testHasDataAfterLoading() async throws {
        let service = deps.purchaseRecordService
        let viewModel = createViewModel()

        let purchase = createSamplePurchase()
        _ = try await service.createRecord(purchase)

        await viewModel.loadPurchases()

        #expect(viewModel.hasData)
    }

    @Test("refreshPurchases reloads data")
    func testRefreshPurchasesReloadsData() async throws {
        let service = deps.purchaseRecordService
        let viewModel = createViewModel()

        // Initial load
        let purchase1 = createSamplePurchase(supplier: "Supplier 1")
        _ = try await service.createRecord(purchase1)
        await viewModel.loadPurchases()

        let initialCount = viewModel.purchases.count

        // Add another purchase
        let purchase2 = createSamplePurchase(supplier: "Supplier 2")
        _ = try await service.createRecord(purchase2)

        // Refresh
        await viewModel.refreshPurchases()

        #expect(viewModel.purchases.count > initialCount)
    }

    // MARK: - Search Tests

    @Test("searchPurchases filters by supplier name")
    func testSearchPurchasesFiltersBySupplier() async throws {
        let service = deps.purchaseRecordService
        let viewModel = createViewModel()

        let purchase1 = createSamplePurchase(supplier: "Glass Supply Co", notes: nil)
        let purchase2 = createSamplePurchase(supplier: "Art Store", notes: nil)
        _ = try await service.createRecord(purchase1)
        _ = try await service.createRecord(purchase2)

        await viewModel.loadPurchases()
        viewModel.searchPurchases(text: "Glass")

        #expect(viewModel.filteredPurchases.contains { $0.supplier.contains("Glass") })
        #expect(!viewModel.filteredPurchases.contains { $0.supplier == "Art Store" })
    }

    @Test("searchPurchases filters by notes")
    func testSearchPurchasesFiltersByNotes() async throws {
        let service = deps.purchaseRecordService
        let viewModel = createViewModel()

        let purchase1 = createSamplePurchase(supplier: "Supplier A", notes: "Bulk order of rods")
        let purchase2 = createSamplePurchase(supplier: "Supplier B", notes: "Frit only")
        _ = try await service.createRecord(purchase1)
        _ = try await service.createRecord(purchase2)

        await viewModel.loadPurchases()
        viewModel.searchPurchases(text: "bulk")

        #expect(viewModel.filteredPurchases.contains { $0.notes?.lowercased().contains("bulk") == true })
        #expect(!viewModel.filteredPurchases.contains { $0.notes == "Frit only" })
    }

    @Test("searchPurchases is case insensitive")
    func testSearchPurchasesCaseInsensitive() async throws {
        let service = deps.purchaseRecordService
        let viewModel = createViewModel()

        let purchase = createSamplePurchase(supplier: "GLASS SUPPLY CO")
        _ = try await service.createRecord(purchase)

        await viewModel.loadPurchases()
        viewModel.searchPurchases(text: "glass")

        #expect(viewModel.filteredPurchases.contains { $0.supplier == "GLASS SUPPLY CO" })
    }

    @Test("searchPurchases updates searchText property")
    func testSearchPurchasesUpdatesSearchText() async throws {
        let viewModel = createViewModel()

        viewModel.searchPurchases(text: "test query")

        #expect(viewModel.searchText == "test query")
    }

    @Test("clearSearch resets filter and searchText")
    func testClearSearchResetsFilter() async throws {
        let service = deps.purchaseRecordService
        let viewModel = createViewModel()

        let purchase1 = createSamplePurchase(supplier: "Glass Supply")
        let purchase2 = createSamplePurchase(supplier: "Art Store")
        _ = try await service.createRecord(purchase1)
        _ = try await service.createRecord(purchase2)

        await viewModel.loadPurchases()
        viewModel.searchPurchases(text: "Glass")

        let filteredCount = viewModel.filteredPurchases.count

        viewModel.clearSearch()

        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.filteredPurchases.count >= filteredCount)
    }

    @Test("Empty search text shows all purchases")
    func testEmptySearchShowsAllPurchases() async throws {
        let service = deps.purchaseRecordService
        let viewModel = createViewModel()

        let purchase1 = createSamplePurchase(supplier: "Supplier 1")
        let purchase2 = createSamplePurchase(supplier: "Supplier 2")
        _ = try await service.createRecord(purchase1)
        _ = try await service.createRecord(purchase2)

        await viewModel.loadPurchases()
        viewModel.searchPurchases(text: "")

        #expect(viewModel.filteredPurchases.count == viewModel.purchases.count)
    }

    @Test("filteredPurchasesCount matches filtered results")
    func testFilteredPurchasesCount() async throws {
        let service = deps.purchaseRecordService
        let viewModel = createViewModel()

        let purchase = createSamplePurchase(supplier: "Test Supplier")
        _ = try await service.createRecord(purchase)

        await viewModel.loadPurchases()

        #expect(viewModel.filteredPurchasesCount == viewModel.filteredPurchases.count)
    }

    // MARK: - Edge Cases

    @Test("Search with no matches returns empty filtered list")
    func testSearchNoMatchesReturnsEmpty() async throws {
        let service = deps.purchaseRecordService
        let viewModel = createViewModel()

        let purchase = createSamplePurchase(supplier: "Glass Supply")
        _ = try await service.createRecord(purchase)

        await viewModel.loadPurchases()
        viewModel.searchPurchases(text: "xyz123nonexistent")

        #expect(viewModel.filteredPurchases.isEmpty)
    }

    @Test("Search text setter triggers filter update")
    func testSearchTextSetterTriggersFilter() async throws {
        let service = deps.purchaseRecordService
        let viewModel = createViewModel()

        let purchase1 = createSamplePurchase(supplier: "Glass Supply")
        let purchase2 = createSamplePurchase(supplier: "Art Store")
        _ = try await service.createRecord(purchase1)
        _ = try await service.createRecord(purchase2)

        await viewModel.loadPurchases()

        // Setting searchText directly should trigger filtering
        viewModel.searchText = "Glass"

        #expect(viewModel.filteredPurchases.allSatisfy { $0.supplier.lowercased().contains("glass") || $0.notes?.lowercased().contains("glass") == true })
    }

    @Test("Purchase with nil notes doesn't crash search")
    func testSearchWithNilNotesNoCrash() async throws {
        let service = deps.purchaseRecordService
        let viewModel = createViewModel()

        let purchaseWithNotes = createSamplePurchase(supplier: "Supplier A", notes: "Some notes")
        let purchaseWithoutNotes = createSamplePurchase(supplier: "Supplier B", notes: nil)
        _ = try await service.createRecord(purchaseWithNotes)
        _ = try await service.createRecord(purchaseWithoutNotes)

        await viewModel.loadPurchases()

        // Should not crash when searching
        viewModel.searchPurchases(text: "Some")

        #expect(viewModel.filteredPurchases.contains { $0.notes == "Some notes" })
    }
}

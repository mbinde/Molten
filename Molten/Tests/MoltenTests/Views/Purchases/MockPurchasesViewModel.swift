//
//  MockPurchasesViewModel.swift
//  MoltenTests
//
//  Created by Assistant on 10/27/25.
//  Mock implementation of PurchasesViewModel for testing and previews
//

import Foundation
import SwiftUI
@testable import Molten

/// Mock implementation of PurchasesViewModelProtocol for testing and previews
///
/// **Usage in tests:**
/// ```swift
/// let mockVM = MockPurchasesViewModel(scenario: .loaded)
/// #expect(mockVM.hasData)
/// ```
///
/// **Usage in previews:**
/// ```swift
/// #Preview("Loaded State") {
///     PurchasesView(viewModel: MockPurchasesViewModel(scenario: .loaded))
/// }
/// ```
@MainActor
@Observable
class MockPurchasesViewModel: PurchasesViewModelProtocol {

    // MARK: - Scenario

    enum Scenario {
        case empty
        case loading
        case error
        case loaded
        case filtered
    }

    // MARK: - Data State

    var purchases: [PurchaseRecordModel]
    var filteredPurchases: [PurchaseRecordModel]

    // MARK: - Loading State

    var isLoading: Bool
    var errorMessage: String?

    // MARK: - Search State

    var searchText: String = ""

    // MARK: - Test Tracking

    var loadPurchasesCalled = false
    var refreshPurchasesCalled = false
    var searchPurchasesCalled = false
    var clearSearchCalled = false

    // MARK: - Initialization

    init(scenario: Scenario = .loaded) {
        switch scenario {
        case .empty:
            self.purchases = []
            self.filteredPurchases = []
            self.isLoading = false
            self.errorMessage = nil

        case .loading:
            self.purchases = []
            self.filteredPurchases = []
            self.isLoading = true
            self.errorMessage = nil

        case .error:
            self.purchases = []
            self.filteredPurchases = []
            self.isLoading = false
            self.errorMessage = "Failed to load purchases"

        case .loaded:
            let mockPurchases = Self.createMockPurchases()
            self.purchases = mockPurchases
            self.filteredPurchases = mockPurchases
            self.isLoading = false
            self.errorMessage = nil

        case .filtered:
            let mockPurchases = Self.createMockPurchases()
            self.purchases = mockPurchases
            // Only show first purchase after "filtering"
            self.filteredPurchases = Array(mockPurchases.prefix(1))
            self.isLoading = false
            self.errorMessage = nil
            self.searchText = "Glass"
        }
    }

    // MARK: - Computed Properties

    var hasData: Bool {
        !purchases.isEmpty
    }

    var hasError: Bool {
        errorMessage != nil
    }

    var filteredPurchasesCount: Int {
        filteredPurchases.count
    }

    // MARK: - Data Loading

    func loadPurchases() async {
        loadPurchasesCalled = true
        // Mock implementation - data already set in init
    }

    func refreshPurchases() async {
        refreshPurchasesCalled = true
        // Mock implementation - data already set in init
    }

    // MARK: - Search

    func searchPurchases(text: String) {
        searchPurchasesCalled = true
        searchText = text

        // Mock implementation - simple filtering
        if text.isEmpty {
            filteredPurchases = purchases
        } else {
            let searchLower = text.lowercased()
            filteredPurchases = purchases.filter { purchase in
                purchase.supplier.lowercased().contains(searchLower) ||
                (purchase.notes?.lowercased().contains(searchLower) ?? false)
            }
        }
    }

    func clearSearch() {
        clearSearchCalled = true
        searchText = ""
        filteredPurchases = purchases
    }

    // MARK: - Mock Data Helpers

    private static func createMockPurchases() -> [PurchaseRecordModel] {
        return [
            PurchaseRecordModel(
                supplier: "Glass Supply Co",
                dateAdded: Date().addingTimeInterval(-86400 * 7), // 7 days ago
                subtotal: 150.00,
                currency: "USD",
                notes: "Bulk order of clear rods"
            ),
            PurchaseRecordModel(
                supplier: "Art Glass Store",
                dateAdded: Date().addingTimeInterval(-86400 * 14), // 14 days ago
                subtotal: 89.50,
                currency: "USD",
                notes: "Frit and powder"
            ),
            PurchaseRecordModel(
                supplier: "Online Glass",
                dateAdded: Date().addingTimeInterval(-86400 * 30), // 30 days ago
                subtotal: 220.00,
                currency: "USD",
                notes: nil
            )
        ]
    }
}

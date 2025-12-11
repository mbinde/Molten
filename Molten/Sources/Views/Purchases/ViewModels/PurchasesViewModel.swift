//
//  PurchasesViewModel.swift
//  Molten
//
//  Created by Assistant on 10/27/25.
//  Protocol-based ViewModel for PurchasesView - enables testability
//

import Foundation
import SwiftUI

/// ViewModel for the Purchases view
///
/// Manages presentation logic for:
/// - Loading purchase records
/// - Searching and filtering purchases
/// - Computing UI state
@MainActor
@Observable
class PurchasesViewModel: PurchasesViewModelProtocol {

    // MARK: - Dependencies

    private let purchaseService: PurchaseRecordService

    // MARK: - Published State

    var purchases: [PurchaseRecordModel] = []
    var isLoading = false
    var errorMessage: String?

    // MARK: - Search State

    var searchText = "" {
        didSet {
            if searchText != oldValue {
                applyFilters()
            }
        }
    }

    // MARK: - Filtered State (computed internally)

    private var _filteredPurchases: [PurchaseRecordModel] = []

    var filteredPurchases: [PurchaseRecordModel] {
        _filteredPurchases
    }

    // MARK: - Initialization

    init(purchaseService: PurchaseRecordService) {
        self.purchaseService = purchaseService
    }

    // MARK: - Computed Properties

    var hasData: Bool {
        !purchases.isEmpty
    }

    var hasError: Bool {
        errorMessage != nil
    }

    var filteredPurchasesCount: Int {
        _filteredPurchases.count
    }

    // MARK: - Data Loading

    func loadPurchases() async {
        isLoading = true
        errorMessage = nil

        do {
            purchases = try await purchaseService.getAllRecords()
                .sorted { $0.dateAdded > $1.dateAdded }
            applyFilters()
        } catch {
            errorMessage = "Failed to load purchases: \(error.localizedDescription)"
            purchases = []
            _filteredPurchases = []
        }

        isLoading = false
    }

    func refreshPurchases() async {
        await loadPurchases()
    }

    // MARK: - Search

    func searchPurchases(text: String) {
        searchText = text
    }

    func clearSearch() {
        searchText = ""
    }

    // MARK: - Private Helpers

    private func applyFilters() {
        var filtered = purchases

        // Apply search filter
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            filtered = filtered.filter { purchase in
                let supplierName = purchase.supplier.lowercased()
                let notes = purchase.notes?.lowercased() ?? ""

                return supplierName.contains(searchLower) ||
                       notes.contains(searchLower)
            }
        }

        _filteredPurchases = filtered
    }
}

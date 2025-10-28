//
//  AddPurchaseRecordViewModel.swift
//  Molten
//
//  Created by Assistant on 10/28/25.
//  ViewModel for AddPurchaseRecordView
//

import Foundation
import SwiftUI

/// ViewModel for adding new purchase records
///
/// Manages form state, validation, and save operations for purchase tracking
@MainActor
@Observable
class AddPurchaseRecordViewModel {

    // MARK: - Form State

    var supplier: String = ""
    var totalAmount: String = ""
    var date: Date = Date()
    var itemType: String = "rod"  // Default type
    var units: CatalogUnits = .rods  // Default units
    var notes: String = ""

    // MARK: - UI State

    var errorMessage: String?
    var showingError: Bool = false
    var isSaving: Bool = false

    // MARK: - Initialization

    init() {
        // Default initialization
    }

    // MARK: - Validation

    /// Check if the form is valid (supplier and amount are required)
    var isValid: Bool {
        let trimmedSupplier = supplier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSupplier.isEmpty else { return false }

        guard let amount = parsedAmount, amount > 0 else { return false }

        return true
    }

    /// Parse amount as Double
    var parsedAmount: Double? {
        guard !totalAmount.isEmpty,
              let value = Double(totalAmount),
              value > 0 else {
            return nil
        }
        return value
    }

    // MARK: - Save Operation

    /// Save the purchase record
    /// - Returns: true if save succeeded, false otherwise
    func save() async -> Bool {
        // Set saving state
        isSaving = true
        defer { isSaving = false }

        // Validate supplier
        let trimmedSupplier = supplier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSupplier.isEmpty else {
            setError("Please enter a valid supplier name")
            return false
        }

        // Validate amount
        guard let amount = parsedAmount else {
            setError("Please enter a valid amount greater than 0")
            return false
        }

        // Create purchase record
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let purchaseRecord = SimplePurchaseRecord(
            supplier: trimmedSupplier,
            totalAmount: amount,
            date: date,
            itemType: itemType,
            units: units,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes
        )

        do {
            // Simulate saving (in a real app, this would integrate with your shopping list service)
            try await simulateSave(purchaseRecord)

            errorMessage = nil
            return true
        } catch {
            setError("Failed to save: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Private Methods

    private func setError(_ message: String) {
        errorMessage = message
        showingError = true
    }

    // Simulate saving the purchase record
    private func simulateSave(_ record: SimplePurchaseRecord) async throws {
        // Simulate network/database delay
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second for tests

        // In a real implementation, this would integrate with:
        // - ShoppingListService for tracking purchases
        // - InventoryTrackingService for updating inventory
        // - A future PurchaseTrackingService

        print("Purchase record saved: \(record.supplier) - $\(record.totalAmount)")
    }
}

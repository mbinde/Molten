//
//  AddInventoryItemViewModel.swift
//  Molten
//
//  Created by Assistant on 10/28/25.
//  ViewModel for AddInventoryItemView
//

import Foundation
import SwiftUI

/// ViewModel for adding new inventory items
///
/// Manages form state, validation, glass item search, type selection, and save operations
@MainActor
@Observable
class AddInventoryItemViewModel {

    // MARK: - Dependencies

    private let inventoryTrackingService: InventoryTrackingService
    private let glassItemRepository: GlassItemRepository
    private let prefilledNaturalKey: String?

    // MARK: - Form State

    var stableId: String = ""
    var selectedGlassItem: GlassItemModel?
    var searchText: String = ""
    var quantity: String = ""
    var selectedType: String = "rod"  // Default type
    var selectedSubtype: String?
    var selectedSubsubtype: String?
    var dimensions: [String: String] = [:]
    var notes: String = ""
    var location: String = ""

    // MARK: - UI State

    var glassItems: [GlassItemModel] = []
    var isLoading: Bool = false
    var isDimensionsExpanded: Bool = false
    var errorMessage: String?
    var showingError: Bool = false

    // MARK: - Initialization

    init(
        prefilledNaturalKey: String? = nil,
        inventoryTrackingService: InventoryTrackingService,
        glassItemRepository: GlassItemRepository
    ) {
        self.prefilledNaturalKey = prefilledNaturalKey
        self.inventoryTrackingService = inventoryTrackingService
        self.glassItemRepository = glassItemRepository

        // Set prefilled key if provided
        if let prefilledKey = prefilledNaturalKey {
            self.stableId = prefilledKey
        }
    }

    // MARK: - Validation

    /// Check if the form is valid (stableId and quantity are required)
    var isValid: Bool {
        !stableId.isEmpty && !quantity.isEmpty
    }

    /// Parse quantity as Double
    var parsedQuantity: Double? {
        guard !quantity.isEmpty,
              let value = Double(quantity),
              value > 0 else {
            return nil
        }
        return value
    }

    // MARK: - Computed Properties

    /// Get the appropriate unit label for quantity based on selected type
    var quantityUnitLabel: String {
        switch selectedType.lowercased() {
        case "rod", "big-rod":
            return selectedType.lowercased()
        case "tube":
            return "tubes"
        case "frit", "powder":
            return "lbs"  // TODO: Add user setting for lbs vs kg
        case "stringer":
            return "stringers"
        case "sheet":
            return "sheets"
        case "scrap":
            return "containers"
        case "murrini-cane":
            return "canes"
        case "murrini-slice":
            return "lbs"
        default:
            return selectedType.lowercased()
        }
    }

    // MARK: - Glass Item Management

    /// Load all glass items from cache (pre-loaded during startup)
    func loadGlassItems() async {
        print("⏱️ [SEARCH] loadGlassItems() started, cache isLoaded=\(CatalogSearchCache.shared.isLoaded)")
        isLoading = true
        defer { isLoading = false }

        // CRITICAL: Trust the cache is loaded during FirstRunDataLoadingView
        // The cache is ALWAYS loaded during startup (see FirstRunDataLoadingView line 189)
        // If it's not loaded yet, we wait for it to finish loading (don't reload!)
        if CatalogSearchCache.shared.isLoaded {
            // Cache ready - instant access!
            glassItems = CatalogSearchCache.shared.items
            print("✅ [SEARCH] Using pre-loaded cache with \(glassItems.count) items")
        } else {
            // Cache still loading from FirstRunDataLoadingView, wait for it
            print("⏳ [SEARCH] Cache not ready, loading from repository...")
            do {
                glassItems = try await glassItemRepository.fetchItems(matching: nil)
                print("✅ [SEARCH] Loaded \(glassItems.count) items from repository")
            } catch {
                print("Error loading glass items: \(error)")
                setError("Failed to load glass items: \(error.localizedDescription)")
            }
        }

        // If we have a prefilled stable_id, retry the lookup now that items are loaded
        if !stableId.isEmpty && selectedGlassItem == nil {
            lookupGlassItem(stableId: stableId)
        }
    }

    /// Select a glass item
    func selectGlassItem(_ item: GlassItemModel) {
        selectedGlassItem = item
        stableId = item.stable_id
    }

    /// Clear selection
    func clearSelection() {
        selectedGlassItem = nil
        stableId = ""
        searchText = ""
    }

    /// Lookup glass item by stable ID
    func lookupGlassItem(stableId: String) {
        selectedGlassItem = glassItems.first { $0.stable_id == stableId }
    }

    // MARK: - Type Management

    /// Called when type changes - resets dependent fields
    func didChangeType() {
        selectedSubtype = nil
        selectedSubsubtype = nil
        dimensions = [:]
        isDimensionsExpanded = false
    }

    /// Called when subtype changes - resets dependent fields
    func didChangeSubtype() {
        selectedSubsubtype = nil
    }

    // MARK: - Save Operation

    /// Save the inventory item
    /// - Returns: true if save succeeded, false otherwise
    func save() async -> Bool {
        // Validate required fields
        guard !stableId.isEmpty else {
            setError("Please select a glass item")
            return false
        }

        guard !quantity.isEmpty else {
            setError("Please enter a quantity")
            return false
        }

        guard let quantityValue = parsedQuantity else {
            setError("Invalid quantity format")
            return false
        }

        // Verify the glass item exists
        guard selectedGlassItem != nil else {
            setError("Please select a glass item")
            return false
        }

        // Prepare location (nil if empty)
        let finalLocation = location.isEmpty ? nil : location

        do {
            _ = try await inventoryTrackingService.addInventory(
                quantity: quantityValue,
                type: selectedType,
                toItem: stableId,
                atLocation: finalLocation
            )

            errorMessage = nil
            return true
        } catch {
            setError("Failed to save: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Error Handling

    private func setError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}

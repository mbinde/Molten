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
    private let catalogService: CatalogService
    private let prefilledNaturalKey: String?

    // MARK: - Form State

    var stableId: String = ""
    var selectedCatalogItem: UnifiedCatalogItem?
    var searchText: String = ""
    var quantity: String = ""
    var selectedType: String = "rod"  // Default type
    var selectedSubtype: String?
    var selectedSubsubtype: String?
    var selectedWeightUnit: WeightUnit = WeightUnitPreference.current
    var selectedDimensionUnit: DimensionUnit = DimensionUnitPreference.current.primaryUnit
    var dimensions: [String: String] = [:]
    var notes: String = ""
    var location: String = ""

    // MARK: - UI State

    var catalogItems: [UnifiedCatalogItem] = []
    var isLoading: Bool = false
    var isDimensionsExpanded: Bool = false
    var errorMessage: String?
    var showingError: Bool = false

    // MARK: - Initialization

    init(
        prefilledNaturalKey: String? = nil,
        inventoryTrackingService: InventoryTrackingService,
        catalogService: CatalogService
    ) {
        self.prefilledNaturalKey = prefilledNaturalKey
        self.inventoryTrackingService = inventoryTrackingService
        self.catalogService = catalogService

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

    /// Check if the selected type uses weight units (grams/ounces)
    var isWeightBasedType: Bool {
        switch selectedType.lowercased() {
        case "frit", "powder", "enamel":
            return true
        default:
            return false
        }
    }

    /// Get the appropriate unit label for quantity based on selected type
    var quantityUnitLabel: String {
        switch selectedType.lowercased() {
        case "rod", "big-rod":
            return selectedType.lowercased()
        case "tube":
            return "tubes"
        case "frit", "powder", "enamel":
            return selectedWeightUnit == .grams ? "g" : "oz"
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

    // MARK: - Catalog Item Management

    /// Load all catalog items from cache (pre-loaded during startup)
    func loadCatalogItems() async {
        print("⏱️ [SEARCH] loadCatalogItems() started, cache isLoaded=\(CatalogSearchCache.shared.isLoaded)")
        isLoading = true
        defer { isLoading = false }

        // CRITICAL: Trust the cache is loaded during FirstRunDataLoadingView
        // The cache is ALWAYS loaded during startup (see FirstRunDataLoadingView line 189)
        // If it's not loaded yet, we wait for it to finish loading (don't reload!)
        if CatalogSearchCache.shared.isLoaded {
            // Cache ready - instant access!
            catalogItems = CatalogSearchCache.shared.items
            print("✅ [SEARCH] Using pre-loaded cache with \(catalogItems.count) items")
        } else {
            // Cache still loading from FirstRunDataLoadingView, wait for it
            print("⏳ [SEARCH] Cache not ready, loading from catalog service...")
            do {
                catalogItems = try await catalogService.getAllCatalogItemsLightweight()
                print("✅ [SEARCH] Loaded \(catalogItems.count) items from catalog service")
            } catch {
                print("Error loading catalog items: \(error)")
                setError("Failed to load catalog items: \(error.localizedDescription)")
            }
        }

        // If we have a prefilled stable_id, retry the lookup now that items are loaded
        if !stableId.isEmpty && selectedCatalogItem == nil {
            lookupCatalogItem(stableId: stableId)
        }
    }

    /// Select a catalog item
    func selectCatalogItem(_ item: UnifiedCatalogItem) {
        selectedCatalogItem = item
        stableId = item.stable_id
    }

    /// Clear selection
    func clearSelection() {
        selectedCatalogItem = nil
        stableId = ""
        searchText = ""
    }

    /// Lookup catalog item by stable ID
    func lookupCatalogItem(stableId: String) {
        selectedCatalogItem = catalogItems.first { $0.stable_id == stableId }
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

        // Verify the catalog item exists
        guard selectedCatalogItem != nil else {
            setError("Please select a catalog item")
            return false
        }

        // Prepare location (nil if empty)
        let finalLocation = location.isEmpty ? nil : location

        // Convert weight to grams if needed (always store in grams)
        let finalQuantity: Double
        if isWeightBasedType && selectedWeightUnit == .ounces {
            // Convert ounces to grams
            finalQuantity = selectedWeightUnit.convert(quantityValue, to: .grams)
        } else {
            finalQuantity = quantityValue
        }

        // Parse dimensions and convert to cm (always store in cm)
        let parsedDimensions: [String: Double]? = {
            guard !dimensions.isEmpty else { return nil }
            var result: [String: Double] = [:]
            for (key, valueString) in dimensions {
                if let value = Double(valueString), !valueString.isEmpty {
                    // Convert to cm if needed
                    let valueInCm = selectedDimensionUnit.convert(value, to: .centimeters)
                    result[key] = valueInCm
                }
            }
            return result.isEmpty ? nil : result
        }()

        do {
            _ = try await inventoryTrackingService.addInventory(
                quantity: finalQuantity,
                type: selectedType,
                toItem: stableId,
                subtype: selectedSubtype,
                subsubtype: selectedSubsubtype,
                dimensions: parsedDimensions,
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

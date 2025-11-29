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
    private let userNotesRepository: UserNotesRepository
    private let prefilledNaturalKey: String?

    // MARK: - Form State

    var stableId: String = ""
    var selectedCatalogItem: UnifiedCatalogItem?
    var searchText: String = ""
    var quantity: String = ""  // Weight input (for weight mode)
    var containerCount: String = ""  // Jar count input (for jars mode)
    var selectedType: String = LastUsedInventoryTypePreference.type  // Default to last used type
    var selectedSubtype: String? = LastUsedInventoryTypePreference.subtype
    var selectedSubsubtype: String? = LastUsedInventoryTypePreference.subsubtype
    var selectedWeightUnit: WeightUnit = WeightUnitPreference.current
    var selectedContainerInputMode: ContainerInputMode = ContainerInputModePreference.current
    var dimensions: [String: String] = [:]
    var dimensionUnits: [String: DimensionUnit] = [:] // Track unit for each dimension field
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
        catalogService: CatalogService,
        userNotesRepository: UserNotesRepository
    ) {
        self.prefilledNaturalKey = prefilledNaturalKey
        self.inventoryTrackingService = inventoryTrackingService
        self.catalogService = catalogService
        self.userNotesRepository = userNotesRepository

        // Set prefilled key if provided
        if let prefilledKey = prefilledNaturalKey {
            self.stableId = prefilledKey
        }
    }

    // MARK: - Validation

    /// Check if the form is valid
    /// For weight-based types: need at least jars OR weight entered
    /// For other types: need quantity entered
    var isValid: Bool {
        guard !stableId.isEmpty else { return false }

        if isWeightBasedType {
            // For weight-based types, need at least one of jars or weight
            return parsedContainerCount != nil || parsedQuantity != nil
        } else {
            // For other types, need quantity
            return !quantity.isEmpty && parsedQuantity != nil
        }
    }

    /// Parse quantity (weight) as Double
    var parsedQuantity: Double? {
        guard !quantity.isEmpty,
              let value = Double(quantity),
              value > 0 else {
            return nil
        }
        return value
    }

    /// Parse container count as Double
    var parsedContainerCount: Double? {
        guard !containerCount.isEmpty,
              let value = Double(containerCount),
              value > 0 else {
            return nil
        }
        return value
    }

    // MARK: - Computed Properties

    /// Check if the selected type uses weight units (grams/ounces)
    var isWeightBasedType: Bool {
        switch selectedType.lowercased() {
        case "frit", "powder", "enamel", "flakes":
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
        case "frit", "powder", "enamel", "flakes":
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

        // CRITICAL: Trust the cache is loaded during LaunchScreenView
        // The cache is ALWAYS loaded during startup
        // If it's not loaded yet, we wait for it to finish loading (don't reload!)
        if CatalogSearchCache.shared.isLoaded {
            // Cache ready - instant access!
            catalogItems = CatalogSearchCache.shared.items
            print("✅ [SEARCH] Using pre-loaded cache with \(catalogItems.count) items")
        } else {
            // Cache still loading from LaunchScreenView, wait for it
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
        dimensionUnits = [:]
        isDimensionsExpanded = false
    }

    /// Get the default dimension unit for a field based on user preference and field name
    func getDefaultDimensionUnit(for fieldName: String) -> DimensionUnit {
        // If already set, return it
        if let existing = dimensionUnits[fieldName] {
            return existing
        }

        // Use smart defaults based on field name and user preference
        let preference = DimensionUnitPreference.current

        // Thickness is often in mm regardless of preference
        if fieldName.lowercased().contains("thickness") {
            return .millimeters
        }

        // Diameter often in mm for metric users
        if fieldName.lowercased().contains("diameter") {
            return preference == .metric ? .millimeters : .inches
        }

        // Length/width/height use primary unit
        return preference.primaryUnit
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

        // Verify the catalog item exists
        guard selectedCatalogItem != nil else {
            setError("Please select a catalog item")
            return false
        }

        // For weight-based types, need at least jars or weight
        // For other types, need quantity
        let finalQuantity: Double
        let finalContainerCount: Double?

        if isWeightBasedType {
            // Weight-based type: can have jars, weight, or both
            let hasJars = parsedContainerCount != nil
            let hasWeight = parsedQuantity != nil

            guard hasJars || hasWeight else {
                setError("Please enter jars or weight")
                return false
            }

            // Get container count if entered
            finalContainerCount = parsedContainerCount

            // Get weight, converting to grams if needed
            if let weightValue = parsedQuantity {
                if selectedWeightUnit == .ounces {
                    finalQuantity = selectedWeightUnit.convert(weightValue, to: .grams)
                } else {
                    finalQuantity = weightValue
                }
            } else {
                // No weight entered - use 0 (will be tracked by jars only)
                // Note: The model allows quantity=0 when containerCount is set
                finalQuantity = 0
            }
        } else {
            // Non-weight type: need quantity
            guard let quantityValue = parsedQuantity else {
                setError("Please enter a quantity")
                return false
            }
            finalQuantity = quantityValue
            finalContainerCount = nil
        }

        // Prepare location (nil if empty)
        let finalLocation = location.isEmpty ? nil : location

        // Parse dimensions and convert to cm (always store in cm)
        let parsedDimensions: [String: Double]? = {
            guard !dimensions.isEmpty else { return nil }
            var result: [String: Double] = [:]
            for (key, valueString) in dimensions {
                if let value = Double(valueString), !valueString.isEmpty {
                    // Convert to cm using the unit selected for this specific field
                    let unit = dimensionUnits[key] ?? .centimeters
                    let valueInCm = unit.convert(value, to: .centimeters)
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
                containerCount: finalContainerCount,
                atLocation: finalLocation
            )

            // Save notes if provided (non-empty after trimming)
            let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedNotes.isEmpty {
                do {
                    let userNotes = UserNotesModel(
                        item_stable_id: stableId,
                        notes: trimmedNotes
                    )
                    _ = try await userNotesRepository.setNotes(userNotes)
                } catch {
                    // Log warning but don't fail the whole operation
                    // Inventory save is primary, notes are secondary
                    print("⚠️ Warning: Failed to save notes for \(stableId): \(error.localizedDescription)")
                }
            }

            // Remember the type/subtype/subsubtype for next time
            LastUsedInventoryTypePreference.save(
                type: selectedType,
                subtype: selectedSubtype,
                subsubtype: selectedSubsubtype
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

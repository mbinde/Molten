//
//  AddShoppingListItemView.swift
//  Flameworker
//
//  Created by Assistant on 10/18/25.
//

import SwiftUI

struct AddShoppingListItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(EntitlementService.self) private var entitlementService

    let prefilledNaturalKey: String?
    let existingItem: ItemShoppingModel?  // For edit mode
    let shoppingListService: ShoppingListService
    let catalogService: CatalogService
    let locationService: UnifiedLocationService

    @State private var showingUpgradePrompt = false
    @State private var shoppingItemCount = 0
    @State private var shoppingItemLimit = 0

    private var isEditMode: Bool { existingItem != nil }

    init(prefilledNaturalKey: String? = nil,
         existingItem: ItemShoppingModel? = nil,
         shoppingListService: ShoppingListService,
         catalogService: CatalogService,
         locationService: UnifiedLocationService) {
        self.prefilledNaturalKey = prefilledNaturalKey
        self.existingItem = existingItem
        self.shoppingListService = shoppingListService
        self.catalogService = catalogService
        self.locationService = locationService
    }

    /// Convenience init using AppDependencies
    init(prefilledNaturalKey: String? = nil, existingItem: ItemShoppingModel? = nil, deps: AppDependencies = .shared) {
        self.prefilledNaturalKey = prefilledNaturalKey
        self.existingItem = existingItem
        self.shoppingListService = deps.shoppingListService
        self.catalogService = deps.catalogService
        self.locationService = deps.unifiedLocationService
    }

    var body: some View {
        AddItemFormView(
            title: isEditMode ? "Edit Shopping List Item" : "Add to Shopping List",
            locationFieldType: .shopping(
                shoppingListRepository: shoppingListService.shoppingListRepository,
                locationService: locationService
            ),
            showNotesField: false,
            catalogService: catalogService,
            prefilledNaturalKey: prefilledNaturalKey ?? existingItem?.item_stable_id,
            prefillData: existingItem.map { item in
                AddItemFormPrefill(
                    quantity: item.quantity,
                    type: item.type ?? "rod",
                    subtype: item.subtype,
                    subsubtype: item.subsubtype,
                    locationOrStore: item.store
                )
            },
            onSave: { formData in
                try await saveShoppingListItem(formData)
            }
        )
        .sheet(isPresented: $showingUpgradePrompt) {
            UpgradePromptView(
                feature: "shopping",
                currentCount: shoppingItemCount,
                limit: shoppingItemLimit
            )
        }
    }

    private func saveShoppingListItem(_ formData: AddItemFormData) async throws {
        // Skip entitlement check if editing (not adding new item)
        if !isEditMode {
            // Check subscription entitlement before adding shopping list item
            // Use the same logic as the display - generate shopping lists and count unique items
            // This accounts for catalog lookup failures, merging, and deduplication
            let shoppingLists = try await shoppingListService.generateAllShoppingLists()
            let currentShoppingCount = shoppingLists.values.reduce(0) { $0 + $1.items.count }
            let limit = entitlementService.getShoppingListLimit()
            let canAdd = entitlementService.canAddShoppingListItem(currentCount: currentShoppingCount)

            print("🛒 [Entitlement] Shopping list check: displayCount=\(currentShoppingCount), limit=\(limit ?? -1), canAdd=\(canAdd), tier=\(entitlementService.currentTier)")

            if !canAdd {
                // Hit the limit - show upgrade prompt
                let limitValue = limit ?? 0
                print("🛒 [Entitlement] BLOCKED - showing upgrade prompt with count=\(currentShoppingCount), limit=\(limitValue)")
                await MainActor.run {
                    shoppingItemCount = currentShoppingCount
                    shoppingItemLimit = limitValue
                    showingUpgradePrompt = true
                }
                // Throw a special error that AddItemFormView will ignore (not show alert)
                // This prevents the form from dismissing while upgrade prompt is shown
                throw ShoppingListLimitError.limitReached
            }
        }

        if isEditMode, let existing = existingItem {
            // Update existing item - preserve the original ID
            let updatedItem = ItemShoppingModel(
                id: existing.id,
                item_stable_id: formData.glassItem.stable_id,
                quantity: formData.quantity,
                store: formData.locationOrStore,
                type: formData.type,
                subtype: formData.subtype,
                subsubtype: formData.subsubtype,
                dateAdded: existing.dateAdded
            )
            _ = try await shoppingListService.shoppingListRepository.updateItem(updatedItem)
        } else {
            // Create new item
            let newItem = ItemShoppingModel(
                item_stable_id: formData.glassItem.stable_id,
                quantity: formData.quantity,
                store: formData.locationOrStore,
                type: formData.type,
                subtype: formData.subtype,
                subsubtype: formData.subsubtype
            )
            _ = try await shoppingListService.shoppingListRepository.createItem(newItem)
        }

        // Post success notification
        await MainActor.run {
            let quantityText = String(format: "%.1f", formData.quantity).replacingOccurrences(of: ".0", with: "")
            let typeText = formData.type
            let action = isEditMode ? "updated" : "added to"
            let message = "\(formData.glassItem.name) (\(quantityText) \(typeText)) \(action) shopping list."

            NotificationCenter.default.post(
                name: .shoppingListItemAdded,
                object: nil,
                userInfo: ["message": message]
            )
        }
    }
}

/// Error thrown when shopping list limit is reached
/// This error is handled specially - it shows the upgrade prompt without an error alert
enum ShoppingListLimitError: Error {
    case limitReached
}

#Preview {
    let deps = AppDependencies(persistenceController: .createTestController())
    NavigationStack {
        AddShoppingListItemView(deps: deps)
    }
}

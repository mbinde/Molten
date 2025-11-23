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
    let shoppingListService: ShoppingListService
    let catalogService: CatalogService
    let locationService: UnifiedLocationService

    @State private var showingUpgradePrompt = false
    @State private var shoppingItemCount = 0
    @State private var shoppingItemLimit = 0

    init(prefilledNaturalKey: String? = nil,
         shoppingListService: ShoppingListService,
         catalogService: CatalogService,
         locationService: UnifiedLocationService) {
        self.prefilledNaturalKey = prefilledNaturalKey
        self.shoppingListService = shoppingListService
        self.catalogService = catalogService
        self.locationService = locationService
    }

    /// Convenience init using AppDependencies
    init(prefilledNaturalKey: String? = nil, deps: AppDependencies = AppDependencies()) {
        self.prefilledNaturalKey = prefilledNaturalKey
        self.shoppingListService = deps.shoppingListService
        self.catalogService = deps.catalogService
        self.locationService = deps.unifiedLocationService
    }

    var body: some View {
        AddItemFormView(
            title: "Add to Shopping List",
            locationFieldType: .shopping(
                shoppingListRepository: shoppingListService.shoppingListRepository,
                locationService: locationService
            ),
            showNotesField: false,
            catalogService: catalogService,
            prefilledNaturalKey: prefilledNaturalKey,
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
        // Check subscription entitlement before adding shopping list item
        let allShoppingItems = try await shoppingListService.shoppingListRepository.fetchAllItems()
        let currentShoppingCount = allShoppingItems.count
        let canAdd = entitlementService.canAddShoppingListItem(currentCount: currentShoppingCount)

        if !canAdd {
            // Hit the limit - show upgrade prompt
            let limit = entitlementService.getShoppingListLimit() ?? 0
            await MainActor.run {
                shoppingItemCount = currentShoppingCount
                shoppingItemLimit = limit
                showingUpgradePrompt = true
            }
            throw NSError(domain: "ShoppingList", code: 1, userInfo: [NSLocalizedDescriptionKey: "Shopping list limit reached"])
        }

        // Create shopping list item (ignoring dimensions/weight units - shopping list doesn't track those)
        let newShoppingListItem = ItemShoppingModel(
            item_stable_id: formData.glassItem.stable_id,
            quantity: formData.quantity,
            store: formData.locationOrStore,
            type: formData.type,
            subtype: formData.subtype,
            subsubtype: formData.subsubtype
        )

        // Save to repository
        _ = try await shoppingListService.shoppingListRepository.createItem(newShoppingListItem)

        // Post success notification
        await MainActor.run {
            let quantityText = String(format: "%.1f", formData.quantity).replacingOccurrences(of: ".0", with: "")
            let typeText = formData.type
            let message = "\(formData.glassItem.name) (\(quantityText) \(typeText)) added to shopping list."

            NotificationCenter.default.post(
                name: .shoppingListItemAdded,
                object: nil,
                userInfo: ["message": message]
            )
        }
    }
}

#Preview {
    let deps = AppDependencies(persistenceController: .createTestController())
    NavigationStack {
        AddShoppingListItemView(deps: deps)
    }
}

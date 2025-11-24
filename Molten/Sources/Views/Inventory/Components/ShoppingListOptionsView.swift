//
//  ShoppingListOptionsView.swift
//  Molten
//
//  Shopping list options view with item card, quantity, and store autocomplete
//

import SwiftUI

/// Shopping list options view with item card, quantity, and store autocomplete
struct ShoppingListOptionsView: View {
    let item: CompleteInventoryItemModel
    let shoppingListRepository: ShoppingListRepository
    let locationService: UnifiedLocationService
    let entitlementService: EntitlementService
    @Environment(\.dismiss) private var dismiss

    @State private var quantity: String = ""
    @State private var store: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccessToast = false
    @State private var isSaving = false
    @State private var showingUpgradePrompt = false

    init(
        item: CompleteInventoryItemModel,
        shoppingListRepository: ShoppingListRepository,
        locationService: UnifiedLocationService,
        entitlementService: EntitlementService
    ) {
        self.item = item
        self.shoppingListRepository = shoppingListRepository
        self.locationService = locationService
        self.entitlementService = entitlementService
    }

    /// Convenience init using AppDependencies
    init(item: CompleteInventoryItemModel, deps: AppDependencies = AppDependencies()) {
        self.item = item
        self.shoppingListRepository = deps.shoppingListRepository
        self.locationService = deps.unifiedLocationService
        self.entitlementService = deps.entitlementService
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Glass Item Card
                    GlassItemCard(item: item.glassItem, variant: .compact)

                    // Form Section
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        // Quantity Field
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Quantity")
                                .font(DesignSystem.Typography.label)
                                .fontWeight(DesignSystem.FontWeight.medium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)

                            TextField("Enter quantity", text: $quantity)
                                .textFieldStyle(.roundedBorder)
                                #if canImport(UIKit)
                                .keyboardType(.decimalPad)
                                #endif
                        }

                        // Store Field
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Store")
                                .font(DesignSystem.Typography.label)
                                .fontWeight(DesignSystem.FontWeight.medium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)

                            StoreAutoCompleteField(
                                store: $store,
                                shoppingListRepository: shoppingListRepository,
                                locationService: locationService
                            )
                        }
                    }

                    // Save Button
                    Button(action: saveToShoppingList) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Add to Shopping List")
                                .fontWeight(DesignSystem.FontWeight.semibold)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isSaving || quantity.isEmpty)
                    .accessibilityIdentifier("shopping_list_options_add")

                    Spacer()
                }
                .padding(DesignSystem.Padding.standard)
            }
            .navigationTitle("Add to Shopping List")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                    .accessibilityIdentifier("shopping_list_options_cancel")
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .successToast(message: "Item added to shopping list", isShowing: $showingSuccessToast)
            .sheet(isPresented: $showingUpgradePrompt) {
                UpgradePromptView(
                    feature: "shopping list items",
                    currentCount: 0, // Don't have access to current count here, will be passed from list view
                    limit: entitlementService.getShoppingListLimit() ?? 10
                )
            }
        }
    }

    // MARK: - Actions

    private func saveToShoppingList() {
        // Validate quantity
        guard let quantityValue = Double(quantity), quantityValue > 0 else {
            errorMessage = "Please enter a valid quantity greater than 0"
            showingError = true
            return
        }

        isSaving = true

        Task {
            do {
                // PRE-EMPTIVE LIMIT CHECK (before attempting to save)
                // Get current shopping list item count
                let currentCount = try await shoppingListRepository.getItemCount()

                // Check if this item already exists in shopping list
                let existingItem = try? await shoppingListRepository.fetchItem(forItem: item.glassItem.stable_id)
                let isNewItem = (existingItem == nil)

                // If adding a NEW item (not updating existing), check limit
                if isNewItem && !entitlementService.canAddShoppingListItem(currentCount: currentCount) {
                    await MainActor.run {
                        isSaving = false
                        showingUpgradePrompt = true
                    }
                    return
                }

                // Use addQuantity which handles creating or updating
                let storeValue = store.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalStore = storeValue.isEmpty ? nil : storeValue

                _ = try await shoppingListRepository.addQuantity(
                    quantityValue,
                    toItem: item.glassItem.stable_id,
                    store: finalStore
                )

                await MainActor.run {
                    isSaving = false

                    // Post notification to refresh shopping list
                    NotificationCenter.default.post(name: .shoppingListItemAdded, object: nil)

                    // Show success toast and dismiss immediately
                    showingSuccessToast = true
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to add item to shopping list: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
}

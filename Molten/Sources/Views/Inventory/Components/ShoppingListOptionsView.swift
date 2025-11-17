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
    @Environment(\.dismiss) private var dismiss

    @State private var quantity: String = ""
    @State private var store: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccessToast = false
    @State private var isSaving = false

    init(
        item: CompleteInventoryItemModel,
        shoppingListRepository: ShoppingListRepository,
        locationService: UnifiedLocationService
    ) {
        self.item = item
        self.shoppingListRepository = shoppingListRepository
        self.locationService = locationService
    }

    /// Convenience init using AppDependencies
    init(item: CompleteInventoryItemModel, deps: AppDependencies = AppDependencies()) {
        self.item = item
        self.shoppingListRepository = deps.shoppingListRepository
        self.locationService = deps.unifiedLocationService
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
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .successToast(message: "Item added to shopping list", isShowing: $showingSuccessToast)
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

//
//  CheckoutSheet.swift
//  Molten
//
//  Extracted from ShoppingListView.swift
//

import SwiftUI

struct CheckoutSheet: View {
    let basketItems: [DetailedShoppingListItemModel]
    let shoppingModeState: ShoppingModeState
    let inventoryTrackingService: InventoryTrackingService
    let shoppingListService: ShoppingListService
    let purchaseService: PurchaseRecordService?
    let subscriptionService: SubscriptionServiceProtocol
    let onComplete: () -> Void
    let onExitWithoutCheckout: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var addToInventory = true
    @State private var removeFromList = true
    @State private var createPurchaseRecord = false
    @State private var isProcessing = false
    @State private var quantities: [String: Double] = [:] // natural_key -> adjusted quantity
    @State private var showInventoryLimitWarning = false
    @State private var currentInventoryCount = 0

    // Purchase record fields
    @State private var supplier = ""
    @State private var subtotal: String = ""
    @State private var tax: String = ""
    @State private var shipping: String = ""
    @State private var currency = "USD"
    @State private var notes = ""

    // Error handling
    @State private var showCheckoutError = false
    @State private var checkoutErrorMessage = ""

    // Helper methods for quantity binding
    private func getQuantity(for item: DetailedShoppingListItemModel) -> Double {
        quantities[item.catalogItem.stable_id] ?? item.shoppingListItem.neededQuantity
    }

    private func setQuantity(for item: DetailedShoppingListItemModel, value: Double) {
        quantities[item.catalogItem.stable_id] = value
    }

    // Sorted basket items by name
    private var sortedBasketItems: [DetailedShoppingListItemModel] {
        basketItems.sorted { $0.catalogItem.name.localizedCaseInsensitiveCompare($1.catalogItem.name) == .orderedAscending }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Checkout options at top
                VStack(spacing: DesignSystem.Spacing.md) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("Checkout Options")
                            .font(.headline)
                            .padding(.horizontal, DesignSystem.Spacing.xs)

                        VStack(spacing: DesignSystem.Spacing.sm) {
                            Toggle("Add to inventory", isOn: $addToInventory)
                                .tint(.accentColor)
                                .padding(.horizontal, DesignSystem.Spacing.xs)
                                .accessibilityIdentifier("checkout_add_to_inventory_toggle")
                            Toggle("Remove from shopping list", isOn: $removeFromList)
                                .tint(.accentColor)
                                .padding(.horizontal, DesignSystem.Spacing.xs)
                                .accessibilityIdentifier("checkout_remove_from_list_toggle")

                            if FeatureFlags.ENABLE_PURCHASES && purchaseService != nil {
                                Toggle("Create purchase record", isOn: $createPurchaseRecord)
                                    .tint(.accentColor)
                                    .padding(.horizontal, DesignSystem.Spacing.xs)
                                    .accessibilityIdentifier("checkout_create_purchase_toggle")
                            }
                        }

                        // Purchase record fields (shown when toggle is enabled)
                        if FeatureFlags.ENABLE_PURCHASES && createPurchaseRecord && purchaseService != nil {
                            purchaseDetailsSection
                        }

                        actionButtons
                    }
                }
                .padding()
                #if os(iOS)
                .background(Color(UIColor.systemGroupedBackground))
                #else
                .background(Color(nsColor: NSColor.windowBackgroundColor))
                #endif

                // Items list below
                itemsList
            }
            .navigationTitle("Checkout")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .alert("Inventory Limit Reached", isPresented: $showInventoryLimitWarning) {
                Button("OK") {
                    addToInventory = false
                }
                Button("Upgrade to Pro") {
                    addToInventory = false
                    Task {
                        try? await subscriptionService.presentPaywall()
                    }
                }
            } message: {
                Text("You currently have \(currentInventoryCount) items in your inventory. Free tier users are limited to \(FeatureFlags.FREE_TIER_INVENTORY_LIMIT) items.\n\nIf you complete this checkout, items will not be added to your inventory unless you upgrade to Pro.")
            }
            .alert("Checkout Error", isPresented: $showCheckoutError) {
                Button("OK") { }
            } message: {
                Text(checkoutErrorMessage)
            }
        }
    }

    // MARK: - View Components

    private var purchaseDetailsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Purchase Details")
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.horizontal, DesignSystem.Spacing.xs)
                .padding(.top, DesignSystem.Spacing.xs)

            VStack(spacing: DesignSystem.Spacing.sm) {
                purchaseField(label: "Supplier:", placeholder: "Supplier name", text: $supplier)
                purchaseField(label: "Subtotal:", placeholder: "0.00", text: $subtotal, isNumeric: true)
                purchaseField(label: "Tax:", placeholder: "0.00", text: $tax, isNumeric: true)
                purchaseField(label: "Shipping:", placeholder: "0.00", text: $shipping, isNumeric: true)
                purchaseField(label: "Notes:", placeholder: "Optional notes", text: $notes)
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(DesignSystem.CornerRadius.medium)
        }
    }

    private func purchaseField(label: String, placeholder: String, text: Binding<String>, isNumeric: Bool = false) -> some View {
        HStack {
            Text(label)
                .frame(width: 80, alignment: .leading)
            TextField(placeholder, text: text)
                #if os(iOS)
                .keyboardType(isNumeric ? .decimalPad : .default)
                .textFieldStyle(.roundedBorder)
                #endif
        }
        .padding(.horizontal, DesignSystem.Spacing.xs)
    }

    private var actionButtons: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Button("Cancel") {
                dismiss()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.gray.opacity(0.2))
            .foregroundColor(.primary)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .accessibilityIdentifier("checkout_cancel_button")

            Button(action: {
                Task {
                    await performCheckout()
                }
            }) {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text("Checkout")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .disabled(isProcessing)
            .accessibilityIdentifier("checkout_confirm_button")
        }
    }

    private var itemsList: some View {
        List {
            Section(header: Text("Items in Basket (\(sortedBasketItems.count))")) {
                ForEach(sortedBasketItems, id: \.shoppingListItem.item_stable_id) { item in
                    HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.catalogItem.name)
                                .font(.headline)
                            Text(item.catalogItem.stable_id)
                                .secondaryCaption()
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            TextField("Qty", value: Binding(
                                get: { getQuantity(for: item) },
                                set: { setQuantity(for: item, value: $0) }
                            ), format: .number)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            #if os(iOS)
                            .textFieldStyle(.roundedBorder)
                            #endif

                            Text("rod")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .onAppear {
            initializeQuantities()
            checkInventoryLimit()
        }
    }

    // MARK: - Actions

    private func initializeQuantities() {
        for item in basketItems {
            if quantities[item.catalogItem.stable_id] == nil {
                quantities[item.catalogItem.stable_id] = shoppingModeState.getQuantity(for: item.catalogItem.stable_id) ?? item.shoppingListItem.neededQuantity
            }
        }
    }

    private func checkInventoryLimit() {
        Task {
            let isPro = await subscriptionService.hasProAccess()
            let itemsWithInventory = try? await inventoryTrackingService.getItemsWithInventory()
            currentInventoryCount = itemsWithInventory?.count ?? 0

            if !isPro && currentInventoryCount >= FeatureFlags.FREE_TIER_INVENTORY_LIMIT {
                showInventoryLimitWarning = true
            }
        }
    }

    private func performCheckout() async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            var purchaseRecordId: UUID? = nil

            // Create purchase record first (if requested)
            if createPurchaseRecord, let purchaseService = purchaseService {
                purchaseRecordId = try await createPurchaseRecord(with: purchaseService)
            }

            // Add to inventory
            if addToInventory {
                try await addItemsToInventory()
            }

            // Remove from shopping list or adjust quantities
            if removeFromList {
                try await processShoppingListItems()
            }

            if let recordId = purchaseRecordId {
                print("🛒 Checkout: Complete! Purchase record: \(recordId)")
            } else {
                print("🛒 Checkout: Complete!")
            }

            await MainActor.run {
                shoppingModeState.clearBasket()
                shoppingModeState.disableShoppingMode()
                dismiss()

                if addToInventory {
                    NotificationCenter.default.post(name: .inventoryItemAdded, object: nil)
                }

                onComplete()
            }
        } catch {
            print("❌ Checkout error: \(error)")
            await MainActor.run {
                checkoutErrorMessage = "Checkout failed: \(error.localizedDescription)"
                showCheckoutError = true
            }
        }
    }

    private func createPurchaseRecord(with purchaseService: PurchaseRecordService) async throws -> UUID {
        print("🛒 Checkout: Creating purchase record...")

        let subtotalDecimal = Decimal(string: subtotal.isEmpty ? "0" : subtotal)
        let taxDecimal = Decimal(string: tax.isEmpty ? "0" : tax)
        let shippingDecimal = Decimal(string: shipping.isEmpty ? "0" : shipping)

        let purchaseItems = basketItems.enumerated().map { index, item in
            let quantity = quantities[item.catalogItem.stable_id] ?? item.shoppingListItem.neededQuantity
            return PurchaseRecordItemModel(
                item_stable_id: item.catalogItem.stable_id,
                type: "rod",
                quantity: quantity,
                orderIndex: Int32(index)
            )
        }

        let purchaseRecord = PurchaseRecordModel(
            supplier: supplier.isEmpty ? "Unknown" : supplier,
            subtotal: subtotalDecimal,
            tax: taxDecimal,
            shipping: shippingDecimal,
            currency: currency,
            notes: notes.isEmpty ? nil : notes,
            items: purchaseItems
        )

        let createdRecord = try await purchaseService.createRecord(purchaseRecord)
        print("  ✓ Created purchase record: \(createdRecord.id)")
        return createdRecord.id
    }

    private func addItemsToInventory() async throws {
        print("🛒 Checkout: Adding \(basketItems.count) items to inventory...")
        for item in basketItems {
            let quantity = quantities[item.catalogItem.stable_id] ?? item.shoppingListItem.neededQuantity
            let itemKey = item.catalogItem.stable_id

            _ = try await inventoryTrackingService.addInventory(
                quantity: quantity,
                type: "rod",
                toItem: itemKey
            )
            print("  ✓ Added \(quantity) of \(itemKey)")
        }
    }

    private func processShoppingListItems() async throws {
        print("🛒 Checkout: Processing \(basketItems.count) items from shopping list...")
        for item in basketItems {
            let boughtQuantity = quantities[item.catalogItem.stable_id] ?? item.shoppingListItem.neededQuantity
            let neededQuantity = item.shoppingListItem.neededQuantity

            if boughtQuantity >= neededQuantity {
                try await shoppingListService.shoppingListRepository.deleteItem(
                    forItem: item.catalogItem.stable_id
                )
                print("  ✓ Removed \(item.catalogItem.stable_id) (bought \(boughtQuantity) of \(neededQuantity) needed)")
            } else {
                let remainingQuantity = neededQuantity - boughtQuantity
                try await shoppingListService.shoppingListRepository.updateNeededQuantity(
                    forItem: item.catalogItem.stable_id,
                    neededQuantity: remainingQuantity
                )
                print("  ✓ Updated \(item.catalogItem.stable_id) to \(remainingQuantity) remaining (bought \(boughtQuantity) of \(neededQuantity) needed)")
            }
        }
    }
}

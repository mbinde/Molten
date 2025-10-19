//
//  AddShoppingListItemView.swift
//  Flameworker
//
//  Created by Assistant on 10/18/25.
//

import SwiftUI

struct AddShoppingListItemView: View {
    @Environment(\.dismiss) private var dismiss

    let prefilledNaturalKey: String?
    private let shoppingListService: ShoppingListService
    private let catalogService: CatalogService

    init(prefilledNaturalKey: String? = nil,
         shoppingListService: ShoppingListService? = nil,
         catalogService: CatalogService? = nil) {
        self.prefilledNaturalKey = prefilledNaturalKey

        // Use provided services or create defaults with repository factory
        self.shoppingListService = shoppingListService ?? RepositoryFactory.createShoppingListService()
        self.catalogService = catalogService ?? RepositoryFactory.createCatalogService()
    }

    var body: some View {
        AddShoppingListFormView(
            prefilledNaturalKey: prefilledNaturalKey,
            shoppingListService: shoppingListService,
            catalogService: catalogService
        )
    }
}

struct AddShoppingListFormView: View {
    @Environment(\.dismiss) private var dismiss

    let prefilledNaturalKey: String?
    private let shoppingListService: ShoppingListService
    private let catalogService: CatalogService

    @State private var naturalKey: String = ""
    @State private var selectedGlassItem: GlassItemModel?
    @State private var searchText: String = ""
    @State private var quantity: String = ""
    @State private var store: String = ""
    @State private var selectedType: String = "rod"
    @State private var selectedSubtype: String? = nil
    @State private var selectedSubsubtype: String? = nil
    @State private var errorMessage = ""
    @State private var showingError = false

    @State private var glassItems: [GlassItemModel] = []
    @State private var isLoading = false

    init(prefilledNaturalKey: String? = nil,
         shoppingListService: ShoppingListService,
         catalogService: CatalogService) {
        self.prefilledNaturalKey = prefilledNaturalKey
        self.shoppingListService = shoppingListService
        self.catalogService = catalogService
    }

    var body: some View {
        NavigationStack {
            Form {
                // Shared glass item search/selection component
                GlassItemSearchSelector(
                    selectedGlassItem: $selectedGlassItem,
                    searchText: $searchText,
                    prefilledNaturalKey: prefilledNaturalKey,
                    glassItems: glassItems,
                    onSelect: { item in
                        selectGlassItem(item)
                    },
                    onClear: {
                        clearSelection()
                    }
                )

                shoppingListDetailsSection
            }
            .navigationTitle("Add to Shopping List")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                toolbarContent
            }
            .onAppear {
                setupInitialData()
            }
            .onChange(of: naturalKey) { _, newValue in
                lookupGlassItem(naturalKey: newValue)
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { showingError = false }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - View Sections

    private var shoppingListDetailsSection: some View {
        Section("Shopping List Details") {
            quantityField

            storeField

            typePickerView

            // Subtype picker (if type has subtypes)
            if !availableSubtypes.isEmpty {
                subtypePickerView
            }
        }
    }

    // MARK: - Sub-Views

    private var quantityField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Quantity")
                .font(.subheadline)
                .fontWeight(.medium)
            TextField("Enter quantity", text: $quantity)
                #if canImport(UIKit)
                .keyboardType(.decimalPad)
                #endif
                .textFieldStyle(.roundedBorder)
        }
    }

    private var storeField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Store (optional)")
                .font(.subheadline)
                .fontWeight(.medium)
            TextField("e.g., Frantz Art Glass", text: $store)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var typePickerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Type (optional)")
                .font(.subheadline)
                .fontWeight(.medium)
            Picker("Type", selection: $selectedType) {
                ForEach(commonInventoryTypes, id: \.self) { type in
                    Text(type.capitalized).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedType) { _, newValue in
                // Reset subtype when type changes
                selectedSubtype = nil
                selectedSubsubtype = nil
            }
        }
    }

    private var subtypePickerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Subtype (optional)")
                .font(.subheadline)
                .fontWeight(.medium)
            Picker("Subtype", selection: $selectedSubtype) {
                Text("None").tag(nil as String?)
                ForEach(availableSubtypes, id: \.self) { subtype in
                    Text(subtype.capitalized).tag(subtype as String?)
                }
            }
            .pickerStyle(.menu)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                KeyboardDismissal.hideKeyboard()
                dismiss()
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            Button("Add") {
                saveShoppingListItem()
            }
            .disabled(naturalKey.isEmpty || quantity.isEmpty)
        }
    }

    // MARK: - Computed Properties

    private var commonInventoryTypes: [String] {
        return InventoryModel.CommonType.allCommonTypes
    }

    private var availableSubtypes: [String] {
        return GlassItemTypeSystem.getSubtypes(for: selectedType)
    }

    // MARK: - Actions

    private func setupInitialData() {
        if let prefilledKey = prefilledNaturalKey {
            naturalKey = prefilledKey
        }

        Task {
            await loadGlassItems()
            if let prefilledKey = prefilledNaturalKey {
                lookupGlassItem(naturalKey: prefilledKey)
            }
        }
    }

    private func selectGlassItem(_ item: GlassItemModel) {
        selectedGlassItem = item
        naturalKey = item.natural_key
        searchText = ""
    }

    private func clearSelection() {
        selectedGlassItem = nil
        naturalKey = ""
        searchText = ""
    }

    private func lookupGlassItem(naturalKey: String) {
        selectedGlassItem = glassItems.first { $0.natural_key == naturalKey }
    }

    private func saveShoppingListItem() {
        Task {
            do {
                try await performSave()
            } catch {
                await showError(error.localizedDescription)
            }
        }
    }

    private func performSave() async throws {
        guard !naturalKey.isEmpty, !quantity.isEmpty else {
            await showError("Please fill in all required fields")
            return
        }

        guard let quantityValue = Double(quantity) else {
            await showError("Invalid quantity format")
            return
        }

        // Verify the glass item exists
        guard let glassItem = selectedGlassItem else {
            await showError("Please select a glass item")
            return
        }

        // Create shopping list item
        let newShoppingListItem = ItemShoppingModel(
            item_natural_key: glassItem.natural_key,
            quantity: quantityValue,
            store: store.isEmpty ? nil : store,
            type: selectedType,
            subtype: selectedSubtype,
            subsubtype: selectedSubsubtype
        )

        // Access repository through service
        _ = try await shoppingListService.shoppingListRepository.createItem(newShoppingListItem)

        await MainActor.run {
            postSuccessNotification(glassItem: glassItem, quantityValue: quantityValue)
            dismiss()
        }
    }

    private func postSuccessNotification(glassItem: GlassItemModel, quantityValue: Double) {
        let quantityText = String(format: "%.1f", quantityValue).replacingOccurrences(of: ".0", with: "")
        let message = "\(glassItem.name) (\(quantityText)) added to shopping list."

        NotificationCenter.default.post(
            name: .shoppingListItemAdded,
            object: nil,
            userInfo: ["message": message]
        )
    }

    @MainActor
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }

    private func loadGlassItems() async {
        isLoading = true

        // Use lightweight preloaded cache for instant search results
        glassItems = await CatalogSearchCache.loadItems(using: catalogService)

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        AddShoppingListItemView()
    }
}

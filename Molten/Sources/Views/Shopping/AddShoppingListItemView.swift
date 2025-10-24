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
    let shoppingListService: ShoppingListService
    let catalogService: CatalogService

    init(prefilledNaturalKey: String? = nil,
         shoppingListService: ShoppingListService,
         catalogService: CatalogService) {
        self.prefilledNaturalKey = prefilledNaturalKey
        self.shoppingListService = shoppingListService
        self.catalogService = catalogService
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

    @State private var stableId: String = ""
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
                // Only pass items if user is searching OR we have a prefilled key
                GlassItemSearchSelector(
                    selectedGlassItem: $selectedGlassItem,
                    searchText: $searchText,
                    prefilledNaturalKey: prefilledNaturalKey,
                    glassItems: (searchText.isEmpty && prefilledNaturalKey == nil) ? [] : glassItems,
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
            .onChange(of: stableId) { _, newValue in
                lookupGlassItem(stableId: newValue)
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
        LabeledDecimalField("Quantity", value: $quantity, placeholder: "Enter quantity")
    }

    private var storeField: some View {
        LabeledField("Store (optional)") {
            TextField("e.g., Frantz Art Glass", text: $store)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var typePickerView: some View {
        LabeledField("Type (optional)") {
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
        LabeledField("Subtype (optional)") {
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
            .disabled(stableId.isEmpty || quantity.isEmpty)
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
            stableId = prefilledKey
        }

        Task {
            await loadGlassItems()
            if let prefilledKey = prefilledNaturalKey {
                lookupGlassItem(stableId: prefilledKey)
            }
        }
    }

    private func selectGlassItem(_ item: GlassItemModel) {
        selectedGlassItem = item
        stableId = item.stable_id
        searchText = ""
    }

    private func clearSelection() {
        selectedGlassItem = nil
        stableId = ""
        searchText = ""
    }

    private func lookupGlassItem(stableId: String) {
        selectedGlassItem = glassItems.first { $0.stable_id == stableId }
    }

    private func saveShoppingListItem() {
        Task {
            do {
                try await performSave()
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    private func performSave() async throws {
        guard !stableId.isEmpty, !quantity.isEmpty else {
            showError("Please fill in all required fields")
            return
        }

        guard let quantityValue = Double(quantity) else {
            showError("Invalid quantity format")
            return
        }

        // Verify the glass item exists
        guard let glassItem = selectedGlassItem else {
            showError("Please select a glass item")
            return
        }

        // Create shopping list item
        let newShoppingListItem = ItemShoppingModel(
            item_stable_id: glassItem.stable_id,
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
        print("⏱️ [SEARCH] loadGlassItems() started, cache isLoaded=\(CatalogSearchCache.shared.isLoaded)")
        isLoading = true

        // CRITICAL: Trust the cache is loaded during FirstRunDataLoadingView
        // The cache is ALWAYS loaded during startup (see FirstRunDataLoadingView line 189)
        // If it's not loaded yet, we wait for it to finish loading (don't reload!)
        if CatalogSearchCache.shared.isLoaded {
            // Cache ready - instant access!
            glassItems = CatalogSearchCache.shared.items
            print("✅ [SEARCH] Using pre-loaded cache with \(glassItems.count) items")
        } else {
            // Cache still loading from FirstRunDataLoadingView, wait for it
            print("⏳ [SEARCH] Cache not ready, waiting for FirstRunDataLoadingView to finish...")
            await CatalogSearchCache.shared.loadIfNeeded(catalogService: catalogService)
            glassItems = CatalogSearchCache.shared.items
            print("✅ [SEARCH] Cache now ready with \(glassItems.count) items")
        }

        isLoading = false
    }
}

#Preview {
    let _ = RepositoryFactory.configureForTesting()
    NavigationStack {
        AddShoppingListItemView(
            shoppingListService: RepositoryFactory.createShoppingListService(),
            catalogService: RepositoryFactory.createCatalogService()
        )
    }
}

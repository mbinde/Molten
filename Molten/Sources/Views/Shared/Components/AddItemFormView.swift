//
//  AddItemFormView.swift
//  Molten
//
//  Unified sophisticated form for adding items to inventory or shopping list
//  Matches the advanced UX of the inventory form with inline pickers, dimensions, weight units
//

import SwiftUI

/// Configuration for the location/store field behavior
enum LocationFieldType {
    case inventory(storageLocationDefinitionRepository: StorageLocationDefinitionRepository)
    case shopping(shoppingListRepository: ShoppingListRepository, locationService: UnifiedLocationService)
}

/// Prefill data for edit mode
struct AddItemFormPrefill {
    let quantity: Double
    let type: String
    let subtype: String?
    let subsubtype: String?
    let locationOrStore: String?
}

/// Unified sophisticated form for adding items to inventory or shopping list
/// Matches the advanced inventory form UX with inline pickers, collapsible dimensions, weight units
struct AddItemFormView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let locationFieldType: LocationFieldType
    let showNotesField: Bool
    let catalogService: CatalogService
    let prefilledNaturalKey: String?
    let prefillData: AddItemFormPrefill?
    let onSave: (AddItemFormData) async throws -> Void

    @State private var selectedGlassItem: UnifiedCatalogItem?
    @State private var searchText: String = ""
    @State private var selectedType: String
    @State private var selectedSubtype: String?
    @State private var selectedSubsubtype: String?
    @State private var quantity: String
    @State private var locationOrStore: String
    @State private var dimensions: [String: String] = [:]
    @State private var dimensionUnits: [String: DimensionUnit] = [:]
    @State private var selectedWeightUnit: WeightUnit = .grams
    @State private var notes: String = ""
    @State private var errorMessage = ""
    @State private var showingError = false
    @State private var glassItems: [UnifiedCatalogItem] = []
    @State private var isLoading = false
    @State private var isDimensionsExpanded = false
    @State private var didApplyPrefill = false
    @StateObject private var terminologySettings = GlassTerminologySettings.shared

    init(
        title: String,
        locationFieldType: LocationFieldType,
        showNotesField: Bool = false,
        catalogService: CatalogService,
        prefilledNaturalKey: String? = nil,
        prefillData: AddItemFormPrefill? = nil,
        onSave: @escaping (AddItemFormData) async throws -> Void
    ) {
        self.title = title
        self.locationFieldType = locationFieldType
        self.showNotesField = showNotesField
        self.catalogService = catalogService
        self.prefilledNaturalKey = prefilledNaturalKey
        self.prefillData = prefillData
        self.onSave = onSave

        // Initialize state from prefill data or defaults
        if let prefill = prefillData {
            let qtyString = prefill.quantity.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", prefill.quantity)
                : String(format: "%.1f", prefill.quantity)
            self._quantity = State(initialValue: qtyString)
            self._selectedType = State(initialValue: prefill.type)
            self._selectedSubtype = State(initialValue: prefill.subtype)
            self._selectedSubsubtype = State(initialValue: prefill.subsubtype)
            self._locationOrStore = State(initialValue: prefill.locationOrStore ?? "")
        } else {
            self._quantity = State(initialValue: "")
            self._selectedType = State(initialValue: "rod")
            self._selectedSubtype = State(initialValue: nil)
            self._selectedSubsubtype = State(initialValue: nil)
            self._locationOrStore = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Glass item search/selection
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

                // Item details section
                Section("Details") {
                    // Sophisticated inline layout: quantity + type + subtype + subsubtype + weight unit
                    quantityTypeRow

                    // Dimensions (collapsible, with per-field unit pickers)
                    if !availableDimensionFields.isEmpty {
                        dimensionsSection
                    }

                    // Location or Store field
                    locationOrStoreField

                    // Notes (optional, for inventory)
                    if showNotesField {
                        notesField
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                toolbarContent
            }
            .onAppear {
                setupInitialData()
            }
            .onChange(of: selectedType) { _, newValue in
                // Reset subtype/dimensions when type changes
                selectedSubtype = nil
                selectedSubsubtype = nil
                dimensions = [:]
                dimensionUnits = [:]
            }
            .onChange(of: selectedSubtype) { _, _ in
                selectedSubsubtype = nil
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { showingError = false }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Sophisticated Inline Layout (matches inventory form)

    private var quantityTypeRow: some View {
        HStack(alignment: .center, spacing: 12) {
            // Quantity field - narrow (80pt)
            TextField("0", text: $quantity)
                #if canImport(UIKit)
                .keyboardType(.decimalPad)
                #endif
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)

            // Type picker (rod/frit/etc) - inline, no label
            Picker("", selection: $selectedType) {
                ForEach(visibleInventoryTypes, id: \.self) { type in
                    Text(terminologySettings.displayName(for: type)).tag(type)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()

            // Subtype picker (if type has subtypes) - inline, no label
            if !availableSubtypes.isEmpty {
                Picker("", selection: $selectedSubtype) {
                    Text("---").tag(nil as String?)
                    ForEach(availableSubtypes, id: \.self) { subtype in
                        Text(subtype.capitalized).tag(subtype as String?)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
            }

            // Subsubtype picker (if selected subtype has subsubtypes) - inline, no label
            if let selectedSubtype = selectedSubtype,
               !getSubsubtypes(for: selectedType, subtype: selectedSubtype).isEmpty {
                Picker("", selection: $selectedSubsubtype) {
                    Text("---").tag(nil as String?)
                    ForEach(getSubsubtypes(for: selectedType, subtype: selectedSubtype), id: \.self) { subsubtype in
                        Text(subsubtype.capitalized).tag(subsubtype as String?)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
            }

            Spacer(minLength: 0)

            // Weight unit picker (if type uses weight) - on the far right
            if isWeightBasedType {
                Picker("", selection: $selectedWeightUnit) {
                    ForEach(WeightUnit.allCases) { unit in
                        Text(unit.symbol).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Collapsible Dimensions Section (matches inventory form)

    private var dimensionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Collapsible header
            Button(action: {
                withAnimation {
                    isDimensionsExpanded.toggle()
                }
            }) {
                HStack {
                    Text("Dimensions (Optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: isDimensionsExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expandable content
            if isDimensionsExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(availableDimensionFields, id: \.name) { field in
                        dimensionFieldRow(for: field)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func dimensionFieldRow(for field: DimensionField) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Field name
                Text(field.displayName + (field.isRequired ? " *" : ""))
                    .font(.caption)
                    .foregroundColor(field.isRequired ? .red : .secondary)

                Spacer()

                // Unit picker for this field
                Picker("", selection: Binding(
                    get: { getDefaultDimensionUnit(for: field.name) },
                    set: { dimensionUnits[field.name] = $0 }
                )) {
                    ForEach(DimensionUnit.allCases) { unit in
                        Text(unit.symbol).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }

            // Value input
            DecimalInputField(
                placeholder: field.placeholder,
                value: Binding(
                    get: { dimensions[field.name] ?? "" },
                    set: { dimensions[field.name] = $0 }
                )
            )
        }
    }

    // MARK: - Other Fields

    @ViewBuilder
    private var locationOrStoreField: some View {
        switch locationFieldType {
        case .inventory(let storageLocationDefinitionRepository):
            LabeledField("Location (optional)") {
                LocationAutoCompleteField(
                    location: $locationOrStore,
                    storageLocationDefinitionRepository: storageLocationDefinitionRepository
                )
            }
        case .shopping(let shoppingListRepository, let locationService):
            LabeledField("Store (optional)") {
                StoreAutoCompleteField(
                    store: $locationOrStore,
                    shoppingListRepository: shoppingListRepository,
                    locationService: locationService
                )
            }
        }
    }

    private var notesField: some View {
        LabeledField("Notes (optional)") {
            TextField("Notes (optional)", text: $notes, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                KeyboardDismissal.hideKeyboard()
                dismiss()
            }
            .accessibilityIdentifier("add_item_form_cancel")
        }

        ToolbarItem(placement: .confirmationAction) {
            Button(prefillData != nil ? "Save" : "Add") {
                saveItem()
            }
            .disabled(!isFormValid)
            .accessibilityIdentifier("add_item_form_add")
        }
    }

    // MARK: - Computed Properties

    private var visibleInventoryTypes: [String] {
        GlassItemTypeSystem.allTypeNames
    }

    private var availableSubtypes: [String] {
        GlassItemTypeSystem.getSubtypes(for: selectedType)
    }

    private func getSubsubtypes(for type: String, subtype: String) -> [String] {
        GlassItemTypeSystem.getSubsubtypes(for: type, subtype: subtype)
    }

    private var availableDimensionFields: [DimensionField] {
        GlassItemTypeSystem.getDimensionFields(for: selectedType)
    }

    private var isWeightBasedType: Bool {
        switch selectedType.lowercased() {
        case "frit", "powder", "enamel", "flakes":
            return true
        default:
            return false
        }
    }

    private var isFormValid: Bool {
        guard selectedGlassItem != nil else { return false }
        guard !quantity.isEmpty, Double(quantity) != nil else { return false }
        return true
    }

    private func getDefaultDimensionUnit(for fieldName: String) -> DimensionUnit {
        return dimensionUnits[fieldName] ?? .inches
    }

    // MARK: - Actions

    private func setupInitialData() {
        // Apply prefill data once (for edit mode)
        if !didApplyPrefill, let prefill = prefillData {
            let qtyString = prefill.quantity.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", prefill.quantity)
                : String(format: "%.1f", prefill.quantity)
            quantity = qtyString
            selectedType = prefill.type
            selectedSubtype = prefill.subtype
            selectedSubsubtype = prefill.subsubtype
            locationOrStore = prefill.locationOrStore ?? ""
            didApplyPrefill = true
        }

        Task {
            await loadGlassItems()
            if let prefilledKey = prefilledNaturalKey {
                lookupGlassItem(stableId: prefilledKey)
            }
        }
    }

    private func selectGlassItem(_ item: UnifiedCatalogItem) {
        selectedGlassItem = item
    }

    private func clearSelection() {
        selectedGlassItem = nil
        searchText = ""
    }

    private func lookupGlassItem(stableId: String) {
        selectedGlassItem = glassItems.first { $0.stable_id == stableId }
    }

    private func saveItem() {
        Task {
            do {
                guard let glassItem = selectedGlassItem else {
                    showError("Please select an item")
                    return
                }

                guard let quantityValue = Double(quantity) else {
                    showError("Invalid quantity format")
                    return
                }

                let formData = AddItemFormData(
                    glassItem: glassItem,
                    type: selectedType,
                    subtype: selectedSubtype,
                    subsubtype: selectedSubsubtype,
                    quantity: quantityValue,
                    dimensions: dimensions,
                    dimensionUnits: dimensionUnits,
                    weightUnit: isWeightBasedType ? selectedWeightUnit : nil,
                    locationOrStore: locationOrStore.isEmpty ? nil : locationOrStore,
                    notes: notes.isEmpty ? nil : notes
                )

                try await onSave(formData)

                await MainActor.run {
                    dismiss()
                }
            } catch is ShoppingListLimitError {
                // Don't show error alert for limit errors - the upgrade prompt is shown instead
                // Just don't dismiss the form
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    @MainActor
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }

    private func loadGlassItems() async {
        isLoading = true

        // Use pre-loaded cache
        if CatalogSearchCache.shared.isLoaded {
            glassItems = CatalogSearchCache.shared.items
        } else {
            await CatalogSearchCache.shared.loadIfNeeded(catalogService: catalogService)
            glassItems = CatalogSearchCache.shared.items
        }

        isLoading = false
    }
}

/// Data structure for form submission
struct AddItemFormData {
    let glassItem: UnifiedCatalogItem
    let type: String
    let subtype: String?
    let subsubtype: String?
    let quantity: Double
    let dimensions: [String: String]
    let dimensionUnits: [String: DimensionUnit]
    let weightUnit: WeightUnit?
    let locationOrStore: String?
    let notes: String?
}

//
//  AddInventoryItemView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//  Updated for GlassItem architecture - 10/14/25
//

import SwiftUI
import Foundation

struct AddInventoryItemView: View {
    @Environment(\.dismiss) private var dismiss

    let prefilledNaturalKey: String?
    private let deps: AppDependencies

    init(prefilledNaturalKey: String? = nil, deps: AppDependencies = AppDependencies()) {
        self.prefilledNaturalKey = prefilledNaturalKey
        self.deps = deps
    }

    var body: some View {
        AddInventoryFormView(
            prefilledNaturalKey: prefilledNaturalKey,
            deps: deps
        )
    }
}

struct AddInventoryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(EntitlementService.self) private var entitlementService

    private let catalogService: CatalogService
    private let inventoryTrackingService: InventoryTrackingService
    private let inventoryRepository: InventoryRepository
    private let storageLocationDefinitionRepository: StorageLocationDefinitionRepository
    private let prefilledNaturalKey: String?
    @State private var viewModel: AddInventoryItemViewModel
    @State private var showingUpgradePrompt = false
    @State private var currentInventoryCount = 0
    @StateObject private var terminologySettings = GlassTerminologySettings.shared

    init(prefilledNaturalKey: String? = nil, deps: AppDependencies = AppDependencies()) {
        self.catalogService = deps.catalogService
        self.inventoryTrackingService = deps.inventoryTrackingService
        self.inventoryRepository = deps.inventoryRepository
        self.storageLocationDefinitionRepository = deps.storageLocationDefinitionRepository
        self.prefilledNaturalKey = prefilledNaturalKey
        self._viewModel = State(initialValue: AddInventoryItemViewModel(
            prefilledNaturalKey: prefilledNaturalKey,
            inventoryTrackingService: deps.inventoryTrackingService,
            catalogService: deps.catalogService,
            userNotesRepository: deps.userNotesRepository
        ))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Limit warning banner (shows at 75%+ usage for free tier)
                if let limit = entitlementService.getInventoryLimit() {
                    LimitWarningBanner(
                        currentCount: currentInventoryCount,
                        limit: limit,
                        featureName: "items",
                        onUpgradeTap: { showingUpgradePrompt = true }
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                }

                // Search field back inside Form for better layout
                GlassItemSearchSelector(
                    selectedGlassItem: $viewModel.selectedCatalogItem,
                    searchText: $viewModel.searchText,
                    prefilledNaturalKey: prefilledNaturalKey,
                    glassItems: viewModel.catalogItems,
                    onSelect: { item in
                        viewModel.selectCatalogItem(item)
                    },
                    onClear: {
                        viewModel.clearSelection()
                    }
                )
                .accessibilityIdentifier("inventory.add.searchSelector")

                inventoryDetailsSection
                additionalInfoSection
            }
            .navigationTitle("Add Inventory")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                toolbarContent
            }
            .onAppear {
                setupInitialData()
            }
            .onChange(of: viewModel.stableId) { _, newValue in
                viewModel.lookupCatalogItem(stableId: newValue)
            }
            .onChange(of: viewModel.selectedCatalogItem?.itemType) { _, newItemType in
                // When item type changes (e.g., selecting a coating vs glass), reset to appropriate default type
                if let itemType = newItemType {
                    if itemType == .coating {
                        viewModel.selectedType = CoatingItemTypeSystem.defaultType
                    } else {
                        viewModel.selectedType = GlassTerminologySettings.rodType
                    }
                    // Clear subtypes when switching item types
                    viewModel.selectedSubtype = nil
                    viewModel.selectedSubsubtype = nil
                }
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK") { viewModel.showingError = false }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $showingUpgradePrompt) {
                UpgradePromptView(
                    feature: "inventory",
                    currentCount: currentInventoryCount,
                    limit: entitlementService.getInventoryLimit() ?? 0
                )
            }
            .task {
                // Load current inventory count for limit banner
                // Use the same cache and hasInventory check as InventoryView for consistency
                let items = await CatalogDataCache.loadItems(using: catalogService)
                currentInventoryCount = items.filter { $0.hasInventory }.count
            }
        }
    }

    // MARK: - View Sections
    
    private var inventoryDetailsSection: some View {
        Section("Inventory Details") {
            quantityTypeRow

            // Dimension fields (if type has dimensions)
            if !availableDimensionFields.isEmpty {
                dimensionFieldsView
            }
        }
    }
    
    private var additionalInfoSection: some View {
        Section("Additional Info") {
            locationField
            notesField
        }
    }
    
    // MARK: - Sub-Views

    private var quantityTypeRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main row: Quantity + Type + Subtypes all on one line
            HStack(alignment: .center, spacing: 12) {
                // Quantity/Container field - use the appropriate binding based on mode
                // Note: Using Group with if/else to ensure binding updates correctly
                Group {
                    if viewModel.isWeightBasedType && viewModel.selectedContainerInputMode == .jars {
                        TextField("0", text: $viewModel.containerCount)
                            .accessibilityIdentifier("inventory.add.containerCountField")
                            .accessibilityLabel("Jar Count")
                    } else {
                        TextField("0", text: $viewModel.quantity)
                            .accessibilityIdentifier("inventory.add.quantityField")
                            .accessibilityLabel("Quantity")
                    }
                }
                #if canImport(UIKit)
                .keyboardType(.decimalPad)
                #endif
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)

                // Weight unit picker (g/oz) - right after quantity field for weight mode
                if viewModel.isWeightBasedType && viewModel.selectedContainerInputMode == .weight {
                    Picker("", selection: $viewModel.selectedWeightUnit) {
                        ForEach(WeightUnit.allCases) { unit in
                            Text(unit.symbol).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 80)
                    .accessibilityIdentifier("inventory.add.weightUnitPicker")
                    .accessibilityLabel("Weight Unit")
                }

                // Type picker (rod/frit/etc) - this IS the label, no separate unit text needed
                Picker("", selection: $viewModel.selectedType) {
                    ForEach(visibleInventoryTypes, id: \.self) { type in
                        Text(terminologySettings.displayName(for: type)).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
                .onChange(of: viewModel.selectedType) { _, newValue in
                    viewModel.didChangeType()
                }
                .accessibilityIdentifier("inventory.add.typePicker")
                .accessibilityLabel("Type")

                // Subtype picker (if type has subtypes) - inline, no label
                if !availableSubtypes.isEmpty {
                    Picker("", selection: $viewModel.selectedSubtype) {
                        Text("---").tag(nil as String?)
                        ForEach(availableSubtypes, id: \.self) { subtype in
                            Text(subtype.capitalized).tag(subtype as String?)
                        }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                    .onChange(of: viewModel.selectedSubtype) { _, newValue in
                        viewModel.didChangeSubtype()
                    }
                    .accessibilityIdentifier("inventory.add.subtypePicker")
                    .accessibilityLabel("Subtype")
                }

                // Subsubtype picker (if selected subtype has subsubtypes) - inline, no label
                if !availableSubsubtypes.isEmpty {
                    Picker("", selection: $viewModel.selectedSubsubtype) {
                        Text("---").tag(nil as String?)
                        ForEach(availableSubsubtypes, id: \.self) { subsubtype in
                            Text(subsubtype.capitalized).tag(subsubtype as String?)
                        }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                    .accessibilityIdentifier("inventory.add.subsubtypePicker")
                    .accessibilityLabel("Sub-subtype")
                }

                Spacer(minLength: 0)
            }

            // Second row: Jars/Weight toggle (only for weight-based types)
            if viewModel.isWeightBasedType {
                HStack(spacing: 12) {
                    Picker("", selection: $viewModel.selectedContainerInputMode) {
                        ForEach(ContainerInputMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                    .accessibilityIdentifier("inventory.add.containerInputModePicker")
                    .accessibilityLabel("Input Mode")

                    // Show the "other" value if entered (for context)
                    otherValueIndicator
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Shows the value entered in the other mode (e.g., if in Jars mode, shows weight if entered)
    @ViewBuilder
    private var otherValueIndicator: some View {
        if viewModel.selectedContainerInputMode == .jars {
            // Currently in Jars mode - show weight if entered
            if let weight = viewModel.parsedQuantity {
                let displayWeight = viewModel.selectedWeightUnit == .ounces
                    ? WeightUnit.grams.convert(weight, to: .ounces)
                    : weight
                let unit = viewModel.selectedWeightUnit.symbol
                Text("(\(String(format: "%.1f", displayWeight))\(unit))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } else {
            // Currently in Weight mode - show jars if entered
            if let jars = viewModel.parsedContainerCount {
                let jarLabel = jars == 1 ? "jar" : "jars"
                Text("(\(String(format: "%.1f", jars).replacingOccurrences(of: ".0", with: "")) \(jarLabel))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var subtypePickerView: some View {
        LabeledField("Subtype (Optional)") {
            Picker("Subtype", selection: $viewModel.selectedSubtype) {
                Text("---").tag(nil as String?)
                ForEach(availableSubtypes, id: \.self) { subtype in
                    Text(subtype.capitalized).tag(subtype as String?)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: viewModel.selectedSubtype) { _, newValue in
                viewModel.didChangeSubtype()
            }
            .accessibilityIdentifier("inventory.add.subtypePicker")
        }
    }

    private var subsubtypePickerView: some View {
        LabeledField("Sub-subtype (Optional)") {
            Picker("Sub-subtype", selection: $viewModel.selectedSubsubtype) {
                Text("---").tag(nil as String?)
                ForEach(availableSubsubtypes, id: \.self) { subsubtype in
                    Text(subsubtype.capitalized).tag(subsubtype as String?)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("inventory.add.subsubtypePicker")
        }
    }

    private var dimensionFieldsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Collapsible header
            Button(action: {
                withAnimation {
                    viewModel.isDimensionsExpanded.toggle()
                }
            }) {
                HStack {
                    Text("Dimensions (Optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: viewModel.isDimensionsExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expandable content
            if viewModel.isDimensionsExpanded {
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
                    get: { viewModel.getDefaultDimensionUnit(for: field.name) },
                    set: { viewModel.dimensionUnits[field.name] = $0 }
                )) {
                    ForEach(DimensionUnit.allCases) { unit in
                        Text(unit.symbol).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
                .accessibilityIdentifier("inventory.add.dimensionUnitPicker.\(field.name)")
                .accessibilityLabel("\(field.displayName) Unit")
            }

            // Value input
            DecimalInputField(
                placeholder: field.placeholder,
                value: Binding(
                    get: { viewModel.dimensions[field.name] ?? "" },
                    set: { viewModel.dimensions[field.name] = $0 }
                )
            )
            .accessibilityIdentifier("inventory.add.dimensionField.\(field.name)")
        }
    }
    
    private var locationField: some View {
        LabeledField("Location (optional)") {
            LocationAutoCompleteField(
                location: $viewModel.location,
                storageLocationDefinitionRepository: storageLocationDefinitionRepository
            )
            .accessibilityIdentifier("inventory.add.locationField")
        }
    }

    private var notesField: some View {
        LabeledField("Notes (optional)") {
            TextField("Notes (optional)", text: $viewModel.notes, axis: .vertical)
                .lineLimit(3...6)
                .accessibilityIdentifier("inventory.add.notesField")
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                KeyboardDismissal.hideKeyboard()
                dismiss()
            }
            .accessibilityIdentifier("inventory.add.cancelButton")
        }

        ToolbarItem(placement: .confirmationAction) {
            Button("Add") {
                saveInventoryItem()
            }
            .disabled(!viewModel.isValid)
            .accessibilityIdentifier("inventory.add.saveButton")
        }
    }
    
    // MARK: - Computed Properties

    /// Check if the selected item is a coating (vs glass)
    private var isCoatingItem: Bool {
        return viewModel.selectedCatalogItem?.itemType == .coating
    }

    /// Get all available inventory types based on item type
    private var visibleInventoryTypes: [String] {
        if isCoatingItem {
            return CoatingItemTypeSystem.allTypeNames
        }
        return GlassItemTypeSystem.allTypeNames
    }

    /// Get the default inventory type based on item type
    private var defaultInventoryType: String {
        if isCoatingItem {
            return CoatingItemTypeSystem.defaultType  // "powder" for coatings
        }
        return GlassTerminologySettings.rodType  // "rod" for glass
    }

    private var availableSubtypes: [String] {
        if isCoatingItem {
            return []  // Coatings don't have subtypes
        }
        return GlassItemTypeSystem.getSubtypes(for: viewModel.selectedType)
    }

    private var availableSubsubtypes: [String] {
        if isCoatingItem {
            return []  // Coatings don't have subsubtypes
        }
        guard let subtype = viewModel.selectedSubtype else { return [] }
        return GlassItemTypeSystem.getSubsubtypes(for: viewModel.selectedType, subtype: subtype)
    }

    private var availableDimensionFields: [DimensionField] {
        if isCoatingItem {
            return []  // Coatings don't have dimensions
        }
        return GlassItemTypeSystem.getDimensionFields(for: viewModel.selectedType)
    }

    // MARK: - Actions

    private func setupInitialData() {
        // Set default inventory type based on terminology settings
        if viewModel.selectedType.isEmpty {
            viewModel.selectedType = defaultInventoryType
        }

        Task {
            await viewModel.loadCatalogItems()
        }
    }
    
    private func saveInventoryItem() {
        Task {
            // Limit check now happens BEFORE showing this form, so just save directly
            let success = await viewModel.save()
            if success, let catalogItem = viewModel.selectedCatalogItem {
                // Post notification first (for views that aren't currently visible)
                postSuccessNotification(catalogItem: catalogItem)
                // Then dismiss (triggers onDismiss callback in parent view)
                dismiss()
            }
        }
    }

    private func postSuccessNotification(catalogItem: UnifiedCatalogItem) {
        let message: String
        if let jarCount = viewModel.parsedContainerCount {
            let jarText = String(format: "%.1f", jarCount).replacingOccurrences(of: ".0", with: "")
            let jarLabel = jarCount == 1 ? "jar" : "jars"
            message = "\(catalogItem.name) (\(jarText) \(jarLabel) of \(viewModel.selectedType)) added to inventory."
        } else if let quantityValue = viewModel.parsedQuantity {
            let quantityText = String(format: "%.1f", quantityValue).replacingOccurrences(of: ".0", with: "")
            message = "\(catalogItem.name) (\(quantityText) \(viewModel.selectedType)) added to inventory."
        } else {
            message = "\(catalogItem.name) added to inventory."
        }

        NotificationCenter.default.post(
            name: .inventoryItemAdded,
            object: nil,
            userInfo: ["message": message]
        )
    }
}

// MARK: - Helper Views

struct TypeDisplayView: View {
    let type: String
    
    var body: some View {
        Text(type.capitalized)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(8)
    }
}

// MARK: - Extensions

// Note: inventoryItemAdded notification is defined in MainTabView.swift

// MARK: - Preview

#Preview {
    NavigationStack {
        AddInventoryItemView(deps: AppDependencies(persistenceController: .createTestController()))
    }
}

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

    private let catalogService: CatalogService
    private let inventoryTrackingService: InventoryTrackingService
    private let prefilledNaturalKey: String?
    @State private var viewModel: AddInventoryItemViewModel
    @StateObject private var terminologySettings = GlassTerminologySettings.shared

    init(prefilledNaturalKey: String? = nil, deps: AppDependencies = AppDependencies()) {
        self.catalogService = deps.catalogService
        self.inventoryTrackingService = deps.inventoryTrackingService
        self.prefilledNaturalKey = prefilledNaturalKey
        self._viewModel = State(initialValue: AddInventoryItemViewModel(
            prefilledNaturalKey: prefilledNaturalKey,
            inventoryTrackingService: deps.inventoryTrackingService,
            catalogService: deps.catalogService
        ))
    }
    
    var body: some View {
        NavigationStack {
            Form {
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
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK") { viewModel.showingError = false }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - View Sections
    
    private var inventoryDetailsSection: some View {
        Section("Inventory Details") {
            quantityTypeRow

            // Subtype picker (if type has subtypes)
            if !availableSubtypes.isEmpty {
                subtypePickerView
            }

            // Subsubtype picker (if selected subtype has subsubtypes)
            if !availableSubsubtypes.isEmpty {
                subsubtypePickerView
            }

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
        VStack(alignment: .leading, spacing: 4) {
            Text("Quantity")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack(spacing: 12) {
                // Quantity field - narrow (80pt)
                TextField("0", text: $viewModel.quantity)
                    #if canImport(UIKit)
                    .keyboardType(.decimalPad)
                    #endif
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .accessibilityIdentifier("inventory.add.quantityField")
                    .accessibilityLabel("Quantity")

                // Unit label (non-editable, based on type)
                Text(viewModel.quantityUnitLabel)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(minWidth: 60, alignment: .leading)

                // Type picker (no label, clear from context)
                Picker("", selection: $viewModel.selectedType) {
                    ForEach(visibleInventoryTypes, id: \.self) { type in
                        Text(terminologySettings.displayName(for: type)).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: viewModel.selectedType) { _, newValue in
                    viewModel.didChangeType()
                }
                .accessibilityIdentifier("inventory.add.typePicker")
                .accessibilityLabel("Type")

                Spacer()
            }
        }
    }

    private var subtypePickerView: some View {
        LabeledField("Subtype (Optional)") {
            Picker("Subtype", selection: $viewModel.selectedSubtype) {
                Text("None").tag(nil as String?)
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
                Text("None").tag(nil as String?)
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
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(field.displayName) (\(field.unit))\(field.isRequired ? " *" : "")")
                                .font(.caption)
                                .foregroundColor(field.isRequired ? .red : .secondary)

                            DecimalInputField(
                                placeholder: field.placeholder,
                                value: Binding(
                                    get: { viewModel.dimensions[field.name] ?? "" },
                                    set: { viewModel.dimensions[field.name] = $0 }
                                )
                            )
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }
    
    private var locationField: some View {
        LabeledField("Location (optional)") {
            TextField("Location (optional)", text: $viewModel.location)
                .textFieldStyle(.roundedBorder)
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
            Button("Save") {
                saveInventoryItem()
            }
            .disabled(!viewModel.isValid)
            .accessibilityIdentifier("inventory.add.saveButton")
        }
    }
    
    // MARK: - Computed Properties

    /// Get all available inventory types
    private var visibleInventoryTypes: [String] {
        return GlassItemTypeSystem.allTypeNames
    }

    /// Get the default inventory type (rod)
    private var defaultInventoryType: String {
        return GlassTerminologySettings.rodType  // "rod" as default
    }

    private var availableSubtypes: [String] {
        return GlassItemTypeSystem.getSubtypes(for: viewModel.selectedType)
    }

    private var availableSubsubtypes: [String] {
        guard let subtype = viewModel.selectedSubtype else { return [] }
        return GlassItemTypeSystem.getSubsubtypes(for: viewModel.selectedType, subtype: subtype)
    }

    private var availableDimensionFields: [DimensionField] {
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
            if success, let catalogItem = viewModel.selectedCatalogItem, let quantityValue = viewModel.parsedQuantity {
                // Post notification first (for views that aren't currently visible)
                postSuccessNotification(catalogItem: catalogItem, quantityValue: quantityValue)
                // Then dismiss (triggers onDismiss callback in parent view)
                dismiss()
            }
        }
    }

    private func postSuccessNotification(catalogItem: UnifiedCatalogItem, quantityValue: Double) {
        let quantityText = String(format: "%.1f", quantityValue).replacingOccurrences(of: ".0", with: "")
        let message = "\(catalogItem.name) (\(quantityText) \(viewModel.selectedType)) added to inventory."

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

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
    private let inventoryTrackingService: InventoryTrackingService
    private let catalogService: CatalogService
    
    init(prefilledNaturalKey: String? = nil, 
         inventoryTrackingService: InventoryTrackingService? = nil,
         catalogService: CatalogService? = nil) {
        self.prefilledNaturalKey = prefilledNaturalKey
        
        // Use provided services or create defaults with repository factory
        self.inventoryTrackingService = inventoryTrackingService ?? RepositoryFactory.createInventoryTrackingService()
        self.catalogService = catalogService ?? RepositoryFactory.createCatalogService()
    }
    
    var body: some View {
        AddInventoryFormView(
            prefilledNaturalKey: prefilledNaturalKey,
            inventoryTrackingService: inventoryTrackingService,
            catalogService: catalogService
        )
    }
}

struct AddInventoryFormView: View {
    @Environment(\.dismiss) private var dismiss
    
    let prefilledNaturalKey: String?
    private let inventoryTrackingService: InventoryTrackingService
    private let catalogService: CatalogService
    
    @State private var naturalKey: String = ""
    @State private var selectedGlassItem: GlassItemModel?
    @State private var searchText: String = ""
    @State private var quantity: String = ""
    @State private var selectedType: String = "rod"
    @State private var selectedSubtype: String? = nil
    @State private var selectedSubsubtype: String? = nil
    @State private var dimensions: [String: String] = [:] // String values for text fields
    @State private var notes: String = ""
    @State private var location: String = ""
    @State private var errorMessage = ""
    @State private var showingError = false
    
    @State private var glassItems: [CompleteInventoryItemModel] = []
    @State private var isLoading = false
    
    init(prefilledNaturalKey: String? = nil,
         inventoryTrackingService: InventoryTrackingService,
         catalogService: CatalogService) {
        self.prefilledNaturalKey = prefilledNaturalKey
        self.inventoryTrackingService = inventoryTrackingService
        self.catalogService = catalogService
    }
    
    var body: some View {
        NavigationStack {
            Form {
                glassItemSection
                inventoryDetailsSection
                additionalInfoSection
            }
            .navigationTitle("Add Inventory")
            .navigationBarTitleDisplayMode(.large)
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
    
    private var glassItemSection: some View {
        Section("Glass Item") {
            VStack(alignment: .leading, spacing: 8) {
                if prefilledNaturalKey == nil {
                    searchField
                }
                
                if let glassItem = selectedGlassItem {
                    selectedItemView(glassItem)
                } else if !searchText.isEmpty && prefilledNaturalKey == nil {
                    searchResultsView
                } else if prefilledNaturalKey != nil {
                    notFoundView
                } else {
                    instructionView
                }
            }
        }
    }
    
    private var inventoryDetailsSection: some View {
        Section("Inventory Details") {
            quantityAndTypeView
            typePickerView

            // Subtype picker (if type has subtypes)
            if !availableSubtypes.isEmpty {
                subtypePickerView
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
    
    private var searchField: some View {
        TextField("Search glass items...", text: $searchText)
            .textFieldStyle(.roundedBorder)
            .disabled(selectedGlassItem != nil)
    }
    
    private func selectedItemView(_ glassItem: GlassItemModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            selectedItemHeader
            GlassItemCard(item: glassItem, variant: .compact)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(selectedItemBackgroundColor)
        .overlay(selectedItemBorder)
        .cornerRadius(8)
    }
    
    private var selectedItemHeader: some View {
        HStack {
            Text(prefilledNaturalKey != nil ? "Adding inventory for:" : "Selected:")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            if prefilledNaturalKey == nil {
                clearButton
            }
        }
    }
    
    private var clearButton: some View {
        Button("Clear") {
            clearSelection()
        }
        .font(.caption)
        .foregroundColor(.blue)
    }
    
    private var selectedItemBackgroundColor: Color {
        let baseColor = prefilledNaturalKey != nil ? Color.blue : Color.green
        return baseColor.opacity(0.1)
    }
    
    private var selectedItemBorder: some View {
        let borderColor = prefilledNaturalKey != nil ? Color.blue : Color.green
        return RoundedRectangle(cornerRadius: 8)
            .stroke(borderColor, lineWidth: 1)
    }
    
    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(filteredGlassItems.prefix(10), id: \.id) { item in
                    SearchResultRow(item: item) {
                        selectGlassItem(item.glassItem)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(maxHeight: 300)
    }
    
    private var notFoundView: some View {
        Group {
            if selectedGlassItem == nil && prefilledNaturalKey != nil {
                NotFoundCard(naturalKey: prefilledNaturalKey!)
            } else {
                EmptyView()
            }
        }
    }
    
    private var instructionView: some View {
        Group {
            if selectedGlassItem == nil && prefilledNaturalKey == nil {
                Text("Search above to find a glass item")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                EmptyView()
            }
        }
    }
    
    private var quantityAndTypeView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Quantity")
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("Enter quantity", text: $quantity)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Type")
                    .font(.subheadline)
                    .fontWeight(.medium)
                TypeDisplayView(type: selectedType)
            }
        }
    }
    
    private var typePickerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Inventory Type")
                .font(.subheadline)
                .fontWeight(.medium)
            Picker("Type", selection: $selectedType) {
                ForEach(commonInventoryTypes, id: \.self) { type in
                    Text(type.capitalized).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedType) { _, newValue in
                // Reset subtype and dimensions when type changes
                selectedSubtype = nil
                selectedSubsubtype = nil
                dimensions = [:]
            }
        }
    }

    private var subtypePickerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Subtype (Optional)")
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

    private var dimensionFieldsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dimensions (Optional)")
                .font(.subheadline)
                .fontWeight(.medium)

            ForEach(availableDimensionFields, id: \.name) { field in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(field.displayName) (\(field.unit))\(field.isRequired ? " *" : "")")
                        .font(.caption)
                        .foregroundColor(field.isRequired ? .red : .secondary)

                    TextField(field.placeholder, text: Binding(
                        get: { dimensions[field.name] ?? "" },
                        set: { dimensions[field.name] = $0 }
                    ))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                }
            }
        }
    }
    
    private var locationField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location (optional)")
                .font(.subheadline)
                .fontWeight(.medium)
            
            TextField("Location (optional)", text: $location)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private var notesField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes (optional)")
                .font(.subheadline)
                .fontWeight(.medium)
            
            TextField("Notes (optional)", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                dismiss()
            }
        }
        
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                saveInventoryItem()
            }
            .disabled(naturalKey.isEmpty || quantity.isEmpty)
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredGlassItems: [CompleteInventoryItemModel] {
        if searchText.isEmpty {
            return glassItems
        } else {
            return glassItems.filter { item in
                let searchLower = searchText.lowercased()
                return item.glassItem.name.lowercased().contains(searchLower) ||
                       item.glassItem.natural_key.lowercased().contains(searchLower) ||
                       item.glassItem.manufacturer.lowercased().contains(searchLower)
            }
        }
    }
    
    private var commonInventoryTypes: [String] {
        return InventoryModel.CommonType.allCommonTypes
    }

    private var availableSubtypes: [String] {
        return GlassItemTypeSystem.getSubtypes(for: selectedType)
    }

    private var availableDimensionFields: [DimensionField] {
        return GlassItemTypeSystem.getDimensionFields(for: selectedType)
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
    }
    
    private func clearSelection() {
        selectedGlassItem = nil
        naturalKey = ""
        searchText = ""
    }
    
    private func lookupGlassItem(naturalKey: String) {
        selectedGlassItem = glassItems.first { $0.glassItem.natural_key == naturalKey }?.glassItem
    }
    
    private func saveInventoryItem() {
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
        
        // Parse dimensions from string values to Double
        var parsedDimensions: [String: Double]? = nil
        if !dimensions.isEmpty {
            var dimensionValues: [String: Double] = [:]
            for (key, value) in dimensions where !value.isEmpty {
                if let doubleValue = Double(value) {
                    dimensionValues[key] = doubleValue
                }
            }
            if !dimensionValues.isEmpty {
                parsedDimensions = dimensionValues
            }
        }

        // Create inventory record with subtype and dimensions
        let newInventory = InventoryModel(
            item_natural_key: glassItem.natural_key,
            type: selectedType,
            subtype: selectedSubtype,
            subsubtype: selectedSubsubtype,
            dimensions: parsedDimensions,
            quantity: quantityValue
        )

        // Add location distribution if provided
        var locationDistribution: [(location: String, quantity: Double)] = []
        if !location.isEmpty {
            locationDistribution.append((location: location, quantity: quantityValue))
        }

        _ = try await inventoryTrackingService.addInventory(
            quantity: quantityValue,
            type: selectedType,
            toItem: glassItem.natural_key,
            distributedTo: locationDistribution
        )
        
        await MainActor.run {
            postSuccessNotification(glassItem: glassItem, quantityValue: quantityValue)
            dismiss()
        }
    }
    
    private func postSuccessNotification(glassItem: GlassItemModel, quantityValue: Double) {
        let quantityText = String(format: "%.1f", quantityValue).replacingOccurrences(of: ".0", with: "")
        let message = "\(glassItem.name) (\(quantityText) \(selectedType)) added to inventory."
        
        NotificationCenter.default.post(
            name: .inventoryItemAdded,
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
        do {
            glassItems = try await catalogService.getAllGlassItems()
        } catch {
            glassItems = []
        }
        isLoading = false
    }
}

// MARK: - Helper Views

struct SearchResultRow: View {
    let item: CompleteInventoryItemModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            GlassItemCard(item: item.glassItem, variant: .compact)
        }
        .buttonStyle(.plain)
    }
}

struct NotFoundCard: View {
    let naturalKey: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Glass item not found")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Natural Key: \(naturalKey)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange, lineWidth: 1)
        )
        .cornerRadius(8)
    }
}

struct TypeDisplayView: View {
    let type: String
    
    var body: some View {
        Text(type.capitalized)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
    }
}

// MARK: - Extensions

// Note: inventoryItemAdded notification is defined in MainTabView.swift

// MARK: - Preview

#Preview {
    NavigationStack {
        AddInventoryItemView()
    }
}

//
//  AddInventoryItemView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

// ✅ COMPLETELY REWRITTEN FOR REPOSITORY PATTERN (October 2025)
//
// This view has been completely rewritten to use the repository pattern with
// clean, simple expressions that compile efficiently.
//
// CHANGES MADE:
// - Clean repository pattern implementation
// - Simple, compiler-friendly view expressions
// - Proper separation of concerns
// - Efficient async/await patterns

import SwiftUI
import Foundation

struct AddInventoryItemView: View {
    @Environment(\.dismiss) private var dismiss
    
    let prefilledCatalogCode: String?
    private let inventoryService: InventoryService
    private let catalogService: CatalogService
    
    init(prefilledCatalogCode: String? = nil, 
         inventoryService: InventoryService? = nil,
         catalogService: CatalogService? = nil) {
        self.prefilledCatalogCode = prefilledCatalogCode
        
        // Use provided services or create defaults with mock repositories
        if let invService = inventoryService {
            self.inventoryService = invService
        } else {
            let mockInvRepository = MockInventoryRepository()
            self.inventoryService = InventoryService(repository: mockInvRepository)
        }
        
        if let catService = catalogService {
            self.catalogService = catService
        } else {
            let mockCatRepository = MockCatalogRepository()
            self.catalogService = CatalogService(repository: mockCatRepository)
        }
    }
    
    var body: some View {
        AddInventoryFormView(
            prefilledCatalogCode: prefilledCatalogCode,
            inventoryService: inventoryService,
            catalogService: catalogService
        )
    }
}

struct AddInventoryFormView: View {
    @Environment(\.dismiss) private var dismiss
    
    let prefilledCatalogCode: String?
    private let inventoryService: InventoryService
    private let catalogService: CatalogService
    
    @State private var catalogCode: String = ""
    @State private var catalogItem: CatalogItemModel?
    @State private var searchText: String = ""
    @State private var quantity: String = ""
    @State private var selectedType: InventoryItemType = .inventory
    @State private var notes: String = ""
    @State private var location: String = ""
    @State private var errorMessage = ""
    @State private var showingError = false
    
    @State private var catalogItems: [CatalogItemModel] = []
    @AppStorage("selectedInventoryFilters") private var selectedInventoryFiltersData: Data = Data()
    
    init(prefilledCatalogCode: String? = nil,
         inventoryService: InventoryService,
         catalogService: CatalogService) {
        self.prefilledCatalogCode = prefilledCatalogCode
        self.inventoryService = inventoryService
        self.catalogService = catalogService
    }
    
    var body: some View {
        Form {
            catalogItemSection
            inventoryDetailsSection
            additionalInfoSection
        }
        .navigationTitle("Add Inventory Item")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            toolbarContent
        }
        .onAppear {
            setupInitialData()
        }
        .onChange(of: catalogCode) { _, newValue in
            lookupCatalogItem(code: newValue)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { showingError = false }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - View Sections
    
    private var catalogItemSection: some View {
        Section("Catalog Item") {
            VStack(alignment: .leading, spacing: 8) {
                if prefilledCatalogCode == nil {
                    searchField
                }
                
                if let catalogItem = catalogItem {
                    selectedItemView(catalogItem)
                } else if !searchText.isEmpty && prefilledCatalogCode == nil {
                    searchResultsView
                } else if prefilledCatalogCode != nil {
                    notFoundView
                } else {
                    instructionView
                }
            }
        }
    }
    
    private var inventoryDetailsSection: some View {
        Section("Inventory Details") {
            quantityAndUnitsView
            typePickerView
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
        TextField("Search catalog items...", text: $searchText)
            .textFieldStyle(.roundedBorder)
            .disabled(catalogItem != nil)
    }
    
    private func selectedItemView(_ item: CatalogItemModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            selectedItemHeader
            CatalogItemCard(item: item)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(selectedItemBackgroundColor)
        .overlay(selectedItemBorder)
        .cornerRadius(8)
    }
    
    private var selectedItemHeader: some View {
        HStack {
            Text(prefilledCatalogCode != nil ? "Adding inventory for:" : "Selected:")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            if prefilledCatalogCode == nil {
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
        let baseColor = prefilledCatalogCode != nil ? Color.blue : Color.green
        return baseColor.opacity(0.1)
    }
    
    private var selectedItemBorder: some View {
        let borderColor = prefilledCatalogCode != nil ? Color.blue : Color.green
        return RoundedRectangle(cornerRadius: 8)
            .stroke(borderColor, lineWidth: 1)
    }
    
    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(filteredCatalogItems.prefix(10), id: \.id) { item in
                    SearchResultRow(item: item) {
                        selectCatalogItem(item)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(maxHeight: 300)
    }
    
    private var notFoundView: some View {
        Group {
            if catalogItem == nil && prefilledCatalogCode != nil {
                NotFoundCard(code: prefilledCatalogCode!)
            } else {
                EmptyView()
            }
        }
    }
    
    private var instructionView: some View {
        Group {
            if catalogItem == nil && prefilledCatalogCode == nil {
                Text("Search above to find a catalog item")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                EmptyView()
            }
        }
    }
    
    private var quantityAndUnitsView: some View {
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
                Text("Units")
                    .font(.subheadline)
                    .fontWeight(.medium)
                UnitsDisplayView(units: displayUnits)
            }
        }
    }
    
    private var typePickerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Add to my")
                .font(.subheadline)
                .fontWeight(.medium)
            Picker("Type", selection: $selectedType) {
                ForEach(InventoryItemType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
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
            .disabled(catalogCode.isEmpty || quantity.isEmpty)
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredCatalogItems: [CatalogItemModel] {
        if searchText.isEmpty {
            return catalogItems
        } else {
            return catalogItems.filter { item in
                let searchLower = searchText.lowercased()
                return item.name.lowercased().contains(searchLower) ||
                       item.code.lowercased().contains(searchLower)
            }
        }
    }
    
    private var displayUnits: String {
        guard let catalogItem = catalogItem else {
            return CatalogUnits.rods.displayName
        }
        
        if catalogItem.units == 0 {
            return CatalogUnits.rods.displayName
        }
        
        let units = CatalogUnits(rawValue: catalogItem.units) ?? .rods
        return units.displayName
    }
    
    // MARK: - Actions
    
    private func setupInitialData() {
        if let prefilledCode = prefilledCatalogCode {
            catalogCode = prefilledCode
        }
        
        Task {
            await loadCatalogItems()
            if let prefilledCode = prefilledCatalogCode {
                lookupCatalogItem(code: prefilledCode)
            }
        }
    }
    
    private func selectCatalogItem(_ item: CatalogItemModel) {
        catalogItem = item
        catalogCode = item.code
    }
    
    private func clearSelection() {
        catalogItem = nil
        catalogCode = ""
        searchText = ""
    }
    
    private func lookupCatalogItem(code: String) {
        catalogItem = catalogItems.first { $0.code == code }
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
        guard !catalogCode.isEmpty, !quantity.isEmpty else {
            await showError("Please fill in all required fields")
            return
        }
        
        guard let quantityValue = Double(quantity) else {
            await showError("Invalid quantity format")
            return
        }
        
        let newItem = InventoryItemModel(
            catalogCode: catalogCode,
            quantity: quantityValue,
            type: selectedType,
            notes: notes.isEmpty ? nil : notes,
            location: location.isEmpty ? nil : location
        )
        
        _ = try await inventoryService.createItem(newItem)
        
        await MainActor.run {
            postSuccessNotification(quantityValue: quantityValue)
            dismiss()
        }
    }
    
    private func postSuccessNotification(quantityValue: Double) {
        let itemName = catalogItem?.name ?? catalogCode
        let quantityText = String(format: "%.1f", quantityValue).replacingOccurrences(of: ".0", with: "")
        let message = "\(itemName) (\(quantityText) items) added to \(selectedType.displayName.lowercased()) inventory."
        
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
    
    private func loadCatalogItems() async {
        do {
            catalogItems = try await catalogService.getAllItems()
        } catch {
            catalogItems = []
        }
    }
}

// MARK: - Helper Views

struct CatalogItemCard: View {
    let item: CatalogItemModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            itemRow
            if !item.tags.isEmpty {
                TagsView(tags: item.tags)
            }
        }
    }
    
    private var itemRow: some View {
        HStack(spacing: 12) {
            productImage
            itemDetails
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var productImage: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(.systemGray5))
            .frame(width: 60, height: 60)
            .overlay(
                Image(systemName: "eyedropper")
                    .foregroundColor(.secondary)
            )
    }
    
    private var itemDetails: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.name)
                .font(.headline)
                .lineLimit(1)
            
            codeAndManufacturer
        }
    }
    
    private var codeAndManufacturer: some View {
        HStack {
            Text(item.code)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("•")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(item.manufacturer)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .lineLimit(1)
    }
}

struct SearchResultRow: View {
    let item: CatalogItemModel
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                searchImage
                searchItemDetails
                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color(.systemGray6).opacity(0.5))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
    
    private var searchImage: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(.systemGray5))
            .frame(width: 50, height: 50)
            .overlay(
                Image(systemName: "eyedropper")
                    .foregroundColor(.secondary)
                    .font(.system(size: 20))
            )
    }
    
    private var searchItemDetails: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            
            HStack {
                Text(item.code)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("•")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(item.manufacturer)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .lineLimit(1)
        }
    }
}

struct TagsView: View {
    let tags: [String]
    
    var body: some View {
        HStack {
            Text("Tags:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        TagChip(text: tag)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }
}

struct TagChip: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct NotFoundCard: View {
    let code: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Item not found in catalog")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Code: \(code)")
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

struct UnitsDisplayView: View {
    let units: String
    
    var body: some View {
        Text(units)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
    }
}

#Preview {
    NavigationStack {
        AddInventoryItemView()
    }
}

//
//  FormComponents.swift
//  Flameworker
//
//  Created by Assistant on 9/29/25.
//

import SwiftUI
import CoreData
import Combine
import Foundation

/// Reusable form components to eliminate duplication across forms

// MARK: - Inventory Form Sections

/// Reusable form section for inventory input (count, units, notes, price, date)
struct InventoryFormSection: View {
    @Binding var count: String
    @Binding var units: InventoryUnits
    @Binding var notes: String
    @Binding var price: String
    @Binding var dateAdded: Date
    
    var body: some View {
        Section {
            CountUnitsInputRow(count: $count, units: $units)
            
            NotesInputField(notes: $notes)
            
            PriceInputField(price: $price)
            
            DateAddedInputField(dateAdded: $dateAdded)
        }
    }
}

/// Reusable count, units, and type input row
struct CountUnitsTypeInputRow: View {
    @Binding var count: String
    @Binding var units: InventoryUnits
    @Binding var selectedType: InventoryItemType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Count", text: $count)
                    .keyboardType(.decimalPad)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Units")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Picker("Units", selection: $units) {
                    ForEach(InventoryUnits.allCases) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Type")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Type", selection: $selectedType) {
                    ForEach(InventoryItemType.allCases) { itemType in
                        HStack {
                            Image(systemName: itemType.systemImageName)
                                .foregroundColor(itemType.color)
                            Text(itemType.displayName)
                        }
                        .tag(itemType)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

/// Reusable count and units input row (without type)
struct CountUnitsInputRow: View {
    @Binding var count: String
    @Binding var units: InventoryUnits
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Amount", text: $count)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Picker("", selection: $units) {
                ForEach(InventoryUnits.allCases) { unit in
                    Text(unit.displayName).tag(unit)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 120)
        }
    }
}

/// Reusable notes input field with consistent styling
struct NotesInputField: View {
    @Binding var notes: String
    
    var body: some View {
        TextField("Notes", text: $notes, axis: .vertical)
            .lineLimit(2...4)
            .textInputAutocapitalization(.sentences)
    }
}

/// Reusable price input field
struct PriceInputField: View {
    @Binding var price: String
    
    var body: some View {
        HStack(spacing: 8) {
            Text("Unit price")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("$")
                .foregroundColor(.secondary)
            
            TextField("0.00", text: $price)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 120)
            
            Spacer()
        }
    }
}

/// Reusable date added input field
struct DateAddedInputField: View {
    @Binding var dateAdded: Date
    
    var body: some View {
        DatePicker("Date Added", selection: $dateAdded, displayedComponents: [.date])
            .datePickerStyle(.compact)
    }
}

/// Reusable general information section
struct GeneralFormSection: View {
    @Binding var catalogCode: String
    @Binding var selectedType: InventoryItemType
    
    var body: some View {
        Section("General") {
            CatalogItemSearchField(selectedCatalogId: $catalogCode)
            
            VStack(alignment: .leading, spacing: 8) {
                Picker("Add to my", selection: $selectedType) {
                    ForEach(InventoryItemType.allCases) { itemType in
                        HStack {
                            Image(systemName: itemType.systemImageName)
                                .foregroundColor(itemType.color)
                            Text(itemType.displayName)
                            Spacer()
                        }
                        .tag(itemType)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }
}

/// Searchable catalog item field that allows typing and shows matching catalog items
struct CatalogItemSearchField: View {
    @Binding var selectedCatalogId: String
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var selectedCatalogItem: CatalogItem?
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        entity: CatalogItem.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \CatalogItem.name, ascending: true)]
    ) private var catalogItems: FetchedResults<CatalogItem>
    
    // Filtered catalog items based on search text
    private var filteredCatalogItems: [CatalogItem] {
        if searchText.count < 2 { // Require at least 2 characters
            return []
        }
        
        // Use the centralized search utility for better results
        let allItems = Array(catalogItems)
        let results = SearchUtilities.searchCatalogItems(allItems, query: searchText)
        
        // Limit results and sort by relevance (exact matches first, then partial matches)
        return Array(results.sorted { item1, item2 in
            let name1 = item1.name ?? ""
            let name2 = item2.name ?? ""
            let searchLower = searchText.lowercased()
            
            // Prioritize exact name matches
            if name1.lowercased() == searchLower && name2.lowercased() != searchLower {
                return true
            } else if name1.lowercased() != searchLower && name2.lowercased() == searchLower {
                return false
            }
            
            // Then prioritize names that start with the search term
            let name1StartsWithSearch = name1.lowercased().hasPrefix(searchLower)
            let name2StartsWithSearch = name2.lowercased().hasPrefix(searchLower)
            
            if name1StartsWithSearch && !name2StartsWithSearch {
                return true
            } else if !name1StartsWithSearch && name2StartsWithSearch {
                return false
            }
            
            // Finally, sort alphabetically
            return name1 < name2
        }.prefix(8))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let selectedItem = selectedCatalogItem {
                // Show selected catalog item
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedItem.name ?? "Unknown Item")
                            .font(.body)
                            .fontWeight(.medium)
                        
                        if let code = selectedItem.code {
                            Text("Code: \(code)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let manufacturer = selectedItem.manufacturer {
                            Text("Manufacturer: \(manufacturer)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button("Change") {
                        selectedCatalogItem = nil
                        selectedCatalogId = ""
                        searchText = ""
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding(12)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                // Show search field
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Search catalog items...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            isSearching = false
                        }
                        .onChange(of: searchText) { _, newValue in
                            isSearching = !newValue.isEmpty
                        }
                    
                    // Show search results
                    if isSearching && !filteredCatalogItems.isEmpty {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(filteredCatalogItems, id: \.objectID) { item in
                                    CatalogItemSearchResultRow(item: item) {
                                        selectCatalogItem(item)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .frame(maxHeight: 200)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else if isSearching && searchText.count == 1 {
                        Text("Type at least 2 characters to search")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                    } else if isSearching && searchText.count >= 2 {
                        Text("No matching catalog items found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                    }
                }
            }
        }
        .onAppear {
            // Load selected catalog item if we have an ID
            loadSelectedCatalogItem()
        }
        .onChange(of: selectedCatalogId) { _, newId in
            if newId.isEmpty {
                selectedCatalogItem = nil
            } else {
                loadSelectedCatalogItem()
            }
        }
    }
    
    private func selectCatalogItem(_ item: CatalogItem) {
        selectedCatalogItem = item
        // Prefer ID over code, but use code as fallback if ID doesn't exist
        if let id = item.value(forKey: "id") as? String, !id.isEmpty {
            selectedCatalogId = id
        } else if let code = item.code, !code.isEmpty {
            selectedCatalogId = code
        } else {
            selectedCatalogId = item.objectID.uriRepresentation().absoluteString
        }
        searchText = ""
        isSearching = false
    }
    
    private func loadSelectedCatalogItem() {
        guard !selectedCatalogId.isEmpty else { return }
        
        // First try to find by ID, then by code
        let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@ OR code == %@", selectedCatalogId, selectedCatalogId)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            selectedCatalogItem = results.first
        } catch {
            print("❌ Failed to load catalog item: \(error)")
        }
    }
}

/// Individual search result row for catalog items
struct CatalogItemSearchResultRow: View {
    let item: CatalogItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Circle()
                    .fill(CatalogItemHelpers.colorForManufacturer(item.manufacturer))
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name ?? "Unknown Item")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        if let code = item.code {
                            Text(code)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let manufacturer = item.manufacturer {
                            Text("• \(manufacturer)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Form State Management

/// Centralized form state for inventory items
@MainActor
final class InventoryFormState: ObservableObject {
    @Published var catalogCode = ""
    @Published var count = ""
    @Published var units: InventoryUnits = .rods
    @Published var selectedType: InventoryItemType = .inventory
    @Published var notes = ""
    @Published var price = ""
    @Published var dateAdded = Date()
    
    // UI state
    @Published var isLoading = false
    @Published var showingError = false
    @Published var errorMessage = ""
    
    /// Initialize with empty values (for adding new items)
    init() {}
    
    /// Initialize with prefilled catalog code (for adding new items with known catalog)
    init(prefilledCatalogCode: String) {
        catalogCode = prefilledCatalogCode
    }
    
    /// Initialize from existing inventory item (for editing)
    init(from item: InventoryItem) {
        catalogCode = item.catalog_code ?? ""
        count = String(item.count)
        units = item.unitsKind
        selectedType = item.itemType
        notes = item.notes ?? ""
        price = String(item.price)
        dateAdded = item.date_added ?? Date()
    }
    
    /// Reset all fields to empty values
    func reset() {
        catalogCode = ""
        count = ""
        units = .rods
        selectedType = .inventory
        notes = ""
        price = ""
        dateAdded = Date()
        
        errorMessage = ""
        showingError = false
    }
    
    /// Validate form data
    func validate() -> Bool {
        // At least one field should have content
        let hasContent = !catalogCode.isEmpty ||
                        !count.isEmpty || !notes.isEmpty
        
        if !hasContent {
            errorMessage = "Please enter at least some information"
            showingError = true
            return false
        }
        
        return true
    }
    
    /// Create new inventory item from form state
    func createInventoryItem(in context: NSManagedObjectContext) throws -> InventoryItem {
        guard validate() else {
            throw FormError.validationFailed(errorMessage)
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let countValue = Double(count) ?? 0.0
        let unitsValue = units.rawValue
        let priceValue = Double(price) ?? 0.0
        
        return try InventoryService.shared.createInventoryItem(
            catalogCode: catalogCode.isEmpty ? nil : catalogCode,
            count: countValue,
            units: unitsValue,
            type: selectedType.rawValue,
            notes: notes.isEmpty ? nil : notes,
            price: priceValue,
            dateAdded: dateAdded,
            in: context
        )
    }
    
    /// Update existing inventory item with form state
    func updateInventoryItem(_ item: InventoryItem, in context: NSManagedObjectContext) throws {
        guard validate() else {
            throw FormError.validationFailed(errorMessage)
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let countValue = Double(count) ?? 0.0
        let unitsValue = units.rawValue
        let priceValue = Double(price) ?? 0.0
        
        try InventoryService.shared.updateInventoryItem(
            item,
            catalogCode: catalogCode.isEmpty ? nil : catalogCode,
            count: countValue,
            units: unitsValue,
            type: selectedType.rawValue,
            notes: notes.isEmpty ? nil : notes,
            price: priceValue,
            dateAdded: dateAdded,
            in: context
        )
    }
}

// MARK: - Form Error Handling

enum FormError: Error, LocalizedError {
    case validationFailed(String)
    case saveFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .validationFailed(let message):
            return message
        case .saveFailed(let message):
            return "Failed to save: \(message)"
        }
    }
}

// MARK: - Complete Form View

/// Complete inventory form using all reusable components
struct InventoryFormView: View {
    @StateObject private var formState: InventoryFormState
    let editingItem: InventoryItem?
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    init(editingItem: InventoryItem? = nil, prefilledCatalogCode: String? = nil) {
        self.editingItem = editingItem
        self._formState = StateObject(wrappedValue: InventoryFormState())
        
        // Set prefilled catalog code if provided
        if let code = prefilledCatalogCode, editingItem == nil {
            self._formState = StateObject(wrappedValue: InventoryFormState(prefilledCatalogCode: code))
        }
    }
    
    var body: some View {
        Form {
            GeneralFormSection(
                catalogCode: $formState.catalogCode,
                selectedType: $formState.selectedType
            )
            
            InventoryFormSection(
                count: $formState.count,
                units: $formState.units,
                notes: $formState.notes,
                price: $formState.price,
                dateAdded: $formState.dateAdded
            )
        }
        .navigationTitle(editingItem == nil ? "Add Item" : "Edit Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .disabled(formState.isLoading)
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button(editingItem == nil ? "Add" : "Save") {
                    saveItem()
                }
                .disabled(formState.isLoading)
            }
        }
        .onAppear {
            if let item = editingItem {
                formState.catalogCode = item.catalog_code ?? ""
                formState.count = String(item.count)
                formState.units = item.unitsKind
                formState.selectedType = item.itemType
                formState.notes = item.notes ?? ""
            }
        }
        .alert("Error", isPresented: $formState.showingError) {
            Button("OK") {
                formState.showingError = false
            }
        } message: {
            Text(formState.errorMessage)
        }
    }
    
    private func saveItem() {
        do {
            if let item = editingItem {
                try formState.updateInventoryItem(item, in: viewContext)
            } else {
                _ = try formState.createInventoryItem(in: viewContext)
            }
            dismiss()
        } catch {
            formState.errorMessage = error.localizedDescription
            formState.showingError = true
        }
    }
}

#Preview("Catalog Search Field") {
    NavigationStack {
        Form {
            Section("Test") {
                CatalogItemSearchField(selectedCatalogId: .constant(""))
            }
        }
        .navigationTitle("Catalog Search Test")
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

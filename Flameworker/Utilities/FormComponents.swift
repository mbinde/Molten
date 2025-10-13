//
//  FormComponents.swift
//  Flameworker
//
//  Created by Assistant on 9/29/25.
//  Migrated to Repository Pattern on 10/12/25 - Removed Core Data dependencies
//

import SwiftUI
import Combine
import Foundation

/// Reusable form components to eliminate duplication across forms

// MARK: - Inventory Form Sections

/// Reusable form section for inventory input (count, units, price, notes)
struct InventoryFormSection: View {
    @Binding var count: String
    @Binding var units: InventoryUnits
    @Binding var notes: String
    @Binding var price: String
    
    var body: some View {
        Section {
            CountUnitsInputRow(count: $count, units: $units)
            
            PriceInputField(price: $price)
            
            NotesInputField(notes: $notes)
        }
    }
}

/// Reusable general information section
struct GeneralFormSection: View {
    @Binding var catalogCode: String
    @Binding var selectedType: InventoryItemType
    
    var body: some View {
        Section("General") {
            CatalogItemSearchField(selectedCatalogId: $catalogCode)
            
            UnifiedPickerField(
                title: "Add to my",
                selection: $selectedType,
                displayProvider: { $0.displayName },
                imageProvider: { $0.systemImageName },
                colorProvider: { $0.color },
                style: .menu
            )
        }
    }
}

/// Searchable catalog item field that allows typing and shows matching catalog items
/// Migrated to Repository Pattern - uses CatalogService instead of Core Data
struct CatalogItemSearchField: View {
    @Binding var selectedCatalogId: String
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var selectedCatalogItem: CatalogItemModel?
    @State private var availableCatalogItems: [CatalogItemModel] = []
    
    private let catalogService: CatalogService
    
    init(selectedCatalogId: Binding<String>, catalogService: CatalogService? = nil) {
        self._selectedCatalogId = selectedCatalogId
        
        // Use provided service or create default with mock repository
        if let service = catalogService {
            self.catalogService = service
        } else {
            let mockRepository = MockCatalogRepository()
            self.catalogService = CatalogService(repository: mockRepository)
        }
    }
    
    // Filtered catalog items based on search text
    private var filteredCatalogItems: [CatalogItemModel] {
        if searchText.count < 2 { // Require at least 2 characters
            return []
        }
        
        // Filter items that match search text
        let results = availableCatalogItems.filter { item in
            item.name.localizedCaseInsensitiveContains(searchText) ||
            item.code.localizedCaseInsensitiveContains(searchText) ||
            item.manufacturer.localizedCaseInsensitiveContains(searchText)
        }
        
        // Limit results and sort by relevance (exact matches first, then partial matches)
        return Array(results.sorted { item1, item2 in
            let name1 = item1.name
            let name2 = item2.name
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
                        Text(selectedItem.name)
                            .font(.body)
                            .fontWeight(.medium)
                        
                        Text("Code: \(selectedItem.code)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Manufacturer: \(selectedItem.manufacturer)")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                                ForEach(filteredCatalogItems, id: \.id) { item in
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
        .task {
            await loadCatalogItems()
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
    
    private func selectCatalogItem(_ item: CatalogItemModel) {
        selectedCatalogItem = item
        selectedCatalogId = item.code
        searchText = ""
        isSearching = false
    }
    
    private func loadCatalogItems() async {
        do {
            availableCatalogItems = try await catalogService.getAllItems()
        } catch {
            print("❌ Failed to load catalog items: \(error)")
        }
    }
    
    private func loadSelectedCatalogItem() {
        guard !selectedCatalogId.isEmpty else { return }
        
        // Find item in available catalog items
        selectedCatalogItem = availableCatalogItems.first { item in
            item.id == selectedCatalogId || item.code == selectedCatalogId
        }
    }
}

/// Individual search result row for catalog items
struct CatalogItemSearchResultRow: View {
    let item: CatalogItemModel
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Circle()
                    .fill(colorForManufacturer(item.manufacturer))
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Text(item.code)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• \(item.manufacturer)")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
    
    // Simple color helper for manufacturer (replace CatalogItemHelpers)
    private func colorForManufacturer(_ manufacturer: String) -> Color {
        // Simple hash-based color generation
        let hash = manufacturer.hashValue
        let colors: [Color] = [.blue, .green, .orange, .purple, .red, .pink, .cyan, .yellow]
        return colors[abs(hash) % colors.count]
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
    
    // New unified error handling
    let errorAlertState = ErrorAlertState()
    
    /// Initialize with empty values (for adding new items)
    init() {}
    
    /// Initialize with prefilled catalog code (for adding new items with known catalog)
    init(prefilledCatalogCode: String) {
        catalogCode = prefilledCatalogCode
    }
    
    /// Initialize from existing inventory item (for editing)
    init(from item: InventoryItemModel) {
        catalogCode = item.catalogCode
        count = String(item.quantity)
        units = .rods // TODO: Add units support to InventoryItemModel
        selectedType = item.type
        notes = item.notes ?? ""
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
    
    /// Create new inventory item from form state using repository pattern
    func createInventoryItem(using inventoryService: InventoryService) async throws -> InventoryItemModel {
        guard validate() else {
            throw FormError.validationFailed(errorMessage)
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let countValue = Double(count) ?? 0.0
        
        // Create inventory item model
        let newItem = InventoryItemModel(
            catalogCode: catalogCode.isEmpty ? "" : catalogCode,
            quantity: countValue,
            type: selectedType,
            notes: notes.isEmpty ? nil : notes,
            location: nil, // Add location support if needed
            dateAdded: Date()
        )
        
        return try await inventoryService.createItem(newItem)
    }
    
    /// Update existing inventory item with form state using repository pattern
    func updateInventoryItem(_ item: InventoryItemModel, using inventoryService: InventoryService) async throws -> InventoryItemModel {
        guard validate() else {
            throw FormError.validationFailed(errorMessage)
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let countValue = Double(count) ?? 0.0
        
        // Create updated model
        let updatedItem = InventoryItemModel(
            id: item.id,
            catalogCode: catalogCode.isEmpty ? item.catalogCode : catalogCode,
            quantity: countValue,
            type: selectedType,
            notes: notes.isEmpty ? nil : notes,
            location: item.location, // Preserve existing location
            dateAdded: item.dateAdded // Preserve creation date
        )
        
        return try await inventoryService.updateItem(updatedItem)
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
/// Migrated to Repository Pattern - uses services instead of Core Data
struct InventoryFormView: View {
    @StateObject private var formState: InventoryFormState
    let editingItem: InventoryItemModel?
    
    private let inventoryService: InventoryService
    private let catalogService: CatalogService
    @Environment(\.dismiss) private var dismiss
    
    init(
        editingItem: InventoryItemModel? = nil, 
        prefilledCatalogCode: String? = nil,
        inventoryService: InventoryService? = nil,
        catalogService: CatalogService? = nil
    ) {
        self.editingItem = editingItem
        
        // Use provided services or create defaults with mock repositories
        if let invService = inventoryService {
            self.inventoryService = invService
        } else {
            let mockInvRepo = MockInventoryRepository()
            self.inventoryService = InventoryService(repository: mockInvRepo)
        }
        
        if let catService = catalogService {
            self.catalogService = catService
        } else {
            let mockCatRepo = MockCatalogRepository()
            self.catalogService = CatalogService(repository: mockCatRepo)
        }
        
        // Initialize form state
        if let item = editingItem {
            self._formState = StateObject(wrappedValue: InventoryFormState(from: item))
        } else if let code = prefilledCatalogCode {
            self._formState = StateObject(wrappedValue: InventoryFormState(prefilledCatalogCode: code))
        } else {
            self._formState = StateObject(wrappedValue: InventoryFormState())
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
                price: $formState.price
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
                    Task {
                        await saveItem()
                    }
                }
                .disabled(formState.isLoading)
            }
        }
        .errorAlert(formState.errorAlertState)
    }
    
    private func saveItem() async {
        do {
            if let item = editingItem {
                _ = try await formState.updateInventoryItem(item, using: inventoryService)
            } else {
                _ = try await formState.createInventoryItem(using: inventoryService)
            }
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                formState.errorAlertState.show(error: error, context: "Failed to save item")
            }
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
}

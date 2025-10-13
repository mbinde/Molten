//
//  InventoryItemDetailView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import SwiftUI
import CoreData

// MARK: - Release Configuration
// Set to false for simplified release builds
private let isAdvancedImageLoadingEnabled = false

struct InventoryItemDetailView: View {
    let item: InventoryItem
    let startInEditMode: Bool
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var isEditing = false
    
    // Custom initializer with default parameter for backwards compatibility
    init(item: InventoryItem, startInEditMode: Bool = false) {
        self.item = item
        self.startInEditMode = startInEditMode
    }
    @State private var showingDeleteAlert = false
    @State private var errorMessage: String?
    @StateObject private var errorState = ErrorAlertState()
    @State private var catalogItem: CatalogItem?
    
    // Editing state
    @State private var count = ""
    @State private var selectedType: InventoryItemType = .inventory
    @State private var notes = ""
    @State private var price = ""
    @State private var location = ""
    
    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Show catalog item details if available
                    if let catalogItem = catalogItem {
                        catalogItemSection(catalogItem)
                    } else {
                        fallbackHeaderSection
                    }
                    
                    // Inventory-specific details
                    inventoryDetailsSection
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle(isEditing ? "Edit Item" : navigationTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isEditing ? "Cancel" : "Done") {
                        if isEditing {
                            // If we started in edit mode, dismiss the sheet entirely
                            if startInEditMode {
                                dismiss()
                            } else {
                                cancelEditing()
                            }
                        } else {
                            dismiss()
                        }
                    }
                }
                
                if !isEditing {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Edit") {
                            startEditing()
                        }
                    }
                } else {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Save") {
                            saveChanges()
                        }
                    }
                }
                
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete") {
                        showingDeleteAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
            .onAppear {
                loadItemData()
                loadCatalogItem()
                if startInEditMode {
                    isEditing = true
                }
            }
            .alert("Delete Item", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteItem()
                }
            } message: {
                Text("This action cannot be undone.")
            }
            .errorAlert(errorState)
    }
    
    // MARK: - Computed Properties
    
    private var navigationTitle: String {
        if let catalogItem = catalogItem {
            return catalogItem.name ?? "Unknown Item"
        } else {
            return item.catalog_code ?? item.id ?? "Unknown Item"
        }
    }
    
    private var shouldShowLocationField: Bool {
        // Location field should show for all inventory item types
        return true
    }
    
    private var safeLocationValue: String {
        return item.location ?? ""
    }
    
    /// Check if item has any inventory data (same logic as removed hasAnyData extension)
    private var hasAnyInventoryData: Bool {
        let hasInventory = item.count > 0
        let hasNotes = !(item.notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        return hasInventory || hasNotes
    }
    
    private var quantityLabelText: String {
        if let catalogItem = catalogItem {
            let info = CatalogItemHelpers.getItemDisplayInfo(catalogItem)
            if let stock = info.stockType, !stock.isEmpty {
                return "Number of \(stock.lowercased())"
            }
        }
        return "Number of \(getUnitsDisplayName().lowercased())"
    }
    
    // MARK: - Helper Methods
    
    /// Get units display name from catalog item or fallback to default
    private func getUnitsDisplayName() -> String {
        // First, try to get units from the catalog item if available
        if let catalogItem = catalogItem {
            let units = InventoryUnits.fromLegacyInt16(catalogItem.units)
            return units.displayName
        }
        
        // Fallback to rods if no catalog item
        return InventoryUnits.rods.displayName
    }
    
    // MARK: - Views
    
    @ViewBuilder
    private func catalogItemSection(_ catalogItem: CatalogItem) -> some View {
        let displayInfo = CatalogItemHelpers.getItemDisplayInfo(catalogItem)
        
        VStack(alignment: .leading, spacing: 16) {
            // Main content with image and details side by side (reusing CatalogItemSimpleView layout)
            HStack(alignment: .top, spacing: 16) {
                // Product image if available - feature gated for release
                if isAdvancedImageLoadingEnabled && ImageHelpers.productImageExists(for: displayInfo.code, manufacturer: displayInfo.manufacturer) {
                    ProductImageDetail(itemCode: displayInfo.code, manufacturer: displayInfo.manufacturer, maxSize: 200)
                        .frame(maxWidth: 200)
                } else {
                    // Placeholder for when no image exists
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 200, height: 200)
                        .overlay(
                            VStack {
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                                    .font(.largeTitle)
                                Text("No Image")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        )
                }
                
                // Item details inline with image
                VStack(alignment: .leading, spacing: 12) {
                    // COE (without thermometer icon)
                    if let coe = displayInfo.coe {
                        inlineDetailRow(title: "COE", value: coe)
                    }
                    
                    // Manufacturer
                    inlineDetailRow(title: "Manufacturer", value: displayInfo.manufacturerFullName)
                    
                    // Item code
                    inlineDetailRow(title: "Item Code", value: displayInfo.code)
                    
                    // Stock Type
                    if let stockType = displayInfo.stockType {
                        inlineDetailRow(title: "Stock Type", value: stockType.capitalized)
                    }
                    
                    // Tags inline
                    if !displayInfo.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Tags")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 60), spacing: 6)
                            ], spacing: 6) {
                                ForEach(displayInfo.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            

            
            // Synonyms section if available
            if !displayInfo.synonyms.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Also Known As")
                        .font(.headline)
                    
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 100), spacing: 8)
                    ], spacing: 8) {
                        ForEach(displayInfo.synonyms, id: \.self) { synonym in
                            Text(synonym)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.1))
                                .foregroundColor(.green)
                                .cornerRadius(12)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var fallbackHeaderSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.catalog_code ?? item.id ?? "Unknown Item")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                InventoryStatusIndicators(
                    hasInventory: item.count > 0,
                    lowStock: item.count > 0 && item.count <= 10.0
                )
            }
            
            // Product image if available (fallback) - feature gated for release
            if isAdvancedImageLoadingEnabled,
               let itemCode = item.catalog_code, 
               !itemCode.isEmpty,
               ImageHelpers.productImageExists(for: itemCode) {
                HStack {
                    ProductImageDetail(itemCode: itemCode, maxSize: 150)
                    Spacer()
                }
            }
        }
        .padding(.bottom, 10)
    }
    
    @ViewBuilder
    private var inventoryDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Inventory")
                .font(.headline)
            
            if isEditing {
                editingForm
            } else {
                readOnlyInventoryContent
            }
        }
    }
    
    @ViewBuilder
    private var readOnlyInventoryContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Count and Units section
            if item.count > 0 {
                sectionView(title: "Inventory", content: "\(String(format: "%.1f", item.count)) \(getUnitsDisplayName()) (\(item.itemType.displayName))")
            }
            
            // Notes section
            if let notes = item.notes, !notes.isEmpty {
                sectionView(title: "Notes", content: notes)
            }
            
            // Location section
            if shouldShowLocationField && !safeLocationValue.isEmpty {
                sectionView(title: "Location", content: safeLocationValue)
            }
            
            if !hasAnyInventoryData {
                Text("No data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
    }
    
    @ViewBuilder
    private var editingForm: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                // Show catalog name as non-editable
                if let catalogItem = catalogItem {
                    Text("Item: \(catalogItem.name ?? "Unknown Item")")
                        .font(.body)
                        .fontWeight(.medium)
                } else if let catalogCode = item.catalog_code, !catalogCode.isEmpty {
                    Text("Item: \(catalogCode)")
                        .font(.body)
                        .fontWeight(.medium)
                }
                
                HStack(alignment: .center, spacing: 12) {
                    // Compact quantity field
                    HStack(spacing: 8) {
                        Text(quantityLabelText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        UnifiedFormField(
                            config: CountFieldConfig(title: ""),
                            value: $count
                        )
                        .frame(width: 90)
                    }
                    
                    // Vertical picker for Type; replaced from segmented picker
                    InventoryTypeVerticalPicker(selectedType: $selectedType, iconOnly: true)
                }
                
                // Location field - show for all inventory item types
                locationInputField
                
                UnifiedMultilineFormField(
                    config: NotesFieldConfig(),
                    value: $notes,
                    lineLimit: 3...6
                )
            }
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private var locationInputField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location")
                .font(.subheadline)
                .fontWeight(.medium)
            
            LocationAutoCompleteField(location: $location, context: viewContext)
        }
    }
    
    private func sectionView(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.body)
                .detailRowStyle()
        }
    }
    
    // MARK: - Actions
    
    private func loadCatalogItem() {
        guard let catalogCode = item.catalog_code, !catalogCode.isEmpty else {
            catalogItem = nil
            return
        }
        
        // Create multiple search patterns like in RelatedInventoryItemsView
        var predicates: [NSPredicate] = []
        
        // Search for exact match with the catalog code
        predicates.append(NSPredicate(format: "code == %@", catalogCode))
        
        // If catalog code has a manufacturer prefix, also try without it
        if catalogCode.contains("-"), let basePart = catalogCode.split(separator: "-").last {
            let baseCode = String(basePart)
            predicates.append(NSPredicate(format: "code == %@", baseCode))
        }
        
        // Also search by ID field
        predicates.append(NSPredicate(format: "id == %@", catalogCode))
        
        let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        
        let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        fetchRequest.predicate = compoundPredicate
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            catalogItem = results.first
        } catch {
            print("❌ Failed to load catalog item: \(error)")
            catalogItem = nil
        }
    }
    
    // MARK: - Helper Views
    
    private func inlineDetailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
    
    private func loadItemData() {
        // Format count without unnecessary decimal places
        if item.count.truncatingRemainder(dividingBy: 1) == 0 {
            // Whole number - show without decimal
            count = String(format: "%.0f", item.count)
        } else {
            // Has decimal part - show with decimals
            count = String(item.count)
        }
        
        selectedType = item.itemType
        notes = item.notes ?? ""
        location = safeLocationValue
    }
            
    private func startEditing() {
        loadItemData()
        isEditing = true
    }
    
    private func cancelEditing() {
        loadItemData()
        isEditing = false
    }
    
    private func saveChanges() {
        let result = ErrorHandler.shared.execute(context: "Saving inventory item changes") {
            let countValue = Double(count) ?? 0.0
            let priceValue = Double(price) ?? 0.0
            
            // Update item properties directly using KVC
            item.setValue(countValue, forKey: "count")
            item.setValue(selectedType.rawValue, forKey: "type")
            item.setValue(notes.isEmpty ? nil : notes, forKey: "notes")
            item.setValue(location.isEmpty ? nil : location, forKey: "location")
            
            // Save the context
            try CoreDataHelpers.safeSave(context: viewContext, description: "Update inventory item with location")
        }
        
        switch result {
        case .success:
            isEditing = false
        case .failure(let error):
            errorState.show(error: error, context: "Failed to save changes")
        }
    }
    
    private func deleteItem() {
        let result = ErrorHandler.shared.execute(context: "Deleting inventory item") {
            viewContext.delete(item)
            try CoreDataHelpers.safeSave(context: viewContext, description: "Delete inventory item")
        }
        
        switch result {
        case .success:
            print("🗑️ Deleted inventory item with ID: \(item.id ?? "unknown")")
            dismiss()
        case .failure(let error):
            errorState.show(error: error, context: "Failed to delete item")
        }
    }
}


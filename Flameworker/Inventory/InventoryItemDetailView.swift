//
//  InventoryItemDetailView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import SwiftUI
import CoreData

struct InventoryItemDetailView: View {
    let item: InventoryItem
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var isEditing = false
    @State private var showingDeleteAlert = false
    @State private var errorMessage: String?
    @State private var catalogItemName: String?
    
    // Editing state
    @State private var count = ""
    @State private var selectedUnits: InventoryUnits = .shorts
    @State private var selectedType: InventoryItemType = .inventory
    @State private var notes = ""
    @State private var price = ""
    @State private var dateAdded = Date()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    headerSection
                    
                    // Main sections
                    if isEditing {
                        editingForm
                    } else {
                        readOnlyContent
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle(isEditing ? "Edit Item" : (catalogItemName ?? item.catalog_code ?? item.id ?? "Unknown Item"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isEditing ? "Cancel" : "Done") {
                        if isEditing {
                            cancelEditing()
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
            }
            .alert("Delete Item", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteItem()
                }
            } message: {
                Text("This action cannot be undone.")
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear {
                loadCatalogItemName()
            }
        }
    }
    
    // MARK: - Views
    
    @ViewBuilder
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(catalogItemName ?? item.catalog_code ?? item.id ?? "Unknown Item")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            InventoryStatusIndicators(
                hasInventory: item.hasInventory,
                lowStock: item.isLowStock
            )
        }
        .padding(.bottom, 10)
    }
    
    @ViewBuilder
    private var readOnlyContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Count and Units section
            if item.count > 0 {
                let displayInfo = item.displayInfo
                sectionView(title: "Inventory", content: "\(String(format: "%.1f", displayInfo.count)) \(displayInfo.unit) (\(item.typeDisplayName))")
            }
            
            // Notes section
            if let notes = item.notes, !notes.isEmpty {
                sectionView(title: "Notes", content: notes)
            }
            
            if !item.hasAnyData {
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
                Text("Item Details")
                    .font(.headline)
                
                // Show catalog name as non-editable
                if let catalogName = catalogItemName {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Catalog Item")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(catalogName)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                } else if let catalogCode = item.catalog_code, !catalogCode.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Catalog Code")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(catalogCode)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                
                HStack(spacing: 12) {
                    TextField("Count", text: $count)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Picker("", selection: $selectedUnits) {
                        ForEach(InventoryUnits.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }
                
                // Type picker
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
                
                TextField("Notes", text: $notes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                    .textInputAutocapitalization(.sentences)
                
                // Price field
                VStack(alignment: .leading, spacing: 4) {
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
                    
                    Text("Price per unit (e.g. per rod or per pound)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Date Added field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Date Added")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    DatePicker("", selection: $dateAdded, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
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
    
    private func loadCatalogItemName() {
        guard let catalogCode = item.catalog_code, !catalogCode.isEmpty else {
            catalogItemName = nil
            return
        }
        
        // Create fetch request to find catalog item by ID or code
        let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@ OR code == %@", catalogCode, catalogCode)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            if let catalogItem = results.first {
                catalogItemName = catalogItem.name
            } else {
                catalogItemName = nil
            }
        } catch {
            print("❌ Failed to load catalog item name: \(error)")
            catalogItemName = nil
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
        
        selectedUnits = item.unitsKind
        selectedType = item.itemType
        notes = item.notes ?? ""
        
        // Format price without unnecessary decimal places
        if item.price.truncatingRemainder(dividingBy: 1) == 0 {
            price = String(format: "%.0f", item.price)
        } else {
            price = String(item.price)
        }
        
        dateAdded = item.date_added ?? Date()
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
        do {
            let countValue = Double(count) ?? 0.0
            let unitsValue = selectedUnits.rawValue
            let priceValue = Double(price) ?? 0.0
            
            // Use existing catalog code since it's no longer editable
            try InventoryService.shared.updateInventoryItem(
                item,
                catalogCode: item.catalog_code, // Keep existing catalog code
                count: countValue,
                units: unitsValue,
                type: selectedType.rawValue,
                notes: notes.isEmpty ? nil : notes,
                price: priceValue,
                dateAdded: dateAdded,
                in: viewContext
            )
            isEditing = false
        } catch {
            errorMessage = "Failed to save changes: \(error.localizedDescription)"
        }
    }
    
    private func deleteItem() {
        do {
            try InventoryService.shared.deleteInventoryItem(item, from: viewContext)
            dismiss()
        } catch {
            errorMessage = "Failed to delete item: \(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack {
        InventoryItemDetailView(item: {
            let item = InventoryItem(context: PersistenceController.preview.container.viewContext)
            item.id = "preview-detail"
            item.catalog_code = "BR-GLR-001"
            item.count = 50.0
            item.units = 1
            item.type = InventoryItemType.sell.rawValue
            item.notes = "High quality borosilicate glass rods for flameworking"
            return item
        }())
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

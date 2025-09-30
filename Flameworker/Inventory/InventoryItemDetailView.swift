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
    
    // Editing state
    @State private var catalogCode = ""
    @State private var count = ""
    @State private var selectedUnits: InventoryUnits = .shorts
    @State private var selectedType: InventoryItemType = .inventory
    @State private var notes = ""
    
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
            .navigationTitle(isEditing ? "Edit Item" : (item.catalog_code ?? item.id ?? "Unknown Item"))
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
        }
    }
    
    // MARK: - Views
    
    @ViewBuilder
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.catalog_code ?? item.id ?? "Unknown Item")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let id = item.id {
                    Text("ID: \(id)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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
            // Catalog Code section
            if let catalogCode = item.catalog_code, !catalogCode.isEmpty {
                sectionView(title: "Catalog Code", content: catalogCode)
            }
            
            // Count and Units section
            if item.count > 0 {
                let displayInfo = item.displayInfo
                sectionView(title: "Inventory", content: "\(String(format: "%.1f", displayInfo.count)) \(displayInfo.unit) (\(item.typeDisplayName))")
            }
            
            // Type section
            sectionView(title: "Type", content: item.typeDisplayName)
            
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
                
                TextField("Catalog Code", text: $catalogCode)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
                
                TextField("Count", text: $count)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Units")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Picker("Units", selection: $selectedUnits) {
                        ForEach(InventoryUnits.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
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
    
    private func loadItemData() {
        catalogCode = item.catalog_code ?? ""
        count = String(item.count)
        selectedUnits = item.unitsKind
        selectedType = item.itemType
        notes = item.notes ?? ""
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
            
            try InventoryService.shared.updateInventoryItem(
                item,
                catalogCode: catalogCode.isEmpty ? nil : catalogCode,
                count: countValue,
                units: unitsValue,
                type: selectedType.rawValue,
                notes: notes.isEmpty ? nil : notes,
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

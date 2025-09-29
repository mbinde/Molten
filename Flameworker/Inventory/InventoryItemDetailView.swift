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
    @State private var customTags = ""
    @State private var isFavorite = false
    @State private var inventoryAmount = ""
    @State private var inventoryUnits = ""
    @State private var inventoryNotes = ""
    @State private var shoppingAmount = ""
    @State private var shoppingUnits = ""
    @State private var shoppingNotes = ""
    @State private var forsaleAmount = ""
    @State private var forsaleUnits = ""
    @State private var forsaleNotes = ""
    
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
            .navigationTitle(isEditing ? "Edit Item" : item.displayTitle)
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
                Text(item.displayTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let id = item.id {
                    Text("ID: \(id)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if InventoryService.shared.isFavorite(item) {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .font(.title3)
            }
        }
        .padding(.bottom, 10)
    }
    
    @ViewBuilder
    private var readOnlyContent: some View {
        // General section
        if let tags = item.custom_tags, !tags.isEmpty {
            sectionView(title: "Tags", content: tags)
        }
        
        // Inventory section using reusable component
        if item.hasInventory {
            InventorySectionView(
                title: "Inventory",
                icon: "archivebox.fill",
                color: .green,
                amount: item.inventory_amount,
                units: item.inventory_units,
                notes: item.inventory_notes,
                isEditing: false,
                amountBinding: .constant(""),
                unitsBinding: .constant(""),
                notesBinding: .constant("")
            )
        }
        
        // Shopping section using reusable component
        if item.needsShopping {
            InventorySectionView(
                title: "Shopping List",
                icon: "cart.fill",
                color: .orange,
                amount: item.shopping_amount,
                units: item.shopping_units,
                notes: item.shopping_notes,
                isEditing: false,
                amountBinding: .constant(""),
                unitsBinding: .constant(""),
                notesBinding: .constant("")
            )
        }
        
        // For Sale section using reusable component
        if item.isForSale {
            InventorySectionView(
                title: "For Sale",
                icon: "dollarsign.circle.fill",
                color: .blue,
                amount: item.forsale_amount,
                units: item.forsale_units,
                notes: item.forsale_notes,
                isEditing: false,
                amountBinding: .constant(""),
                unitsBinding: .constant(""),
                notesBinding: .constant("")
            )
        }
        
        if !item.hasAnyInventoryData {
            Text("No data available")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        }
    }
    
    @ViewBuilder
    private var editingForm: some View {
        VStack(spacing: 20) {
            // General section
            VStack(alignment: .leading, spacing: 12) {
                Text("General")
                    .font(.headline)
                
                TextField("Custom Tags", text: $customTags)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
                
                Toggle("Favorite", isOn: $isFavorite)
            }
            
            // Inventory section using reusable component
            InventorySectionView(
                title: "Inventory",
                icon: "archivebox.fill",
                color: .green,
                amount: nil,
                units: nil,
                notes: nil,
                isEditing: true,
                amountBinding: $inventoryAmount,
                unitsBinding: $inventoryUnits,
                notesBinding: $inventoryNotes
            )
            
            // Shopping section using reusable component
            InventorySectionView(
                title: "Shopping List",
                icon: "cart.fill",
                color: .orange,
                amount: nil,
                units: nil,
                notes: nil,
                isEditing: true,
                amountBinding: $shoppingAmount,
                unitsBinding: $shoppingUnits,
                notesBinding: $shoppingNotes
            )
            
            // For Sale section using reusable component
            InventorySectionView(
                title: "For Sale",
                icon: "dollarsign.circle.fill",
                color: .blue,
                amount: nil,
                units: nil,
                notes: nil,
                isEditing: true,
                amountBinding: $forsaleAmount,
                unitsBinding: $forsaleUnits,
                notesBinding: $forsaleNotes
            )
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
        customTags = item.custom_tags ?? ""
        isFavorite = InventoryService.shared.isFavorite(item)
        inventoryAmount = item.inventory_amount ?? ""
        inventoryUnits = item.inventory_units ?? ""
        inventoryNotes = item.inventory_notes ?? ""
        shoppingAmount = item.shopping_amount ?? ""
        shoppingUnits = item.shopping_units ?? ""
        shoppingNotes = item.shopping_notes ?? ""
        forsaleAmount = item.forsale_amount ?? ""
        forsaleUnits = item.forsale_units ?? ""
        forsaleNotes = item.forsale_notes ?? ""
    }
    
    private func startEditing() {
        loadItemData() // Refresh from current item
        isEditing = true
    }
    
    private func cancelEditing() {
        loadItemData() // Reset to original values
        isEditing = false
    }
    
    private func saveChanges() {
        do {
            try InventoryService.shared.updateInventoryItem(
                item,
                customTags: customTags.isEmpty ? nil : customTags,
                isFavorite: isFavorite,
                inventoryAmount: inventoryAmount.isEmpty ? nil : inventoryAmount,
                inventoryUnits: inventoryUnits.isEmpty ? nil : inventoryUnits,
                inventoryNotes: inventoryNotes.isEmpty ? nil : inventoryNotes,
                shoppingAmount: shoppingAmount.isEmpty ? nil : shoppingAmount,
                shoppingUnits: shoppingUnits.isEmpty ? nil : shoppingUnits,
                shoppingNotes: shoppingNotes.isEmpty ? nil : shoppingNotes,
                forsaleAmount: forsaleAmount.isEmpty ? nil : forsaleAmount,
                forsaleUnits: forsaleUnits.isEmpty ? nil : forsaleUnits,
                forsaleNotes: forsaleNotes.isEmpty ? nil : forsaleNotes,
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
            item.custom_tags = "Clear Glass Rods"
            item.favorite = Data([1])
            item.inventory_amount = "50"
            item.inventory_units = "pieces"
            item.inventory_notes = "High quality borosilicate glass rods for flameworking"
            item.shopping_amount = "25"
            item.shopping_units = "pieces"
            item.shopping_notes = "Need to restock soon"
            item.forsale_amount = "10"
            item.forsale_units = "pieces"
            item.forsale_notes = "Selling extra inventory"
            return item
        }())
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
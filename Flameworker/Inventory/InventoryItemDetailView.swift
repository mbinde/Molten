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
            .navigationTitle(isEditing ? "Edit Item" : displayTitle)
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
                Text(displayTitle)
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
        
        // Inventory section
        if hasInventoryData {
            inventorySection(isEditable: false)
        }
        
        // Shopping section
        if hasShoppingData {
            shoppingSection(isEditable: false)
        }
        
        // For Sale section
        if hasForSaleData {
            forSaleSection(isEditable: false)
        }
        
        if !hasAnyData {
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
            
            // Inventory section
            inventorySection(isEditable: true)
            
            // Shopping section
            shoppingSection(isEditable: true)
            
            // For Sale section
            forSaleSection(isEditable: true)
        }
    }
    
    @ViewBuilder
    private func inventorySection(isEditable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Inventory", systemImage: "archivebox.fill")
                .font(.headline)
                .foregroundColor(.green)
            
            if isEditable {
                HStack {
                    TextField("Amount", text: $inventoryAmount)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numbersAndPunctuation)
                    
                    TextField("Units", text: $inventoryUnits)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words)
                }
                
                TextField("Notes", text: $inventoryNotes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                    .textInputAutocapitalization(.sentences)
            } else {
                if let amount = item.inventory_amount, !amount.isEmpty {
                    detailRow(title: "Amount", value: "\(amount) \(item.inventory_units ?? "")")
                }
                if let notes = item.inventory_notes, !notes.isEmpty {
                    detailRow(title: "Notes", value: notes)
                }
            }
        }
    }
    
    @ViewBuilder
    private func shoppingSection(isEditable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Shopping List", systemImage: "cart.fill")
                .font(.headline)
                .foregroundColor(.orange)
            
            if isEditable {
                HStack {
                    TextField("Amount", text: $shoppingAmount)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numbersAndPunctuation)
                    
                    TextField("Units", text: $shoppingUnits)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words)
                }
                
                TextField("Notes", text: $shoppingNotes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                    .textInputAutocapitalization(.sentences)
            } else {
                if let amount = item.shopping_amount, !amount.isEmpty {
                    detailRow(title: "Amount", value: "\(amount) \(item.shopping_units ?? "")")
                }
                if let notes = item.shopping_notes, !notes.isEmpty {
                    detailRow(title: "Notes", value: notes)
                }
            }
        }
    }
    
    @ViewBuilder
    private func forSaleSection(isEditable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("For Sale", systemImage: "dollarsign.circle.fill")
                .font(.headline)
                .foregroundColor(.blue)
            
            if isEditable {
                HStack {
                    TextField("Amount", text: $forsaleAmount)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numbersAndPunctuation)
                    
                    TextField("Units", text: $forsaleUnits)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words)
                }
                
                TextField("Notes", text: $forsaleNotes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                    .textInputAutocapitalization(.sentences)
            } else {
                if let amount = item.forsale_amount, !amount.isEmpty {
                    detailRow(title: "Amount", value: "\(amount) \(item.forsale_units ?? "")")
                }
                if let notes = item.forsale_notes, !notes.isEmpty {
                    detailRow(title: "Notes", value: notes)
                }
            }
        }
    }
    
    private func sectionView(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Computed Properties
    
    private var displayTitle: String {
        if let tags = item.custom_tags, !tags.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return tags
        } else if let id = item.id, !id.isEmpty {
            return "Item \(String(id.prefix(8)))"
        } else {
            return "Untitled Item"
        }
    }
    
    private var hasInventoryData: Bool {
        (item.inventory_amount != nil && !item.inventory_amount!.isEmpty) ||
        (item.inventory_notes != nil && !item.inventory_notes!.isEmpty)
    }
    
    private var hasShoppingData: Bool {
        (item.shopping_amount != nil && !item.shopping_amount!.isEmpty) ||
        (item.shopping_notes != nil && !item.shopping_notes!.isEmpty)
    }
    
    private var hasForSaleData: Bool {
        (item.forsale_amount != nil && !item.forsale_amount!.isEmpty) ||
        (item.forsale_notes != nil && !item.forsale_notes!.isEmpty)
    }
    
    private var hasAnyData: Bool {
        hasInventoryData || hasShoppingData || hasForSaleData ||
        (item.custom_tags != nil && !item.custom_tags!.isEmpty)
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
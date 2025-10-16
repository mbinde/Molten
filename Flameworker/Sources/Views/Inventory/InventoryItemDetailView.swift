//
//  InventoryItemDetailView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//  Updated for GlassItem Architecture on 10/14/25.
//

import SwiftUI

// MARK: - Release Configuration
// Set to false for simplified release builds
private let isAdvancedImageLoadingEnabled = false

struct InventoryItemDetailView: View {
    let completeItem: CompleteInventoryItemModel
    let startInEditMode: Bool
    let inventoryTrackingService: InventoryTrackingService
    
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    
    // MARK: - Dependency Injection Initializers
    
    /// Initialize with complete inventory model and service (new architecture)
    init(
        completeItem: CompleteInventoryItemModel, 
        inventoryTrackingService: InventoryTrackingService, 
        startInEditMode: Bool = false
    ) {
        self.completeItem = completeItem
        self.inventoryTrackingService = inventoryTrackingService
        self.startInEditMode = startInEditMode
    }
    
    /// Convenience initializer for complete model only (creates default service for previews)
    init(completeItem: CompleteInventoryItemModel, startInEditMode: Bool = false) {
        self.completeItem = completeItem
        self.startInEditMode = startInEditMode
        // Create service using RepositoryFactory for previews
        RepositoryFactory.configureForTesting()
        self.inventoryTrackingService = RepositoryFactory.createInventoryTrackingService()
    }
    
    @State private var showingDeleteAlert = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    // Editing state - populated from complete inventory model
    @State private var editingQuantity = ""
    @State private var selectedType = "rod"
    @State private var editingNotes = ""
    @State private var selectedInventoryId: UUID?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with glass item information
                glassItemHeaderSection
                
                // Inventory breakdown section
                inventoryBreakdownSection
                
                // Tags section
                tagsSection
                
                // Location details section
                locationDetailsSection
                
                Spacer(minLength: 20)
            }
            .padding()
        }
        .navigationTitle(isEditing ? "Edit Inventory" : completeItem.glassItem.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(isEditing ? "Cancel" : "Done") {
                    if isEditing {
                        if startInEditMode {
                            dismiss()
                        } else {
                            isEditing = false
                        }
                    } else {
                        dismiss()
                    }
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                if !isEditing {
                    Button("Edit") {
                        isEditing = true
                    }
                }
            }
        }
        .onAppear {
            loadInitialData()
            if startInEditMode {
                isEditing = true
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadInitialData() {
        // Load data from the first inventory record if available
        if let firstInventory = completeItem.inventory.first {
            editingQuantity = String(firstInventory.quantity)
            selectedType = firstInventory.type
            selectedInventoryId = firstInventory.id
        }
        
        // Notes aren't stored in inventory in the new architecture
        // They could be stored as special tags or in glass item notes
        editingNotes = completeItem.glassItem.mfr_notes ?? ""
    }
    
    // MARK: - View Sections
    
    @ViewBuilder
    private var glassItemHeaderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(completeItem.glassItem.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("SKU: \(completeItem.glassItem.sku)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Manufacturer: \(completeItem.glassItem.manufacturer)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("COE \(completeItem.glassItem.coe)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    
                    Text("Total: \(String(format: "%.1f", completeItem.totalQuantity))")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.bottom, 10)
    }
    
    @ViewBuilder
    private var inventoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Inventory Breakdown")
                .font(.headline)
            
            if completeItem.inventory.isEmpty {
                Text("No inventory recorded")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(completeItem.inventory, id: \.id) { inventory in
                    InventoryRowView(
                        inventory: inventory,
                        isEditing: isEditing && selectedInventoryId == inventory.id
                    ) {
                        selectedInventoryId = inventory.id
                        editingQuantity = String(inventory.quantity)
                        selectedType = inventory.type
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var tagsSection: some View {
        if !completeItem.tags.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Tags")
                    .font(.headline)
                
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 80), spacing: 8)
                ], spacing: 8) {
                    ForEach(completeItem.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(6)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var locationDetailsSection: some View {
        if !completeItem.locations.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("Location Details")
                    .font(.headline)
                
                ForEach(completeItem.locations, id: \.id) { location in
                    LocationRowView(location: location)
                }
            }
        }
    }
}

// MARK: - Helper Views

struct InventoryRowView: View {
    let inventory: InventoryModel
    let isEditing: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(inventory.type.capitalized)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Quantity: \(String(format: "%.1f", inventory.quantity))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isEditing {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(isEditing ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct LocationRowView: View {
    let location: LocationModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(location.location)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Quantity: \(String(format: "%.1f", location.quantity))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "location")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        // Create sample data for preview
        let sampleGlassItem = GlassItemModel(
            natural_key: "bullseye-001-0",
            name: "Clear",
            sku: "001",
            manufacturer: "bullseye",
            mfr_notes: "Crystal clear glass",
            coe: 90,
            url: nil,
            mfr_status: "available"
        )
        
        let sampleInventory = [
            InventoryModel(
                id: UUID(),
                item_natural_key: "bullseye-001-0",
                type: "rod",
                quantity: 25.0
            ),
            InventoryModel(
                id: UUID(),
                item_natural_key: "bullseye-001-0", 
                type: "sheet",
                quantity: 10.0
            )
        ]
        
        let sampleLocation = [
            LocationModel(
                id: UUID(),
                inventoryId: UUID(),
                location: "Studio Shelf A",
                quantity: 15.0
            ),
            LocationModel(
                id: UUID(),
                inventoryId: UUID(),
                location: "Storage Room B",
                quantity: 20.0
            )
        ]
        
        let sampleCompleteItem = CompleteInventoryItemModel(
            glassItem: sampleGlassItem,
            inventory: sampleInventory,
            tags: ["clear", "compatible", "bullseye"],
            locations: sampleLocation
        )
        
        InventoryItemDetailView(completeItem: sampleCompleteItem)
    }
}

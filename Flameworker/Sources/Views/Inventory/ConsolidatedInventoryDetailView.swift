//
//  ConsolidatedInventoryDetailView.swift
//  Flameworker
//
//  Created by Assistant on 10/13/25.
//  Repository-based detail view for consolidated inventory items
//  Updated for GlassItem architecture - 10/14/25
//

import SwiftUI

/// Detail view for a consolidated inventory item using new GlassItem architecture
struct ConsolidatedInventoryDetailView: View {
    let glassItem: GlassItemModel
    let inventoryTrackingService: InventoryTrackingService
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var inventoryToDelete: InventoryModel?
    @State private var detailedSummary: DetailedInventorySummaryModel?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    init(glassItem: GlassItemModel, inventoryTrackingService: InventoryTrackingService) {
        self.glassItem = glassItem
        self.inventoryTrackingService = inventoryTrackingService
    }
    
    var body: some View {
        NavigationStack {
            if isLoading {
                ProgressView("Loading inventory...")
            } else if let errorMessage = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Error loading inventory")
                        .font(.headline)
                    Text(errorMessage)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        loadInventorySummary()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                List {
                    // Glass Item Info Section
                    Section("Glass Item") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(glassItem.name)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            
                            HStack {
                                Text("Natural Key:")
                                    .foregroundColor(.secondary)
                                Text(glassItem.naturalKey)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("Manufacturer:")
                                    .foregroundColor(.secondary)
                                Text(glassItem.manufacturer.uppercased())
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("COE:")
                                    .foregroundColor(.secondary)
                                Text("\(glassItem.coe)")
                                    .fontWeight(.medium)
                            }
                            
                            if let mfrNotes = glassItem.mfrNotes, !mfrNotes.isEmpty {
                                Text(mfrNotes)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Inventory Summary Section
                    if let detailed = detailedSummary {
                        let summary = detailed.summary
                        Section("Inventory Summary") {
                            HStack(spacing: 24) {
                                InventoryStatView(
                                    title: "Total Quantity", 
                                    count: summary.totalQuantity,
                                    color: .blue,
                                    icon: "archivebox.fill"
                                )
                                
                                InventoryStatView(
                                    title: "Types", 
                                    count: Double(summary.inventoryByType.count),
                                    color: .orange,
                                    icon: "square.stack.3d.up"
                                )
                            }
                        }
                        
                        // Individual Inventory Items Section
                        if summary.inventoryRecordCount > 0 {
                            Section("Inventory by Type (\(summary.inventoryRecordCount))") {
                                ForEach(summary.inventoryByType.sorted(by: { $0.key < $1.key }), id: \.key) { type, quantity in
                                    InventoryTypeRow(type: type, quantity: quantity, locations: detailed.locationDetails[type] ?? [])
                                }
                            }
                        }
                    } else {
                        Section("Inventory") {
                            Text("No inventory found")
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                }
                .navigationTitle("Inventory Details")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .task {
            await loadInventorySummary()
        }
    }
    
    @MainActor
    private func loadInventorySummary() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let detailed = try await inventoryTrackingService.getInventorySummary(for: glassItem.naturalKey)
                await MainActor.run {
                    self.detailedSummary = detailed
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct InventoryStatView: View {
    let title: String
    let count: Double
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            Text(formatQuantity(count))
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
    
    private func formatQuantity(_ quantity: Double) -> String {
        if quantity == Double(Int(quantity)) {
            return String(Int(quantity))
        } else {
            return String(format: "%.1f", quantity)
        }
    }
}

struct InventoryTypeRow: View {
    let type: String
    let quantity: Double
    let locations: [(location: String, quantity: Double)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.capitalized)
                        .font(.headline)
                    
                    if !locations.isEmpty {
                        Text("\(locations.count) location\(locations.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatQuantity(quantity))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
                    Text("units")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Show location breakdown if available
            if !locations.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(locations.sorted(by: { $0.location < $1.location }), id: \.location) { locationInfo in
                        HStack {
                            Text("• \(locationInfo.location)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatQuantity(locationInfo.quantity))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.leading, 16)
            }
        }
        .padding(.vertical, 2)
    }
    
    private func formatQuantity(_ quantity: Double) -> String {
        if quantity == Double(Int(quantity)) {
            return String(Int(quantity))
        } else {
            return String(format: "%.1f", quantity)
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleGlassItem = GlassItemModel(
        naturalKey: "bullseye-rgr-001-0",
        name: "Red Glass Rod",
        sku: "rgr-001",
        manufacturer: "bullseye",
        mfrNotes: "Beautiful red glass rods perfect for flame working",
        coe: 104,
        url: "https://bullseyeglass.com/products/red-glass-rods",
        mfrStatus: "available"
    )
    
    let inventoryTrackingService = RepositoryFactory.createInventoryTrackingService()
    
    ConsolidatedInventoryDetailView(
        glassItem: sampleGlassItem,
        inventoryTrackingService: inventoryTrackingService
    )
}

//
//  InventoryItemRowView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

// ✅ MIGRATED TO REPOSITORY PATTERN (October 2025)
//
// This view has been migrated from Core Data entities to repository pattern.
//
// CHANGES MADE:
// - Removed import CoreData and @Environment(\.managedObjectContext)
// - Updated to use InventoryItemModel instead of InventoryItem entity
// - Added CatalogService dependency injection for catalog lookups
// - Clean async/await pattern for data loading
// - Removed Core Data-specific code (NSFetchRequest, etc.)

import SwiftUI

struct InventoryItemRowView: View {
    let item: InventoryItemModel
    private let catalogService: CatalogService
    
    @State private var catalogItemName: String?
    
    init(item: InventoryItemModel, catalogService: CatalogService? = nil) {
        self.item = item
        
        // Use provided service or create default with mock repository
        if let catService = catalogService {
            self.catalogService = catService
        } else {
            let mockCatRepository = MockCatalogRepository()
            self.catalogService = CatalogService(repository: mockCatRepository)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            itemHeader
            itemDetails
            itemNotes
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle()) // Makes the entire row tappable
        .task {
            await loadCatalogItemName()
        }
    }
    
    // MARK: - View Components
    
    private var itemHeader: some View {
        HStack {
            // Main identifier - use catalog item name or fallback to catalog code/id
            Text(catalogItemName ?? item.catalogCode)
                .font(.headline)
                .lineLimit(1)
            
            Spacer()
            
            // Status indicators
            statusIndicators
        }
    }
    
    private var statusIndicators: some View {
        HStack(spacing: 8) {
            if item.quantity > 0 {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
            
            if item.quantity > 0 && item.quantity <= 10 {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
        }
    }
    
    private var itemDetails: some View {
        HStack {
            if item.quantity > 0 {
                HStack(spacing: 4) {
                    Image(systemName: item.type.systemImageName)
                        .foregroundColor(item.type.color)
                        .font(.caption)
                    
                    Text(formattedQuantity)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            
            Spacer()
        }
    }
    
    private var itemNotes: some View {
        Group {
            if let notes = item.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var formattedQuantity: String {
        // Format quantity with appropriate units
        let quantityText = String(format: "%.1f", item.quantity).replacingOccurrences(of: ".0", with: "")
        
        // For now, use a default unit display - could be enhanced with catalog lookup
        return "\(quantityText) items"
    }
    
    // MARK: - Data Loading
    
    private func loadCatalogItemName() async {
        guard !item.catalogCode.isEmpty else {
            catalogItemName = nil
            return
        }
        
        do {
            // Search for catalog item by code using repository pattern
            let catalogItems = try await catalogService.searchItems(searchText: item.catalogCode)
            
            // Find exact match by code
            if let catalogItem = catalogItems.first(where: { $0.code == item.catalogCode }) {
                await MainActor.run {
                    catalogItemName = catalogItem.name
                }
            } else {
                await MainActor.run {
                    catalogItemName = nil
                }
            }
        } catch {
            print("❌ Failed to load catalog item name: \(error)")
            await MainActor.run {
                catalogItemName = nil
            }
        }
    }
}

#Preview {
    List {
        InventoryItemRowView(
            item: InventoryItemModel(
                catalogCode: "BR-GLR-001",
                quantity: 50.0,
                type: .sell,
                notes: "High quality borosilicate glass rods for flameworking"
            )
        )
        
        InventoryItemRowView(
            item: InventoryItemModel(
                catalogCode: "FR-COL-002", 
                quantity: 200.0,
                type: .buy,
                notes: "Assorted colored frit for decoration"
            )
        )
        
        InventoryItemRowView(
            item: InventoryItemModel(
                catalogCode: "LOW-STOCK-001",
                quantity: 5.0,
                type: .inventory,
                notes: "Low stock item"
            )
        )
    }
}

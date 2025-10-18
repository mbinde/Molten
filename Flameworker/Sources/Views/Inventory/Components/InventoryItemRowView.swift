//
//  InventoryItemRowView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

// ✅ MIGRATED TO GLASSITEM ARCHITECTURE (October 2025)
//
// This view has been migrated from legacy InventoryItemModel to new GlassItem architecture.
//
// CHANGES MADE:
// - Updated to use CompleteInventoryItemModel instead of InventoryItemModel
// - Uses GlassItem data directly instead of catalog lookups
// - Simplified architecture with embedded glass item information
// - Removed unnecessary async catalog lookups
// - Updated to work with new inventory types

import SwiftUI

struct InventoryItemRowView: View {
    let completeItem: CompleteInventoryItemModel
    
    init(completeItem: CompleteInventoryItemModel) {
        self.completeItem = completeItem
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            itemHeader
            itemDetails
            itemNotes
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle()) // Makes the entire row tappable
    }
    
    // MARK: - View Components
    
    private var itemHeader: some View {
        HStack {
            // Main identifier - use glass item name
            Text(completeItem.glassItem.name)
                .font(.headline)
                .lineLimit(1)
            
            Spacer()
            
            // Status indicators
            statusIndicators
        }
    }
    
    private var statusIndicators: some View {
        HStack(spacing: 8) {
            if completeItem.totalQuantity > 0 {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
            
            if completeItem.totalQuantity > 0 && completeItem.totalQuantity <= 10 {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
        }
    }
    
    private var itemDetails: some View {
        HStack {
            if completeItem.totalQuantity > 0 {
                HStack(spacing: 4) {
                    Image(systemName: inventoryTypeIcon)
                        .foregroundColor(inventoryTypeColor)
                        .font(.caption)
                    
                    Text(formattedQuantity)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            
            // Show manufacturer and COE
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(completeItem.glassItem.manufacturer.capitalized)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("COE \(completeItem.glassItem.coe)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var itemNotes: some View {
        Group {
            if let mfr_notes = completeItem.glassItem.mfr_notes, !mfr_notes.isEmpty {
                Text(mfr_notes)
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
        let quantityText = String(format: "%.1f", completeItem.totalQuantity).replacingOccurrences(of: ".0", with: "")
        
        // Show inventory types if multiple
        if completeItem.inventory.count > 1 {
            let types = completeItem.inventory.map { $0.type }.joined(separator: ", ")
            return "\(quantityText) (\(types))"
        } else if let firstInventory = completeItem.inventory.first {
            return "\(quantityText) \(firstInventory.type)"
        } else {
            return "\(quantityText) items"
        }
    }
    
    private var inventoryTypeIcon: String {
        // Use icon based on primary inventory type
        if let primaryType = completeItem.inventory.first?.type {
            switch primaryType.lowercased() {
            case "rod", "rods":
                return "line.3.horizontal"
            case "frit":
                return "circle.grid.cross"
            case "sheet", "sheets":
                return "rectangle"
            default:
                return "cube.box"
            }
        }
        return "cube.box"
    }
    
    private var inventoryTypeColor: Color {
        // Use color based on primary inventory type
        if let primaryType = completeItem.inventory.first?.type {
            switch primaryType.lowercased() {
            case "rod", "rods":
                return .blue
            case "frit":
                return .purple
            case "sheet", "sheets":
                return .green
            default:
                return .gray
            }
        }
        return .gray
    }
}

// MARK: - Legacy Support

/// Legacy wrapper for backward compatibility during migration
@available(*, deprecated, message: "Use InventoryItemRowView with CompleteInventoryItemModel instead")
struct LegacyInventoryItemRowView: View {
    var body: some View {
        Text("Legacy inventory item view - please migrate to new architecture")
            .foregroundColor(.red)
            .italic()
    }
}

#Preview {
    let sampleGlassItem = GlassItemModel(
        natural_key: "bullseye-254-0",
        name: "Red Transparent",
        sku: "254",
        manufacturer: "bullseye",
        mfr_notes: "Beautiful deep red transparent glass",
        coe: 90,
        url: "https://bullseyeglass.com",
        mfr_status: "available"
    )
    
    let sampleInventory = [
        InventoryModel(
            item_natural_key: "bullseye-254-0",
            type: "rod",
            quantity: 50.0
        ),
        InventoryModel(
            item_natural_key: "bullseye-254-0",
            type: "frit",
            quantity: 10.0
        )
    ]
    
    let completeItem = CompleteInventoryItemModel(
        glassItem: sampleGlassItem,
        inventory: sampleInventory,
        tags: ["transparent", "red", "bullseye"],
        userTags: [],
        locations: []
    )
    
    List {
        InventoryItemRowView(completeItem: completeItem)
        
        // Another example with different data
        InventoryItemRowView(
            completeItem: CompleteInventoryItemModel(
                glassItem: GlassItemModel(
                    natural_key: "spectrum-96-0",
                    name: "Clear Borosilicate",
                    sku: "96",
                    manufacturer: "spectrum",
                    mfr_notes: "High quality borosilicate glass",
                    coe: 96,
                    url: nil,
                    mfr_status: "available"
                ),
                inventory: [
                    InventoryModel(
                        item_natural_key: "spectrum-96-0",
                        type: "sheet",
                        quantity: 5.0
                    )
                ],
                tags: ["clear", "borosilicate"],
                userTags: [],
                locations: []
            )
        )
    }
}

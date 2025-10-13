//
//  InventoryViewComponents.swift
//  Flameworker
//
//  Created by Assistant on 9/29/25.
//  Migrated to Repository Pattern on 10/12/25 - Removed Core Data dependencies
//

import SwiftUI
import Foundation

// MARK: - Release Configuration
// Set to false for simplified release builds  
private let isAdvancedImageLoadingEnabled = false

/// Reusable components for inventory-related views using repository pattern

// MARK: - Status Indicators

struct InventoryStatusIndicators: View {
    let hasInventory: Bool
    let lowStock: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            if hasInventory {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
            }
            
            if lowStock {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
            }
        }
    }
}

// MARK: - Inventory Section Views

struct InventoryCountUnitsView: View {
    let count: Double
    let units: CatalogUnits
    let type: InventoryItemType
    let isEditing: Bool
    @Binding var countBinding: String
    @Binding var unitsBinding: String
    
    var body: some View {
        if isEditing {
            HStack {
                TextField("Count", text: $countBinding)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                
                TextField("Units", text: $unitsBinding)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
            }
        } else {
            if count > 0 {
                HStack {
                    Image(systemName: type.systemImageName)
                        .foregroundColor(type.color)
                    Text("\(String(format: "%.1f", count)) \(units.displayName) (\(type.displayName))")
                        .font(.body)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

struct InventoryNotesView: View {
    let notes: String?
    let isEditing: Bool
    @Binding var notesBinding: String
    
    var body: some View {
        if isEditing {
            TextField("Notes", text: $notesBinding, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
                .textInputAutocapitalization(.sentences)
        } else {
            if let notes = notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(notes)
                        .font(.body)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

struct InventorySectionView: View {
    let title: String
    let icon: String
    let color: Color
    let count: Double
    let units: CatalogUnits
    let type: InventoryItemType
    let notes: String?
    let isEditing: Bool
    
    @Binding var countBinding: String
    @Binding var unitsBinding: String
    @Binding var notesBinding: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(color)
            
            InventoryCountUnitsView(
                count: count,
                units: units,
                type: type,
                isEditing: isEditing,
                countBinding: $countBinding,
                unitsBinding: $unitsBinding
            )
            
            InventoryNotesView(
                notes: notes,
                isEditing: isEditing,
                notesBinding: $notesBinding
            )
        }
    }
}

// MARK: - Grid Item Views

struct InventoryGridItemView: View {
    let title: String
    let icon: String
    let color: Color
    let count: Double
    let units: CatalogUnits
    let type: InventoryItemType
    let itemCode: String? // Add item code for image loading
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Product image if available, otherwise use icon
            HStack {
                if isAdvancedImageLoadingEnabled,
                   let itemCode = itemCode, 
                   ImageHelpers.productImageExists(for: itemCode) {
                    ProductImageThumbnail(itemCode: itemCode, size: 30)
                } else {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.title3)
                        .frame(width: 30, height: 30)
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                if count > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: type.systemImageName)
                            .foregroundColor(type.color)
                            .font(.caption2)
                        Text("\(String(format: "%.1f", count)) \(units.displayName)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(8)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Repository Pattern Extensions for InventoryItemModel

// Extension providing inventory status logic for repository pattern models
extension InventoryItemModel {
    var hasInventory: Bool {
        quantity > 0
    }
    
    var isLowStock: Bool {
        quantity > 0 && quantity <= 10.0 // Consider items with count <= 10 as low stock
    }
    
    var hasNotes: Bool {
        guard let notes = notes else { return false }
        return !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var hasAnyData: Bool {
        hasInventory || hasNotes
    }
}

// MARK: - Convenience View Extensions

extension View {
    /// Creates a consistent detail row layout
    func detailRowStyle() -> some View {
        self
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Data Validation Helpers

struct InventoryDataValidator {
    static func hasInventoryData(_ item: InventoryItemModel) -> Bool {
        return item.hasInventory || item.hasNotes
    }
    
    static func formatInventoryDisplay(count: Double, units: CatalogUnits, type: InventoryItemType, notes: String?) -> String? {
        var display = ""
        
        if count > 0 {
            let formattedCount = String(format: "%.1f", count)
            display += "\(formattedCount) \(units.displayName) (\(type.displayName))"
        }
        
        if let notes = notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if !display.isEmpty {
                display += " • "
            }
            display += notes
        }
        
        return display.isEmpty ? nil : display
    }
}



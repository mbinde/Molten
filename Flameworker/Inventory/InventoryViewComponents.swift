//
//  InventoryViewComponents.swift
//  Flameworker
//
//  Created by Assistant on 9/29/25.
//

import SwiftUI
import CoreData

/// Reusable components for inventory-related views

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
    let units: Int16
    let type: Int16
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
                    Image(systemName: InventoryItemType(from: type).systemImageName)
                        .foregroundColor(InventoryItemType(from: type).color)
                    Text("\(String(format: "%.1f", count)) \(InventoryUnits(from: units).displayName) (\(InventoryItemType(from: type).displayName))")
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
    let units: Int16
    let type: Int16
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
    let units: Int16
    let type: Int16
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            if count > 0 {
                HStack(spacing: 4) {
                    Image(systemName: InventoryItemType(from: type).systemImageName)
                        .foregroundColor(InventoryItemType(from: type).color)
                        .font(.caption2)
                    Text("\(String(format: "%.1f", count)) \(InventoryUnits(from: units).displayName) (\(InventoryItemType(from: type).displayName))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Protocol Extensions for Core Data Entities

// Extension providing inventory status logic
extension InventoryItem {
    var hasInventory: Bool {
        count > 0
    }
    
    var isLowStock: Bool {
        count > 0 && count <= 10.0 // Consider items with count <= 10 as low stock
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
    static func hasInventoryData(_ item: InventoryItem) -> Bool {
        return item.hasInventory || item.hasNotes
    }
    
    static func formatInventoryDisplay(count: Double, units: Int16, type: Int16, notes: String?) -> String? {
        var display = ""
        
        if count > 0 {
            let formattedCount = String(format: "%.1f", count)
            let itemType = InventoryItemType(from: type)
            let unitName = InventoryUnits(from: units).displayName
            display += "\(formattedCount) \(unitName) (\(itemType.displayName))"
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



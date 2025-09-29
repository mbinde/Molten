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
    let needsShopping: Bool
    let isForSale: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            if hasInventory {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
            }
            
            if needsShopping {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
            }
            
            if isForSale {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            }
        }
    }
}

// MARK: - Inventory Section Views

struct InventoryAmountUnitsView: View {
    let amount: String?
    let units: String?
    let isEditing: Bool
    @Binding var amountBinding: String
    @Binding var unitsBinding: String
    
    var body: some View {
        if isEditing {
            HStack {
                TextField("Amount", text: $amountBinding)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numbersAndPunctuation)
                
                TextField("Units", text: $unitsBinding)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
            }
        } else {
            if let amount = amount, !amount.isEmpty {
                Text("\(amount) \(units ?? "")")
                    .font(.body)
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
    let amount: String?
    let units: String?
    let notes: String?
    let isEditing: Bool
    
    @Binding var amountBinding: String
    @Binding var unitsBinding: String
    @Binding var notesBinding: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(color)
            
            InventoryAmountUnitsView(
                amount: amount,
                units: units,
                isEditing: isEditing,
                amountBinding: $amountBinding,
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
    let amount: String?
    let units: String?
    
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
            if let amount = amount, !amount.isEmpty {
                Text("\(amount) \(units ?? "")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Protocol Extensions for Views

extension InventoryItem: DisplayableEntity, InventoryDataEntity {
    // DisplayableEntity conformance - already implemented by Core Data
    
    // InventoryDataEntity conformance - already implemented by Core Data
    
    // Override the custom_tags implementation for the protocol
    var custom_tags_for_protocol: String? { custom_tags }
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
    static func hasInventoryData(_ item: InventoryDataEntity) -> Bool {
        return item.hasInventory || item.needsShopping || item.isForSale
    }
    
    static func createNotesPreview(
        inventory: String?,
        shopping: String?,
        forsale: String?
    ) -> String? {
        let allNotes = [inventory, shopping, forsale]
            .compactMap { $0 }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " • ")
        
        return allNotes.isEmpty ? nil : allNotes
    }
}
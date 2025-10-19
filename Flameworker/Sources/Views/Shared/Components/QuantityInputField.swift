//
//  QuantityInputField.swift
//  Flameworker
//
//  Created by Assistant on 10/5/25.
//  Migrated to Repository Pattern on 10/12/25 - Removed Core Data dependencies
//

import SwiftUI

/// Unified quantity input field that displays units from catalog item model
struct QuantityInputField: View {
    @Binding var quantity: String
    let catalogItem: CatalogItemModel?
    
    // Get units from catalog item model, with fallback to rods
    private var displayUnits: String {
        guard let catalogItem = catalogItem else {
            return CatalogUnits.rods.displayName
        }
        
        // For now, default to rods since CatalogItemModel doesn't have units field yet
        // TODO: Add units field to CatalogItemModel when catalog schema is updated
        return CatalogUnits.rods.displayName
    }
    
    var body: some View {
        HStack {
            Text("Number of \(displayUnits.lowercased()):")
                .font(.subheadline)
                .fontWeight(.medium)
            
            TextField("Enter quantity", text: $quantity)
                #if canImport(UIKit)
                .keyboardType(.decimalPad)
                #endif
                .textFieldStyle(.roundedBorder)
        }
    }
}

#Preview {
    QuantityInputField(
        quantity: .constant("5"),
        catalogItem: nil
    )
    .padding()
}

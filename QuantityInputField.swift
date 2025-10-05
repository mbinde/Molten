//
//  QuantityInputField.swift
//  Flameworker
//
//  Created by Assistant on 10/5/25.
//

import SwiftUI
import CoreData

/// Unified quantity input field that displays units from catalog item
struct QuantityInputField: View {
    @Binding var quantity: String
    let catalogItem: CatalogItem?
    
    // Get units from catalog item, with fallback to rods
    private var displayUnits: String {
        guard let catalogItem = catalogItem else {
            return InventoryUnits.rods.displayName
        }
        
        if catalogItem.units == 0 {
            return InventoryUnits.rods.displayName
        }
        
        let units = InventoryUnits(rawValue: catalogItem.units) ?? .rods
        return units.displayName
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Number of \(displayUnits.lowercased())")
                .font(.subheadline)
                .fontWeight(.medium)
            TextField("Enter quantity", text: $quantity)
                .keyboardType(.decimalPad)
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
//
//  AddInventoryItemView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import SwiftUI
import CoreData

struct AddInventoryItemView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let prefilledCatalogCode: String?
    
    init(prefilledCatalogCode: String? = nil) {
        self.prefilledCatalogCode = prefilledCatalogCode
    }
    
    var body: some View {
        AddInventoryFormView(prefilledCatalogCode: prefilledCatalogCode)
    }
}

struct AddInventoryFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let prefilledCatalogCode: String?
    
    @State private var catalogCode: String = ""
    @State private var catalogItem: CatalogItem?
    @State private var quantity: String = ""
    @State private var selectedUnits: InventoryUnits = .rods
    @State private var selectedType: InventoryItemType = .inventory
    @State private var notes: String = ""
    
    init(prefilledCatalogCode: String? = nil) {
        self.prefilledCatalogCode = prefilledCatalogCode
    }
    
    var body: some View {
        Form {
            Section("Catalog Item") {
                HStack {
                    TextField("Catalog Code", text: $catalogCode)
                    if let catalogItem = catalogItem {
                        Text(catalogItem.name ?? "Unknown Item")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Inventory Details") {
                TextField("Quantity", text: $quantity)
                    .keyboardType(.decimalPad)
                
                Picker("Units", selection: $selectedUnits) {
                    ForEach(InventoryUnits.allCases, id: \.self) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                
                Picker("Type", selection: $selectedType) {
                    ForEach(InventoryItemType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
            }
            
            Section("Additional Info") {
                TextField("Notes (optional)", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle("Add Inventory Item")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveInventoryItem()
                }
                .disabled(catalogCode.isEmpty || quantity.isEmpty)
            }
        }
        .onAppear {
            setupPrefilledData()
        }
        .onChange(of: catalogCode) { _, newValue in
            lookupCatalogItem(code: newValue)
        }
    }
    
    private func setupPrefilledData() {
        if let prefilledCode = prefilledCatalogCode {
            print("🔍 Received prefilled code: '\(prefilledCode)'")
            
            let cleanedCode = _cleanCatalogCode(prefilledCode)
            print("🧹 Cleaned code: '\(cleanedCode)'")
            
            catalogCode = cleanedCode
            lookupCatalogItem(code: cleanedCode)
        }
    }
    
    private func lookupCatalogItem(code: String) {
        let request: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        request.predicate = NSPredicate(format: "code == %@", code)
        
        do {
            let items = try viewContext.fetch(request)
            catalogItem = items.first
        } catch {
            print("Error fetching catalog item: \(error)")
            catalogItem = nil
        }
    }
    
    private func saveInventoryItem() {
        // Basic validation
        guard !catalogCode.isEmpty, !quantity.isEmpty else { return }
        
        // Convert quantity string to double
        guard let quantityValue = Double(quantity) else {
            print("Invalid quantity format")
            return
        }
        
        // Create new inventory item
        let newItem = InventoryItem(context: viewContext)
        newItem.id = UUID().uuidString
        newItem.catalog_code = catalogCode
        newItem.count = quantityValue
        newItem.units = selectedUnits.rawValue
        newItem.type = selectedType.rawValue
        newItem.notes = notes.isEmpty ? nil : notes
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving inventory item: \(error)")
        }
    }
    
    private func cleanCatalogCode(_ code: String) -> String {
        // Handle different catalog code formats:
        // "Effetre-ABC123" -> "ABC123" 
        // "ABC123" -> "ABC123" (unchanged)
        // Remove manufacturer prefix if present (separated by dash)
        
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Look for manufacturer-code pattern
        if let dashIndex = trimmedCode.firstIndex(of: "-") {
            let codeAfterDash = String(trimmedCode[trimmedCode.index(after: dashIndex)...])
            return codeAfterDash.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return trimmedCode
    }
    
    private func _cleanCatalogCode(_ code: String) -> String {
        // Remove manufacturer prefix if present
        // Example: "Effetre-ABC123" -> "ABC123"
        let components = code.split(separator: "-", maxSplits: 1)
        if components.count > 1 {
            return String(components[1])
        }
        return code
    }
}

#Preview {
    NavigationStack {
        AddInventoryItemView()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

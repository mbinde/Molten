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
    @State private var searchText: String = ""
    @State private var showingCatalogSearch: Bool = false
    @State private var quantity: String = ""
    @State private var selectedUnits: InventoryUnits = .rods
    @State private var selectedType: InventoryItemType = .inventory
    @State private var notes: String = ""
    
    @FetchRequest(
        entity: CatalogItem.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \CatalogItem.name, ascending: true)]
    ) private var catalogItems: FetchedResults<CatalogItem>
    
    init(prefilledCatalogCode: String? = nil) {
        self.prefilledCatalogCode = prefilledCatalogCode
    }
    
    // Filtered catalog items for search
    private var filteredCatalogItems: [CatalogItem] {
        if searchText.isEmpty {
            return Array(catalogItems)
        } else {
            return catalogItems.filter { item in
                let searchLower = searchText.lowercased()
                let nameMatch = item.name?.lowercased().contains(searchLower) ?? false
                let codeMatch = item.code?.lowercased().contains(searchLower) ?? false
                return nameMatch || codeMatch
            }
        }
    }
    
    var body: some View {
        Form {
            Section("Catalog Item") {
                if prefilledCatalogCode != nil {
                    // Show traditional text field when prefilled code is provided
                    HStack {
                        TextField("Catalog Code", text: $catalogCode)
                        if let catalogItem = catalogItem {
                            Text(catalogItem.name ?? "Unknown Item")
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    // Show searchable catalog item selection when no prefilled code
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("Search catalog items...", text: $searchText)
                                .textFieldStyle(.roundedBorder)
                                .disabled(catalogItem != nil) // Disable search when item is selected
                        }
                        
                        if catalogItem != nil {
                            // Show selected item using catalog row format
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Selected:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Button("Clear") {
                                        clearSelection()
                                    }
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                }
                                
                                // Use the same row format as catalog list view
                                CatalogItemRowView(item: catalogItem!)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color.green.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.green, lineWidth: 1)
                                    )
                                    .cornerRadius(8)
                            }
                        } else if !searchText.isEmpty {
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 4) {
                                    ForEach(filteredCatalogItems.prefix(10), id: \.objectID) { item in
                                        Button {
                                            selectCatalogItem(item)
                                        } label: {
                                            CatalogItemRowView(item: item)
                                                .padding(.vertical, 4)
                                                .padding(.horizontal, 8)
                                                .background(Color(.systemGray6).opacity(0.5))
                                                .cornerRadius(6)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                            .frame(maxHeight: 300)
                        }
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
    
    private func selectCatalogItem(_ item: CatalogItem) {
        catalogItem = item
        catalogCode = item.code ?? ""
        // Keep the search text to show what was searched, but disable further searching
    }
    
    private func clearSelection() {
        catalogItem = nil
        catalogCode = ""
        searchText = ""
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

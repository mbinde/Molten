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
    @State private var selectedType: InventoryItemType = .inventory
    @State private var notes: String = ""
    @State private var location: String = ""
    
    // Read current inventory filter settings to check if item might be hidden
    @AppStorage("selectedInventoryFilters") private var selectedInventoryFiltersData: Data = Data()
    
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
    
    // Get units from selected catalog item, with fallback to rods
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
        Form {
            Section("Catalog Item") {
                VStack(alignment: .leading, spacing: 8) {
                    // Only show search field if no prefilled code is provided
                    if prefilledCatalogCode == nil {
                        TextField("Search catalog items...", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .disabled(catalogItem != nil) // Disable search when item is selected
                    }
                    
                    if catalogItem != nil {
                        // Show selected item using consistent catalog row format
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(prefilledCatalogCode != nil ? "Adding inventory for:" : "Selected:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                // Only show clear button if not prefilled
                                if prefilledCatalogCode == nil {
                                    Button("Clear") {
                                        clearSelection()
                                    }
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                }
                            }
                            
                            // Enhanced display with image if available
                            HStack(alignment: .top, spacing: 12) {
                                // Product image if available
                                if let catalogItem = catalogItem,
                                   let itemCode = catalogItem.code,
                                   ImageHelpers.productImageExists(for: itemCode) {
                                    ProductImageDetail(itemCode: itemCode, maxSize: 80)
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                
                                // Use the same row format for both prefilled and selected items
                                VStack(alignment: .leading, spacing: 8) {
                                    CatalogItemRowView(item: catalogItem!)
                                        .frame(maxWidth: .infinity)
                                    
                                    // Display tags if the catalog item has them
                                    if let tagsValue = catalogItem!.value(forKey: "tags") as? String,
                                       !tagsValue.isEmpty {
                                        let tags = tagsValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                        if !tags.isEmpty {
                                            HStack {
                                                Text("Tags:")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                
                                                ScrollView(.horizontal, showsIndicators: false) {
                                                    HStack(spacing: 6) {
                                                        ForEach(tags, id: \.self) { tag in
                                                            Text(tag)
                                                                .font(.caption)
                                                                .padding(.horizontal, 8)
                                                                .padding(.vertical, 4)
                                                                .background(Color.blue.opacity(0.1))
                                                                .foregroundColor(.blue)
                                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                        }
                                                    }
                                                    .padding(.horizontal, 1)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background((prefilledCatalogCode != nil ? Color.blue : Color.green).opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(prefilledCatalogCode != nil ? Color.blue : Color.green, lineWidth: 1)
                        )
                        .cornerRadius(8)
                    } else if !searchText.isEmpty && prefilledCatalogCode == nil {
                        // Show search results only if no prefilled code and user is searching
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
                    } else if catalogItem == nil && prefilledCatalogCode != nil {
                        // Fallback message if prefilled item couldn't be found
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Item not found in catalog")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Code: \(prefilledCatalogCode!)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.orange, lineWidth: 1)
                        )
                        .cornerRadius(8)
                    } else if catalogItem == nil && prefilledCatalogCode == nil {
                        // Show instruction text when no item selected and no search
                        Text("Search above to find a catalog item")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    }
                }
            }
            
            Section("Inventory Details") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Quantity")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            TextField("Enter quantity", text: $quantity)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Units")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(displayUnits)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Add to my")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Picker("Type", selection: $selectedType) {
                        ForEach(InventoryItemType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            
            Section("Additional Info") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Location (optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    LocationAutoCompleteField(location: $location, context: viewContext)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes (optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
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
            print("🔍 Original code length: \(prefilledCode.count)")
            print("🔍 Original code characters: \(Array(prefilledCode))")
            
            // Don't clean prefilled codes - use them exactly as provided
            // The consolidated inventory already has the correct catalog code
            catalogCode = prefilledCode
            lookupCatalogItem(code: prefilledCode)
        }
    }
    
    private func lookupCatalogItem(code: String) {
        print("🔎 Looking up catalog item with code: '\(code)'")
        
        catalogItem = CatalogCodeLookup.findCatalogItem(byCode: code, in: viewContext)
        
        if catalogItem == nil {
            print("🔍 No catalog item found for code: '\(code)'")
            
            // Let's also try a broader search to see what catalog items exist
            let broadRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
            broadRequest.fetchLimit = 50  // Get more samples
            do {
                let allItems = try viewContext.fetch(broadRequest)
                print("📋 Found \(allItems.count) total catalog items in database")
                print("📋 Looking for items containing 'NS' or '143':")
                let matchingItems = allItems.filter { item in
                    let id = item.id?.lowercased() ?? ""
                    let code = item.code?.lowercased() ?? ""
                    let name = item.name?.lowercased() ?? ""
                    return id.contains("ns") || code.contains("ns") || 
                           id.contains("143") || code.contains("143") || 
                           name.contains("143")
                }
                for item in matchingItems {
                    print("   🎯 MATCH: id: '\(item.id ?? "nil")', code: '\(item.code ?? "nil")', name: '\(item.name ?? "nil")'")
                }
                if matchingItems.isEmpty {
                    print("   ❌ No items found containing 'NS' or '143'")
                }
            } catch {
                print("❌ Error fetching catalog items: \(error)")
            }
        } else {
            print("✅ Found catalog item: '\(catalogItem?.name ?? "Unknown")' for code: '\(code)'")
            print("   - id: '\(catalogItem?.id ?? "nil")'")
            print("   - code: '\(catalogItem?.code ?? "nil")'")
            print("   - name: '\(catalogItem?.name ?? "nil")'")
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
        newItem.type = selectedType.rawValue
        newItem.notes = notes.isEmpty ? nil : notes
        newItem.location = location.isEmpty ? nil : location
        
        do {
            try viewContext.save()
            
            // Generate success message for inventory view
            let itemName = catalogItem?.name ?? catalogCode
            let quantityText = String(format: "%.1f", quantityValue).replacingOccurrences(of: ".0", with: "")
            let baseMessage = "\(itemName) (\(quantityText) items) added to \(selectedType.displayName.lowercased()) inventory."
            let filteringMessage = checkIfItemWouldBeFiltered()
            
            let fullMessage = filteringMessage.isEmpty ? baseMessage : baseMessage + " " + filteringMessage.replacingOccurrences(of: "Note: ", with: "")
            
            // Post notification for inventory view to show toast
            NotificationCenter.default.post(
                name: .inventoryItemAdded, 
                object: nil, 
                userInfo: ["message": fullMessage]
            )
            
            // Immediately dismiss for faster batch entry
            dismiss()
            
        } catch {
            print("Error saving inventory item: \(error)")
        }
    }
    
    private func checkIfItemWouldBeFiltered() -> String {
        // Get current inventory filter settings
        guard !selectedInventoryFiltersData.isEmpty else {
            // No filter data means default (all types shown)
            return ""
        }
        
        // Try to decode current filter settings (stored as array of InventoryFilterType)
        guard let currentFilterTypes = try? JSONDecoder().decode([InventoryFilterType].self, from: selectedInventoryFiltersData) else {
            return ""
        }
        
        // Convert InventoryItemType to InventoryFilterType for comparison
        let filterTypeForItem: InventoryFilterType
        switch selectedType {
        case .inventory:
            filterTypeForItem = .inventory
        case .buy:
            filterTypeForItem = .buy
        case .sell:
            filterTypeForItem = .sell
        }
        
        // Check if current filter settings would hide this item type
        if !currentFilterTypes.contains(filterTypeForItem) {
            return "Note: This item may not be visible in your inventory list due to your current filter settings. Check your inventory filters if you don't see the new item."
        }
        
        return ""
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

//
//  CatalogItemDetailView.swift
//  Flameworker
//
//  Intelligently Combined and Enhanced Version
//  Created by Assistant on 10/01/25.
//

import SwiftUI
import CoreData

struct CatalogItemDetailView: View {
    let item: CatalogItem
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // Fetch related inventory items using comprehensive matching
    private var inventoryItems: [InventoryItem] {
        let catalogCode = item.code
        let catalogId = item.id
        
        let fetchRequest: NSFetchRequest<InventoryItem> = InventoryItem.fetchRequest()
        
        // Build compound predicate to search in multiple fields
        var predicates: [NSPredicate] = []
        
        // Match by catalog_code (exact and contains)
        if let code = catalogCode, !code.isEmpty {
            predicates.append(NSPredicate(format: "catalog_code == %@", code))
            predicates.append(NSPredicate(format: "catalog_code CONTAINS[cd] %@", code))
        }
        
        // Match by catalog ID
        if let id = catalogId, !id.isEmpty {
            predicates.append(NSPredicate(format: "catalog_code == %@", id))
            predicates.append(NSPredicate(format: "catalog_code CONTAINS[cd] %@", id))
        }
        
        guard !predicates.isEmpty else { return [] }
        
        // Use compound OR predicate
        fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \InventoryItem.count, ascending: false)]
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("❌ Failed to fetch inventory items: \(error)")
            return []
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header section
                    headerSection
                    
                    // Main details
                    mainDetailsSection
                    
                    // Additional information
                    additionalInfoSection
                    
                    // Inventory Section - Show based on availability
                    if !inventoryItems.isEmpty {
                        inventorySection
                    } else {
                        noInventorySection
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle(item.name ?? "Unknown Item")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - View Sections
    
    @ViewBuilder
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name ?? "Unknown Item")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let code = item.code {
                    Text("Code: \(code)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Color indicator for manufacturer using unified system
            Circle()
                .fill(manufacturerColor)
                .frame(width: 24, height: 24)
        }
        .catalogDetailRowStyle()
    }
    
    @ViewBuilder
    private var mainDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Manufacturer section with optional URL link
            if let manufacturer = item.manufacturer, !manufacturer.isEmpty {
                manufacturerSection(manufacturer: manufacturer)
            }
            
            // COE information
            if let coe = coeDisplayValue {
                sectionView(title: "COE", content: coe)
            }
            
            // Start and end dates
            if let startDate = item.start_date {
                sectionView(title: "Available From", content: formatDate(startDate))
            }
            
            if let endDate = item.end_date {
                sectionView(title: "Available Until", content: formatDate(endDate))
            }
        }
    }
    
    @ViewBuilder
    private var additionalInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Description
            if let description = manufacturerDescription, !description.isEmpty {
                sectionView(title: "Description", content: description)
            }
            
            // Tags
            if !tagsArray.isEmpty {
                tagsSection(tags: tagsArray)
            }
            
            // Synonyms
            if !synonymsArray.isEmpty {
                sectionView(title: "Also Known As", content: synonymsArray.joined(separator: ", "))
            }
            
            // Stock type
            if let stockType = stockType, !stockType.isEmpty {
                sectionView(title: "Stock Type", content: stockType)
            }
        }
    }
    
    @ViewBuilder
    private func manufacturerSection(manufacturer: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Manufacturer")
                .font(.headline)
            
            HStack(spacing: 8) {
                // Show full name if available, fallback to provided value
                Text(manufacturerFullName ?? manufacturer)
                    .font(.body)
                
                // Show link icon and make clickable if manufacturer_url exists
                if let url = manufacturerURL {
                    Button(action: {
                        UIApplication.shared.open(url)
                    }) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.body)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
        }
        .catalogDetailRowStyle()
    }
    
    @ViewBuilder
    private func tagsSection(tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 80), alignment: .leading)
            ], alignment: .leading, spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .catalogDetailRowStyle()
    }
    
    // MARK: - Inventory Sections
    
    @ViewBuilder
    private var inventorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Inventory")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Summary badge
                Text("\(inventoryItems.count) item\(inventoryItems.count == 1 ? "" : "s")")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .clipShape(Capsule())
            }
            
            // Inventory items list
            VStack(spacing: 0) {
                ForEach(inventoryItems, id: \.objectID) { inventoryItem in
                    NavigationLink {
                        InventoryItemDetailView(item: inventoryItem)
                    } label: {
                        InventoryItemRowView(item: inventoryItem)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(.systemBackground))
                    }
                    .buttonStyle(.plain)
                    
                    // Add divider between items (except for last item)
                    if inventoryItem != inventoryItems.last {
                        Divider()
                            .padding(.horizontal, 16)
                    }
                }
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    @ViewBuilder
    private var noInventorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Inventory")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                Image(systemName: "archivebox")
                    .font(.system(size: 40))
                    .foregroundColor(.primary.opacity(0.6))
                
                Text("No Inventory Items")
                    .font(.headline)
                    .foregroundColor(.primary.opacity(0.8))
                
                Text("You don't have any inventory items for this catalog item yet.")
                    .font(.subheadline)
                    .foregroundColor(.primary.opacity(0.7))
                    .multilineTextAlignment(.center)

                Text("Add some to get started, either as inventory you have or as part of your shopping list.")
                    .font(.subheadline)
                    .foregroundColor(.primary.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionView(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.body)
        }
        .catalogDetailRowStyle()
    }
    
    // MARK: - Computed Properties (Unified Data Access)
    
    private var manufacturerColor: Color {
        // Use unified GlassManufacturers if available, otherwise fallback to CatalogItemHelpers
        if let manufacturer = item.manufacturer {
            return GlassManufacturers.colorForManufacturer(manufacturer)
        }
        return .secondary
    }
    
    private var manufacturerFullName: String? {
        guard let manufacturer = item.manufacturer else { return nil }
        return GlassManufacturers.fullName(for: manufacturer)
    }
    
    private var manufacturerDescription: String? {
        return item.value(forKey: "manufacturer_description") as? String
    }
    
    private var synonymsArray: [String] {
        guard let synonymsString = item.value(forKey: "synonyms") as? String, 
              !synonymsString.isEmpty else { return [] }
        
        return synonymsString.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    private var tagsArray: [String] {
        guard let tagsString = item.value(forKey: "tags") as? String, 
              !tagsString.isEmpty else { return [] }
        
        return tagsString.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    private var coeDisplayValue: String? {
        if let coe = item.value(forKey: "coe") as? Int {
            return String(coe)
        } else if let coe = item.value(forKey: "coe") as? String, !coe.isEmpty {
            return coe
        }
        return nil
    }
    
    private var stockType: String? {
        guard let stockType = item.value(forKey: "stock_type") as? String,
              !stockType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return stockType
    }
    
    private var manufacturerURL: URL? {
        guard let urlString = item.value(forKey: "manufacturer_url") as? String,
              !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let url = URL(string: urlString) else {
            return nil
        }
        return url
    }
    
    // MARK: - Utility Functions
    
    private func formatDate(_ date: Date, style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - View Style Extension (Unified naming to resolve conflicts)

extension View {
    func catalogDetailRowStyle() -> some View {
        self
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let sampleItem = CatalogItem(context: context)
    sampleItem.name = "Sample Glass Color"
    sampleItem.code = "EFF001"
    sampleItem.manufacturer = "EF"
    sampleItem.setValue("transparent,clear,colorless", forKey: "tags")
    sampleItem.setValue("crystal,white", forKey: "synonyms")
    sampleItem.setValue("104", forKey: "coe")
    sampleItem.setValue("images/eff001.jpg", forKey: "image_path")
    sampleItem.setValue("COE 104 and compatible with our other COE 104 glass!", forKey: "manufacturer_description")
    sampleItem.setValue("https://example.com/manufacturer", forKey: "manufacturer_url")
    
    return CatalogItemDetailView(item: sampleItem)
        .environment(\.managedObjectContext, context)
}

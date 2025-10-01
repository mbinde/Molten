//
//  CatalogItemDetailView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import SwiftUI
import CoreData

struct CatalogItemDetailView: View {
    let item: CatalogItem
    @Environment(\.managedObjectContext) private var viewContext
    
    // Fetch related inventory items
    private var inventoryItems: [InventoryItem] {
        // Try multiple matching strategies
        let catalogCode = item.code
        let catalogId = item.id
        
        let fetchRequest: NSFetchRequest<InventoryItem> = InventoryItem.fetchRequest()
        
        // Build a compound predicate to search in multiple fields
        var predicates: [NSPredicate] = []
        
        // Match by catalog_code
        if let code = catalogCode, !code.isEmpty {
            predicates.append(NSPredicate(format: "catalog_code == %@", code))
            predicates.append(NSPredicate(format: "catalog_code CONTAINS[cd] %@", code))
        }
        
        // Match by catalog ID
        if let id = catalogId, !id.isEmpty {
            predicates.append(NSPredicate(format: "catalog_code == %@", id))
            predicates.append(NSPredicate(format: "catalog_code CONTAINS[cd] %@", id))
        }
        
        // If no predicates, return empty array
        guard !predicates.isEmpty else {
            return []
        }
        
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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Catalog Item Information
                catalogInfoSection
                
                // Inventory Section
                if !inventoryItems.isEmpty {
                    inventorySection
                } else {
                    noInventorySection
                }
                
                Spacer(minLength: 20)
            }
            .padding()
        }
        .navigationTitle("Item Details")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
    
    // MARK: - Catalog Info Section
    private var catalogInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Catalog Information")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(item.name ?? "Unknown")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("Code: \(item.code ?? "N/A")")
                    .foregroundColor(.primary.opacity(0.8))
                
                Text("Manufacturer: \(GlassManufacturers.fullName(for: item.manufacturer ?? "") ?? item.manufacturer ?? "N/A")")
                    .foregroundColor(.primary.opacity(0.8))
                
                // Display manufacturer description if available
                if let manufacturerDescription = item.value(forKey: "manufacturer_description") as? String, 
                   !manufacturerDescription.isEmpty {
                    Text(manufacturerDescription)
                        .font(.subheadline)
                        .foregroundColor(.primary.opacity(0.7))
                        .italic()
                        .padding(.top, 2)
                }
                
                // Display COE if available
                if let coe = item.value(forKey: "coe") as? String, !coe.isEmpty {
                    Text("COE: \(coe)")
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                // Display image path if available
                if let imagePath = item.value(forKey: "image_path") as? String, !imagePath.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Image:")
                            .fontWeight(.medium)
                            .foregroundColor(.primary.opacity(0.9))
                        Text(imagePath)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                
                // Display tags
                let tags = CatalogItemHelpers.tagsArrayForItem(item)
                if !tags.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Text("Tags:")
                            .fontWeight(.medium)
                            .foregroundColor(.primary.opacity(0.9))
                        
                        // Simple horizontal flow of tags
                        HStack(spacing: 6) {
                            ForEach(tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .clipShape(Capsule())
                            }
                        }
                        
                        Spacer()
                    }
                }
                
                // Display synonyms
                let synonyms = CatalogItemHelpers.synonymsArrayForItem(item)
                if !synonyms.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Synonyms:")
                            .fontWeight(.medium)
                            .foregroundColor(.primary.opacity(0.9))
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                            ForEach(synonyms, id: \.self) { synonym in
                                Text(synonym)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.green.opacity(0.1))
                                    .foregroundColor(.green)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Inventory Section
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
            
            // Inventory items list using the exact same component as inventory screen
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
    
    // MARK: - No Inventory Section
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
}

#Preview {
    NavigationStack {
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
        
        return CatalogItemDetailView(item: sampleItem)
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

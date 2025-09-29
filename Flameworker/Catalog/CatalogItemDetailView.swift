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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.name ?? "Unknown")
                .font(.title2)
                .fontWeight(.bold)
            Text("Code: \(item.code ?? "N/A")")
                .foregroundColor(.secondary)
            Text("Manufacturer: \(item.manufacturer ?? "N/A")")
                .foregroundColor(.secondary)
            
            // Display COE if available
            if let coe = item.value(forKey: "coe") as? String, !coe.isEmpty {
                Text("COE: \(coe)")
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
            }
            if let startDate = item.start_date {
                Text("Available from: \(startDate, formatter: CatalogFormatters.itemFormatter)")
                    .foregroundColor(.secondary)
            }
            
            // Display image path if available
            if let imagePath = item.value(forKey: "image_path") as? String, !imagePath.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Image:")
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tags:")
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.top, 8)
            }
            
            // Display synonyms
            let synonyms = CatalogItemHelpers.synonymsArrayForItem(item)
            if !synonyms.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Synonyms:")
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
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
                .padding(.top, 8)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Item Details")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}

#Preview {
    NavigationStack {
        let context = PersistenceController.preview.container.viewContext
        let sampleItem = CatalogItem(context: context)
        sampleItem.name = "Sample Glass Color"
        sampleItem.code = "EFF001"
        sampleItem.manufacturer = "Effetre"
        sampleItem.start_date = Date()
        sampleItem.setValue("transparent,clear,colorless", forKey: "tags")
        sampleItem.setValue("crystal,white", forKey: "synonyms")
        sampleItem.setValue("104", forKey: "coe")
        sampleItem.setValue("images/eff001.jpg", forKey: "image_path")
        
        return CatalogItemDetailView(item: sampleItem)
    }
}

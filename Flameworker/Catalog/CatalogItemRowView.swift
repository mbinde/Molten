//
//  CatalogItemRowView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import SwiftUI
import CoreData

struct CatalogItemRowView: View {
    let item: CatalogItem
    @AppStorage("showManufacturerColors") private var showManufacturerColors = false
    
    var body: some View {
        HStack {
            if showManufacturerColors {
                Circle()
                    .fill(CatalogColorHelper.colorForManufacturer(item.manufacturer))
                    .frame(width: 12, height: 12)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name ?? "Unknown")
                    .fontWeight(.medium)
                
                HStack {
                    Text(item.code ?? "N/A")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    // Show COE if available
                    if let coe = item.value(forKey: "coe") as? String, !coe.isEmpty {
                        Text("COE \(coe)")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    Text(item.manufacturer ?? "Unknown")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Display image path if available
                if let imagePath = item.value(forKey: "image_path") as? String, !imagePath.isEmpty {
                    Text("📷 \(imagePath)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
                
                // Display tags if available
                let tags = CatalogItemHelpers.tagsArrayForItem(item)
                if !tags.isEmpty {
                    HStack {
                        ForEach(tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                        }
                        if tags.count > 3 {
                            Text("+\(tags.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                
                // Display synonyms if available
                let synonyms = CatalogItemHelpers.synonymsArrayForItem(item)
                if !synonyms.isEmpty {
                    HStack {
                        ForEach(synonyms.prefix(2), id: \.self) { synonym in
                            Text(synonym)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.1))
                                .foregroundColor(.green)
                                .clipShape(Capsule())
                        }
                        if synonyms.count > 2 {
                            Text("+\(synonyms.count - 2)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
            }
        }
    }
}

#Preview {
    // Create a preview with a sample catalog item
    let context = PersistenceController.preview.container.viewContext
    let sampleItem = CatalogItem(context: context)
    sampleItem.name = "Sample Glass"
    sampleItem.code = "EFF001"
    sampleItem.manufacturer = "Effetre"
    sampleItem.setValue("transparent,clear,colorless", forKey: "tags")
    sampleItem.setValue("crystal,white", forKey: "synonyms")
    sampleItem.setValue("104", forKey: "coe")
    
    return CatalogItemRowView(item: sampleItem)
        .previewLayout(.sizeThatFits)
        .padding()
}

//
//  CatalogItemRowView.swift
//  Flameworker
//
//  Intelligently Combined and Enhanced Version
//  Created by Assistant on 10/01/25.
//

import SwiftUI
import CoreData

struct CatalogItemRowView: View {
    let item: CatalogItem
    @AppStorage("showManufacturerColors") private var showManufacturerColors = false
    @AppStorage("showDetailedRowInfo") private var showDetailedRowInfo = true
    
    // Get comprehensive display info once to avoid repeated calculations
    private var displayInfo: CatalogItemDisplayInfo {
        CatalogItemHelpers.getItemDisplayInfo(item)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Product image thumbnail (if available)
            ProductImageThumbnail(itemCode: displayInfo.code, manufacturer: displayInfo.manufacturer, size: 50)
            
            // Color indicator for manufacturer (optional based on user preference)
            if showManufacturerColors {
                Circle()
                    .fill(displayInfo.color)
                    .frame(width: 16, height: 16)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Item name
                Text(displayInfo.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                // Code and manufacturer info
                HStack(spacing: 8) {
                    Text(displayInfo.code)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Text("• \(displayInfo.manufacturerFullName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Show link icon if manufacturer_url exists
                        if let url = displayInfo.manufacturerURL {
                            Button(action: {
                                UIApplication.shared.open(url)
                            }) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // COE and additional info row
                HStack(spacing: 8) {
                    if let coe = displayInfo.coe {
                        Text("COE \(coe)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    
                    if let stockType = displayInfo.stockType {
                        Text(stockType.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    
                    Spacer()
                }
                
                // Extended info section (tags, synonyms, image) - shown based on user preference
                if showDetailedRowInfo && displayInfo.hasExtendedInfo {
                    extendedInfoSection
                }
            }
            
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var extendedInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Display image path if available
            if let imagePath = displayInfo.imagePath, !imagePath.isEmpty {
                Text("📷 \(imagePath)")
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .lineLimit(1)
            }
            
            // Display tags if available
            if !displayInfo.tags.isEmpty {
                HStack {
                    ForEach(displayInfo.tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                    }
                    if displayInfo.tags.count > 3 {
                        Text("+\(displayInfo.tags.count - 3)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
            
            // Display synonyms if available
            if !displayInfo.synonyms.isEmpty {
                HStack {
                    ForEach(displayInfo.synonyms.prefix(2), id: \.self) { synonym in
                        Text(synonym)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green)
                            .clipShape(Capsule())
                    }
                    if displayInfo.synonyms.count > 2 {
                        Text("+\(displayInfo.synonyms.count - 2)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
        }
    }
    
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    
    // Create sample catalog items for preview
    let item1 = CatalogItem(context: context)
    item1.name = "Cobalt Blue"
    item1.code = "EF-001"
    item1.manufacturer = "EF"
    item1.setValue(Date(), forKey: "start_date")
    item1.setValue("104", forKey: "coe")
    item1.setValue("https://effetre.com", forKey: "manufacturer_url")
    item1.setValue("rod", forKey: "stock_type")
    item1.setValue("transparent,blue,bright", forKey: "tags")
    item1.setValue("cobalt,electric blue", forKey: "synonyms")
    item1.setValue("images/ef001.jpg", forKey: "image_path")
    
    let item2 = CatalogItem(context: context)
    item2.name = "Clear Glass"
    item2.code = "DH-100"
    item2.manufacturer = "DH"
    item2.setValue(Date(), forKey: "start_date")
    item2.setValue(Date(), forKey: "end_date")
    item2.setValue("104", forKey: "coe")
    item2.setValue("sheet", forKey: "stock_type")
    
    let item3 = CatalogItem(context: context)
    item3.name = "Future Release Glass"
    item3.code = "GA-999"
    item3.manufacturer = "GA"
    item3.setValue(Calendar.current.date(byAdding: .month, value: 1, to: Date()), forKey: "start_date")
    item3.setValue("33", forKey: "coe")
    
    return List {
        CatalogItemRowView(item: item1)
        CatalogItemRowView(item: item2)
        CatalogItemRowView(item: item3)
    }
    .environment(\.managedObjectContext, context)
}

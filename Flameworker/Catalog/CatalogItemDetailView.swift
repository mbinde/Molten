//
//  CatalogItemDetailView.swift
//  Flameworker
//
//  Created by Assistant on 10/01/25.
//

import SwiftUI
import CoreData

struct CatalogItemDetailView: View {
    let item: CatalogItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    // Get comprehensive display info once to avoid repeated calculations
    private var displayInfo: CatalogItemDisplayInfo {
        CatalogItemHelpers.getItemDisplayInfo(item)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with image and basic info
                    headerSection
                    
                    // Basic information section
                    basicInfoSection
                    
                    // Extended information section
                    if displayInfo.hasExtendedInfo {
                        extendedInfoSection
                    }
                    
                    // Related inventory items section
                    relatedInventorySection
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle(displayInfo.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                // Add to inventory button
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(destination: AddInventoryItemView(prefilledCatalogCode: displayInfo.code)) {
                        Label("Add to Inventory", systemImage: "plus.circle.fill")
                    }
                }
            }
            .toolbar {
                // External link if available
                if let url = displayInfo.manufacturerURL {
                    ToolbarItem(placement: .secondaryAction) {
                        Button {
                            UIApplication.shared.open(url)
                        } label: {
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - View Sections
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Product image if available
            if ImageHelpers.productImageExists(for: displayInfo.code, manufacturer: displayInfo.manufacturer) {
                HStack {
                    ProductImageDetail(itemCode: displayInfo.code, manufacturer: displayInfo.manufacturer, maxSize: 200)
                    Spacer()
                }
            }
            
            // Basic item info
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(displayInfo.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 12) {
                        Text(displayInfo.code)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            .cornerRadius(6)
                        
                        Text(displayInfo.manufacturerFullName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
            }
        }
        .padding(.bottom, 10)
    }
    
    @ViewBuilder
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.headline)
            
            VStack(spacing: 12) {
                // COE
                if let coe = displayInfo.coe {
                    detailRow(title: "COE", value: coe, icon: "thermometer")
                }
                
                // Stock Type
                if let stockType = displayInfo.stockType {
                    detailRow(title: "Stock Type", value: stockType.capitalized, icon: "cube.box")
                }
            
            }
        }
    }
    
    @ViewBuilder
    private var extendedInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Additional Information")
                .font(.headline)
            
            // Tags
            if !displayInfo.tags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "tag")
                            .foregroundColor(.blue)
                        Text("Tags")
                            .fontWeight(.medium)
                    }
                    
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 80), spacing: 8)
                    ], spacing: 8) {
                        ForEach(displayInfo.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(12)
                        }
                    }
                }
            }
            
            // Synonyms
            if !displayInfo.synonyms.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "text.bubble")
                            .foregroundColor(.green)
                        Text("Also Known As")
                            .fontWeight(.medium)
                    }
                    
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 100), spacing: 8)
                    ], spacing: 8) {
                        ForEach(displayInfo.synonyms, id: \.self) { synonym in
                            Text(synonym)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.1))
                                .foregroundColor(.green)
                                .cornerRadius(12)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var relatedInventorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inventory")
                .font(.headline)
            
            // Check for existing inventory items
            RelatedInventoryItemsView(catalogCode: displayInfo.code)
        }
    }
    
    
    // MARK: - Helper Views
    
    private func detailRow(title: String, value: String, icon: String, valueColor: Color = .primary) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            Text(title)
                .fontWeight(.medium)
            
            Spacer()
            
            Text(value)
                .foregroundColor(valueColor)
                .fontWeight(.medium)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Related Inventory Items View

struct RelatedInventoryItemsView: View {
    let catalogCode: String
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest private var inventoryItems: FetchedResults<InventoryItem>
    
    init(catalogCode: String) {
        self.catalogCode = catalogCode
        self._inventoryItems = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \InventoryItem.type, ascending: true)],
            predicate: NSPredicate(format: "catalog_code == %@", catalogCode)
        )
    }
    
    var body: some View {
        if inventoryItems.isEmpty {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "cube.transparent")
                        .foregroundColor(.secondary)
                    Text("No inventory items yet")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                NavigationLink(destination: AddInventoryItemView(prefilledCatalogCode: catalogCode)) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add to Inventory")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(8)
        } else {
            VStack(spacing: 8) {
                ForEach(inventoryItems, id: \.objectID) { item in
                    NavigationLink(destination: InventoryItemDetailView(item: item)) {
                        HStack {
                            Image(systemName: InventoryItemType(rawValue: item.type)?.systemImageName ?? "cube")
                                .foregroundColor(InventoryItemType(rawValue: item.type)?.color ?? .gray)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(InventoryItemType(rawValue: item.type)?.displayName ?? "Unknown")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text(item.formattedCountWithUnits)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                
                NavigationLink(destination: AddInventoryItemView(prefilledCatalogCode: catalogCode)) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add Another Item")
                            .font(.subheadline)
                    }
                    .foregroundColor(.blue)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }
}

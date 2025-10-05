//
//  ConsolidatedInventoryRowView.swift
//  Flameworker
//
//  Created by Assistant on 9/29/25.
//

import SwiftUI

enum InventoryFilterType: CaseIterable, Hashable, Codable {
    case inventory, buy, sell
    
    var title: String {
        switch self {
        case .inventory: return "Inventory"
        case .buy: return "Buy"
        case .sell: return "Sell"
        }
    }
    
    var icon: String {
        switch self {
        case .inventory: return "archivebox.fill"
        case .buy: return "cart.fill"
        case .sell: return "dollarsign.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .inventory: return .blue
        case .buy: return .orange
        case .sell: return .green
        }
    }
}

// MARK: - ConsolidatedInventoryRowView

struct ConsolidatedInventoryRowView: View {
    let consolidatedItem: ConsolidatedInventoryItem
    let selectedFilters: Set<InventoryFilterType>
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Product image if available
            if let catalogCode = consolidatedItem.catalogCode,
               ImageHelpers.productImageExists(for: catalogCode) {
                ProductImageDetail(itemCode: catalogCode, maxSize: 60)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                // Placeholder for consistent alignment when no image
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                            .font(.title2)
                    )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Main identifier - use catalog item name
                    Text(consolidatedItem.displayName)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Spacer()
                }
                
                // Item details - show only selected filter types with counts
                HStack(spacing: 12) {
                    if selectedFilters.contains(.inventory) && consolidatedItem.totalInventoryCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "archivebox.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            
                            Text(formatCount(consolidatedItem.totalInventoryCount, units: consolidatedItem.inventoryUnits))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                    
                    if selectedFilters.contains(.buy) && consolidatedItem.totalBuyCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "cart.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            
                            Text(formatCount(consolidatedItem.totalBuyCount, units: consolidatedItem.buyUnits))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                    
                    if selectedFilters.contains(.sell) && consolidatedItem.totalSellCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                                                        
                            Text(formatCount(consolidatedItem.totalSellCount, units: consolidatedItem.sellUnits))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle()) // Makes the entire row tappable
    }
    
    private func formatCount(_ count: Double, units: InventoryUnits?) -> String {
        guard let units = units else {
            let formattedCount: String
            if count.truncatingRemainder(dividingBy: 1) == 0 {
                formattedCount = String(format: "%.0f", count)
            } else {
                formattedCount = String(format: "%.1f", count)
            }
            return "\(formattedCount) units"
        }
        
        // Use the conversion logic from UnitsDisplayHelper
        let displayInfo = UnitsDisplayHelper.convertCount(count, from: units)
        
        let formattedCount: String
        if displayInfo.count.truncatingRemainder(dividingBy: 1) == 0 {
            formattedCount = String(format: "%.0f", displayInfo.count)
        } else {
            formattedCount = String(format: "%.1f", displayInfo.count)
        }
        
        return "\(formattedCount) \(displayInfo.unit)"
    }
}

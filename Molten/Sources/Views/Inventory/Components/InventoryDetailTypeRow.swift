//
//  InventoryDetailTypeRow.swift
//  Molten
//
//  Inventory type row with tap handling for detail view
//

import SwiftUI

/// Inventory type row with tap handling for detail view
struct InventoryDetailTypeRow: View {
    let type: String
    let quantity: Double
    let inventoryRecords: [InventoryModel]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.capitalized)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    // Show subtypes if present
                    if !subtypesSummary.isEmpty {
                        Text(subtypesSummary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Show dimensions summary if present
                    if !dimensionsSummary.isEmpty {
                        Text(dimensionsSummary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("\(inventoryRecords.count) record\(inventoryRecords.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatQuantity(quantity))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                    Text("units")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color.secondary.opacity(0.6))
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    /// Get a summary of subtypes present in inventory records
    private var subtypesSummary: String {
        let subtypes = Set(inventoryRecords.compactMap { $0.subtype }).sorted()
        if subtypes.isEmpty {
            return ""
        } else if subtypes.count == 1 {
            return subtypes[0].capitalized
        } else if subtypes.count == 2 {
            return subtypes.map { $0.capitalized }.joined(separator: ", ")
        } else {
            return "\(subtypes.count) subtypes"
        }
    }

    /// Get a summary of dimensions present in inventory records
    private var dimensionsSummary: String {
        let recordsWithDimensions = inventoryRecords.filter { $0.dimensions != nil && !($0.dimensions?.isEmpty ?? true) }

        if recordsWithDimensions.isEmpty {
            return ""
        }

        // If there's just one record with dimensions, show them
        if recordsWithDimensions.count == 1, let dims = recordsWithDimensions.first?.dimensions {
            return formatDimensions(dims)
        }

        // Otherwise, just indicate there are multiple dimension sets
        return "\(recordsWithDimensions.count) with dimensions"
    }

    /// Format dimensions for display
    private func formatDimensions(_ dimensions: [String: Double]) -> String {
        let formatted = GlassItemTypeSystem.formatDimensions(dimensions, for: type)
        if formatted.count > 40 {
            return String(formatted.prefix(40)) + "..."
        }
        return formatted
    }

    private func formatQuantity(_ quantity: Double) -> String {
        if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", quantity)
        } else {
            return String(format: "%.1f", quantity)
        }
    }
}

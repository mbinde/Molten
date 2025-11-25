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
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(type.capitalized)
                        .font(DesignSystem.Typography.formLabel)
                        .fontWeight(DesignSystem.FontWeight.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    // Show subtypes if present
                    if !subtypesSummary.isEmpty {
                        Text(subtypesSummary)
                            .font(DesignSystem.Typography.listItemCaption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    // Show dimensions summary if present
                    if !dimensionsSummary.isEmpty {
                        Text(dimensionsSummary)
                            .font(DesignSystem.Typography.listItemCaption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    Text("\(inventoryRecords.count) record\(inventoryRecords.count == 1 ? "" : "s")")
                        .font(DesignSystem.Typography.listItemCaptionSmall)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
                    Text(formatQuantity(quantity))
                        .font(DesignSystem.Typography.prominentNumberSmall)
                        .fontWeight(DesignSystem.FontWeight.semibold)
                        .foregroundColor(DesignSystem.Colors.moltenTeal)
                    Text("units")
                        .font(DesignSystem.Typography.listItemCaptionSmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Image(systemName: "chevron.right")
                    .font(DesignSystem.Typography.listItemCaption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            .padding()
            .background(DesignSystem.Colors.backgroundTertiary)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
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

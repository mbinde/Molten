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
                    Text(formattedTotalDisplay)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                    Text(quantityUnitLabel)
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

    /// Check if this is a weight-based type
    private var isWeightBasedType: Bool {
        switch type.lowercased() {
        case "frit", "powder", "enamel":
            return true
        default:
            return false
        }
    }

    /// Total container count across all records
    private var totalContainerCount: Double {
        inventoryRecords.compactMap { $0.containerCount }.reduce(0, +)
    }

    /// Format the total display for weight-based types
    private var formattedTotalDisplay: String {
        if isWeightBasedType {
            let hasJars = totalContainerCount > 0
            let hasWeight = quantity > 0
            let preferredUnit = WeightUnitPreference.current

            if hasJars && hasWeight {
                // Both jars and weight
                let jarText = formatJarCount(totalContainerCount)
                let weightText = formatWeight(quantity, unit: preferredUnit)

                if ContainerInputModePreference.current == .jars {
                    return "\(jarText) (~\(weightText))"
                } else {
                    return "\(weightText) (\(jarText))"
                }
            } else if hasJars {
                return formatJarCount(totalContainerCount)
            } else if hasWeight {
                return formatWeight(quantity, unit: preferredUnit)
            } else {
                return "0"
            }
        } else {
            return formatQuantity(quantity)
        }
    }

    /// Unit label for the quantity
    private var quantityUnitLabel: String {
        if isWeightBasedType {
            let hasJars = totalContainerCount > 0
            let hasWeight = quantity > 0

            if hasJars && !hasWeight {
                return ""  // "jars" is in the number itself
            } else if !hasJars && hasWeight {
                return ""  // unit symbol is in the number
            } else {
                return ""  // Combined display handles its own labels
            }
        } else {
            return "units"
        }
    }

    /// Format jar count
    private func formatJarCount(_ count: Double) -> String {
        let countStr = count.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", count)
            : String(format: "%.1f", count)
        let label = count == 1 ? "jar" : "jars"
        return "\(countStr) \(label)"
    }

    /// Format weight with unit
    private func formatWeight(_ grams: Double, unit: WeightUnit) -> String {
        let value: Double
        if unit == .ounces {
            value = WeightUnit.grams.convert(grams, to: .ounces)
        } else {
            value = grams
        }

        let valueStr = value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
        return "\(valueStr)\(unit.symbol)"
    }
}

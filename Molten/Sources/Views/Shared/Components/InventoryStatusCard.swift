//
//  InventoryStatusCard.swift
//  Molten
//
//  Prominent inventory status card with SF Rounded count display
//  Inspired by the "Luminous Precision" design mockups
//

import SwiftUI

/// Prominent card showing inventory status with large SF Rounded count
/// Used in detail views to highlight current stock levels
struct InventoryStatusCard: View {
    let inventory: [InventoryModel]
    let onTapRecord: ((InventoryModel) -> Void)?
    let onTapRecordsForType: (([InventoryModel], String) -> Void)?
    let onTapDetails: (() -> Void)?

    init(
        inventory: [InventoryModel],
        onTapRecord: ((InventoryModel) -> Void)? = nil,
        onTapRecordsForType: (([InventoryModel], String) -> Void)? = nil,
        onTapDetails: (() -> Void)? = nil
    ) {
        self.inventory = inventory
        self.onTapRecord = onTapRecord
        self.onTapRecordsForType = onTapRecordsForType
        self.onTapDetails = onTapDetails
    }

    /// Group inventory by type, summing quantities
    private var inventoryByType: [String: Double] {
        var result: [String: Double] = [:]
        for record in inventory {
            result[record.type, default: 0] += record.quantity
        }
        return result
    }

    /// Get the first record for each type (for editing)
    private func recordsForType(_ type: String) -> [InventoryModel] {
        inventory.filter { $0.type == type }
    }

    private var totalQuantity: Double {
        inventory.reduce(0) { $0 + $1.quantity }
    }

    private var primaryType: String? {
        inventoryByType.max(by: { $0.value < $1.value })?.key
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Section header with optional "Details" link
            HStack {
                Text("Inventory Status")
                    .font(DesignSystem.Typography.subsectionTitle)
                    .fontWeight(DesignSystem.FontWeight.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                if onTapDetails != nil && !inventoryByType.isEmpty {
                    Button(action: { onTapDetails?() }) {
                        Text("Details")
                            .font(DesignSystem.Typography.listItemCaption)
                            .foregroundColor(DesignSystem.Colors.accentPrimary)
                    }
                }
            }

            if inventoryByType.isEmpty {
                emptyState
            } else {
                // Inventory type cards
                VStack(spacing: DesignSystem.Spacing.md) {
                    ForEach(Array(inventoryByType.keys.sorted()), id: \.self) { type in
                        let quantity = inventoryByType[type] ?? 0
                        inventoryTypeRow(type: type, quantity: quantity)
                    }
                }
            }
        }
        .padding(DesignSystem.Padding.standard)
        .background(DesignSystem.Colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.extraLarge))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "cube.box")
                    .font(.system(size: 32))
                    .foregroundColor(DesignSystem.Colors.textTertiary)

                Text("No inventory")
                    .font(DesignSystem.Typography.formLabel)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .padding(.vertical, DesignSystem.Spacing.xl)
            Spacer()
        }
    }

    // MARK: - Inventory Type Row

    @ViewBuilder
    private func inventoryTypeRow(type: String, quantity: Double) -> some View {
        let records = recordsForType(type)

        Button(action: {
            // If single record, edit it directly; otherwise show records for this type
            if records.count == 1, let record = records.first {
                onTapRecord?(record)
            } else {
                // Multiple records - show just this type's records
                onTapRecordsForType?(records, type)
            }
        }) {
            HStack(alignment: .center) {
                // Type icon and name
                HStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: iconForType(type))
                        .font(.system(size: 20))
                        .foregroundColor(DesignSystem.Colors.accentPrimary)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayNameForType(type))
                            .font(DesignSystem.Typography.formLabel)
                            .fontWeight(DesignSystem.FontWeight.medium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        // Show location if single record
                        if records.count == 1, let location = records.first?.location, !location.isEmpty {
                            Text(location)
                                .font(DesignSystem.Typography.listItemCaption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        } else if records.count > 1 {
                            Text("\(records.count) locations")
                                .font(DesignSystem.Typography.listItemCaption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }

                Spacer()

                // Quantity with SF Rounded - use InventoryCountBadge for consistent formatting
                InventoryCountBadge.forInventory(
                    type: type,
                    quantity: quantity,
                    style: .compact
                )

                // Chevron if tappable
                if onTapRecord != nil || onTapDetails != nil {
                    Image(systemName: "chevron.right")
                        .font(DesignSystem.Typography.listItemCaption)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
            }
            .padding(DesignSystem.Padding.standard)
            .background(DesignSystem.Colors.background)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
        .buttonStyle(.plain)
        .disabled(onTapRecord == nil && onTapDetails == nil)
    }

    // MARK: - Helper Methods

    private func iconForType(_ type: String) -> String {
        switch type.lowercased() {
        case "rod", "rods": return "line.3.horizontal"
        case "tube", "tubes": return "cylinder"
        case "sheet", "sheets": return "rectangle"
        case "frit": return "circle.grid.3x3"
        case "powder": return "sparkles"
        case "stringer", "stringers": return "line.diagonal"
        default: return "cube.box"
        }
    }

    private func displayNameForType(_ type: String) -> String {
        GlassTerminologySettings.shared.displayName(for: type).capitalized
    }
}

// MARK: - Preview

#Preview("With Inventory") {
    let sampleInventory = [
        InventoryModel(id: UUID(), item_stable_id: "test", type: "sheet", quantity: 8, location: "Cabinet 1"),
        InventoryModel(id: UUID(), item_stable_id: "test", type: "rod", quantity: 5, location: "Studio"),
        InventoryModel(id: UUID(), item_stable_id: "test", type: "rod", quantity: 7, location: "Garage"),
        InventoryModel(id: UUID(), item_stable_id: "test", type: "frit", quantity: 250, location: "Cabinet 2")
    ]

    ScrollView {
        InventoryStatusCard(
            inventory: sampleInventory,
            onTapRecord: { record in
                print("Tapped record: \(record.type) at \(record.location ?? "unknown")")
            },
            onTapDetails: {
                print("Tapped details")
            }
        )
        .padding()
    }
}

#Preview("Empty") {
    InventoryStatusCard(
        inventory: [],
        onTapRecord: nil
    )
    .padding()
}

#Preview("Single Type") {
    let sampleInventory = [
        InventoryModel(id: UUID(), item_stable_id: "test", type: "sheet", quantity: 8, location: "Cabinet 1")
    ]

    InventoryStatusCard(
        inventory: sampleInventory,
        onTapRecord: { _ in }
    )
    .padding()
}

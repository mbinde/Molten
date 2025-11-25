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
    let inventoryByType: [String: Double]
    let onTapType: ((String) -> Void)?

    init(
        inventoryByType: [String: Double],
        onTapType: ((String) -> Void)? = nil
    ) {
        self.inventoryByType = inventoryByType
        self.onTapType = onTapType
    }

    private var totalQuantity: Double {
        inventoryByType.values.reduce(0, +)
    }

    private var primaryType: String? {
        inventoryByType.max(by: { $0.value < $1.value })?.key
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Section header
            Text("Inventory Status")
                .font(DesignSystem.Typography.subsectionTitle)
                .fontWeight(DesignSystem.FontWeight.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)

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

    private func inventoryTypeRow(type: String, quantity: Double) -> some View {
        Button(action: {
            onTapType?(type)
        }) {
            HStack(alignment: .center) {
                // Type icon and name
                HStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: iconForType(type))
                        .font(.system(size: 20))
                        .foregroundColor(DesignSystem.Colors.accentPrimary)
                        .frame(width: 28)

                    Text(displayNameForType(type))
                        .font(DesignSystem.Typography.formLabel)
                        .fontWeight(DesignSystem.FontWeight.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }

                Spacer()

                // Quantity with SF Rounded - use InventoryCountBadge for consistent formatting
                InventoryCountBadge.forInventory(
                    type: type,
                    quantity: quantity,
                    style: .compact
                )

                // Chevron if tappable
                if onTapType != nil {
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
        .disabled(onTapType == nil)
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
    ScrollView {
        InventoryStatusCard(
            inventoryByType: [
                "sheet": 8,
                "rod": 12,
                "frit": 250
            ],
            onTapType: { type in
                print("Tapped: \(type)")
            }
        )
        .padding()
    }
}

#Preview("Empty") {
    InventoryStatusCard(
        inventoryByType: [:],
        onTapType: nil
    )
    .padding()
}

#Preview("Single Type") {
    InventoryStatusCard(
        inventoryByType: ["sheet": 8],
        onTapType: { _ in }
    )
    .padding()
}

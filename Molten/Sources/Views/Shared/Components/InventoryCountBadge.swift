//
//  InventoryCountBadge.swift
//  Molten
//
//  Prominent inventory count badge using SF Rounded font
//

import SwiftUI

/// Displays inventory count with SF Rounded font
/// Used in list rows (trailing) and detail views
struct InventoryCountBadge: View {
    let quantity: Double
    let unit: String
    let style: Style

    enum Style {
        /// Large style for detail views - vertical layout
        case large
        /// Compact style for list rows - horizontal layout
        case compact
        /// Minimal style - just the number
        case minimal
    }

    init(
        quantity: Double,
        unit: String,
        style: Style = .compact
    ) {
        self.quantity = quantity
        self.unit = unit
        self.style = style
    }

    // MARK: - Computed Properties

    private var isOutOfStock: Bool {
        quantity <= 0
    }

    private var displayColor: Color {
        if isOutOfStock {
            return DesignSystem.Colors.textTertiary
        } else {
            return DesignSystem.Colors.moltenTeal
        }
    }

    private var formattedQuantity: String {
        // Strip trailing .0 for whole numbers
        if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", quantity)
        } else {
            return String(format: "%.1f", quantity)
        }
    }

    // MARK: - Body

    var body: some View {
        switch style {
        case .large:
            largeStyle
        case .compact:
            compactStyle
        case .minimal:
            minimalStyle
        }
    }

    // MARK: - Style Views

    /// Large vertical layout for detail views
    private var largeStyle: some View {
        VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xxs) {
            Text(formattedQuantity)
                .font(DesignSystem.Typography.prominentNumberLarge)
                .fontWeight(DesignSystem.FontWeight.bold)
                .foregroundColor(displayColor)

            Text(unit)
                .font(DesignSystem.Typography.listItemCaption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }

    /// Compact horizontal layout for list rows
    private var compactStyle: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Text(formattedQuantity)
                .font(DesignSystem.Typography.prominentNumber)
                .fontWeight(DesignSystem.FontWeight.bold)
                .foregroundColor(displayColor)

            Text(unit)
                .font(DesignSystem.Typography.listItemCaption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }

    /// Minimal - just the number
    private var minimalStyle: some View {
        Text(formattedQuantity)
            .font(DesignSystem.Typography.prominentNumberSmall)
            .fontWeight(DesignSystem.FontWeight.semibold)
            .foregroundColor(displayColor)
    }
}

// MARK: - Convenience Initializers

extension InventoryCountBadge {
    /// Create badge from inventory type and quantity
    /// Automatically determines the display unit based on type
    static func forInventory(
        type: String,
        quantity: Double,
        style: Style = .compact
    ) -> InventoryCountBadge {
        let unit = displayUnit(for: type)
        // For weight-based types, convert from grams to user preference
        let displayQuantity: Double
        let isWeightBased = ["frit", "powder", "enamel"].contains(type.lowercased())
        if isWeightBased {
            displayQuantity = WeightUnit.grams.convert(quantity, to: WeightUnitPreference.current)
        } else {
            displayQuantity = quantity
        }
        return InventoryCountBadge(
            quantity: displayQuantity,
            unit: unit,
            style: style
        )
    }

    /// Create badge showing total across multiple inventory types
    static func forTotalInventory(
        totalQuantity: Double,
        primaryType: String?,
        style: Style = .compact
    ) -> InventoryCountBadge {
        let unit: String
        if let type = primaryType {
            unit = displayUnit(for: type)
        } else {
            unit = "items"
        }

        return InventoryCountBadge(
            quantity: totalQuantity,
            unit: unit,
            style: style
        )
    }

    /// Get display unit for a type - uses GlassTerminologySettings for consistency
    private static func displayUnit(for type: String) -> String {
        // Weight-based types use weight unit preference
        let isWeightBased = ["frit", "powder", "enamel"].contains(type.lowercased())
        if isWeightBased {
            return WeightUnitPreference.current.symbol
        }

        // All other types use the central terminology settings (already pluralized)
        return GlassTerminologySettings.shared.displayName(for: type).lowercased()
    }
}

// MARK: - Previews

#Preview("Styles") {
    VStack(spacing: DesignSystem.Spacing.xxl) {
        // Large style
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Large Style (Detail View)")
                .font(DesignSystem.Typography.listItemCaption)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            HStack(spacing: DesignSystem.Spacing.xxl) {
                InventoryCountBadge(quantity: 8, unit: "sheets", style: .large)
                InventoryCountBadge(quantity: 2, unit: "rods", style: .large)
                InventoryCountBadge(quantity: 0, unit: "items", style: .large)
            }
        }

        Divider()

        // Compact style
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Compact Style (List Row)")
                .font(DesignSystem.Typography.listItemCaption)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            HStack(spacing: DesignSystem.Spacing.xxl) {
                InventoryCountBadge(quantity: 15, unit: "rods", style: .compact)
                InventoryCountBadge(quantity: 3, unit: "sheets", style: .compact)
                InventoryCountBadge(quantity: 0, unit: "items", style: .compact)
            }
        }

        Divider()

        // Minimal style
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Minimal Style")
                .font(DesignSystem.Typography.listItemCaption)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            HStack(spacing: DesignSystem.Spacing.xxl) {
                InventoryCountBadge(quantity: 42, unit: "", style: .minimal)
                InventoryCountBadge(quantity: 2, unit: "", style: .minimal)
                InventoryCountBadge(quantity: 0, unit: "", style: .minimal)
            }
        }
    }
    .padding()
}

#Preview("In List Context") {
    List {
        HStack {
            VStack(alignment: .leading) {
                Text("Bullseye Red Transparent")
                    .font(DesignSystem.Typography.listItemTitle)
                Text("Bullseye • BE-0124-30")
                    .font(DesignSystem.Typography.listItemSubtitle)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            Spacer()
            InventoryCountBadge(quantity: 8, unit: "sheets", style: .compact)
        }

        HStack {
            VStack(alignment: .leading) {
                Text("Oceanside Yellow Opaque")
                    .font(DesignSystem.Typography.listItemTitle)
                Text("Oceanside • OC-200-YEL")
                    .font(DesignSystem.Typography.listItemSubtitle)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            Spacer()
            InventoryCountBadge(quantity: 1, unit: "lb", style: .compact)
        }

        HStack {
            VStack(alignment: .leading) {
                Text("CiM Deep Blue")
                    .font(DesignSystem.Typography.listItemTitle)
                Text("CiM • 425")
                    .font(DesignSystem.Typography.listItemSubtitle)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            Spacer()
            InventoryCountBadge(quantity: 0, unit: "rods", style: .compact)
        }
    }
}

#Preview("Convenience Initializers") {
    VStack(spacing: DesignSystem.Spacing.xl) {
        InventoryCountBadge.forInventory(type: "sheet", quantity: 1)
        InventoryCountBadge.forInventory(type: "sheet", quantity: 5)
        InventoryCountBadge.forInventory(type: "rod", quantity: 10)
        InventoryCountBadge.forInventory(type: "frit", quantity: 250)
        InventoryCountBadge.forTotalInventory(totalQuantity: 15, primaryType: "rod")
        InventoryCountBadge.forTotalInventory(totalQuantity: 1, primaryType: nil)
    }
    .padding()
}

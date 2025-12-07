//
//  InventoryStatusCard.swift
//  Molten
//
//  Prominent inventory status card with SF Rounded count display
//  Shows inventory grouped by location/type/subtype with +/- controls
//

import SwiftUI

/// Key for grouping inventory records
struct InventoryGroupKey: Hashable {
    let location: String?
    let type: String
    let subtype: String?
    let subsubtype: String?
}

/// Prominent card showing inventory status grouped by location/type
/// Each row shows total quantity with +/- controls and move option
struct InventoryStatusCard: View {
    let inventory: [InventoryModel]
    let onIncrement: ((InventoryGroupKey) -> Void)?
    let onDecrement: ((InventoryGroupKey) -> Void)?
    let onMove: ((InventoryGroupKey) -> Void)?
    let onTapDetails: (() -> Void)?

    init(
        inventory: [InventoryModel],
        onIncrement: ((InventoryGroupKey) -> Void)? = nil,
        onDecrement: ((InventoryGroupKey) -> Void)? = nil,
        onMove: ((InventoryGroupKey) -> Void)? = nil,
        onTapDetails: (() -> Void)? = nil
    ) {
        self.inventory = inventory
        self.onIncrement = onIncrement
        self.onDecrement = onDecrement
        self.onMove = onMove
        self.onTapDetails = onTapDetails
    }

    /// Group inventory by location/type/subtype/subsubtype, summing quantities
    private var groupedInventory: [(key: InventoryGroupKey, quantity: Double)] {
        var result: [InventoryGroupKey: Double] = [:]
        for record in inventory {
            let key = InventoryGroupKey(
                location: record.location,
                type: record.type,
                subtype: record.subtype,
                subsubtype: record.subsubtype
            )
            result[key, default: 0] += record.quantity
        }
        // Sort: by location (named first, then nil), then by type
        return result.sorted { lhs, rhs in
            // Compare locations first
            switch (lhs.key.location, rhs.key.location) {
            case (nil, nil): break
            case (nil, _): return false
            case (_, nil): return true
            case (let a?, let b?):
                if a.isEmpty && !b.isEmpty { return false }
                if !a.isEmpty && b.isEmpty { return true }
                if a != b { return a < b }
            }
            // Then by type
            if lhs.key.type != rhs.key.type {
                return lhs.key.type < rhs.key.type
            }
            // Then by subtype
            switch (lhs.key.subtype, rhs.key.subtype) {
            case (nil, nil): break
            case (nil, _): return true
            case (_, nil): return false
            case (let a?, let b?): if a != b { return a < b }
            }
            // Then by subsubtype
            switch (lhs.key.subsubtype, rhs.key.subsubtype) {
            case (nil, nil): return false
            case (nil, _): return true
            case (_, nil): return false
            case (let a?, let b?): return a < b
            }
        }.map { (key: $0.key, quantity: $0.value) }
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

                if onTapDetails != nil && !inventory.isEmpty {
                    Button(action: { onTapDetails?() }) {
                        Text("Details")
                            .font(DesignSystem.Typography.listItemCaption)
                            .foregroundColor(DesignSystem.Colors.accentPrimary)
                    }
                }
            }

            if inventory.isEmpty {
                emptyState
            } else {
                // Inventory rows
                VStack(spacing: DesignSystem.Spacing.md) {
                    ForEach(groupedInventory, id: \.key) { item in
                        inventoryRow(key: item.key, quantity: item.quantity)
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

    // MARK: - Inventory Row

    private func inventoryRow(key: InventoryGroupKey, quantity: Double) -> some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
            // Type icon and info
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: iconForType(key.type))
                    .font(.system(size: 18))
                    .foregroundColor(DesignSystem.Colors.accentPrimary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    // Primary: type name
                    Text(displayNameForType(key.type))
                        .font(DesignSystem.Typography.formLabel)
                        .fontWeight(DesignSystem.FontWeight.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    // Secondary: location and subtype info
                    let details = buildDetailsText(key: key)
                    if !details.isEmpty {
                        Text(details)
                            .font(DesignSystem.Typography.listItemCaption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Move button with divider
            if onMove != nil {
                // Vertical divider
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 2, height: 28)
                    .shadow(color: Color.white.opacity(0.5), radius: 1, x: 1, y: 0)

                Button(action: {
                    onMove?(key)
                }) {
                    Image(systemName: "arrow.right.arrow.left")
                        .font(.system(size: 18))
                        .foregroundColor(DesignSystem.Colors.accentSecondary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, DesignSystem.Spacing.md)

                // Vertical divider
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 2, height: 28)
                    .shadow(color: Color.white.opacity(0.5), radius: 1, x: 1, y: 0)
            }

            // +/- controls with quantity
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Decrement button
                Button(action: {
                    onDecrement?(key)
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(quantity > 0 ? DesignSystem.Colors.accentPrimary : DesignSystem.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .disabled(quantity <= 0 || onDecrement == nil)

                // Quantity display
                Text(formatQuantity(quantity))
                    .font(DesignSystem.Typography.prominentNumber)
                    .fontWeight(DesignSystem.FontWeight.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .frame(minWidth: 44)
                    .multilineTextAlignment(.center)

                // Increment button
                Button(action: {
                    onIncrement?(key)
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(DesignSystem.Colors.accentPrimary)
                }
                .buttonStyle(.plain)
                .disabled(onIncrement == nil)
            }
        }
        .padding(DesignSystem.Padding.standard)
        .background(DesignSystem.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }

    // MARK: - Helper Methods

    private func buildDetailsText(key: InventoryGroupKey) -> String {
        var parts: [String] = []

        // Location
        if let loc = key.location, !loc.isEmpty {
            parts.append(loc)
        }

        // Subtype
        if let sub = key.subtype, !sub.isEmpty {
            parts.append(sub.capitalized)
        }

        // Subsubtype
        if let subsub = key.subsubtype, !subsub.isEmpty {
            parts.append(subsub.capitalized)
        }

        return parts.joined(separator: " · ")
    }

    private func iconForType(_ type: String) -> String {
        switch type.lowercased() {
        case "rod", "rods": return "line.3.horizontal"
        case "big-rod", "bar", "bars": return "equal"
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

    private func formatQuantity(_ quantity: Double) -> String {
        if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", quantity)
        } else {
            return String(format: "%.1f", quantity)
        }
    }
}

// MARK: - Preview

#Preview("With Inventory") {
    let sampleInventory = [
        InventoryModel(id: UUID(), item_stable_id: "test", type: "sheet", quantity: 8, location: "Cabinet 1"),
        InventoryModel(id: UUID(), item_stable_id: "test", type: "rod", subtype: "stringer", quantity: 5, location: "Studio"),
        InventoryModel(id: UUID(), item_stable_id: "test", type: "rod", subtype: "standard", quantity: 7, location: "Studio"),
        InventoryModel(id: UUID(), item_stable_id: "test", type: "frit", subtype: "medium", quantity: 250, location: nil)
    ]

    ScrollView {
        InventoryStatusCard(
            inventory: sampleInventory,
            onIncrement: { key in
                print("Increment: \(key.type) at \(key.location ?? "no location")")
            },
            onDecrement: { key in
                print("Decrement: \(key.type) at \(key.location ?? "no location")")
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
        inventory: []
    )
    .padding()
}

#Preview("Single Item") {
    let sampleInventory = [
        InventoryModel(id: UUID(), item_stable_id: "test", type: "sheet", quantity: 8, location: "Cabinet 1")
    ]

    InventoryStatusCard(
        inventory: sampleInventory,
        onIncrement: { _ in },
        onDecrement: { _ in }
    )
    .padding()
}

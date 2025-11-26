//
//  SpecificationTile.swift
//  Molten
//
//  Icon-based specification tiles for detail views
//  Inspired by the "Luminous Precision" design mockups
//

import SwiftUI

/// Single specification tile with icon and value (no label)
/// Used in grids to display item specifications
struct SpecificationTile: View {
    let icon: String
    let value: String
    let tintColor: Color

    init(
        icon: String,
        value: String,
        tintColor: Color = DesignSystem.Colors.accentPrimary
    ) {
        self.icon = icon
        self.value = value
        self.tintColor = tintColor
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(tintColor)

            // Value - scales down to fit, never truncates
            Text(value)
                .font(DesignSystem.Typography.tileValue)
                .fontWeight(DesignSystem.FontWeight.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }
}

/// Grid of specification tiles
struct SpecificationTileGrid: View {
    let tiles: [TileData]

    struct TileData: Identifiable {
        let id = UUID()
        let icon: String
        let value: String
        let tintColor: Color

        init(icon: String, value: String, tintColor: Color = DesignSystem.Colors.accentPrimary) {
            self.icon = icon
            self.value = value
            self.tintColor = tintColor
        }
    }

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: DesignSystem.Spacing.md),
                GridItem(.flexible(), spacing: DesignSystem.Spacing.md)
            ],
            spacing: DesignSystem.Spacing.md
        ) {
            ForEach(tiles) { tile in
                SpecificationTile(
                    icon: tile.icon,
                    value: tile.value,
                    tintColor: tile.tintColor
                )
            }
        }
    }
}

// MARK: - Preview

#Preview("Specification Tiles") {
    VStack(spacing: DesignSystem.Spacing.xl) {
        Text("Specifications")
            .font(DesignSystem.Typography.subsectionTitle)
            .fontWeight(DesignSystem.FontWeight.semibold)
            .frame(maxWidth: .infinity, alignment: .leading)

        SpecificationTileGrid(tiles: [
            .init(icon: "arrow.left.and.right", value: "90 COE"),
            .init(icon: "building.2", value: "Bullseye"),
            .init(icon: "tag", value: "BE-0124-30"),
            .init(icon: "checkmark.circle", value: "Available", tintColor: DesignSystem.Colors.moltenTeal)
        ])
    }
    .padding()
}

#Preview("Single Tile") {
    SpecificationTile(
        icon: "arrow.left.and.right",
        value: "90 COE"
    )
    .frame(width: 160)
    .padding()
}

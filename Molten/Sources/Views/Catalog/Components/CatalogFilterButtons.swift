//
//  CatalogFilterButtons.swift
//  Molten
//
//  Compact filter button components for CatalogView
//

import SwiftUI

// MARK: - Manufacturer Filter Button

struct ManufacturerFilterButton: View {
    let selectedManufacturers: Set<String>
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if selectedManufacturers.isEmpty {
                    Image(systemName: "building.2")
                        .font(DesignSystem.Typography.captionSmall)
                    Text("Mfr")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.medium)
                } else {
                    // Show first 2 manufacturers inline (abbreviated)
                    let displayedMfrs = Array(selectedManufacturers.prefix(2))
                    ForEach(displayedMfrs, id: \.self) { mfr in
                        Text(mfr)
                            .font(DesignSystem.Typography.captionSmall)
                            .fontWeight(DesignSystem.FontWeight.semibold)
                    }

                    // Show count if more than 2
                    if selectedManufacturers.count > 2 {
                        Text("+\(selectedManufacturers.count - 2)")
                            .font(DesignSystem.Typography.captionSmall)
                            .fontWeight(DesignSystem.FontWeight.semibold)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(
                selectedManufacturers.isEmpty
                    ? DesignSystem.Colors.backgroundSecondary
                    : DesignSystem.Colors.accentPrimary.opacity(0.15)
            )
            .foregroundColor(
                selectedManufacturers.isEmpty
                    ? DesignSystem.Colors.textSecondary
                    : DesignSystem.Colors.accentPrimary
            )
            .cornerRadius(DesignSystem.CornerRadius.medium)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("catalog_filter_manufacturer")
    }
}

// MARK: - COE Filter Button

struct COEFilterButton: View {
    let selectedCOEs: Set<Int32>
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if selectedCOEs.isEmpty {
                    Image(systemName: "number")
                        .font(DesignSystem.Typography.captionSmall)
                    Text("COE")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.medium)
                } else {
                    // Show first 2 COEs inline
                    let displayedCOEs = Array(selectedCOEs.sorted().prefix(2))
                    ForEach(displayedCOEs, id: \.self) { coe in
                        Text(String(coe))
                            .font(DesignSystem.Typography.captionSmall)
                            .fontWeight(DesignSystem.FontWeight.semibold)
                    }

                    // Show count if more than 2
                    if selectedCOEs.count > 2 {
                        Text("+\(selectedCOEs.count - 2)")
                            .font(DesignSystem.Typography.captionSmall)
                            .fontWeight(DesignSystem.FontWeight.semibold)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(
                selectedCOEs.isEmpty
                    ? DesignSystem.Colors.backgroundSecondary
                    : DesignSystem.Colors.accentPrimary.opacity(0.15)
            )
            .foregroundColor(
                selectedCOEs.isEmpty
                    ? DesignSystem.Colors.textSecondary
                    : DesignSystem.Colors.accentPrimary
            )
            .cornerRadius(DesignSystem.CornerRadius.medium)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("catalog_filter_coe")
    }
}

// MARK: - Tag Filter Button

struct TagFilterButton: View {
    let selectedTags: Set<String>
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if selectedTags.isEmpty {
                    Image(systemName: "tag")
                        .font(DesignSystem.Typography.captionSmall)
                    Text("Tags")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.medium)
                } else {
                    // Show first 2 tags inline
                    let displayedTags = Array(selectedTags.sorted().prefix(2))
                    ForEach(displayedTags, id: \.self) { tag in
                        Text(tag)
                            .font(DesignSystem.Typography.captionSmall)
                            .fontWeight(DesignSystem.FontWeight.semibold)
                            .lineLimit(1)
                    }

                    // Show count if more than 2
                    if selectedTags.count > 2 {
                        Text("+\(selectedTags.count - 2)")
                            .font(DesignSystem.Typography.captionSmall)
                            .fontWeight(DesignSystem.FontWeight.semibold)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(
                selectedTags.isEmpty
                    ? DesignSystem.Colors.backgroundSecondary
                    : DesignSystem.Colors.accentPrimary.opacity(0.15)
            )
            .foregroundColor(
                selectedTags.isEmpty
                    ? DesignSystem.Colors.textSecondary
                    : DesignSystem.Colors.accentPrimary
            )
            .cornerRadius(DesignSystem.CornerRadius.medium)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("catalog_filter_tags")
    }
}

// MARK: - Product Type Filter Button

struct ProductTypeFilterButton: View {
    let selectedProductTypes: Set<String>
    let action: () -> Void

    private func displayNameForProductType(_ type: String) -> String {
        switch type.lowercased() {
        case "rod": return "Rod"
        case "tube": return "Tube"
        case "frit": return "Frit"
        case "sheet": return "Sheet"
        case "stringer": return "Stringer"
        default: return type.capitalized
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "shippingbox")
                    .font(DesignSystem.Typography.captionSmall)

                if selectedProductTypes.isEmpty {
                    Text("All Types")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.medium)
                } else if selectedProductTypes.count == 1 {
                    Text(displayNameForProductType(selectedProductTypes.first!))
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.semibold)
                } else {
                    Text("\(selectedProductTypes.count) Types")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.semibold)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(
                selectedProductTypes.isEmpty
                    ? DesignSystem.Colors.backgroundSecondary
                    : DesignSystem.Colors.accentPrimary.opacity(0.15)
            )
            .foregroundColor(
                selectedProductTypes.isEmpty
                    ? DesignSystem.Colors.textSecondary
                    : DesignSystem.Colors.accentPrimary
            )
            .cornerRadius(DesignSystem.CornerRadius.medium)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("catalog_filter_product_type")
    }
}

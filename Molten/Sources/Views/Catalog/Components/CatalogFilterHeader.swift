//
//  CatalogFilterHeader.swift
//  Molten
//
//  Filter header component for CatalogView
//

import SwiftUI

struct CatalogFilterHeader: View {
    @Binding var searchTitlesOnly: Bool
    @Binding var selectedProductTypes: Set<String>
    @Binding var selectedCOEs: Set<Int32>
    @Binding var selectedTags: Set<String>
    @Binding var selectedManufacturers: Set<String>

    let onProductTypeFilterTap: () -> Void
    let onCOEFilterTap: () -> Void
    let onTagFilterTap: () -> Void
    let onManufacturerFilterTap: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.none) {
            // Top row: Search titles only toggle
            HStack {
                // Compact search titles only toggle
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Toggle("", isOn: $searchTitlesOnly)
                        .labelsHidden()
                        .accessibilityIdentifier("catalog_search_titles_only")
                    Text("Search titles only")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.medium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, DesignSystem.Padding.standard)
            .padding(.top, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.xs)

            // Bottom row: Product type (left) and filter chips (right)
            HStack(spacing: DesignSystem.Spacing.md) {
                // Left: Product type filter (radio button style, single select)
                ProductTypeFilterButton(
                    selectedProductTypes: selectedProductTypes,
                    action: onProductTypeFilterTap
                )

                Spacer()

                // Right: Filter chips (COE, Tags, Mfr from left to right)
                HStack(spacing: DesignSystem.Spacing.sm) {
                    // COE filter chip
                    COEFilterButton(
                        selectedCOEs: selectedCOEs,
                        action: onCOEFilterTap
                    )

                    // Tag filter chip
                    TagFilterButton(
                        selectedTags: selectedTags,
                        action: onTagFilterTap
                    )

                    // Manufacturer filter chip (far right)
                    ManufacturerFilterButton(
                        selectedManufacturers: selectedManufacturers,
                        action: onManufacturerFilterTap
                    )
                }
            }
            .padding(.horizontal, DesignSystem.Padding.standard)
            .padding(.bottom, DesignSystem.Spacing.md)
        }
        .background(DesignSystem.Colors.background)
    }
}

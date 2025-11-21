//
//  ModernFilterHeader.swift
//  Molten
//
//  Reusable filter header component for modern search pattern
//  Used by Catalog and Inventory views
//

import SwiftUI

/// Modern filter header with search titles only toggle, sort button, and filter chips
/// Designed to work with SwiftUI's native .searchable() modifier
struct ModernFilterHeader<SortOption: RawRepresentable & CaseIterable & Hashable>: View where SortOption.RawValue == String {

    // MARK: - Search Toggle
    @Binding var searchTitlesOnly: Bool

    // MARK: - Sort
    @Binding var sortOption: SortOption
    let sortOptions: [SortOption]
    let sortOptionIcon: (SortOption) -> String
    let onSortChange: ((SortOption) -> Void)?

    // MARK: - Filters
    @Binding var selectedTags: Set<String>
    @Binding var selectedCOEs: Set<Int32>
    @Binding var selectedManufacturers: Set<String>

    // MARK: - Sheet Presentation
    @Binding var showingTagsSheet: Bool
    @Binding var showingCOESheet: Bool
    @Binding var showingManufacturerSheet: Bool

    // MARK: - Optional Product Type Filter
    var productTypeFilter: ProductTypeFilterConfig?

    struct ProductTypeFilterConfig {
        var selectedProductTypes: Binding<Set<String>>
        let availableTypes: [String]
        let displayName: (String) -> String
    }

    init(
        searchTitlesOnly: Binding<Bool>,
        sortOption: Binding<SortOption>,
        sortOptions: [SortOption],
        sortOptionIcon: @escaping (SortOption) -> String,
        onSortChange: ((SortOption) -> Void)? = nil,
        selectedTags: Binding<Set<String>>,
        selectedCOEs: Binding<Set<Int32>>,
        selectedManufacturers: Binding<Set<String>>,
        showingTagsSheet: Binding<Bool>,
        showingCOESheet: Binding<Bool>,
        showingManufacturerSheet: Binding<Bool>,
        productTypeFilter: ProductTypeFilterConfig? = nil
    ) {
        self._searchTitlesOnly = searchTitlesOnly
        self._sortOption = sortOption
        self.sortOptions = sortOptions
        self.sortOptionIcon = sortOptionIcon
        self.onSortChange = onSortChange
        self._selectedTags = selectedTags
        self._selectedCOEs = selectedCOEs
        self._selectedManufacturers = selectedManufacturers
        self._showingTagsSheet = showingTagsSheet
        self._showingCOESheet = showingCOESheet
        self._showingManufacturerSheet = showingManufacturerSheet
        self.productTypeFilter = productTypeFilter
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.none) {
            // Top row: Search titles only toggle and Sort button
            HStack {
                // Compact search titles only toggle
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Toggle("", isOn: $searchTitlesOnly)
                        .labelsHidden()
                    Text("Search titles only")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.medium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Spacer()

                // Sort button
                Menu {
                    ForEach(sortOptions, id: \.self) { option in
                        Button {
                            sortOption = option
                            onSortChange?(option)
                        } label: {
                            Label(option.rawValue, systemImage: sortOptionIcon(option))
                        }
                    }
                } label: {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(DesignSystem.Typography.caption)
                        Text("Sort")
                            .font(DesignSystem.Typography.caption)
                            .fontWeight(DesignSystem.FontWeight.medium)
                    }
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                }
            }
            .padding(.horizontal, DesignSystem.Padding.standard)
            .padding(.top, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.xs)

            // Bottom row: Product type (left, optional) and filter chips (right)
            HStack(spacing: DesignSystem.Spacing.md) {
                // Left: Product type filter (optional)
                if var productTypeConfig = productTypeFilter {
                    ProductTypeFilterMenu(
                        selectedProductTypes: productTypeConfig.selectedProductTypes,
                        availableTypes: productTypeConfig.availableTypes,
                        displayName: productTypeConfig.displayName
                    )
                }

                Spacer()

                // Right: Filter chips (COE, Tags, Mfr from left to right)
                HStack(spacing: DesignSystem.Spacing.sm) {
                    // COE filter chip
                    FilterChipButton(
                        title: "COE",
                        icon: nil,
                        selectedItems: Array(selectedCOEs).map(String.init).sorted(),
                        action: { showingCOESheet = true },
                        onClear: { selectedCOEs.removeAll() }
                    )

                    // Tag filter chip
                    FilterChipButton(
                        title: "Tags",
                        icon: "tag",
                        selectedItems: Array(selectedTags).sorted(),
                        action: { showingTagsSheet = true },
                        onClear: { selectedTags.removeAll() }
                    )

                    // Manufacturer filter chip
                    FilterChipButton(
                        title: "Mfr",
                        icon: "building.2",
                        selectedItems: Array(selectedManufacturers).sorted().map { $0.uppercased() },
                        action: { showingManufacturerSheet = true },
                        onClear: { selectedManufacturers.removeAll() }
                    )
                }
            }
            .padding(.horizontal, DesignSystem.Padding.standard)
            .padding(.bottom, DesignSystem.Spacing.md)
        }
        .background(DesignSystem.Colors.background)
    }
}

// MARK: - Filter Chip Button

private struct FilterChipButton: View {
    let title: String
    let icon: String?
    let selectedItems: [String]
    let action: () -> Void
    let onClear: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if selectedItems.isEmpty {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(DesignSystem.Typography.captionSmall)
                    }
                    Text(title)
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.medium)
                } else {
                    // Show first 2 items inline
                    ForEach(Array(selectedItems.prefix(2)), id: \.self) { item in
                        Text(item)
                            .font(DesignSystem.Typography.captionSmall)
                            .fontWeight(DesignSystem.FontWeight.bold)
                            .lineLimit(1)
                    }
                    if selectedItems.count > 2 {
                        Text("+\(selectedItems.count - 2)")
                            .font(DesignSystem.Typography.captionSmall)
                            .fontWeight(DesignSystem.FontWeight.medium)
                    }
                    // X button to clear
                    Image(systemName: "xmark.circle.fill")
                        .font(DesignSystem.Typography.captionSmall)
                        .onTapGesture {
                            onClear()
                        }
                }
                if selectedItems.isEmpty {
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
            }
            .foregroundColor(selectedItems.isEmpty ? .secondary : .white)
            .padding(.horizontal, DesignSystem.Padding.chip)
            .padding(.vertical, DesignSystem.Padding.chipVertical)
            .background(selectedItems.isEmpty ? Color(.systemGray6) : Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
    }
}

// MARK: - Product Type Filter Menu

private struct ProductTypeFilterMenu: View {
    let selectedProductTypes: Binding<Set<String>>
    let availableTypes: [String]
    let displayName: (String) -> String

    var body: some View {
        Menu {
            // Single-select product type options
            ForEach(availableTypes, id: \.self) { type in
                Button {
                    withAnimation {
                        // Single-select: replace all selections with this one type
                        selectedProductTypes.wrappedValue.removeAll()
                        selectedProductTypes.wrappedValue.insert(type)
                    }
                } label: {
                    HStack {
                        Text(displayName(type))
                        Spacer()
                        if selectedProductTypes.wrappedValue.contains(type) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Show selected type (always has a selection)
                if let selectedType = selectedProductTypes.wrappedValue.first {
                    Text(displayName(selectedType))
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.medium)
                        .lineLimit(1)
                } else {
                    // Fallback if somehow empty
                    Image(systemName: "square.stack.3d.up")
                        .font(DesignSystem.Typography.captionSmall)
                    Text("Type")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.medium)
                }

                // Always show dropdown arrow
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundColor(DesignSystem.Colors.textSecondary)
            .padding(.horizontal, DesignSystem.Padding.chip + DesignSystem.Spacing.xs)
            .padding(.vertical, DesignSystem.Padding.buttonVertical)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
    }
}

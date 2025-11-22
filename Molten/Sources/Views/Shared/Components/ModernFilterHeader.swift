//
//  ModernFilterHeader.swift
//  Molten
//
//  Reusable filter header component for modern search pattern
//  Used by Catalog and Inventory views
//

import SwiftUI

/// Modern filter header with sort button and filter chips
/// Designed to work with SwiftUI's native .searchable() modifier
/// Note: "Search titles only" toggle should be added to .searchable() content block, not here
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

    // MARK: - Optional Store Filter
    var storeFilter: StoreFilterConfig?

    struct StoreFilterConfig {
        var selectedStore: Binding<String?>
        let availableStores: [String]
        let onClear: () -> Void
    }

    // MARK: - Optional COE Filter
    var coeFilter: COEFilterConfig?

    struct COEFilterConfig {
        var selectedCOEs: Binding<Set<Int32>>
        let availableCOEs: [Int32]
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
        productTypeFilter: ProductTypeFilterConfig? = nil,
        storeFilter: StoreFilterConfig? = nil,
        coeFilter: COEFilterConfig? = nil
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
        self.storeFilter = storeFilter
        self.coeFilter = coeFilter
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.none) {
            // Top row: Optional store filter (left) and Sort button (right)
            // Note: "Search titles only" toggle is in the search bar via .searchScopes() modifier
            HStack {
                // Optional store filter (only show if multiple stores available)
                if let storeConfig = storeFilter, storeConfig.availableStores.count > 1 {
                    // Use FilterChipButton pattern with Menu
                    Menu {
                        // Clear option
                        Button {
                            storeConfig.onClear()
                        } label: {
                            Text("All Stores")
                        }

                        Divider()

                        // Store options
                        ForEach(storeConfig.availableStores, id: \.self) { store in
                            Button {
                                storeConfig.selectedStore.wrappedValue = store
                            } label: {
                                if storeConfig.selectedStore.wrappedValue == store {
                                    Label(store, systemImage: "checkmark")
                                } else {
                                    Text(store)
                                }
                            }
                        }
                    } label: {
                        // Match FilterChipButton exactly
                        Button(action: {}) {
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                if let selected = storeConfig.selectedStore.wrappedValue {
                                    // Show selected store with X to clear
                                    Text(selected)
                                        .font(DesignSystem.Typography.captionSmall)
                                        .fontWeight(DesignSystem.FontWeight.bold)
                                        .lineLimit(1)
                                    Image(systemName: "xmark.circle.fill")
                                        .font(DesignSystem.Typography.captionSmall)
                                        .onTapGesture {
                                            storeConfig.onClear()
                                        }
                                } else {
                                    // Show "All Stores" label with chevron (no icon)
                                    Text("All Stores")
                                        .font(DesignSystem.Typography.caption)
                                        .fontWeight(DesignSystem.FontWeight.medium)
                                    Image(systemName: "chevron.down")
                                        .font(.caption2)
                                }
                            }
                            .foregroundColor(storeConfig.selectedStore.wrappedValue != nil ? .white : .secondary)
                            .padding(.horizontal, DesignSystem.Padding.chip)
                            .padding(.vertical, DesignSystem.Padding.chipVertical)
                            .background(storeConfig.selectedStore.wrappedValue != nil ? DesignSystem.Colors.accentPrimary : Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                        }
                        .buttonStyle(.plain)
                    }
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
                    // COE filter - use inline menu if coeFilter config provided, otherwise use sheet
                    if let coeConfig = coeFilter {
                        COEFilterMenu(
                            selectedCOEs: coeConfig.selectedCOEs,
                            availableCOEs: coeConfig.availableCOEs
                        )
                    } else {
                        // Fallback to sheet-based filter chip
                        FilterChipButton(
                            title: "COE",
                            icon: nil,
                            selectedItems: Array(selectedCOEs).map(String.init).sorted(),
                            action: { showingCOESheet = true },
                            onClear: { selectedCOEs.removeAll() }
                        )
                    }

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
            .background(selectedItems.isEmpty ? Color(.systemGray6) : DesignSystem.Colors.accentPrimary)
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
            // "All types" option - shows all product types
            Button {
                withAnimation {
                    selectedProductTypes.wrappedValue.removeAll()
                }
            } label: {
                HStack {
                    Text("All types")
                    Spacer()
                    if selectedProductTypes.wrappedValue.isEmpty {
                        Image(systemName: "checkmark")
                    }
                }
            }

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
                // Show selected type or "All types" if empty
                if let selectedType = selectedProductTypes.wrappedValue.first {
                    Text(displayName(selectedType))
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.medium)
                        .lineLimit(1)
                } else {
                    // Show "All types" when no specific type is selected
                    Text("All types")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.medium)
                }

                // Always show dropdown arrow
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundColor(DesignSystem.Colors.textSecondary)
            .padding(.horizontal, DesignSystem.Padding.chip)
            .padding(.vertical, DesignSystem.Padding.chipVertical)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
    }
}

// MARK: - COE Filter Menu

private struct COEFilterMenu: View {
    let selectedCOEs: Binding<Set<Int32>>
    let availableCOEs: [Int32]

    var body: some View {
        Menu {
            // "All COEs" option
            Button {
                withAnimation {
                    selectedCOEs.wrappedValue.removeAll()
                }
            } label: {
                HStack {
                    Text("All COEs")
                    Spacer()
                    if selectedCOEs.wrappedValue.isEmpty {
                        Image(systemName: "checkmark")
                    }
                }
            }

            Divider()

            // Multi-select COE options
            ForEach(availableCOEs.sorted(), id: \.self) { coe in
                Button {
                    withAnimation {
                        if selectedCOEs.wrappedValue.contains(coe) {
                            selectedCOEs.wrappedValue.remove(coe)
                        } else {
                            selectedCOEs.wrappedValue.insert(coe)
                        }
                    }
                } label: {
                    HStack {
                        Text(String(coe))
                        Spacer()
                        if selectedCOEs.wrappedValue.contains(coe) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if selectedCOEs.wrappedValue.isEmpty {
                    // Show "COE" label with chevron
                    Text("COE")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.medium)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                } else {
                    // Show selected COEs
                    let sortedCOEs = Array(selectedCOEs.wrappedValue).sorted()
                    ForEach(Array(sortedCOEs.prefix(2)), id: \.self) { coe in
                        Text(String(coe))
                            .font(DesignSystem.Typography.captionSmall)
                            .fontWeight(DesignSystem.FontWeight.bold)
                            .lineLimit(1)
                    }
                    if sortedCOEs.count > 2 {
                        Text("+\(sortedCOEs.count - 2)")
                            .font(DesignSystem.Typography.captionSmall)
                            .fontWeight(DesignSystem.FontWeight.medium)
                    }
                    // X button to clear
                    Image(systemName: "xmark.circle.fill")
                        .font(DesignSystem.Typography.captionSmall)
                        .onTapGesture {
                            selectedCOEs.wrappedValue.removeAll()
                        }
                }
            }
            .foregroundColor(selectedCOEs.wrappedValue.isEmpty ? .secondary : .white)
            .padding(.horizontal, DesignSystem.Padding.chip)
            .padding(.vertical, DesignSystem.Padding.chipVertical)
            .background(selectedCOEs.wrappedValue.isEmpty ? Color(.systemGray6) : DesignSystem.Colors.accentPrimary)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
    }
}

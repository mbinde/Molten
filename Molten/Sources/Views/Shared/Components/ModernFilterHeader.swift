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
        let typeCounts: [String: Int]
    }

    // MARK: - Optional Store Filter
    var storeFilter: StoreFilterConfig?

    struct StoreFilterConfig {
        var selectedStore: Binding<String?>
        let availableStores: [String]
        let itemCounts: [String: Int]
        let onClear: () -> Void
    }

    // MARK: - Optional Location Filter
    var locationFilter: LocationFilterConfig?

    struct LocationFilterConfig {
        var selectedLocation: Binding<String?>
        let availableLocations: [String]
        let itemCounts: [String: Int]
        let onClear: () -> Void
    }

    // MARK: - Optional Inventory Type Filter (Kind)
    var inventoryTypeFilter: InventoryTypeFilterConfig?

    struct InventoryTypeFilterConfig {
        var selectedType: Binding<String?>
        let availableTypes: [String]
        let itemCounts: [String: Int]
        let displayName: (String) -> String
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
        locationFilter: LocationFilterConfig? = nil,
        inventoryTypeFilter: InventoryTypeFilterConfig? = nil,
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
        self.locationFilter = locationFilter
        self.inventoryTypeFilter = inventoryTypeFilter
        self.coeFilter = coeFilter
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.none) {
            // Top row: Optional store filter (left) and Sort button (right)
            // Note: "Search titles only" toggle is in the search bar via .searchScopes() modifier
            HStack {
                // Optional store filter
                if let storeConfig = storeFilter {
                    StoreFilterMenu(
                        selectedStore: storeConfig.selectedStore,
                        availableStores: storeConfig.availableStores,
                        itemCounts: storeConfig.itemCounts,
                        onClear: storeConfig.onClear
                    )
                    .id("store-filter") // Force stable identity
                }

                // Optional location filter
                if let locationConfig = locationFilter {
                    LocationFilterMenu(
                        selectedLocation: locationConfig.selectedLocation,
                        availableLocations: locationConfig.availableLocations,
                        itemCounts: locationConfig.itemCounts,
                        onClear: locationConfig.onClear
                    )
                    .id("location-filter") // Force stable identity
                }

                // Optional inventory type filter (Kind)
                if let typeConfig = inventoryTypeFilter {
                    InventoryTypeFilterMenu(
                        selectedType: typeConfig.selectedType,
                        availableTypes: typeConfig.availableTypes,
                        itemCounts: typeConfig.itemCounts,
                        displayName: typeConfig.displayName,
                        onClear: typeConfig.onClear
                    )
                    .id("kind-filter") // Force stable identity
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
                if let productTypeConfig = productTypeFilter {
                    ProductTypeFilterMenu(
                        selectedProductTypes: productTypeConfig.selectedProductTypes,
                        availableTypes: productTypeConfig.availableTypes,
                        displayName: productTypeConfig.displayName,
                        typeCounts: productTypeConfig.typeCounts
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
                            onClear: { selectedCOEs.removeAll() },
                            accessibilityId: "filter_chip_coe"
                        )
                    }

                    // Tag filter chip
                    FilterChipButton(
                        title: "Tags",
                        icon: "tag",
                        selectedItems: Array(selectedTags).sorted(),
                        action: { showingTagsSheet = true },
                        onClear: { selectedTags.removeAll() },
                        accessibilityId: "filter_chip_tags"
                    )

                    // Manufacturer filter chip
                    FilterChipButton(
                        title: "Mfr",
                        icon: "building.2",
                        selectedItems: Array(selectedManufacturers).sorted().map { $0.uppercased() },
                        action: { showingManufacturerSheet = true },
                        onClear: { selectedManufacturers.removeAll() },
                        accessibilityId: "filter_chip_manufacturer"
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
    var accessibilityId: String? = nil

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
        .accessibilityIdentifier(accessibilityId ?? "")
    }
}

// MARK: - Product Type Filter Menu

private struct ProductTypeFilterMenu: View {
    let selectedProductTypes: Binding<Set<String>>
    let availableTypes: [String]
    let displayName: (String) -> String
    let typeCounts: [String: Int]

    /// Total count across all types
    private var totalCount: Int {
        typeCounts.values.reduce(0, +)
    }

    var body: some View {
        Menu {
            // "All types" option - shows all product types
            Button {
                withAnimation {
                    selectedProductTypes.wrappedValue.removeAll()
                }
            } label: {
                if selectedProductTypes.wrappedValue.isEmpty {
                    Label("All types (\(totalCount))", systemImage: "checkmark")
                } else {
                    Text("All types (\(totalCount))")
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
                    if selectedProductTypes.wrappedValue.contains(type) {
                        Label("\(displayName(type)) (\(typeCounts[type] ?? 0))", systemImage: "checkmark")
                    } else {
                        Text("\(displayName(type)) (\(typeCounts[type] ?? 0))")
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

// MARK: - Store Filter Menu

private struct StoreFilterMenu: View {
    let selectedStore: Binding<String?>
    let availableStores: [String]
    let itemCounts: [String: Int]
    let onClear: () -> Void

    var body: some View {
        Menu {
            // Clear option
            Button {
                onClear()
            } label: {
                Text("All Stores")
            }

            Divider()

            // Store options
            ForEach(availableStores, id: \.self) { store in
                Button {
                    selectedStore.wrappedValue = store
                } label: {
                    if selectedStore.wrappedValue == store {
                        if let count = itemCounts[store] {
                            Label("\(store) (\(count))", systemImage: "checkmark")
                        } else {
                            Label(store, systemImage: "checkmark")
                        }
                    } else {
                        if let count = itemCounts[store] {
                            Text("\(store) (\(count))")
                        } else {
                            Text(store)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if let selected = selectedStore.wrappedValue {
                    Text(selected)
                        .font(DesignSystem.Typography.captionSmall)
                        .fontWeight(DesignSystem.FontWeight.bold)
                        .lineLimit(1)
                    // X button to clear
                    Image(systemName: "xmark.circle.fill")
                        .font(DesignSystem.Typography.captionSmall)
                        .onTapGesture {
                            onClear()
                        }
                } else {
                    Text("All Stores")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.medium)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
            }
            .foregroundColor(selectedStore.wrappedValue != nil ? .white : .secondary)
            .padding(.horizontal, DesignSystem.Padding.chip)
            .padding(.vertical, DesignSystem.Padding.chipVertical)
            .background(selectedStore.wrappedValue != nil ? DesignSystem.Colors.accentPrimary : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
    }
}

// MARK: - Location Filter Menu

private struct LocationFilterMenu: View {
    let selectedLocation: Binding<String?>
    let availableLocations: [String]
    let itemCounts: [String: Int]
    let onClear: () -> Void

    var body: some View {
        Menu {
            // Clear option
            Button {
                onClear()
            } label: {
                Text("All Locations")
            }

            Divider()

            // Location options
            ForEach(availableLocations, id: \.self) { location in
                Button {
                    selectedLocation.wrappedValue = location
                } label: {
                    if selectedLocation.wrappedValue == location {
                        if let count = itemCounts[location] {
                            Label("\(location) (\(count))", systemImage: "checkmark")
                        } else {
                            Label(location, systemImage: "checkmark")
                        }
                    } else {
                        if let count = itemCounts[location] {
                            Text("\(location) (\(count))")
                        } else {
                            Text(location)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if let selected = selectedLocation.wrappedValue {
                    Text(selected)
                        .font(DesignSystem.Typography.captionSmall)
                        .fontWeight(DesignSystem.FontWeight.bold)
                        .lineLimit(1)
                    // X button to clear
                    Image(systemName: "xmark.circle.fill")
                        .font(DesignSystem.Typography.captionSmall)
                        .onTapGesture {
                            onClear()
                        }
                } else {
                    Text("All Locations")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.medium)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
            }
            .foregroundColor(selectedLocation.wrappedValue != nil ? .white : .secondary)
            .padding(.horizontal, DesignSystem.Padding.chip)
            .padding(.vertical, DesignSystem.Padding.chipVertical)
            .background(selectedLocation.wrappedValue != nil ? DesignSystem.Colors.accentPrimary : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
    }
}

// MARK: - Inventory Type Filter Menu

private struct InventoryTypeFilterMenu: View {
    let selectedType: Binding<String?>
    let availableTypes: [String]
    let itemCounts: [String: Int]
    let displayName: (String) -> String
    let onClear: () -> Void

    var body: some View {
        Menu {
            // Clear option
            Button {
                onClear()
            } label: {
                Text("All Kinds")
            }

            Divider()

            // Inventory type options
            ForEach(availableTypes, id: \.self) { type in
                Button {
                    selectedType.wrappedValue = type
                } label: {
                    let displayName = displayName(type)
                    if selectedType.wrappedValue == type {
                        if let count = itemCounts[type] {
                            Label("\(displayName) (\(count))", systemImage: "checkmark")
                        } else {
                            Label(displayName, systemImage: "checkmark")
                        }
                    } else {
                        if let count = itemCounts[type] {
                            Text("\(displayName) (\(count))")
                        } else {
                            Text(displayName)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if let selected = selectedType.wrappedValue {
                    Text(displayName(selected))
                        .font(DesignSystem.Typography.captionSmall)
                        .fontWeight(DesignSystem.FontWeight.bold)
                        .lineLimit(1)
                    // X button to clear
                    Image(systemName: "xmark.circle.fill")
                        .font(DesignSystem.Typography.captionSmall)
                        .onTapGesture {
                            onClear()
                        }
                } else {
                    Text("All Kinds")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.medium)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
            }
            .foregroundColor(selectedType.wrappedValue != nil ? .white : .secondary)
            .padding(.horizontal, DesignSystem.Padding.chip)
            .padding(.vertical, DesignSystem.Padding.chipVertical)
            .background(selectedType.wrappedValue != nil ? DesignSystem.Colors.accentPrimary : Color(.systemGray6))
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

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

    // MARK: - Display Density
    private var displayDensity: UserSettings.DisplayDensity {
        UserSettings.shared.displayDensity
    }

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

    // MARK: - Sort Visibility
    var showSort: Bool = true

    // MARK: - Comfortable Mode Sheet
    @State private var showingFiltersSheet: Bool = false

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
        coeFilter: COEFilterConfig? = nil,
        showSort: Bool = true
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
        self.showSort = showSort
    }

    var body: some View {
        Group {
            if displayDensity == .comfortable {
                comfortableLayout
            } else {
                compactLayout
            }
        }
        .background(DesignSystem.Colors.background)
        .sheet(isPresented: $showingFiltersSheet) {
            ComfortableFiltersSheet(
                selectedTags: $selectedTags,
                selectedCOEs: $selectedCOEs,
                selectedManufacturers: $selectedManufacturers,
                showingTagsSheet: $showingTagsSheet,
                showingCOESheet: $showingCOESheet,
                showingManufacturerSheet: $showingManufacturerSheet,
                selectedStore: storeFilter?.selectedStore,
                availableStores: storeFilter?.availableStores ?? [],
                storeItemCounts: storeFilter?.itemCounts ?? [:],
                onClearStore: storeFilter?.onClear,
                selectedLocation: locationFilter?.selectedLocation,
                availableLocations: locationFilter?.availableLocations ?? [],
                locationItemCounts: locationFilter?.itemCounts ?? [:],
                onClearLocation: locationFilter?.onClear,
                selectedInventoryType: inventoryTypeFilter?.selectedType,
                availableInventoryTypes: inventoryTypeFilter?.availableTypes ?? [],
                inventoryTypeItemCounts: inventoryTypeFilter?.itemCounts ?? [:],
                inventoryTypeDisplayName: inventoryTypeFilter?.displayName,
                onClearInventoryType: inventoryTypeFilter?.onClear,
                availableCOEs: coeFilter?.availableCOEs ?? []
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Comfortable Layout

    private var comfortableLayout: some View {
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

            // Filters button that opens sheet
            Button {
                showingFiltersSheet = true
            } label: {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(DesignSystem.Typography.formValue)
                    Text("Filters")
                        .font(DesignSystem.Typography.formValue)
                        .fontWeight(DesignSystem.FontWeight.medium)
                    if activeFilterCount > 0 {
                        Text("\(activeFilterCount)")
                            .font(DesignSystem.Typography.listItemCaptionSmall)
                            .fontWeight(DesignSystem.FontWeight.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.accentPrimary)
                            .clipShape(Capsule())
                    }
                }
                .foregroundColor(activeFilterCount > 0 ? DesignSystem.Colors.accentPrimary : DesignSystem.Colors.textPrimary)
                .padding(.horizontal, DesignSystem.Padding.standard)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
            }
            .accessibilityIdentifier("comfortable_filters_button")

            // Sort button (optional, shown by default)
            if showSort {
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
                            .font(DesignSystem.Typography.formValue)
                        Text("Sort")
                            .font(DesignSystem.Typography.formValue)
                            .fontWeight(DesignSystem.FontWeight.medium)
                    }
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding(.horizontal, DesignSystem.Padding.standard)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
                }
            }
        }
        .padding(.horizontal, DesignSystem.Padding.standard)
        .padding(.vertical, DesignSystem.Spacing.md)
    }

    // MARK: - Compact Layout (Original)

    private var compactLayout: some View {
        VStack(spacing: DesignSystem.Spacing.none) {
            // Top row: Optional store/location/kind filters (left) and Sort button (right)
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Optional store filter
                if let storeConfig = storeFilter {
                    StoreFilterMenu(
                        selectedStore: storeConfig.selectedStore,
                        availableStores: storeConfig.availableStores,
                        itemCounts: storeConfig.itemCounts,
                        onClear: storeConfig.onClear
                    )
                    .id("store-filter")
                }

                // Optional location filter
                if let locationConfig = locationFilter {
                    LocationFilterMenu(
                        selectedLocation: locationConfig.selectedLocation,
                        availableLocations: locationConfig.availableLocations,
                        itemCounts: locationConfig.itemCounts,
                        onClear: locationConfig.onClear
                    )
                    .id("location-filter")
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
                    .id("kind-filter")
                }

                Spacer()

                // Sort button (optional, shown by default)
                if showSort {
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
            }
            .padding(.horizontal, DesignSystem.Padding.standard)
            .padding(.top, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.xs)

            // Bottom row: Product type (left) and filter chips (right)
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

                // Right: Filter chips (COE, Tags, Mfr)
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
    }

    // MARK: - Helpers

    private var activeFilterCount: Int {
        var count = 0
        if !selectedTags.isEmpty { count += 1 }
        if !selectedCOEs.isEmpty { count += 1 }
        if !selectedManufacturers.isEmpty { count += 1 }
        if let storeConfig = storeFilter, storeConfig.selectedStore.wrappedValue != nil { count += 1 }
        if let locationConfig = locationFilter, locationConfig.selectedLocation.wrappedValue != nil { count += 1 }
        if let typeConfig = inventoryTypeFilter, typeConfig.selectedType.wrappedValue != nil { count += 1 }
        return count
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

// MARK: - Comfortable Filters Sheet

/// A spacious filter sheet for Comfortable display density mode
private struct ComfortableFiltersSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedTags: Set<String>
    @Binding var selectedCOEs: Set<Int32>
    @Binding var selectedManufacturers: Set<String>
    @Binding var showingTagsSheet: Bool
    @Binding var showingCOESheet: Bool
    @Binding var showingManufacturerSheet: Bool

    // Store filter data (simplified)
    private var selectedStore: Binding<String?>?
    private var availableStores: [String]
    private var storeItemCounts: [String: Int]
    private var onClearStore: (() -> Void)?

    // Location filter data
    private var selectedLocation: Binding<String?>?
    private var availableLocations: [String]
    private var locationItemCounts: [String: Int]
    private var onClearLocation: (() -> Void)?

    // Inventory type filter data
    private var selectedInventoryType: Binding<String?>?
    private var availableInventoryTypes: [String]
    private var inventoryTypeItemCounts: [String: Int]
    private var inventoryTypeDisplayName: ((String) -> String)?
    private var onClearInventoryType: (() -> Void)?

    // COE filter data
    private var availableCOEs: [Int32]

    init(
        selectedTags: Binding<Set<String>>,
        selectedCOEs: Binding<Set<Int32>>,
        selectedManufacturers: Binding<Set<String>>,
        showingTagsSheet: Binding<Bool>,
        showingCOESheet: Binding<Bool>,
        showingManufacturerSheet: Binding<Bool>,
        selectedStore: Binding<String?>? = nil,
        availableStores: [String] = [],
        storeItemCounts: [String: Int] = [:],
        onClearStore: (() -> Void)? = nil,
        selectedLocation: Binding<String?>? = nil,
        availableLocations: [String] = [],
        locationItemCounts: [String: Int] = [:],
        onClearLocation: (() -> Void)? = nil,
        selectedInventoryType: Binding<String?>? = nil,
        availableInventoryTypes: [String] = [],
        inventoryTypeItemCounts: [String: Int] = [:],
        inventoryTypeDisplayName: ((String) -> String)? = nil,
        onClearInventoryType: (() -> Void)? = nil,
        availableCOEs: [Int32] = []
    ) {
        self._selectedTags = selectedTags
        self._selectedCOEs = selectedCOEs
        self._selectedManufacturers = selectedManufacturers
        self._showingTagsSheet = showingTagsSheet
        self._showingCOESheet = showingCOESheet
        self._showingManufacturerSheet = showingManufacturerSheet
        self.selectedStore = selectedStore
        self.availableStores = availableStores
        self.storeItemCounts = storeItemCounts
        self.onClearStore = onClearStore
        self.selectedLocation = selectedLocation
        self.availableLocations = availableLocations
        self.locationItemCounts = locationItemCounts
        self.onClearLocation = onClearLocation
        self.selectedInventoryType = selectedInventoryType
        self.availableInventoryTypes = availableInventoryTypes
        self.inventoryTypeItemCounts = inventoryTypeItemCounts
        self.inventoryTypeDisplayName = inventoryTypeDisplayName
        self.onClearInventoryType = onClearInventoryType
        self.availableCOEs = availableCOEs
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Store filter
                    if let selectedStore = selectedStore, let onClear = onClearStore {
                        ComfortableFilterRow(
                            title: "Store",
                            icon: "storefront",
                            selectedValue: selectedStore.wrappedValue,
                            onClear: onClear
                        ) {
                            Menu {
                                Button("All Stores") {
                                    onClear()
                                }
                                Divider()
                                ForEach(availableStores, id: \.self) { store in
                                    Button {
                                        selectedStore.wrappedValue = store
                                    } label: {
                                        HStack {
                                            Text(store)
                                            if let count = storeItemCounts[store] {
                                                Text("(\(count))")
                                                    .foregroundColor(.secondary)
                                            }
                                            if selectedStore.wrappedValue == store {
                                                Spacer()
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                ComfortableFilterButton(
                                    text: selectedStore.wrappedValue ?? "All Stores",
                                    isSelected: selectedStore.wrappedValue != nil
                                )
                            }
                        }
                    }

                    // Location filter
                    if let selectedLocation = selectedLocation, let onClear = onClearLocation {
                        ComfortableFilterRow(
                            title: "Location",
                            icon: "mappin.and.ellipse",
                            selectedValue: selectedLocation.wrappedValue,
                            onClear: onClear
                        ) {
                            Menu {
                                Button("All Locations") {
                                    onClear()
                                }
                                Divider()
                                ForEach(availableLocations, id: \.self) { location in
                                    Button {
                                        selectedLocation.wrappedValue = location
                                    } label: {
                                        HStack {
                                            Text(location)
                                            if let count = locationItemCounts[location] {
                                                Text("(\(count))")
                                                    .foregroundColor(.secondary)
                                            }
                                            if selectedLocation.wrappedValue == location {
                                                Spacer()
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                ComfortableFilterButton(
                                    text: selectedLocation.wrappedValue ?? "All Locations",
                                    isSelected: selectedLocation.wrappedValue != nil
                                )
                            }
                        }
                    }

                    // Kind filter
                    if let selectedType = selectedInventoryType, let displayName = inventoryTypeDisplayName, let onClear = onClearInventoryType {
                        ComfortableFilterRow(
                            title: "Kind",
                            icon: "square.stack.3d.up",
                            selectedValue: selectedType.wrappedValue.map { displayName($0) },
                            onClear: onClear
                        ) {
                            Menu {
                                Button("All Kinds") {
                                    onClear()
                                }
                                Divider()
                                ForEach(availableInventoryTypes, id: \.self) { type in
                                    Button {
                                        selectedType.wrappedValue = type
                                    } label: {
                                        HStack {
                                            Text(displayName(type))
                                            if let count = inventoryTypeItemCounts[type] {
                                                Text("(\(count))")
                                                    .foregroundColor(.secondary)
                                            }
                                            if selectedType.wrappedValue == type {
                                                Spacer()
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                ComfortableFilterButton(
                                    text: selectedType.wrappedValue.map { displayName($0) } ?? "All Kinds",
                                    isSelected: selectedType.wrappedValue != nil
                                )
                            }
                        }
                    }

                    Divider()
                        .padding(.horizontal, DesignSystem.Padding.standard)

                    // COE filter
                    ComfortableFilterRow(
                        title: "COE",
                        icon: "thermometer.medium",
                        selectedValue: selectedCOEs.isEmpty ? nil : selectedCOEs.sorted().map(String.init).joined(separator: ", "),
                        onClear: { selectedCOEs.removeAll() }
                    ) {
                        if !availableCOEs.isEmpty {
                            Menu {
                                Button("All COEs") {
                                    selectedCOEs.removeAll()
                                }
                                Divider()
                                ForEach(availableCOEs.sorted(), id: \.self) { coe in
                                    Button {
                                        if selectedCOEs.contains(coe) {
                                            selectedCOEs.remove(coe)
                                        } else {
                                            selectedCOEs.insert(coe)
                                        }
                                    } label: {
                                        HStack {
                                            Text(String(coe))
                                            if selectedCOEs.contains(coe) {
                                                Spacer()
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                ComfortableFilterButton(
                                    text: selectedCOEs.isEmpty ? "All COEs" : selectedCOEs.sorted().map(String.init).joined(separator: ", "),
                                    isSelected: !selectedCOEs.isEmpty
                                )
                            }
                        } else {
                            Button {
                                dismiss()
                                showingCOESheet = true
                            } label: {
                                ComfortableFilterButton(
                                    text: selectedCOEs.isEmpty ? "Select COEs" : selectedCOEs.sorted().map(String.init).joined(separator: ", "),
                                    isSelected: !selectedCOEs.isEmpty
                                )
                            }
                        }
                    }

                    // Tags filter
                    ComfortableFilterRow(
                        title: "Tags",
                        icon: "tag",
                        selectedValue: selectedTags.isEmpty ? nil : Array(selectedTags).sorted().prefix(3).joined(separator: ", ") + (selectedTags.count > 3 ? "..." : ""),
                        onClear: { selectedTags.removeAll() }
                    ) {
                        Button {
                            dismiss()
                            showingTagsSheet = true
                        } label: {
                            ComfortableFilterButton(
                                text: selectedTags.isEmpty ? "Select Tags" : "\(selectedTags.count) selected",
                                isSelected: !selectedTags.isEmpty
                            )
                        }
                    }

                    // Manufacturer filter
                    ComfortableFilterRow(
                        title: "Manufacturer",
                        icon: "building.2",
                        selectedValue: selectedManufacturers.isEmpty ? nil : Array(selectedManufacturers).sorted().map { $0.uppercased() }.prefix(3).joined(separator: ", ") + (selectedManufacturers.count > 3 ? "..." : ""),
                        onClear: { selectedManufacturers.removeAll() }
                    ) {
                        Button {
                            dismiss()
                            showingManufacturerSheet = true
                        } label: {
                            ComfortableFilterButton(
                                text: selectedManufacturers.isEmpty ? "Select Manufacturers" : "\(selectedManufacturers.count) selected",
                                isSelected: !selectedManufacturers.isEmpty
                            )
                        }
                    }

                    Spacer(minLength: DesignSystem.Spacing.xl)
                }
                .padding(.top, DesignSystem.Spacing.lg)
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Clear All") {
                        selectedTags.removeAll()
                        selectedCOEs.removeAll()
                        selectedManufacturers.removeAll()
                        onClearStore?()
                        onClearLocation?()
                        onClearInventoryType?()
                    }
                    .foregroundColor(DesignSystem.Colors.accentDanger)
                }
            }
        }
    }
}

// MARK: - Comfortable Filter Row

private struct ComfortableFilterRow<Content: View>: View {
    let title: String
    let icon: String
    let selectedValue: String?
    let onClear: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Label(title, systemImage: icon)
                    .font(DesignSystem.Typography.listItemTitle)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                if selectedValue != nil {
                    Button {
                        onClear()
                    } label: {
                        Text("Clear")
                            .font(DesignSystem.Typography.listItemCaption)
                            .foregroundColor(DesignSystem.Colors.accentDanger)
                    }
                }
            }

            content()
        }
        .padding(.horizontal, DesignSystem.Padding.standard)
    }
}

// MARK: - Comfortable Filter Button

private struct ComfortableFilterButton: View {
    let text: String
    let isSelected: Bool

    var body: some View {
        HStack {
            Text(text)
                .font(DesignSystem.Typography.formValue)
                .foregroundColor(isSelected ? DesignSystem.Colors.accentPrimary : DesignSystem.Colors.textPrimary)
                .lineLimit(1)

            Spacer()

            Image(systemName: "chevron.down")
                .font(DesignSystem.Typography.listItemCaption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .padding(.horizontal, DesignSystem.Padding.standard)
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
    }
}

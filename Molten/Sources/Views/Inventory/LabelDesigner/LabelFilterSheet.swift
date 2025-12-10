//
//  LabelFilterSheet.swift
//  Molten
//
//  Sheet for selecting which inventory items to include when printing labels
//  Uses inclusion model - nothing selected by default, user adds items to print
//

import SwiftUI

// MARK: - Date Filter Enum

/// Filter options for date-based filtering
enum LabelDateFilter: String, CaseIterable, Sendable {
    case any = "Any"
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case last3Months = "Last 3 Months"
    case thisYear = "This Year"

    /// Check if a date matches this filter
    func matches(date: Date) -> Bool {
        switch self {
        case .any:
            return true
        case .today:
            return Calendar.current.isDateInToday(date)
        case .thisWeek:
            return Calendar.current.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
        case .thisMonth:
            return Calendar.current.isDate(date, equalTo: Date(), toGranularity: .month)
        case .last3Months:
            guard let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date()) else {
                return false
            }
            return date >= threeMonthsAgo
        case .thisYear:
            return Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year)
        }
    }
}

// MARK: - Inventory Row Model

/// Represents a single inventory record row in the filter sheet
struct InventoryFilterRow: Identifiable {
    let item: CompleteInventoryItemModel
    let inventory: InventoryModel
    let storageLocation: StorageLocationModel?  // Associated storage location (if any)

    var id: UUID { inventory.id }

    /// Display name combining item name and type info
    var displayName: String {
        item.catalogItem.name
    }

    /// Type path (type/subtype/subsubtype)
    var typePath: String {
        inventory.fullTypePath
    }

    /// Short type description
    var typeDescription: String {
        inventory.typeDescription
    }

    /// Location name (from StorageLocation or fallback to Inventory.location)
    var locationName: String? {
        if let loc = storageLocation {
            return loc.locationName
        }
        return inventory.location
    }

    /// Date added at current location (from StorageLocation or fallback to Inventory.date_added)
    var dateAddedAtLocation: Date {
        if let loc = storageLocation {
            return loc.dateAdded
        }
        return inventory.date_added
    }

    /// Whether this is a transferred inventory (moved from another location)
    var isTransfer: Bool {
        storageLocation?.isTransfer ?? false
    }
}

// MARK: - Label Filter Sheet

/// Sheet for selecting which items to include in label printing
/// Uses inclusion model - start with nothing selected, add items to print
struct LabelFilterSheet: View {
    let items: [CompleteInventoryItemModel]
    let selectedFormat: LabelGeometry  // Current label format for sheet capacity info
    @Binding var selectedInventoryIds: Set<UUID>  // What we want to print
    @Binding var inventoryLabelCounts: [UUID: Int]
    @Binding var showAllSelected: Bool  // Override filters to show all selected
    @Binding var locationFilter: String?
    @Binding var dateAddedFilter: LabelDateFilter
    @Binding var dateModifiedFilter: LabelDateFilter

    @Environment(\.dismiss) private var dismiss

    // Local state for editing before applying
    @State private var localSelected: Set<UUID> = []
    @State private var localLabelCounts: [UUID: Int] = [:]
    @State private var localShowAllSelected: Bool = false
    @State private var localLocation: String?
    @State private var localDateAdded: LabelDateFilter = .any
    @State private var localDateModified: LabelDateFilter = .any

    /// All unique locations from the items
    private var allLocations: [String] {
        let locations = items.flatMap { $0.locations }
        return Array(Set(locations)).sorted()
    }

    /// All inventory rows (one per inventory record)
    private var allInventoryRows: [InventoryFilterRow] {
        items.flatMap { item in
            item.inventory.map { inv in
                // Find matching StorageLocation for this inventory record
                let storageLocation = item.storageLocations.first { $0.inventoryId == inv.id }
                return InventoryFilterRow(item: item, inventory: inv, storageLocation: storageLocation)
            }
        }
    }

    /// Inventory rows after applying date and location filters
    /// When showAllSelected is true, shows all selected items regardless of filters
    private var filteredRows: [InventoryFilterRow] {
        if localShowAllSelected {
            // Show only selected items, regardless of filters
            return allInventoryRows.filter { localSelected.contains($0.id) }
        }

        return allInventoryRows.filter { row in
            // Check location filter (uses StorageLocation.locationName or Inventory.location fallback)
            if let location = localLocation {
                if row.locationName != location {
                    return false
                }
            }

            // Check date added filter (uses StorageLocation.dateAdded or Inventory.date_added fallback)
            // Also filters out transfers when using date filter - transfers shouldn't trigger "new" label printing
            if localDateAdded != .any {
                // Exclude transfers when filtering by date added (transfers are not "new" inventory)
                if row.isTransfer {
                    return false
                }
                let dateToCheck = row.dateAddedAtLocation
                if !localDateAdded.matches(date: dateToCheck) {
                    return false
                }
            }

            // Check date modified filter (still uses Inventory.date_modified)
            if localDateModified != .any {
                if !localDateModified.matches(date: row.inventory.date_modified) {
                    return false
                }
            }

            return true
        }
    }

    /// Rows grouped by item for display
    private var rowsGroupedByItem: [(item: CompleteInventoryItemModel, rows: [InventoryFilterRow])] {
        let grouped = Dictionary(grouping: filteredRows) { $0.item.id }
        return items.compactMap { item in
            guard let rows = grouped[item.id], !rows.isEmpty else { return nil }
            return (item: item, rows: rows)
        }
    }

    /// Get label count for an inventory record (override or default)
    private func labelCount(for row: InventoryFilterRow) -> Int {
        if let override = localLabelCounts[row.id] {
            return override
        }
        return row.inventory.defaultLabelCount
    }

    /// Total labels to print (sum of all selected rows)
    private var totalLabelsToPrint: Int {
        allInventoryRows
            .filter { localSelected.contains($0.id) }
            .reduce(0) { $0 + labelCount(for: $1) }
    }

    /// Count of inventory records that are selected
    private var selectedCount: Int {
        localSelected.count
    }

    /// Count of selected items visible in current filter
    private var selectedVisibleCount: Int {
        filteredRows.filter { localSelected.contains($0.id) }.count
    }

    /// Count of selected items NOT visible in current filter (hidden by filters)
    private var selectedHiddenCount: Int {
        selectedCount - selectedVisibleCount
    }

    /// Total inventory record count
    private var totalCount: Int {
        allInventoryRows.count
    }

    /// Whether all visible rows are selected
    private var allVisibleSelected: Bool {
        filteredRows.allSatisfy { localSelected.contains($0.id) }
    }

    /// Whether no visible rows are selected
    private var noneVisibleSelected: Bool {
        filteredRows.allSatisfy { !localSelected.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Summary section
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Labels to print")
                            Spacer()
                            Text("\(totalLabelsToPrint)")
                                .font(.headline)
                                .foregroundColor(selectedCount > 0 ? .accentColor : .secondary)
                        }
                        Text("\(selectedCount) inventory type\(selectedCount == 1 ? "" : "s") selected")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        if totalLabelsToPrint > 0 {
                            if totalLabelsToPrint < selectedFormat.labelsPerSheet {
                                Text("Less than 1 sheet (\(selectedFormat.labelsPerSheet) labels per sheet)")
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            } else if totalLabelsToPrint > selectedFormat.labelsPerSheet {
                                let sheets = Int(ceil(Double(totalLabelsToPrint) / Double(selectedFormat.labelsPerSheet)))
                                Text("This will create \(sheets) sheets")
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            } else {
                                Text("Exactly 1 full sheet")
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }
                } footer: {
                    Text("Using \(selectedFormat.name)")
                        .font(.caption)
                }

                // Show All Selected toggle (when items are hidden by filters)
                if selectedHiddenCount > 0 && !localShowAllSelected {
                    Section {
                        Button {
                            localShowAllSelected = true
                        } label: {
                            HStack {
                                Image(systemName: "eye")
                                Text("Show All \(selectedCount) Selected")
                                Spacer()
                                Text("\(selectedHiddenCount) hidden by filters")
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }
                }

                // Return to filtered view (when showing all selected)
                if localShowAllSelected {
                    Section {
                        Button {
                            localShowAllSelected = false
                        } label: {
                            HStack {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                Text("Return to Filtered View")
                                Spacer()
                                if hasActiveFilters {
                                    Text("Filters active")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    } footer: {
                        Text("Currently showing all \(selectedCount) selected items. Tap to return to filtered view.")
                            .font(.caption)
                    }
                }

                // Filters section (hidden when showing all selected)
                if !localShowAllSelected {
                    // Location filter
                    if !allLocations.isEmpty {
                        Section("Filter by Location") {
                            Picker("Location", selection: $localLocation) {
                                Text("All Locations").tag(nil as String?)
                                ForEach(allLocations, id: \.self) { location in
                                    Text(location).tag(location as String?)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    // Date filters
                    Section("Filter by Date") {
                        Picker("Date Added", selection: $localDateAdded) {
                            ForEach(LabelDateFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }

                        Picker("Date Modified", selection: $localDateModified) {
                            ForEach(LabelDateFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                    }
                }

                // Inventory selection - grouped by item
                Section {
                    // Select all / none buttons for visible items
                    HStack {
                        Button("Select All Visible") {
                            for row in filteredRows {
                                localSelected.insert(row.id)
                            }
                        }
                        .disabled(allVisibleSelected)

                        Spacer()

                        Button("Deselect All Visible") {
                            for row in filteredRows {
                                localSelected.remove(row.id)
                            }
                        }
                        .disabled(noneVisibleSelected)
                    }
                    .buttonStyle(.borderless)

                    // Items with their inventory types
                    ForEach(rowsGroupedByItem, id: \.item.id) { group in
                        ItemWithInventorySection(
                            item: group.item,
                            rows: group.rows,
                            localSelected: $localSelected,
                            localLabelCounts: $localLabelCounts
                        )
                    }
                } header: {
                    if localShowAllSelected {
                        Text("Selected Items (\(filteredRows.count))")
                    } else {
                        Text("Select Inventory (\(filteredRows.count) shown)")
                    }
                } footer: {
                    if !localShowAllSelected && filteredRows.count < allInventoryRows.count {
                        Text("\(allInventoryRows.count - filteredRows.count) record\(allInventoryRows.count - filteredRows.count == 1 ? "" : "s") hidden by filters")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Select Labels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        // Apply local state to bindings
                        selectedInventoryIds = localSelected
                        inventoryLabelCounts = localLabelCounts
                        showAllSelected = localShowAllSelected
                        locationFilter = localLocation
                        dateAddedFilter = localDateAdded
                        dateModifiedFilter = localDateModified
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Clear Selection") {
                            localSelected = []
                            localLabelCounts = [:]
                        }

                        Button("Reset Filters") {
                            localLocation = nil
                            localDateAdded = .any
                            localDateModified = .any
                            localShowAllSelected = false
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                // Initialize local state from bindings
                localSelected = selectedInventoryIds
                localLabelCounts = inventoryLabelCounts
                localShowAllSelected = showAllSelected
                localLocation = locationFilter
                localDateAdded = dateAddedFilter
                localDateModified = dateModifiedFilter
            }
        }
    }

    /// Whether any filters are active
    private var hasActiveFilters: Bool {
        localLocation != nil || localDateAdded != .any || localDateModified != .any
    }
}

// MARK: - Item With Inventory Section

/// Shows an item with its inventory types as toggleable rows
/// When there's only one type, shows a single combined row
private struct ItemWithInventorySection: View {
    let item: CompleteInventoryItemModel
    let rows: [InventoryFilterRow]
    @Binding var localSelected: Set<UUID>
    @Binding var localLabelCounts: [UUID: Int]

    /// Whether all rows for this item are selected
    private var allItemRowsSelected: Bool {
        rows.allSatisfy { localSelected.contains($0.id) }
    }

    /// Whether no rows for this item are selected
    private var noItemRowsSelected: Bool {
        rows.allSatisfy { !localSelected.contains($0.id) }
    }

    /// Get label count for a row
    private func labelCount(for row: InventoryFilterRow) -> Int {
        localLabelCounts[row.id] ?? row.inventory.defaultLabelCount
    }

    var body: some View {
        if rows.count == 1, let row = rows.first {
            // Single type: show combined row
            SingleInventoryRow(
                item: item,
                row: row,
                isSelected: localSelected.contains(row.id),
                labelCount: Binding(
                    get: { labelCount(for: row) },
                    set: { localLabelCounts[row.id] = $0 }
                ),
                defaultCount: row.inventory.defaultLabelCount,
                onToggle: {
                    if localSelected.contains(row.id) {
                        localSelected.remove(row.id)
                    } else {
                        localSelected.insert(row.id)
                    }
                }
            )
        } else {
            // Multiple types: show header + indented rows
            // Item header row (toggles all inventory for this item)
            Button {
                if allItemRowsSelected {
                    // Deselect all
                    for row in rows {
                        localSelected.remove(row.id)
                    }
                } else {
                    // Select all
                    for row in rows {
                        localSelected.insert(row.id)
                    }
                }
            } label: {
                HStack {
                    // Checkbox showing aggregate state
                    Image(systemName: allItemRowsSelected ? "checkmark.circle.fill" :
                            (noItemRowsSelected ? "circle" : "minus.circle.fill"))
                        .foregroundColor(noItemRowsSelected ? .secondary : .accentColor)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.catalogItem.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            if let mfrName = GlassManufacturers.fullName(for: item.catalogItem.manufacturer) {
                                Text(mfrName)
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }

                            if let sku = item.catalogItem.sku {
                                Text(sku)
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }

                    Spacer()

                    // Total labels for this item (only selected rows)
                    let totalLabels = rows.filter { localSelected.contains($0.id) }
                        .reduce(0) { $0 + labelCount(for: $1) }
                    if totalLabels > 0 {
                        Text("\(totalLabels) labels")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .buttonStyle(.plain)

            // Individual inventory type rows (indented)
            ForEach(rows) { row in
                LabelInventoryTypeRow(
                    row: row,
                    isSelected: localSelected.contains(row.id),
                    labelCount: Binding(
                        get: { labelCount(for: row) },
                        set: { localLabelCounts[row.id] = $0 }
                    ),
                    defaultCount: row.inventory.defaultLabelCount,
                    onToggle: {
                        if localSelected.contains(row.id) {
                            localSelected.remove(row.id)
                        } else {
                            localSelected.insert(row.id)
                        }
                    }
                )
                .padding(.leading, 28)  // Indent under parent item
            }
        }
    }
}

// MARK: - Single Inventory Row

/// Combined row showing item name + type when there's only one inventory type
private struct SingleInventoryRow: View {
    let item: CompleteInventoryItemModel
    let row: InventoryFilterRow
    let isSelected: Bool
    @Binding var labelCount: Int
    let defaultCount: Int
    let onToggle: () -> Void

    @State private var labelCountText: String = ""

    var body: some View {
        HStack {
            // Checkbox button
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            // Item + type info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.catalogItem.name)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    // Type badge
                    Text(row.typeDescription)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }

                HStack(spacing: 8) {
                    // Manufacturer
                    if let mfrName = GlassManufacturers.fullName(for: item.catalogItem.manufacturer) {
                        Text(mfrName)
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    // Quantity
                    Text(row.inventory.formattedQuantityDisplay())
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    // Location
                    if let location = row.inventory.location {
                        Text(location)
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }

            Spacer()

            // Label count input (only when selected)
            if isSelected {
                LabelCountField(
                    count: $labelCount,
                    defaultCount: defaultCount
                )
            }
        }
        .opacity(isSelected ? 1.0 : 0.6)
    }
}

// MARK: - Label Inventory Type Row

/// Row showing a single inventory type with toggle for label selection
private struct LabelInventoryTypeRow: View {
    let row: InventoryFilterRow
    let isSelected: Bool
    @Binding var labelCount: Int
    let defaultCount: Int
    let onToggle: () -> Void

    var body: some View {
        HStack {
            // Checkbox button
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.body)
            }
            .buttonStyle(.plain)

            // Type info
            VStack(alignment: .leading, spacing: 2) {
                Text(row.typeDescription)
                    .font(.body)
                    .foregroundColor(.primary)

                HStack(spacing: 8) {
                    // Quantity
                    Text(row.inventory.formattedQuantityDisplay())
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    // Location
                    if let location = row.inventory.location {
                        Text(location)
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }

            Spacer()

            // Label count input (only when selected)
            if isSelected {
                LabelCountField(
                    count: $labelCount,
                    defaultCount: defaultCount
                )
            }
        }
        .opacity(isSelected ? 1.0 : 0.6)
    }
}

// MARK: - Label Count Field

/// Compact text field for entering label count
private struct LabelCountField: View {
    @Binding var count: Int
    let defaultCount: Int

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    /// Whether the count differs from default
    private var isModified: Bool {
        count != defaultCount
    }

    var body: some View {
        HStack(spacing: 4) {
            TextField("", text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 40)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(isModified ? Color.orange.opacity(0.2) : Color.secondary.opacity(0.1))
                .cornerRadius(6)
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    if let newCount = Int(newValue), newCount >= 0 {
                        count = newCount
                    }
                }
                .onSubmit {
                    // Ensure valid number on submit
                    if let newCount = Int(text), newCount >= 0 {
                        count = newCount
                    } else {
                        text = "\(count)"
                    }
                }

            Text("labels")
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .onAppear {
            text = "\(count)"
        }
        .onChange(of: count) { _, newValue in
            if !isFocused {
                text = "\(newValue)"
            }
        }
    }
}

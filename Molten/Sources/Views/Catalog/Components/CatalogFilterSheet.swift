//
//  CatalogFilterSheet.swift
//  Molten
//
//  Main filter sheet accessible from the floating filter button
//

import SwiftUI

struct CatalogFilterSheet: View {
    @Binding var isPresented: Bool

    // Sort
    @Binding var sortOption: SortOption
    let onSortChange: (SortOption) -> Void

    // Filters
    @Binding var selectedTags: Set<String>
    @Binding var selectedCOEs: Set<Int32>
    @Binding var selectedManufacturers: Set<String>
    @Binding var selectedProductTypes: Set<String>

    // Available options
    let allAvailableTags: [String]
    let allAvailableCOEs: [Int32]
    let availableManufacturers: [String]
    let availableProductTypes: [String]

    // Counts
    let tagCounts: [String: Int]
    let coeCounts: [Int32: Int]
    let manufacturerCounts: [String: Int]
    let productTypeCounts: [String: Int]

    // Display helpers
    let manufacturerDisplayName: (String) -> String
    let productTypeDisplayName: (String) -> String

    // State for tags sub-sheet
    @State private var showingTagsSheet = false

    // Manufacturer sort (persisted, defaults to count)
    @AppStorage("catalogFilterManufacturerSortByCount") private var manufacturerSortByCount = true

    var body: some View {
        NavigationStack {
            List {
                // Clear all filters button (top)
                if hasActiveFilters {
                    Section {
                        Button(role: .destructive) {
                            clearAllFilters()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Clear All Filters")
                                Spacer()
                            }
                        }
                    }
                }

                // Sort section
                Section("Sort") {
                    ForEach(availableSortOptions, id: \.self) { option in
                        Button {
                            sortOption = option
                            onSortChange(option)
                        } label: {
                            HStack {
                                Label(option.rawValue, systemImage: option.sortIcon)
                                    .foregroundColor(.primary)
                                Spacer()
                                if sortOption == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(DesignSystem.Colors.accentPrimary)
                                }
                            }
                        }
                    }
                }

                // Product Type filter (horizontal chips)
                Section("Product Type") {
                    HStack(spacing: 10) {
                        ForEach(availableProductTypes, id: \.self) { type in
                            ProductTypeChip(
                                type: type,
                                displayName: productTypeDisplayName(type),
                                count: productTypeCounts[type] ?? 0,
                                isSelected: selectedProductTypes.contains(type),
                                onTap: {
                                    if selectedProductTypes.contains(type) {
                                        selectedProductTypes.remove(type)
                                    } else {
                                        selectedProductTypes.insert(type)
                                    }
                                }
                            )
                        }
                        Spacer()
                    }
                }

                // COE filter (horizontal chips)
                if !allAvailableCOEs.isEmpty {
                    Section("COE") {
                        HStack(spacing: 10) {
                            ForEach(allAvailableCOEs, id: \.self) { coe in
                                COEChip(
                                    coe: coe,
                                    count: coeCounts[coe] ?? 0,
                                    isSelected: selectedCOEs.contains(coe),
                                    onTap: {
                                        if selectedCOEs.contains(coe) {
                                            selectedCOEs.remove(coe)
                                        } else {
                                            selectedCOEs.insert(coe)
                                        }
                                    }
                                )
                            }
                            Spacer()
                        }
                    }
                }

                // Tags filter (opens sub-sheet)
                if !allAvailableTags.isEmpty {
                    Section("Tags") {
                        Button {
                            showingTagsSheet = true
                        } label: {
                            HStack {
                                Text("Select Tags")
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedTags.isEmpty {
                                    Text("All")
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("\(selectedTags.count) selected")
                                        .foregroundColor(DesignSystem.Colors.accentPrimary)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .listRowBackground(selectedTags.isEmpty ? nil : DesignSystem.Colors.accentPrimary.opacity(0.15))
                    }
                }

                // Manufacturer filter
                if !availableManufacturers.isEmpty {
                    Section {
                        ForEach(sortedManufacturers, id: \.self) { manufacturer in
                            let count = manufacturerCounts[manufacturer] ?? 0
                            let isSelected = selectedManufacturers.contains(manufacturer)
                            let isDisabled = count == 0 && !isSelected
                            Button {
                                if selectedManufacturers.contains(manufacturer) {
                                    selectedManufacturers.remove(manufacturer)
                                } else {
                                    selectedManufacturers.insert(manufacturer)
                                }
                            } label: {
                                HStack {
                                    Text(manufacturerDisplayName(manufacturer))
                                        .foregroundColor(isDisabled ? .secondary : .primary)
                                    Spacer()
                                    Text("\(count)")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(DesignSystem.Colors.accentPrimary)
                                    }
                                }
                                .opacity(isDisabled ? 0.5 : 1.0)
                            }
                            .disabled(isDisabled)
                            .listRowBackground(isSelected ? DesignSystem.Colors.accentPrimary.opacity(0.15) : nil)
                        }
                    } header: {
                        HStack {
                            Text("Manufacturer")
                            Spacer()
                            Picker("Sort", selection: $manufacturerSortByCount) {
                                Text("A-Z").tag(false)
                                Text("Count").tag(true)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 120)
                        }
                    }
                }

                // Clear all filters button
                if hasActiveFilters {
                    Section {
                        Button(role: .destructive) {
                            clearAllFilters()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Clear All Filters")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter & Sort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showingTagsSheet) {
                TagFilterSubSheet(
                    selectedTags: $selectedTags,
                    allAvailableTags: allAvailableTags,
                    tagCounts: tagCounts
                )
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var hasActiveFilters: Bool {
        !selectedTags.isEmpty || !selectedCOEs.isEmpty ||
        !selectedManufacturers.isEmpty || !selectedProductTypes.isEmpty
    }

    private var sortedManufacturers: [String] {
        if manufacturerSortByCount {
            return availableManufacturers.sorted { manufacturer1, manufacturer2 in
                let count1 = manufacturerCounts[manufacturer1] ?? 0
                let count2 = manufacturerCounts[manufacturer2] ?? 0
                if count1 != count2 {
                    return count1 > count2
                }
                // Secondary sort by name when counts are equal
                return manufacturerDisplayName(manufacturer1)
                    .localizedCaseInsensitiveCompare(manufacturerDisplayName(manufacturer2)) == .orderedAscending
            }
        } else {
            return availableManufacturers.sorted {
                manufacturerDisplayName($0)
                    .localizedCaseInsensitiveCompare(manufacturerDisplayName($1)) == .orderedAscending
            }
        }
    }

    private var availableSortOptions: [SortOption] {
        SortOption.allCases.filter { option in
            // Hide rating sort option when ratings feature is disabled
            if option == .rating && !FeatureFlags.ENABLE_RATINGS {
                return false
            }
            return true
        }
    }

    private func clearAllFilters() {
        selectedTags.removeAll()
        selectedCOEs.removeAll()
        selectedManufacturers.removeAll()
        selectedProductTypes.removeAll()
    }
}

// MARK: - COE Chip

private struct COEChip: View {
    let coe: Int32
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void

    private var isDisabled: Bool {
        count == 0 && !isSelected
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text("\(coe)")
                    .lineLimit(1)
                    .fixedSize()
                Text("(\(count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .fixedSize()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.accentPrimary)
                }
            }
            .font(.subheadline)
            .foregroundColor(isDisabled ? .secondary : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? DesignSystem.Colors.accentPrimary.opacity(0.15) : Color(.systemGray6))
            )
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

// MARK: - Tag Filter Sub-Sheet

struct TagFilterSubSheet: View {
    @Binding var selectedTags: Set<String>
    let allAvailableTags: [String]
    let tagCounts: [String: Int]

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredTags: [String] {
        if searchText.isEmpty {
            return allAvailableTags
        }
        return allAvailableTags.filter { tag in
            tag.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredTags, id: \.self) { tag in
                    let count = tagCounts[tag] ?? 0
                    let isSelected = selectedTags.contains(tag)
                    let isDisabled = count == 0 && !isSelected

                    Button {
                        if isSelected {
                            selectedTags.remove(tag)
                        } else {
                            selectedTags.insert(tag)
                        }
                    } label: {
                        HStack {
                            Text(tag)
                                .foregroundColor(isDisabled ? .secondary : .primary)
                            Spacer()
                            Text("\(count)")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .foregroundColor(DesignSystem.Colors.accentPrimary)
                            }
                        }
                        .opacity(isDisabled ? 0.5 : 1.0)
                    }
                    .disabled(isDisabled)
                    .listRowBackground(isSelected ? DesignSystem.Colors.accentPrimary.opacity(0.15) : nil)
                }
            }
            .searchable(text: $searchText, prompt: "Search tags")
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    if !selectedTags.isEmpty {
                        Button("Clear") {
                            selectedTags.removeAll()
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Product Type Chip

private struct ProductTypeChip: View {
    let type: String
    let displayName: String
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void

    private var isDisabled: Bool {
        count == 0 && !isSelected
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text(displayName)
                    .lineLimit(1)
                    .fixedSize()
                Text("(\(count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .fixedSize()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.accentPrimary)
                }
            }
            .font(.subheadline)
            .foregroundColor(isDisabled ? .secondary : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? DesignSystem.Colors.accentPrimary.opacity(0.15) : Color(.systemGray6))
            )
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

//
//  ShoppingFilterSheet.swift
//  Molten
//
//  Filter sheet for Shopping List view, accessible from the floating filter button
//

import SwiftUI

struct ShoppingFilterSheet: View {
    @Binding var isPresented: Bool

    // Sort
    @Binding var sortOption: ShoppingListSortOption

    // Filters
    @Binding var selectedTags: Set<String>
    @Binding var selectedCOEs: Set<Int32>
    @Binding var selectedManufacturers: Set<String>
    @Binding var selectedStore: String?
    @Binding var selectedProductTypes: Set<String>
    @Binding var selectedInventoryType: String?

    // Available options
    let allAvailableTags: [String]
    let allAvailableCOEs: [Int32]
    let availableManufacturers: [String]
    let availableStores: [String]
    let availableProductTypes: [String]
    let availableInventoryTypes: [String]

    // Counts
    let tagCounts: [String: Int]
    let coeCounts: [Int32: Int]
    let manufacturerCounts: [String: Int]
    let storeCounts: [String: Int]
    let productTypeCounts: [String: Int]
    let inventoryTypeCounts: [String: Int]

    // Display helpers
    let manufacturerDisplayName: (String) -> String
    let productTypeDisplayName: (String) -> String
    let inventoryTypeDisplayName: (String) -> String

    // State for tags sub-sheet
    @State private var showingTagsSheet = false

    var body: some View {
        NavigationStack {
            List {
                // Sort section
                Section("Sort") {
                    ForEach(ShoppingListSortOption.allCases, id: \.self) { option in
                        Button {
                            sortOption = option
                        } label: {
                            HStack {
                                Label(option.rawValue, systemImage: option.icon)
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

                // Store filter
                if !availableStores.isEmpty {
                    Section("Store") {
                        ForEach(availableStores, id: \.self) { store in
                            let count = storeCounts[store] ?? 0
                            let isSelected = selectedStore == store
                            let isDisabled = count == 0 && !isSelected
                            Button {
                                if selectedStore == store {
                                    selectedStore = nil
                                } else {
                                    selectedStore = store
                                }
                            } label: {
                                HStack {
                                    Text(store)
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
                }

                // Inventory Type (Kind) filter
                if !availableInventoryTypes.isEmpty {
                    Section("Kind") {
                        ForEach(availableInventoryTypes, id: \.self) { type in
                            let count = inventoryTypeCounts[type] ?? 0
                            let isSelected = selectedInventoryType == type
                            let isDisabled = count == 0 && !isSelected
                            Button {
                                if selectedInventoryType == type {
                                    selectedInventoryType = nil
                                } else {
                                    selectedInventoryType = type
                                }
                            } label: {
                                HStack {
                                    Text(inventoryTypeDisplayName(type))
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
                }

                // COE filter
                if !allAvailableCOEs.isEmpty {
                    Section("COE") {
                        ForEach(allAvailableCOEs, id: \.self) { coe in
                            let count = coeCounts[coe] ?? 0
                            let isSelected = selectedCOEs.contains(coe)
                            let isDisabled = count == 0 && !isSelected
                            Button {
                                if selectedCOEs.contains(coe) {
                                    selectedCOEs.remove(coe)
                                } else {
                                    selectedCOEs.insert(coe)
                                }
                            } label: {
                                HStack {
                                    Text("\(coe)")
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
                    Section("Manufacturer") {
                        ForEach(availableManufacturers, id: \.self) { manufacturer in
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
        !selectedManufacturers.isEmpty || selectedStore != nil ||
        !selectedProductTypes.isEmpty || selectedInventoryType != nil
    }

    private func clearAllFilters() {
        selectedTags.removeAll()
        selectedCOEs.removeAll()
        selectedManufacturers.removeAll()
        selectedStore = nil
        selectedProductTypes.removeAll()
        selectedInventoryType = nil
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
                Text("(\(count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
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

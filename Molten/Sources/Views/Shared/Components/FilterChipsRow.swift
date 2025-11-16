//
//  FilterChipsRow.swift
//  Molten
//
//  Reusable filter row component for use with native .searchable()
//  Based on CatalogView implementation
//
//  TODO: Migrate remaining views to use this component with native .searchable():
//  - InventoryView (currently uses StandardSearchAndFilterHeader)
//  - ShoppingListView (currently uses StandardSearchAndFilterHeader)
//  - ProjectsView (currently uses StandardSearchAndFilterHeader)
//  - LogbookView (currently uses StandardSearchAndFilterHeader)
//  Once migrated, deprecate/remove StandardSearchAndFilterHeader and SearchAndFilterHeader
//

import SwiftUI

/// Filter row component designed to work with native `.searchable()` modifier
///
/// Usage:
/// ```swift
/// NavigationStack {
///     VStack {
///         FilterChipsRow(
///             searchTitlesOnly: $searchTitlesOnly,
///             selectedManufacturers: $selectedManufacturers,
///             selectedCOEs: $selectedCOEs,
///             selectedTags: $selectedTags,
///             selectedProductTypes: $selectedProductTypes,
///             // ... other parameters
///         )
///         // Your content
///     }
///     .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
/// }
/// ```
struct FilterChipsRow: View {

    // MARK: - Filter State

    @Binding var searchTitlesOnly: Bool
    @Binding var selectedManufacturers: Set<String>
    @Binding var selectedCOEs: Set<Int32>
    @Binding var selectedTags: Set<String>
    @Binding var selectedProductTypes: Set<String>

    // MARK: - Sheet Presentation State

    @Binding var showingManufacturerFilterSelection: Bool
    @Binding var showingCOESelection: Bool
    @Binding var showingAllTags: Bool

    // MARK: - Available Options

    let availableManufacturers: [String]
    let allAvailableCOEs: [Int32]
    let allAvailableTags: [String]

    // MARK: - Display Functions

    let manufacturerDisplayName: (String) -> String

    // MARK: - Optional Counts

    let manufacturerCounts: [String: Int]?
    let coeCounts: [Int32: Int]?
    let tagCounts: [String: Int]?

    // MARK: - Configuration

    let showProductTypeFilter: Bool

    init(
        searchTitlesOnly: Binding<Bool>,
        selectedManufacturers: Binding<Set<String>>,
        selectedCOEs: Binding<Set<Int32>>,
        selectedTags: Binding<Set<String>>,
        selectedProductTypes: Binding<Set<String>> = .constant([]),
        showingManufacturerFilterSelection: Binding<Bool>,
        showingCOESelection: Binding<Bool>,
        showingAllTags: Binding<Bool>,
        availableManufacturers: [String],
        allAvailableCOEs: [Int32],
        allAvailableTags: [String],
        manufacturerDisplayName: @escaping (String) -> String = { code in
            GlassManufacturers.fullName(for: code) ?? code
        },
        manufacturerCounts: [String: Int]? = nil,
        coeCounts: [Int32: Int]? = nil,
        tagCounts: [String: Int]? = nil,
        showProductTypeFilter: Bool = true
    ) {
        self._searchTitlesOnly = searchTitlesOnly
        self._selectedManufacturers = selectedManufacturers
        self._selectedCOEs = selectedCOEs
        self._selectedTags = selectedTags
        self._selectedProductTypes = selectedProductTypes
        self._showingManufacturerFilterSelection = showingManufacturerFilterSelection
        self._showingCOESelection = showingCOESelection
        self._showingAllTags = showingAllTags
        self.availableManufacturers = availableManufacturers
        self.allAvailableCOEs = allAvailableCOEs
        self.allAvailableTags = allAvailableTags
        self.manufacturerDisplayName = manufacturerDisplayName
        self.manufacturerCounts = manufacturerCounts
        self.coeCounts = coeCounts
        self.tagCounts = tagCounts
        self.showProductTypeFilter = showProductTypeFilter
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.none) {
            // Top row: Search titles only toggle
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
            }
            .padding(.horizontal, DesignSystem.Padding.standard)
            .padding(.top, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.xs)

            // Bottom row: Product type (left) and filter chips (right)
            HStack(spacing: DesignSystem.Spacing.md) {
                // Left: Product type filter (if enabled)
                if showProductTypeFilter {
                    compactProductTypeFilterButton
                }

                Spacer()

                // Right: Filter chips (COE, Tags, Mfr from left to right)
                HStack(spacing: DesignSystem.Spacing.sm) {
                    // COE filter chip
                    compactCOEFilterButton

                    // Tag filter chip
                    compactTagFilterButton

                    // Manufacturer filter chip (far right)
                    compactManufacturerFilterButton
                }
            }
            .padding(.horizontal, DesignSystem.Padding.standard)
            .padding(.bottom, DesignSystem.Spacing.md)
        }
        .background(DesignSystem.Colors.background)
    }

    // MARK: - Compact Filter Buttons

    private var compactManufacturerFilterButton: some View {
        Button {
            showingManufacturerFilterSelection = true
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if selectedManufacturers.isEmpty {
                    Image(systemName: "building.2")
                        .font(DesignSystem.Typography.captionSmall)
                    Text("Mfr")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.medium)
                } else {
                    // Show first 2 manufacturers inline (abbreviated)
                    let sortedMfrs = selectedManufacturers.sorted()
                    ForEach(Array(sortedMfrs.prefix(2)), id: \.self) { mfr in
                        Text(mfr.uppercased())
                            .font(DesignSystem.Typography.captionSmall)
                            .fontWeight(DesignSystem.FontWeight.bold)
                    }
                    if selectedManufacturers.count > 2 {
                        Text("+\(selectedManufacturers.count - 2)")
                            .font(DesignSystem.Typography.captionSmall)
                            .fontWeight(DesignSystem.FontWeight.medium)
                    }
                    // X button to clear
                    Image(systemName: "xmark.circle.fill")
                        .font(DesignSystem.Typography.captionSmall)
                        .onTapGesture {
                            selectedManufacturers.removeAll()
                        }
                }
                if selectedManufacturers.isEmpty {
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
            }
            .foregroundColor(selectedManufacturers.isEmpty ? .secondary : .white)
            .padding(.horizontal, DesignSystem.Padding.chip)
            .padding(.vertical, DesignSystem.Padding.chipVertical)
            .background(selectedManufacturers.isEmpty ? Color(.systemGray6) : Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
    }

    private var compactCOEFilterButton: some View {
        Button {
            showingCOESelection = true
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if selectedCOEs.isEmpty {
                    Text("COE")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.medium)
                } else {
                    // Show selected COEs inline
                    let sortedCOEs = selectedCOEs.sorted()
                    ForEach(Array(sortedCOEs.prefix(2)), id: \.self) { coe in
                        Text(String(coe))
                            .font(DesignSystem.Typography.captionSmall)
                            .fontWeight(DesignSystem.FontWeight.bold)
                    }
                    if selectedCOEs.count > 2 {
                        Text("+\(selectedCOEs.count - 2)")
                            .font(DesignSystem.Typography.captionSmall)
                            .fontWeight(DesignSystem.FontWeight.medium)
                    }
                    // X button to clear
                    Image(systemName: "xmark.circle.fill")
                        .font(DesignSystem.Typography.captionSmall)
                        .onTapGesture {
                            selectedCOEs.removeAll()
                        }
                }
                if selectedCOEs.isEmpty {
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
            }
            .foregroundColor(selectedCOEs.isEmpty ? .secondary : .white)
            .padding(.horizontal, DesignSystem.Padding.chip)
            .padding(.vertical, DesignSystem.Padding.chipVertical)
            .background(selectedCOEs.isEmpty ? Color(.systemGray6) : Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
    }

    private var compactTagFilterButton: some View {
        Button {
            showingAllTags = true
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if selectedTags.isEmpty {
                    Image(systemName: "tag")
                        .font(DesignSystem.Typography.captionSmall)
                    Text("Tags")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.medium)
                } else {
                    // Show first 2 tags inline
                    let sortedTags = selectedTags.sorted()
                    ForEach(Array(sortedTags.prefix(2)), id: \.self) { tag in
                        Text(tag)
                            .font(DesignSystem.Typography.captionSmall)
                            .fontWeight(DesignSystem.FontWeight.bold)
                            .lineLimit(1)
                    }
                    if selectedTags.count > 2 {
                        Text("+\(selectedTags.count - 2)")
                            .font(DesignSystem.Typography.captionSmall)
                            .fontWeight(DesignSystem.FontWeight.medium)
                    }
                    // X button to clear
                    Image(systemName: "xmark.circle.fill")
                        .font(DesignSystem.Typography.captionSmall)
                        .onTapGesture {
                            selectedTags.removeAll()
                        }
                }
                if selectedTags.isEmpty {
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
            }
            .foregroundColor(selectedTags.isEmpty ? .secondary : .white)
            .padding(.horizontal, DesignSystem.Padding.chip)
            .padding(.vertical, DesignSystem.Padding.chipVertical)
            .background(selectedTags.isEmpty ? Color(.systemGray6) : Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
    }

    private var compactProductTypeFilterButton: some View {
        Menu {
            // Single-select product type options
            ForEach(["glass", "coating", "tool"], id: \.self) { type in
                Button {
                    withAnimation {
                        // Single-select: replace all selections with this one type
                        selectedProductTypes.removeAll()
                        selectedProductTypes.insert(type)
                    }
                } label: {
                    HStack {
                        Text(displayNameForProductType(type))
                        Spacer()
                        if selectedProductTypes.contains(type) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Show selected type (always has a selection)
                if let selectedType = selectedProductTypes.first {
                    Text(displayNameForProductType(selectedType))
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
        .accessibilityIdentifier("productTypeFilterButton")
    }

    private func displayNameForProductType(_ type: String) -> String {
        switch type.lowercased() {
        case "glass": return "Glass"
        case "coating": return "Coatings"
        case "tool": return "Tools"
        default: return type.capitalized
        }
    }
}

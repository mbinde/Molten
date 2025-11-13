//
//  SearchAndFilterHeader.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//

import SwiftUI

/// Reusable search and filter header component used across Catalog and Inventory views
/// Provides consistent search, tag filtering, and sorting UI with collapsible tray
struct SearchAndFilterHeader: View {
    // Search state
    @Binding var searchText: String
    @State private var localSearchText: String = ""  // Local copy for immediate UI updates
    @Binding var searchTitlesOnly: Bool

    // Filter state
    @Binding var selectedTags: Set<String>
    @Binding var showingAllTags: Bool
    let allAvailableTags: [String]

    // COE filter state
    @Binding var selectedCOEs: Set<Int32>
    @Binding var showingCOESelection: Bool
    let allAvailableCOEs: [Int32]

    // Product type filter state
    @Binding var selectedProductTypes: Set<String>  // Set of "glass", "coating", "tool"
    @Binding var showingProductTypeSelection: Bool
    let allAvailableProductTypes: [String]  // Usually ["glass", "coating", "tool"]

    // Manufacturer filter state
    @Binding var selectedManufacturers: Set<String>
    @Binding var showingManufacturerSelection: Bool
    let allAvailableManufacturers: [String]
    let manufacturerDisplayName: (String) -> String

    // Optional filter counts
    var manufacturerCounts: [String: Int]?
    var coeCounts: [Int32: Int]?
    var tagCounts: [String: Int]?
    var productTypeCounts: [String: Int]?

    // Sort menu content
    let sortMenuContent: () -> AnyView

    // Optional feedback state
    @Binding var searchClearedFeedback: Bool

    // Configuration
    let searchPlaceholder: String

    // User defaults for persistence
    let userDefaults: UserDefaults
    let searchTitlesOnlyKey: String

    init(
        searchText: Binding<String>,
        searchTitlesOnly: Binding<Bool>,
        selectedTags: Binding<Set<String>>,
        showingAllTags: Binding<Bool>,
        allAvailableTags: [String],
        selectedCOEs: Binding<Set<Int32>>,
        showingCOESelection: Binding<Bool>,
        allAvailableCOEs: [Int32],
        selectedProductTypes: Binding<Set<String>>,
        showingProductTypeSelection: Binding<Bool>,
        allAvailableProductTypes: [String] = ["glass", "coating", "tool"],
        selectedManufacturers: Binding<Set<String>>,
        showingManufacturerSelection: Binding<Bool>,
        allAvailableManufacturers: [String],
        manufacturerDisplayName: @escaping (String) -> String = { $0 },
        manufacturerCounts: [String: Int]? = nil,
        coeCounts: [Int32: Int]? = nil,
        tagCounts: [String: Int]? = nil,
        productTypeCounts: [String: Int]? = nil,
        sortMenuContent: @escaping () -> AnyView,
        searchClearedFeedback: Binding<Bool> = .constant(false),
        searchPlaceholder: String = "Search...",
        userDefaults: UserDefaults = .standard,
        searchTitlesOnlyKey: String = "searchTitlesOnly"
    ) {
        self._searchText = searchText
        self._searchTitlesOnly = searchTitlesOnly
        self._selectedTags = selectedTags
        self._showingAllTags = showingAllTags
        self.allAvailableTags = allAvailableTags
        self._selectedCOEs = selectedCOEs
        self._showingCOESelection = showingCOESelection
        self.allAvailableCOEs = allAvailableCOEs
        self._selectedProductTypes = selectedProductTypes
        self._showingProductTypeSelection = showingProductTypeSelection
        self.allAvailableProductTypes = allAvailableProductTypes
        self._selectedManufacturers = selectedManufacturers
        self._showingManufacturerSelection = showingManufacturerSelection
        self.allAvailableManufacturers = allAvailableManufacturers
        self.manufacturerDisplayName = manufacturerDisplayName
        self.manufacturerCounts = manufacturerCounts
        self.coeCounts = coeCounts
        self.tagCounts = tagCounts
        self.productTypeCounts = productTypeCounts
        self.sortMenuContent = sortMenuContent
        self._searchClearedFeedback = searchClearedFeedback
        self.searchPlaceholder = searchPlaceholder
        self.userDefaults = userDefaults
        self.searchTitlesOnlyKey = searchTitlesOnlyKey
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.none) {
            // Search box (always visible)
            persistentSearchBox
                .padding(.horizontal, DesignSystem.Padding.standard)
                .padding(.top, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.xs)
                .background(DesignSystem.Colors.background)

            // Filter controls (always visible)
            VStack(spacing: DesignSystem.Spacing.md) {
                // Top row: Search titles only toggle + Sort button
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
                    .onChange(of: searchTitlesOnly) { _, newValue in
                        // Save toggle state to UserDefaults
                        userDefaults.set(newValue, forKey: searchTitlesOnlyKey)
                    }

                    Spacer()

                    // Sort button
                    Menu {
                        sortMenuContent()
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(DesignSystem.Typography.caption)
                            Text("Sort")
                                .font(DesignSystem.Typography.caption)
                                .fontWeight(DesignSystem.FontWeight.medium)
                        }
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .padding(.horizontal, DesignSystem.Padding.standard)
                        .padding(.vertical, DesignSystem.Padding.compact)
                        .background(DesignSystem.Colors.backgroundInput)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                    }
                }

                // Filter buttons row: Type (left), then COE/Mfr/Tags (right-aligned)
                HStack(spacing: DesignSystem.Spacing.md) {
                    // Product type selector (left-anchored)
                    compactProductTypePicker

                    Spacer()

                    // Right-aligned filters: COE, Mfr, Tags (from left to right)
                    // COE filter button (only for glass)
                    if !allAvailableCOEs.isEmpty {
                        compactCOEFilterButton
                    }

                    // Manufacturer filter button
                    if !allAvailableManufacturers.isEmpty {
                        compactManufacturerFilterButton
                    }

                    // Tag filter button (always shown if tags are available)
                    if !allAvailableTags.isEmpty {
                        compactTagFilterButton
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Padding.standard)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.background)
        }
        .background(DesignSystem.Colors.background)
        .sheet(isPresented: $showingManufacturerSelection) {
            FilterSelectionSheet.manufacturers(
                availableManufacturers: allAvailableManufacturers,
                selectedManufacturers: $selectedManufacturers,
                manufacturerDisplayName: manufacturerDisplayName,
                itemCounts: manufacturerCounts
            )
        }
        .overlay(
            // Search cleared feedback
            Group {
                if searchClearedFeedback {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(DesignSystem.Colors.accentSuccess)
                        Text("Search cleared")
                            .font(DesignSystem.Typography.caption)
                            .fontWeight(DesignSystem.FontWeight.medium)
                    }
                    .padding(.horizontal, DesignSystem.Padding.standard)
                    .padding(.vertical, DesignSystem.Padding.buttonVertical)
                    .background(DesignSystem.Colors.tintGreen)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                    .transition(.opacity.combined(with: .scale))
                }
            }
            , alignment: .center
        )
    }

    // MARK: - Helper Views (removed collapsed summary - filters always visible)

    private var unused_collapsedSummaryView: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            if hasActiveFilters {
                // Show active filters summary
                HStack(spacing: DesignSystem.Spacing.sm) {
                    if !selectedManufacturers.isEmpty {
                        Text("\(selectedManufacturers.count) mfr\(selectedManufacturers.count == 1 ? "" : "s")")
                            .font(DesignSystem.Typography.label)
                            .fontWeight(DesignSystem.FontWeight.medium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }

                    if !selectedManufacturers.isEmpty && (!selectedTags.isEmpty || !selectedCOEs.isEmpty) {
                        Text("•")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    if !selectedTags.isEmpty {
                        Text("\(selectedTags.count) tag\(selectedTags.count == 1 ? "" : "s")")
                            .font(DesignSystem.Typography.label)
                            .fontWeight(DesignSystem.FontWeight.medium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }

                    if !selectedTags.isEmpty && !selectedCOEs.isEmpty {
                        Text("•")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    if !selectedCOEs.isEmpty {
                        Text("\(selectedCOEs.count) COE\(selectedCOEs.count == 1 ? "" : "s")")
                            .font(DesignSystem.Typography.label)
                            .fontWeight(DesignSystem.FontWeight.medium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                }
                .lineLimit(1)
            } else {
                // No filters active
                Text("Tap for filter options")
                    .font(DesignSystem.Typography.label)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }

    // MARK: - Helpers

    private var hasActiveFilters: Bool {
        !selectedTags.isEmpty || !selectedCOEs.isEmpty || !selectedManufacturers.isEmpty || !selectedProductTypes.isEmpty
    }

    private func clearAllFilters() {
        withAnimation {
            selectedTags.removeAll()
            selectedCOEs.removeAll()
            selectedManufacturers.removeAll()
            selectedProductTypes.removeAll()
        }
    }

    // Persistent search box (always visible)
    private var persistentSearchBox: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                TextField(searchPlaceholder, text: $localSearchText)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .accessibilityIdentifier("searchField")
                    .onChange(of: localSearchText) { oldValue, newValue in
                        // Debounce search text updates (300ms delay)
                        // This prevents expensive filtering on every keystroke
                        Task {
                            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                            if localSearchText == newValue {
                                // Only update if the value hasn't changed (user stopped typing)
                                searchText = newValue
                            }
                        }
                    }

                // Clear button (X)
                Button {
                    localSearchText = ""
                    searchText = ""
                    hideKeyboard()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(localSearchText.isEmpty ? DesignSystem.Colors.textSecondary.opacity(DesignSystem.Colors.opacityInteractive) : DesignSystem.Colors.textSecondary)
                        .font(DesignSystem.Typography.caption)
                }
                .buttonStyle(.plain)
                .disabled(localSearchText.isEmpty)
                .accessibilityIdentifier("clearSearchButton")
            }
            .padding(.horizontal, DesignSystem.Padding.standard)
            .padding(.vertical, DesignSystem.Padding.compact)
            .background(DesignSystem.Colors.backgroundInput)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))

            Menu {
                sortMenuContent()
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(DesignSystem.Typography.subSectionHeader)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            .accessibilityIdentifier("sortButton")
            .padding(.horizontal, DesignSystem.Spacing.xs)
        }
        .onAppear {
            // Sync local search text with binding on appear
            localSearchText = searchText
        }
        .onChange(of: searchText) { oldValue, newValue in
            // Sync local search text when external changes occur (e.g., clear all)
            if newValue != localSearchText {
                localSearchText = newValue
            }
        }
    }

    private var compactManufacturerFilterButton: some View {
        Button {
            showingManufacturerSelection = true
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
                            .fontWeight(DesignSystem.FontWeight.medium)
                            .lineLimit(1)
                    }

                    // Show "+X" if more than 2 manufacturers selected
                    if selectedManufacturers.count > 2 {
                        Text("+\(selectedManufacturers.count - 2)")
                            .font(DesignSystem.Typography.captionSmall)
                            .fontWeight(DesignSystem.FontWeight.semibold)
                    }

                    // X to clear
                    Image(systemName: "xmark.circle.fill")
                        .font(DesignSystem.Typography.caption)
                        .onTapGesture {
                            withAnimation {
                                selectedManufacturers.removeAll()
                            }
                        }
                }

                if selectedManufacturers.isEmpty {
                    Image(systemName: "chevron.down")
                        .font(Font.system(size: 10))
                }
            }
            .foregroundColor(selectedManufacturers.isEmpty ? DesignSystem.Colors.textSecondary : .white)
            .padding(.horizontal, DesignSystem.Padding.chip + DesignSystem.Spacing.xs)
            .padding(.vertical, DesignSystem.Padding.buttonVertical)
            .background(selectedManufacturers.isEmpty ? DesignSystem.Colors.backgroundInput : DesignSystem.Colors.accentPrimary)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
        .accessibilityIdentifier("manufacturerFilterButton")
    }

    private var compactCOEFilterButton: some View {
        Menu {
            // "Show All" option
            Button {
                withAnimation {
                    selectedCOEs.removeAll()
                }
            } label: {
                HStack {
                    Text("All COEs")
                    Spacer()
                    if selectedCOEs.isEmpty {
                        Image(systemName: "checkmark")
                    }
                }
            }

            Divider()

            // Individual COE options (filter out zero-count items)
            ForEach(allAvailableCOEs.sorted().filter { coe in
                // Show all items if no counts provided, otherwise only show items with count > 0
                coeCounts == nil || (coeCounts?[coe] ?? 0) > 0
            }, id: \.self) { coe in
                Button {
                    withAnimation {
                        toggleCOE(coe)
                    }
                } label: {
                    HStack {
                        Text("COE \(coe)")
                        Spacer()
                        if selectedCOEs.contains(coe) {
                            Image(systemName: "checkmark")
                        }
                        if let count = coeCounts?[coe] {
                            Text("(\(count))")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if selectedCOEs.isEmpty {
                    Image(systemName: "flame")
                        .font(DesignSystem.Typography.captionSmall)
                    Text("COE")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.medium)
                } else {
                    // Show first 2 COE values inline
                    let sortedCOEs = selectedCOEs.sorted()
                    ForEach(Array(sortedCOEs.prefix(2)), id: \.self) { coe in
                        Text("\(coe)")
                            .font(DesignSystem.Typography.captionSmall)
                            .fontWeight(DesignSystem.FontWeight.medium)
                            .lineLimit(1)
                    }

                    // Show "+X" if more than 2 COEs selected
                    if selectedCOEs.count > 2 {
                        Text("+\(selectedCOEs.count - 2)")
                            .font(DesignSystem.Typography.captionSmall)
                            .fontWeight(DesignSystem.FontWeight.semibold)
                    }

                    // X to clear
                    Image(systemName: "xmark.circle.fill")
                        .font(DesignSystem.Typography.caption)
                        .onTapGesture {
                            withAnimation {
                                selectedCOEs.removeAll()
                            }
                        }
                }

                if selectedCOEs.isEmpty {
                    Image(systemName: "chevron.down")
                        .font(Font.system(size: 10))
                }
            }
            .foregroundColor(selectedCOEs.isEmpty ? DesignSystem.Colors.textSecondary : .white)
            .padding(.horizontal, DesignSystem.Padding.chip + DesignSystem.Spacing.xs)
            .padding(.vertical, DesignSystem.Padding.buttonVertical)
            .background(selectedCOEs.isEmpty ? DesignSystem.Colors.backgroundInput : DesignSystem.Colors.accentPrimary)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
        .accessibilityIdentifier("coeFilterButton")
    }

    private func toggleCOE(_ coe: Int32) {
        if selectedCOEs.contains(coe) {
            selectedCOEs.remove(coe)
        } else {
            selectedCOEs.insert(coe)
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
                        HStack(spacing: 3) {
                            TagColorCircle(tag: tag, size: 6)

                            Text(tag)
                                .font(DesignSystem.Typography.captionSmall)
                                .fontWeight(DesignSystem.FontWeight.medium)
                                .lineLimit(1)
                        }
                    }

                    // Show "+X" if more than 2 tags selected
                    if selectedTags.count > 2 {
                        Text("+\(selectedTags.count - 2)")
                            .font(DesignSystem.Typography.captionSmall)
                            .fontWeight(DesignSystem.FontWeight.semibold)
                    }

                    // X to clear
                    Image(systemName: "xmark.circle.fill")
                        .font(DesignSystem.Typography.caption)
                        .onTapGesture {
                            withAnimation {
                                selectedTags.removeAll()
                            }
                        }
                }

                if selectedTags.isEmpty {
                    Image(systemName: "chevron.down")
                        .font(Font.system(size: 10))
                }
            }
            .foregroundColor(selectedTags.isEmpty ? DesignSystem.Colors.textSecondary : .white)
            .padding(.horizontal, DesignSystem.Padding.chip + DesignSystem.Spacing.xs)
            .padding(.vertical, DesignSystem.Padding.buttonVertical)
            .background(selectedTags.isEmpty ? DesignSystem.Colors.backgroundInput : DesignSystem.Colors.accentPrimary)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
        .accessibilityIdentifier("tagFilterButton")
    }

    private var compactProductTypePicker: some View {
        Menu {
            // Individual product type options (single-select, filter out zero-count items and show counts)
            ForEach(allAvailableProductTypes.filter { type in
                // Show all items if no counts provided, otherwise only show items with count > 0
                productTypeCounts == nil || (productTypeCounts?[type] ?? 0) > 0
            }, id: \.self) { type in
                Button {
                    withAnimation {
                        selectProductType(type)
                    }
                } label: {
                    HStack {
                        Text(type.capitalized)
                        Spacer()
                        if selectedProductTypes.contains(type) {
                            Image(systemName: "checkmark")
                        }
                        if let count = productTypeCounts?[type] {
                            Text("(\(count))")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Show selected type (always has a selection now)
                if let selectedType = selectedProductTypes.first {
                    Text(selectedType.capitalized)
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.medium)
                        .lineLimit(1)
                } else {
                    // Fallback if somehow empty (shouldn't happen with default)
                    Image(systemName: "square.stack.3d.up")
                        .font(DesignSystem.Typography.captionSmall)
                    Text("Type")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.medium)
                }

                // Always show dropdown arrow
                Image(systemName: "chevron.down")
                    .font(Font.system(size: 10))
            }
            .foregroundColor(DesignSystem.Colors.textSecondary)
            .padding(.horizontal, DesignSystem.Padding.chip + DesignSystem.Spacing.xs)
            .padding(.vertical, DesignSystem.Padding.buttonVertical)
            .background(DesignSystem.Colors.backgroundInput)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
        .accessibilityIdentifier("productTypeFilterButton")
    }

    private func selectProductType(_ type: String) {
        // Single-select: replace all selections with this one type
        selectedProductTypes.removeAll()
        selectedProductTypes.insert(type)
    }

    private func toggleProductType(_ type: String) {
        if selectedProductTypes.contains(type) {
            selectedProductTypes.remove(type)
        } else {
            selectedProductTypes.insert(type)
        }
    }

    private func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

}

// MARK: - Product Type Selection Sheet

struct ProductTypeSelectionSheet: View {
    @Binding var selectedProductTypes: Set<String>
    let allAvailableProductTypes: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(allAvailableProductTypes, id: \.self) { type in
                    Button {
                        withAnimation {
                            toggleProductType(type)
                        }
                        // Don't dismiss - allow multiple selections
                    } label: {
                        HStack {
                            Text(type.capitalized)
                                .foregroundColor(DesignSystem.Colors.textPrimary)

                            Spacer()

                            if selectedProductTypes.contains(type) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(DesignSystem.Colors.accentPrimary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Product Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") {
                        selectedProductTypes.removeAll()
                    }
                    .disabled(selectedProductTypes.isEmpty)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func toggleProductType(_ type: String) {
        if selectedProductTypes.contains(type) {
            selectedProductTypes.remove(type)
        } else {
            selectedProductTypes.insert(type)
        }
    }
}

#Preview {
    @Previewable @State var searchText = ""
    @Previewable @State var searchTitlesOnly = true
    @Previewable @State var selectedTags: Set<String> = []
    @Previewable @State var showingAllTags = false
    @Previewable @State var selectedCOEs: Set<Int32> = []
    @Previewable @State var showingCOESelection = false
    @Previewable @State var selectedProductTypes: Set<String> = []
    @Previewable @State var showingProductTypeSelection = false
    @Previewable @State var selectedManufacturers: Set<String> = []
    @Previewable @State var showingManufacturerSelection = false
    @Previewable @State var searchClearedFeedback = false

    return VStack {
        SearchAndFilterHeader(
            searchText: $searchText,
            searchTitlesOnly: $searchTitlesOnly,
            selectedTags: $selectedTags,
            showingAllTags: $showingAllTags,
            allAvailableTags: ["clear", "opaque", "transparent", "rod", "frit"],
            selectedCOEs: $selectedCOEs,
            showingCOESelection: $showingCOESelection,
            allAvailableCOEs: [90, 96, 104],
            selectedProductTypes: $selectedProductTypes,
            showingProductTypeSelection: $showingProductTypeSelection,
            allAvailableProductTypes: ["glass", "coating", "tool"],
            selectedManufacturers: $selectedManufacturers,
            showingManufacturerSelection: $showingManufacturerSelection,
            allAvailableManufacturers: ["be", "cim", "ef", "ga", "tag"],
            manufacturerDisplayName: { code in
                switch code {
                case "be": return "Bullseye Glass Co"
                case "cim": return "Creation is Messy"
                case "ef": return "Effetre"
                case "ga": return "Glass Alchemy"
                case "tag": return "Trautman Art Glass"
                default: return code.uppercased()
                }
            },
            sortMenuContent: {
                AnyView(Group {
                    Button("Name") { }
                    Button("Date") { }
                    Button("Quantity") { }
                })
            },
            searchClearedFeedback: $searchClearedFeedback,
            searchPlaceholder: "Search colors, codes, manufacturers..."
        )

        Spacer()
    }
}

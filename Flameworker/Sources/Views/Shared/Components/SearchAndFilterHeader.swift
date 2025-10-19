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

    // Manufacturer filter state
    @Binding var selectedManufacturers: Set<String>
    @Binding var showingManufacturerSelection: Bool
    let allAvailableManufacturers: [String]
    let manufacturerDisplayName: (String) -> String

    // Optional filter counts
    var manufacturerCounts: [String: Int]?
    var coeCounts: [Int32: Int]?
    var tagCounts: [String: Int]?

    // Sort menu content
    let sortMenuContent: () -> AnyView

    // Optional feedback state
    @Binding var searchClearedFeedback: Bool

    // Configuration
    let searchPlaceholder: String

    // User defaults for persistence
    let userDefaults: UserDefaults
    let searchTitlesOnlyKey: String

    // Collapsible state
    @State private var isExpanded: Bool = true

    init(
        searchText: Binding<String>,
        searchTitlesOnly: Binding<Bool>,
        selectedTags: Binding<Set<String>>,
        showingAllTags: Binding<Bool>,
        allAvailableTags: [String],
        selectedCOEs: Binding<Set<Int32>>,
        showingCOESelection: Binding<Bool>,
        allAvailableCOEs: [Int32],
        selectedManufacturers: Binding<Set<String>>,
        showingManufacturerSelection: Binding<Bool>,
        allAvailableManufacturers: [String],
        manufacturerDisplayName: @escaping (String) -> String = { $0 },
        manufacturerCounts: [String: Int]? = nil,
        coeCounts: [Int32: Int]? = nil,
        tagCounts: [String: Int]? = nil,
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
        self._selectedManufacturers = selectedManufacturers
        self._showingManufacturerSelection = showingManufacturerSelection
        self.allAvailableManufacturers = allAvailableManufacturers
        self.manufacturerDisplayName = manufacturerDisplayName
        self.manufacturerCounts = manufacturerCounts
        self.coeCounts = coeCounts
        self.tagCounts = tagCounts
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

            // Header (always visible) - tap to expand/collapse
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                    userDefaults.set(isExpanded, forKey: "searchFilterHeaderExpanded")
                }
            } label: {
                HStack {
                    if isExpanded {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Text("Filters")
                                .font(DesignSystem.Typography.label)
                                .fontWeight(DesignSystem.FontWeight.semibold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)

                            // Clear All button (only when expanded with active filters)
                            if hasActiveFilters {
                                Button {
                                    clearAllFilters()
                                } label: {
                                    Text("Clear All")
                                        .font(DesignSystem.Typography.caption)
                                        .fontWeight(DesignSystem.FontWeight.medium)
                                        .foregroundColor(DesignSystem.Colors.accentPrimary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        // Collapsed summary
                        collapsedSummaryView
                    }

                    Spacer()

                    // Chevron
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(.horizontal, DesignSystem.Padding.standard)
                .padding(.vertical, DesignSystem.Spacing.lg)
                .background(DesignSystem.Colors.backgroundInputLight)
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
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

                    // Filter buttons row: Manufacturers, COE, Tags
                    HStack(spacing: DesignSystem.Spacing.md) {
                        // Manufacturer filter button
                        if !allAvailableManufacturers.isEmpty {
                            compactManufacturerFilterButton
                        }

                        // COE filter button
                        if !allAvailableCOEs.isEmpty {
                            compactCOEFilterButton
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
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(DesignSystem.Colors.background)
        .sheet(isPresented: $showingManufacturerSelection) {
            ManufacturerSelectionSheet(
                availableManufacturers: allAvailableManufacturers,
                manufacturerDisplayName: manufacturerDisplayName,
                selectedManufacturers: $selectedManufacturers,
                itemCounts: manufacturerCounts
            )
        }
        .sheet(isPresented: $showingCOESelection) {
            COESelectionSheet(
                availableCOEs: allAvailableCOEs,
                selectedCOEs: $selectedCOEs,
                itemCounts: coeCounts
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
        .onAppear {
            // Load saved expanded state (default to true)
            isExpanded = userDefaults.bool(forKey: "searchFilterHeaderExpanded") != false
        }
    }

    // MARK: - Collapsed Summary

    private var collapsedSummaryView: some View {
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
        !selectedTags.isEmpty || !selectedCOEs.isEmpty || !selectedManufacturers.isEmpty
    }

    private func clearAllFilters() {
        withAnimation {
            selectedTags.removeAll()
            selectedCOEs.removeAll()
            selectedManufacturers.removeAll()
        }
    }

    // Persistent search box (always visible)
    private var persistentSearchBox: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                TextField(searchPlaceholder, text: $localSearchText)
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
    }

    private var compactCOEFilterButton: some View {
        Button {
            showingCOESelection = true
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
    }

    private func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

}

// MARK: - COE Selection Sheet

struct COESelectionSheet: View {
    let availableCOEs: [Int32]
    @Binding var selectedCOEs: Set<Int32>
    var itemCounts: [Int32: Int]? = nil  // Optional: count of items for each COE
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                // Clear All button as first item
                if !selectedCOEs.isEmpty {
                    Button(action: {
                        selectedCOEs.removeAll()
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(DesignSystem.Colors.accentDanger)
                            Text("Clear All")
                                .foregroundColor(DesignSystem.Colors.accentDanger)
                            Spacer()
                        }
                    }
                }

                // COE list
                ForEach(availableCOEs.sorted(), id: \.self) { coe in
                    Button(action: {
                        if selectedCOEs.contains(coe) {
                            selectedCOEs.remove(coe)
                        } else {
                            selectedCOEs.insert(coe)
                        }
                    }) {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            if let count = itemCounts?[coe] {
                                Text("COE \(coe) (\(count))")
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                            } else {
                                Text("COE \(coe)")
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                            }

                            Spacer()

                            if selectedCOEs.contains(coe) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(DesignSystem.Colors.accentPrimary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select COE")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Manufacturer Selection Sheet

struct ManufacturerSelectionSheet: View {
    let availableManufacturers: [String]
    let manufacturerDisplayName: (String) -> String
    @Binding var selectedManufacturers: Set<String>
    var itemCounts: [String: Int]? = nil  // Optional: count of items for each manufacturer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                // Clear All button
                if !selectedManufacturers.isEmpty {
                    Button(action: {
                        selectedManufacturers.removeAll()
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(DesignSystem.Colors.accentDanger)
                            Text("Clear All")
                                .foregroundColor(DesignSystem.Colors.accentDanger)
                            Spacer()
                        }
                    }
                }

                // Manufacturer list (showing full names)
                ForEach(availableManufacturers.sorted(), id: \.self) { mfr in
                    Button(action: {
                        if selectedManufacturers.contains(mfr) {
                            selectedManufacturers.remove(mfr)
                        } else {
                            selectedManufacturers.insert(mfr)
                        }
                    }) {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            if let count = itemCounts?[mfr] {
                                Text("\(manufacturerDisplayName(mfr)) (\(count))")
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                            } else {
                                Text(manufacturerDisplayName(mfr))
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                            }

                            Spacer()

                            if selectedManufacturers.contains(mfr) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(DesignSystem.Colors.accentPrimary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Manufacturers")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
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

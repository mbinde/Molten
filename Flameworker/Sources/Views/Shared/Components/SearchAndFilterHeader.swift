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
    @Binding var searchTitlesOnly: Bool

    // Filter state
    @Binding var selectedTags: Set<String>
    @Binding var showingAllTags: Bool
    let allAvailableTags: [String]

    // COE filter state
    @Binding var selectedCOEs: Set<Int32>
    @Binding var showingCOESelection: Bool
    let allAvailableCOEs: [Int32]

    // Sort state
    @Binding var showingSortMenu: Bool

    // Optional feedback state
    @Binding var searchClearedFeedback: Bool

    // Configuration
    let searchPlaceholder: String
    let showSearchTitlesToggle: Bool

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
        showingSortMenu: Binding<Bool>,
        searchClearedFeedback: Binding<Bool> = .constant(false),
        searchPlaceholder: String = "Search...",
        showSearchTitlesToggle: Bool = true,
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
        self._showingSortMenu = showingSortMenu
        self._searchClearedFeedback = searchClearedFeedback
        self.searchPlaceholder = searchPlaceholder
        self.showSearchTitlesToggle = showSearchTitlesToggle
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
                        Text("Filters")
                            .font(DesignSystem.Typography.label)
                            .fontWeight(DesignSystem.FontWeight.semibold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    } else {
                        // Collapsed summary
                        collapsedSummaryView
                    }

                    Spacer()

                    // Clear All button (only when collapsed with active filters)
                    if !isExpanded && hasActiveFilters {
                        Button {
                            clearAllFilters()
                        } label: {
                            Text("Clear All")
                                .font(DesignSystem.Typography.caption)
                                .fontWeight(DesignSystem.FontWeight.medium)
                                .foregroundColor(DesignSystem.Colors.accentPrimary)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, DesignSystem.Spacing.md)
                    }

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
                    // Sort button (search is always visible above)
                    HStack {
                        Spacer()
                        Button {
                            showingSortMenu = true
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

                    // Filter dropdowns row
                    HStack(spacing: DesignSystem.Spacing.lg) {
                        // Compact search titles only toggle
                        if showSearchTitlesToggle {
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
                        }

                        Spacer()

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
        !selectedTags.isEmpty || !selectedCOEs.isEmpty
    }

    private func clearAllFilters() {
        withAnimation {
            selectedTags.removeAll()
            selectedCOEs.removeAll()
        }
    }

    // Persistent search box (always visible)
    private var persistentSearchBox: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                TextField(searchPlaceholder, text: $searchText)

                // Clear button (X)
                Button {
                    searchText = ""
                    hideKeyboard()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(searchText.isEmpty ? DesignSystem.Colors.textSecondary.opacity(DesignSystem.Colors.opacityInteractive) : DesignSystem.Colors.textSecondary)
                        .font(DesignSystem.Typography.caption)
                }
                .buttonStyle(.plain)
                .disabled(searchText.isEmpty)
            }
            .padding(.horizontal, DesignSystem.Padding.standard)
            .padding(.vertical, DesignSystem.Padding.compact)
            .background(DesignSystem.Colors.backgroundInput)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))

            Button {
                showingSortMenu = true
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(DesignSystem.Typography.subSectionHeader)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            .padding(.horizontal, DesignSystem.Spacing.xs)
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
                        Text(tag)
                            .font(DesignSystem.Typography.captionSmall)
                            .fontWeight(DesignSystem.FontWeight.medium)
                            .lineLimit(1)
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
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - COE Selection Sheet

struct COESelectionSheet: View {
    let availableCOEs: [Int32]
    @Binding var selectedCOEs: Set<Int32>
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
                            Text("COE \(coe)")
                                .foregroundColor(DesignSystem.Colors.textPrimary)

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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
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
    @Previewable @State var showingSortMenu = false
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
            showingSortMenu: $showingSortMenu,
            searchClearedFeedback: $searchClearedFeedback,
            searchPlaceholder: "Search colors, codes, manufacturers..."
        )

        Spacer()
    }
}

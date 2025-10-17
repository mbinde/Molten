//
//  SearchAndFilterHeader.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//

import SwiftUI

/// Reusable search and filter header component used across Catalog and Inventory views
/// Provides consistent search, tag filtering, and sorting UI
struct SearchAndFilterHeader: View {
    // Search state
    @Binding var searchText: String
    @Binding var searchTitlesOnly: Bool

    // Filter state
    @Binding var selectedTags: Set<String>
    @Binding var showingAllTags: Bool
    let allAvailableTags: [String]

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

    init(
        searchText: Binding<String>,
        searchTitlesOnly: Binding<Bool>,
        selectedTags: Binding<Set<String>>,
        showingAllTags: Binding<Bool>,
        allAvailableTags: [String],
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
        self._showingSortMenu = showingSortMenu
        self._searchClearedFeedback = searchClearedFeedback
        self.searchPlaceholder = searchPlaceholder
        self.showSearchTitlesToggle = showSearchTitlesToggle
        self.userDefaults = userDefaults
        self.searchTitlesOnlyKey = searchTitlesOnlyKey
    }

    var body: some View {
        VStack(spacing: 8) {
            // Custom search bar with inline sort button
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField(searchPlaceholder, text: $searchText)

                    // Clear button (X) - always visible
                    Button {
                        searchText = ""
                        hideKeyboard()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(searchText.isEmpty ? .secondary.opacity(0.3) : .secondary)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    .disabled(searchText.isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Button {
                    showingSortMenu = true
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 4)
            }

            // Filter dropdowns row
            HStack(spacing: 12) {
                // Compact search titles only toggle
                if showSearchTitlesToggle {
                    HStack(spacing: 6) {
                        Toggle("", isOn: $searchTitlesOnly)
                            .labelsHidden()
                        Text("Search titles only")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .onChange(of: searchTitlesOnly) { _, newValue in
                        // Save toggle state to UserDefaults
                        userDefaults.set(newValue, forKey: searchTitlesOnlyKey)
                    }
                }

                Spacer()

                // Tag filter button (always shown if tags are available)
                if !allAvailableTags.isEmpty {
                    compactTagFilterButton
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            // Search cleared feedback
            Group {
                if searchClearedFeedback {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Search cleared")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .transition(.opacity.combined(with: .scale))
                }
            }
            , alignment: .center
        )
    }

    private var compactTagFilterButton: some View {
        Button {
            showingAllTags = true
        } label: {
            HStack(spacing: 6) {
                if selectedTags.isEmpty {
                    Image(systemName: "tag")
                        .font(.system(size: 12))
                    Text("Tags")
                        .font(.system(size: 13, weight: .medium))
                } else {
                    // Show first 2 tags inline
                    let sortedTags = selectedTags.sorted()
                    ForEach(Array(sortedTags.prefix(2)), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                    }

                    // Show "+X" if more than 2 tags selected
                    if selectedTags.count > 2 {
                        Text("+\(selectedTags.count - 2)")
                            .font(.system(size: 12, weight: .semibold))
                    }

                    // X to clear
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .onTapGesture {
                            withAnimation {
                                selectedTags.removeAll()
                            }
                        }
                }

                if selectedTags.isEmpty {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                }
            }
            .foregroundColor(selectedTags.isEmpty ? .secondary : .white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(selectedTags.isEmpty ? Color(.systemGray5) : Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

#Preview {
    @Previewable @State var searchText = ""
    @Previewable @State var searchTitlesOnly = true
    @Previewable @State var selectedTags: Set<String> = []
    @Previewable @State var showingAllTags = false
    @Previewable @State var showingSortMenu = false
    @Previewable @State var searchClearedFeedback = false

    return VStack {
        SearchAndFilterHeader(
            searchText: $searchText,
            searchTitlesOnly: $searchTitlesOnly,
            selectedTags: $selectedTags,
            showingAllTags: $showingAllTags,
            allAvailableTags: ["clear", "opaque", "transparent", "rod", "frit"],
            showingSortMenu: $showingSortMenu,
            searchClearedFeedback: $searchClearedFeedback,
            searchPlaceholder: "Search colors, codes, manufacturers..."
        )

        Spacer()
    }
}

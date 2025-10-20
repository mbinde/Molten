//
//  GlassItemSearchSelector.swift
//  Flameworker
//
//  Created by Assistant on 10/18/25.
//  Shared component for searching and selecting glass items
//

import SwiftUI

/// Shared component for searching and selecting glass items
/// Used by AddInventoryItemView and AddShoppingListItemView
/// Uses lightweight GlassItemModel for optimal search performance
struct GlassItemSearchSelector: View {
    @Binding var selectedGlassItem: GlassItemModel?
    @Binding var searchText: String
    let prefilledNaturalKey: String?
    let glassItems: [GlassItemModel]
    let onSelect: (GlassItemModel) -> Void
    let onClear: () -> Void

    @State private var localSearchText: String = ""  // Local copy for immediate UI updates
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        print("⏱️ [SEARCH SELECTOR] body evaluation started at \(Date()), glassItems.count=\(glassItems.count)")
        let startTime = Date()

        defer {
            let elapsed = Date().timeIntervalSince(startTime)
            print("⏱️ [SEARCH SELECTOR] body evaluation completed in \(elapsed * 1000)ms")
        }

        return Section("Glass Item") {
            if prefilledNaturalKey == nil {
                searchField
            }

            if let glassItem = selectedGlassItem {
                selectedItemView(glassItem)
            } else if !searchText.isEmpty && prefilledNaturalKey == nil {
                // Only show results after debounce completes (searchText is updated)
                searchResultsView
            } else if prefilledNaturalKey != nil {
                notFoundView
            } else {
                instructionView
            }
        }
        .onAppear {
            print("⏱️ [SEARCH SELECTOR] onAppear called at \(Date())")
            // Sync local search text with binding on appear
            localSearchText = searchText
        }
        .onChange(of: searchText) { oldValue, newValue in
            // Sync local search text when external changes occur (e.g., clear selection)
            if newValue != localSearchText {
                localSearchText = newValue
            }
        }
    }

    // MARK: - Sub-Views

    private var searchField: some View {
        TextField("Search glass items...", text: $localSearchText)
            .textFieldStyle(.roundedBorder)
            .focused($isSearchFieldFocused)
            .disabled(selectedGlassItem != nil)
            .onChange(of: isSearchFieldFocused) { oldValue, newValue in
                print("⏱️ [SEARCH FIELD] Focus changed from \(oldValue) to \(newValue) at \(Date())")
            }
            .onChange(of: localSearchText) { oldValue, newValue in
                print("⏱️ [SEARCH FIELD] Text changed from '\(oldValue)' to '\(newValue)' at \(Date())")
                // Debounce search text updates (200ms delay)
                // This prevents expensive filtering on every keystroke
                Task {
                    try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
                    if localSearchText == newValue {
                        // Only update if the value hasn't changed (user stopped typing)
                        searchText = newValue
                        // Note: Auto-selection and filtering now happen in the view body
                        // after searchText is updated, preventing image loading during debounce
                    }
                }
            }
    }

    private func selectedItemView(_ glassItem: GlassItemModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            selectedItemHeader
            GlassItemCard(item: glassItem, variant: .compact)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(selectedItemBackgroundColor)
        .overlay(selectedItemBorder)
        .cornerRadius(8)
    }

    private var selectedItemHeader: some View {
        HStack {
            Text(prefilledNaturalKey != nil ? "Adding for:" : "Selected:")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            if prefilledNaturalKey == nil {
                clearButton
            }
        }
    }

    private var clearButton: some View {
        Button("Clear") {
            onClear()
        }
        .font(.caption)
        .foregroundColor(.blue)
    }

    private var selectedItemBackgroundColor: Color {
        let baseColor = prefilledNaturalKey != nil ? Color.blue : Color.green
        return baseColor.opacity(0.1)
    }

    private var selectedItemBorder: some View {
        let borderColor = prefilledNaturalKey != nil ? Color.blue : Color.green
        return RoundedRectangle(cornerRadius: 8)
            .stroke(borderColor, lineWidth: 1)
    }

    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(filteredGlassItems.prefix(10), id: \.natural_key) { item in
                    Button(action: {
                        // Prevent deselection when there's only one result
                        // (it's auto-selected, so clicking shouldn't toggle it off)
                        if filteredGlassItems.count > 1 || selectedGlassItem == nil {
                            onSelect(item)
                        }
                    }) {
                        GlassItemCard(item: item, variant: .compact)
                    }
                    .buttonStyle(.plain)
                    .disabled(filteredGlassItems.count == 1 && selectedGlassItem != nil)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(maxHeight: 300)
    }

    private var notFoundView: some View {
        Group {
            if selectedGlassItem == nil && prefilledNaturalKey != nil {
                NotFoundCard(naturalKey: prefilledNaturalKey!)
            } else {
                EmptyView()
            }
        }
    }

    private var instructionView: some View {
        Group {
            if selectedGlassItem == nil && prefilledNaturalKey == nil {
                Text("Search above to find a glass item")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                EmptyView()
            }
        }
    }

    // MARK: - Computed Properties

    private var filteredGlassItems: [GlassItemModel] {
        // Use searchText (not localSearchText) so filtering only happens AFTER debounce
        // This prevents expensive image loading during the debounce period
        if searchText.isEmpty {
            return []
        } else {
            return glassItems.filter { item in
                let searchLower = searchText.lowercased()
                return item.name.lowercased().contains(searchLower) ||
                       item.natural_key.lowercased().contains(searchLower) ||
                       item.manufacturer.lowercased().contains(searchLower)
            }
        }
    }
}

// MARK: - Helper Views

struct NotFoundCard: View {
    let naturalKey: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Glass item not found")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Natural Key: \(naturalKey)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange, lineWidth: 1)
        )
        .cornerRadius(8)
    }
}

#Preview {
    let _ = RepositoryFactory.configureForTesting()

    struct PreviewWrapper: View {
        @State private var selectedItem: GlassItemModel? = nil
        @State private var searchText: String = ""
        @State private var glassItems: [GlassItemModel] = []
        private let catalogService = RepositoryFactory.createCatalogService()

        var body: some View {
            Form {
                GlassItemSearchSelector(
                    selectedGlassItem: $selectedItem,
                    searchText: $searchText,
                    prefilledNaturalKey: nil,
                    glassItems: glassItems,
                    onSelect: { item in
                        selectedItem = item
                        searchText = ""
                    },
                    onClear: {
                        selectedItem = nil
                        searchText = ""
                    }
                )
            }
            .task {
                do {
                    glassItems = try await catalogService.getGlassItemsLightweight()
                } catch {
                    print("Error loading items: \(error)")
                }
            }
        }
    }

    return PreviewWrapper()
}

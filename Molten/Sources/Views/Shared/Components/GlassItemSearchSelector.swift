//
//  GlassItemSearchSelector.swift
//  Flameworker
//
//  Created by Assistant on 10/18/25.
//  Shared component for searching and selecting catalog items (glass, coatings, tools)
//

import SwiftUI

/// Shared component for searching and selecting catalog items
/// Used by AddInventoryItemView and AddShoppingListItemView
/// Uses lightweight UnifiedCatalogItem for optimal search performance
struct GlassItemSearchSelector: View {
    @Binding var selectedGlassItem: UnifiedCatalogItem?
    @Binding var searchText: String
    let prefilledNaturalKey: String?
    let glassItems: [UnifiedCatalogItem]
    let onSelect: (UnifiedCatalogItem) -> Void
    let onClear: () -> Void

    @State private var localSearchText: String = ""  // Local copy for immediate UI updates
    @State private var wasManuallySelected: Bool = false  // Track if selection was manual vs auto
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        Section("Catalog Item") {
            // Always show search field (even when item is selected)
            if prefilledNaturalKey == nil {
                searchField
            }

            if let catalogItem = selectedGlassItem {
                selectedItemView(catalogItem)
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
            // Sync local search text with binding on appear
            localSearchText = searchText
        }
        .onChange(of: searchText) { oldValue, newValue in
            // Sync local search text when external changes occur (e.g., clear selection)
            if newValue != localSearchText {
                localSearchText = newValue
            }

            // If user edits search text while an item is selected, deselect it immediately
            if selectedGlassItem != nil && !newValue.isEmpty && newValue != oldValue {
                selectedGlassItem = nil
            }

            // Auto-select when there's exactly one result
            if filteredGlassItems.count == 1, selectedGlassItem == nil {
                onSelect(filteredGlassItems[0])
                wasManuallySelected = false  // Mark as auto-selected
            }
        }
        .onChange(of: selectedGlassItem) { oldValue, newValue in
            // Reset manual selection flag when item is cleared
            if newValue == nil {
                wasManuallySelected = false
            }
        }
    }

    // MARK: - Sub-Views

    private var searchField: some View {
        HStack(spacing: 8) {
            TextField("Search glass items...", text: $localSearchText)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .focused($isSearchFieldFocused)
                .onChange(of: localSearchText) { oldValue, newValue in
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

            // Clear button (X) appears when there's text
            if !localSearchText.isEmpty {
                Button(action: {
                    localSearchText = ""
                    searchText = ""
                    onClear()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("glass_item_search_clear")
            }
        }
    }

    private func selectedItemView(_ catalogItem: UnifiedCatalogItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            selectedItemHeader
            GlassItemCard(catalogItem: catalogItem, variant: .compact)
                .allowsHitTesting(false) // Prevent card clicks from deselecting
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
        }
    }

    private var selectedItemBackgroundColor: Color {
        let baseColor = prefilledNaturalKey != nil ? Color.accentColor : DesignSystem.Colors.accentSuccess
        return baseColor.opacity(0.1)
    }

    private var selectedItemBorder: some View {
        let borderColor = prefilledNaturalKey != nil ? Color.accentColor : DesignSystem.Colors.accentSuccess
        return RoundedRectangle(cornerRadius: 8)
            .stroke(borderColor, lineWidth: 1)
    }

    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(filteredGlassItems, id: \.stable_id) { item in
                    Button(action: {
                        wasManuallySelected = true
                        onSelect(item)
                        // Don't clear search text - keep it for refinement
                    }) {
                        GlassItemCard(catalogItem: item, variant: .compact)
                    }
                    .buttonStyle(.plain)
                }

                // Show message if results are very large
                if filteredGlassItems.count > 50 {
                    Text("Showing \(filteredGlassItems.count) results. Refine search for better results.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(maxHeight: 300)
    }

    private var notFoundView: some View {
        Group {
            if selectedGlassItem == nil && prefilledNaturalKey != nil {
                NotFoundCard(stableId: prefilledNaturalKey!)
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

    private var filteredGlassItems: [UnifiedCatalogItem] {
        // Use searchText (not localSearchText) so filtering only happens AFTER debounce
        // This prevents expensive image loading during the debounce period
        if searchText.isEmpty {
            return []
        } else {
            return glassItems.filter { item in
                let searchLower = searchText.lowercased()
                return item.name.lowercased().contains(searchLower) ||
                       item.stable_id.contains(searchText) ||
                       item.manufacturer.lowercased().contains(searchLower)
            }
        }
    }
}

// MARK: - Helper Views

struct NotFoundCard: View {
    let stableId: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Glass item not found")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Stable ID: \(stableId)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(DesignSystem.Colors.accentWarning.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(DesignSystem.Colors.accentWarning, lineWidth: 1)
        )
        .cornerRadius(8)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedItem: UnifiedCatalogItem? = nil
        @State private var searchText: String = ""
        @State private var catalogItems: [UnifiedCatalogItem] = []
        private let catalogService: CatalogService

        init() {
            let deps = AppDependencies(persistenceController: .createTestController())
            self.catalogService = deps.catalogService
        }

        var body: some View {
            Form {
                GlassItemSearchSelector(
                    selectedGlassItem: $selectedItem,
                    searchText: $searchText,
                    prefilledNaturalKey: nil,
                    glassItems: catalogItems,
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
                    catalogItems = try await catalogService.getAllCatalogItemsLightweight()
                } catch {
                    print("Error loading items: \(error)")
                }
            }
        }
    }

    return PreviewWrapper()
}

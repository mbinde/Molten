//
//  GlobalSearchOverlay.swift
//  Molten
//
//  Full-screen search overlay triggered by the floating search button
//

import SwiftUI

/// Scope for global search - determines which items to search
enum GlobalSearchScope {
    case catalog
    case inventory
    case shopping
}

struct GlobalSearchOverlay: View {
    @Binding var isPresented: Bool
    let deps: AppDependencies
    var initialSearchText: String = ""
    var searchScope: GlobalSearchScope = .catalog
    var onSearchSubmit: ((String) -> Void)?
    var onItemSelected: ((CompleteInventoryItemModel) -> Void)?

    @State private var searchText: String
    @FocusState private var isSearchFieldFocused: Bool

    init(isPresented: Binding<Bool>, deps: AppDependencies, initialSearchText: String = "", searchScope: GlobalSearchScope = .catalog, onSearchSubmit: ((String) -> Void)? = nil, onItemSelected: ((CompleteInventoryItemModel) -> Void)? = nil) {
        self._isPresented = isPresented
        self.deps = deps
        self.initialSearchText = initialSearchText
        self.searchScope = searchScope
        self.onSearchSubmit = onSearchSubmit
        self.onItemSelected = onItemSelected
        self._searchText = State(initialValue: initialSearchText)
    }

    private var searchPlaceholder: String {
        switch searchScope {
        case .catalog:
            return "Search catalog..."
        case .inventory:
            return "Search inventory..."
        case .shopping:
            return "Search shopping list..."
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Results area (above search bar) - always show, filter as you type
            SearchResultsView(searchText: searchText, deps: deps, searchScope: searchScope) { item in
                // Save search text before dismissing, then navigate to detail
                onSearchSubmit?(searchText)  // Save current search text
                isPresented = false
                onItemSelected?(item)
            }

            Divider()

            // Search bar at bottom
            HStack(spacing: 12) {
                // Search field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField(searchPlaceholder, text: $searchText)
                        .textFieldStyle(.plain)
                        .focused($isSearchFieldFocused)
                        .submitLabel(.search)
                        .onSubmit {
                            // When user taps search button on keyboard, apply filter to catalog
                            if !searchText.isEmpty {
                                onSearchSubmit?(searchText)
                                isPresented = false
                            }
                        }

                    Button {
                        // Close search overlay
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )

                // X button to dismiss
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color(.systemGray5)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(DesignSystem.Colors.background)
        .presentationDragIndicator(.visible)
        .onAppear {
            // Focus the search field when overlay appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isSearchFieldFocused = true
            }
        }
    }
}

// MARK: - Search Results View

private struct SearchResultsView: View {
    let searchText: String
    let deps: AppDependencies
    let searchScope: GlobalSearchScope
    let onItemTap: (CompleteInventoryItemModel) -> Void

    @State private var results: [CompleteInventoryItemModel] = []
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if results.isEmpty && !searchText.isEmpty {
                // Only show "no results" if user actually searched for something
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No results for \"\(searchText)\"")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(results, id: \.id) { item in
                    SearchResultRow(item: item, searchScope: searchScope)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onItemTap(item)
                        }
                }
                .listStyle(.plain)
            }
        }
        .onChange(of: searchText) { _, newValue in
            performSearch(query: newValue)
        }
        .onAppear {
            performSearch(query: searchText)
        }
    }

    private func performSearch(query: String) {
        // Treat non-meaningful search text (empty, only quotes) as empty
        let effectiveQuery = SearchTextParser.isSearchTextMeaningful(query) ? query : ""

        isLoading = true

        Task {
            // Get items based on search scope
            // For catalog scope, use filteredItemsWithoutSearch from cache if available
            // This ensures search respects active filters (manufacturer, COE, tags, product type)
            let allItems: [CompleteInventoryItemModel]
            switch searchScope {
            case .catalog:
                // Use filtered items if available, otherwise fall back to all items
                allItems = await MainActor.run {
                    CatalogDataCache.shared.filteredItemsWithoutSearch ?? CatalogDataCache.shared.items
                }
            case .inventory:
                // Only search items that are in inventory (have inventory records)
                allItems = await MainActor.run {
                    CatalogDataCache.shared.items.filter { item in
                        item.hasInventory
                    }
                }
            case .shopping:
                // Only search items that are on the shopping list
                let shoppingStableIds: Set<String>
                do {
                    let shoppingItems = try await deps.shoppingListRepository.fetchAllItems()
                    shoppingStableIds = Set(shoppingItems.map { $0.item_stable_id })
                } catch {
                    shoppingStableIds = []
                }
                allItems = await MainActor.run {
                    CatalogDataCache.shared.items.filter { item in
                        shoppingStableIds.contains(item.catalogItem.stable_id)
                    }
                }
            }

            let filtered: [CompleteInventoryItemModel]
            if effectiveQuery.isEmpty {
                // Show all items when no search query
                filtered = allItems
            } else {
                // Use SearchTextParser for consistent search behavior with main catalog
                let searchMode = SearchTextParser.parseSearchText(effectiveQuery)
                // Always search all fields in global search (not just titles)
                filtered = allItems.filter { item in
                    let allFields = [
                        item.catalogItem.name,
                        item.catalogItem.stable_id,
                        item.catalogItem.manufacturer,
                        item.catalogItem.sku,
                        item.catalogItem.mfr_notes
                    ].compactMap { $0 }
                    return SearchTextParser.matchesAnyField(fields: allFields, mode: searchMode)
                }
            }

            await MainActor.run {
                results = filtered
                isLoading = false
            }
        }
    }
}

// MARK: - Search Result Row

private struct SearchResultRow: View {
    let item: CompleteInventoryItemModel
    let searchScope: GlobalSearchScope

    var body: some View {
        HStack(spacing: 12) {
            // Product thumbnail using standard image loading
            ProductImageThumbnail(
                itemCode: item.catalogItem.stable_id,
                manufacturer: item.catalogItem.manufacturer,
                stableId: item.catalogItem.stable_id,
                imagePath: item.catalogItem.image_path,
                imageThumbPath: item.catalogItem.image_thumb_path,
                dominantColors: item.catalogItem.dominant_colors,
                size: 44
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(item.catalogItem.name)
                    .font(.body)
                    .lineLimit(1)

                Text("\(item.catalogItem.sku ?? "") • \(item.catalogItem.manufacturer)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Show quantity based on search scope
            switch searchScope {
            case .inventory:
                if item.hasInventory {
                    // Format quantity - strip .0 for whole numbers
                    let qty = item.totalQuantity
                    let formatted = qty.truncatingRemainder(dividingBy: 1) == 0
                        ? String(format: "%.0f", qty)
                        : String(format: "%.1f", qty)
                    Text(formatted)
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.accentSecondary)
                }
            case .shopping:
                // Shopping list status is not stored in CompleteInventoryItemModel
                // The search just filters items that could be on the list
                EmptyView()
            case .catalog:
                EmptyView()
            }
        }
        .padding(.vertical, 4)
    }
}

//
//  ShoppingListView.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//

import SwiftUI

struct ShoppingListView: View {
    private let shoppingListService: ShoppingListService

    @State private var shoppingLists: [String: DetailedShoppingListModel] = [:]
    @State private var isLoading = false

    // Search and filter state
    @State private var searchText = ""
    @State private var searchTitlesOnly = false
    @State private var selectedTags: Set<String> = []
    @State private var showingAllTags = false
    @State private var selectedCOEs: Set<Int32> = []
    @State private var showingCOESelection = false
    @State private var showingSortMenu = false
    @State private var searchClearedFeedback = false
    @State private var sortOption: SortOption = .neededQuantity

    enum SortOption: String, CaseIterable {
        case neededQuantity = "Needed Quantity"
        case itemName = "Item Name"
        case store = "Store"

        var icon: String {
            switch self {
            case .neededQuantity: return "exclamationmark.triangle.fill"
            case .itemName: return "textformat.abc"
            case .store: return "building.2"
            }
        }
    }

    init(shoppingListService: ShoppingListService) {
        self.shoppingListService = shoppingListService
    }

    // Computed properties for filtering
    private var allAvailableTags: [String] {
        let allItems = shoppingLists.values.flatMap { $0.items }
        let allTags = allItems.flatMap { $0.tags }
        return Array(Set(allTags)).sorted()
    }

    private var allAvailableCOEs: [Int32] {
        let allItems = shoppingLists.values.flatMap { $0.items }
        let allCOEs = allItems.map { $0.glassItem.coe }
        return Array(Set(allCOEs)).sorted()
    }

    private var filteredShoppingLists: [String: DetailedShoppingListModel] {
        var filtered = shoppingLists

        // Apply search filter
        if !searchText.isEmpty && SearchTextParser.isSearchTextMeaningful(searchText) {
            let searchMode = SearchTextParser.parseSearchText(searchText)
            filtered = filtered.mapValues { list in
                let filteredItems = list.items.filter { item in
                    let allFields = [
                        item.glassItem.name,
                        item.glassItem.natural_key,
                        item.glassItem.manufacturer,
                        item.glassItem.sku
                    ]
                    return SearchTextParser.matchesAnyField(fields: allFields, mode: searchMode)
                }
                return DetailedShoppingListModel(
                    store: list.store,
                    items: filteredItems,
                    totalItems: filteredItems.count,
                    totalValue: list.totalValue
                )
            }.filter { !$0.value.items.isEmpty }
        }

        // Apply tag filter
        if !selectedTags.isEmpty {
            filtered = filtered.mapValues { list in
                let filteredItems = list.items.filter { item in
                    !selectedTags.isDisjoint(with: Set(item.tags))
                }
                return DetailedShoppingListModel(
                    store: list.store,
                    items: filteredItems,
                    totalItems: filteredItems.count,
                    totalValue: list.totalValue
                )
            }.filter { !$0.value.items.isEmpty }
        }

        // Apply COE filter
        if !selectedCOEs.isEmpty {
            filtered = filtered.mapValues { list in
                let filteredItems = list.items.filter { item in
                    selectedCOEs.contains(item.glassItem.coe)
                }
                return DetailedShoppingListModel(
                    store: list.store,
                    items: filteredItems,
                    totalItems: filteredItems.count,
                    totalValue: list.totalValue
                )
            }.filter { !$0.value.items.isEmpty }
        }

        return filtered
    }

    private var sortedStores: [String] {
        switch sortOption {
        case .neededQuantity:
            // Sort stores by total needed quantity (descending)
            return filteredShoppingLists.keys.sorted { store1, store2 in
                let qty1 = filteredShoppingLists[store1]?.items.reduce(0.0) { $0 + $1.shoppingListItem.neededQuantity } ?? 0
                let qty2 = filteredShoppingLists[store2]?.items.reduce(0.0) { $0 + $1.shoppingListItem.neededQuantity } ?? 0
                return qty1 > qty2
            }
        case .itemName:
            // Sort stores alphabetically
            return filteredShoppingLists.keys.sorted()
        case .store:
            // Sort stores alphabetically (same as itemName for stores)
            return filteredShoppingLists.keys.sorted()
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search and filter controls
                SearchAndFilterHeader(
                    searchText: $searchText,
                    searchTitlesOnly: $searchTitlesOnly,
                    selectedTags: $selectedTags,
                    showingAllTags: $showingAllTags,
                    allAvailableTags: allAvailableTags,
                    selectedCOEs: $selectedCOEs,
                    showingCOESelection: $showingCOESelection,
                    allAvailableCOEs: allAvailableCOEs,
                    showingSortMenu: $showingSortMenu,
                    searchClearedFeedback: $searchClearedFeedback,
                    searchPlaceholder: "Search shopping list...",
                    showSearchTitlesToggle: false
                )

                // Main content
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredShoppingLists.isEmpty {
                    if !shoppingLists.isEmpty && (!searchText.isEmpty || !selectedTags.isEmpty || !selectedCOEs.isEmpty) {
                        searchEmptyStateView
                    } else {
                        emptyStateView
                    }
                } else {
                    shoppingListContent
                }
            }
            .navigationTitle("Shopping List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await loadShoppingList()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showingAllTags) {
                TagSelectionSheet(
                    availableTags: allAvailableTags,
                    selectedTags: $selectedTags
                )
            }
            .sheet(isPresented: $showingCOESelection) {
                COESelectionSheet(
                    availableCOEs: allAvailableCOEs,
                    selectedCOEs: $selectedCOEs
                )
            }
            .confirmationDialog("Sort Options", isPresented: $showingSortMenu) {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        sortOption = option
                    } label: {
                        Label(option.rawValue, systemImage: option.icon)
                    }
                }
            }
            .task {
                await loadShoppingList()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "cart")
                .font(.system(size: 80))
                .foregroundColor(.secondary)

            Text("No Items Below Minimum")
                .font(.title2)
                .fontWeight(.bold)

            Text("Set minimum quantities in the catalog to generate shopping lists")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }

    private var searchEmptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No Results")
                .font(.title2)
                .fontWeight(.bold)

            Text("No items match your search or filter criteria")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var shoppingListContent: some View {
        List {
            ForEach(sortedStores, id: \.self) { store in
                if let list = filteredShoppingLists[store] {
                    Section(header: storeHeader(store: store, itemCount: list.totalItems)) {
                        ForEach(sortedItems(for: list), id: \.shoppingListItem.itemNaturalKey) { item in
                            ShoppingListRowView(item: item)
                        }
                    }
                }
            }
        }
    }

    private func sortedItems(for list: DetailedShoppingListModel) -> [DetailedShoppingListItemModel] {
        switch sortOption {
        case .neededQuantity:
            return list.items.sorted { $0.shoppingListItem.neededQuantity > $1.shoppingListItem.neededQuantity }
        case .itemName:
            return list.items.sorted { $0.glassItem.name.localizedCaseInsensitiveCompare($1.glassItem.name) == .orderedAscending }
        case .store:
            // Already sorted by store at the section level
            return list.items.sorted { $0.shoppingListItem.neededQuantity > $1.shoppingListItem.neededQuantity }
        }
    }

    private func storeHeader(store: String, itemCount: Int) -> some View {
        HStack {
            Text(store)
                .font(.headline)
            Spacer()
            Text("\(itemCount) item\(itemCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func loadShoppingList() async {
        isLoading = true
        defer { isLoading = false }

        do {
            shoppingLists = try await shoppingListService.generateAllShoppingLists()
        } catch {
            print("Error loading shopping list: \(error)")
        }
    }
}

struct ShoppingListRowView: View {
    let item: DetailedShoppingListItemModel

    var body: some View {
        HStack(spacing: 12) {
            // Product image thumbnail using SKU
            ProductImageThumbnail(
                itemCode: item.glassItem.sku,
                manufacturer: item.glassItem.manufacturer,
                size: 60
            )

            // Item details
            VStack(alignment: .leading, spacing: 4) {
                // Item name
                Text(item.glassItem.name)
                    .font(.headline)
                    .lineLimit(1)

                // Item code and manufacturer
                HStack {
                    Text(item.glassItem.natural_key)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(item.glassItem.manufacturer)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .lineLimit(1)

                // Shopping quantity badge
                HStack(spacing: 6) {
                    Text("Need: \(item.shoppingListItem.neededQuantity, specifier: "%.1f")")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)

                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("Current: \(item.shoppingListItem.currentQuantity, specifier: "%.1f")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Tags if available (includes both manufacturer and user tags)
                if !item.allTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(item.allTags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.gray.opacity(0.15))
                                    .foregroundColor(.secondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let _ = RepositoryFactory.configureForTesting()
    let shoppingListService = RepositoryFactory.createShoppingListService()
    return ShoppingListView(shoppingListService: shoppingListService)
}

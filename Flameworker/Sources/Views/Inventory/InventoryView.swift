//
//
//  InventoryView.swift
//  Flameworker
//
//  Migrated to Repository Pattern on 10/12/25 by Assistant
//  Updated for GlassItem architecture on 10/14/25
//

import SwiftUI
import Foundation
import OSLog

/// Repository-based InventoryView that uses the new GlassItem architecture
struct InventoryView: View {
    @State private var searchText = ""
    @State private var searchTitlesOnly = false  // Inventory doesn't need title-only search
    @State private var showingAddItem = false
    @State private var selectedGlassItem: CompleteInventoryItemModel?
    @State private var prefilledNaturalKey: String = ""
    @State private var showingAddFromCatalog = false
    @State private var selectedTags: Set<String> = []
    @State private var showingAllTags = false
    @State private var selectedCOEs: Set<Int32> = []
    @State private var showingCOESelection = false
    @State private var sortOption: InventorySortOption = .name
    @State private var showingSuccessToast = false
    @State private var successMessage = ""
    @State private var searchClearedFeedback = false
    @State private var glassItems: [CompleteInventoryItemModel] = []
    @State private var isLoading = false

    private let catalogService: CatalogService
    private let inventoryTrackingService: InventoryTrackingService
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Flameworker", category: "InventoryView")
    
    enum InventorySortOption: String, CaseIterable {
        case name = "Name"
        case totalQuantity = "Total Quantity"
        case manufacturer = "Manufacturer"
        case dateAdded = "Date Added"

        var title: String { rawValue }

        var icon: String {
            switch self {
            case .name: return "textformat.abc"
            case .totalQuantity: return "archivebox.fill"
            case .manufacturer: return "building.2"
            case .dateAdded: return "calendar"
            }
        }
    }

    // Initialize with repository-based services
    init(catalogService: CatalogService? = nil, inventoryTrackingService: InventoryTrackingService? = nil) {
        self.catalogService = catalogService ?? RepositoryFactory.createCatalogService()
        self.inventoryTrackingService = inventoryTrackingService ?? RepositoryFactory.createInventoryTrackingService()
    }
    
    // Computed properties
    private var filteredItems: [CompleteInventoryItemModel] {
        var items = glassItems

        // Only show items with inventory (totalQuantity > 0)
        items = items.filter { $0.totalQuantity > 0 }

        // Apply tag filter
        if !selectedTags.isEmpty {
            items = items.filter { item in
                !selectedTags.isDisjoint(with: Set(item.tags))
            }
        }

        // Apply COE filter
        if !selectedCOEs.isEmpty {
            items = items.filter { item in
                selectedCOEs.contains(item.glassItem.coe)
            }
        }

        // Apply search filter using SearchTextParser for advanced search (including grey/gray synonyms)
        if !searchText.isEmpty && SearchTextParser.isSearchTextMeaningful(searchText) {
            let searchMode = SearchTextParser.parseSearchText(searchText)
            items = items.filter { item in
                let allFields = [
                    item.glassItem.name,
                    item.glassItem.natural_key,
                    item.glassItem.manufacturer
                ]
                return SearchTextParser.matchesAnyField(fields: allFields, mode: searchMode)
            }
        }

        return items
    }
    
    private var sortedFilteredItems: [CompleteInventoryItemModel] {
        return filteredItems.sorted { (item1: CompleteInventoryItemModel, item2: CompleteInventoryItemModel) -> Bool in
            switch sortOption {
            case .name:
                return item1.glassItem.name.localizedCaseInsensitiveCompare(item2.glassItem.name) == .orderedAscending
            case .totalQuantity:
                return item1.totalQuantity != item2.totalQuantity ?
                    item1.totalQuantity > item2.totalQuantity :
                    item1.glassItem.name.localizedCaseInsensitiveCompare(item2.glassItem.name) == .orderedAscending
            case .manufacturer:
                return item1.glassItem.manufacturer.localizedCaseInsensitiveCompare(item2.glassItem.manufacturer) == .orderedAscending
            case .dateAdded:
                // Sort by most recent first (descending order) - get the newest date_added from inventory
                let item1Date = item1.inventory.map { $0.date_added }.max() ?? Date.distantPast
                let item2Date = item2.inventory.map { $0.date_added }.max() ?? Date.distantPast
                return item1Date > item2Date
            }
        }
    }
    
    private var isEmpty: Bool {
        filteredItems.isEmpty
    }

    private var allAvailableTags: [String] {
        // Get all tags from items with inventory
        let itemsWithInventory = glassItems.filter { $0.totalQuantity > 0 }
        let allTags = itemsWithInventory.flatMap { $0.tags }
        return Array(Set(allTags)).sorted()
    }

    private var allAvailableCOEs: [Int32] {
        // Get all COE values from items with inventory
        let itemsWithInventory = glassItems.filter { $0.totalQuantity > 0 }
        let allCOEs = itemsWithInventory.map { $0.glassItem.coe }
        return Array(Set(allCOEs)).sorted()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search and filter controls using shared component
                SearchAndFilterHeader(
                    searchText: $searchText,
                    searchTitlesOnly: $searchTitlesOnly,
                    selectedTags: $selectedTags,
                    showingAllTags: $showingAllTags,
                    allAvailableTags: allAvailableTags,
                    selectedCOEs: $selectedCOEs,
                    showingCOESelection: $showingCOESelection,
                    allAvailableCOEs: allAvailableCOEs,
                    sortMenuContent: {
                        AnyView(
                            Group {
                                ForEach(InventorySortOption.allCases, id: \.self) { option in
                                    Button {
                                        sortOption = option
                                    } label: {
                                        Label(option.title, systemImage: option.icon)
                                    }
                                }
                            }
                        )
                    },
                    searchClearedFeedback: $searchClearedFeedback,
                    searchPlaceholder: "Search inventory by name, code, manufacturer..."
                )

                // Main content
                Group {
                    if isEmpty {
                        inventoryEmptyState
                    } else {
                        inventoryListView
                    }
                }
            }
            .navigationTitle("Inventory")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                toolbarContent
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
            .sheet(isPresented: $showingAddItem, onDismiss: {
                Task {
                    await loadData()
                }
            }) {
                NavigationStack {
                    AddInventoryItemView(
                        prefilledNaturalKey: prefilledNaturalKey.isEmpty ? nil : prefilledNaturalKey,
                        inventoryTrackingService: inventoryTrackingService,
                        catalogService: catalogService
                    )
                }
            }
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
            }
            .onReceive(NotificationCenter.default.publisher(for: .inventoryItemAdded)) { _ in
                Task {
                    await loadData()
                }
            }
        }
    }
    
    // MARK: - Views
    
    private var inventoryEmptyState: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "archivebox")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)

                Text("No Inventory Yet")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Start tracking your glass inventory by adding your first item")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button("Add Item") {
                    showingAddItem = true
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var inventoryListView: some View {
        List {
            ForEach(sortedFilteredItems, id: \.id) { item in
                Button(action: {
                    selectedGlassItem = item
                }) {
                    InventoryItemRow(item: item)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(item: $selectedGlassItem) { item in
            // Shared detail view (same as catalog)
            InventoryDetailView(
                item: item,
                inventoryTrackingService: inventoryTrackingService
            )
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showingAddItem = true
            } label: {
                Label("Add Item", systemImage: "plus")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadData() async {
        isLoading = true
        do {
            let items = try await catalogService.getAllGlassItems()
            await MainActor.run {
                glassItems = items
                isLoading = false
            }
        } catch {
            await MainActor.run {
                glassItems = []
                isLoading = false
            }
            print("Error loading inventory items: \(error)")
        }
    }
}

// MARK: - Supporting Views

struct InventoryItemRow: View {
    let item: CompleteInventoryItemModel

    var body: some View {
        HStack(spacing: 12) {
            // Product image thumbnail using SKU
            #if canImport(UIKit)
            ProductImageThumbnail(
                itemCode: item.glassItem.sku,
                manufacturer: item.glassItem.manufacturer,
                naturalKey: item.glassItem.natural_key,
                size: 60
            )
            #else
            // Placeholder for macOS
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundColor(.secondary)
                        .font(.system(size: 24))
                }
            #endif

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

                // Inventory quantity badge
                HStack(spacing: 6) {
                    Text("\(item.totalQuantity, specifier: "%.1f")")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)

                    if !item.inventoryByType.isEmpty {
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text("\(item.inventoryByType.count) type\(item.inventoryByType.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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

// Tag selection sheet
struct TagSelectionSheet: View {
    let availableTags: [String]
    @Binding var selectedTags: Set<String>
    var userTags: Set<String> = []  // Optional: set of user-created tags for visual distinction
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                // Clear All button as first item
                if !selectedTags.isEmpty {
                    Button(action: {
                        selectedTags.removeAll()
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(.red)
                            Text("Clear All")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }

                // Tag list
                ForEach(availableTags, id: \.self) { tag in
                    Button(action: {
                        if selectedTags.contains(tag) {
                            selectedTags.remove(tag)
                        } else {
                            selectedTags.insert(tag)
                        }
                    }) {
                        HStack(spacing: 8) {
                            TagColorCircle(tag: tag, size: 12)

                            // User tag indicator (person icon)
                            if userTags.contains(tag) {
                                Image(systemName: "person.fill")
                                    .font(.caption)
                                    .foregroundColor(.purple)
                            }

                            Text(tag)
                                .foregroundColor(userTags.contains(tag) ? .purple : .primary)

                            Spacer()

                            if selectedTags.contains(tag) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Tags")
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
    InventoryView()
}

//
//  FriendInventoryView.swift
//  Molten
//
//  View for displaying a friend's shared inventory
//

import SwiftUI

struct FriendInventoryView: View {

    @State private var viewModel: FriendInventoryViewModel
    @Environment(\.dismiss) private var dismiss

    // UI state
    @State private var showingAllTags = false
    @State private var showingCOESelection = false
    @State private var showingManufacturerSelection = false
    @State private var showingProductTypeSelection = false

    init(friend: FriendShare) {
        self._viewModel = State(initialValue: FriendInventoryViewModel(friend: friend))
    }

    var body: some View {
        mainContent
            .navigationTitle("\(viewModel.friend.friendName)'s Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // Auto-load inventory when view appears
                // Will show cached data instantly, then refresh from server
                await viewModel.loadInventory()
            }
            .alert("Share No Longer Available", isPresented: .constant(viewModel.errorMessage?.contains("no longer available") == true)) {
                Button("OK") {
                    viewModel.clearError()
                    dismiss() // Navigate back to friend list
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil && viewModel.errorMessage?.contains("no longer available") == false)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .sheet(isPresented: $showingAllTags) {
                FilterSelectionSheet.tags(
                    availableTags: viewModel.availableTags,
                    selectedTags: $viewModel.selectedTags,
                    itemCounts: tagCounts
                )
            }
            .sheet(isPresented: $showingCOESelection) {
                FilterSelectionSheet.coes(
                    availableCOEs: viewModel.availableCOEs,
                    selectedCOEs: $viewModel.selectedCOEs,
                    itemCounts: coeCounts
                )
            }
            .sheet(isPresented: $showingManufacturerSelection) {
                FilterSelectionSheet.manufacturers(
                    availableManufacturers: viewModel.availableManufacturers,
                    selectedManufacturers: $viewModel.selectedManufacturers,
                    manufacturerDisplayName: { $0 },  // Just use manufacturer code as-is
                    itemCounts: manufacturerCounts
                )
            }
    }

    private var mainContent: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.enrichedInventory.isEmpty && !viewModel.rawInventory.isEmpty {
                // Data loaded but couldn't enrich (catalog not available)
                emptyState
            } else if viewModel.enrichedInventory.isEmpty {
                loadButton
            } else {
                inventoryListWithFilters
            }
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ProgressView()
            Text("Loading inventory...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadButton: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Load \(viewModel.friend.friendName)'s Inventory")
                .font(.headline)

            Button {
                Task {
                    await viewModel.loadInventory()
                }
            } label: {
                Text("Load Inventory")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("friend_inventory_load")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("\(viewModel.friend.friendName) has no inventory")
                .font(.headline)

            Text("They haven't added any glass to their inventory yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var inventoryListWithFilters: some View {
        VStack(spacing: 0) {
            // Search and filter controls - OUTSIDE the List for full width
            searchAndFilterHeader

            // Comparison filter buttons
            comparisonButtons

            // Inventory list
            if viewModel.filteredInventory.isEmpty {
                searchEmptyState
            } else {
                inventoryList
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        await viewModel.loadInventory(forceRefresh: true)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
                .accessibilityIdentifier("friend_inventory_refresh")
            }
        }
    }

    private var comparisonButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.md) {
                ComparisonButton(
                    title: "Everything",
                    isSelected: viewModel.comparisonMode == .all
                ) {
                    viewModel.comparisonMode = .all
                }

                ComparisonButton(
                    title: "I Need",
                    isSelected: viewModel.comparisonMode == .theyHaveIDoNot
                ) {
                    viewModel.comparisonMode = .theyHaveIDoNot
                }

                ComparisonButton(
                    title: "They Need",
                    isSelected: viewModel.comparisonMode == .iHaveTheyDoNot
                ) {
                    viewModel.comparisonMode = .iHaveTheyDoNot
                }

                ComparisonButton(
                    title: "In Common",
                    isSelected: viewModel.comparisonMode == .weBothHave
                ) {
                    viewModel.comparisonMode = .weBothHave
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(Color(.systemBackground))
    }

    private var searchAndFilterHeader: some View {
        StandardSearchAndFilterHeader(
            searchText: $viewModel.searchText,
            searchTitlesOnly: $viewModel.searchTitlesOnly,
            selectedTags: $viewModel.selectedTags,
            selectedCOEs: $viewModel.selectedCOEs,
            selectedManufacturers: $viewModel.selectedManufacturers,
            selectedProductTypes: $viewModel.selectedProductTypes,
            showingAllTags: $showingAllTags,
            showingCOESelection: $showingCOESelection,
            showingManufacturerSelection: $showingManufacturerSelection,
            showingProductTypeSelection: $showingProductTypeSelection,
            allAvailableTags: viewModel.availableTags,
            allAvailableCOEs: viewModel.availableCOEs,
            allAvailableManufacturers: viewModel.availableManufacturers,
            allAvailableProductTypes: viewModel.availableProductTypes,
            manufacturerCounts: manufacturerCounts,
            coeCounts: coeCounts,
            tagCounts: tagCounts,
            sortMenuContent: {
                AnyView(
                    Group {
                        ForEach(FriendInventorySortOption.allCases, id: \.self) { option in
                            Button {
                                viewModel.sortOption = option
                            } label: {
                                Label(option.title, systemImage: option.icon)
                            }
                        }
                    }
                )
            },
            searchPlaceholder: "Search \(viewModel.friend.friendName)'s inventory..."
        )
    }

    // MARK: - Filter Counts

    // Delegate filter counts to ViewModel for DRY approach
    private var manufacturerCounts: [String: Int] {
        viewModel.manufacturerCounts
    }

    private var coeCounts: [Int32: Int] {
        viewModel.coeCounts
    }

    private var tagCounts: [String: Int] {
        viewModel.tagCounts
    }

    private var productTypeCounts: [String: Int] {
        viewModel.productTypeCounts
    }

    private var searchEmptyState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No items match your search")
                .font(.headline)

            Button("Clear Filters") {
                viewModel.clearAllFilters()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, DesignSystem.Spacing.xl)
    }

    private var inventoryList: some View {
        List {
            Section {
                ForEach(viewModel.filteredInventory) { item in
                    GlassItemRowView.friendInventory(item: item)
                }
            } header: {
                Text("\(viewModel.filteredInventory.count) item\(viewModel.filteredInventory.count == 1 ? "" : "s")")
            }
        }
    }
}

// MARK: - Comparison Button Component

private struct ComparisonButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview("Loading") {
    NavigationStack {
        FriendInventoryView(
            friend: FriendShare(
                shareCode: "ABC123",
                friendName: "Alice",
                dateAdded: Date(),
                lastRefreshed: Date()
            )
        )
    }
}

#Preview("With Inventory") {
    NavigationStack {
        FriendInventoryView(
            friend: FriendShare(
                shareCode: "ABC123",
                friendName: "Alice",
                dateAdded: Date(),
                lastRefreshed: Date()
            )
        )
    }
}

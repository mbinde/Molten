//
//  StoreListView.swift
//  Molten
//
//  Created for Store Feature on 10/26/25.
//  Updated for Maps Feature on 10/27/25.
//

import SwiftUI
import Combine
import CoreLocation

enum StoreNavigationDestination: Hashable {
    case storeDetail(store: UnifiedLocationModel)
}

struct StoreListView: View {
    @State private var navigationPath = NavigationPath()
    @State private var showZipCodeEntry = false
    @State private var showSearchEntry = false

    // ViewModel manages all state
    @State private var viewModel: StoreListViewModel

    init(viewModel: StoreListViewModel = StoreListViewModel()) {
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Action buttons
                actionButtons

                // Technique filter chips
                techniqueFilterChips

                // Active filter indicator
                if !viewModel.searchText.isEmpty || !viewModel.selectedTechniques.isEmpty {
                    activeFilterBanner
                }

                // Content (Split view: Map + List)
                if viewModel.isLoading {
                    LoadingStateView(message: "Loading stores...")
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                } else {
                    // Always show split view, even when filtered stores is empty
                    splitViewContent
                }
            }
            .navigationTitle("Stores")
            .navigationDestination(for: StoreNavigationDestination.self) { destination in
                switch destination {
                case .storeDetail(let store):
                    StoreDetailView(store: store, deps: AppDependencies())
                }
            }
            .task {
                await viewModel.loadStores()
            }
            .refreshable {
                await viewModel.loadStores()
            }
            .sheet(isPresented: $showZipCodeEntry) {
                ZipCodeEntryView(viewModel: viewModel)
            }
            .sheet(isPresented: $showSearchEntry) {
                SearchStoresView(viewModel: viewModel)
            }
        }
    }

    // MARK: - Subviews

    /// Horizontal scrollable technique filter chips
    private var techniqueFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(TechniqueType.allCases.filter { $0 != .other }, id: \.self) { technique in
                    TechniqueChip(
                        technique: technique,
                        isSelected: viewModel.selectedTechniques.contains(technique),
                        action: {
                            viewModel.toggleTechnique(technique)
                        }
                    )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
        }
        .background(Color(.systemGray6))
        .frame(height: 44) // Fixed height to prevent collapse
    }

    /// Active filter indicator banner
    private var activeFilterBanner: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                if !viewModel.searchText.isEmpty {
                    Text("Search: \"\(viewModel.searchText)\"")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }

                if !viewModel.selectedTechniques.isEmpty {
                    Text("Techniques: \(viewModel.selectedTechniques.map { $0.displayName }.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Text("(\(viewModel.filteredStores.count))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: {
                viewModel.clearAllFilters()
            }) {
                HStack(spacing: 4) {
                    Text("Clear All")
                    Image(systemName: "xmark.circle.fill")
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(Color.orange.opacity(0.1))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.orange.opacity(0.3)),
            alignment: .bottom
        )
    }

    /// Split view: Map on top, visible stores list below
    private var splitViewContent: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Map (top 40% of available space)
                StoreMapView(viewModel: viewModel)
                    .frame(height: geometry.size.height * 0.4)

                Divider()

                // Visible stores list (bottom 60%)
                visibleStoresList
                    .frame(height: geometry.size.height * 0.6)
            }
        }
    }

    /// List showing stores visible in current map region, plus stores outside view
    private var visibleStoresList: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header showing count and suggest button
            HStack {
                Text("\(viewModel.visibleStores.count) stores in view")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)

                Spacer()

                // Suggest new store button
                Link(destination: URL(string: "https://moltenglass.app/submit-store/")!) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "plus.circle")
                        Text("Suggest Store")
                    }
                    .font(.caption)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.2))
                    .foregroundStyle(Color.accentColor)
                    .cornerRadius(DesignSystem.CornerRadius.small)
                }
                .padding(.trailing, DesignSystem.Spacing.md)
            }
            .background(Color(.systemGray6))

            // List of stores (visible + outside view)
            if viewModel.visibleStores.isEmpty && viewModel.storesOutsideView.isEmpty {
                VStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "map")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)

                    Text("No stores in this area")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Pan the map to explore")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    // Section 1: Stores in view
                    ForEach(viewModel.visibleStores, id: \.stable_id) { store in
                        Button(action: {
                            navigationPath.append(StoreNavigationDestination.storeDetail(store: store))
                        }) {
                            StoreRowView(
                                store: store,
                                userLocation: viewModel.effectiveLocation?.coordinate
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Section 2: Stores outside view
                    if !viewModel.storesOutsideView.isEmpty {
                        Section {
                            ForEach(viewModel.storesOutsideView, id: \.stable_id) { store in
                                Button(action: {
                                    navigationPath.append(StoreNavigationDestination.storeDetail(store: store))
                                }) {
                                    StoreRowView(
                                        store: store,
                                        userLocation: viewModel.effectiveLocation?.coordinate,
                                        showDistance: true
                                    )
                                }
                                .buttonStyle(.plain)
                                .opacity(0.5) // Reduced opacity for outside stores
                            }
                        } header: {
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: "arrow.down.to.line")
                                    .font(.caption2)
                                Text("Outside Map View")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text("(\(viewModel.storesOutsideView.count))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    /// Action buttons for search and location
    private var actionButtons: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Search Stores button
            Button(action: { showSearchEntry = true }) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "magnifyingglass")
                    Text("Search Stores")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(Color(.systemGray6))
                .cornerRadius(DesignSystem.CornerRadius.medium)
            }
            .foregroundStyle(.primary)

            // Set Location button
            Button(action: { showZipCodeEntry = true }) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "mappin.circle")
                    Text("Set Location")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(Color(.systemGray6))
                .cornerRadius(DesignSystem.CornerRadius.medium)
            }
            .foregroundStyle(.primary)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "storefront")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Stores Found")
                .font(.title2)
                .fontWeight(.semibold)

            if !viewModel.searchText.isEmpty || !viewModel.selectedTechniques.isEmpty {
                Text("Try adjusting your filters")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Clear Filters") {
                    viewModel.clearAllFilters()
                }
                .buttonStyle(.bordered)
            } else {
                Text("No stores available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.orange)

            Text("Error Loading Stores")
                .font(.title2)
                .fontWeight(.semibold)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task { await viewModel.loadStores() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

// MARK: - Technique Chip Component

/// Tappable chip for filtering by technique
struct TechniqueChip: View {
    let technique: TechniqueType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(technique.displayName)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .cornerRadius(DesignSystem.CornerRadius.small)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    StoreListView()
}

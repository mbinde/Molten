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
    case storeDetail(store: StoreModel)
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

                // Active search indicator
                if !viewModel.searchText.isEmpty {
                    activeSearchBanner
                }

                // Content (Split view: Map + List)
                if viewModel.isLoading {
                    ProgressView("Loading stores...")
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                } else if viewModel.filteredStores.isEmpty {
                    emptyStateView
                } else {
                    splitViewContent
                }
            }
            .navigationTitle("Stores")
            .navigationDestination(for: StoreNavigationDestination.self) { destination in
                switch destination {
                case .storeDetail(let store):
                    StoreDetailView(store: store, storeService: RepositoryFactory.createStoreService())
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

    /// Active search indicator banner
    private var activeSearchBanner: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .foregroundStyle(.orange)

            Text("Filtering: \"\(viewModel.searchText)\"")
                .font(.subheadline)
                .foregroundStyle(.primary)

            Text("(\(viewModel.filteredStores.count) stores)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: {
                viewModel.clearSearch()
            }) {
                HStack(spacing: 4) {
                    Text("Clear")
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

    /// List showing only stores visible in current map region
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

            // List of visible stores
            if viewModel.visibleStores.isEmpty {
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

            if !viewModel.searchText.isEmpty {
                Text("Try adjusting your search")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Clear Search") {
                    viewModel.clearSearch()
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

#Preview {
    StoreListView()
}

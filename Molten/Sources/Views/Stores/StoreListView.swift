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

    // ViewModel manages all state
    @State private var viewModel: StoreListViewModel

    init(viewModel: StoreListViewModel = StoreListViewModel()) {
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Search bar
                searchBar

                // Sort and filter options
                filterControls

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
        }
    }

    // MARK: - Subviews

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
            // Header showing count
            HStack {
                Text("\(viewModel.visibleStores.count) stores in view")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)

                Spacer()

                // Zip code entry button (if no location permission)
                if !viewModel.isLocationAuthorized {
                    zipCodeButton
                }
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
                                userLocation: viewModel.effectiveLocation?.coordinate,
                                showDistance: viewModel.sortOption == .distance
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    /// Button to enter zip code for manual location
    private var zipCodeButton: some View {
        Button(action: {
            showZipCodeEntry = true
        }) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "mappin.circle")
                Text("Set Location")
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

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search stores...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()

            if !viewModel.searchText.isEmpty {
                Button(action: { viewModel.clearSearch() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(DesignSystem.Padding.compact)
        .background(Color(.systemGray6))
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
    }

    private var filterControls: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Sort menu
                Menu {
                    Picker("Sort By", selection: $viewModel.sortOption) {
                        ForEach(StoreSortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } label: {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(viewModel.sortOption.rawValue)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(Color(.systemGray6))
                    .cornerRadius(DesignSystem.CornerRadius.medium)
                }

                // Verified filter toggle
                Button(action: { viewModel.showVerifiedOnly.toggle() }) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: viewModel.showVerifiedOnly ? "checkmark.circle.fill" : "checkmark.circle")
                        Text("Verified")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(viewModel.showVerifiedOnly ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
                    .foregroundStyle(viewModel.showVerifiedOnly ? Color.accentColor : Color.primary)
                    .cornerRadius(DesignSystem.CornerRadius.medium)
                }

                // Location sort button
                if viewModel.sortOption == .distance {
                    Button(action: { viewModel.requestLocationPermission() }) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: viewModel.isLocationAuthorized ? "location.fill" : "location.slash")
                            Text(viewModel.isLocationAuthorized ? "Nearby" : "Enable Location")
                        }
                        .font(.subheadline)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(viewModel.isLocationAuthorized ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
                        .foregroundStyle(viewModel.isLocationAuthorized ? Color.accentColor : Color.secondary)
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
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

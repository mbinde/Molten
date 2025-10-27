//
//  StoreListView.swift
//  Molten
//
//  Created for Store Feature on 10/26/25.
//

import SwiftUI
import Combine
import CoreLocation

enum StoreNavigationDestination: Hashable {
    case storeDetail(store: StoreModel)
}

struct StoreListView: View {
    @State private var searchText = ""
    @State private var stores: [StoreModel] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var sortOption: StoreSortOption = .name
    @State private var showVerifiedOnly = false
    @State private var navigationPath = NavigationPath()

    // Location services
    @StateObject private var locationManager = LocationManager()
    @State private var showingLocationPermissionAlert = false

    // Service dependency (injected via default parameter)
    private let storeService: StoreService

    init(storeService: StoreService = RepositoryFactory.createStoreService()) {
        self.storeService = storeService
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Search bar
                searchBar

                // Sort and filter options
                filterControls

                // Store list
                if isLoading {
                    ProgressView("Loading stores...")
                        .padding()
                } else if let error = errorMessage {
                    errorView(error)
                } else if filteredStores.isEmpty {
                    emptyStateView
                } else {
                    storeList
                }
            }
            .navigationTitle("Stores")
            .navigationDestination(for: StoreNavigationDestination.self) { destination in
                switch destination {
                case .storeDetail(let store):
                    StoreDetailView(store: store, storeService: storeService)
                }
            }
            .task {
                await loadStores()
            }
            .refreshable {
                await loadStores()
            }
        }
    }

    // MARK: - Subviews

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search stores...", text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
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
                    Picker("Sort By", selection: $sortOption) {
                        ForEach(StoreSortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } label: {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(sortOption.rawValue)
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
                Button(action: { showVerifiedOnly.toggle() }) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: showVerifiedOnly ? "checkmark.circle.fill" : "checkmark.circle")
                        Text("Verified")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(showVerifiedOnly ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
                    .foregroundStyle(showVerifiedOnly ? Color.accentColor : Color.primary)
                    .cornerRadius(DesignSystem.CornerRadius.medium)
                }

                // Location sort button
                if sortOption == .distance {
                    Button(action: requestLocationPermission) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: locationManager.isAuthorized ? "location.fill" : "location.slash")
                            Text(locationManager.isAuthorized ? "Nearby" : "Enable Location")
                        }
                        .font(.subheadline)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(locationManager.isAuthorized ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
                        .foregroundStyle(locationManager.isAuthorized ? Color.accentColor : Color.secondary)
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }

    private var storeList: some View {
        List {
            ForEach(filteredStores, id: \.stable_id) { store in
                Button(action: {
                    navigationPath.append(StoreNavigationDestination.storeDetail(store: store))
                }) {
                    StoreRowView(
                        store: store,
                        userLocation: locationManager.location?.coordinate,
                        showDistance: sortOption == .distance
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "storefront")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Stores Found")
                .font(.title2)
                .fontWeight(.semibold)

            if !searchText.isEmpty {
                Text("Try adjusting your search")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Clear Search") {
                    searchText = ""
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
                Task { await loadStores() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    // MARK: - Computed Properties

    private var filteredStores: [StoreModel] {
        var result = stores

        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { store in
                store.name.localizedCaseInsensitiveContains(searchText) ||
                store.city?.localizedCaseInsensitiveContains(searchText) == true ||
                store.state?.localizedCaseInsensitiveContains(searchText) == true
            }
        }

        // Filter by verified status
        if showVerifiedOnly {
            result = result.filter { $0.isVerified }
        }

        // Sort
        switch sortOption {
        case .name:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .city:
            result.sort { ($0.city ?? "").localizedCaseInsensitiveCompare($1.city ?? "") == .orderedAscending }
        case .state:
            result.sort { ($0.state ?? "").localizedCaseInsensitiveCompare($1.state ?? "") == .orderedAscending }
        case .verified:
            result.sort { store1, store2 in
                if store1.isVerified != store2.isVerified {
                    return store1.isVerified
                }
                return store1.name.localizedCaseInsensitiveCompare(store2.name) == .orderedAscending
            }
        case .distance:
            if let userCoord = locationManager.location?.coordinate {
                result.sort { store1, store2 in
                    let dist1 = store1.distance(from: userCoord) ?? Double.greatestFiniteMagnitude
                    let dist2 = store2.distance(from: userCoord) ?? Double.greatestFiniteMagnitude
                    return dist1 < dist2
                }
            }
        }

        return result
    }

    // MARK: - Methods

    private func loadStores() async {
        isLoading = true
        errorMessage = nil

        do {
            // Check if we need to load initial data from bundle
            let storeCount = try await storeService.getStoreCount()

            if storeCount == 0 {
                // First launch - load stores from bundle
                print("📦 StoreListView: No stores found, loading from bundle...")
                let loadedCount = try await storeService.loadStoresFromBundleResource(filename: "stores")
                print("✅ StoreListView: Loaded \(loadedCount) stores from bundle")
            }

            // Fetch all stores
            stores = try await storeService.getAllStores()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func requestLocationPermission() {
        locationManager.requestPermission()
    }
}

// MARK: - Location Manager

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?
    @Published var isAuthorized = false

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer

        // Check initial authorization status
        updateAuthorizationStatus(manager.authorizationStatus)
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            updateAuthorizationStatus(status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let lastLocation = locations.last
        Task { @MainActor in
            location = lastLocation
        }
    }

    private func updateAuthorizationStatus(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            isAuthorized = true
            manager.startUpdatingLocation()
        case .denied, .restricted:
            isAuthorized = false
            manager.stopUpdatingLocation()
        case .notDetermined:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }
}

#Preview {
    StoreListView()
}

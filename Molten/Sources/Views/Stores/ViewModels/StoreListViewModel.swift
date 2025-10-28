//
//  StoreListViewModel.swift
//  Molten
//
//  Created for Store Maps Feature on 10/27/25.
//

import SwiftUI
import CoreLocation
import MapKit
import Combine

/// Concrete implementation of StoreListViewModelProtocol
///
/// Manages state for both list and map views of stores, including:
/// - Loading stores from StoreService
/// - Filtering by search text and verified status
/// - Sorting by various criteria (name, city, distance, etc.)
/// - Tracking selected store for map callouts
/// - Location authorization and user location tracking
/// - Manual location entry via zip code
/// - Filtering stores by visible map region
@MainActor
@Observable
class StoreListViewModel: StoreListViewModelProtocol {

    // MARK: - UserDefaults Keys

    private static let manualLocationLatKey = "StoreListViewModel.manualLocation.latitude"
    private static let manualLocationLonKey = "StoreListViewModel.manualLocation.longitude"
    private static let searchTextKey = "StoreListViewModel.searchText"
    private static let selectedTechniquesKey = "StoreListViewModel.selectedTechniques"

    // MARK: - Published Properties

    private(set) var stores: [StoreModel] = []
    var searchText: String = "" {
        didSet {
            saveSearchText()
        }
    }
    var selectedTechniques: Set<TechniqueType> = [] {
        didSet {
            saveSelectedTechniques()
        }
    }
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?
    var sortOption: StoreSortOption = .name
    var showVerifiedOnly: Bool = false
    var selectedStore: StoreModel?
    var manualLocation: CLLocation? {
        didSet {
            saveManualLocation()
        }
    }
    var visibleRegion: MKCoordinateRegion?
    private(set) var mapRecenterTrigger: Int = 0

    var userLocation: CLLocation? {
        locationManager.location
    }

    var effectiveLocation: CLLocation? {
        userLocation ?? manualLocation
    }

    var isLocationAuthorized: Bool {
        locationManager.isAuthorized
    }

    // MARK: - Computed Properties

    var filteredStores: [StoreModel] {
        var result = stores

        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { store in
                store.name.localizedCaseInsensitiveContains(searchText) ||
                store.city?.localizedCaseInsensitiveContains(searchText) == true ||
                store.state?.localizedCaseInsensitiveContains(searchText) == true
            }
        }

        // Filter by techniques (OR logic - show stores that support ANY selected technique)
        if !selectedTechniques.isEmpty {
            result = result.filter { store in
                selectedTechniques.contains { technique in
                    store.supportsTechnique(technique)
                }
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
            if let effectiveLoc = effectiveLocation {
                result.sort { store1, store2 in
                    let dist1 = store1.distance(from: effectiveLoc.coordinate) ?? Double.greatestFiniteMagnitude
                    let dist2 = store2.distance(from: effectiveLoc.coordinate) ?? Double.greatestFiniteMagnitude
                    return dist1 < dist2
                }
            }
        }

        return result
    }

    /// Stores visible in the current map region
    var visibleStores: [StoreModel] {
        guard let region = visibleRegion else {
            return filteredStores
        }

        return filteredStores.filter { store in
            guard store.hasValidLocation else { return false }
            return isCoordinate(store.coordinate, inRegion: region)
        }
    }

    // MARK: - Dependencies

    private let storeService: StoreService
    private let locationManager: LocationManager

    // MARK: - Initialization

    init(
        storeService: StoreService = RepositoryFactory.createStoreService(),
        locationManager: LocationManager = LocationManager()
    ) {
        self.storeService = storeService
        self.locationManager = locationManager
        loadPersistedState()
    }

    // MARK: - Methods

    func loadStores() async {
        isLoading = true
        errorMessage = nil

        do {
            // Load stores using hybrid approach: bundle + web (web wins)
            let storeCount = try await storeService.getStoreCount()

            if storeCount == 0 {
                // First launch - load stores with hybrid approach
                print("📦 StoreListViewModel: No stores found, loading with hybrid approach...")
                let result = try await storeService.loadStoresHybrid()
                print("✅ StoreListViewModel: Loaded \(result.bundled) from bundle, \(result.web) from web, \(result.total) total")
            } else {
                // Subsequent launches - refresh from web in background (non-blocking)
                print("🔄 StoreListViewModel: Refreshing stores from web...")
                Task {
                    do {
                        let webCount = try await storeService.fetchStoresFromWeb()
                        print("✅ StoreListViewModel: Refreshed \(webCount) stores from web")
                        // Reload stores to show updates
                        stores = try await storeService.getAllStores()
                    } catch {
                        print("⚠️  StoreListViewModel: Failed to refresh from web (using cached): \(error.localizedDescription)")
                        // This is OK - we have cached data
                    }
                }
            }

            // Fetch all stores (from cache)
            stores = try await storeService.getAllStores()

            // Debug: Check if stores have technique data
            print("📊 Loaded \(stores.count) stores")
            if let firstStore = stores.first {
                print("📊 First store: \(firstStore.name)")
                print("📊 Techniques: \(firstStore.techniques.map { $0.displayName })")
                print("📊 supportsCasting: \(firstStore.supportsCasting)")
                print("📊 supportsFusing: \(firstStore.supportsFusing)")
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func requestLocationPermission() {
        locationManager.requestPermission()
    }

    func clearSearch() {
        searchText = ""
    }

    func toggleTechnique(_ technique: TechniqueType) {
        if selectedTechniques.contains(technique) {
            selectedTechniques.remove(technique)
        } else {
            selectedTechniques.insert(technique)
        }

        // Debug: Log filter results
        print("🔍 Selected techniques: \(selectedTechniques.map { $0.displayName })")
        print("🔍 Total stores: \(stores.count)")
        print("🔍 Filtered stores: \(filteredStores.count)")
        if filteredStores.count > 0 {
            print("🔍 First filtered store: \(filteredStores[0].name) - techniques: \(filteredStores[0].techniques.map { $0.displayName })")
        }
    }

    func clearAllFilters() {
        searchText = ""
        selectedTechniques.removeAll()
    }

    /// Set manual location from zip code using geocoding
    func setLocationFromZipCode(_ zipCode: String) async {
        let geocoder = CLGeocoder()

        do {
            let placemarks = try await geocoder.geocodeAddressString(zipCode)

            if let location = placemarks.first?.location {
                manualLocation = location
                mapRecenterTrigger += 1
                print("✅ StoreListViewModel: Set location from zip code \(zipCode): \(location.coordinate.latitude), \(location.coordinate.longitude)")
                print("🗺️ StoreListViewModel: Map recenter trigger = \(mapRecenterTrigger)")
            } else {
                print("⚠️  StoreListViewModel: No location found for zip code \(zipCode)")
            }
        } catch {
            print("❌ StoreListViewModel: Geocoding failed for zip code \(zipCode): \(error.localizedDescription)")
        }
    }

    /// Update visible map region
    func updateVisibleRegion(_ region: MKCoordinateRegion) {
        visibleRegion = region
    }

    // MARK: - Helper Methods

    /// Check if a coordinate falls within a map region
    private func isCoordinate(_ coordinate: CLLocationCoordinate2D, inRegion region: MKCoordinateRegion) -> Bool {
        let latDelta = region.span.latitudeDelta
        let lonDelta = region.span.longitudeDelta

        let minLat = region.center.latitude - latDelta / 2
        let maxLat = region.center.latitude + latDelta / 2
        let minLon = region.center.longitude - lonDelta / 2
        let maxLon = region.center.longitude + lonDelta / 2

        return coordinate.latitude >= minLat &&
               coordinate.latitude <= maxLat &&
               coordinate.longitude >= minLon &&
               coordinate.longitude <= maxLon
    }

    // MARK: - Persistence

    /// Load persisted state from UserDefaults
    private func loadPersistedState() {
        // Load manual location
        if let latitude = UserDefaults.standard.object(forKey: Self.manualLocationLatKey) as? Double,
           let longitude = UserDefaults.standard.object(forKey: Self.manualLocationLonKey) as? Double {
            manualLocation = CLLocation(latitude: latitude, longitude: longitude)
            print("📍 StoreListViewModel: Loaded persisted location: \(latitude), \(longitude)")
        }

        // Load search text
        if let savedSearchText = UserDefaults.standard.string(forKey: Self.searchTextKey) {
            searchText = savedSearchText
            print("🔍 StoreListViewModel: Loaded persisted search text: '\(savedSearchText)'")
        }

        // Load selected techniques
        if let savedTechniques = UserDefaults.standard.array(forKey: Self.selectedTechniquesKey) as? [String] {
            selectedTechniques = Set(savedTechniques.compactMap { TechniqueType(rawValue: $0) })
            print("🏷️ StoreListViewModel: Loaded persisted techniques: \(savedTechniques)")
        }
    }

    /// Save manual location to UserDefaults
    private func saveManualLocation() {
        if let location = manualLocation {
            UserDefaults.standard.set(location.coordinate.latitude, forKey: Self.manualLocationLatKey)
            UserDefaults.standard.set(location.coordinate.longitude, forKey: Self.manualLocationLonKey)
            print("💾 StoreListViewModel: Saved location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        } else {
            UserDefaults.standard.removeObject(forKey: Self.manualLocationLatKey)
            UserDefaults.standard.removeObject(forKey: Self.manualLocationLonKey)
            print("💾 StoreListViewModel: Cleared location")
        }
    }

    /// Save search text to UserDefaults
    private func saveSearchText() {
        if searchText.isEmpty {
            UserDefaults.standard.removeObject(forKey: Self.searchTextKey)
            print("💾 StoreListViewModel: Cleared search text")
        } else {
            UserDefaults.standard.set(searchText, forKey: Self.searchTextKey)
            print("💾 StoreListViewModel: Saved search text: '\(searchText)'")
        }
    }

    /// Save selected techniques to UserDefaults
    private func saveSelectedTechniques() {
        if selectedTechniques.isEmpty {
            UserDefaults.standard.removeObject(forKey: Self.selectedTechniquesKey)
            print("💾 StoreListViewModel: Cleared selected techniques")
        } else {
            let techniqueStrings = selectedTechniques.map { $0.rawValue }
            UserDefaults.standard.set(techniqueStrings, forKey: Self.selectedTechniquesKey)
            print("💾 StoreListViewModel: Saved selected techniques: \(techniqueStrings)")
        }
    }
}

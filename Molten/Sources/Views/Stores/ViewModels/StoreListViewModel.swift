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
/// - Loading stores from UnifiedLocationService
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

    private(set) var stores: [UnifiedLocationModel] = []
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
    var sortOption: LocationSortOption = .name
    var showVerifiedOnly: Bool = false
    var selectedStore: UnifiedLocationModel?
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

    var filteredStores: [UnifiedLocationModel] {
        var result = stores

        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { location in
                location.name.localizedCaseInsensitiveContains(searchText) ||
                location.city?.localizedCaseInsensitiveContains(searchText) == true ||
                location.state?.localizedCaseInsensitiveContains(searchText) == true
            }
        }

        // Filter by techniques (OR logic - show stores that support ANY selected technique)
        if !selectedTechniques.isEmpty {
            result = result.filter { location in
                selectedTechniques.contains { technique in
                    location.supportsTechnique(technique)
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
            result.sort { location1, location2 in
                if location1.isVerified != location2.isVerified {
                    return location1.isVerified
                }
                return location1.name.localizedCaseInsensitiveCompare(location2.name) == .orderedAscending
            }
        case .distance:
            if let effectiveLoc = effectiveLocation {
                result.sort { location1, location2 in
                    let dist1 = location1.distance(from: effectiveLoc.coordinate) ?? Double.greatestFiniteMagnitude
                    let dist2 = location2.distance(from: effectiveLoc.coordinate) ?? Double.greatestFiniteMagnitude
                    return dist1 < dist2
                }
            }
        case .capabilities:
            // Sort by number of capabilities (more capabilities first)
            result.sort { location1, location2 in
                let cap1 = location1.retailCapabilities.count + location1.educationCapabilities.count + location1.servicesCapabilities.count
                let cap2 = location2.retailCapabilities.count + location2.educationCapabilities.count + location2.servicesCapabilities.count
                if cap1 != cap2 {
                    return cap1 > cap2
                }
                return location1.name.localizedCaseInsensitiveCompare(location2.name) == .orderedAscending
            }
        }

        return result
    }

    /// Stores visible in the current map region
    var visibleStores: [UnifiedLocationModel] {
        guard let region = visibleRegion else {
            return filteredStores
        }

        return filteredStores.filter { location in
            guard location.hasValidLocation else { return false }
            return isCoordinate(location.coordinate, inRegion: region)
        }
    }

    /// Stores outside the current map region, sorted by distance from map center
    var storesOutsideView: [UnifiedLocationModel] {
        guard let region = visibleRegion else {
            return []
        }

        let outsideStores = filteredStores.filter { location in
            guard location.hasValidLocation else { return false }
            return !isCoordinate(location.coordinate, inRegion: region)
        }

        // Sort by distance from map center
        let mapCenter = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
        return outsideStores.sorted { location1, location2 in
            let dist1 = location1.distance(from: mapCenter.coordinate) ?? Double.greatestFiniteMagnitude
            let dist2 = location2.distance(from: mapCenter.coordinate) ?? Double.greatestFiniteMagnitude
            return dist1 < dist2
        }
    }

    // MARK: - Dependencies

    private let locationService: UnifiedLocationService
    private let locationManager: LocationManager

    // MARK: - Initialization

    init(
        locationService: UnifiedLocationService,
        locationManager: LocationManager
    ) {
        self.locationService = locationService
        self.locationManager = locationManager
        loadPersistedState()
    }

    /// Convenience init using AppDependencies
    convenience init(deps: AppDependencies = AppDependencies(), locationManager: LocationManager = LocationManager()) {
        self.init(
            locationService: deps.unifiedLocationService,
            locationManager: locationManager
        )
    }

    // MARK: - Methods

    func loadStores() async {
        isLoading = true
        errorMessage = nil

        do {
            // Load stores using hybrid approach: bundle + web (web wins)
            let storeCount = try await locationService.getRetailLocationCount()

            if storeCount == 0 {
                // First launch - load stores with hybrid approach
                print("📦 StoreListViewModel: No locations found, loading with hybrid approach...")
                let result = try await locationService.loadLocationsHybrid()
                print("✅ StoreListViewModel: Loaded \(result.bundled) from bundle, \(result.web) from web, \(result.total) total")
            } else {
                // Subsequent launches - refresh from web in background (non-blocking)
                print("🔄 StoreListViewModel: Refreshing locations from web...")
                Task {
                    do {
                        let webCount = try await locationService.fetchLocationsFromWeb()
                        print("✅ StoreListViewModel: Refreshed \(webCount) locations from web")
                        // Reload stores to show updates
                        stores = try await locationService.getRetailLocations()
                    } catch {
                        print("⚠️  StoreListViewModel: Failed to refresh from web (using cached): \(error.localizedDescription)")
                        // This is OK - we have cached data
                    }
                }
            }

            // Fetch all retail locations (from cache)
            stores = try await locationService.getRetailLocations()

            // Debug: Check if stores have technique data
            print("📊 Loaded \(stores.count) locations")
            if let firstLocation = stores.first {
                print("📊 First location: \(firstLocation.name)")
                print("📊 Retail techniques: \(firstLocation.retailTechniques.map { $0.displayName })")
                print("📊 Has retail: \(firstLocation.hasRetail)")
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
        }

        // Load selected techniques
        if let savedTechniques = UserDefaults.standard.array(forKey: Self.selectedTechniquesKey) as? [String] {
            selectedTechniques = Set(savedTechniques.compactMap { TechniqueType(rawValue: $0) })
        }
    }

    /// Save manual location to UserDefaults
    private func saveManualLocation() {
        if let location = manualLocation {
            UserDefaults.standard.set(location.coordinate.latitude, forKey: Self.manualLocationLatKey)
            UserDefaults.standard.set(location.coordinate.longitude, forKey: Self.manualLocationLonKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.manualLocationLatKey)
            UserDefaults.standard.removeObject(forKey: Self.manualLocationLonKey)
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

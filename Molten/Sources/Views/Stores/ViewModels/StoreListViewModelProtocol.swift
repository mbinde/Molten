//
//  StoreListViewModelProtocol.swift
//  Molten
//
//  Created for Store Maps Feature on 10/27/25.
//

import SwiftUI
import CoreLocation
import MapKit
import Combine

/// Protocol defining the interface for store list/map presentation logic
/// Note: LocationSortOption is defined in UnifiedLocationService.swift
protocol StoreListViewModelProtocol: ObservableObject {
    // MARK: - Published Properties

    /// Current list of stores (unfiltered)
    var stores: [UnifiedLocationModel] { get }

    /// Filtered and sorted stores based on current criteria
    var filteredStores: [UnifiedLocationModel] { get }

    /// Stores visible in the current map region
    var visibleStores: [UnifiedLocationModel] { get }

    /// Current search text
    var searchText: String { get set }

    /// Whether stores are currently loading
    var isLoading: Bool { get }

    /// Current error message, if any
    var errorMessage: String? { get }

    /// Current sort option
    var sortOption: LocationSortOption { get set }

    /// Whether to show only verified stores
    var showVerifiedOnly: Bool { get set }

    /// User's current location (if authorized)
    var userLocation: CLLocation? { get }

    /// Manual location (set via zip code if user doesn't share GPS location)
    var manualLocation: CLLocation? { get set }

    /// Effective location (user location if authorized, else manual location)
    var effectiveLocation: CLLocation? { get }

    /// Whether location access is authorized
    var isLocationAuthorized: Bool { get }

    /// Selected store for map marker callout
    var selectedStore: UnifiedLocationModel? { get set }

    /// Current visible map region
    var visibleRegion: MKCoordinateRegion? { get set }

    /// Trigger that increments when map should recenter (e.g., after zip code entry)
    var mapRecenterTrigger: Int { get }

    // MARK: - Methods

    /// Load stores from the service
    func loadStores() async

    /// Request location permission
    func requestLocationPermission()

    /// Clear the current search
    func clearSearch()

    /// Set manual location from zip code
    func setLocationFromZipCode(_ zipCode: String) async

    /// Update visible map region (called when map is panned/zoomed)
    func updateVisibleRegion(_ region: MKCoordinateRegion)
}

//
//  LocationsViewModel.swift
//  Molten
//
//  Created for unified Locations feature on 11/1/25.
//

import Foundation
import CoreLocation
import Observation
import MapKit

/// ViewModel for unified locations view (stores, classes, workshops)
@Observable
@MainActor
class LocationsViewModel {

    // MARK: - Dependencies

    private let locationService: UnifiedLocationService

    // MARK: - State

    var allLocations: [AnyLocationModel] = []
    var filteredLocations: [AnyLocationModel] = []
    var selectedTypes: Set<LocationType>
    var searchText: String = ""  // What's shown in the search field (zip code for location search)
    var isLoading: Bool = false
    var errorMessage: String?
    var showMap: Bool = true
    var userLocation: CLLocationCoordinate2D?
    var mapCenter: CLLocationCoordinate2D?
    var mapBounds: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)?
    var selectedTechnique: TechniqueType?
    var geocodedLocation: CLLocationCoordinate2D?  // Location from zip code search
    var geocodedLocationTrigger: Int = 0  // Increment to trigger map update
    var isGeocoding: Bool = false

    // MARK: - Computed Properties

    var isEmpty: Bool {
        filteredLocations.isEmpty
    }

    var emptyStateMessage: String {
        if !searchText.isEmpty {
            return "No locations found matching '\(searchText)'. Try different search terms or filters."
        } else if mapBounds != nil {
            return "No locations in this area. Zoom out or pan the map to explore more locations."
        } else {
            return "No locations found. Try adjusting your filters."
        }
    }

    // MARK: - Initialization

    init(
        locationService: UnifiedLocationService,
        selectedTypes: Set<LocationType>? = nil,
        selectedTechnique: TechniqueType? = nil
    ) {
        self.locationService = locationService
        self.selectedTypes = selectedTypes ?? LocationFilterPreferences.getSelectedTypes()
        self.selectedTechnique = selectedTechnique ?? LocationFilterPreferences.getSelectedTechnique()
    }

    // MARK: - Data Loading

    func loadLocations() async {
        isLoading = true
        errorMessage = nil

        do {
            // Load all unified locations
            let unifiedLocations = try await locationService.getAllLocations()

            // Convert to AnyLocationModel and filter by selected types
            var locations: [AnyLocationModel] = []
            for location in unifiedLocations {
                let anyLocation = AnyLocationModel(unified: location)

                // Include location if its type is selected
                if selectedTypes.contains(anyLocation.type) {
                    locations.append(anyLocation)
                }
            }

            allLocations = locations
            applyFilters()

        } catch {
            errorMessage = "Failed to load locations: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Filtering & Sorting

    func applyFilters() {
        var results = allLocations

        // Filter by map bounds
        if let bounds = mapBounds {
            results = results.filter { location in
                guard location.hasValidLocation else { return false }
                return location.latitude >= bounds.minLat &&
                       location.latitude <= bounds.maxLat &&
                       location.longitude >= bounds.minLon &&
                       location.longitude <= bounds.maxLon
            }
        }

        // Filter by selected technique
        if let technique = selectedTechnique {
            results = results.filter { $0.supportsTechnique(technique) }
        }

        // Sort by distance from map center (or user location), then alphabetically
        let referencePoint = mapCenter ?? userLocation

        if let refPoint = referencePoint {
            results.sort { loc1, loc2 in
                let dist1 = loc1.distance(from: refPoint) ?? Double.greatestFiniteMagnitude
                let dist2 = loc2.distance(from: refPoint) ?? Double.greatestFiniteMagnitude

                // If distances are significantly different, sort by distance
                if abs(dist1 - dist2) > 1000 { // 1km threshold
                    return dist1 < dist2
                }
                // Otherwise sort alphabetically
                return loc1.name.localizedCaseInsensitiveCompare(loc2.name) == .orderedAscending
            }
        } else {
            // No reference point, just sort alphabetically
            results.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        filteredLocations = results
    }

    func updateSearchText(_ text: String) {
        searchText = text
    }

    /// Geocode the current search text and center the map on the result
    func performSearch() async {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            geocodedLocation = nil
            return
        }

        isGeocoding = true
        defer { isGeocoding = false }

        let geocoder = CLGeocoder()

        do {
            let placemarks = try await geocoder.geocodeAddressString(trimmed)

            if let location = placemarks.first?.location {
                geocodedLocation = location.coordinate
                geocodedLocationTrigger += 1
            }
        } catch {
            print("❌ LocationsViewModel: Geocoding failed for '\(trimmed)': \(error.localizedDescription)")
            geocodedLocation = nil
        }
    }

    func toggleType(_ type: LocationType) async {
        if selectedTypes.contains(type) {
            // Don't allow deselecting the last type
            if selectedTypes.count > 1 {
                selectedTypes.remove(type)
            }
        } else {
            selectedTypes.insert(type)
        }

        // Save preference
        LocationFilterPreferences.saveSelectedTypes(selectedTypes)

        // Reload data with new filters
        await loadLocations()
    }

    func updateUserLocation(_ location: CLLocationCoordinate2D?) {
        userLocation = location
        applyFilters()
    }

    func updateMapCenter(_ center: CLLocationCoordinate2D?) {
        mapCenter = center
        applyFilters()
    }

    func updateMapBounds(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        mapBounds = (minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
        applyFilters()
    }

    func updateSelectedTechnique(_ technique: TechniqueType?) {
        selectedTechnique = technique
        LocationFilterPreferences.saveSelectedTechnique(technique)
        applyFilters()
    }

    // MARK: - Search by Technique

    func filterByTechnique(_ technique: TechniqueType) async {
        isLoading = true
        errorMessage = nil

        do {
            // Get all locations that support the technique (either retail or education)
            let unifiedLocations = try await locationService.getLocations(supportingTechnique: technique)

            // Convert to AnyLocationModel and filter by selected types
            var locations: [AnyLocationModel] = []
            for location in unifiedLocations {
                let anyLocation = AnyLocationModel(unified: location)

                // Include location if its type is selected
                if selectedTypes.contains(anyLocation.type) {
                    locations.append(anyLocation)
                }
            }

            allLocations = locations
            applyFilters()

        } catch {
            errorMessage = "Failed to filter locations: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Map Toggle

    func toggleMap() {
        showMap.toggle()
    }
}

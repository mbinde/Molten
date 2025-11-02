//
//  LocationsViewModel.swift
//  Molten
//
//  Created for unified Locations feature on 11/1/25.
//

import Foundation
import CoreLocation
import Observation

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
    var searchText: String = ""
    var isLoading: Bool = false
    var errorMessage: String?
    var showMap: Bool = true
    var userLocation: CLLocationCoordinate2D?

    // MARK: - Computed Properties

    var isEmpty: Bool {
        filteredLocations.isEmpty
    }

    var emptyStateMessage: String {
        if searchText.isEmpty {
            return "No locations found. Try expanding your search radius or adjusting filters."
        } else {
            return "No locations found matching '\(searchText)'. Try different search terms or filters."
        }
    }

    // MARK: - Initialization

    init(
        locationService: UnifiedLocationService,
        selectedTypes: Set<LocationType>? = nil
    ) {
        self.locationService = locationService
        self.selectedTypes = selectedTypes ?? LocationFilterPreferences.getSelectedTypes()
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

        // Filter by search text
        if !searchText.isEmpty {
            results = results.filter { $0.matchesSearchText(searchText) }
        }

        // Sort by distance (if available), then alphabetically
        if let userLoc = userLocation {
            results.sort { loc1, loc2 in
                let dist1 = loc1.distance(from: userLoc) ?? Double.greatestFiniteMagnitude
                let dist2 = loc2.distance(from: userLoc) ?? Double.greatestFiniteMagnitude

                // If distances are significantly different, sort by distance
                if abs(dist1 - dist2) > 1000 { // 1km threshold
                    return dist1 < dist2
                }
                // Otherwise sort alphabetically
                return loc1.name.localizedCaseInsensitiveCompare(loc2.name) == .orderedAscending
            }
        } else {
            // No user location, just sort alphabetically
            results.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        filteredLocations = results
    }

    func updateSearchText(_ text: String) {
        searchText = text
        applyFilters()
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

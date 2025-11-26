//
//  LocationsView.swift
//  Molten
//
//  Created for unified Locations feature on 11/1/25.
//

import SwiftUI
import MapKit

/// Unified view for browsing stores, classes, and workshops
struct LocationsView: View {
    @State private var viewModel: LocationsViewModel
    @StateObject private var locationManager = LocationManager()
    @State private var showLocationPicker = false
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var mapUpdateTask: Task<Void, Never>?

    // Init accepts ViewModel directly (DI pattern)
    init(viewModel: LocationsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBarView
                    .padding(.horizontal, DesignSystem.Padding.standard)
                    .padding(.vertical, DesignSystem.Padding.compact)

                // Filter chips
                filterChipsView
                    .padding(.horizontal, DesignSystem.Padding.standard)
                    .padding(.bottom, DesignSystem.Padding.compact)

                // Map view (toggleable)
                if viewModel.showMap {
                    VStack(spacing: 0) {
                        mapView
                            .frame(height: 250)

                        // Suggest location link below map
                        HStack {
                            Spacer()
                            Button {
                                if let url = URL(string: "https://moltenglass.app/submit-store/") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Text("Suggest a location")
                                    .font(.caption)
                                    .foregroundStyle(Color.accentColor)
                            }
                            .padding(.trailing, DesignSystem.Padding.standard)
                        }
                        .padding(.vertical, 4)
                        .padding(.bottom, 4)
                    }
                }

                // List view
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.isEmpty {
                    if shouldShowSearchEmptyState {
                        searchEmptyStateView
                    } else {
                        emptyStateView
                    }
                } else {
                    listView
                }
            }
            .navigationTitle("Locations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        // Clear search button - placed in toolbar for reliable accessibility
                        if !viewModel.searchText.isEmpty {
                            Button {
                                viewModel.updateSearchText("")
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                            }
                            .accessibilityIdentifier("locations_clear_search")
                            .accessibilityLabel("Clear search")
                        }

                        Button {
                            viewModel.toggleMap()
                        } label: {
                            Image(systemName: viewModel.showMap ? "map.fill" : "map")
                        }
                        .accessibilityIdentifier("locations_toggle_map")
                    }
                }
            }
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerSheet(onLocationSelected: { coordinate in
                    viewModel.updateUserLocation(coordinate)

                    // Center map on selected location (approximately 25 miles radius)
                    let span = MKCoordinateSpan(latitudeDelta: 0.36, longitudeDelta: 0.36)
                    let region = MKCoordinateRegion(center: coordinate, span: span)
                    mapCameraPosition = .region(region)

                    // Update map bounds for the new location
                    let minLat = coordinate.latitude - (span.latitudeDelta / 2)
                    let maxLat = coordinate.latitude + (span.latitudeDelta / 2)
                    let minLon = coordinate.longitude - (span.longitudeDelta / 2)
                    let maxLon = coordinate.longitude + (span.longitudeDelta / 2)

                    viewModel.updateMapCenter(coordinate)
                    viewModel.updateMapBounds(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)

                    showLocationPicker = false
                })
            }
            .task {
                await viewModel.loadLocations()
            }
            .onChange(of: locationManager.location) { oldValue, newValue in
                if let location = newValue {
                    viewModel.updateUserLocation(location.coordinate)
                }
            }
            .onAppear {
                // Request location permission on first appearance
                if !locationManager.isAuthorized {
                    locationManager.requestPermission()
                }
            }
        }
    }

    // MARK: - Filter Chips

    private var filterChipsView: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Location type filters (exclude workshops)
            ForEach(LocationType.allCases.filter { $0 != .workshop }) { type in
                filterChip(for: type)
            }

            // Technique filter dropdown
            techniqueFilterMenu

            Spacer()
        }
    }

    private func filterChip(for type: LocationType) -> some View {
        Button {
            Task {
                await viewModel.toggleType(type)
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.xs) {
                type.icon
                    .font(.caption)
                Text(type.displayName)
                    .font(DesignSystem.Typography.label)
            }
            .padding(.horizontal, DesignSystem.Padding.standard)
            .padding(.vertical, DesignSystem.Padding.compact)
            .background(
                viewModel.selectedTypes.contains(type)
                    ? DesignSystem.Colors.accentPrimary
                    : Color.gray.opacity(0.2)
            )
            .foregroundStyle(
                viewModel.selectedTypes.contains(type)
                    ? .white
                    : DesignSystem.Colors.textSecondary
            )
            .cornerRadius(DesignSystem.CornerRadius.large)
        }
    }

    private var techniqueFilterMenu: some View {
        Menu {
            // "All Techniques" option to clear filter
            Button {
                viewModel.updateSelectedTechnique(nil)
            } label: {
                HStack {
                    Text("All Techniques")
                    if viewModel.selectedTechnique == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }

            Divider()

            // Individual technique options
            ForEach(TechniqueType.allCases, id: \.self) { technique in
                Button {
                    viewModel.updateSelectedTechnique(technique)
                } label: {
                    HStack {
                        Text(technique.displayName)
                        if viewModel.selectedTechnique == technique {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.caption)
                Text(viewModel.selectedTechnique?.displayName ?? "Technique")
                    .font(DesignSystem.Typography.label)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, DesignSystem.Padding.standard)
            .padding(.vertical, DesignSystem.Padding.compact)
            .background(
                viewModel.selectedTechnique != nil
                    ? DesignSystem.Colors.accentPrimary
                    : Color.gray.opacity(0.2)
            )
            .foregroundStyle(
                viewModel.selectedTechnique != nil
                    ? .white
                    : DesignSystem.Colors.textSecondary
            )
            .cornerRadius(DesignSystem.CornerRadius.large)
        }
    }

    // MARK: - Search Bar

    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DesignSystem.Colors.textTertiary)

            TextField("Search locations", text: Binding(
                get: { viewModel.searchText },
                set: { viewModel.updateSearchText($0) }
            ))
            .textFieldStyle(.plain)
            .autocorrectionDisabled()

            // Clear button moved to toolbar for reliable accessibility
            // (in-field button can be obscured by keyboard on some devices)
        }
        .padding(DesignSystem.Padding.compact)
        .background(DesignSystem.Colors.backgroundSecondary)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }

    // MARK: - Map View

    private var mapView: some View {
        Map(position: $mapCameraPosition, interactionModes: [.pan, .zoom]) {
            ForEach(viewModel.filteredLocations) { location in
                if location.hasValidLocation {
                    Annotation(location.name, coordinate: location.coordinate) {
                        ZStack {
                            // Outer colored ring
                            Circle()
                                .stroke(ringColor(for: location), lineWidth: 3)
                                .frame(width: 40, height: 40)

                            // Blue background circle
                            Circle()
                                .fill(DesignSystem.Colors.accentPrimary)
                                .frame(width: 34, height: 34)

                            // White icon(s)
                            markerIcon(for: location)
                                .font(.caption)
                                .foregroundStyle(.white)
                        }
                    }
                }
            }

            // Show user location if available
            if let userLoc = locationManager.location {
                Annotation("My Location", coordinate: userLoc.coordinate) {
                    ZStack {
                        Circle()
                            .fill(.blue)
                            .frame(width: 20, height: 20)

                        Circle()
                            .stroke(.white, lineWidth: 3)
                            .frame(width: 20, height: 20)
                    }
                }
            }
        }
        .mapStyle(.standard)
        .onMapCameraChange { context in
            // Debounce map updates to avoid updating multiple times per frame
            // Cancel any pending update
            mapUpdateTask?.cancel()

            // Schedule new update after a short delay
            mapUpdateTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }

                // Save the camera position
                saveMapRegion(context.region)

                // Calculate map bounds
                let center = context.region.center
                let span = context.region.span
                let minLat = center.latitude - (span.latitudeDelta / 2)
                let maxLat = center.latitude + (span.latitudeDelta / 2)
                let minLon = center.longitude - (span.longitudeDelta / 2)
                let maxLon = center.longitude + (span.longitudeDelta / 2)

                // Update ViewModel with new map center and bounds
                viewModel.updateMapCenter(context.region.center)
                viewModel.updateMapBounds(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
            }
        }
        .onAppear {
            // Restore saved map region on first appear
            restoreMapRegion()
        }
    }

    // MARK: - Helper Methods

    /// Save map region to UserDefaults
    private func saveMapRegion(_ region: MKCoordinateRegion) {
        let defaults = UserDefaults.standard
        defaults.set(region.center.latitude, forKey: "LocationsMap.latitude")
        defaults.set(region.center.longitude, forKey: "LocationsMap.longitude")
        defaults.set(region.span.latitudeDelta, forKey: "LocationsMap.latitudeDelta")
        defaults.set(region.span.longitudeDelta, forKey: "LocationsMap.longitudeDelta")
    }

    /// Restore map region from UserDefaults
    private func restoreMapRegion() {
        let defaults = UserDefaults.standard

        // Only restore if we have saved values
        guard defaults.object(forKey: "LocationsMap.latitude") != nil else {
            return
        }

        let latitude = defaults.double(forKey: "LocationsMap.latitude")
        let longitude = defaults.double(forKey: "LocationsMap.longitude")
        let latitudeDelta = defaults.double(forKey: "LocationsMap.latitudeDelta")
        let longitudeDelta = defaults.double(forKey: "LocationsMap.longitudeDelta")

        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let span = MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        let region = MKCoordinateRegion(center: center, span: span)

        mapCameraPosition = .region(region)

        // Calculate and update map bounds
        let minLat = center.latitude - (span.latitudeDelta / 2)
        let maxLat = center.latitude + (span.latitudeDelta / 2)
        let minLon = center.longitude - (span.longitudeDelta / 2)
        let maxLon = center.longitude + (span.longitudeDelta / 2)

        // Update ViewModel with restored map center and bounds
        viewModel.updateMapCenter(center)
        viewModel.updateMapBounds(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
    }

    /// Center map on user's current location
    private func centerMapOnUserLocation() {
        guard let userLocation = locationManager.location?.coordinate else {
            // If no location available, request permission
            locationManager.requestPermission()
            return
        }

        // Center map on user location (approximately 25 miles radius)
        let span = MKCoordinateSpan(latitudeDelta: 0.36, longitudeDelta: 0.36)
        let region = MKCoordinateRegion(center: userLocation, span: span)
        mapCameraPosition = .region(region)

        // Update map bounds
        let minLat = userLocation.latitude - (span.latitudeDelta / 2)
        let maxLat = userLocation.latitude + (span.latitudeDelta / 2)
        let minLon = userLocation.longitude - (span.longitudeDelta / 2)
        let maxLon = userLocation.longitude + (span.longitudeDelta / 2)

        viewModel.updateMapCenter(userLocation)
        viewModel.updateMapBounds(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
    }

    /// Determine ring color based on location capabilities
    private func ringColor(for location: AnyLocationModel) -> Color {
        return .black
    }

    /// Determine marker icon based on location capabilities
    @ViewBuilder
    private func markerIcon(for location: AnyLocationModel) -> some View {
        if location.hasRetail && location.hasEducation {
            // Both icons for mixed locations
            HStack(spacing: 2) {
                Image(systemName: "storefront.fill")
                    .font(.system(size: 10))
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 10))
            }
        } else if location.hasEducation {
            Image(systemName: "graduationcap.fill")
        } else {
            Image(systemName: "storefront.fill")
        }
    }

    // MARK: - List View

    private var listView: some View {
        List {
            ForEach(viewModel.filteredLocations) { location in
                NavigationLink(value: location) {
                    LocationRow(
                        location: location,
                        userLocation: viewModel.userLocation
                    )
                }
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: AnyLocationModel.self) { location in
            LocationDetailView(location: location)
        }
    }

    // MARK: - Loading & Empty States

    private var loadingView: some View {
        LoadingStateView(message: "Loading locations...")
    }

    private var shouldShowSearchEmptyState: Bool {
        !viewModel.allLocations.isEmpty && (!viewModel.searchText.isEmpty || !viewModel.selectedTypes.isEmpty || viewModel.selectedTechnique != nil)
    }

    private var emptyStateView: some View {
        CustomEmptyStateView(
            icon: "map",
            title: "No locations found",
            description: viewModel.emptyStateMessage
        )
    }

    private var searchEmptyStateView: some View {
        var activeFilters: [String] = []
        if !viewModel.selectedTypes.isEmpty {
            activeFilters.append(viewModel.selectedTypes.map { $0.displayName }.joined(separator: ", "))
        }
        if let technique = viewModel.selectedTechnique {
            activeFilters.append("technique '\(technique.displayName)'")
        }

        return CustomEmptyStateView.searchResults(
            searchTerm: viewModel.searchText.isEmpty ? nil : viewModel.searchText,
            filters: activeFilters,
            onClearFilters: {
                viewModel.updateSearchText("")
                viewModel.selectedTypes.removeAll()
                viewModel.updateSelectedTechnique(nil)
            }
        )
    }
}

#Preview {
    let deps = AppDependencies(persistenceController: .createTestController())
    return LocationsView(viewModel: LocationsViewModel(
        locationService: deps.unifiedLocationService
    ))
}

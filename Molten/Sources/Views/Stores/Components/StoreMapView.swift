//
//  StoreMapView.swift
//  Molten
//
//  Created for Store Maps Feature on 10/27/25.
//

import SwiftUI
import MapKit

/// Map view displaying store locations with markers and callouts
///
/// Features:
/// - Store markers with clustering for performance
/// - Tap to select stores and show callouts
/// - User location tracking
/// - Dynamic map region based on stores
/// - Integrates with StoreListViewModel for filtering/sorting
struct StoreMapView: View {
    // ViewModel provides filtered stores
    @Bindable var viewModel: StoreListViewModel

    // Map state
    @State private var position: MapCameraPosition = .automatic
    @State private var mapSelection: String? // Store stable_id
    @State private var currentRegion: MKCoordinateRegion?

    var body: some View {
        Map(position: $position, selection: $mapSelection) {
            // User location marker (if authorized)
            if viewModel.isLocationAuthorized {
                UserAnnotation()
            }

            // Manual location marker (if set and no GPS)
            if !viewModel.isLocationAuthorized, let manualLoc = viewModel.manualLocation {
                Annotation("Your Location", coordinate: manualLoc.coordinate) {
                    ZStack {
                        Circle()
                            .fill(.blue.opacity(0.3))
                            .frame(width: 32, height: 32)
                        Circle()
                            .fill(.blue)
                            .frame(width: 16, height: 16)
                    }
                }
            }

            // Location markers with clustering
            ForEach(viewModel.filteredStores, id: \.stable_id) { location in
                if location.hasValidLocation {
                    // Different markers based on location capabilities
                    if location.hasRetail && location.hasEducation {
                        // Mixed retail + education: Custom annotation with both icons
                        Annotation(location.name, coordinate: location.coordinate) {
                            ZStack {
                                // Background circle
                                Circle()
                                    .fill(Color.purple)
                                    .frame(width: 36, height: 36)

                                // Both icons side-by-side
                                HStack(spacing: 2) {
                                    Image(systemName: "storefront.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.white)
                                    Image(systemName: "graduationcap.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .tag(location.stable_id)
                    } else if location.hasEducation {
                        // Education only: graduation cap icon
                        Marker(
                            location.name,
                            systemImage: "graduationcap.fill",
                            coordinate: location.coordinate
                        )
                        .tint(.green)
                        .tag(location.stable_id)
                    } else {
                        // Retail only: storefront icon
                        Marker(
                            location.name,
                            systemImage: "storefront.fill",
                            coordinate: location.coordinate
                        )
                        .tint(.orange)
                        .tag(location.stable_id)
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .onChange(of: mapSelection) { oldValue, newValue in
            // Update selected store when map marker is tapped
            if let stableId = newValue {
                viewModel.selectedStore = viewModel.filteredStores.first(where: { $0.stable_id == stableId })
            } else {
                viewModel.selectedStore = nil
            }
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            // Track visible region when map is panned/zoomed
            currentRegion = context.region
            viewModel.updateVisibleRegion(context.region)
        }
        .onAppear {
            // Set initial camera position to show all stores
            updateMapRegion()
        }
        .onChange(of: viewModel.filteredStores) { oldValue, newValue in
            // Update map region when filtered stores change
            updateMapRegion()
        }
        .onChange(of: viewModel.mapRecenterTrigger) { oldValue, newValue in
            // Center map on manual location when trigger changes (e.g., after zip code entry)
            if let manualLoc = viewModel.manualLocation {
                print("🗺️ StoreMapView: Recentering map to \(manualLoc.coordinate.latitude), \(manualLoc.coordinate.longitude)")
                position = .region(MKCoordinateRegion(
                    center: manualLoc.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                ))
            }
        }
        // Store detail callout overlay
        .overlay(alignment: .bottom) {
            if let selectedStore = viewModel.selectedStore {
                StoreMapCalloutView(
                    store: selectedStore,
                    userLocation: viewModel.effectiveLocation,
                    onClose: {
                        viewModel.selectedStore = nil
                        mapSelection = nil
                    },
                    onGetDirections: {
                        openInMaps(store: selectedStore)
                    }
                )
                .padding(DesignSystem.Spacing.md)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Helper Methods

    /// Update map camera to show all filtered stores
    private func updateMapRegion() {
        let stores = viewModel.filteredStores.filter { $0.hasValidLocation }

        guard !stores.isEmpty else {
            // Default to effective location or US if no stores
            if let effectiveCoord = viewModel.effectiveLocation?.coordinate {
                position = .region(MKCoordinateRegion(
                    center: effectiveCoord,
                    span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                ))
            }
            return
        }

        if stores.count == 1 {
            // Single store - center on it
            let store = stores[0]
            position = .region(MKCoordinateRegion(
                center: store.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            ))
        } else {
            // Multiple stores - fit all in view
            let coordinates = stores.map { $0.coordinate }
            let region = coordinateRegion(for: coordinates)
            position = .region(region)
        }
    }

    /// Calculate region that fits all coordinates
    private func coordinateRegion(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -95.4194), // US center
                span: MKCoordinateSpan(latitudeDelta: 40, longitudeDelta: 40)
            )
        }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        // Add padding around markers
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.1, (maxLat - minLat) * 1.3),
            longitudeDelta: max(0.1, (maxLon - minLon) * 1.3)
        )

        return MKCoordinateRegion(center: center, span: span)
    }

    /// Open store location in Apple Maps for turn-by-turn directions
    private func openInMaps(store: UnifiedLocationModel) {
        // iOS 26+ API: Use MKMapItem(location:address:) instead of MKPlacemark
        let location = CLLocation(latitude: store.coordinate.latitude, longitude: store.coordinate.longitude)
        let mapItem = MKMapItem(location: location, address: nil)
        mapItem.name = store.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

// MARK: - Store Map Callout View

/// Callout view shown when a store marker is selected
struct StoreMapCalloutView: View {
    let store: UnifiedLocationModel
    let userLocation: CLLocation?
    let onClose: () -> Void
    let onGetDirections: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Header with store name and close button
            HStack {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    // Show appropriate icon(s) based on capabilities
                    if store.hasRetail && store.hasEducation {
                        // Both icons for mixed locations
                        HStack(spacing: 2) {
                            Image(systemName: "storefront.fill")
                                .foregroundStyle(.orange)
                            Image(systemName: "graduationcap.fill")
                                .foregroundStyle(.green)
                        }
                    } else if store.hasEducation {
                        Image(systemName: "graduationcap.fill")
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "storefront.fill")
                            .foregroundStyle(.orange)
                    }

                    Text(store.name)
                        .font(.headline)
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
            }

            // Address
            if let address = store.fullAddress {
                Text(address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Distance (if user location available)
            if let userLoc = userLocation,
               let formattedDistance = store.formattedDistance(from: userLoc.coordinate) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                    Text(formattedDistance)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }

            // Action buttons
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Get Directions button
                Button(action: onGetDirections) {
                    Label("Directions", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)

                // Phone button (if available)
                if let phone = store.phone {
                    Button(action: {
                        if let url = URL(string: "tel://\(phone.filter { $0.isNumber })") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Image(systemName: "phone.fill")
                    }
                    .buttonStyle(.bordered)
                }

                // Website button (if available)
                if let websiteUrl = store.websiteUrl,
                   let url = URL(string: websiteUrl) {
                    Button(action: {
                        UIApplication.shared.open(url)
                    }) {
                        Image(systemName: "safari.fill")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(DesignSystem.Padding.standard)
        .background(.regularMaterial)
        .cornerRadius(DesignSystem.CornerRadius.large)
        .shadow(radius: 8)
    }
}

// MARK: - Previews

#Preview("Map with Multiple Stores") {
    StoreMapView(viewModel: StoreListViewModel())
}

#Preview("Map Callout") {
    let store = UnifiedLocationModel(
        stable_id: "frantz-art-glass",
        name: "Frantz Art Glass",
        addressLine1: "205 E Alma Ave",
        addressLine2: nil,
        city: "San Jose",
        state: "CA",
        zip: "95112",
        latitude: 37.3184323,
        longitude: -121.8710054,
        websiteUrl: "https://frantzartglass.com",
        phone: "(408) 287-6200",
        hoursJson: nil,
        heroImagePath: nil,
        notes: nil,
        isVerified: true,
        retailCapabilities: [RetailCapability(technique: .glassBlowing)]
    )

    let userLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)

    StoreMapCalloutView(
        store: store,
        userLocation: userLocation,
        onClose: {},
        onGetDirections: {}
    )
    .padding()
}

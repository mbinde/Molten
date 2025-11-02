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

    // Default parameter evaluated once per view instance
    init(viewModel: LocationsViewModel = LocationsViewModel(
        locationService: RepositoryFactory.createUnifiedLocationService()
    )) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter chips
                filterChipsView
                    .padding(.horizontal, DesignSystem.Padding.standard)
                    .padding(.vertical, DesignSystem.Padding.compact)

                // Search bar
                searchBarView
                    .padding(.horizontal, DesignSystem.Padding.standard)
                    .padding(.bottom, DesignSystem.Padding.compact)

                // Map view (toggleable)
                if viewModel.showMap {
                    mapView
                        .frame(height: 250)
                }

                // List view
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.isEmpty {
                    emptyStateView
                } else {
                    listView
                }
            }
            .navigationTitle("Locations")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.toggleMap()
                    } label: {
                        Image(systemName: viewModel.showMap ? "map.fill" : "map")
                    }
                }
            }
            .task {
                await viewModel.loadLocations()
            }
        }
    }

    // MARK: - Filter Chips

    private var filterChipsView: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(LocationType.allCases) { type in
                filterChip(for: type)
            }
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

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.updateSearchText("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }
        }
        .padding(DesignSystem.Padding.compact)
        .background(DesignSystem.Colors.backgroundSecondary)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }

    // MARK: - Map View

    private var mapView: some View {
        Map {
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
        }
        .mapStyle(.standard)
    }

    // MARK: - Helper Methods

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
        VStack(spacing: DesignSystem.Spacing.lg) {
            ProgressView()
            Text("Loading locations...")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundStyle(DesignSystem.Colors.textTertiary)

            Text(viewModel.emptyStateMessage)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Padding.generous)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    LocationsView()
}

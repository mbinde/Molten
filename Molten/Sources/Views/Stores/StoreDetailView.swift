//
//  StoreDetailView.swift
//  Molten
//
//  Created for Store Feature on 10/26/25.
//

import SwiftUI
import MapKit

struct StoreDetailView: View {
    let store: StoreModel
    let storeService: StoreService

    @State private var region: MKCoordinateRegion
    @State private var showingDirections = false
    @Environment(\.openURL) private var openURL

    init(store: StoreModel, storeService: StoreService) {
        self.store = store
        self.storeService = storeService

        // Initialize map region centered on store
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: store.latitude ?? 0,
                longitude: store.longitude ?? 0
            ),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Map (if location available)
                if store.hasValidLocation {
                    mapView
                }

                // Store info
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    // Header with name and verification
                    headerSection

                    Divider()

                    // Contact info
                    contactSection

                    // Address
                    if let address = store.fullAddress {
                        Divider()
                        addressSection(address)
                    }

                    // Notes
                    if let notes = store.notes, !notes.isEmpty {
                        Divider()
                        notesSection(notes)
                    }

                    // Action buttons
                    Divider()
                    actionButtons
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.xl)
            }
        }
        .navigationTitle(store.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Subviews

    private var mapView: some View {
        Map(coordinateRegion: $region, annotationItems: [store]) { store in
            MapMarker(
                coordinate: CLLocationCoordinate2D(
                    latitude: store.latitude ?? 0,
                    longitude: store.longitude ?? 0
                ),
                tint: .accentColor
            )
        }
        .frame(height: 200)
        .cornerRadius(DesignSystem.CornerRadius.large)
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .onTapGesture {
            openInMaps()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text(store.name)
                    .font(.title2)
                    .fontWeight(.bold)

                if store.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }

            if store.isVerified {
                Label("Verified Store", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Contact")
                .font(.headline)

            // Phone
            if let phone = store.phone {
                Button(action: { callPhone(phone) }) {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "phone.fill")
                            .frame(width: 24)
                            .foregroundStyle(Color.accentColor)

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Phone")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(phone)
                                .font(.body)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }

            // Website
            if let websiteUrl = store.websiteUrl, let url = URL(string: websiteUrl) {
                Button(action: { openURL(url) }) {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "globe")
                            .frame(width: 24)
                            .foregroundStyle(Color.accentColor)

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Website")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(websiteUrl)
                                .font(.body)
                                .lineLimit(1)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func addressSection(_ address: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Address")
                .font(.headline)

            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "mappin.and.ellipse")
                    .frame(width: 24)
                    .foregroundStyle(Color.accentColor)

                Text(address)
                    .font(.body)

                Spacer()
            }
        }
    }

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Notes")
                .font(.headline)

            Text(notes)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Get Directions button
            if store.hasValidLocation {
                Button(action: openInMaps) {
                    Label("Get Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                }
            }

            // Share button
            ShareLink(item: shareText) {
                Label("Share Store", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .foregroundStyle(.primary)
                    .cornerRadius(DesignSystem.CornerRadius.medium)
            }
        }
    }

    // MARK: - Computed Properties

    private var shareText: String {
        var text = store.name
        if let address = store.fullAddress {
            text += "\n\(address)"
        }
        if let phone = store.phone {
            text += "\nPhone: \(phone)"
        }
        if let website = store.websiteUrl {
            text += "\n\(website)"
        }
        return text
    }

    // MARK: - Methods

    private func openInMaps() {
        guard store.hasValidLocation else { return }

        let coordinate = CLLocationCoordinate2D(
            latitude: store.latitude ?? 0,
            longitude: store.longitude ?? 0
        )

        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = store.name

        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private func callPhone(_ phoneNumber: String) {
        // Remove formatting characters
        let cleaned = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()

        if let url = URL(string: "tel://\(cleaned)") {
            openURL(url)
        }
    }
}

#Preview("Store with Full Info") {
    NavigationStack {
        StoreDetailView(
            store: StoreModel(
                stable_id: "preview-1",
                name: "Frantz Art Glass",
                addressLine1: "1222 1st Ave W",
                city: "Seattle",
                state: "WA",
                zip: "98119",
                latitude: 47.6362,
                longitude: -122.3598,
                websiteUrl: "https://frantzartglass.com",
                phone: "(206) 284-5600",
                notes: "Full-service glass art supplier with extensive inventory of rods, frits, and tools.",
                isVerified: true
            ),
            storeService: RepositoryFactory.createStoreService()
        )
    }
}

#Preview("Store with Minimal Info") {
    NavigationStack {
        StoreDetailView(
            store: StoreModel(
                stable_id: "preview-2",
                name: "Local Glass Shop",
                city: "Portland",
                state: "OR",
                isVerified: false
            ),
            storeService: RepositoryFactory.createStoreService()
        )
    }
}

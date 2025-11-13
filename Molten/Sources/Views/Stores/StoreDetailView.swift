//
//  StoreDetailView.swift
//  Molten
//
//  Created for Store Feature on 10/26/25.
//

import SwiftUI
import MapKit

struct StoreDetailView: View {
    let store: UnifiedLocationModel
    let locationService: UnifiedLocationService
    let shoppingListService: ShoppingListService

    @State private var region: MKCoordinateRegion
    @State private var showingDirections = false
    @State private var hasShoppingListItems = false
    @State private var shoppingListItemCount = 0
    @Environment(\.openURL) private var openURL

    init(store: UnifiedLocationModel,
         locationService: UnifiedLocationService,
         shoppingListService: ShoppingListService) {
        self.store = store
        self.locationService = locationService
        self.shoppingListService = shoppingListService

        // Initialize map region centered on store
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: store.latitude,
                longitude: store.longitude
            ),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }

    /// Convenience init using AppDependencies
    init(store: UnifiedLocationModel, deps: AppDependencies = AppDependencies()) {
        self.store = store
        self.locationService = deps.unifiedLocationService
        self.shoppingListService = deps.shoppingListService

        // Initialize map region centered on store
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: store.latitude,
                longitude: store.longitude
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

                    // Techniques
                    if !store.retailTechniques.isEmpty {
                        Divider()
                        techniquesSection
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
        .task {
            await checkForShoppingListItems()
        }
    }

    // MARK: - Subviews

    private var mapView: some View {
        Map(coordinateRegion: $region, annotationItems: [store]) { store in
            MapMarker(
                coordinate: CLLocationCoordinate2D(
                    latitude: store.latitude,
                    longitude: store.longitude
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
            Text(store.name)
                .font(.title2)
                .fontWeight(.bold)
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

    private var techniquesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Techniques Supported")
                .font(.headline)

            // Wrapping layout for technique chips
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 100), spacing: DesignSystem.Spacing.sm)],
                alignment: .leading,
                spacing: DesignSystem.Spacing.sm
            ) {
                ForEach(store.retailTechniques, id: \.self) { technique in
                    Text(technique.displayName)
                        .font(.caption)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.2))
                        .foregroundStyle(Color.accentColor)
                        .cornerRadius(DesignSystem.CornerRadius.small)
                }
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // View Shopping List button (if items exist)
            if hasShoppingListItems {
                Button(action: navigateToShoppingList) {
                    HStack {
                        Label("View Shopping List", systemImage: "cart.fill")
                        Spacer()
                        Text("\(shoppingListItemCount)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.3))
                            .cornerRadius(DesignSystem.CornerRadius.small)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .cornerRadius(DesignSystem.CornerRadius.medium)
                }
            }

            // Get Directions button
            if store.hasValidLocation {
                Button(action: openInMaps) {
                    Label("Get Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(hasShoppingListItems ? Color(.systemGray6) : Color.accentColor)
                        .foregroundStyle(hasShoppingListItems ? .primary : Color.white)
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                }
            }

            // Share button
            if let mapsURL = shareMapsURL {
                ShareLink(item: mapsURL) {
                    Label("Share Store", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .foregroundStyle(.primary)
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                }
            }
        }
    }

    // MARK: - Computed Properties

    /// Creates an Apple Maps URL that will show as a beautiful map card in Messages
    private var shareMapsURL: URL? {
        guard store.hasValidLocation else { return nil }

        // URL encode the store name for the query parameter
        let storeName = store.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? store.name

        // Create Apple Maps URL with store name and coordinates
        // Format: https://maps.apple.com/?q=Store+Name&ll=latitude,longitude
        let urlString = "https://maps.apple.com/?q=\(storeName)&ll=\(store.latitude),\(store.longitude)"

        return URL(string: urlString)
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

    private func checkForShoppingListItems() async {
        do {
            // Fetch items for this store from shopping list
            let items = try await shoppingListService.shoppingListRepository.fetchItems(forStore: store.name)
            await MainActor.run {
                hasShoppingListItems = !items.isEmpty
                shoppingListItemCount = items.count
            }
        } catch {
            print("❌ Error checking for shopping list items: \(error)")
            await MainActor.run {
                hasShoppingListItems = false
                shoppingListItemCount = 0
            }
        }
    }

    private func navigateToShoppingList() {
        // Post notification to switch to shopping tab and filter by this store
        NotificationCenter.default.post(
            name: .navigateToShoppingListForStore,
            object: nil,
            userInfo: ["storeName": store.name]
        )
    }
}

#Preview("Store with Full Info") {
    let deps = AppDependencies(persistenceController: .createTestController())
    NavigationStack {
        StoreDetailView(
            store: UnifiedLocationModel(
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
                isVerified: true,
                retailCapabilities: [
                    RetailCapability(technique: .casting),
                    RetailCapability(technique: .flameworkinghard),
                    RetailCapability(technique: .flameworkingsoft),
                    RetailCapability(technique: .fusing),
                    RetailCapability(technique: .glassBlowing)
                ]
            ),
            deps: deps
        )
    }
}

#Preview("Store with Minimal Info") {
    let deps = AppDependencies(persistenceController: .createTestController())
    NavigationStack {
        StoreDetailView(
            store: UnifiedLocationModel(
                stable_id: "preview-2",
                name: "Local Glass Shop",
                city: "Portland",
                state: "OR",
                isVerified: false,
                retailCapabilities: [
                    RetailCapability(technique: .fusing),
                    RetailCapability(technique: .stainedGlass)
                ]
            ),
            deps: deps
        )
    }
}

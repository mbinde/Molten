//
//  StoreRowView.swift
//  Molten
//
//  Created for Store Feature on 10/26/25.
//

import SwiftUI
import CoreLocation

struct StoreRowView: View {
    let store: UnifiedLocationModel
    let userLocation: CLLocationCoordinate2D?
    var showDistance: Bool = true

    var body: some View {
        ListRowContainer(
            leading: {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: "storefront")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.accentColor)
                }
            },
            header: {
                Text(store.name)
                    .font(DesignSystem.Typography.rowTitle)
                    .foregroundStyle(.primary)
            },
            details: {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    // Address
                    if let address = store.compactAddress {
                        Text(address)
                            .font(DesignSystem.Typography.label)
                            .foregroundStyle(.secondary)
                    }

                    // Distance (if available)
                    if showDistance, let userLocation = userLocation, let distance = store.distance(from: userLocation) {
                        IconTextBadge.location(store.formattedDistance(from: userLocation) ?? "")
                    }

                    // Phone (if available)
                    if let phone = store.phone {
                        IconTextBadge.phone(phone)
                    }
                }
            },
            trailing: {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            },
            spacing: DesignSystem.Spacing.xs,
            verticalPadding: DesignSystem.Padding.rowVertical
        )
    }
}

#Preview("Basic Store") {
    List {
        StoreRowView(
            store: UnifiedLocationModel(
                stable_id: "preview-1",
                name: "Glass Art Supply",
                addressLine1: "123 Main St",
                city: "Seattle",
                state: "WA",
                zip: "98101",
                latitude: 47.6062,
                longitude: -122.3321,
                phone: "(206) 555-1234",
                isVerified: false,
                retailCapabilities: []
            ),
            userLocation: nil,
            showDistance: false
        )
    }
}

#Preview("Verified Store with Distance") {
    List {
        StoreRowView(
            store: UnifiedLocationModel(
                stable_id: "preview-2",
                name: "Frantz Art Glass",
                addressLine1: "1222 1st Ave W",
                city: "Seattle",
                state: "WA",
                zip: "98119",
                latitude: 47.6362,
                longitude: -122.3598,
                phone: "(206) 284-5600",
                isVerified: true,
                retailCapabilities: [RetailCapability(technique: .glassBlowing)]
            ),
            userLocation: CLLocationCoordinate2D(latitude: 47.6062, longitude: -122.3321),
            showDistance: true
        )
    }
}

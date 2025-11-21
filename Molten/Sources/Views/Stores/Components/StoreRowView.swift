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
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            // Store icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: "storefront")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }

            // Store info
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                // Store name
                Text(store.name)
                    .font(DesignSystem.Typography.rowTitle)
                    .foregroundStyle(.primary)

                // Address
                if let address = store.compactAddress {
                    Text(address)
                        .font(DesignSystem.Typography.label)
                        .foregroundStyle(.secondary)
                }

                // Distance (if available)
                if showDistance, let userLocation = userLocation, let _ = store.distance(from: userLocation) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                        Text(store.formattedDistance(from: userLocation) ?? "")
                            .font(DesignSystem.Typography.caption)
                    }
                    .foregroundStyle(.secondary)
                }

                // Phone (if available)
                if let phone = store.phone {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "phone.fill")
                            .font(.caption)
                        Text(phone)
                            .font(DesignSystem.Typography.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, DesignSystem.Padding.rowVertical)
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

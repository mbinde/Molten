//
//  LocationRow.swift
//  Molten
//
//  Created for unified Locations feature on 11/1/25.
//

import SwiftUI
import CoreLocation

/// Reusable row component for displaying any location (store, class, workshop)
struct LocationRow: View {
    let location: AnyLocationModel
    let userLocation: CLLocationCoordinate2D?

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            // Type icon
            location.type.icon
                .font(.title2)
                .foregroundStyle(DesignSystem.Colors.accentPrimary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                // Name with verification badge
                Text(location.displayName)
                    .font(DesignSystem.Typography.rowTitle)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                // Address (compact)
                if let address = location.compactAddress {
                    Text(address)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                // Distance (if user location available)
                if let userLoc = userLocation,
                   let distance = location.formattedDistance(from: userLoc) {
                    Text(distance)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                // Techniques
                if !location.techniques.isEmpty {
                    Text(location.techniquesDisplay)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
        .padding(.vertical, DesignSystem.Padding.rowVertical)
    }
}

#Preview("Store") {
    List {
        LocationRow(
            location: AnyLocationModel(store: StoreModel.create(
                name: "Frantz Art Glass",
                city: "Shelton",
                state: "WA",
                latitude: 47.2,
                longitude: -123.1,
                isVerified: true,
                techniques: [.fusing, .casting]
            )),
            userLocation: CLLocationCoordinate2D(latitude: 47.6, longitude: -122.3)
        )
    }
}

#Preview("Class") {
    List {
        LocationRow(
            location: AnyLocationModel(classLocation: ClassLocationModel.create(
                name: "Pilchuck Glass School",
                city: "Stanwood",
                state: "WA",
                latitude: 48.2,
                longitude: -122.4,
                isVerified: true,
                techniques: [.glassBlowing, .fusing, .casting]
            )),
            userLocation: nil
        )
    }
}

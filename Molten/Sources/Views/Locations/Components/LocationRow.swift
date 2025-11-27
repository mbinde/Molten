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
        ListRowContainer(
            leading: {
                iconView
                    .font(.title2)
                    .frame(width: 32)
            },
            header: {
                Text(location.displayName)
                    .font(DesignSystem.Typography.listItemTitle)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            },
            details: {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    // Address (compact)
                    if let address = location.compactAddress {
                        Text(address)
                            .font(DesignSystem.Typography.listItemCaption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }

                    // Techniques
                    if !location.techniques.isEmpty {
                        Text(location.techniquesDisplay)
                            .font(DesignSystem.Typography.listItemCaption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }
            },
            trailing: {
                // Distance badge (if user location available)
                if let userLoc = userLocation,
                   let distance = location.formattedDistance(from: userLoc) {
                    Text(distance)
                        .font(DesignSystem.Typography.prominentNumberSmall)
                        .fontWeight(.medium)
                        .foregroundStyle(DesignSystem.Colors.moltenTeal)
                }
            },
            spacing: DesignSystem.Spacing.xs,
            verticalPadding: DesignSystem.Padding.rowVertical
        )
    }

    // MARK: - Icon View

    @ViewBuilder
    private var iconView: some View {
        ZStack {
            // Outer colored ring
            Circle()
                .stroke(Color.black, lineWidth: 2.5)
                .frame(width: 32, height: 32)

            // Orange background circle
            Circle()
                .fill(DesignSystem.Colors.moltenOrange)
                .frame(width: 26, height: 26)

            // White icon(s)
            iconImage
                .font(.caption)
                .foregroundStyle(.white)
        }
    }

    /// Icon image based on capabilities
    @ViewBuilder
    private var iconImage: some View {
        if location.hasRetail && location.hasEducation {
            // Both icons for mixed locations
            HStack(spacing: 1) {
                Image(systemName: "storefront.fill")
                    .font(.caption2)
                Image(systemName: "graduationcap.fill")
                    .font(.caption2)
            }
        } else if location.hasEducation {
            Image(systemName: "graduationcap.fill")
        } else {
            Image(systemName: "storefront.fill")
        }
    }
}

#Preview("Store") {
    List {
        LocationRow(
            location: AnyLocationModel(unified: UnifiedLocationModel(
                stable_id: "frantz-art-glass",
                name: "Frantz Art Glass",
                city: "Shelton",
                state: "WA",
                latitude: 47.2,
                longitude: -123.1,
                isVerified: true,
                retailCapabilities: [
                    RetailCapability(technique: .fusing),
                    RetailCapability(technique: .casting)
                ]
            )),
            userLocation: CLLocationCoordinate2D(latitude: 47.6, longitude: -122.3)
        )
    }
}

#Preview("Class") {
    List {
        LocationRow(
            location: AnyLocationModel(unified: UnifiedLocationModel(
                stable_id: "pilchuck-glass-school",
                name: "Pilchuck Glass School",
                city: "Stanwood",
                state: "WA",
                latitude: 48.2,
                longitude: -122.4,
                isVerified: true,
                educationCapabilities: [
                    EducationCapability(technique: .glassBlowing),
                    EducationCapability(technique: .fusing),
                    EducationCapability(technique: .casting)
                ]
            )),
            userLocation: nil
        )
    }
}

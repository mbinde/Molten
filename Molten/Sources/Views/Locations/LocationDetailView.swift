//
//  LocationDetailView.swift
//  Molten
//
//  Created for unified Locations feature on 11/1/25.
//

import SwiftUI
import MapKit

/// Shared detail view for any location type (store, class, workshop)
struct LocationDetailView: View {
    let location: AnyLocationModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                // Hero image (if available)
                if let imagePath = location.heroImagePath {
                    heroImageView(imagePath: imagePath)
                }

                // Main info section
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    // Type badge
                    typeBadge

                    // Name
                    Text(location.displayName)
                        .font(DesignSystem.Typography.sectionTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    // Contact info card
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        // Address
                        if let fullAddress = location.fullAddress {
                            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.body)
                                    .foregroundStyle(DesignSystem.Colors.moltenOrange)
                                    .frame(width: 24)
                                Text(fullAddress)
                                    .font(DesignSystem.Typography.listItemSubtitle)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                            }
                        }

                        // Phone
                        if let phone = location.formattedPhone {
                            Link(destination: URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))")!) {
                                HStack(spacing: DesignSystem.Spacing.md) {
                                    Image(systemName: "phone.fill")
                                        .font(.body)
                                        .foregroundStyle(DesignSystem.Colors.moltenTeal)
                                        .frame(width: 24)
                                    Text(phone)
                                        .font(DesignSystem.Typography.listItemSubtitle)
                                        .foregroundStyle(DesignSystem.Colors.moltenTeal)
                                }
                            }
                            .accessibilityIdentifier("location_detail_phone")
                        }

                        // Website
                        if let websiteUrl = location.websiteUrl,
                           let url = URL(string: websiteUrl) {
                            Link(destination: url) {
                                HStack(spacing: DesignSystem.Spacing.md) {
                                    Image(systemName: "globe")
                                        .font(.body)
                                        .foregroundStyle(DesignSystem.Colors.moltenTeal)
                                        .frame(width: 24)
                                    Text(extractDomain(from: websiteUrl))
                                        .font(DesignSystem.Typography.listItemSubtitle)
                                        .foregroundStyle(DesignSystem.Colors.moltenTeal)
                                        .lineLimit(1)
                                }
                            }
                            .accessibilityIdentifier("location_detail_website")
                        }
                    }
                    .padding(DesignSystem.Padding.standard)
                    .background(DesignSystem.Colors.backgroundSecondary)
                    .cornerRadius(DesignSystem.CornerRadius.medium)
                }
                .padding(.horizontal, DesignSystem.Padding.standard)

                // Techniques section
                if !location.techniques.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("Techniques Offered")
                            .font(DesignSystem.Typography.subsectionTitle)
                            .fontWeight(.semibold)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)

                        FlowLayout(spacing: DesignSystem.Spacing.sm) {
                            ForEach(location.techniques, id: \.self) { technique in
                                HStack(spacing: DesignSystem.Spacing.xs) {
                                    Image(systemName: "flame.fill")
                                        .font(.caption2)
                                        .foregroundStyle(DesignSystem.Colors.moltenOrange)
                                    Text(technique.displayName)
                                        .font(DesignSystem.Typography.listItemCaption)
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                                }
                                .padding(.horizontal, DesignSystem.Padding.standard)
                                .padding(.vertical, DesignSystem.Padding.compact)
                                .background(DesignSystem.Colors.tintPrimary)
                                .cornerRadius(DesignSystem.CornerRadius.medium)
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Padding.standard)
                }

                // Map
                if location.hasValidLocation {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("Location")
                            .font(DesignSystem.Typography.subsectionTitle)
                            .fontWeight(.semibold)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .padding(.horizontal, DesignSystem.Padding.standard)

                        Map(position: .constant(.region(MKCoordinateRegion(
                            center: location.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                        )))) {
                            Annotation(location.name, coordinate: location.coordinate) {
                                ZStack {
                                    // Outer ring
                                    Circle()
                                        .stroke(Color.black, lineWidth: 3)
                                        .frame(width: 44, height: 44)

                                    // Orange fill
                                    Circle()
                                        .fill(DesignSystem.Colors.moltenOrange)
                                        .frame(width: 38, height: 38)

                                    location.type.icon
                                        .font(.body)
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .frame(height: 200)
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                        .padding(.horizontal, DesignSystem.Padding.standard)

                        // Get Directions button
                        Button(action: openDirections) {
                            HStack(spacing: DesignSystem.Spacing.md) {
                                Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                                    .font(.title3)
                                Text("Get Directions")
                                    .font(DesignSystem.Typography.listItemTitle)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Padding.standard)
                            .background(DesignSystem.Colors.moltenOrange)
                            .cornerRadius(DesignSystem.CornerRadius.large)
                        }
                        .padding(.horizontal, DesignSystem.Padding.standard)
                        .accessibilityIdentifier("location_detail_directions")

                        // Suggest change link below map
                        HStack {
                            Spacer()
                            Button {
                                if let url = URL(string: "https://moltenglass.app/submit-store/") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Text("Suggest a Change or Deletion")
                                    .font(DesignSystem.Typography.listItemCaptionSmall)
                                    .foregroundStyle(DesignSystem.Colors.moltenTeal)
                            }
                            .padding(.trailing, DesignSystem.Padding.standard)
                            .accessibilityIdentifier("location_detail_suggest_change")
                        }
                        .padding(.top, DesignSystem.Spacing.xs)
                    }
                }

                // Notes
                if let notes = location.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("Notes")
                            .font(DesignSystem.Typography.subsectionTitle)
                            .fontWeight(.semibold)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)

                        Text(notes)
                            .font(DesignSystem.Typography.listItemSubtitle)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.horizontal, DesignSystem.Padding.standard)
                }
            }
            .padding(.vertical, DesignSystem.Padding.standard)
        }
        .navigationTitle(location.type.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    /// Extract domain from URL for cleaner display
    private func extractDomain(from urlString: String) -> String {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return urlString
        }
        // Remove www. prefix if present
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    // MARK: - Actions

    private func openDirections() {
        guard location.hasValidLocation else { return }

        let coordinate = location.coordinate
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = location.name

        // Open in Apple Maps with directions
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    // MARK: - Subviews

    private var typeBadge: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            location.type.icon
                .font(.caption)
            Text(location.type.displayName.uppercased())
                .font(DesignSystem.Typography.listItemCaptionSmall)
                .fontWeight(.bold)
                .tracking(0.5)
        }
        .padding(.horizontal, DesignSystem.Padding.standard)
        .padding(.vertical, DesignSystem.Padding.compact)
        .background(DesignSystem.Colors.moltenOrange)
        .foregroundStyle(.white)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }

    private func heroImageView(imagePath: String) -> some View {
        AsyncImage(url: URL(string: imagePath)) { phase in
            switch phase {
            case .empty:
                Rectangle()
                    .fill(DesignSystem.Colors.backgroundSecondary)
                    .frame(height: 200)
                    .overlay {
                        ProgressView()
                    }
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
            case .failure:
                Rectangle()
                    .fill(DesignSystem.Colors.backgroundSecondary)
                    .frame(height: 200)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
            @unknown default:
                EmptyView()
            }
        }
    }
}

// FlowLayout is now in Molten/Sources/Views/Shared/Layouts/FlowLayout.swift

#Preview {
    NavigationStack {
        LocationDetailView(
            location: AnyLocationModel(unified: UnifiedLocationModel(
                stable_id: "frantz-art-glass",
                name: "Frantz Art Glass",
                addressLine1: "123 Main St",
                city: "Shelton",
                state: "WA",
                zip: "98584",
                latitude: 47.2,
                longitude: -123.1,
                websiteUrl: "https://frantzartglass.com",
                phone: "3605551234",
                notes: "Family-owned glass supply shop with over 40 years of experience.",
                isVerified: true,
                retailCapabilities: [
                    RetailCapability(technique: .fusing),
                    RetailCapability(technique: .casting),
                    RetailCapability(technique: .stainedGlass)
                ]
            ))
        )
    }
}

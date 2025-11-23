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
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    // Type badge
                    typeBadge

                    // Name
                    Text(location.displayName)
                        .font(.title)
                        .fontWeight(.bold)

                    // Address
                    if let fullAddress = location.fullAddress {
                        Label {
                            Text(fullAddress)
                                .font(DesignSystem.Typography.body)
                        } icon: {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(DesignSystem.Colors.accentPrimary)
                        }
                    }

                    // Phone
                    if let phone = location.formattedPhone {
                        Link(destination: URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))")!) {
                            Label {
                                Text(phone)
                                    .font(DesignSystem.Typography.body)
                            } icon: {
                                Image(systemName: "phone.fill")
                                    .foregroundStyle(DesignSystem.Colors.accentPrimary)
                            }
                        }
                    }

                    // Website
                    if let websiteUrl = location.websiteUrl,
                       let url = URL(string: websiteUrl) {
                        Link(destination: url) {
                            Label {
                                Text(websiteUrl)
                                    .font(DesignSystem.Typography.body)
                                    .lineLimit(1)
                            } icon: {
                                Image(systemName: "link")
                                    .foregroundStyle(DesignSystem.Colors.accentPrimary)
                            }
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Padding.standard)

                // Techniques section
                if !location.techniques.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("Techniques Offered")
                            .font(DesignSystem.Typography.sectionHeader)
                            .fontWeight(.semibold)

                        FlowLayout(spacing: DesignSystem.Spacing.sm) {
                            ForEach(location.techniques, id: \.self) { technique in
                                Text(technique.displayName)
                                    .font(DesignSystem.Typography.caption)
                                    .padding(.horizontal, DesignSystem.Padding.standard)
                                    .padding(.vertical, DesignSystem.Padding.compact)
                                    .background(DesignSystem.Colors.backgroundSecondary)
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
                            .font(DesignSystem.Typography.sectionHeader)
                            .fontWeight(.semibold)
                            .padding(.horizontal, DesignSystem.Padding.standard)

                        Map(position: .constant(.region(MKCoordinateRegion(
                            center: location.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                        )))) {
                            Annotation(location.name, coordinate: location.coordinate) {
                                ZStack {
                                    Circle()
                                        .fill(DesignSystem.Colors.accentPrimary)
                                        .frame(width: 40, height: 40)

                                    location.type.icon
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .frame(height: 200)
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                        .padding(.horizontal, DesignSystem.Padding.standard)

                        // Get Directions button
                        Button(action: openDirections) {
                            Label("Get Directions", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(DesignSystem.Colors.accentSecondary)
                                .cornerRadius(DesignSystem.CornerRadius.large)
                        }
                        .padding(.horizontal, DesignSystem.Padding.standard)

                        // Suggest change link below map
                        HStack {
                            Spacer()
                            Button {
                                if let url = URL(string: "https://moltenglass.app/submit-store/") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Text("Suggest a Change or Deletion")
                                    .font(.caption)
                                    .foregroundStyle(Color.accentColor)
                            }
                            .padding(.trailing, DesignSystem.Padding.standard)
                        }
                        .padding(.top, 4)
                    }
                }

                // Notes
                if let notes = location.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("Notes")
                            .font(DesignSystem.Typography.sectionHeader)
                            .fontWeight(.semibold)

                        Text(notes)
                            .font(DesignSystem.Typography.body)
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

    // MARK: - Actions

    private func openDirections() {
        guard location.hasValidLocation else { return }

        // iOS 26+ API: Use MKMapItem(location:address:) instead of MKPlacemark
        let coordinate = location.coordinate
        let clLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let mapItem = MKMapItem(location: clLocation, address: nil)
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
                .font(.caption2)
            Text(location.type.displayName.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, DesignSystem.Padding.compact)
        .padding(.vertical, DesignSystem.Padding.chipVertical)
        .background(DesignSystem.Colors.accentPrimary.opacity(0.1))
        .foregroundStyle(DesignSystem.Colors.accentPrimary)
        .cornerRadius(DesignSystem.CornerRadius.small)
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

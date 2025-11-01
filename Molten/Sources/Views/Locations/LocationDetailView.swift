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

                        Map {
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
        .navigationTitle(location.type.singularName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Subviews

    private var typeBadge: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            location.type.icon
                .font(.caption2)
            Text(location.type.singularName.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, DesignSystem.Padding.compact)
        .padding(.vertical, DesignSystem.Padding.xs)
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

// MARK: - FlowLayout Helper

/// Simple flow layout for technique chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

#Preview {
    NavigationStack {
        LocationDetailView(
            location: AnyLocationModel(store: StoreModel.create(
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
                techniques: [.fusing, .casting, .stainedGlass]
            ))
        )
    }
}

//
//  GlassItemCard.swift
//  Flameworker
//
//  Reusable glass item card component with large and compact variants
//

import SwiftUI

/// Reusable glass item card component for displaying glass item information
/// Available in two sizes: large (detail header) and compact (editor/list)
struct GlassItemCard: View {
    let item: GlassItemModel
    let variant: Variant

    enum Variant {
        /// Large variant with full details, used in detail views
        case large
        /// Compact variant with minimal info, used in editors and lists
        case compact
    }

    var body: some View {
        HStack(alignment: .top, spacing: variant.spacing) {
            // Product image using SKU
            ProductImageDetail(
                itemCode: item.sku,
                manufacturer: item.manufacturer,
                maxSize: variant.imageSize
            )

            // Item information
            VStack(alignment: .leading, spacing: variant.contentSpacing) {
                if variant == .compact {
                    // Compact header: manufacturer badge
                    Text(item.manufacturer.uppercased())
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.semibold)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                // Item name
                Text(item.name)
                    .font(variant.titleFont)
                    .fontWeight(variant.titleWeight)

                // Details section
                detailsSection

                // Manufacturer link (large variant only)
                if variant == .large {
                    manufacturerLink
                }
            }

            Spacer()
        }
        .padding(variant.padding)
        .background(variant.background)
        .clipShape(RoundedRectangle(cornerRadius: variant.cornerRadius))
    }

    // MARK: - Details Section

    @ViewBuilder
    private var detailsSection: some View {
        switch variant {
        case .large:
            // Large variant: show SKU, COE, and Status in detail rows
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                detailRow(title: "SKU", value: item.sku)
                detailRow(title: "COE", value: "\(item.coe)")
                detailRow(title: "Status", value: item.mfr_status.capitalized)
            }

        case .compact:
            // Compact variant: show SKU only
            Text("SKU: \(item.sku)")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }

    // MARK: - Manufacturer Link

    @ViewBuilder
    private var manufacturerLink: some View {
        if let urlString = item.url, !urlString.isEmpty, let url = URL(string: urlString) {
            let manufacturerDisplayName = GlassManufacturers.fullName(for: item.manufacturer) ?? "Manufacturer Website"

            Link(destination: url) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "link")
                        .font(DesignSystem.Typography.caption)
                    Text(manufacturerDisplayName)
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.medium)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(DesignSystem.Typography.captionSmall)
                }
                .foregroundColor(DesignSystem.Colors.accentPrimary)
            }
        }
    }

    // MARK: - Helper Methods

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(DesignSystem.Typography.caption)
                .fontWeight(DesignSystem.FontWeight.medium)
        }
    }
}

// MARK: - Variant Configuration

extension GlassItemCard.Variant {
    /// Image size for the variant
    var imageSize: CGFloat {
        switch self {
        case .large: return 120
        case .compact: return 60
        }
    }

    /// Spacing between image and content
    var spacing: CGFloat {
        switch self {
        case .large: return DesignSystem.Spacing.xl
        case .compact: return DesignSystem.Spacing.lg
        }
    }

    /// Spacing within content
    var contentSpacing: CGFloat {
        switch self {
        case .large: return DesignSystem.Spacing.md
        case .compact: return DesignSystem.Spacing.xs
        }
    }

    /// Title font
    var titleFont: Font {
        switch self {
        case .large: return DesignSystem.Typography.sectionHeader
        case .compact: return DesignSystem.Typography.rowTitle
        }
    }

    /// Title weight
    var titleWeight: Font.Weight {
        switch self {
        case .large: return DesignSystem.FontWeight.bold
        case .compact: return DesignSystem.FontWeight.semibold
        }
    }

    /// Card padding
    var padding: EdgeInsets {
        switch self {
        case .large:
            return EdgeInsets(
                top: DesignSystem.Padding.rowVertical,
                leading: 0,
                bottom: DesignSystem.Padding.rowVertical,
                trailing: 0
            )
        case .compact:
            return EdgeInsets(
                top: DesignSystem.Padding.standard,
                leading: DesignSystem.Padding.standard,
                bottom: DesignSystem.Padding.standard,
                trailing: DesignSystem.Padding.standard
            )
        }
    }

    /// Background color
    var background: Color {
        switch self {
        case .large: return Color.clear
        case .compact: return DesignSystem.Colors.backgroundInputLight
        }
    }

    /// Corner radius
    var cornerRadius: CGFloat {
        switch self {
        case .large: return 0
        case .compact: return DesignSystem.CornerRadius.extraLarge
        }
    }
}

// MARK: - Preview

#Preview("Large Variant") {
    let sampleItem = GlassItemModel(
        natural_key: "bullseye-0001-0",
        name: "Bullseye Red Opal",
        sku: "0001",
        manufacturer: "bullseye",
        mfr_notes: "A beautiful deep red opal glass.",
        coe: 90,
        url: "https://www.bullseyeglass.com/color/0001-red-opal",
        mfr_status: "available"
    )

    return VStack {
        GlassItemCard(item: sampleItem, variant: .large)
            .padding()
        Spacer()
    }
}

#Preview("Compact Variant") {
    let sampleItem = GlassItemModel(
        natural_key: "cim-874-0",
        name: "Pale Gray",
        sku: "874",
        manufacturer: "cim",
        coe: 104,
        mfr_status: "available"
    )

    return VStack {
        GlassItemCard(item: sampleItem, variant: .compact)
            .padding()
        Spacer()
    }
}

#Preview("Both Variants") {
    let largeItem = GlassItemModel(
        natural_key: "bullseye-0001-0",
        name: "Bullseye Red Opal",
        sku: "0001",
        manufacturer: "bullseye",
        mfr_notes: "A beautiful deep red opal glass.",
        coe: 90,
        url: "https://www.bullseyeglass.com/color/0001-red-opal",
        mfr_status: "available"
    )

    let compactItem = GlassItemModel(
        natural_key: "cim-874-0",
        name: "Pale Gray",
        sku: "874",
        manufacturer: "cim",
        coe: 104,
        mfr_status: "available"
    )

    return VStack(spacing: DesignSystem.Spacing.xxl) {
        VStack(alignment: .leading) {
            Text("Large Variant")
                .font(DesignSystem.Typography.label)
                .fontWeight(DesignSystem.FontWeight.semibold)
            GlassItemCard(item: largeItem, variant: .large)
        }
        .padding()

        VStack(alignment: .leading) {
            Text("Compact Variant")
                .font(DesignSystem.Typography.label)
                .fontWeight(DesignSystem.FontWeight.semibold)
            GlassItemCard(item: compactItem, variant: .compact)
        }
        .padding()

        Spacer()
    }
}

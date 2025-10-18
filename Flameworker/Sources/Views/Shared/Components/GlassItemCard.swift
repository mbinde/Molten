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
    let tags: [String]
    let userTags: [String]
    let onManageTags: (() -> Void)?

    @State private var isTagsExpanded = false

    enum Variant {
        /// Large variant with full details, used in detail views
        case large
        /// Compact variant with minimal info, used in editors and lists
        case compact
    }

    init(
        item: GlassItemModel,
        variant: Variant,
        tags: [String] = [],
        userTags: [String] = [],
        onManageTags: (() -> Void)? = nil
    ) {
        self.item = item
        self.variant = variant
        self.tags = tags
        self.userTags = userTags
        self.onManageTags = onManageTags
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main card content
            HStack(alignment: .top, spacing: variant.spacing) {
                // Product image using SKU
                ProductImageDetail(
                    itemCode: item.sku,
                    manufacturer: item.manufacturer,
                    naturalKey: item.natural_key,
                    maxSize: variant.imageSize,
                    allowImageUpload: variant == .large,
                    onImageUploaded: nil
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

            // Tags section below the main content
            if !allTags.isEmpty {
                Divider()
                    .padding(.horizontal, variant.padding.leading)

                tagsView
                    .padding(variant.padding)
            }
        }
        .background(variant.background)
        .clipShape(RoundedRectangle(cornerRadius: variant.cornerRadius))
    }

    // MARK: - Details Section

    @ViewBuilder
    private var detailsSection: some View {
        switch variant {
        case .large:
            // Large variant: show SKU and COE on same line
            HStack {
                Text("SKU")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                Text(item.sku)
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(DesignSystem.FontWeight.medium)

                Spacer()
                    .frame(width: DesignSystem.Spacing.xl)

                Text("COE")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                Text("\(item.coe)")
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(DesignSystem.FontWeight.medium)

                Spacer()
            }

        case .compact:
            // Compact variant: show SKU only
            Text("SKU: \(item.sku)")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }

    // MARK: - Tags View

    @ViewBuilder
    private var tagsView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            // Collapsible header bar
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isTagsExpanded.toggle()
                }
            }) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .rotationEffect(.degrees(isTagsExpanded ? 90 : 0))

                    // Tag count
                    Text("\(allTags.count) tag\(allTags.count == 1 ? "" : "s")")
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    // Preview of first few tags (when collapsed)
                    if !isTagsExpanded && !allTags.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(allTags.prefix(3), id: \.self) { tag in
                                TagChip(tag: tag, isUserTag: userTags.contains(tag))
                            }
                            if allTags.count > 3 {
                                Text("+\(allTags.count - 3)")
                                    .font(DesignSystem.Typography.captionSmall)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }

                    Spacer()

                    // Manage button (only show when there's a handler)
                    if onManageTags != nil {
                        Button(action: { onManageTags?() }) {
                            HStack(spacing: 2) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 8))
                                Text("Manage")
                                    .font(DesignSystem.Typography.captionSmall)
                                    .fontWeight(DesignSystem.FontWeight.medium)
                            }
                            .foregroundColor(.purple)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            // Expanded tags view
            if isTagsExpanded {
                WrappingHStack(tags: allTags, spacing: DesignSystem.Spacing.xs) { tag in
                    TagChip(tag: tag, isUserTag: userTags.contains(tag))
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // Computed property for all tags merged and sorted
    private var allTags: [String] {
        Array(Set(tags + userTags)).sorted()
    }

    // MARK: - Manufacturer Link

    @ViewBuilder
    private var manufacturerLink: some View {
        if let urlString = item.url, !urlString.isEmpty, let url = URL(string: urlString) {
            let manufacturerDisplayName = GlassManufacturers.fullName(for: item.manufacturer) ?? "Manufacturer Website"

            HStack(spacing: DesignSystem.Spacing.md) {
                Link(destination: url) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Text(manufacturerDisplayName)
                            .font(DesignSystem.Typography.caption)
                            .fontWeight(DesignSystem.FontWeight.medium)
                        Image(systemName: "arrow.up.right")
                            .font(DesignSystem.Typography.captionSmall)
                    }
                    .foregroundColor(DesignSystem.Colors.accentPrimary)
                }

                Spacer()

                // Share button
                Button(action: {
                    shareItem()
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.accentPrimary)
                }
            }
        }
    }

    private func shareItem() {
        // TODO: Implement share functionality
        print("Share item: \(item.name)")
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

// MARK: - Tag Components

/// Simple tag chip component with visual distinction for user tags
private struct TagChip: View {
    let tag: String
    let isUserTag: Bool

    init(tag: String, isUserTag: Bool = false) {
        self.tag = tag
        self.isUserTag = isUserTag
    }

    var body: some View {
        HStack(spacing: 2) {
            if isUserTag {
                Image(systemName: "person.fill")
                    .font(.system(size: 7))
                    .foregroundColor(.purple)
            }
            Text(tag)
                .font(DesignSystem.Typography.captionSmall)
                .fontWeight(DesignSystem.FontWeight.medium)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(isUserTag ? Color.purple.opacity(0.1) : DesignSystem.Colors.accentPrimary.opacity(0.1))
        .foregroundColor(isUserTag ? .purple : DesignSystem.Colors.accentPrimary)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }
}

/// Wrapping horizontal stack for tags
private struct WrappingHStack<Content: View>: View {
    let tags: [String]
    let spacing: CGFloat
    @ViewBuilder let content: (String) -> Content

    var body: some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
                    content(tag)
                        .alignmentGuide(.leading) { d in
                            if abs(width - d.width) > geo.size.width {
                                width = 0
                                height -= d.height + spacing
                            }
                            let result = width
                            if index == tags.count - 1 {
                                width = 0
                            } else {
                                width -= d.width + spacing
                            }
                            return result
                        }
                        .alignmentGuide(.top) { _ in
                            let result = height
                            if index == tags.count - 1 {
                                height = 0
                            }
                            return result
                        }
                }
            }
        }
        .frame(height: calculateHeight())
    }

    private func calculateHeight() -> CGFloat {
        // Estimate height based on number of tags (simplified)
        let estimatedRows = ceil(Double(tags.count) / 3.0)
        return CGFloat(estimatedRows) * 28 // Approximate chip height
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
        GlassItemCard(item: sampleItem, variant: .large, tags: ["red", "opaque", "warm", "bullseye"])
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
            GlassItemCard(item: largeItem, variant: .large, tags: ["red", "opaque", "warm", "bullseye", "coe-90"])
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

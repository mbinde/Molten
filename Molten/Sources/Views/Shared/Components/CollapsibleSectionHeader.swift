//
//  CollapsibleSectionHeader.swift
//  Molten
//
//  Created by Assistant on 11/15/25.
//  Reusable collapsible section header with chevron and item count
//

import SwiftUI

/// A reusable header for collapsible sections with expand/collapse indicator
/// Use this for consistent expandable section UI across the app
struct CollapsibleSectionHeader: View {
    let title: String
    let itemCount: Int?
    let isExpanded: Bool
    let onToggle: () -> Void

    var leadingIcon: String? = nil
    var countSuffix: String? = nil // e.g., "item" for "5 items"

    init(
        title: String,
        itemCount: Int? = nil,
        isExpanded: Bool,
        onToggle: @escaping () -> Void,
        leadingIcon: String? = nil,
        countSuffix: String? = nil
    ) {
        self.title = title
        self.itemCount = itemCount
        self.isExpanded = isExpanded
        self.onToggle = onToggle
        self.leadingIcon = leadingIcon
        self.countSuffix = countSuffix
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                // Chevron indicator
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 12)

                // Optional leading icon
                if let icon = leadingIcon {
                    Image(systemName: icon)
                        .foregroundColor(.secondary)
                }

                // Title
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                // Optional item count
                if let count = itemCount {
                    Text(formatCount(count))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle()) // Makes entire area tappable
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("collapsible_section_header_\(title.lowercased().replacingOccurrences(of: " ", with: "_"))")
    }

    private func formatCount(_ count: Int) -> String {
        guard let suffix = countSuffix else {
            return "\(count)"
        }

        let pluralSuffix = count == 1 ? suffix : "\(suffix)s"
        return "\(count) \(pluralSuffix)"
    }
}

// MARK: - Convenience Initializers

extension CollapsibleSectionHeader {
    /// Creates a header with automatic "item/items" pluralization
    static func withItemCount(
        title: String,
        itemCount: Int,
        isExpanded: Bool,
        onToggle: @escaping () -> Void,
        leadingIcon: String? = nil
    ) -> CollapsibleSectionHeader {
        CollapsibleSectionHeader(
            title: title,
            itemCount: itemCount,
            isExpanded: isExpanded,
            onToggle: onToggle,
            leadingIcon: leadingIcon,
            countSuffix: "item"
        )
    }
}

// MARK: - Previews

#Preview("Basic") {
    VStack(spacing: 0) {
        CollapsibleSectionHeader(
            title: "Bullseye Glass",
            itemCount: 12,
            isExpanded: true,
            onToggle: {},
            countSuffix: "item"
        )
        .padding()

        Divider()

        CollapsibleSectionHeader(
            title: "Oceanside Glass",
            itemCount: 8,
            isExpanded: false,
            onToggle: {},
            countSuffix: "item"
        )
        .padding()
    }
}

#Preview("With Icons") {
    VStack(spacing: 0) {
        CollapsibleSectionHeader(
            title: "Stores",
            itemCount: 5,
            isExpanded: true,
            onToggle: {},
            leadingIcon: "storefront",
            countSuffix: "store"
        )
        .padding()

        Divider()

        CollapsibleSectionHeader(
            title: "Manufacturers",
            itemCount: 15,
            isExpanded: false,
            onToggle: {},
            leadingIcon: "building.2",
            countSuffix: "manufacturer"
        )
        .padding()
    }
}

#Preview("No Count") {
    VStack(spacing: 0) {
        CollapsibleSectionHeader(
            title: "Settings",
            isExpanded: true,
            onToggle: {}
        )
        .padding()

        Divider()

        CollapsibleSectionHeader(
            title: "Advanced",
            isExpanded: false,
            onToggle: {}
        )
        .padding()
    }
}

#Preview("Interactive") {
    @Previewable @State var isExpanded = false

    VStack(spacing: 16) {
        CollapsibleSectionHeader.withItemCount(
            title: "My Section",
            itemCount: 42,
            isExpanded: isExpanded,
            onToggle: {
                withAnimation {
                    isExpanded.toggle()
                }
            }
        )
        .padding()
        #if canImport(AppKit)
        .background(Color(NSColor.controlBackgroundColor))
        #else
        .background(Color(.systemGray6))
        #endif

        if isExpanded {
            Text("Content goes here...")
                .frame(maxWidth: .infinity)
                .padding()
                #if os(macOS)
                .background(Color(NSColor.windowBackgroundColor))
                #else
                .background(Color(.systemBackground))
                #endif
        }
    }
    .padding()
}

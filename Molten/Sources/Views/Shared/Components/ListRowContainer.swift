//
//  ListRowContainer.swift
//  Molten
//
//  Created by Assistant on 11/15/25.
//  Reusable container for consistent list row layouts
//

import SwiftUI

/// A flexible container for list rows that provides consistent spacing and layout patterns
/// Supports both simple content rows and icon-based rows with leading/trailing accessories
struct ListRowContainer<Leading: View, Header: View, Details: View, Footer: View, Trailing: View>: View {
    let leading: Leading?
    let header: Header
    let details: Details?
    let footer: Footer?
    let trailing: Trailing?
    let spacing: CGFloat
    let verticalPadding: CGFloat

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Leading accessory (icon, image, checkbox, etc.)
            if let leading = leading {
                leading
            }

            // Main content area
            VStack(alignment: .leading, spacing: spacing) {
                header

                if let details = details {
                    details
                }

                if let footer = footer {
                    footer
                }
            }

            Spacer()

            // Trailing accessory (chevron, badge, action button, etc.)
            if let trailing = trailing {
                trailing
            }
        }
        .padding(.vertical, verticalPadding)
        .contentShape(Rectangle()) // Makes entire row tappable
    }
}

// MARK: - Convenience Initializers

extension ListRowContainer where Leading == EmptyView, Details == EmptyView, Footer == EmptyView, Trailing == EmptyView {
    /// Simplest row: header only
    init(
        @ViewBuilder header: () -> Header,
        spacing: CGFloat = 8,
        verticalPadding: CGFloat = 4
    ) {
        self.leading = nil
        self.header = header()
        self.details = nil
        self.footer = nil
        self.trailing = nil
        self.spacing = spacing
        self.verticalPadding = verticalPadding
    }
}

extension ListRowContainer where Leading == EmptyView, Details == EmptyView, Trailing == EmptyView {
    /// Header + footer (e.g., simple content rows)
    init(
        @ViewBuilder header: () -> Header,
        @ViewBuilder footer: () -> Footer,
        spacing: CGFloat = 8,
        verticalPadding: CGFloat = 4
    ) {
        self.leading = nil
        self.header = header()
        self.details = nil
        self.footer = footer()
        self.trailing = nil
        self.spacing = spacing
        self.verticalPadding = verticalPadding
    }
}

extension ListRowContainer where Leading == EmptyView, Footer == EmptyView, Trailing == EmptyView {
    /// Header + details (no footer)
    init(
        @ViewBuilder header: () -> Header,
        @ViewBuilder details: () -> Details,
        spacing: CGFloat = 8,
        verticalPadding: CGFloat = 4
    ) {
        self.leading = nil
        self.header = header()
        self.details = details()
        self.footer = nil
        self.trailing = nil
        self.spacing = spacing
        self.verticalPadding = verticalPadding
    }
}

extension ListRowContainer where Leading == EmptyView, Trailing == EmptyView {
    /// Header + details + footer (no accessories)
    init(
        @ViewBuilder header: () -> Header,
        @ViewBuilder details: () -> Details,
        @ViewBuilder footer: () -> Footer,
        spacing: CGFloat = 8,
        verticalPadding: CGFloat = 4
    ) {
        self.leading = nil
        self.header = header()
        self.details = details()
        self.footer = footer()
        self.trailing = nil
        self.spacing = spacing
        self.verticalPadding = verticalPadding
    }
}

extension ListRowContainer where Details == EmptyView, Footer == EmptyView {
    /// Icon row with header and trailing chevron (no details/footer)
    init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder header: () -> Header,
        @ViewBuilder trailing: () -> Trailing,
        spacing: CGFloat = 8,
        verticalPadding: CGFloat = 4
    ) {
        self.leading = leading()
        self.header = header()
        self.details = nil
        self.footer = nil
        self.trailing = trailing()
        self.spacing = spacing
        self.verticalPadding = verticalPadding
    }
}

extension ListRowContainer where Footer == EmptyView {
    /// Icon row with header, details, and trailing chevron (no footer)
    init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder header: () -> Header,
        @ViewBuilder details: () -> Details,
        @ViewBuilder trailing: () -> Trailing,
        spacing: CGFloat = 8,
        verticalPadding: CGFloat = 4
    ) {
        self.leading = leading()
        self.header = header()
        self.details = details()
        self.footer = nil
        self.trailing = trailing()
        self.spacing = spacing
        self.verticalPadding = verticalPadding
    }
}

extension ListRowContainer {
    /// Full row with all components
    init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder header: () -> Header,
        @ViewBuilder details: () -> Details,
        @ViewBuilder footer: () -> Footer,
        @ViewBuilder trailing: () -> Trailing,
        spacing: CGFloat = 8,
        verticalPadding: CGFloat = 4
    ) {
        self.leading = leading()
        self.header = header()
        self.details = details()
        self.footer = footer()
        self.trailing = trailing()
        self.spacing = spacing
        self.verticalPadding = verticalPadding
    }
}

// MARK: - Previews

#Preview("Simple Content Row") {
    List {
        ListRowContainer(
            header: {
                HStack {
                    Text("Purchase from Mountain Glass")
                        .font(.headline)
                    Spacer()
                    Text("$125.00")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
            },
            footer: {
                Text("Monthly glass rod order")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        )
    }
}

#Preview("Icon Row with Chevron") {
    List {
        ListRowContainer(
            leading: {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: "storefront")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
            },
            header: {
                Text("Glass Art Supply")
                    .font(.headline)
            },
            details: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("123 Main St, Seattle, WA")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("5.2 mi")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            },
            trailing: {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        )
    }
}

#Preview("Schedule Row with Badges") {
    List {
        ListRowContainer(
            header: {
                HStack {
                    Text("Full Fuse - Dichroic")
                        .font(.headline)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                        Text("2h 30m")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DesignSystem.Colors.accentWarning.opacity(0.8))
                    .clipShape(Capsule())
                }
            },
            details: {
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                        Text("Fusing")
                            .font(.caption)
                    }
                    .foregroundColor(.orange)

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.caption2)
                        Text("4 segments")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            },
            footer: {
                Text("Recommended for dichroic glass with base layer")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        )
    }
}

#Preview("Inventory Item Row") {
    List {
        ListRowContainer(
            header: {
                HStack {
                    Text("Red Transparent")
                        .font(.headline)
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
            },
            details: {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("50 rod")
                            .font(.caption)
                            .fontWeight(.medium)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Bullseye")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("COE 90")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            },
            footer: {
                Text("Beautiful deep red transparent glass")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        )
    }
}

#Preview("All Variants") {
    List {
        Section("Header Only") {
            ListRowContainer(
                header: { Text("Header Only").font(.headline) }
            )
        }

        Section("Header + Footer") {
            ListRowContainer(
                header: { Text("Header").font(.headline) },
                footer: { Text("Footer").font(.caption).foregroundColor(.secondary) }
            )
        }

        Section("Header + Details") {
            ListRowContainer(
                header: { Text("Header").font(.headline) },
                details: { Text("Details").font(.caption).foregroundColor(.secondary) }
            )
        }

        Section("Full") {
            ListRowContainer(
                leading: {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                },
                header: { Text("Header").font(.headline) },
                details: { Text("Details").font(.caption).foregroundColor(.secondary) },
                footer: { Text("Footer").font(.caption).foregroundColor(.secondary) },
                trailing: {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            )
        }
    }
}

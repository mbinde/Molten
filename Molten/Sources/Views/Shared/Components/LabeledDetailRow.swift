//
//  LabeledDetailRow.swift
//  Molten
//
//  Created by Assistant on 11/15/25.
//  Reusable label + value row component for detail views
//

import SwiftUI

/// A reusable component for displaying label + value pairs in detail views
/// Supports both vertical and horizontal layouts
struct LabeledDetailRow: View {
    let label: String
    let value: String
    let layout: Layout
    let labelFont: Font
    let labelColor: Color
    let valueFont: Font
    let valueFontWeight: Font.Weight
    let valueColor: Color
    let alignment: HorizontalAlignment

    enum Layout {
        case vertical(spacing: CGFloat = 4)
        case horizontal(spacing: CGFloat = 0)
    }

    init(
        label: String,
        value: String,
        layout: Layout = .vertical(),
        labelFont: Font = .caption,
        labelColor: Color = .secondary,
        valueFont: Font = .body,
        valueFontWeight: Font.Weight = .regular,
        valueColor: Color = .primary,
        alignment: HorizontalAlignment = .leading
    ) {
        self.label = label
        self.value = value
        self.layout = layout
        self.labelFont = labelFont
        self.labelColor = labelColor
        self.valueFont = valueFont
        self.valueFontWeight = valueFontWeight
        self.valueColor = valueColor
        self.alignment = alignment
    }

    var body: some View {
        Group {
            switch layout {
            case .vertical(let spacing):
                VStack(alignment: alignment, spacing: spacing) {
                    labelView
                    valueView
                }

            case .horizontal(let spacing):
                HStack(spacing: spacing) {
                    labelView
                    Spacer()
                    valueView
                }
            }
        }
    }

    private var labelView: some View {
        Text(label)
            .font(labelFont)
            .foregroundColor(labelColor)
    }

    private var valueView: some View {
        Text(value)
            .font(valueFont)
            .fontWeight(valueFontWeight)
            .foregroundColor(valueColor)
    }
}

// MARK: - Convenience Initializers

extension LabeledDetailRow {
    /// Creates a vertical detail row with prominent (large, bold) value
    static func prominent(label: String, value: String, alignment: HorizontalAlignment = .leading) -> LabeledDetailRow {
        LabeledDetailRow(
            label: label,
            value: value,
            layout: .vertical(spacing: 4),
            labelFont: .caption,
            labelColor: .secondary,
            valueFont: .title2,
            valueFontWeight: .semibold,
            valueColor: .primary,
            alignment: alignment
        )
    }

    /// Creates a horizontal detail row with label and value side-by-side
    static func horizontal(label: String, value: String) -> LabeledDetailRow {
        LabeledDetailRow(
            label: label,
            value: value,
            layout: .horizontal(),
            labelFont: .caption,
            labelColor: .secondary,
            valueFont: .body,
            valueFontWeight: .regular,
            valueColor: .primary
        )
    }

    /// Creates a vertical detail row with regular-sized value
    static func regular(label: String, value: String, alignment: HorizontalAlignment = .leading) -> LabeledDetailRow {
        LabeledDetailRow(
            label: label,
            value: value,
            layout: .vertical(spacing: 4),
            labelFont: .caption,
            labelColor: .secondary,
            valueFont: .body,
            valueFontWeight: .regular,
            valueColor: .primary,
            alignment: alignment
        )
    }
}

// MARK: - Previews

#Preview("Vertical Layouts") {
    VStack(spacing: 20) {
        LabeledDetailRow.prominent(label: "Supplier", value: "Mountain Glass")

        LabeledDetailRow.regular(label: "Location", value: "Seattle, WA")

        LabeledDetailRow(
            label: "COE",
            value: "96",
            layout: .vertical(spacing: 2),
            labelFont: .caption2,
            valueFont: .caption,
            valueFontWeight: .medium
        )
    }
    .padding()
}

#Preview("Horizontal Layout") {
    VStack(spacing: 12) {
        LabeledDetailRow.horizontal(label: "Date", value: "Nov 15, 2025")

        LabeledDetailRow.horizontal(label: "Total", value: "$125.00")

        LabeledDetailRow.horizontal(label: "Status", value: "Completed")
    }
    .padding()
}

#Preview("Alignment Variants") {
    HStack(spacing: 40) {
        VStack(alignment: .leading, spacing: 12) {
            Text("Left Aligned")
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            LabeledDetailRow.prominent(
                label: "Supplier",
                value: "Bullseye Glass",
                alignment: .leading
            )
        }

        VStack(alignment: .trailing, spacing: 12) {
            Text("Right Aligned")
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            LabeledDetailRow.prominent(
                label: "Total Amount",
                value: "$150.00",
                alignment: .trailing
            )
        }
    }
    .padding()
}

#Preview("In Detail View Context") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            // Header section with two prominent values
            HStack {
                LabeledDetailRow.prominent(
                    label: "Supplier",
                    value: "Mountain Glass",
                    alignment: .leading
                )

                Spacer()

                LabeledDetailRow.prominent(
                    label: "Total Amount",
                    value: "$125.50",
                    alignment: .trailing
                )
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)

            // Details section with horizontal rows
            VStack(alignment: .leading, spacing: 12) {
                LabeledDetailRow.horizontal(label: "Date", value: "Nov 15, 2025")
                Divider()
                LabeledDetailRow.horizontal(label: "Order #", value: "12345")
                Divider()
                LabeledDetailRow.horizontal(label: "Status", value: "Shipped")
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
        }
        .padding()
    }
}

#Preview("With Custom Styling") {
    VStack(spacing: 16) {
        LabeledDetailRow(
            label: "ERROR",
            value: "Something went wrong",
            layout: .vertical(spacing: 6),
            labelFont: .caption,
            labelColor: .red,
            valueFont: .headline,
            valueFontWeight: .bold,
            valueColor: .red
        )

        LabeledDetailRow(
            label: "SUCCESS",
            value: "Operation completed",
            layout: .vertical(spacing: 6),
            labelFont: .caption,
            labelColor: .green,
            valueFont: .headline,
            valueFontWeight: .bold,
            valueColor: .green
        )
    }
    .padding()
}

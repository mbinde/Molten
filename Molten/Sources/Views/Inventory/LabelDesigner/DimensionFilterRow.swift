//
//  DimensionFilterRow.swift
//  Molten
//
//  Dimension filter for label format search
//

import SwiftUI

/// Row with width and height text fields for filtering labels by dimensions
struct DimensionFilterRow: View {
    @Binding var filterWidth: String
    @Binding var filterHeight: String

    var body: some View {
        HStack(spacing: 8) {
            Text("Size")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 36, alignment: .leading)

            // Width field
            HStack(spacing: 4) {
                TextField("W", text: $filterWidth)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 50)
                    .accessibilityIdentifier("dimension_filter_width")

                Text("×")
                    .foregroundColor(.secondary)

                // Height field
                TextField("H", text: $filterHeight)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 50)
                    .accessibilityIdentifier("dimension_filter_height")

                Text("in")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Clear button
            if !filterWidth.isEmpty || !filterHeight.isEmpty {
                Button {
                    filterWidth = ""
                    filterHeight = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("dimension_filter_clear")
            }
        }
        .padding(.vertical, 4)
    }
}

//
//  DimensionFilterRow.swift
//  Molten
//
//  Dimension and page format filters for label format search
//

import SwiftUI

/// Row with dimension text fields and page format picker for filtering labels
struct DimensionFilterRow: View {
    @Binding var filterWidth: String
    @Binding var filterHeight: String
    @Binding var pageFormat: LabelPageFormat

    var body: some View {
        HStack(spacing: 8) {
            // Dimension fields
            HStack(spacing: 4) {
                TextField("W", text: $filterWidth)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 44)
                    .accessibilityIdentifier("dimension_filter_width")

                Text("×")
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                TextField("H", text: $filterHeight)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 44)
                    .accessibilityIdentifier("dimension_filter_height")

                Text("in")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            // Clear dimensions button
            if !filterWidth.isEmpty || !filterHeight.isEmpty {
                Button {
                    filterWidth = ""
                    filterHeight = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("dimension_filter_clear")
            }

            Spacer()

            // Page format picker (compact)
            Picker("", selection: $pageFormat) {
                ForEach(LabelPageFormat.allCases) { format in
                    Text(format.displayName).tag(format)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 140)
            .accessibilityIdentifier("page_format_filter")
        }
        .padding(.vertical, 4)
    }
}

// Backwards compatibility initializer for existing call sites
extension DimensionFilterRow {
    init(filterWidth: Binding<String>, filterHeight: Binding<String>) {
        self._filterWidth = filterWidth
        self._filterHeight = filterHeight
        self._pageFormat = .constant(.letter)
    }
}

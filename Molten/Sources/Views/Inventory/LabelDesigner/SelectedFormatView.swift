//
//  SelectedFormatView.swift
//  Molten
//
//  Extracted from LabelDesignerView.swift
//

import SwiftUI

/// Selected format display button
struct SelectedFormatView: View {
    let selectedFormat: AveryFormat
    @Binding var isSearching: Bool

    var body: some View {
        Button {
            withAnimation {
                isSearching = true
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.body)

                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedFormat.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    FormatDetailsText(format: selectedFormat)
                }

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

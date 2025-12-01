//
//  FormatRow.swift
//  Molten
//
//  Extracted from LabelDesignerView.swift
//

import SwiftUI

/// Format row in search results
struct FormatRow: View {
    let format: LabelGeometry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(format.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                FormatDetailsText(format: format)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .contentShape(Rectangle())  // Make entire row tappable
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("format_row_\(format.name.lowercased().replacingOccurrences(of: " ", with: "_"))")
    }
}

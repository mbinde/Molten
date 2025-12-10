//
//  FormatDetailsText.swift
//  Molten
//
//  Extracted from LabelDesignerView.swift
//

import SwiftUI

/// Format details text (labels • dimensions • grid)
struct FormatDetailsText: View {
    let format: LabelGeometry

    var body: some View {
        HStack(spacing: 4) {
            Text("\(format.labelsPerSheet) labels")
            Text("•")
            Text(formatDimensions)
            Text("•")
            Text("\(format.columns)×\(format.rows)")
        }
        .font(.caption)
        .foregroundColor(DesignSystem.Colors.textSecondary)
    }

    private var formatDimensions: String {
        let widthInches = format.labelWidth / 72.0
        let heightInches = format.labelHeight / 72.0

        let widthStr = formatInches(widthInches)
        let heightStr = formatInches(heightInches)

        return "\(widthStr)\" × \(heightStr)\""
    }

    private func formatInches(_ inches: Double) -> String {
        if abs(inches - 0.5) < 0.01 { return "½" }
        if abs(inches - 0.75) < 0.01 { return "¾" }
        if abs(inches - 1.75) < 0.01 { return "1¾" }
        if abs(inches - 2.625) < 0.01 { return "2⅝" }
        if abs(inches - 3.33) < 0.01 { return "3⅓" }
        if abs(inches - 3.375) < 0.01 { return "3⅜" }
        if abs(inches - 2.33) < 0.01 { return "2⅓" }
        if abs(inches - 1.33) < 0.01 { return "1⅓" }
        if abs(inches - 1.25) < 0.01 { return "1¼" }
        if abs(inches - 2.25) < 0.01 { return "2¼" }
        if abs(inches - 3.5) < 0.01 { return "3.5" }

        if abs(inches - round(inches)) < 0.01 {
            return "\(Int(round(inches)))"
        }

        return String(format: "%.1f", inches)
    }
}

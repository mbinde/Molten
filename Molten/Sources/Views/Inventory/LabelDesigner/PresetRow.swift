//
//  PresetRow.swift
//  Molten
//
//  Extracted from LabelDesignerView.swift
//

import SwiftUI

/// Row showing a preset
struct PresetRow: View {
    let preset: LabelBuilderPreset
    let onSelect: (LabelBuilderPreset) -> Void

    var body: some View {
        Button {
            onSelect(preset)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(preset.description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Label(preset.config.qrPosition.rawValue, systemImage: "qrcode")
                    Label("\(preset.config.textFields.count) fields", systemImage: "list.bullet")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

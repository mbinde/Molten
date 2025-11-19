//
//  PresetSelectionSheet.swift
//  Molten
//
//  Extracted from LabelDesignerView.swift
//

import SwiftUI

struct PresetSelectionSheet: View {
    let presets: [LabelBuilderPreset]
    let onSelect: (LabelBuilderPreset) -> Void
    let onDelete: (LabelBuilderPreset) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // User presets (shown first)
                let userPresets = presets.filter { preset in
                    !LabelBuilderConfig.presets.contains(where: { $0.id == preset.id })
                }
                if !userPresets.isEmpty {
                    Section("My Presets") {
                        ForEach(userPresets) { preset in
                            PresetRow(preset: preset, onSelect: onSelect)
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { index in
                                onDelete(userPresets[index])
                            }
                        }
                    }
                }

                // Built-in presets (shown second)
                let builtInPresets = presets.filter { preset in
                    LabelBuilderConfig.presets.contains(where: { $0.id == preset.id })
                }
                if !builtInPresets.isEmpty {
                    Section("Built-in Presets") {
                        ForEach(builtInPresets) { preset in
                            PresetRow(preset: preset, onSelect: onSelect)
                        }
                    }
                }

                if presets.isEmpty {
                    Section {
                        Text("No presets available")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Load Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

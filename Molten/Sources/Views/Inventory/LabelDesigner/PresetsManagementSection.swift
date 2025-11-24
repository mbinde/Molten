//
//  PresetsManagementSection.swift
//  Molten
//
//  Extracted from LabelDesignerView.swift
//

import SwiftUI

struct PresetsManagementSection: View {
    @ObservedObject var presetsManager: LabelPresetsManager
    @Binding var currentPresetName: String?
    @Binding var isPresetModified: Bool
    @Binding var showingPresetSheet: Bool
    @Binding var showingSavePreset: Bool
    @Binding var showingEditPreset: Bool
    @Binding var editingPresetName: String
    @Binding var editingPresetDescription: String

    let onRequestDelete: (LabelBuilderPreset) -> Void
    let onOverwritePreset: () -> Void

    var body: some View {
        Section {
            Button {
                showingPresetSheet = true
            } label: {
                HStack {
                    Image(systemName: "square.grid.2x2")
                    Text("Load Preset")
                    Spacer()
                    Text("\(presetsManager.allPresets.count) available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityIdentifier("presets_load")

            // Current preset name display
            if let presetName = currentPresetName {
                HStack {
                    Text(presetName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if isPresetModified {
                        Text("(modified)")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .italic()
                    }
                    Spacer()

                    // Edit button (only for user presets, not built-in)
                    if !LabelBuilderConfig.presets.contains(where: { $0.name == presetName }) {
                        Button {
                            // Find the preset to edit
                            if let preset = presetsManager.allPresets.first(where: { $0.name == presetName }) {
                                editingPresetName = preset.name
                                editingPresetDescription = preset.description
                                showingEditPreset = true
                            }
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("presets_edit")
                    }

                    // Delete button (only for user presets, not built-in)
                    if !LabelBuilderConfig.presets.contains(where: { $0.name == presetName }) {
                        Button(role: .destructive) {
                            // Find the preset to delete
                            if let preset = presetsManager.allPresets.first(where: { $0.name == presetName }) {
                                onRequestDelete(preset)
                            }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("presets_delete")
                    }
                }
                .padding(.vertical, 4)
            }

            // Overwrite button (only when preset is modified and not a built-in preset)
            if isPresetModified,
               let presetName = currentPresetName,
               !LabelBuilderConfig.presets.contains(where: { $0.name == presetName }) {
                Button {
                    onOverwritePreset()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Overwrite Current Preset")
                    }
                }
                .foregroundColor(.orange)
                .accessibilityIdentifier("presets_overwrite")
            }

            Button {
                showingSavePreset = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text("Save Current as a New Preset")
                }
            }
            .accessibilityIdentifier("presets_save_new")
        } header: {
            Text("Presets")
        } footer: {
            Text("Save your favorite label configurations as presets for quick access")
                .font(.caption)
        }
    }
}

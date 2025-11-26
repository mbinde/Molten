//
//  SavePresetSheet.swift
//  Molten
//
//  Extracted from LabelDesignerView.swift
//

import SwiftUI

/// Sheet for saving a new preset
struct SavePresetSheet: View {
    @Binding var presetName: String
    @Binding var presetDescription: String
    var isEditing: Bool = false
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Preset Details") {
                    TextField("Preset Name", text: $presetName)
                        .textInputAutocapitalization(.words)

                    TextField("Description (optional)", text: $presetDescription, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section {
                    Text(isEditing
                         ? "Update the name and description for this preset."
                         : "This will save your current label configuration (QR position, size, and fields) as a preset for quick access later.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(isEditing ? "Edit Preset" : "Save Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .accessibilityIdentifier("save_preset_cancel")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                    }
                    .disabled(presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("save_preset_save")
                }
            }
        }
    }
}

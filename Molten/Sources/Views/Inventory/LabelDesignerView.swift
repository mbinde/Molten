//
//  LabelDesignerView.swift
//  Molten
//
//  UI for designing and exporting printable labels with QR codes
//

import SwiftUI

/// View for designing and exporting printable labels for inventory items
struct LabelDesignerView: View {
    let items: [CompleteInventoryItemModel]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.editMode) private var editMode

    @State private var selectedFormat: AveryFormat = .avery5160

    // Label builder configuration (replaces template)
    @State private var builderConfig: LabelBuilderConfig = .default

    @State private var isGenerating = false
    @State private var generatedPDFURL: URL?
    @State private var showingShareSheet = false
    @State private var errorMessage: String?

    // Print adjustments
    @State private var offsetX: Double = 0.0
    @State private var offsetY: Double = 0.0

    // Start position for partial sheets
    @State private var startRow: Int = 0
    @State private var startColumn: Int = 0

    // Advanced options collapsed state
    @State private var showAdvancedOptions: Bool = false
    @State private var showAdvancedLayoutOptions: Bool = false

    // Preset management
    @State private var showingPresetSheet = false
    @State private var showingSavePreset = false
    @State private var newPresetName = ""
    @State private var newPresetDescription = ""
    @StateObject private var presetsManager = LabelPresetsManager.shared

    // CRITICAL: Cache service instance in @State to prevent recreation on every body evaluation
    @State private var labelService: LabelPrintingService?

    // Preview item selection
    @State private var selectedPreviewIndex: Int = 0

    // Owner editing popup
    @State private var showingOwnerEditor = false
    @State private var ownerEditText = ""

    // Track currently loaded preset (if any)
    @State private var currentPreset: LabelBuilderPreset?
    @State private var previousPreset: LabelBuilderPreset?  // Fallback when deleting current preset

    // Delete confirmation
    @State private var showingDeleteConfirmation = false
    @State private var presetToDelete: LabelBuilderPreset?

    var body: some View {
        NavigationStack {
            Form {
                Group {
                Section {
                    Text("\(totalLabelCount) label\(totalLabelCount == 1 ? "" : "s") to print")
                        .font(.headline)

                    Text("From \(items.count) item\(items.count == 1 ? "" : "s") selected")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if totalLabelCount > selectedFormat.labelsPerSheet {
                        Text("This will require \(numberOfSheets) sheet\(numberOfSheets == 1 ? " of labels" : "s of labels")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Label Format") {
                    Picker("Format", selection: $selectedFormat) {
                        Text("Avery 5160 (30 labels, 1\" × 2⅝\")").tag(AveryFormat.avery5160)
                        Text("Avery 18167 (80 labels, ½\" × 1¾\")").tag(AveryFormat.avery18167)
                        Text("Mr-Label MR184 (30 labels, 1\" × 2⅝\")").tag(AveryFormat.mrLabel184)
                        // Temporarily hidden for testing - uncomment to enable
                        // Text("Avery 5163 (10 labels, 2\" × 4\")").tag(AveryFormat.avery5163)
                        // Text("Avery 5167 (80 labels, ½\" × 1¾\")").tag(AveryFormat.avery5167)
                    }

                    HStack(spacing: 6) {
                        Text(selectedFormat.name)
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("•")
                            .foregroundColor(.secondary)
                        Text("\(selectedFormat.labelsPerSheet) labels per sheet (\(selectedFormat.columns)×\(selectedFormat.rows))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Presets Section
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

                    // Show current preset status
                    if let preset = currentPreset {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text(preset.name)
                                .font(.subheadline)
                            if preset.config != builderConfig {
                                Text("(modified)")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }

                    // Show different options based on whether we have a current user preset loaded
                    if let preset = currentPreset, !LabelBuilderConfig.presets.contains(where: { $0.id == preset.id }) {
                        // User preset is loaded - show Save (if modified), Save As New, Delete
                        let isModified = preset.config != builderConfig

                        if isModified {
                            Button {
                                saveCurrentPreset()
                            } label: {
                                HStack {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("Overwrite Preset")
                                }
                            }
                        }

                        Button {
                            showingSavePreset = true
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.down.on.square")
                                Text("Save as New Preset")
                            }
                        }

                        Button(role: .destructive) {
                            presetToDelete = preset
                            showingDeleteConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Preset")
                            }
                        }
                    } else {
                        // No user preset loaded - show Save As New only
                        Button {
                            showingSavePreset = true
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("Save Current as a New Preset")
                            }
                        }
                    }
                } header: {
                    Text("Presets")
                } footer: {
                    Text("Save your favorite label configurations as presets for quick access")
                        .font(.caption)
                }

                // Label Preview Section (before Label Layout)
                if let previewData = sampleLabelData {
                    Section {
                        // Item selector (if multiple items)
                        if items.count > 1 {
                            Picker("Preview with:", selection: $selectedPreviewIndex) {
                                ForEach(0..<items.count, id: \.self) { index in
                                    let item = items[index]
                                    Text("\(item.glassItem.name)")
                                        .lineLimit(1)
                                        .tag(index)
                                }
                            }
                            .pickerStyle(.menu)
                            Text("Select which item to preview above. Red highlighting will show text that will be truncated on the label.")
                                .font(.caption)
                        } else {
                            Text("Red highlighting will show text that will be truncated on the label.")
                                .font(.caption)
                        }

                        labelPreview
                    } header: {
                        if items.count > 1 {
                            Text("Select which item to preview above. Red highlighting will show text that will be truncated on the label.")
                                .font(.caption)
                        } else {
                            Text("Red highlighting will show text that will be truncated on the label.")
                                .font(.caption)
                        }
                    }
                }
                } // End Group 1

                Group {
                // Label Builder Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        // Font Size (compact inline)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 12) {
                                Text("Font Size")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(width: 80, alignment: .leading)

                                Slider(value: fontScaleBinding, in: 0.2...2.0, step: 0.1)
                                    .tint(isUsingCustomFontScale ? .orange : .blue)
                                    .id("fontScale-\(builderConfig.fontScale?.description ?? "default")")

                                Text("\(Int(effectiveFontScale * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                                    .frame(width: 45, alignment: .trailing)
                            }

                            if isUsingCustomFontScale {
                                HStack(spacing: 4) {
                                    Image(systemName: "info.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                    Text("Custom (\(selectedFormat.name) default: \(Int(selectedFormat.defaultFontScale * 100))%)")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                    Spacer()
                                    Button {
                                        builderConfig.fontScale = nil
                                    } label: {
                                        Text("Reset to Default")
                                            .font(.caption2)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.orange)
                                }
                            }
                        }

                        Divider()

                        // QR Code Position (compact inline)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 12) {
                                Text("QR Code Position")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Spacer()

                                Picker("QR Position", selection: $builderConfig.qrPosition) {
                                    ForEach(QRCodePosition.allCases, id: \.self) { position in
                                        Text(position.rawValue).tag(position)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                            }

                            if builderConfig.qrPosition != .none {
                                // QR Code Size (compact inline, matching others)
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 12) {
                                        Text("QR Code Size")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .frame(width: 140, alignment: .leading)

                                        Slider(value: qrSizeBinding, in: 0.5...0.8, step: 0.05)
                                            .tint(isUsingCustomQRSize ? .orange : .blue)
                                            .id("qrSize-\(builderConfig.qrSize?.description ?? "default")")

                                        Text("\(Int(effectiveQRSize * 100))%")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .monospacedDigit()
                                            .frame(width: 45, alignment: .trailing)
                                    }

                                    if isUsingCustomQRSize {
                                        HStack(spacing: 4) {
                                            Image(systemName: "info.circle.fill")
                                                .font(.caption2)
                                                .foregroundColor(.orange)
                                            Text("Custom (\(selectedFormat.name) default: \(Int(selectedFormat.defaultQRSize * 100))%)")
                                                .font(.caption2)
                                                .foregroundColor(.orange)
                                            Spacer()
                                            Button {
                                                builderConfig.qrSize = nil
                                            } label: {
                                                Text("Reset to Default")
                                                    .font(.caption2)
                                            }
                                            .buttonStyle(.bordered)
                                            .tint(.orange)
                                        }
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }

                        Divider()

                        // Text Fields (Reorderable List)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Label Fields")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("Tap to toggle • Drag to reorder")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            // Included fields (reorderable)
                            if !builderConfig.textFields.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    List {
                                        ForEach(builderConfig.textFields, id: \.self) { field in
                                            Button {
                                                toggleField(field)
                                            } label: {
                                                HStack(spacing: 8) {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.green)

                                                    Text(field.rawValue)
                                                        .font(.subheadline)

                                                    Spacer()
                                                }
                                                .contentShape(Rectangle())
                                            }
                                            .buttonStyle(.plain)
                                            .listRowBackground(Color(.systemGray6))
                                        }
                                        .onMove { from, to in
                                            builderConfig.textFields.move(fromOffsets: from, toOffset: to)
                                        }
                                    }
                                    .listStyle(.plain)
                                    .frame(height: CGFloat(builderConfig.textFields.count * 52))
                                    .environment(\.editMode, .constant(.active))
                                }

                                Divider()
                                    .padding(.vertical, 8)
                            }

                            // Available fields (not included)
                            // Filter out owner field if owner isn't set in settings
                            let ownerIsSet = UserSettings.shared.inventoryOwner != nil && !UserSettings.shared.inventoryOwner!.isEmpty
                            let unusedFields = LabelTextField.allCases.filter { field in
                                !builderConfig.textFields.contains(field) && (field != .owner || ownerIsSet)
                            }

                            if !unusedFields.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Available Fields (unused):")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.bottom, 4)

                                    ForEach(unusedFields, id: \.self) { field in
                                        Button {
                                            toggleField(field)
                                        } label: {
                                            HStack(spacing: 8) {
                                                Image(systemName: "circle")
                                                    .foregroundColor(.secondary)

                                                Text(field.rawValue)
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)

                                                Spacer()
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 8)
                                    }
                                }
                            }

                            // Show helpful message if owner field is not available because owner isn't set
                            if !ownerIsSet {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "info.circle")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text("To include an Owner field on labels,")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        + Text(" ")
                                        + Text("tap here to set your inventory owner")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                            .underline()
                                    }
                                    .padding(.top, 8)
                                    .onTapGesture {
                                        ownerEditText = UserSettings.shared.inventoryOwner ?? ""
                                        showingOwnerEditor = true
                                    }
                                }
                            }

                            if !builderConfig.textFields.isEmpty {
                                Text("Long-press and drag to reorder active fields")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .italic()
                                    .padding(.top, 8)
                            }
                        }
                    }
                } header: {
                    Text("Label Layout")
                } footer: {
                    // Layout validation warnings
                    let validation = builderConfig.validateLayout(for: selectedFormat, fontScale: effectiveFontScale)
                    if !validation.warnings.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(validation.warnings, id: \.self) { warning in
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    Text(warning)
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }

                // Preview Copy #2 (before Field Formatting)
                if sampleLabelData != nil {
                    Section {
                        labelPreview
                    }
                }

                // Advanced Layout Options Section (manufacturer image + field formatting)
                Section {
                    DisclosureGroup(
                        isExpanded: $showAdvancedLayoutOptions,
                        content: {
                            VStack(alignment: .leading, spacing: 16) {
                                // Manufacturer Image Section
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Manufacturer Logo")
                                        .font(.headline)

                                    // Position picker
                                    HStack(spacing: 12) {
                                        Text("Position")
                                            .font(.subheadline)
                                            .fontWeight(.medium)

                                        Spacer()

                                        Picker("Image Position", selection: $builderConfig.manufacturerImagePosition) {
                                            ForEach(ManufacturerImagePosition.allCases, id: \.self) { position in
                                                Text(position.rawValue).tag(position)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .labelsHidden()
                                    }

                                    // Overlap warning
                                    if builderConfig.manufacturerImageOverlapsQR() {
                                        HStack(spacing: 4) {
                                            Rectangle()
                                                .fill(Color.red)
                                                .frame(height: 2)
                                                .frame(maxWidth: .infinity)
                                        }
                                        Text("Image overlaps with QR code and won't be visible")
                                            .font(.caption2)
                                            .foregroundColor(.red)
                                    }

                                    // Size slider (if manufacturer image is enabled)
                                    if builderConfig.manufacturerImagePosition != .none {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(spacing: 12) {
                                                Text("Image Size")
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .frame(width: 80, alignment: .leading)

                                                Slider(value: manufacturerImageSizeBinding, in: 0.3...0.9, step: 0.05)
                                                    .tint(isUsingCustomManufacturerImageSize ? .orange : .blue)
                                                    .id("manufacturerImageSize-\(builderConfig.manufacturerImageSize?.description ?? "default")")

                                                Text("\(Int(effectiveManufacturerImageSize * 100))%")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .monospacedDigit()
                                                    .frame(width: 45, alignment: .trailing)
                                            }

                                            if isUsingCustomManufacturerImageSize {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "info.circle.fill")
                                                        .font(.caption2)
                                                        .foregroundColor(.orange)
                                                    Text("Custom (default: 60%)")
                                                        .font(.caption2)
                                                        .foregroundColor(.orange)
                                                    Spacer()
                                                    Button {
                                                        builderConfig.manufacturerImageSize = nil
                                                    } label: {
                                                        Text("Reset to Default")
                                                            .font(.caption2)
                                                    }
                                                    .buttonStyle(.bordered)
                                                    .tint(.orange)
                                                }
                                            }
                                        }
                                        .padding(.top, 4)
                                    }
                                }

                                Divider()

                                // Field Formatting Section
                                Text("Field Formatting")
                                    .font(.headline)

                                Text("Customize formatting for each field on your labels")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                ForEach(LabelTextField.allCases, id: \.self) { field in
                                    FieldFormatEditor(
                                        field: field,
                                        format: Binding(
                                            get: { builderConfig.format(for: field) },
                                            set: { builderConfig.fieldFormats[field] = $0 }
                                        )
                                    )
                                }
                            }
                            .padding(.vertical, 8)
                        },
                        label: {
                            Label("Advanced Layout Options", systemImage: "textformat")
                        }
                    )
                } footer: {
                    Text("Customize manufacturer logo position and size, and adjust font size, bold, and italic formatting for individual fields. These settings are saved with presets.")
                        .font(.caption)
                }
                } // End Group 2

                // Preview Copy #3 (before Advanced Sheet Options)
                if sampleLabelData != nil {
                    Section {
                        labelPreview
                    }
                }

                Group {
                // Advanced Sheet Options Section (collapsed by default)
                Section {
                    DisclosureGroup(
                        isExpanded: $showAdvancedOptions,
                        content: {
                            VStack(spacing: 20) {
                                // Partial Sheet Controls
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Partial Sheet")
                                        .font(.headline)

                                    Text("Use this if you're printing on a partially-used label sheet")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    // Start Row
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("Start Row")
                                                .font(.subheadline)
                                            Spacer()
                                            Text("Row \(startRow + 1)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .monospacedDigit()
                                        }

                                        Picker("Start Row", selection: $startRow) {
                                            ForEach(0..<selectedFormat.rows, id: \.self) { row in
                                                Text("Row \(row + 1)").tag(row)
                                            }
                                        }
                                        .pickerStyle(.wheel)
                                        .frame(height: 100)
                                    }

                                    // Start Column
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("Start Column")
                                                .font(.subheadline)
                                            Spacer()
                                            Text("Column \(startColumn + 1)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .monospacedDigit()
                                        }

                                        Picker("Start Column", selection: $startColumn) {
                                            ForEach(0..<selectedFormat.columns, id: \.self) { col in
                                                Text("Column \(col + 1)").tag(col)
                                            }
                                        }
                                        .pickerStyle(.segmented)
                                    }

                                    // Show position description
                                    if startRow != 0 || startColumn != 0 {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.down.right.circle.fill")
                                                .foregroundColor(.orange)
                                            Text("Printing will start at Row \(startRow + 1), Column \(startColumn + 1)")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }

                                        Button {
                                            withAnimation {
                                                startRow = 0
                                                startColumn = 0
                                            }
                                        } label: {
                                            Label("Reset to Full Sheet", systemImage: "arrow.counterclockwise")
                                                .font(.caption)
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }

                                Divider()

                                // Print Position Adjustments
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Position Adjustments")
                                        .font(.headline)

                                    // Horizontal offset
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("Horizontal Position")
                                                .font(.subheadline)
                                            Spacer()
                                            Text(offsetX > 0 ? "+\(Int(offsetX))pt" : "\(Int(offsetX))pt")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .monospacedDigit()
                                        }

                                        Slider(value: $offsetX, in: -10...10, step: 0.5) {
                                            Text("Horizontal Offset")
                                        }
                                        .tint(.orange)

                                        HStack {
                                            Text("← Left")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text("Right →")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    // Vertical offset
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("Vertical Position")
                                                .font(.subheadline)
                                            Spacer()
                                            Text(offsetY > 0 ? "+\(Int(offsetY))pt" : "\(Int(offsetY))pt")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .monospacedDigit()
                                        }

                                        Slider(value: $offsetY, in: -10...10, step: 0.5) {
                                            Text("Vertical Offset")
                                        }
                                        .tint(.orange)

                                        HStack {
                                            Text("↑ Up")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text("Down ↓")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    // Reset button
                                    if offsetX != 0.0 || offsetY != 0.0 {
                                        Button {
                                            withAnimation {
                                                offsetX = 0.0
                                                offsetY = 0.0
                                            }
                                        } label: {
                                            Label("Reset Position", systemImage: "arrow.counterclockwise")
                                                .font(.caption)
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                            }
                        },
                        label: {
                            Label("Advanced Sheet Op,tions", systemImage: "gearshape")
                        }
                    )
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                } // End Group 3
            }
            .navigationTitle("Print Labels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Generate PDF") {
                        Task {
                            await generatePDF()
                        }
                    }
                    .disabled(isGenerating || items.isEmpty)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = generatedPDFURL {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $showingPresetSheet) {
                PresetSelectionSheet(
                    presets: presetsManager.allPresets,
                    onSelect: { preset in
                        previousPreset = currentPreset  // Save current as previous before switching
                        builderConfig = preset.config
                        currentPreset = preset  // Track loaded preset
                        showingPresetSheet = false
                    },
                    onDelete: { preset in
                        presetToDelete = preset
                        showingDeleteConfirmation = true
                    }
                )
            }
            .sheet(isPresented: $showingSavePreset) {
                SavePresetSheet(
                    presetName: $newPresetName,
                    presetDescription: $newPresetDescription,
                    onSave: {
                        let preset = LabelBuilderPreset(
                            name: newPresetName.isEmpty ? "Custom Preset" : newPresetName,
                            description: newPresetDescription.isEmpty ? "User-created preset" : newPresetDescription,
                            config: builderConfig
                        )
                        presetsManager.savePreset(preset)
                        currentPreset = preset  // Track the newly created preset
                        newPresetName = ""
                        newPresetDescription = ""
                        showingSavePreset = false
                    },
                    onCancel: {
                        newPresetName = ""
                        newPresetDescription = ""
                        showingSavePreset = false
                    }
                )
            }
            .alert("Set Inventory Owner", isPresented: $showingOwnerEditor) {
                TextField("Owner name", text: $ownerEditText)
                    .textInputAutocapitalization(.words)
                Button("Cancel", role: .cancel) {
                    ownerEditText = ""
                }
                Button("Save") {
                    let trimmed = ownerEditText.trimmingCharacters(in: .whitespacesAndNewlines)
                    UserSettings.shared.inventoryOwner = trimmed.isEmpty ? nil : trimmed
                    ownerEditText = ""
                }
            } message: {
                Text("Enter the name to display on the Owner field for your inventory labels.")
            }
            .alert("Delete Preset?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    presetToDelete = nil
                }
                Button("OK", role: .destructive) {
                    if let preset = presetToDelete {
                        let isDeletingCurrent = currentPreset?.id == preset.id
                        presetsManager.deletePreset(preset)

                        // If we deleted the current preset, fall back to previous or default
                        if isDeletingCurrent {
                            if let previous = previousPreset, presetsManager.allPresets.contains(where: { $0.id == previous.id }) {
                                // Previous preset still exists, load it
                                builderConfig = previous.config
                                currentPreset = previous
                            } else {
                                // No valid fallback, use default config
                                builderConfig = .default
                                currentPreset = nil
                                previousPreset = nil
                            }
                        }
                        presetToDelete = nil
                    }
                }
            } message: {
                Text("This operation cannot be undone.")
            }
            .onAppear {
                if labelService == nil {
                    labelService = LabelPrintingService()
                }
                loadLastUsedFormat()
                loadSettings()
                // If no preset matched from saved settings, check if current config matches a preset
                if currentPreset == nil {
                    updateCurrentPresetFromConfig()
                }
            }
            .onChange(of: selectedFormat) { _, newFormat in
                saveLastUsedFormat(newFormat)
                loadSettings()
            }
            .onChange(of: offsetX) { _, _ in
                saveSettings()
            }
            .onChange(of: offsetY) { _, _ in
                saveSettings()
            }
            .onChange(of: builderConfig) { _, _ in
                saveSettings()
                // Keep currentPreset so we can show "Preset Name (modified)"
                // The UI already handles showing (modified) when preset.config != builderConfig
            }
        }
    }

    // MARK: - Computed Properties

    /// Effective font scale (preset override or format default)
    private var effectiveFontScale: CGFloat {
        return builderConfig.fontScale ?? selectedFormat.defaultFontScale
    }

    /// Effective QR size (preset override or format default)
    private var effectiveQRSize: CGFloat {
        return builderConfig.qrSize ?? selectedFormat.defaultQRSize
    }

    /// Effective manufacturer image size (preset override or default 0.6)
    private var effectiveManufacturerImageSize: CGFloat {
        return builderConfig.manufacturerImageSize ?? 0.6
    }

    /// Whether font scale is using a custom value (not format default)
    private var isUsingCustomFontScale: Bool {
        return builderConfig.fontScale != nil
    }

    /// Whether QR size is using a custom value (not format default)
    private var isUsingCustomQRSize: Bool {
        return builderConfig.qrSize != nil
    }

    /// Whether manufacturer image size is using a custom value (not default)
    private var isUsingCustomManufacturerImageSize: Bool {
        return builderConfig.manufacturerImageSize != nil
    }

    /// Reusable preview view
    @ViewBuilder
    private var labelPreview: some View {
        if let previewData = sampleLabelData {
            LabelPreviewView(
                format: selectedFormat,
                config: builderConfig,
                sampleData: previewData,
                fontScale: effectiveFontScale,
                offsetX: offsetX,
                offsetY: offsetY
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    /// Binding for font scale slider (syncs with builderConfig.fontScale)
    private var fontScaleBinding: Binding<Double> {
        Binding(
            get: { Double(self.effectiveFontScale) },
            set: { newValue in
                // Set to nil if it matches the format default, otherwise set custom value
                let cgValue = CGFloat(newValue)
                if abs(cgValue - self.selectedFormat.defaultFontScale) < 0.01 {
                    self.builderConfig.fontScale = nil
                } else {
                    self.builderConfig.fontScale = cgValue
                }
            }
        )
    }

    /// Binding for QR size slider (syncs with builderConfig.qrSize)
    private var qrSizeBinding: Binding<Double> {
        Binding(
            get: { Double(self.effectiveQRSize) },
            set: { newValue in
                // Set to nil if it matches the format default, otherwise set custom value
                let cgValue = CGFloat(newValue)
                if abs(cgValue - self.selectedFormat.defaultQRSize) < 0.05 {
                    self.builderConfig.qrSize = nil
                } else {
                    self.builderConfig.qrSize = cgValue
                }
            }
        )
    }

    /// Binding for manufacturer image size slider (syncs with builderConfig.manufacturerImageSize)
    private var manufacturerImageSizeBinding: Binding<Double> {
        Binding(
            get: { Double(self.effectiveManufacturerImageSize) },
            set: { newValue in
                // Set to nil if it matches the default (0.6), otherwise set custom value
                let cgValue = CGFloat(newValue)
                if abs(cgValue - 0.6) < 0.05 {
                    self.builderConfig.manufacturerImageSize = nil
                } else {
                    self.builderConfig.manufacturerImageSize = cgValue
                }
            }
        )
    }

    /// Total number of labels to print (sum of all inventory quantities)
    private var totalLabelCount: Int {
        items.reduce(0) { total, item in
            let quantity = item.inventory.first?.quantity ?? 1.0

            // Safe conversion: check if quantity is within Int range
            guard !quantity.isNaN && !quantity.isInfinite &&
                  quantity >= Double(Int.min) && quantity <= Double(Int.max) else {
                return Int.max
            }

            let quantityInt = Int(quantity)

            // Prevent overflow when adding to total
            if total > Int.max - quantityInt {
                return Int.max
            }
            return total + quantityInt
        }
    }

    private var numberOfSheets: Int {
        Int(ceil(Double(totalLabelCount) / Double(selectedFormat.labelsPerSheet)))
    }

    private var sampleLabelData: LabelData? {
        // Use selected index if valid, otherwise use first item
        let index = selectedPreviewIndex < items.count ? selectedPreviewIndex : 0
        guard index < items.count else { return nil }

        let item = items[index]
        let glassItem = item.glassItem
        let location = item.locations.first

        return LabelData(
            stableId: glassItem.stable_id,
            manufacturer: glassItem.manufacturer,
            sku: glassItem.sku,
            colorName: glassItem.name,
            coe: "\(glassItem.coe)",
            location: location,
            owner: UserSettings.shared.inventoryOwner
        )
    }

    // MARK: - Methods

    @MainActor
    private func generatePDF() async {
        print("🏷️ LabelDesignerView: generatePDF() called")

        guard let service = labelService else {
            print("❌ LabelDesignerView: labelService is nil!")
            errorMessage = "Service not initialized. Please try again."
            return
        }

        isGenerating = true
        errorMessage = nil

        // Convert CompleteInventoryItemModel to LabelData, duplicating for each quantity
        var labelData: [LabelData] = []

        print("🏷️ LabelDesignerView: Processing \(items.count) items...")
        for item in items {
            let glassItem = item.glassItem
            let inventory = item.inventory.first
            let location = item.locations.first

            // Calculate number of labels to generate (default to 1 if no inventory)
            let labelCount = inventory.map { Int($0.quantity) } ?? 1

            // Create one label for each physical item (e.g., 7 rods = 7 labels)
            for _ in 0..<labelCount {
                labelData.append(LabelData(
                    stableId: glassItem.stable_id,
                    manufacturer: glassItem.manufacturer,
                    sku: glassItem.sku,
                    colorName: glassItem.name,
                    coe: "\(glassItem.coe)",
                    location: location,
                    owner: UserSettings.shared.inventoryOwner
                ))
            }
        }

        print("🏷️ LabelDesignerView: Generating PDF for \(labelData.count) labels...")
        // Generate PDF with adjustments and start position
        guard let pdfURL = await service.generateLabelSheet(
            labels: labelData,
            format: selectedFormat,
            config: builderConfig,
            fontScale: effectiveFontScale,
            offsetX: offsetX,
            offsetY: offsetY,
            startRow: startRow,
            startColumn: startColumn
        ) else {
            print("❌ LabelDesignerView: PDF generation failed")
            errorMessage = "Failed to generate PDF. Please try again."
            isGenerating = false
            return
        }

        print("✅ LabelDesignerView: PDF generated at \(pdfURL.path)")
        generatedPDFURL = pdfURL
        isGenerating = false

        // Show share sheet
        showingShareSheet = true
    }

    // MARK: - Field Toggling

    /// Toggle a field in the builder config
    private func toggleField(_ field: LabelTextField) {
        withAnimation {
            if let index = builderConfig.textFields.firstIndex(of: field) {
                // Remove if already included
                builderConfig.textFields.remove(at: index)
            } else {
                // Add if not included
                builderConfig.textFields.append(field)
            }
        }
    }

    // MARK: - Preset Management

    /// Save changes to the currently loaded preset
    private func saveCurrentPreset() {
        guard let preset = currentPreset else { return }

        // Update the preset with current config
        var updatedPreset = preset
        updatedPreset.config = builderConfig
        updatedPreset.modifiedAt = Date()

        presetsManager.savePreset(updatedPreset)
        currentPreset = updatedPreset
    }

    // MARK: - Settings Persistence

    private var settingsKey: String {
        "labelPrinting.\(selectedFormat.name)"
    }

    /// Load the last used label format from UserDefaults
    private func loadLastUsedFormat() {
        let defaults = UserDefaults.standard
        if let formatName = defaults.string(forKey: "labelPrinting.lastUsedFormat") {
            // Try to match the saved format name to an AveryFormat case
            if formatName == AveryFormat.avery5160.name {
                selectedFormat = .avery5160
            } else if formatName == AveryFormat.avery18167.name {
                selectedFormat = .avery18167
            } else if formatName == AveryFormat.mrLabel184.name {
                selectedFormat = .mrLabel184
            } else if formatName == AveryFormat.avery5163.name {
                selectedFormat = .avery5163
            } else if formatName == AveryFormat.avery5167.name {
                selectedFormat = .avery5167
            }
            // If no match, keep default .avery5160
        }
    }

    /// Save the currently selected format to UserDefaults
    private func saveLastUsedFormat(_ format: AveryFormat) {
        let defaults = UserDefaults.standard
        defaults.set(format.name, forKey: "labelPrinting.lastUsedFormat")
    }

    private func loadSettings() {
        let defaults = UserDefaults.standard
        offsetX = defaults.double(forKey: "\(settingsKey).offsetX")
        offsetY = defaults.double(forKey: "\(settingsKey).offsetY")

        // Load builder config
        if let configData = defaults.data(forKey: "\(settingsKey).builderConfig"),
           let savedConfig = try? JSONDecoder().decode(LabelBuilderConfig.self, from: configData) {
            builderConfig = savedConfig

            // Try to match the loaded config to a preset
            updateCurrentPresetFromConfig()
        }
    }

    /// Update currentPreset to match the loaded config (if it matches a known preset)
    private func updateCurrentPresetFromConfig() {
        // Check all presets (built-in + user) to see if any match the current config
        if let matchingPreset = presetsManager.allPresets.first(where: { $0.config == builderConfig }) {
            currentPreset = matchingPreset
        } else {
            // No exact match - fall back to "Information Dense" as default
            if let infoDensePreset = presetsManager.allPresets.first(where: { $0.name == "Information Dense" }) {
                currentPreset = infoDensePreset
                builderConfig = infoDensePreset.config  // Sync config to match preset
            }
        }
    }

    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(offsetX, forKey: "\(settingsKey).offsetX")
        defaults.set(offsetY, forKey: "\(settingsKey).offsetY")

        // Save builder config
        if let configData = try? JSONEncoder().encode(builderConfig) {
            defaults.set(configData, forKey: "\(settingsKey).builderConfig")
        }
    }
}

// MARK: - Preset Selection Sheet

/// Sheet for selecting a preset configuration
private struct PresetSelectionSheet: View {
    let presets: [LabelBuilderPreset]
    let onSelect: (LabelBuilderPreset) -> Void
    let onDelete: (LabelBuilderPreset) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // User presets FIRST
                let userPresets = presets.filter { preset in
                    !LabelBuilderConfig.presets.contains(where: { $0.id == preset.id })
                }
                if !userPresets.isEmpty {
                    Section("My Presets") {
                        ForEach(userPresets) { preset in
                            PresetRow(preset: preset, onSelect: onSelect, showDelete: true, onDelete: onDelete)
                        }
                    }
                }

                // Built-in presets SECOND
                let builtInPresets = presets.filter { preset in
                    LabelBuilderConfig.presets.contains(where: { $0.id == preset.id })
                }
                if !builtInPresets.isEmpty {
                    Section("Built-in Presets") {
                        ForEach(builtInPresets) { preset in
                            PresetRow(preset: preset, onSelect: onSelect, showDelete: false, onDelete: nil)
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

/// Row showing a preset
private struct PresetRow: View {
    let preset: LabelBuilderPreset
    let onSelect: (LabelBuilderPreset) -> Void
    let showDelete: Bool
    let onDelete: ((LabelBuilderPreset) -> Void)?

    var body: some View {
        Button {
            onSelect(preset)
        } label: {
            HStack(spacing: 12) {
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

                Spacer()

                if showDelete, let onDelete = onDelete {
                    Button {
                        onDelete(preset)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .contentShape(Rectangle())  // Make entire row tappable
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Save Preset Sheet

/// Sheet for saving a new preset
private struct SavePresetSheet: View {
    @Binding var presetName: String
    @Binding var presetDescription: String
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
                    Text("This will save your current label configuration (QR position, size, and fields) as a preset for quick access later.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Save Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                    }
                    .disabled(presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Field Format Editor

/// Editor for customizing individual field formatting
private struct FieldFormatEditor: View {
    let field: LabelTextField
    @Binding var format: LabelFieldFormat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(field.rawValue)
                .font(.subheadline)
                .fontWeight(.medium)

            // Font Size Slider
            HStack(spacing: 12) {
                Text("Size")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .leading)

                Slider(value: $format.fontSize, in: 5...14, step: 0.5)
                    .tint(.blue)

                Text("\(Int(format.fontSize))pt")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                    .frame(width: 35, alignment: .trailing)
            }

            // Bold & Italic Toggles
            HStack(spacing: 12) {
                Text("Style")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .leading)

                Toggle("Bold", isOn: $format.bold)
                    .toggleStyle(.button)
                    .font(.caption)

                Toggle("Italic", isOn: $format.italic)
                    .toggleStyle(.button)
                    .font(.caption)

                Spacer()

                // Reset to default
                Button {
                    format = LabelFieldFormat.defaultFormat(for: field)
                } label: {
                    Text("Reset")
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }

            Divider()
        }
    }
}

#Preview {
    LabelDesignerView(items: [
        CompleteInventoryItemModel(
            glassItem: GlassItemModel(
                stable_id: "bullseye-clear-001",
                name: "Clear",
                sku: "1101",
                manufacturer: "be",
                mfr_notes: nil,
                coe: 96,
                mfr_status: "current"
            ),
            inventory: [
                InventoryModel(
                    id: UUID(),
                    item_stable_id: "bullseye-clear-001",
                    type: "rod",
                    quantity: 12.0
                )
            ],
            tags: [],
            userTags: []
        )
    ])
}

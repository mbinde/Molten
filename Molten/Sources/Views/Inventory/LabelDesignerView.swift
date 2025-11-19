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

    @State private var selectedFormat: AveryFormat = .avery5160
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false

    // Label builder configuration (replaces template)
    @State private var builderConfig: LabelBuilderConfig = .default

    @State private var isGenerating = false
    @State private var generatedPDFURL: URL?
    @State private var showingShareSheet = false
    @State private var errorMessage: String?

    // Print adjustments (persisted per format/template in UserDefaults)
    @State private var fontScale: Double = 1.0
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
    @State private var currentPresetName: String?
    @State private var isPresetModified: Bool = false
    @State private var presetToDelete: LabelBuilderPreset?
    @State private var showingDeleteConfirmation = false
    @State private var showingUnsavedChangesAlert = false
    @State private var isLoadingPreset: Bool = false  // Flag to suppress onChange during loading
    @State private var loadingTask: Task<Void, Never>?  // Track the loading task so we can cancel it
    @State private var showingEditPreset = false
    @State private var editingPresetName = ""
    @State private var editingPresetDescription = ""

    // CRITICAL: Cache service instance in @State to prevent recreation on every body evaluation
    @State private var labelService: LabelPrintingService?

    // Preview item selection
    @State private var selectedPreviewIndex: Int = 0

    var body: some View {
        NavigationStack {
            Form {
                formContent
            }
            .navigationTitle("Label Designer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showingPresetSheet) {
                presetSheet
            }
            .sheet(isPresented: $showingSavePreset) {
                savePresetSheet
            }
            .sheet(isPresented: $showingEditPreset) {
                editPresetSheet
            }
            .alert("Unsaved Changes", isPresented: $showingUnsavedChangesAlert) {
                Button("Discard Changes", role: .destructive) {
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                if let presetName = currentPresetName {
                    Text("You have unsaved changes to '\(presetName)'. Discard them?")
                } else {
                    Text("You have unsaved changes. Discard them?")
                }
            }
            .alert("Delete Preset?", isPresented: $showingDeleteConfirmation, presenting: presetToDelete) { preset in
                Button("Cancel", role: .cancel) {
                    presetToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    deletePreset(preset)
                }
            } message: { preset in
                Text("Are you sure you want to delete '\(preset.name)'? This action cannot be undone.")
            }
            .task {
                print("🏷️ LabelDesignerView: .task called")
                if labelService == nil {
                    print("🏷️ LabelDesignerView: Creating LabelPrintingService...")
                    labelService = LabelPrintingService()
                    print("✅ LabelDesignerView: LabelPrintingService created")
                } else {
                    print("✅ LabelDesignerView: LabelPrintingService already exists (cached)")
                }
                loadLastUsedFormat()
                await loadSettings()
            }
            .onChange(of: items) { _, _ in
                // Reset error when items change
                errorMessage = nil
            }
            .onChange(of: selectedFormat) { _, newFormat in
                saveLastUsedFormat(newFormat)
                saveSettings()
            }
            .onChange(of: fontScale) { _, _ in
                // Mark as modified if not currently loading
                if !isLoadingPreset && currentPresetName != nil {
                    isPresetModified = true
                }
                saveSettings()
            }
            .onChange(of: startRow) { _, _ in
                saveSettings()
            }
            .onChange(of: startColumn) { _, _ in
                saveSettings()
            }
            .onChange(of: offsetX) { _, _ in
                // Mark as modified if not currently loading
                if !isLoadingPreset && currentPresetName != nil {
                    isPresetModified = true
                }
                saveSettings()
            }
            .onChange(of: offsetY) { _, _ in
                // Mark as modified if not currently loading
                if !isLoadingPreset && currentPresetName != nil {
                    isPresetModified = true
                }
                saveSettings()
            }
            .onChange(of: builderConfig) { _, _ in
                // Cancel any pending loading task (user made a change)
                loadingTask?.cancel()
                loadingTask = nil

                // If we were loading, stop that now
                if isLoadingPreset {
                    isLoadingPreset = false
                    // Don't mark as modified - this is the loading completing
                } else if currentPresetName != nil {
                    // User made a change after loading completed
                    isPresetModified = true
                }
                saveSettings()
            }
        }
    }

    @ViewBuilder
    private var formContent: some View {
        labelCountSection

        Section {
                    if isSearching {
                        FormatSearchView(
                            searchText: $searchText,
                            isSearching: $isSearching,
                            selectedFormat: $selectedFormat,
                            filteredFormats: filteredFormats
                        )
                    } else {
                        SelectedFormatView(
                            selectedFormat: selectedFormat,
                            isSearching: $isSearching
                        )
                    }
                } header: {
                    Text("Label Format")
                } footer: {
                    if !isSearching {
                        Text("Tap to search from \(AveryFormat.flatList.count) available formats")
                            .font(.caption)
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
                            }

                            // Delete button (only for user presets, not built-in)
                            if !LabelBuilderConfig.presets.contains(where: { $0.name == presetName }) {
                                Button(role: .destructive) {
                                    // Find the preset to delete
                                    if let preset = presetsManager.allPresets.first(where: { $0.name == presetName }) {
                                        requestDeletePreset(preset)
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Overwrite button (only when preset is modified and not a built-in preset)
                    if isPresetModified,
                       let presetName = currentPresetName,
                       !LabelBuilderConfig.presets.contains(where: { $0.name == presetName }) {
                        Button {
                            overwriteCurrentPreset()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Overwrite Current Preset")
                            }
                        }
                        .foregroundColor(.orange)
                    }

                    Button {
                        showingSavePreset = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save Current as a New Preset")
                        }
                    }
                } header: {
                    Text("Presets")
                } footer: {
                    Text("Save your favorite label configurations as presets for quick access")
                        .font(.caption)
                }

                labelPreviewSection
                labelBuilderSection

                // Second preview before Advanced Options (just the image)
                if let previewData = sampleLabelData {
                    Section {
                        LabelPreviewView(
                            format: selectedFormat,
                            config: builderConfig,
                            sampleData: previewData,
                            fontScale: fontScale,
                            offsetX: offsetX,
                            offsetY: offsetY
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }

                // Advanced Layout Options Section (collapsible)
                Section {
                    DisclosureGroup(
                        isExpanded: $showAdvancedLayoutOptions,
                        content: {
                    VStack(alignment: .leading, spacing: 16) {
                        // Manufacturer Image Position
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Manufacturer Image")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Picker("Image Position", selection: $builderConfig.manufacturerImagePosition) {
                                ForEach(ManufacturerImagePosition.allCases, id: \.self) { position in
                                    Text(position.rawValue).tag(position)
                                }
                            }
                            .pickerStyle(.segmented)

                            // Overlap warning
                            if builderConfig.manufacturerImageOverlapsQR() {
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                    Text("Manufacturer image will be covered by QR code")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                .padding(.top, 4)
                            }

                            // Manufacturer Image Size slider
                            if builderConfig.manufacturerImagePosition != .none {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Image Size")
                                            .font(.caption)
                                        Spacer()
                                        Text("\(Int((builderConfig.manufacturerImageSize ?? 0.6) * 100))%")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .monospacedDigit()
                                    }

                                    Slider(
                                        value: Binding(
                                            get: { builderConfig.manufacturerImageSize ?? 0.6 },
                                            set: { builderConfig.manufacturerImageSize = $0 }
                                        ),
                                        in: 0.4...0.8,
                                        step: 0.05
                                    )
                                    .tint(.blue)

                                    HStack {
                                        Text("Smaller")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("Larger")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.top, 8)
                            }
                        }

                        // Per-field formatting controls
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Field Formatting")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.top, 8)

                            ForEach(builderConfig.textFields, id: \.self) { field in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(field.rawValue.capitalized)
                                        .font(.caption)
                                        .fontWeight(.medium)

                                    // Get current format or default
                                    let currentFormat = builderConfig.format(for: field)

                                    // Style picker (plain/bold/italic)
                                    HStack(spacing: 12) {
                                        Text("Style:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        Button {
                                            var format = builderConfig.format(for: field)
                                            format.bold = false
                                            format.italic = false
                                            builderConfig.fieldFormats[field] = format
                                        } label: {
                                            Text("Plain")
                                                .font(.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(!currentFormat.bold && !currentFormat.italic ? Color.blue : Color.clear)
                                                .foregroundColor(!currentFormat.bold && !currentFormat.italic ? .white : .primary)
                                                .cornerRadius(4)
                                        }
                                        .buttonStyle(.plain)

                                        Button {
                                            var format = builderConfig.format(for: field)
                                            format.bold = true
                                            format.italic = false
                                            builderConfig.fieldFormats[field] = format
                                        } label: {
                                            Text("Bold")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(currentFormat.bold && !currentFormat.italic ? Color.blue : Color.clear)
                                                .foregroundColor(currentFormat.bold && !currentFormat.italic ? .white : .primary)
                                                .cornerRadius(4)
                                        }
                                        .buttonStyle(.plain)

                                        Button {
                                            var format = builderConfig.format(for: field)
                                            format.bold = false
                                            format.italic = true
                                            builderConfig.fieldFormats[field] = format
                                        } label: {
                                            Text("Italic")
                                                .font(.caption)
                                                .italic()
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(!currentFormat.bold && currentFormat.italic ? Color.blue : Color.clear)
                                                .foregroundColor(!currentFormat.bold && currentFormat.italic ? .white : .primary)
                                                .cornerRadius(4)
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    // Font size slider
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("Font Size")
                                                .font(.caption)
                                            Spacer()
                                            Text("\(Int(currentFormat.fontSize))pt")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .monospacedDigit()
                                        }

                                        Slider(
                                            value: Binding(
                                                get: { builderConfig.format(for: field).fontSize },
                                                set: { newValue in
                                                    var format = builderConfig.format(for: field)
                                                    format.fontSize = newValue
                                                    builderConfig.fieldFormats[field] = format
                                                }
                                            ),
                                            in: 5...14,
                                            step: 0.5
                                        )
                                        .tint(.blue)

                                        HStack {
                                            Text("5pt")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text("14pt")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    Divider()
                                }
                            }
                        }
                    }
                        },
                        label: {
                            Label("Advanced Layout Options", systemImage: "slider.horizontal.3")
                        }
                    )
                }

                // Advanced Options Section (collapsed by default)
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
                            Label("Advanced Sheet Options", systemImage: "gearshape")
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
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                if isPresetModified {
                    showingUnsavedChangesAlert = true
                } else {
                    dismiss()
                }
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

    @ViewBuilder
    private var presetSheet: some View {
        PresetSelectionSheet(
            presets: presetsManager.allPresets,
            onSelect: { preset in
                // Load new preset (suppress onChange marking as modified)
                isLoadingPreset = true
                builderConfig = preset.config
                currentPresetName = preset.name
                showingPresetSheet = false

                // Reset flags after a short delay to ensure onChange has processed
                // Store the task so we can cancel it if user makes changes
                loadingTask = Task {
                    try? await Task.sleep(for: .milliseconds(10))
                    isLoadingPreset = false
                    isPresetModified = false
                    loadingTask = nil
                }
            },
            onDelete: { preset in
                requestDeletePreset(preset)
            }
        )
    }

    @ViewBuilder
    private var savePresetSheet: some View {
        SavePresetSheet(
            presetName: $newPresetName,
            presetDescription: $newPresetDescription,
            onSave: {
                let presetName = newPresetName.isEmpty ? "Custom Preset" : newPresetName
                let preset = LabelBuilderPreset(
                    name: presetName,
                    description: newPresetDescription.isEmpty ? "User-created preset" : newPresetDescription,
                    config: builderConfig
                )
                presetsManager.savePreset(preset)
                currentPresetName = presetName
                isPresetModified = false
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

    private var editPresetSheet: some View {
        SavePresetSheet(
            presetName: $editingPresetName,
            presetDescription: $editingPresetDescription,
            isEditing: true,
            onSave: {
                // Find the existing preset
                guard let presetName = currentPresetName,
                      let existingPreset = presetsManager.allPresets.first(where: { $0.name == presetName }) else {
                    showingEditPreset = false
                    return
                }

                // Create updated preset with new name/description but same config
                let updatedPreset = LabelBuilderPreset(
                    id: existingPreset.id,
                    name: editingPresetName.isEmpty ? existingPreset.name : editingPresetName,
                    description: editingPresetDescription,
                    config: existingPreset.config,
                    createdAt: existingPreset.createdAt,
                    modifiedAt: Date()
                )

                presetsManager.savePreset(updatedPreset)
                currentPresetName = updatedPreset.name
                editingPresetName = ""
                editingPresetDescription = ""
                showingEditPreset = false
            },
            onCancel: {
                editingPresetName = ""
                editingPresetDescription = ""
                showingEditPreset = false
            }
        )
    }

    // MARK: - Computed Properties

    /// Label builder section
    @ViewBuilder
    private var labelBuilderSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                // Font Size (at the top)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Font Size")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(Int(fontScale * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                            Spacer()
                        }

                        Slider(value: $fontScale, in: 0.2...2.0, step: 0.1) {
                            Text("Font Size")
                        }
                        .tint(.blue)

                        HStack {
                            Text("Smaller")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Larger")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Divider()

                // QR Code Position
                VStack(alignment: .leading, spacing: 6) {
                    Text("QR Code Position")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Picker("QR Position", selection: $builderConfig.qrPosition) {
                        ForEach(QRCodePosition.allCases, id: \.self) { position in
                            Text(position.rawValue).tag(position)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Overlap warning
                    if builderConfig.manufacturerImageOverlapsQR() {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                            Text("QR code will cover manufacturer image")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(.top, 4)
                    }

                    if builderConfig.qrPosition != .none {
                        // QR Size slider
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("QR Code Size")
                                    .font(.caption)
                                Spacer()
                                Text("\(Int((builderConfig.qrSize ?? 0.65) * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }

                            Slider(
                                value: Binding(
                                    get: { builderConfig.qrSize ?? 0.65 },
                                    set: { builderConfig.qrSize = $0 }
                                ),
                                in: 0.5...0.8,
                                step: 0.05
                            )
                            .tint(.blue)

                            HStack {
                                Text("Smaller")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("Larger")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
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
                            Text("Active Fields (in order):")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.bottom, 4)

                            ForEach(builderConfig.textFields, id: \.self) { field in
                                HStack(spacing: 8) {
                                    Image(systemName: "line.3.horizontal")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Button {
                                        toggleField(field)
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)

                                            Text(field.rawValue)
                                                .font(.subheadline)

                                            Spacer()

                                            if let index = builderConfig.textFields.firstIndex(of: field) {
                                                Text("#\(index + 1)")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                    .monospacedDigit()
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(6)
                            }
                            .onMove { from, to in
                                builderConfig.textFields.move(fromOffsets: from, toOffset: to)
                            }
                        }

                        Divider()
                            .padding(.vertical, 8)
                    }

                    // Available fields (not included)
                    let unusedFields = LabelTextField.allCases.filter { !builderConfig.textFields.contains($0) }
                    if !unusedFields.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Available Fields:")
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
            let validation = builderConfig.validateLayout(for: selectedFormat, fontScale: fontScale)
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
    }

    /// Label preview section
    @ViewBuilder
    private var labelPreviewSection: some View {
        if let previewData = sampleLabelData {
            Section {
                // Item selector (if multiple items)
                if items.count > 1 {
                    Picker("Preview Item", selection: $selectedPreviewIndex) {
                        ForEach(0..<items.count, id: \.self) { index in
                            let item = items[index]
                            Text("\(item.glassItem.manufacturer)  \(item.glassItem.sku) - \(item.glassItem.name)")
                                .lineLimit(1)
                                .tag(index)
                        }
                    }
                    .pickerStyle(.menu)
                }

                LabelPreviewView(
                    format: selectedFormat,
                    config: builderConfig,
                    sampleData: previewData,
                    fontScale: fontScale,
                    offsetX: offsetX,
                    offsetY: offsetY
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } header: {
                Text("Preview")
            } footer: {
                if items.count > 1 {
                    Text("Select which item to preview above. Red highlighting shows text that will be truncated in the PDF.")
                        .font(.caption)
                } else {
                    Text("Red highlighting shows text that will be truncated in the PDF.")
                        .font(.caption)
                }
            }
        }
    }

    /// Label count summary section
    private var labelCountSection: some View {
        Section {
            Text("\(totalLabelCount) label\(totalLabelCount == 1 ? "" : "s") to print")
                .font(.headline)

            Text("From \(items.count) item\(items.count == 1 ? "" : "s") selected")
                .font(.caption)
                .foregroundColor(.secondary)

            if totalLabelCount > selectedFormat.labelsPerSheet {
                Text("This will create \(numberOfSheets) sheet\(numberOfSheets == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    /// Filtered formats based on search text
    private var filteredFormats: [AveryFormat] {
        if searchText.isEmpty {
            // Show popular formats when no search
            return AveryFormat.allFormats["Popular"] ?? []
        }

        let searchLower = searchText.lowercased()
        return AveryFormat.flatList.filter { format in
            // Search by name (e.g., "5160", "Avery 5160")
            if format.name.lowercased().contains(searchLower) {
                return true
            }

            // Search by dimensions (e.g., "2.625", "1 x 2")
            let dimensions = formatDimensions(format).lowercased()
            if dimensions.contains(searchLower) {
                return true
            }

            // Search by label count (e.g., "30 labels")
            if "\(format.labelsPerSheet)".contains(searchLower) {
                return true
            }

            // Search by category
            for (category, formats) in AveryFormat.allFormats {
                if category.lowercased().contains(searchLower) && formats.contains(where: { $0.name == format.name }) {
                    return true
                }
            }

            return false
        }
    }

    /// Total number of labels to print (sum of all inventory quantities)
    private var totalLabelCount: Int {
        items.reduce(0) { total, item in
            let quantity = item.inventory.first?.quantity ?? 1.0
            return total + Int(quantity)
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
            fontScale: fontScale,
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

    /// Request deletion of a preset (shows confirmation alert)
    private func requestDeletePreset(_ preset: LabelBuilderPreset) {
        presetToDelete = preset
        showingDeleteConfirmation = true
    }

    /// Actually delete the preset (called after confirmation)
    private func deletePreset(_ preset: LabelBuilderPreset) {
        presetsManager.deletePreset(preset)

        // If we deleted the currently loaded preset, clear it
        if currentPresetName == preset.name {
            currentPresetName = nil
            isPresetModified = false
        }

        presetToDelete = nil
    }

    /// Overwrite the current preset with current settings
    private func overwriteCurrentPreset() {
        guard let presetName = currentPresetName else { return }

        // Find the existing preset
        guard let existingPreset = presetsManager.allPresets.first(where: { $0.name == presetName }) else {
            return
        }

        // Create updated preset with same ID and name but new config
        let updatedPreset = LabelBuilderPreset(
            id: existingPreset.id,
            name: existingPreset.name,
            description: existingPreset.description,
            config: builderConfig,
            createdAt: existingPreset.createdAt,
            modifiedAt: Date()
        )

        // Update the preset
        presetsManager.savePreset(updatedPreset)

        // Clear the modified flag
        isPresetModified = false
    }

    // MARK: - Format Display Helpers

    /// Format display name for picker (shows count and dimensions)
    private func formatDisplayName(_ format: AveryFormat) -> String {
        let dimensions = formatDimensions(format)
        return "\(format.name) (\(format.labelsPerSheet) labels, \(dimensions))"
    }

    /// Format dimensions as human-readable string
    private func formatDimensions(_ format: AveryFormat) -> String {
        let widthInches = format.labelWidth / 72.0
        let heightInches = format.labelHeight / 72.0

        // Format to remove unnecessary decimals
        let widthStr = formatInches(widthInches)
        let heightStr = formatInches(heightInches)

        return "\(widthStr)\" × \(heightStr)\""
    }

    /// Format inches value, using fractions for common values
    private func formatInches(_ inches: Double) -> String {
        // Common fractional values
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

        // For whole numbers, just show the integer
        if abs(inches - round(inches)) < 0.01 {
            return "\(Int(round(inches)))"
        }

        // Otherwise, show with one decimal
        return String(format: "%.1f", inches)
    }

    // MARK: - Settings Persistence

    private var settingsKey: String {
        "labelPrinting.\(selectedFormat.name)"
    }

    /// Load the last used label format from UserDefaults
    private func loadLastUsedFormat() {
        let defaults = UserDefaults.standard
        if let formatName = defaults.string(forKey: "labelPrinting.lastUsedFormat") {
            // Search through all available formats to find matching name
            if let matchedFormat = AveryFormat.flatList.first(where: { $0.name == formatName }) {
                selectedFormat = matchedFormat
            }
            // If no match, keep default .avery5160
        }
    }

    /// Save the currently selected format to UserDefaults
    private func saveLastUsedFormat(_ format: AveryFormat) {
        let defaults = UserDefaults.standard
        defaults.set(format.name, forKey: "labelPrinting.lastUsedFormat")
    }

    private func loadSettings() async {
        // Suppress onChange marking as modified during load
        isLoadingPreset = true

        let defaults = UserDefaults.standard
        fontScale = defaults.double(forKey: "\(settingsKey).fontScale")
        if fontScale == 0 { fontScale = 1.0 }  // Default if never set
        offsetX = defaults.double(forKey: "\(settingsKey).offsetX")
        offsetY = defaults.double(forKey: "\(settingsKey).offsetY")

        // Load current preset name
        currentPresetName = defaults.string(forKey: "\(settingsKey).currentPresetName")

        // Load builder config
        if let configData = defaults.data(forKey: "\(settingsKey).builderConfig"),
           let savedConfig = try? JSONDecoder().decode(LabelBuilderConfig.self, from: configData) {
            builderConfig = savedConfig
        } else {
            // No saved config - default to "Information Dense" preset
            if let informationDensePreset = LabelBuilderConfig.presets.first(where: { $0.name == "Information Dense" }) {
                builderConfig = informationDensePreset.config
                currentPresetName = informationDensePreset.name
            }
        }

        // Wait for next runloop to ensure all onChange handlers have finished
        try? await Task.sleep(for: .milliseconds(10))

        // After all loading is complete, reset flags
        isLoadingPreset = false
        isPresetModified = false
    }

    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(fontScale, forKey: "\(settingsKey).fontScale")
        defaults.set(offsetX, forKey: "\(settingsKey).offsetX")
        defaults.set(offsetY, forKey: "\(settingsKey).offsetY")

        // Save current preset name
        if let presetName = currentPresetName {
            defaults.set(presetName, forKey: "\(settingsKey).currentPresetName")
        } else {
            defaults.removeObject(forKey: "\(settingsKey).currentPresetName")
        }

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

/// Row showing a preset
private struct PresetRow: View {
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

// MARK: - Save Preset Sheet

/// Sheet for saving a new preset
private struct SavePresetSheet: View {
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

// MARK: - Format Search View

/// Search view for finding label formats
private struct FormatSearchView: View {
    @Binding var searchText: String
    @Binding var isSearching: Bool
    @Binding var selectedFormat: AveryFormat
    let filteredFormats: [AveryFormat]

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.body)

                TextField("Search label formats...", text: $searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Button("Cancel") {
                    withAnimation {
                        isSearching = false
                        searchText = ""
                    }
                }
                .font(.body)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }

        // Search results
        ForEach(filteredFormats, id: \.name) { format in
            FormatRow(format: format) {
                withAnimation {
                    selectedFormat = format
                    isSearching = false
                    searchText = ""
                }
            }
        }

        if filteredFormats.isEmpty && !searchText.isEmpty {
            Text("No formats match \"\(searchText)\"")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.vertical, 8)
        }
    }
}

/// Selected format display button
private struct SelectedFormatView: View {
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

/// Format row in search results
private struct FormatRow: View {
    let format: AveryFormat
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
        }
        .buttonStyle(.plain)
    }
}

/// Format details text (labels • dimensions • grid)
private struct FormatDetailsText: View {
    let format: AveryFormat

    var body: some View {
        HStack(spacing: 4) {
            Text("\(format.labelsPerSheet) labels")
            Text("•")
            Text(formatDimensions)
            Text("•")
            Text("\(format.columns)×\(format.rows)")
        }
        .font(.caption)
        .foregroundColor(.secondary)
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

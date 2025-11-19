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
                PresetsManagementSection(
                    presetsManager: presetsManager,
                    currentPresetName: $currentPresetName,
                    isPresetModified: $isPresetModified,
                    showingPresetSheet: $showingPresetSheet,
                    showingSavePreset: $showingSavePreset,
                    showingEditPreset: $showingEditPreset,
                    editingPresetName: $editingPresetName,
                    editingPresetDescription: $editingPresetDescription,
                    onRequestDelete: requestDeletePreset,
                    onOverwritePreset: overwriteCurrentPreset
                )

                labelPreviewSection

                LabelBuilderSection(
                    builderConfig: $builderConfig,
                    fontScale: $fontScale,
                    selectedFormat: selectedFormat,
                    onToggleField: toggleField
                )

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
                AdvancedLayoutOptionsSection(
                    builderConfig: $builderConfig,
                    showAdvancedLayoutOptions: $showAdvancedLayoutOptions
                )

                // Advanced Options Section (collapsed by default)
                AdvancedSheetOptionsSection(
                    showAdvancedOptions: $showAdvancedOptions,
                    startRow: $startRow,
                    startColumn: $startColumn,
                    offsetX: $offsetX,
                    offsetY: $offsetY,
                    selectedFormat: selectedFormat
                )

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
                Task {
                    try? await presetsManager.savePreset(preset)
                    await MainActor.run {
                        currentPresetName = presetName
                        isPresetModified = false
                        newPresetName = ""
                        newPresetDescription = ""
                        showingSavePreset = false
                    }
                }
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

                Task {
                    try? await presetsManager.savePreset(updatedPreset)
                    await MainActor.run {
                        currentPresetName = updatedPreset.name
                        editingPresetName = ""
                        editingPresetDescription = ""
                        showingEditPreset = false
                    }
                }
            },
            onCancel: {
                editingPresetName = ""
                editingPresetDescription = ""
                showingEditPreset = false
            }
        )
    }

    // MARK: - Computed Properties

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
                            Text("\(GlassManufacturers.fullName(for: item.glassItem.manufacturer) ?? item.glassItem.manufacturer)  \(item.glassItem.sku ?? "") - \(item.glassItem.name)")
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
        Task {
            try? await presetsManager.deletePreset(preset)

            await MainActor.run {
                // If we deleted the currently loaded preset, clear it
                if currentPresetName == preset.name {
                    currentPresetName = nil
                    isPresetModified = false
                }

                presetToDelete = nil
            }
        }
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
        Task {
            try? await presetsManager.savePreset(updatedPreset)

            await MainActor.run {
                // Clear the modified flag
                isPresetModified = false
            }
        }
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

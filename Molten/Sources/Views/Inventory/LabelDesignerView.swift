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

    @State private var selectedFormat: LabelGeometry = .defaultFormat
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    @State private var selectedShapeFilter: LabelShape?
    @State private var selectedBrandSlug: String?
    @State private var selectedPageFormat: LabelPageFormat = .letter  // Default to US Letter

    // Dimension filters (in inches)
    @State private var filterWidth: String = ""
    @State private var filterHeight: String = ""

    // Database-backed label formats
    @State private var databaseFormats: [LabelGeometry] = []
    @State private var availableBrands: [LabelBrand] = []
    private let labelDatabase = LabelDatabaseService.shared

    // Label builder configuration (replaces template)
    @State private var builderConfig: LabelBuilderConfig = .default

    @State private var isGenerating = false
    @State private var generatedPDFURL: URL?
    @State private var showingShareSheet = false
    @State private var errorMessage: String?

    // Print adjustments (persisted per format/template in UserDefaults)
    @State private var fontScale: Double = 1.0

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

    // Label format change alert when overwriting preset
    @State private var showingLabelChangeAlert = false
    @State private var pendingOverwritePreset: LabelBuilderPreset?  // Preset waiting to be overwritten

    // Switch to recommended label alert when loading preset
    @State private var showingSwitchToRecommendedAlert = false
    @State private var recommendedLabelName: String?  // The label name the preset recommends

    // CRITICAL: Cache service instance in @State to prevent recreation on every body evaluation
    @State private var labelService: LabelPrintingService?

    // Preview item selection
    @State private var selectedPreviewIndex: Int = 0

    // Weight-based label count overrides (key: "stableId:type", value: label count)
    @State private var labelCountOverrides: [String: Int] = [:]
    @State private var showingLabelCountInput: Bool = false

    // Label selection (inclusion-based - start with nothing selected)
    @State private var selectedInventoryIds: Set<UUID> = []  // What we want to print
    @State private var inventoryLabelCounts: [UUID: Int] = [:]  // Per-record label count overrides
    @State private var showingFilterSheet: Bool = false
    @State private var showAllSelected: Bool = false  // Override filters to show all selected items
    @State private var locationFilter: String? = nil
    @State private var dateAddedFilter: LabelDateFilter = .any
    @State private var dateModifiedFilter: LabelDateFilter = .any

    // MARK: - Navigation Content (extracted to reduce body complexity)

    @ViewBuilder
    private var navigationContent: some View {
        NavigationStack {
            Form {
                formContent
            }
            .navigationTitle("Label Designer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showingPresetSheet) { presetSheet }
            .sheet(isPresented: $showingSavePreset) { savePresetSheet }
            .sheet(isPresented: $showingEditPreset) { editPresetSheet }
            .sheet(isPresented: $showingLabelCountInput) { labelCountInputSheet }
            .sheet(isPresented: $showingFilterSheet) { filterSheet }
            .sheet(isPresented: $showingShareSheet) {
                if let pdfURL = generatedPDFURL {
                    ShareSheet(items: [pdfURL])
                }
            }
            .alert("Unsaved Changes", isPresented: $showingUnsavedChangesAlert) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Cancel", role: .cancel) { }
            } message: {
                unsavedChangesMessage
            }
            .alert("Delete Preset?", isPresented: $showingDeleteConfirmation, presenting: presetToDelete) { preset in
                Button("Cancel", role: .cancel) { presetToDelete = nil }
                Button("Delete", role: .destructive) { deletePreset(preset) }
            } message: { preset in
                Text("Are you sure you want to delete '\(preset.name)'? This action cannot be undone.")
            }
            .alert("Update Recommended Label?", isPresented: $showingLabelChangeAlert, presenting: pendingOverwritePreset) { preset in
                Button("Cancel", role: .cancel) { pendingOverwritePreset = nil }
                Button("Keep Current") { savePresetWithLabel(preset, labelName: preset.recommended_label) }
                Button("Update Label") { savePresetWithLabel(preset, labelName: selectedFormat.name) }
            } message: { preset in
                labelChangeMessage(for: preset)
            }
            .alert("Switch to Recommended Label?", isPresented: $showingSwitchToRecommendedAlert) {
                Button("Keep Current", role: .cancel) { recommendedLabelName = nil }
                Button("Switch") { switchToRecommendedLabel() }
            } message: {
                switchToRecommendedMessage
            }
        }
    }

    private var unsavedChangesMessage: Text {
        if let presetName = currentPresetName {
            return Text("You have unsaved changes to '\(presetName)'. Discard them?")
        } else {
            return Text("You have unsaved changes. Discard them?")
        }
    }

    private func labelChangeMessage(for preset: LabelBuilderPreset) -> Text {
        let existingLabel = preset.recommended_label ?? "none"
        return Text("This preset recommends '\(existingLabel)' but you're using '\(selectedFormat.name)'. Update the recommended label?")
    }

    private var switchToRecommendedMessage: Text {
        let recommended = recommendedLabelName ?? ""
        return Text("This preset was designed for '\(recommended)'. You're currently using '\(selectedFormat.name)'. Switch to the recommended label format?")
    }

    private var labelCountInputSheet: some View {
        WeightBasedLabelCountSheet(
            items: filteredItems,
            labelCountOverrides: $labelCountOverrides,
            onComplete: {
                showingLabelCountInput = false
                Task { await generatePDF() }
            },
            onCancel: { showingLabelCountInput = false }
        )
    }

    private var filterSheet: some View {
        LabelFilterSheet(
            items: items,
            selectedFormat: selectedFormat,
            selectedInventoryIds: $selectedInventoryIds,
            inventoryLabelCounts: $inventoryLabelCounts,
            showAllSelected: $showAllSelected,
            locationFilter: $locationFilter,
            dateAddedFilter: $dateAddedFilter,
            dateModifiedFilter: $dateModifiedFilter
        )
    }

    var body: some View {
        navigationContent
            .task {
                if labelService == nil {
                    labelService = LabelPrintingService()
                }

                // Load database formats (major brands + all barbell labels for default list)
                availableBrands = labelDatabase.getBrands()
                let majorBrands = availableBrands.filter { $0.isMajor }
                var formats: [LabelGeometry] = []
                for brand in majorBrands {
                    let brandFormats = labelDatabase.getProducts(brandSlug: brand.slug)
                    formats.append(contentsOf: brandFormats.map { $0.toLabelGeometry() })
                }

                // Also include ALL barbell/flag labels (from any brand, not just major)
                let barbellFormats = labelDatabase.getProducts(shape: .flag)
                for barbell in barbellFormats {
                    let geometry = barbell.toLabelGeometry()
                    // Avoid duplicates (some may already be from major brands)
                    if !formats.contains(where: { $0.name == geometry.name }) {
                        formats.append(geometry)
                    }
                }

                databaseFormats = formats.sorted { $0.name < $1.name }

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

    @ViewBuilder
    private var formContent: some View {
        labelCountSection

        Section {
                    // Shape filter buttons
                    ShapeFilterButtons(selectedShape: $selectedShapeFilter)

                    // Dimension filter (width × height) and page format (US Letter vs A4)
                    DimensionFilterRow(
                        filterWidth: $filterWidth,
                        filterHeight: $filterHeight,
                        pageFormat: $selectedPageFormat
                    )

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
                        let stats = labelDatabase.getStatistics()
                        Text("Tap to search from \(stats.products) formats across \(stats.brands) brands")
                            .font(.caption)
                    }
                }

                // Show label format preview immediately after selection
                if let previewData = sampleLabelData {
                    Section {
                        LabelPreviewView(
                            format: selectedFormat,
                            config: builderConfig,
                            sampleData: previewData,
                            fontScale: fontScale
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    } header: {
                        Text("Format Preview")
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
                            fontScale: fontScale
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

                // Label preview between layout and sheet options
                if let previewData = sampleLabelData {
                    Section {
                        LabelPreviewView(
                            format: selectedFormat,
                            config: builderConfig,
                            sampleData: previewData,
                            fontScale: fontScale
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }

                // Advanced Options Section (collapsed by default)
                AdvancedSheetOptionsSection(
                    showAdvancedOptions: $showAdvancedOptions,
                    startRow: $startRow,
                    startColumn: $startColumn,
                    builderConfig: $builderConfig,
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
            Button("Done") {
                if isPresetModified {
                    showingUnsavedChangesAlert = true
                } else {
                    dismiss()
                }
            }
            .frame(minWidth: 100, alignment: .leading)
            .accessibilityIdentifier("label_designer_done")
        }

        ToolbarItem(placement: .primaryAction) {
            Button("Generate") {
                // Check if we need to ask for label counts for weight-based items
                let needsInput = itemsNeedingLabelCountInput.filter { item in
                    // Only show sheet if user hasn't already set an override
                    labelCountOverrides[item.id] == nil
                }

                if !needsInput.isEmpty {
                    // Show sheet to get label counts
                    showingLabelCountInput = true
                } else {
                    Task {
                        await generatePDF()
                    }
                }
            }
            .disabled(isGenerating || filteredItems.isEmpty)
            .accessibilityIdentifier("label_designer_generate_pdf")
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

                // Check if preset recommends a different label format
                if let recommended = preset.recommended_label, recommended != selectedFormat.name {
                    recommendedLabelName = recommended
                    showingSwitchToRecommendedAlert = true
                }

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
                    config: builderConfig,
                    recommended_label: selectedFormat.name
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
                            let manufacturer = GlassManufacturers.fullName(for: item.glassItem.manufacturer) ?? item.glassItem.manufacturer
                            let sku = item.glassItem.sku ?? ""
                            Text("\(item.glassItem.name) (\(manufacturer) · \(sku))")
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
                    fontScale: fontScale
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

    /// Total inventory record count (before filtering)
    private var totalInventoryRecordCount: Int {
        items.reduce(0) { $0 + $1.inventory.count }
    }

    /// Filtered inventory record count
    private var filteredInventoryRecordCount: Int {
        filteredItems.reduce(0) { $0 + $1.inventory.count }
    }

    /// Label count summary section
    private var labelCountSection: some View {
        Section {
            if hasSelectedLabels {
                // Items selected - show summary and small filter button
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(totalLabelCount) label\(totalLabelCount == 1 ? "" : "s") to print")
                            .font(.headline)

                        Text("From \(selectedInventoryIds.count) inventory type\(selectedInventoryIds.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if totalLabelCount > 0 {
                            if totalLabelCount < selectedFormat.labelsPerSheet {
                                Text("Less than 1 sheet (\(selectedFormat.labelsPerSheet) labels per sheet)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else if totalLabelCount > selectedFormat.labelsPerSheet {
                                Text("This will create \(numberOfSheets) sheets")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Exactly 1 full sheet")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Spacer()

                    Button {
                        showingFilterSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checklist")
                            Text("Edit")
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                // Nothing selected - show prominent button to select labels
                VStack(spacing: 12) {
                    Text("No labels selected")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("Select which inventory items you want to print labels for")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        showingFilterSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checklist")
                            Text("Select Labels to Print")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
    }

    /// Whether any filters are active (location or date filters)
    private var hasActiveFilters: Bool {
        locationFilter != nil || dateAddedFilter != .any || dateModifiedFilter != .any
    }

    /// Whether any labels are selected for printing
    private var hasSelectedLabels: Bool {
        !selectedInventoryIds.isEmpty
    }

    /// Items that are selected for printing
    /// Only returns items with at least one selected inventory record
    private var filteredItems: [CompleteInventoryItemModel] {
        // Only include inventory records that are explicitly selected
        items.compactMap { item in
            let selectedInventory = item.inventory.filter { record in
                selectedInventoryIds.contains(record.id)
            }

            guard !selectedInventory.isEmpty else { return nil }

            return CompleteInventoryItemModel(
                catalogItem: item.catalogItem,
                inventory: selectedInventory,
                tags: item.tags,
                userTags: item.userTags,
                rating: item.rating
            )
        }
    }

    /// Parsed dimension filter values (with tolerance for approximate matching)
    private var parsedDimensionFilters: (width: Double?, height: Double?) {
        let width = Double(filterWidth.trimmingCharacters(in: .whitespaces))
        let height = Double(filterHeight.trimmingCharacters(in: .whitespaces))
        return (width, height)
    }

    /// Whether any dimension filter is active
    private var hasDimensionFilter: Bool {
        parsedDimensionFilters.width != nil || parsedDimensionFilters.height != nil
    }

    /// Filtered formats based on shape filter, dimension filter, page format, and search text
    /// Uses database for searching 2,600+ label formats
    private var filteredFormats: [LabelGeometry] {
        let dims = parsedDimensionFilters
        // Use a small tolerance (0.1") for dimension matching
        let tolerance = 0.1
        let pageFormat = selectedPageFormat.databaseValue  // nil for "all"

        // Use database search if we have search text
        // Pass all filters to database so LIMIT is applied AFTER filtering
        if !searchText.isEmpty {
            let results = labelDatabase.searchProducts(
                query: searchText,
                shape: selectedShapeFilter,
                pageFormat: pageFormat,
                minWidth: dims.width.map { $0 - tolerance },
                maxWidth: dims.width.map { $0 + tolerance },
                minHeight: dims.height.map { $0 - tolerance },
                maxHeight: dims.height.map { $0 + tolerance },
                limit: 100
            )
            return results.map { $0.toLabelGeometry() }
        }

        // If filtering by brand
        if let brandSlug = selectedBrandSlug {
            let results = labelDatabase.getProducts(brandSlug: brandSlug)
            var formats = results.map { $0.toLabelGeometry() }

            if let shape = selectedShapeFilter {
                formats = formats.filter { $0.shape == shape }
            }

            // Apply page format filter
            if let pageFormat = pageFormat {
                formats = formats.filter { $0.pageFormat == pageFormat }
            }

            // Apply dimension filters
            formats = applyDimensionFilter(to: formats, width: dims.width, height: dims.height, tolerance: tolerance)

            return formats
        }

        // Query with shape, page format, and/or dimension filters
        if selectedShapeFilter != nil || hasDimensionFilter || pageFormat != nil {
            let results = labelDatabase.getProducts(
                shape: selectedShapeFilter,
                pageFormat: pageFormat,
                minWidth: dims.width.map { $0 - tolerance },
                maxWidth: dims.width.map { $0 + tolerance },
                minHeight: dims.height.map { $0 - tolerance },
                maxHeight: dims.height.map { $0 + tolerance }
            )
            return results.map { $0.toLabelGeometry() }.sorted { $0.name < $1.name }
        }

        return databaseFormats
    }

    /// Apply dimension filter to a list of formats (for post-search filtering)
    private func applyDimensionFilter(
        to formats: [LabelGeometry],
        width: Double?,
        height: Double?,
        tolerance: Double
    ) -> [LabelGeometry] {
        formats.filter { format in
            if let w = width {
                let formatWidth = format.labelWidth / 72.0  // Convert points to inches
                if abs(formatWidth - w) > tolerance {
                    return false
                }
            }
            if let h = height {
                let formatHeight = format.labelHeight / 72.0  // Convert points to inches
                if abs(formatHeight - h) > tolerance {
                    return false
                }
            }
            return true
        }
    }

    /// Total number of labels to print (uses LabelCountCalculator for proper handling of weight-based types)
    private var totalLabelCount: Int {
        LabelCountCalculator.calculateTotalLabelCount(
            for: filteredItems,
            userOverrides: labelCountOverrides,
            inventoryRecordOverrides: inventoryLabelCounts
        )
    }

    /// Items that need user input for label count (weight-based items without containerCount)
    private var itemsNeedingLabelCountInput: [LabelCountCalculator.WeightBasedItem] {
        LabelCountCalculator.itemsNeedingLabelCountInput(from: filteredItems)
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
        let inventory = item.inventory.first  // Use first inventory record for type info

        return LabelData(
            stableId: glassItem.stable_id,
            manufacturer: glassItem.manufacturer,
            sku: glassItem.sku,
            colorName: glassItem.name,
            coe: "\(glassItem.coe)",
            location: location,
            owner: UserSettings.shared.inventoryOwner,
            inventoryType: inventory?.type,
            inventorySubtype: inventory?.subtype,
            inventorySubsubtype: inventory?.subsubtype
        )
    }

    // MARK: - Methods

    @MainActor
    private func generatePDF() async {

        guard let service = labelService else {
            print("❌ LabelDesignerView: labelService is nil!")
            errorMessage = "Service not initialized. Please try again."
            return
        }

        isGenerating = true
        errorMessage = nil

        // Generate LabelData with proper type info for QR codes (uses filtered items)
        let labelData = LabelCountCalculator.generateLabelData(
            for: filteredItems,
            userOverrides: labelCountOverrides,
            inventoryRecordOverrides: inventoryLabelCounts,
            owner: UserSettings.shared.inventoryOwner
        )

        // Generate PDF with adjustments and start position
        guard let pdfURL = await service.generateLabelSheet(
            labels: labelData,
            format: selectedFormat,
            config: builderConfig,
            fontScale: fontScale,
            startRow: startRow,
            startColumn: startColumn
        ) else {
            print("❌ LabelDesignerView: PDF generation failed")
            errorMessage = "Failed to generate PDF. Please try again."
            isGenerating = false
            return
        }

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

        // Check if label format has changed
        let existingLabel = existingPreset.recommended_label
        let currentLabel = selectedFormat.name

        if let existingLabel = existingLabel, existingLabel != currentLabel {
            // Label format is different - ask user what to do
            pendingOverwritePreset = existingPreset
            showingLabelChangeAlert = true
        } else {
            // No label change (or no previous label) - save with current label
            savePresetWithLabel(existingPreset, labelName: currentLabel)
        }
    }

    /// Switch to the recommended label format
    private func switchToRecommendedLabel() {
        guard let labelName = recommendedLabelName else { return }

        // Search database for the label format by name
        let results = labelDatabase.searchProducts(query: labelName, limit: 10)
        if let matchedFormat = results.first(where: { $0.displayName == labelName })?.toLabelGeometry() {
            selectedFormat = matchedFormat
        }

        recommendedLabelName = nil
    }

    /// Save preset with specified label format
    private func savePresetWithLabel(_ existingPreset: LabelBuilderPreset, labelName: String?) {
        let updatedPreset = LabelBuilderPreset(
            id: existingPreset.id,
            name: existingPreset.name,
            description: existingPreset.description,
            config: builderConfig,
            createdAt: existingPreset.createdAt,
            modifiedAt: Date(),
            recommended_label: labelName
        )

        Task {
            try? await presetsManager.savePreset(updatedPreset)

            await MainActor.run {
                isPresetModified = false
                pendingOverwritePreset = nil
            }
        }
    }

    // MARK: - Format Display Helpers

    /// Format display name for picker (shows count and dimensions)
    private func formatDisplayName(_ format: LabelGeometry) -> String {
        let dimensions = formatDimensions(format)
        return "\(format.name) (\(format.labelsPerSheet) labels, \(dimensions))"
    }

    /// Format dimensions as human-readable string
    private func formatDimensions(_ format: LabelGeometry) -> String {
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
            // Search database for the saved format name
            let results = labelDatabase.searchProducts(query: formatName, limit: 1)
            if let matchedFormat = results.first?.toLabelGeometry(), matchedFormat.name == formatName {
                selectedFormat = matchedFormat
            }
            // If no exact match, keep default
        }
    }

    /// Save the currently selected format to UserDefaults
    private func saveLastUsedFormat(_ format: LabelGeometry) {
        let defaults = UserDefaults.standard
        defaults.set(format.name, forKey: "labelPrinting.lastUsedFormat")
    }

    private func loadSettings() async {
        // Suppress onChange marking as modified during load
        isLoadingPreset = true

        let defaults = UserDefaults.standard
        fontScale = defaults.double(forKey: "\(settingsKey).fontScale")
        if fontScale == 0 { fontScale = 1.0 }  // Default if never set

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
        // Note: positionHorizontal/positionVertical are now saved as part of builderConfig

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

// MARK: - Weight-Based Label Count Input Sheet

/// Sheet for asking how many labels to print for weight-based items (frit, powder, enamel)
/// Similar to the checkout sheet in ShoppingListView that asks for jar counts
struct WeightBasedLabelCountSheet: View {
    let items: [CompleteInventoryItemModel]
    @Binding var labelCountOverrides: [String: Int]
    let onComplete: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var localCounts: [String: Int] = [:]

    /// Get the weight-based inventory records that need label count input
    /// Only includes items stored by weight (no containerCount), not items stored by jars
    private var weightBasedItems: [WeightBasedItemInfo] {
        var result: [WeightBasedItemInfo] = []
        for item in items {
            for inventory in item.inventory {
                if inventory.isWeightBasedType {
                    // Only include if stored by weight (no containerCount set)
                    // If they track by jars, we already know how many labels to print
                    if inventory.containerCount == nil || inventory.containerCount == 0 {
                        result.append(WeightBasedItemInfo(item: item, inventory: inventory))
                    }
                }
            }
        }
        return result
    }

    struct WeightBasedItemInfo: Identifiable {
        let item: CompleteInventoryItemModel
        let inventory: InventoryModel

        var id: String { "\(item.catalogItem.stable_id):\(inventory.type)" }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header explanation
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("How many labels?")
                        .font(.headline)

                    Text("For weight-based items like frit and powder, enter how many labels you want to print (typically one per jar).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                #if os(iOS)
                .background(Color(UIColor.systemGroupedBackground))
                #else
                .background(Color(nsColor: NSColor.windowBackgroundColor))
                #endif

                // Items list
                List {
                    ForEach(weightBasedItems) { item in
                        HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
                            // Item info
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.item.catalogItem.name)
                                    .font(.headline)
                                    .lineLimit(1)

                                HStack(spacing: 4) {
                                    Text(item.inventory.type.capitalized)
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(DesignSystem.Colors.accentWarning.opacity(0.2))
                                        .foregroundColor(DesignSystem.Colors.accentWarning)
                                        .cornerRadius(4)

                                    if let containerCount = item.inventory.containerCount, containerCount > 0 {
                                        Text("\(Int(containerCount)) jar\(containerCount == 1 ? "" : "s") tracked")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }

                            Spacer()

                            // Label count input
                            VStack(alignment: .trailing, spacing: 2) {
                                TextField("Labels", value: Binding(
                                    get: { localCounts[item.id] ?? defaultCount(for: item) },
                                    set: { localCounts[item.id] = max(0, $0) }
                                ), format: .number)
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                                #if os(iOS)
                                .textFieldStyle(.roundedBorder)
                                #endif

                                Text("label\(labelCount(for: item) == 1 ? "" : "s")")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Label Counts")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        // Save local counts to the binding
                        for (key, value) in localCounts {
                            labelCountOverrides[key] = value
                        }
                        // Also save defaults for items that weren't modified
                        for item in weightBasedItems {
                            if labelCountOverrides[item.id] == nil {
                                labelCountOverrides[item.id] = defaultCount(for: item)
                            }
                        }
                        onComplete()
                    }
                }
            }
            .onAppear {
                // Initialize local counts from existing overrides or defaults
                for item in weightBasedItems {
                    localCounts[item.id] = labelCountOverrides[item.id] ?? defaultCount(for: item)
                }
            }
        }
    }

    private func defaultCount(for item: WeightBasedItemInfo) -> Int {
        // Use containerCount if available, otherwise default to 1
        if let containerCount = item.inventory.containerCount, containerCount > 0 {
            return Int(containerCount)
        }
        return 1
    }

    private func labelCount(for item: WeightBasedItemInfo) -> Int {
        localCounts[item.id] ?? defaultCount(for: item)
    }
}

// MARK: - Preset Selection Sheet

/// Sheet for selecting a preset configuration

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

    var body: some View {
        NavigationStack {
            Form {
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

                Section("Label Format") {
                    Picker("Format", selection: $selectedFormat) {
                        Text("Avery 5160 (30 labels, 1\" × 2⅝\")").tag(AveryFormat.avery5160)
                        Text("Avery 18167 (80 labels, ½\" × 1¾\")").tag(AveryFormat.avery18167)
                        Text("Mr-Label MR184 (30 labels, 1\" × 2⅝\")").tag(AveryFormat.mrLabel184)
                        // Temporarily hidden for testing - uncomment to enable
                        // Text("Avery 5163 (10 labels, 2\" × 4\")").tag(AveryFormat.avery5163)
                        // Text("Avery 5167 (80 labels, ½\" × 1¾\")").tag(AveryFormat.avery5167)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedFormat.name)
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("\(selectedFormat.labelsPerSheet) labels per sheet (\(selectedFormat.columns)×\(selectedFormat.rows))")
                            .font(.caption2)
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

                    Button {
                        showingSavePreset = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save Current as Preset")
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

                // Label Builder Section
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

                            if builderConfig.qrPosition != .none {
                                // QR Size slider
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("QR Code Size")
                                            .font(.caption)
                                        Spacer()
                                        Text("\(Int(builderConfig.qrSize * 100))%")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .monospacedDigit()
                                    }

                                    Slider(value: $builderConfig.qrSize, in: 0.5...0.8, step: 0.05)
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
                            Label("Advanced Options", systemImage: "gearshape")
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
                        builderConfig = preset.config
                        showingPresetSheet = false
                    },
                    onDelete: { preset in
                        presetsManager.deletePreset(preset)
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
            .onAppear {
                print("🏷️ LabelDesignerView: .onAppear called")
                if labelService == nil {
                    print("🏷️ LabelDesignerView: Creating LabelPrintingService...")
                    labelService = LabelPrintingService()
                    print("✅ LabelDesignerView: LabelPrintingService created")
                } else {
                    print("✅ LabelDesignerView: LabelPrintingService already exists (cached)")
                }
                loadSettings()
            }
            .onChange(of: selectedFormat) { _, _ in
                loadSettings()
            }
            .onChange(of: fontScale) { _, _ in
                saveSettings()
            }
            .onChange(of: offsetX) { _, _ in
                saveSettings()
            }
            .onChange(of: offsetY) { _, _ in
                saveSettings()
            }
            .onChange(of: builderConfig) { _, _ in
                saveSettings()
            }
        }
    }

    // MARK: - Computed Properties

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
            location: location?.location
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
                    location: location?.location
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

    // MARK: - Settings Persistence

    private var settingsKey: String {
        "labelPrinting.\(selectedFormat.name)"
    }

    private func loadSettings() {
        let defaults = UserDefaults.standard
        fontScale = defaults.double(forKey: "\(settingsKey).fontScale")
        if fontScale == 0 { fontScale = 1.0 }  // Default if never set
        offsetX = defaults.double(forKey: "\(settingsKey).offsetX")
        offsetY = defaults.double(forKey: "\(settingsKey).offsetY")

        // Load builder config
        if let configData = defaults.data(forKey: "\(settingsKey).builderConfig"),
           let savedConfig = try? JSONDecoder().decode(LabelBuilderConfig.self, from: configData) {
            builderConfig = savedConfig
        }
    }

    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(fontScale, forKey: "\(settingsKey).fontScale")
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
                // Built-in presets
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

                // User presets
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

#Preview {
    LabelDesignerView(items: [
        CompleteInventoryItemModel(
            glassItem: GlassItemModel(
                stable_id: "bullseye-clear-001",
                natural_key: "bullseye-clear-001",
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
            userTags: [],
            locations: []
        )
    ])
}

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
    @State private var selectedTemplate: LabelTemplate = .informationDense
    @State private var isGenerating = false
    @State private var generatedPDFURL: URL?
    @State private var showingShareSheet = false
    @State private var errorMessage: String?

    // CRITICAL: Cache service instance in @State to prevent recreation on every body evaluation
    @State private var labelService: LabelPrintingService?

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
                        Text("Avery 5163 (10 labels, 2\" × 4\")").tag(AveryFormat.avery5163)
                        Text("Avery 5167 (80 labels, ½\" × 1¾\")").tag(AveryFormat.avery5167)
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

                Section("Label Template") {
                    Picker("Template", selection: $selectedTemplate) {
                        Text("Information Dense").tag(LabelTemplate.informationDense)
                        Text("QR Focused").tag(LabelTemplate.qrFocused)
                        Text("Location Based").tag(LabelTemplate.locationBased)
                    }

                    // Template description
                    VStack(alignment: .leading, spacing: 4) {
                        Text(templateDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Template field preview
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Includes:")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        ForEach(templateFields, id: \.self) { field in
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                                Text(field)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Label Preview Section
                if let previewData = sampleLabelData {
                    Section {
                        LabelPreviewView(
                            format: selectedFormat,
                            template: selectedTemplate,
                            sampleData: previewData
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    } header: {
                        Text("Preview")
                    }
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
            .onAppear {
                print("🏷️ LabelDesignerView: .onAppear called")
                if labelService == nil {
                    print("🏷️ LabelDesignerView: Creating LabelPrintingService...")
                    labelService = LabelPrintingService()
                    print("✅ LabelDesignerView: LabelPrintingService created")
                } else {
                    print("✅ LabelDesignerView: LabelPrintingService already exists (cached)")
                }
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

    private var templateDescription: String {
        if selectedTemplate == .informationDense {
            return "Maximum information with QR code. Best for standard rod labels."
        } else if selectedTemplate == .qrFocused {
            return "Large QR code with minimal text. Best for small labels where scanning is priority."
        } else if selectedTemplate == .locationBased {
            return "Includes location information. Best for box and shelf labels."
        } else {
            return "Standard label template"
        }
    }

    private var templateFields: [String] {
        var fields: [String] = []
        if selectedTemplate.includeQRCode { fields.append("QR Code") }
        if selectedTemplate.includeManufacturer { fields.append("Manufacturer") }
        if selectedTemplate.includeSKU { fields.append("SKU") }
        if selectedTemplate.includeColor { fields.append("Color Name") }
        if selectedTemplate.includeCOE { fields.append("COE") }
        if selectedTemplate.includeQuantity { fields.append("Quantity") }
        if selectedTemplate.includeLocation { fields.append("Location") }
        return fields
    }

    private var sampleLabelData: LabelData? {
        guard let firstItem = items.first else { return nil }

        let glassItem = firstItem.glassItem
        let location = firstItem.locations.first

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
        // Generate PDF
        guard let pdfURL = await service.generateLabelSheet(
            labels: labelData,
            format: selectedFormat,
            template: selectedTemplate
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

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

    private let labelService = LabelPrintingService()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("\(items.count) item\(items.count == 1 ? "" : "s") selected")
                        .font(.headline)

                    if items.count > selectedFormat.labelsPerSheet {
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
        }
    }

    // MARK: - Computed Properties

    private var numberOfSheets: Int {
        Int(ceil(Double(items.count) / Double(selectedFormat.labelsPerSheet)))
    }

    private var templateDescription: String {
        switch selectedTemplate {
        case .informationDense:
            return "Maximum information with QR code. Best for standard rod labels."
        case .qrFocused:
            return "Large QR code with minimal text. Best for small labels where scanning is priority."
        case .locationBased:
            return "Includes location information. Best for box and shelf labels."
        default:
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

    // MARK: - Methods

    @MainActor
    private func generatePDF() async {
        isGenerating = true
        errorMessage = nil

        // Convert CompleteInventoryItemModel to LabelData
        let labelData = items.map { item in
            let glassItem = item.glassItem
            let inventory = item.inventories.first // Use first inventory for quantity/location

            return LabelData(
                naturalKey: glassItem.natural_key,
                manufacturer: glassItem.manufacturer,
                sku: glassItem.sku,
                colorName: glassItem.color_name,
                coe: glassItem.coe,
                quantity: inventory.map { formatQuantity($0) },
                location: inventory?.location
            )
        }

        // Generate PDF
        guard let pdfURL = await labelService.generateLabelSheet(
            labels: labelData,
            format: selectedFormat,
            template: selectedTemplate
        ) else {
            errorMessage = "Failed to generate PDF. Please try again."
            isGenerating = false
            return
        }

        generatedPDFURL = pdfURL
        isGenerating = false

        // Show share sheet
        showingShareSheet = true
    }

    private func formatQuantity(_ inventory: InventoryModel) -> String {
        let qty = inventory.quantity
        let type = inventory.type

        if qty == 1.0 {
            return "1 \(type)"
        } else if qty.truncatingRemainder(dividingBy: 1.0) == 0 {
            return "\(Int(qty)) \(type)s"
        } else {
            return "\(qty) \(type)s"
        }
    }
}

/// Share sheet for exporting PDFs
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

#Preview {
    LabelDesignerView(items: [
        CompleteInventoryItemModel(
            glassItem: GlassItemModel(
                natural_key: "bullseye-clear-001",
                manufacturer: "be",
                sku: "1101",
                color_name: "Clear",
                coe: "96",
                type: "rod",
                stable_id: "bullseye-clear-001"
            ),
            inventories: [
                InventoryModel(
                    id: UUID(),
                    item_natural_key: "bullseye-clear-001",
                    type: "rod",
                    quantity: 12.0,
                    location: "Shelf A"
                )
            ],
            tags: []
        )
    ])
}

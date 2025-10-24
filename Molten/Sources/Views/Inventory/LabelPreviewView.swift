//
//  LabelPreviewView.swift
//  Molten
//
//  Visual preview of label appearance based on format and template
//

import SwiftUI

/// Preview component showing what a label will look like
struct LabelPreviewView: View {
    let format: AveryFormat
    let config: LabelBuilderConfig
    let sampleData: LabelData
    var fontScale: Double = 1.0
    var offsetX: Double = 0.0
    var offsetY: Double = 0.0

    // CRITICAL: Cache service instance in @State to prevent recreation on every body evaluation
    @State private var labelService: LabelPrintingService?

    // Scale factor to make labels visible on screen
    private var scaleFactor: CGFloat {
        // Scale to fit nicely in preview area (roughly 200-300pt wide)
        let targetWidth: CGFloat = 280
        return targetWidth / format.labelWidth
    }

    private var previewWidth: CGFloat {
        format.labelWidth * scaleFactor
    }

    private var previewHeight: CGFloat {
        format.labelHeight * scaleFactor
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("Label Preview")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            // Label preview with border
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white)
                    )

                // Label content based on QR position
                buildLabelContent()
                    .frame(height: previewHeight - 8)
                    .padding(.vertical, 4)
                    .offset(x: offsetX * scaleFactor, y: offsetY * scaleFactor)
            }
            .frame(width: previewWidth, height: previewHeight)

            // Dimensions
            Text("\(format.name) - \(formattedDimensions)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(8)
        .onAppear {
            if labelService == nil {
                labelService = LabelPrintingService()
            }
        }
    }

    // MARK: - Label Content Builder

    @ViewBuilder
    private func buildLabelContent() -> some View {
        switch config.qrPosition {
        case .none:
            // No QR code - text only
            HStack(alignment: .top, spacing: 0) {
                buildTextContent()
                    .padding(.leading, 8 * scaleFactor)
                    .padding(.trailing, 4 * scaleFactor)
                    .padding(.top, 4 * scaleFactor)
                Spacer()
            }

        case .left:
            // QR code on left, text on right
            HStack(alignment: .center, spacing: 0) {
                if let service = labelService {
                    let qrSize = previewHeight * config.qrSize
                    QRCodeView(stableId: sampleData.stableId, service: service)
                        .frame(width: qrSize * 0.9, height: qrSize * 0.9)
                        .padding(.leading, 4 * scaleFactor)
                }

                VStack(alignment: .leading, spacing: 0) {
                    buildTextContent()
                        .padding(.leading, 4 * scaleFactor)
                        .padding(.trailing, 4 * scaleFactor)
                        .padding(.top, 4 * scaleFactor)
                    Spacer()
                }
            }

        case .right:
            // Text on left, QR code on right
            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    buildTextContent()
                        .padding(.leading, 8 * scaleFactor)
                        .padding(.trailing, 4 * scaleFactor)
                        .padding(.top, 4 * scaleFactor)
                    Spacer()
                }

                if let service = labelService {
                    let qrSize = previewHeight * config.qrSize
                    QRCodeView(stableId: sampleData.stableId, service: service)
                        .frame(width: qrSize * 0.9, height: qrSize * 0.9)
                        .padding(.trailing, 4 * scaleFactor)
                }
            }

        case .both:
            // QR codes on both sides, text in middle
            HStack(alignment: .center, spacing: 0) {
                if let service = labelService {
                    let qrSize = previewHeight * config.qrSize
                    QRCodeView(stableId: sampleData.stableId, service: service)
                        .frame(width: qrSize * 0.9, height: qrSize * 0.9)
                        .padding(.leading, 4 * scaleFactor)
                }

                VStack(alignment: .leading, spacing: 0) {
                    buildTextContent()
                        .padding(.leading, 4 * scaleFactor)
                        .padding(.trailing, 4 * scaleFactor)
                        .padding(.top, 4 * scaleFactor)
                    Spacer()
                }

                if let service = labelService {
                    let qrSize = previewHeight * config.qrSize
                    QRCodeView(stableId: sampleData.stableId, service: service)
                        .frame(width: qrSize * 0.9, height: qrSize * 0.9)
                        .padding(.trailing, 4 * scaleFactor)
                }
            }
        }
    }

    @ViewBuilder
    private func buildTextContent() -> some View {
        VStack(alignment: .leading, spacing: 1 * scaleFactor) {
            // Render fields in the order specified by config
            ForEach(config.textFields, id: \.self) { field in
                buildTextField(field)
            }
        }
    }

    @ViewBuilder
    private func buildTextField(_ field: LabelTextField) -> some View {
        switch field {
        case .manufacturer:
            if let manufacturer = sampleData.manufacturer {
                // Check if SKU already starts with manufacturer (case-insensitive)
                let skuStartsWithManufacturer: Bool = {
                    guard let sku = sampleData.sku,
                          config.textFields.contains(.sku) else {
                        return false
                    }
                    return sku.lowercased().hasPrefix(manufacturer.lowercased())
                }()

                // Only show manufacturer if SKU doesn't already start with it
                if !skuStartsWithManufacturer {
                    let text = manufacturer.uppercased()
                    let fontSize = 9 * scaleFactor * fontScale
                    let font = UIFont.boldSystemFont(ofSize: fontSize)
                    let willTruncate = textWillTruncate(text, font: font)

                    Text(text)
                        .font(.system(size: fontSize, weight: .bold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .background(willTruncate ? Color.red.opacity(0.2) : Color.clear)
                }
            }

        case .sku:
            if let sku = sampleData.sku {
                let fontSize = 9 * scaleFactor * fontScale
                let font = UIFont.boldSystemFont(ofSize: fontSize)
                let willTruncate = textWillTruncate(sku, font: font)

                Text(sku)
                    .font(.system(size: fontSize, weight: .bold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .background(willTruncate ? Color.red.opacity(0.2) : Color.clear)
            }

        case .colorName:
            if let colorName = sampleData.colorName {
                let fontSize = 8 * scaleFactor * fontScale
                let font = UIFont.systemFont(ofSize: fontSize)
                let willTruncate = textWillTruncate(colorName, font: font)

                Text(colorName)
                    .font(.system(size: fontSize))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .background(willTruncate ? Color.red.opacity(0.2) : Color.clear)
            }

        case .coe:
            if let coe = sampleData.coe {
                let text = "COE \(coe)"
                let fontSize = 7 * scaleFactor * fontScale
                let font = UIFont.systemFont(ofSize: fontSize)
                let willTruncate = textWillTruncate(text, font: font)

                Text(text)
                    .font(.system(size: fontSize))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .background(willTruncate ? Color.red.opacity(0.2) : Color.clear)
            }

        case .location:
            if let location = sampleData.location {
                let text = "📍 \(location)"
                let fontSize = 7 * scaleFactor * fontScale
                let font = UIFont.systemFont(ofSize: fontSize)
                let willTruncate = textWillTruncate(text, font: font)

                Text(text)
                    .font(.system(size: fontSize))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .background(willTruncate ? Color.red.opacity(0.2) : Color.clear)
            }
        }
    }

    /// Check if text will be truncated given the available width
    private func textWillTruncate(_ text: String, font: UIFont) -> Bool {
        // Calculate available width based on QR position
        let padding: CGFloat = 4
        var availableWidth = format.labelWidth - (padding * 2)

        if config.qrPosition != .none {
            let qrSize = format.labelHeight * config.qrSize

            switch config.qrPosition {
            case .left, .right:
                availableWidth -= (qrSize + padding)
            case .both:
                availableWidth -= (2 * qrSize + 2 * padding)
            case .none:
                break
            }
        }

        // Calculate text width using actual font metrics (matches PDF rendering)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (text as NSString).size(withAttributes: attributes)

        return textSize.width > availableWidth
    }

    private var formattedDimensions: String {
        let widthInches = format.labelWidth / 72.0
        let heightInches = format.labelHeight / 72.0

        // Format as fractions if possible
        let widthFraction = formatAsInches(widthInches)
        let heightFraction = formatAsInches(heightInches)

        return "\(heightFraction)\" × \(widthFraction)\""
    }

    private func formatAsInches(_ inches: Double) -> String {
        if inches == 0.5 { return "½" }
        if inches == 1.0 { return "1" }
        if inches == 1.75 { return "1¾" }
        if inches == 2.0 { return "2" }
        if inches == 2.625 { return "2⅝" }
        if inches == 4.0 { return "4" }

        return String(format: "%.2f", inches)
    }
}

/// QR Code generator view
private struct QRCodeView: View {
    let stableId: String
    let service: LabelPrintingService

    @State private var qrImage: UIImage?

    var body: some View {
        if let qrImage = qrImage {
            Image(uiImage: qrImage)
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .onAppear {
                    // Generate QR code once on appear
                    qrImage = service.generateQRCode(for: stableId)
                }
        }
    }
}

#Preview("Avery 5160 - Information Dense") {
    LabelPreviewView(
        format: .avery5160,
        config: LabelBuilderConfig.presets[0].config,  // Information Dense
        sampleData: LabelData(
            stableId: "bullseye-clear-001",
            manufacturer: "be",
            sku: "1101",
            colorName: "Clear",
            coe: "96",
            location: nil
        )
    )
}

#Preview("Avery 5163 - QR Focused") {
    LabelPreviewView(
        format: .avery5163,
        config: LabelBuilderConfig.presets[1].config,  // QR Focused
        sampleData: LabelData(
            stableId: "bullseye-clear-001",
            manufacturer: "be",
            sku: "1101",
            colorName: "Clear",
            coe: "96",
            location: nil
        )
    )
}

#Preview("Avery 5167 - Dual QR") {
    LabelPreviewView(
        format: .avery5167,
        config: LabelBuilderConfig.presets[2].config,  // Dual QR
        sampleData: LabelData(
            stableId: "bullseye-clear-001",
            manufacturer: "be",
            sku: "1101",
            colorName: "Clear",
            coe: "96",
            location: nil
        )
    )
}

#Preview("Avery 5163 - Location Based") {
    LabelPreviewView(
        format: .avery5163,
        config: LabelBuilderConfig.presets[3].config,  // Location Labels
        sampleData: LabelData(
            stableId: "bullseye-clear-001",
            manufacturer: "be",
            sku: "1101",
            colorName: "Clear",
            coe: "96",
            location: "Studio Shelf A2"
        )
    )
}

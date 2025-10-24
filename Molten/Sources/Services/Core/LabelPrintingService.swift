//
//  LabelPrintingService.swift
//  Molten
//
//  Service for generating printable labels with QR codes for inventory items
//

import UIKit
import CoreImage.CIFilterBuiltins

/// Avery label format specifications
struct AveryFormat: Equatable, Hashable {
    let name: String
    let labelsPerSheet: Int
    let columns: Int
    let rows: Int
    let labelWidth: CGFloat  // in points (1/72 inch)
    let labelHeight: CGFloat
    let leftMargin: CGFloat
    let topMargin: CGFloat
    let horizontalGap: CGFloat
    let verticalGap: CGFloat

    /// Avery 5160 (Address Labels)
    /// 30 labels per sheet (3 columns × 10 rows)
    /// 1" × 2⅝" per label
    /// Most common format for rod labels
    static let avery5160 = AveryFormat(
        name: "Avery 5160",
        labelsPerSheet: 30,
        columns: 3,
        rows: 10,
        labelWidth: 189,  // 2⅝" × 72 = 189pt
        labelHeight: 72,  // 1" × 72 = 72pt
        leftMargin: 14.85,
        topMargin: 36,
        horizontalGap: 13.5,
        verticalGap: 0
    )

    /// Avery 5163 (Shipping Labels)
    /// 10 labels per sheet (2 columns × 5 rows)
    /// 2" × 4" per label
    /// Use for box labels with more detailed info
    static let avery5163 = AveryFormat(
        name: "Avery 5163",
        labelsPerSheet: 10,
        columns: 2,
        rows: 5,
        labelWidth: 288,  // 4" × 72 = 288pt
        labelHeight: 144,  // 2" × 72 = 144pt
        leftMargin: 18,
        topMargin: 36,
        horizontalGap: 18,
        verticalGap: 0
    )

    /// Avery 5167 (Return Address)
    /// 80 labels per sheet (4 columns × 20 rows)
    /// ½" × 1¾" per label
    /// Use for tiny labels on small rods
    static let avery5167 = AveryFormat(
        name: "Avery 5167",
        labelsPerSheet: 80,
        columns: 4,
        rows: 20,
        labelWidth: 126,  // 1¾" × 72 = 126pt
        labelHeight: 36,  // ½" × 72 = 36pt
        leftMargin: 22.5,
        topMargin: 36,
        horizontalGap: 9,
        verticalGap: 0
    )
}

/// Label layout template configuration
struct LabelTemplate: Equatable, Hashable {
    let name: String
    let includeQRCode: Bool
    let includeManufacturer: Bool
    let includeSKU: Bool
    let includeColor: Bool
    let includeCOE: Bool
    let includeQuantity: Bool
    let includeLocation: Bool
    let qrCodeSize: CGFloat  // as percentage of label height

    /// Information-dense template (for protruding rod labels)
    static let informationDense = LabelTemplate(
        name: "Information Dense",
        includeQRCode: true,
        includeManufacturer: true,
        includeSKU: true,
        includeColor: true,
        includeCOE: true,
        includeQuantity: true,
        includeLocation: false,
        qrCodeSize: 0.65
    )

    /// QR-focused template (minimal text, larger QR)
    static let qrFocused = LabelTemplate(
        name: "QR Focused",
        includeQRCode: true,
        includeManufacturer: true,
        includeSKU: true,
        includeColor: false,
        includeCOE: false,
        includeQuantity: false,
        includeLocation: false,
        qrCodeSize: 0.75
    )

    /// Box/Shelf labels (location-based)
    static let locationBased = LabelTemplate(
        name: "Location Based",
        includeQRCode: true,
        includeManufacturer: true,
        includeSKU: true,
        includeColor: true,
        includeCOE: true,
        includeQuantity: true,
        includeLocation: true,
        qrCodeSize: 0.50
    )
}

/// Label data model for a single inventory item
struct LabelData: Sendable {
    let stableId: String  // The stable_id of the glass item (e.g., "2wjEBu")
    let manufacturer: String?
    let sku: String?
    let colorName: String?
    let coe: String?
    let quantity: String?
    let location: String?
}

/// Service for generating printable label sheets with QR codes
@preconcurrency
class LabelPrintingService {

    /// Generate QR code image for a glass item
    /// - Parameter stableId: The stable_id of the glass item (e.g., "2wjEBu")
    /// - Returns: UIImage containing the QR code
    func generateQRCode(for stableId: String) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        // Create deep link URL with stable_id
        let deepLink = "molten://glass/\(stableId)"
        let data = Data(deepLink.utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction

        // Scale QR code to appropriate size
        guard let outputImage = filter.outputImage else { return UIImage() }
        let scaleX = 200 / outputImage.extent.width
        let scaleY = 200 / outputImage.extent.height
        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else {
            return UIImage()
        }

        return UIImage(cgImage: cgImage)
    }

    /// Generate label sheet PDF
    /// - Parameters:
    ///   - labels: Array of label data to print
    ///   - format: Avery format to use
    ///   - template: Label template configuration
    /// - Returns: URL to the generated PDF file in temporary storage
    func generateLabelSheet(
        labels: [LabelData],
        format: AveryFormat = .avery5160,
        template: LabelTemplate = .informationDense
    ) async -> URL? {
        // Create temporary file URL
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "Molten-Labels-\(Date().timeIntervalSince1970).pdf"
        let fileURL = tempDir.appendingPathComponent(fileName)

        // Remove existing file if present
        try? FileManager.default.removeItem(at: fileURL)

        // Generate PDF
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter (8.5" × 11")
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = pdfRenderer.pdfData { context in
            var labelIndex = 0
            let totalLabels = labels.count

            while labelIndex < totalLabels {
                context.beginPage()

                // Draw labels on this page
                for row in 0..<format.rows {
                    for col in 0..<format.columns {
                        if labelIndex >= totalLabels { break }

                        let labelData = labels[labelIndex]

                        // Calculate label position
                        let x = format.leftMargin + (CGFloat(col) * (format.labelWidth + format.horizontalGap))
                        let y = format.topMargin + (CGFloat(row) * (format.labelHeight + format.verticalGap))
                        let labelRect = CGRect(x: x, y: y, width: format.labelWidth, height: format.labelHeight)

                        // Draw single label
                        drawLabel(
                            labelData: labelData,
                            rect: labelRect,
                            template: template,
                            context: context.cgContext
                        )

                        labelIndex += 1
                    }
                    if labelIndex >= totalLabels { break }
                }
            }
        }

        // Write PDF data to file
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error writing PDF: \(error)")
            return nil
        }
    }

    // MARK: - Drawing Helpers

    private func drawLabel(
        labelData: LabelData,
        rect: CGRect,
        template: LabelTemplate,
        context: CGContext
    ) {
        let padding: CGFloat = 4

        // Draw QR code if enabled
        var contentX = rect.minX + padding
        var contentWidth = rect.width - (padding * 2)

        if template.includeQRCode {
            let qrSize = rect.height * template.qrCodeSize
            let qrImage = generateQRCode(for: labelData.stableId)

            let qrRect = CGRect(
                x: rect.minX + padding,
                y: rect.minY + (rect.height - qrSize) / 2,
                width: qrSize,
                height: qrSize
            )

            qrImage.draw(in: qrRect)

            // Adjust content area to be to the right of QR code
            contentX = qrRect.maxX + padding
            contentWidth = rect.maxX - contentX - padding
        }

        // Draw text content
        var yPosition = rect.minY + padding
        let lineHeight: CGFloat = 10

        // Manufacturer + SKU (combined on first line)
        if template.includeManufacturer || template.includeSKU {
            var line = ""
            if let manufacturer = labelData.manufacturer, template.includeManufacturer {
                line += manufacturer.uppercased()
            }
            if let sku = labelData.sku, template.includeSKU {
                if !line.isEmpty { line += " " }
                line += sku
            }

            if !line.isEmpty {
                yPosition = drawText(
                    line,
                    at: CGPoint(x: contentX, y: yPosition),
                    width: contentWidth,
                    font: .boldSystemFont(ofSize: 9),
                    context: context
                )
            }
        }

        // Color name
        if template.includeColor, let colorName = labelData.colorName {
            yPosition = drawText(
                colorName,
                at: CGPoint(x: contentX, y: yPosition),
                width: contentWidth,
                font: .systemFont(ofSize: 8),
                context: context
            )
        }

        // COE
        if template.includeCOE, let coe = labelData.coe {
            yPosition = drawText(
                "COE \(coe)",
                at: CGPoint(x: contentX, y: yPosition),
                width: contentWidth,
                font: .systemFont(ofSize: 7),
                color: .darkGray,
                context: context
            )
        }

        // Quantity
        if template.includeQuantity, let quantity = labelData.quantity {
            yPosition = drawText(
                quantity,
                at: CGPoint(x: contentX, y: yPosition),
                width: contentWidth,
                font: .systemFont(ofSize: 7),
                color: .darkGray,
                context: context
            )
        }

        // Location
        if template.includeLocation, let location = labelData.location {
            yPosition = drawText(
                "📍 \(location)",
                at: CGPoint(x: contentX, y: yPosition),
                width: contentWidth,
                font: .systemFont(ofSize: 7),
                color: .darkGray,
                context: context
            )
        }
    }

    private func drawText(
        _ text: String,
        at point: CGPoint,
        width: CGFloat,
        font: UIFont,
        color: UIColor = .black,
        alignment: NSTextAlignment = .left,
        context: CGContext
    ) -> CGFloat {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = .byTruncatingTail

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textRect = CGRect(x: point.x, y: point.y, width: width, height: font.lineHeight)

        attributedString.draw(in: textRect)

        return point.y + font.lineHeight + 1
    }
}

//
//  LabelPrintingService.swift
//  Molten
//
//  Service for generating printable labels with QR codes for inventory items
//

import UIKit
import CoreImage.CIFilterBuiltins
import Combine

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
        labelWidth: 189,  // 2.625" × 72 = 189pt
        labelHeight: 72,  // 1" × 72 = 72pt
        leftMargin: 13.5,  // 0.1875" × 72
        topMargin: 36,  // 0.5" × 72
        horizontalGap: 9,  // Spacing: 2.75" × 72 - 189pt = 9pt
        verticalGap: 0  // Labels are vertically contiguous
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
        leftMargin: 20.25,  // 0.28125" × 72
        topMargin: 36,  // 0.5" × 72
        horizontalGap: 22.5,  // Spacing: 2.0625" × 72 - 126pt = 22.5pt
        verticalGap: 0  // Labels are vertically contiguous
    )

    /// Avery 18167 (Return Address - Same dimensions as 5167)
    /// 80 labels per sheet (4 columns × 20 rows)
    /// ½" × 1¾" per label
    /// Alternative product code for same format as 5167
    static let avery18167 = AveryFormat(
        name: "Avery 18167",
        labelsPerSheet: 80,
        columns: 4,
        rows: 20,
        labelWidth: 126,  // 1¾" × 72 = 126pt
        labelHeight: 36,  // ½" × 72 = 36pt
        leftMargin: 20.25,  // 0.28125" × 72
        topMargin: 36,  // 0.5" × 72
        horizontalGap: 22.5,  // Spacing: 2.0625" × 72 - 126pt = 22.5pt
        verticalGap: 0  // Labels are vertically contiguous
    )

    /// Mr-Label MR184 (Cable Labels)
    /// 30 labels per sheet (3 columns × 10 rows)
    /// 1" × 2.625" per label (similar layout to Avery 5160)
    /// Waterproof, tear-resistant flag-style cable labels
    /// Note: Use offset adjustments in UI to fine-tune alignment for your specific label sheets
    static let mrLabel184 = AveryFormat(
        name: "Mr-Label MR184",
        labelsPerSheet: 30,
        columns: 3,
        rows: 10,
        labelWidth: 189,  // 2.625" × 72 = 189pt (same as Avery 5160)
        labelHeight: 72,  // 1" × 72 = 72pt
        leftMargin: 13.5,  // 0.1875" × 72
        topMargin: 36,  // 0.5" × 72
        horizontalGap: 9,  // Spacing between columns
        verticalGap: 0  // Labels are vertically contiguous
    )
}

/// QR code position on label
enum QRCodePosition: String, CaseIterable, Codable {
    case none = "None"
    case left = "Left"
    case right = "Right"
    case both = "Both"
}

/// Text field that can be included on a label
enum LabelTextField: String, CaseIterable, Codable {
    case manufacturer = "Manufacturer"
    case sku = "SKU"
    case colorName = "Color Name"
    case coe = "COE"
    case location = "Location"
    case owner = "Owner"

    var estimatedHeight: CGFloat {
        switch self {
        case .manufacturer, .sku: return 10  // Bold font, slightly taller
        case .colorName: return 9
        case .coe, .location, .owner: return 8
        }
    }
}

/// Label builder configuration - user-customizable label layout
struct LabelBuilderConfig: Equatable, Codable {
    var qrPosition: QRCodePosition
    var qrSize: CGFloat  // as percentage of label height (0.5 to 0.8, min 2cm/57pt per QR spec)
    var textFields: [LabelTextField]

    /// Default configuration (information dense)
    static let `default` = LabelBuilderConfig(
        qrPosition: .left,
        qrSize: 0.65,
        textFields: [.manufacturer, .sku, .colorName, .coe]
    )

    /// Preset configurations for common use cases
    static let presets: [LabelBuilderPreset] = [
        LabelBuilderPreset(
            name: "Information Dense",
            description: "Maximum info with QR code on left",
            config: LabelBuilderConfig(
                qrPosition: .left,
                qrSize: 0.65,
                textFields: [.manufacturer, .sku, .colorName, .coe]
            )
        ),
        LabelBuilderPreset(
            name: "QR Focused",
            description: "Large QR code, minimal text",
            config: LabelBuilderConfig(
                qrPosition: .left,
                qrSize: 0.75,
                textFields: [.manufacturer, .sku]
            )
        ),
        LabelBuilderPreset(
            name: "Dual QR",
            description: "QR codes on both ends",
            config: LabelBuilderConfig(
                qrPosition: .both,
                qrSize: 0.65,
                textFields: [.manufacturer, .sku, .colorName]
            )
        ),
        LabelBuilderPreset(
            name: "Location Labels",
            description: "With location information",
            config: LabelBuilderConfig(
                qrPosition: .left,
                qrSize: 0.50,
                textFields: [.manufacturer, .sku, .colorName, .coe, .location]
            )
        )
    ]

    /// Convert to legacy LabelTemplate for backwards compatibility
    func toLegacyTemplate() -> LabelTemplate {
        return LabelTemplate(
            name: "Custom",
            includeQRCode: qrPosition != .none,
            dualQRCodes: qrPosition == .both,
            includeManufacturer: textFields.contains(.manufacturer),
            includeSKU: textFields.contains(.sku),
            includeColor: textFields.contains(.colorName),
            includeCOE: textFields.contains(.coe),
            includeQuantity: false,  // Not used in builder config
            includeLocation: textFields.contains(.location),
            includeOwner: textFields.contains(.owner),
            qrCodeSize: qrSize
        )
    }

    /// Estimate if content will fit within label bounds
    /// - Parameters:
    ///   - format: The Avery format to check against
    ///   - fontScale: Font scale multiplier
    /// - Returns: (fits, estimatedHeight, warnings)
    /// - Note: QR codes will NEVER overflow - they are sized to always fit. Only text may be truncated.
    func validateLayout(for format: AveryFormat, fontScale: CGFloat = 1.0) -> LabelLayoutValidation {
        let padding: CGFloat = 4
        var warnings: [String] = []

        // Calculate available text area
        var availableWidth = format.labelWidth - (padding * 2)
        var availableHeight = format.labelHeight - (padding * 2)

        // Account for QR code(s) - QR codes are sized as percentage of label height, so they always fit
        if qrPosition != .none {
            let qrSize = format.labelHeight * qrSize

            switch qrPosition {
            case .left, .right:
                availableWidth -= (qrSize + padding)
            case .both:
                availableWidth -= (2 * qrSize + 2 * padding)
                // Warn if dual QR leaves very little text space
                if format.labelWidth < 120 {
                    warnings.append("Dual QR codes leave minimal space for text")
                }
            case .none:
                break
            }
        }

        // Estimate text height
        let estimatedTextHeight = textFields.reduce(0) { $0 + ($1.estimatedHeight * fontScale) }
        let textFits = estimatedTextHeight <= availableHeight

        // Check for potential text truncation issues
        if !textFits {
            let overflow = Int(estimatedTextHeight - availableHeight)
            warnings.append("Text will be truncated (\(overflow)pt overflow) - reduce font size or remove fields")
        }

        if availableWidth < 40 {
            warnings.append("Very narrow text area - consider reducing QR size or using fewer fields")
        }

        // Check if too many fields for the label size
        if textFields.count > 5 && format.labelHeight < 72 {
            warnings.append("Small label with many fields - text will be very compact")
        }

        return LabelLayoutValidation(
            fits: textFits && availableWidth >= 40,
            estimatedTextHeight: estimatedTextHeight,
            availableHeight: availableHeight,
            availableWidth: availableWidth,
            warnings: warnings
        )
    }
}

/// Result of label layout validation
struct LabelLayoutValidation {
    let fits: Bool
    let estimatedTextHeight: CGFloat
    let availableHeight: CGFloat
    let availableWidth: CGFloat
    let warnings: [String]
}

/// Label builder preset - named configuration that can be saved and shared
struct LabelBuilderPreset: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var config: LabelBuilderConfig
    var createdAt: Date
    var modifiedAt: Date

    init(id: UUID = UUID(), name: String, description: String, config: LabelBuilderConfig, createdAt: Date = Date(), modifiedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.description = description
        self.config = config
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    /// Export preset as JSON for sharing
    func exportJSON() -> Data? {
        try? JSONEncoder().encode(self)
    }

    /// Import preset from JSON
    static func importJSON(_ data: Data) -> LabelBuilderPreset? {
        try? JSONDecoder().decode(LabelBuilderPreset.self, from: data)
    }
}

/// Manager for storing and retrieving label builder presets
@MainActor
class LabelPresetsManager: ObservableObject {
    @Published private(set) var userPresets: [LabelBuilderPreset] = []

    private let userDefaultsKey = "molten.labelBuilder.userPresets"

    static let shared = LabelPresetsManager()

    private init() {
        loadPresets()
    }

    /// Save a new preset or update existing one
    func savePreset(_ preset: LabelBuilderPreset) {
        if let index = userPresets.firstIndex(where: { $0.id == preset.id }) {
            var updatedPreset = preset
            updatedPreset.modifiedAt = Date()
            userPresets[index] = updatedPreset
        } else {
            userPresets.append(preset)
        }
        persistPresets()
    }

    /// Delete a preset
    func deletePreset(_ preset: LabelBuilderPreset) {
        userPresets.removeAll { $0.id == preset.id }
        persistPresets()
    }

    /// Export preset to share with others
    func exportPreset(_ preset: LabelBuilderPreset) -> Data? {
        preset.exportJSON()
    }

    /// Import preset from others
    func importPreset(from data: Data) throws {
        guard let preset = LabelBuilderPreset.importJSON(data) else {
            throw LabelPresetsError.invalidData
        }
        // Assign new ID to avoid conflicts
        let importedPreset = LabelBuilderPreset(
            id: UUID(),
            name: preset.name,
            description: preset.description,
            config: preset.config
        )
        savePreset(importedPreset)
    }

    /// Get all presets (built-in + user)
    var allPresets: [LabelBuilderPreset] {
        LabelBuilderConfig.presets + userPresets
    }

    // MARK: - Private Methods

    private func loadPresets() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let presets = try? JSONDecoder().decode([LabelBuilderPreset].self, from: data) else {
            return
        }
        userPresets = presets
    }

    private func persistPresets() {
        guard let data = try? JSONEncoder().encode(userPresets) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
}

enum LabelPresetsError: Error {
    case invalidData
}

// MARK: - Legacy Template Support (for migration)

/// Label layout template configuration (DEPRECATED - use LabelBuilderConfig)
struct LabelTemplate: Equatable, Hashable {
    let name: String
    let includeQRCode: Bool
    let dualQRCodes: Bool
    let includeManufacturer: Bool
    let includeSKU: Bool
    let includeColor: Bool
    let includeCOE: Bool
    let includeQuantity: Bool
    let includeLocation: Bool
    let qrCodeSize: CGFloat

    /// Convert to LabelBuilderConfig
    func toBuilderConfig() -> LabelBuilderConfig {
        var qrPosition: QRCodePosition = .none
        if includeQRCode {
            qrPosition = dualQRCodes ? .both : .left
        }

        var fields: [LabelTextField] = []
        if includeManufacturer { fields.append(.manufacturer) }
        if includeSKU { fields.append(.sku) }
        if includeColor { fields.append(.colorName) }
        if includeCOE { fields.append(.coe) }
        if includeLocation { fields.append(.location) }

        return LabelBuilderConfig(
            qrPosition: qrPosition,
            qrSize: qrCodeSize,
            textFields: fields
        )
    }

    static let informationDense = LabelTemplate(
        name: "Information Dense",
        includeQRCode: true,
        dualQRCodes: false,
        includeManufacturer: true,
        includeSKU: true,
        includeColor: true,
        includeCOE: true,
        includeQuantity: true,
        includeLocation: false,
        qrCodeSize: 0.65
    )

    static let qrFocused = LabelTemplate(
        name: "QR Focused",
        includeQRCode: true,
        dualQRCodes: false,
        includeManufacturer: true,
        includeSKU: true,
        includeColor: false,
        includeCOE: false,
        includeQuantity: false,
        includeLocation: false,
        qrCodeSize: 0.75
    )

    static let locationBased = LabelTemplate(
        name: "Location Based",
        includeQRCode: true,
        dualQRCodes: false,
        includeManufacturer: true,
        includeSKU: true,
        includeColor: true,
        includeCOE: true,
        includeQuantity: true,
        includeLocation: true,
        qrCodeSize: 0.50
    )

    static let dualQR = LabelTemplate(
        name: "Dual QR",
        includeQRCode: true,
        dualQRCodes: true,
        includeManufacturer: true,
        includeSKU: true,
        includeColor: true,
        includeCOE: false,
        includeQuantity: false,
        includeLocation: false,
        qrCodeSize: 0.65
    )
}

/// Label data model for a single label (one label = one physical item like one rod)
struct LabelData: Sendable {
    let stableId: String  // The stable_id of the glass item (e.g., "2wjEBu")
    let manufacturer: String?
    let sku: String?
    let colorName: String?
    let coe: String?
    let location: String?
}

/// Service for generating printable label sheets with QR codes
@preconcurrency
class LabelPrintingService {

    /// Generate QR code image for a glass item with Molten logo overlay
    /// - Parameter stableId: The stable_id of the glass item (e.g., "2wjEBu")
    /// - Returns: UIImage containing the QR code with logo in center
    func generateQRCode(for stableId: String) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        // Create deep link URL with stable_id
        let deepLink = "molten://g/\(stableId)"
        print("📱 LabelPrintingService: Generating QR code for: \(deepLink)")
        print("📱 LabelPrintingService: stableId: '\(stableId)'")
        let data = Data(deepLink.utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction

        // Scale QR code to appropriate size
        guard let outputImage = filter.outputImage else { return UIImage() }
        let qrSize: CGFloat = 200
        let scaleX = qrSize / outputImage.extent.width
        let scaleY = qrSize / outputImage.extent.height
        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else {
            return UIImage()
        }

        let qrImage = UIImage(cgImage: cgImage)

        // Overlay logo in center
        return overlayLogoOnQRCode(qrImage: qrImage, qrSize: qrSize)
    }

    /// Overlay Molten logo in the center of QR code
    /// - Parameters:
    ///   - qrImage: The base QR code image
    ///   - qrSize: The size of the QR code
    /// - Returns: QR code with logo overlay
    private func overlayLogoOnQRCode(qrImage: UIImage, qrSize: CGFloat) -> UIImage {
        // Load logo from Assets
        guard let logo = UIImage(named: "molten-glass-logo-QR") else {
            print("⚠️ LabelPrintingService: Logo 'molten-glass-logo-QR' not found in Assets")
            return qrImage
        }

        // Logo should be about 22% of QR code size (safe with H error correction)
        let logoSize = qrSize * 0.22

        // Create graphics context
        UIGraphicsBeginImageContextWithOptions(CGSize(width: qrSize, height: qrSize), false, 0)
        defer { UIGraphicsEndImageContext() }

        // Draw QR code
        qrImage.draw(in: CGRect(x: 0, y: 0, width: qrSize, height: qrSize))

        // Draw white background circle behind logo for better contrast
        let logoRect = CGRect(
            x: (qrSize - logoSize) / 2,
            y: (qrSize - logoSize) / 2,
            width: logoSize,
            height: logoSize
        )

        // White circle slightly larger than logo
        let circleSize = logoSize * 1.1
        let circleRect = CGRect(
            x: (qrSize - circleSize) / 2,
            y: (qrSize - circleSize) / 2,
            width: circleSize,
            height: circleSize
        )

        UIColor.white.setFill()
        let circlePath = UIBezierPath(ovalIn: circleRect)
        circlePath.fill()

        // Draw logo
        logo.draw(in: logoRect)

        // Get composite image
        guard let compositeImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return qrImage
        }

        print("✅ LabelPrintingService: Logo overlay applied to QR code")
        return compositeImage
    }

    /// Generate label sheet PDF
    /// - Parameters:
    ///   - labels: Array of label data to print
    ///   - format: Avery format to use
    ///   - config: Label builder configuration
    ///   - fontScale: Font size multiplier (0.7 to 1.3)
    ///   - offsetX: Horizontal position adjustment in points (-10 to +10)
    ///   - offsetY: Vertical position adjustment in points (-10 to +10)
    ///   - startRow: Starting row (0-based) for partial sheets (default: 0)
    ///   - startColumn: Starting column (0-based) for partial sheets (default: 0)
    /// - Returns: URL to the generated PDF file in temporary storage
    func generateLabelSheet(
        labels: [LabelData],
        format: AveryFormat = .avery5160,
        config: LabelBuilderConfig = .default,
        fontScale: Double = 1.0,
        offsetX: Double = 0.0,
        offsetY: Double = 0.0,
        startRow: Int = 0,
        startColumn: Int = 0
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
            var isFirstPage = true

            while labelIndex < totalLabels {
                context.beginPage()

                // Draw labels on this page
                for row in 0..<format.rows {
                    for col in 0..<format.columns {
                        // Skip positions before start position on first page
                        if isFirstPage && (row < startRow || (row == startRow && col < startColumn)) {
                            continue  // Skip this position (it's before our start position)
                        }

                        if labelIndex >= totalLabels { break }

                        let labelData = labels[labelIndex]

                        // Calculate label position with user adjustments
                        let x = format.leftMargin + (CGFloat(col) * (format.labelWidth + format.horizontalGap)) + CGFloat(offsetX)
                        let y = format.topMargin + (CGFloat(row) * (format.labelHeight + format.verticalGap)) + CGFloat(offsetY)
                        let labelRect = CGRect(x: x, y: y, width: format.labelWidth, height: format.labelHeight)

                        // Draw single label
                        drawLabel(
                            labelData: labelData,
                            rect: labelRect,
                            config: config,
                            fontScale: CGFloat(fontScale),
                            context: context.cgContext
                        )

                        labelIndex += 1
                    }
                    if labelIndex >= totalLabels { break }
                }

                isFirstPage = false  // After first page, start from beginning of sheet
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
        config: LabelBuilderConfig,
        fontScale: CGFloat = 1.0,
        context: CGContext
    ) {
        let padding: CGFloat = 4

        // Draw QR code(s) based on position
        var contentX = rect.minX + padding
        var contentWidth = rect.width - (padding * 2)

        if config.qrPosition != .none {
            let qrSize = rect.height * config.qrSize
            let qrImage = generateQRCode(for: labelData.stableId)

            switch config.qrPosition {
            case .left:
                // Draw left QR code
                let leftQRRect = CGRect(
                    x: rect.minX + padding,
                    y: rect.minY + (rect.height - qrSize) / 2,
                    width: qrSize,
                    height: qrSize
                )
                qrImage.draw(in: leftQRRect)

                // Adjust content area to be to the right of QR code
                contentX = leftQRRect.maxX + padding
                contentWidth = rect.maxX - contentX - padding

            case .right:
                // Draw right QR code
                let rightQRRect = CGRect(
                    x: rect.maxX - padding - qrSize,
                    y: rect.minY + (rect.height - qrSize) / 2,
                    width: qrSize,
                    height: qrSize
                )
                qrImage.draw(in: rightQRRect)

                // Content area is from left edge to QR code
                contentWidth = rightQRRect.minX - contentX - padding

            case .both:
                // Draw left QR code
                let leftQRRect = CGRect(
                    x: rect.minX + padding,
                    y: rect.minY + (rect.height - qrSize) / 2,
                    width: qrSize,
                    height: qrSize
                )
                qrImage.draw(in: leftQRRect)

                // Draw right QR code
                let rightQRRect = CGRect(
                    x: rect.maxX - padding - qrSize,
                    y: rect.minY + (rect.height - qrSize) / 2,
                    width: qrSize,
                    height: qrSize
                )
                qrImage.draw(in: rightQRRect)

                // Content area is between the two QR codes
                contentX = leftQRRect.maxX + padding
                contentWidth = rightQRRect.minX - contentX - padding

            case .none:
                break
            }
        }

        // Draw text fields in the order specified by config
        var yPosition = rect.minY + padding

        for field in config.textFields {
            switch field {
            case .manufacturer:
                if let manufacturer = labelData.manufacturer {
                    // Check if SKU already starts with manufacturer (case-insensitive)
                    let skuStartsWithManufacturer: Bool = {
                        guard let sku = labelData.sku,
                              config.textFields.contains(.sku) else {
                            return false
                        }
                        return sku.lowercased().hasPrefix(manufacturer.lowercased())
                    }()

                    // Only show manufacturer if SKU doesn't already start with it
                    if !skuStartsWithManufacturer {
                        yPosition = drawText(
                            manufacturer.uppercased(),
                            at: CGPoint(x: contentX, y: yPosition),
                            width: contentWidth,
                            font: .boldSystemFont(ofSize: 9 * fontScale),
                            context: context
                        )
                    }
                }

            case .sku:
                if let sku = labelData.sku {
                    yPosition = drawText(
                        sku,
                        at: CGPoint(x: contentX, y: yPosition),
                        width: contentWidth,
                        font: .boldSystemFont(ofSize: 9 * fontScale),
                        context: context
                    )
                }

            case .colorName:
                if let colorName = labelData.colorName {
                    yPosition = drawText(
                        colorName,
                        at: CGPoint(x: contentX, y: yPosition),
                        width: contentWidth,
                        font: .systemFont(ofSize: 8 * fontScale),
                        context: context
                    )
                }

            case .coe:
                if let coe = labelData.coe {
                    yPosition = drawText(
                        "COE \(coe)",
                        at: CGPoint(x: contentX, y: yPosition),
                        width: contentWidth,
                        font: .systemFont(ofSize: 7 * fontScale),
                        color: .darkGray,
                        context: context
                    )
                }

            case .location:
                if let location = labelData.location {
                    yPosition = drawText(
                        "📍 \(location)",
                        at: CGPoint(x: contentX, y: yPosition),
                        width: contentWidth,
                        font: .systemFont(ofSize: 7 * fontScale),
                        color: .darkGray,
                        context: context
                    )
                }
            }
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

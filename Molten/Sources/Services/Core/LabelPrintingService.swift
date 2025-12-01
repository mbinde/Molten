//
//  LabelPrintingService.swift
//  Molten
//
//  Service for generating printable labels with QR codes for inventory items
//  Types extracted to LabelTypes.swift
//

#if os(iOS)
import UIKit
#endif
import CoreImage.CIFilterBuiltins
import Combine

// MARK: - Preset Manager

/// Manager for storing and retrieving label builder presets
/// Uses Core Data for CloudKit sync, replacing UserDefaults
@MainActor
class LabelPresetsManager: ObservableObject {
    @Published private(set) var userPresets: [LabelBuilderPreset] = []

    private let userDefaultsKey = "molten.labelBuilder.userPresets"

    static let shared = LabelPresetsManager()

    /// Initialize with optional repository (for testing, provide a repository)
    init(repository: LabelPresetRepository? = nil) {
        // Use provided repository or get from PersistenceController (available at init time)
        self.repository = repository ?? CoreDataLabelPresetRepository(context: PersistenceController.shared.cloudContext)

        // Load presets asynchronously
        Task {
            await loadPresets()
            // Auto-migrate from UserDefaults if needed
            await migrateFromUserDefaults()
        }
    }

    /// Save a new preset or update existing one
    func savePreset(_ preset: LabelBuilderPreset) async throws {
        var presetToSave = preset
        if let existingIndex = userPresets.firstIndex(where: { $0.id == preset.id }) {
            // Update existing
            presetToSave.modifiedAt = Date()
            _ = try await repository.updatePreset(presetToSave)
            await MainActor.run {
                self.userPresets[existingIndex] = presetToSave
            }
        } else {
            // Create new
            _ = try await repository.createPreset(presetToSave)
            await MainActor.run {
                self.userPresets.append(presetToSave)
            }
        }
    }

    /// Delete a preset
    func deletePreset(_ preset: LabelBuilderPreset) async throws {
        try await repository.deletePreset(id: preset.id)
        await MainActor.run {
            self.userPresets.removeAll { $0.id == preset.id }
        }
    }

    /// Export preset to share with others
    func exportPreset(_ preset: LabelBuilderPreset) -> Data? {
        preset.exportJSON()
    }

    /// Import preset from others
    func importPreset(from data: Data) async throws {
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
        try await savePreset(importedPreset)
    }

    /// Get all presets (user first, then built-in)
    var allPresets: [LabelBuilderPreset] {
        userPresets + LabelBuilderConfig.presets
    }

    // MARK: - Private Properties

    private let repository: LabelPresetRepository

    // MARK: - Private Methods

    private func loadPresets() async {
        do {
            let presets = try await repository.fetchAllPresets()
            await MainActor.run {
                self.userPresets = presets
            }
        } catch {
            print("❌ Failed to load presets: \(error)")
        }
    }

    /// Migrate old UserDefaults presets to Core Data (one-time migration)
    func migrateFromUserDefaults() async {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let oldPresets = try? JSONDecoder().decode([LabelBuilderPreset].self, from: data) else {
            return
        }

        print("🔄 Migrating \(oldPresets.count) presets from UserDefaults to Core Data...")

        for preset in oldPresets {
            do {
                _ = try await repository.createPreset(preset)
            } catch {
                print("❌ Failed to migrate preset '\(preset.name)': \(error)")
            }
        }

        // Clear old UserDefaults storage
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        print("✅ Migration complete, cleared UserDefaults storage")

        // Reload presets
        await loadPresets()
    }
}

#if os(iOS)
/// Service for generating printable label sheets with QR codes
@preconcurrency
class LabelPrintingService {

    // MARK: - Performance Optimization

    /// Shared CIContext for QR code generation (expensive to create)
    private let qrContext = CIContext()

    /// Cache for generated QR codes (key = stableId)
    private var qrCodeCache: [String: UIImage] = [:]

    /// Generate QR code image for a glass item with Molten logo overlay
    /// - Parameter stableId: The stable_id of the glass item (e.g., "2wjEBu")
    /// - Returns: UIImage containing the QR code with logo in center
    func generateQRCode(for stableId: String) -> UIImage {
        return generateQRCode(for: stableId, type: nil, subtype: nil, subsubtype: nil)
    }

    /// Generate QR code image for a glass item with inventory type info
    /// - Parameters:
    ///   - stableId: The stable_id of the glass item (e.g., "2wjEBu")
    ///   - type: Inventory type (e.g., "rod", "frit")
    ///   - subtype: Optional subtype (e.g., "coarse", "fine")
    ///   - subsubtype: Optional subsubtype
    /// - Returns: UIImage containing the QR code with logo in center
    func generateQRCode(
        for stableId: String,
        type: String?,
        subtype: String?,
        subsubtype: String?
    ) -> UIImage {
        // Build cache key including type info
        let cacheKey = [stableId, type, subtype, subsubtype]
            .compactMap { $0 }
            .joined(separator: ":")

        // Check cache first
        if let cachedQR = qrCodeCache[cacheKey] {
            return cachedQR
        }

        let filter = CIFilter.qrCodeGenerator()

        // Create deep link URL with stable_id and optional type code
        let deepLink: String
        if let type = type {
            deepLink = InventoryTypeEncoder.buildQRCodeURL(
                stableId: stableId,
                type: type,
                subtype: subtype,
                subsubtype: subsubtype
            )
        } else {
            deepLink = "molten://i/\(stableId)"
        }

        let data = Data(deepLink.utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction

        // Scale QR code to appropriate size
        guard let outputImage = filter.outputImage else { return UIImage() }
        let qrSize: CGFloat = 200
        let scaleX = qrSize / outputImage.extent.width
        let scaleY = qrSize / outputImage.extent.height
        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        guard let cgImage = qrContext.createCGImage(transformedImage, from: transformedImage.extent) else {
            return UIImage()
        }

        let qrImage = UIImage(cgImage: cgImage)

        // Overlay logo in center
        let finalImage = overlayLogoOnQRCode(qrImage: qrImage, qrSize: qrSize)

        // Cache for reuse
        qrCodeCache[cacheKey] = finalImage

        return finalImage
    }

    /// Generate QR code from LabelData (convenience method)
    func generateQRCode(for labelData: LabelData) -> UIImage {
        return generateQRCode(
            for: labelData.stableId,
            type: labelData.inventoryType,
            subtype: labelData.inventorySubtype,
            subsubtype: labelData.inventorySubsubtype
        )
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
    ///   - startRow: Starting row (0-based) for partial sheets (default: 0)
    ///   - startColumn: Starting column (0-based) for partial sheets (default: 0)
    /// - Returns: URL to the generated PDF file in temporary storage
    /// Note: Position offsets (horizontal/vertical) are now taken from config.positionHorizontal/positionVertical
    func generateLabelSheet(
        labels: [LabelData],
        format: LabelGeometry = .defaultFormat,
        config: LabelBuilderConfig = .default,
        fontScale: Double = 1.0,
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
                        let x = format.leftMargin + (CGFloat(col) * (format.labelWidth + format.horizontalGap)) + config.positionHorizontal
                        let y = format.topMargin + (CGFloat(row) * (format.labelHeight + format.verticalGap)) + config.positionVertical
                        let labelRect = CGRect(x: x, y: y, width: format.labelWidth, height: format.labelHeight)

                        // Draw single label
                        drawLabel(
                            labelData: labelData,
                            rect: labelRect,
                            format: format,
                            config: config,
                            fontScale: CGFloat(fontScale),
                            row: row,
                            col: col,
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

    // MARK: - QR Code Sizing

    /// Minimum QR code size in points (must be scannable)
    private let minQRSize: CGFloat = 36  // ~0.5 inch

    /// Maximum QR code size in points (no need to be huge on large labels)
    private let maxQRSize: CGFloat = 108  // ~1.5 inches

    /// Calculate QR code size with min/max bounds
    /// - Parameters:
    ///   - labelHeight: The height of the label
    ///   - qrSizePercent: The desired QR size as percentage of label height (0.0-1.0)
    /// - Returns: The actual QR size in points, clamped to min/max bounds
    private func calculateQRSize(labelHeight: CGFloat, qrSizePercent: CGFloat) -> CGFloat {
        let desiredSize = labelHeight * qrSizePercent
        return min(max(desiredSize, minQRSize), maxQRSize)
    }

    // MARK: - Font Scaling

    /// Reference label height for font sizing (1 inch = 72pt)
    /// Font sizes in LabelFieldFormat.defaults are designed for this height
    private let referenceLabelHeight: CGFloat = 72

    /// Maximum font scale multiplier for large labels
    private let maxFontScaleMultiplier: CGFloat = 2.5

    /// Calculate font scale multiplier based on label height
    /// - Parameter labelHeight: The height of the label in points
    /// - Returns: A multiplier to apply to base font sizes
    ///
    /// Labels at reference height (72pt/1") use 1.0x scaling.
    /// Larger labels scale up proportionally, capped at maxFontScaleMultiplier.
    /// Smaller labels use 1.0x (don't shrink text below designed sizes).
    func calculateLabelFontScale(labelHeight: CGFloat) -> CGFloat {
        let ratio = labelHeight / referenceLabelHeight
        // Don't shrink below 1.0 for small labels, cap at max for large labels
        return min(max(ratio, 1.0), maxFontScaleMultiplier)
    }

    // MARK: - Drawing Helpers

    private func drawLabel(
        labelData: LabelData,
        rect: CGRect,
        format: LabelGeometry,
        config: LabelBuilderConfig,
        fontScale: CGFloat = 1.0,
        row: Int = 0,
        col: Int = 0,
        context: CGContext
    ) {
        // Clip all drawing to the label boundary
        // This prevents any content from overflowing into adjacent labels
        context.saveGState()

        if format.isCircular {
            // Circular labels: clip to ellipse (or circle if width == height)
            context.addEllipse(in: rect)
        } else {
            // Rectangular and barbell labels: clip to rect
            context.addRect(rect)
        }
        context.clip()

        // Apply label-size-based font scaling on top of user's fontScale setting
        // This ensures text scales appropriately for larger labels
        let labelBasedScale = calculateLabelFontScale(labelHeight: rect.height)
        let effectiveFontScale = fontScale * labelBasedScale

        // Handle special label formats
        if format.isBarbell, let style = format.barbellStyle {
            switch style {
            case .pStyleFolded:
                drawPStyleFoldedLabel(
                    labelData: labelData,
                    rect: rect,
                    format: format,
                    config: config,
                    fontScale: effectiveFontScale,
                    row: row,
                    col: col,
                    context: context
                )
                context.restoreGState()
                return
            case .symmetric:
                drawSymmetricBarbellLabel(
                    labelData: labelData,
                    rect: rect,
                    format: format,
                    config: config,
                    fontScale: effectiveFontScale,
                    context: context
                )
                context.restoreGState()
                return
            case .tStyle, .pStyle, .wrap:
                // TODO: Implement other barbell styles
                // For now, fall through to standard label drawing
                break
            }
        }

        let padding: CGFloat = 4

        // Draw QR code(s) based on position
        // For circular labels, positions are top/bottom instead of left/right
        var contentX = rect.minX + padding
        var contentWidth = rect.width - (padding * 2)
        var contentY = rect.minY + padding
        var contentHeight = rect.height - (padding * 2)

        if config.qrPosition != .none {
            let effectiveQRPercent = config.qrSize ?? format.defaultQRSize
            let qrSize = calculateQRSize(labelHeight: rect.height, qrSizePercent: effectiveQRPercent)
            let qrImage = generateQRCode(for: labelData.stableId)

            // Determine if this label uses vertical layout (top/bottom QR positioning)
            // Circular, portrait, and square labels all use vertical layout since text expands horizontally
            let usesVerticalLayout = format.isCircular || format.shape == .portrait || format.shape == .square

            if usesVerticalLayout {
                // Circular, portrait, and square labels: top/bottom QR positioning
                switch config.qrPosition {
                case .left:  // "Top" for vertical labels
                    let topQRRect = CGRect(
                        x: rect.midX - qrSize / 2,
                        y: rect.minY + padding,
                        width: qrSize,
                        height: qrSize
                    )
                    qrImage.draw(in: topQRRect)
                    contentY = topQRRect.maxY + padding
                    contentHeight = rect.maxY - contentY - padding

                case .right:  // "Bottom" for vertical labels
                    let bottomQRRect = CGRect(
                        x: rect.midX - qrSize / 2,
                        y: rect.maxY - padding - qrSize,
                        width: qrSize,
                        height: qrSize
                    )
                    qrImage.draw(in: bottomQRRect)
                    contentHeight = bottomQRRect.minY - contentY - padding

                case .both:  // "Top & Bottom" for vertical labels
                    let topQRRect = CGRect(
                        x: rect.midX - qrSize / 2,
                        y: rect.minY + padding,
                        width: qrSize,
                        height: qrSize
                    )
                    qrImage.draw(in: topQRRect)

                    let bottomQRRect = CGRect(
                        x: rect.midX - qrSize / 2,
                        y: rect.maxY - padding - qrSize,
                        width: qrSize,
                        height: qrSize
                    )
                    qrImage.draw(in: bottomQRRect)

                    contentY = topQRRect.maxY + padding
                    contentHeight = bottomQRRect.minY - contentY - padding

                case .none:
                    break
                }
            } else {
                // Landscape and square labels: left/right QR positioning
                switch config.qrPosition {
                case .left:
                    let leftQRRect = CGRect(
                        x: rect.minX + padding,
                        y: rect.minY + (rect.height - qrSize) / 2,
                        width: qrSize,
                        height: qrSize
                    )
                    qrImage.draw(in: leftQRRect)
                    contentX = leftQRRect.maxX + padding
                    contentWidth = rect.maxX - contentX - padding

                case .right:
                    let rightQRRect = CGRect(
                        x: rect.maxX - padding - qrSize,
                        y: rect.minY + (rect.height - qrSize) / 2,
                        width: qrSize,
                        height: qrSize
                    )
                    qrImage.draw(in: rightQRRect)
                    contentWidth = rightQRRect.minX - contentX - padding

                case .both:
                    let leftQRRect = CGRect(
                        x: rect.minX + padding,
                        y: rect.minY + (rect.height - qrSize) / 2,
                        width: qrSize,
                        height: qrSize
                    )
                    qrImage.draw(in: leftQRRect)

                    let rightQRRect = CGRect(
                        x: rect.maxX - padding - qrSize,
                        y: rect.minY + (rect.height - qrSize) / 2,
                        width: qrSize,
                        height: qrSize
                    )
                    qrImage.draw(in: rightQRRect)

                    contentX = leftQRRect.maxX + padding
                    contentWidth = rightQRRect.minX - contentX - padding

                case .none:
                    break
                }
            }
        }

        // Draw manufacturer image(s) if configured
        if config.manufacturerImagePosition != .none, let manufacturer = labelData.manufacturer {
            let effectiveImageSize = config.manufacturerImageSize ?? 0.6
            let imageSize = rect.height * effectiveImageSize

            // Try to load manufacturer logo
            // Manufacturer codes are uppercase (e.g., "EF", "BE"), but files are lowercase with _print.png suffix
            let imageName = "\(manufacturer.lowercased())_print.png"
            if let logoImage = UIImage(named: imageName) {
                switch config.manufacturerImagePosition {
                case .left:
                    // Draw left image
                    let leftImageRect = CGRect(
                        x: rect.minX + padding,
                        y: rect.minY + (rect.height - imageSize) / 2,
                        width: imageSize,
                        height: imageSize
                    )
                    logoImage.draw(in: leftImageRect)

                    // Adjust content area to be to the right of image
                    contentX = leftImageRect.maxX + padding
                    contentWidth = rect.maxX - contentX - padding

                case .right:
                    // Draw right image
                    let rightImageRect = CGRect(
                        x: rect.maxX - padding - imageSize,
                        y: rect.minY + (rect.height - imageSize) / 2,
                        width: imageSize,
                        height: imageSize
                    )
                    logoImage.draw(in: rightImageRect)

                    // Content area is from left edge to image
                    contentWidth = rightImageRect.minX - contentX - padding

                case .both:
                    // Draw left image
                    let leftImageRect = CGRect(
                        x: rect.minX + padding,
                        y: rect.minY + (rect.height - imageSize) / 2,
                        width: imageSize,
                        height: imageSize
                    )
                    logoImage.draw(in: leftImageRect)

                    // Draw right image
                    let rightImageRect = CGRect(
                        x: rect.maxX - padding - imageSize,
                        y: rect.minY + (rect.height - imageSize) / 2,
                        width: imageSize,
                        height: imageSize
                    )
                    logoImage.draw(in: rightImageRect)

                    // Content area is between the two images
                    contentX = leftImageRect.maxX + padding
                    contentWidth = rightImageRect.minX - contentX - padding

                case .none:
                    break
                }
            } else {
                print("⚠️ LabelPrintingService: Manufacturer image '\(imageName)' not found in Assets")
                print("   Expected file naming: {manufacturer}_print.png (e.g., be_print.png, cim_print.png)")
            }
        } else if config.manufacturerImagePosition != .none {
            print("ℹ️ LabelPrintingService: Manufacturer image position is \(config.manufacturerImagePosition.rawValue) but no manufacturer data available")
        }

        // Calculate total text height first for vertical centering
        var totalTextHeight: CGFloat = 0
        for field in config.textFields {
            let fieldFormat = config.format(for: field)
            let font: UIFont = fieldFormat.bold ? .boldSystemFont(ofSize: fieldFormat.fontSize * effectiveFontScale) : .systemFont(ofSize: fieldFormat.fontSize * effectiveFontScale)

            // Only count this field if it has data to show
            let shouldShow: Bool = {
                switch field {
                case .manufacturer: return labelData.manufacturer != nil
                case .sku: return labelData.sku != nil
                case .colorName: return labelData.colorName != nil
                case .coe: return labelData.coe != nil
                case .location: return labelData.location != nil
                case .owner: return labelData.owner != nil
                }
            }()

            if shouldShow {
                totalTextHeight += font.lineHeight + 1
            }
        }

        // Start Y position centered vertically in the available content area
        // For circular labels with QR codes, contentY and contentHeight are adjusted
        var yPosition = contentY + max(0, (contentHeight - totalTextHeight) / 2)

        // Convert text alignment to NSTextAlignment
        let textAlignment: NSTextAlignment = {
            switch config.textAlignment {
            case .left: return .left
            case .center: return .center
            case .right: return .right
            }
        }()

        for field in config.textFields {
            switch field {
            case .manufacturer:
                if let manufacturer = labelData.manufacturer {
                    // Convert manufacturer abbreviation to full name first
                    let fullName = GlassManufacturers.fullName(for: manufacturer) ?? manufacturer

                    // Check if SKU already starts with full manufacturer name (case-insensitive)
                    // Only hide manufacturer if SKU literally starts with the full name (not just abbreviation)
                    let skuStartsWithManufacturer: Bool = {
                        guard let sku = labelData.sku,
                              config.textFields.contains(.sku) else {
                            return false
                        }
                        return sku.lowercased().hasPrefix(fullName.lowercased())
                    }()

                    // Only show manufacturer if SKU doesn't already start with it
                    if !skuStartsWithManufacturer {
                        let fieldFormat = config.format(for: .manufacturer)
                        let font: UIFont = fieldFormat.bold ? .boldSystemFont(ofSize: fieldFormat.fontSize * effectiveFontScale) : .systemFont(ofSize: fieldFormat.fontSize * effectiveFontScale)
                        yPosition = drawText(
                            fullName,
                            at: CGPoint(x: contentX, y: yPosition),
                            width: contentWidth,
                            font: font,
                            alignment: textAlignment,
                            context: context,
                            italic: fieldFormat.italic
                        )
                    }
                }

            case .sku:
                if let sku = labelData.sku {
                    let fieldFormat = config.format(for: .sku)
                    let font: UIFont = fieldFormat.bold ? .boldSystemFont(ofSize: fieldFormat.fontSize * effectiveFontScale) : .systemFont(ofSize: fieldFormat.fontSize * effectiveFontScale)
                    yPosition = drawText(
                        sku,
                        at: CGPoint(x: contentX, y: yPosition),
                        width: contentWidth,
                        font: font,
                        alignment: textAlignment,
                        context: context,
                        italic: fieldFormat.italic
                    )
                }

            case .colorName:
                if let colorName = labelData.colorName {
                    let fieldFormat = config.format(for: .colorName)
                    let font: UIFont = fieldFormat.bold ? .boldSystemFont(ofSize: fieldFormat.fontSize * effectiveFontScale) : .systemFont(ofSize: fieldFormat.fontSize * effectiveFontScale)
                    yPosition = drawText(
                        colorName,
                        at: CGPoint(x: contentX, y: yPosition),
                        width: contentWidth,
                        font: font,
                        alignment: textAlignment,
                        context: context,
                        italic: fieldFormat.italic
                    )
                }

            case .coe:
                if let coe = labelData.coe {
                    let fieldFormat = config.format(for: .coe)
                    let font: UIFont = fieldFormat.bold ? .boldSystemFont(ofSize: fieldFormat.fontSize * effectiveFontScale) : .systemFont(ofSize: fieldFormat.fontSize * effectiveFontScale)
                    yPosition = drawText(
                        "COE \(coe)",
                        at: CGPoint(x: contentX, y: yPosition),
                        width: contentWidth,
                        font: font,
                        color: .darkGray,
                        alignment: textAlignment,
                        context: context,
                        italic: fieldFormat.italic
                    )
                }

            case .location:
                if let location = labelData.location {
                    let fieldFormat = config.format(for: .location)
                    let font: UIFont = fieldFormat.bold ? .boldSystemFont(ofSize: fieldFormat.fontSize * effectiveFontScale) : .systemFont(ofSize: fieldFormat.fontSize * effectiveFontScale)
                    yPosition = drawText(
                        "📍 \(location)",
                        at: CGPoint(x: contentX, y: yPosition),
                        width: contentWidth,
                        font: font,
                        color: .darkGray,
                        alignment: textAlignment,
                        context: context,
                        italic: fieldFormat.italic
                    )
                }

            case .owner:
                if let owner = labelData.owner {
                    let fieldFormat = config.format(for: .owner)
                    let font: UIFont = fieldFormat.bold ? .boldSystemFont(ofSize: fieldFormat.fontSize * effectiveFontScale) : .systemFont(ofSize: fieldFormat.fontSize * effectiveFontScale)
                    yPosition = drawText(
                        owner,
                        at: CGPoint(x: contentX, y: yPosition),
                        width: contentWidth,
                        font: font,
                        color: .darkGray,
                        alignment: textAlignment,
                        context: context,
                        italic: fieldFormat.italic
                    )
                }
            }
        }

        // Restore graphics state (removes clipping)
        context.restoreGState()
    }

    // MARK: - Symmetric Barbell Label Drawing

    /// Draw a symmetric barbell/flag cable label with two flag areas on each end
    /// Layout: [Left Flag] - [Narrow Wrap] - [Right Flag]
    /// Both flags get identical content in the same orientation (label wraps horizontally)
    private func drawSymmetricBarbellLabel(
        labelData: LabelData,
        rect: CGRect,
        format: LabelGeometry,
        config: LabelBuilderConfig,
        fontScale: CGFloat,
        context: CGContext
    ) {
        // Get flag width - this is the printable area on each end
        guard let flagWidth = format.barbellFlagWidth else {
            // Fallback: divide label into thirds (flag-wrap-flag)
            let fallbackFlagWidth = rect.width / 3
            drawSymmetricBarbellFlagAreas(
                labelData: labelData,
                rect: rect,
                flagWidth: fallbackFlagWidth,
                config: config,
                fontScale: fontScale,
                context: context
            )
            return
        }

        drawSymmetricBarbellFlagAreas(
            labelData: labelData,
            rect: rect,
            flagWidth: flagWidth,
            config: config,
            fontScale: fontScale,
            context: context
        )
    }

    /// Draw the two flag areas of a symmetric barbell label
    /// Layout: Left flag gets text, Right flag gets QR (if enabled) or duplicate text
    private func drawSymmetricBarbellFlagAreas(
        labelData: LabelData,
        rect: CGRect,
        flagWidth: CGFloat,
        config: LabelBuilderConfig,
        fontScale: CGFloat,
        context: CGContext
    ) {
        let padding: CGFloat = 2

        // Left flag area
        let leftFlagRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: flagWidth,
            height: rect.height
        )

        // Right flag area
        let rightFlagRect = CGRect(
            x: rect.maxX - flagWidth,
            y: rect.minY,
            width: flagWidth,
            height: rect.height
        )

        // Draw left flag - TEXT ONLY (no QR)
        drawBarbellFlagTextOnly(
            labelData: labelData,
            rect: leftFlagRect,
            config: config,
            fontScale: fontScale,
            padding: padding,
            context: context
        )

        // Draw right flag - QR ONLY (if enabled) or duplicate text
        if config.qrPosition != .none {
            drawBarbellFlagQROnly(
                labelData: labelData,
                rect: rightFlagRect,
                config: config,
                padding: padding,
                context: context
            )
        } else {
            // No QR configured - duplicate text on right flag
            drawBarbellFlagTextOnly(
                labelData: labelData,
                rect: rightFlagRect,
                config: config,
                fontScale: fontScale,
                padding: padding,
                context: context
            )
        }
    }

    /// Draw TEXT ONLY on a barbell flag area (no QR code)
    private func drawBarbellFlagTextOnly(
        labelData: LabelData,
        rect: CGRect,
        config: LabelBuilderConfig,
        fontScale: CGFloat,
        padding: CGFloat,
        context: CGContext
    ) {
        let contentX = rect.minX + padding
        let contentWidth = rect.width - (padding * 2)
        let contentHeight = rect.height - (padding * 2)

        // Calculate text sizing - barbell labels need smaller text
        // Use user's font scale directly - they can adjust if text doesn't fit
        let barbellFontScale = fontScale

        // Calculate total text height for vertical centering
        var totalTextHeight: CGFloat = 0
        for field in config.textFields {
            let fieldFormat = config.format(for: field)
            let font: UIFont = fieldFormat.bold
                ? .boldSystemFont(ofSize: fieldFormat.fontSize * barbellFontScale)
                : .systemFont(ofSize: fieldFormat.fontSize * barbellFontScale)

            let shouldShow: Bool = {
                switch field {
                case .manufacturer: return labelData.manufacturer != nil
                case .sku: return labelData.sku != nil
                case .colorName: return labelData.colorName != nil
                case .coe: return labelData.coe != nil
                case .location: return labelData.location != nil
                case .owner: return labelData.owner != nil
                }
            }()

            if shouldShow {
                totalTextHeight += font.lineHeight + 1
            }
        }

        // Start Y position centered vertically
        var yPosition = rect.minY + padding + max(0, (contentHeight - totalTextHeight) / 2)

        // Text alignment
        let textAlignment: NSTextAlignment = {
            switch config.textAlignment {
            case .left: return .left
            case .center: return .center
            case .right: return .right
            }
        }()

        // Draw text fields
        for field in config.textFields {
            let fieldFormat = config.format(for: field)
            let font: UIFont = fieldFormat.bold
                ? .boldSystemFont(ofSize: fieldFormat.fontSize * barbellFontScale)
                : .systemFont(ofSize: fieldFormat.fontSize * barbellFontScale)

            switch field {
            case .manufacturer:
                if let manufacturer = labelData.manufacturer {
                    let fullName = GlassManufacturers.fullName(for: manufacturer) ?? manufacturer
                    let skuStartsWithManufacturer: Bool = {
                        guard let sku = labelData.sku, config.textFields.contains(.sku) else { return false }
                        return sku.lowercased().hasPrefix(fullName.lowercased())
                    }()
                    if !skuStartsWithManufacturer {
                        yPosition = drawText(fullName, at: CGPoint(x: contentX, y: yPosition), width: contentWidth, font: font, alignment: textAlignment, context: context, italic: fieldFormat.italic)
                    }
                }
            case .sku:
                if let sku = labelData.sku {
                    yPosition = drawText(sku, at: CGPoint(x: contentX, y: yPosition), width: contentWidth, font: font, alignment: textAlignment, context: context, italic: fieldFormat.italic)
                }
            case .colorName:
                if let colorName = labelData.colorName {
                    yPosition = drawText(colorName, at: CGPoint(x: contentX, y: yPosition), width: contentWidth, font: font, alignment: textAlignment, context: context, italic: fieldFormat.italic)
                }
            case .coe:
                if let coe = labelData.coe {
                    yPosition = drawText("COE \(coe)", at: CGPoint(x: contentX, y: yPosition), width: contentWidth, font: font, color: .darkGray, alignment: textAlignment, context: context, italic: fieldFormat.italic)
                }
            case .location:
                if let location = labelData.location {
                    yPosition = drawText(location, at: CGPoint(x: contentX, y: yPosition), width: contentWidth, font: font, alignment: textAlignment, context: context, italic: fieldFormat.italic)
                }
            case .owner:
                if let owner = labelData.owner {
                    yPosition = drawText(owner, at: CGPoint(x: contentX, y: yPosition), width: contentWidth, font: font, color: .darkGray, alignment: textAlignment, context: context, italic: fieldFormat.italic)
                }
            }
        }
    }

    /// Draw QR CODE ONLY on a barbell flag area (centered)
    private func drawBarbellFlagQROnly(
        labelData: LabelData,
        rect: CGRect,
        config: LabelBuilderConfig,
        padding: CGFloat,
        context: CGContext
    ) {
        // Use user's configured QR size percentage (or default 0.65)
        // For barbell labels, size is relative to label height
        let qrPercent = config.qrSize ?? 0.65
        let desiredQRSize = rect.height * qrPercent

        // Clamp to fit within flag area (with padding)
        let maxFlagSize = min(rect.width, rect.height) - (padding * 2)
        let qrSize = min(desiredQRSize, maxFlagSize)

        let qrImage = generateQRCode(for: labelData)

        // Center the QR code in the flag area
        let qrX = rect.minX + (rect.width - qrSize) / 2
        let qrY = rect.minY + (rect.height - qrSize) / 2

        let qrRect = CGRect(x: qrX, y: qrY, width: qrSize, height: qrSize)
        qrImage.draw(in: qrRect)
    }

    // MARK: - P-Style Folded Label Drawing

    /// Draw a p-style-folded cable label with two print areas (A and B)
    /// Labels are vertical on the sheet with alternating stub positions:
    /// - Even (row+col): stub at top, print areas below
    /// - Odd (row+col): stub at bottom, print areas above (entire label flipped)
    private func drawPStyleFoldedLabel(
        labelData: LabelData,
        rect: CGRect,
        format: LabelGeometry,
        config: LabelBuilderConfig,
        fontScale: CGFloat,
        row: Int,
        col: Int,
        context: CGContext
    ) {
        // Get the printable area height (stored as barbellWrapHeight for vertical labels)
        guard let printAreaHeight = format.barbellWrapHeight else {
            return
        }

        let paddingLeft = max(config.paddingLeft, 2)
        let paddingRight = max(config.paddingRight, 2)
        let paddingTop = max(config.paddingTop, 2)
        let paddingBottom = max(config.paddingBottom, 2)

        // Alternating pattern: (row + col) % 2 determines if label is flipped
        let isFlipped = (row + col) % 2 == 1

        // Stub height is the remaining space after the print area
        let stubHeight = format.barbellFlagWidth ?? (rect.height - printAreaHeight)
        let halfPrintHeight = printAreaHeight / 2

        context.saveGState()

        if isFlipped {
            // Rotate entire label 180° around its center
            context.translateBy(x: rect.midX, y: rect.midY)
            context.rotate(by: .pi)
            context.translateBy(x: -rect.midX, y: -rect.midY)
        }

        // Draw as if stub is at top:
        // [Stub - blank]
        // [Area A - normal]
        // [Area B - rotated 180°]

        let areaARect = CGRect(
            x: rect.minX,
            y: rect.minY + stubHeight,
            width: rect.width,
            height: halfPrintHeight
        )

        let areaBRect = CGRect(
            x: rect.minX,
            y: rect.minY + stubHeight + halfPrintHeight,
            width: rect.width,
            height: halfPrintHeight
        )

        // Draw Area A (normal orientation)
        drawPStyleFoldedArea(
            labelData: labelData,
            rect: areaARect,
            config: config,
            fontScale: fontScale,
            paddingLeft: paddingLeft,
            paddingRight: paddingRight,
            paddingTop: paddingTop,
            paddingBottom: paddingBottom,
            rotated: false,
            context: context
        )

        // Draw Area B (content rotated 180°)
        drawPStyleFoldedArea(
            labelData: labelData,
            rect: areaBRect,
            config: config,
            fontScale: fontScale,
            paddingLeft: paddingLeft,
            paddingRight: paddingRight,
            paddingTop: paddingTop,
            paddingBottom: paddingBottom,
            rotated: true,
            context: context
        )

        context.restoreGState()
    }

    /// Draw a single print area (A or B) of a p-style-folded label
    private func drawPStyleFoldedArea(
        labelData: LabelData,
        rect: CGRect,
        config: LabelBuilderConfig,
        fontScale: CGFloat,
        paddingLeft: CGFloat,
        paddingRight: CGFloat,
        paddingTop: CGFloat,
        paddingBottom: CGFloat,
        rotated: Bool,
        context: CGContext
    ) {
        context.saveGState()

        if rotated {
            context.translateBy(x: rect.midX, y: rect.midY)
            context.rotate(by: .pi)
            context.translateBy(x: -rect.midX, y: -rect.midY)
        }

        var contentX = rect.minX + paddingLeft
        var contentWidth = rect.width - paddingLeft - paddingRight

        // Draw QR code if configured
        if config.qrPosition != .none {
            let effectiveQRSize = config.qrSize ?? 0.7
            let qrSize = min(rect.width * 0.35, rect.height * effectiveQRSize)
            let qrImage = generateQRCode(for: labelData.stableId)

            let qrRect = CGRect(
                x: rect.minX + paddingLeft,
                y: rect.minY + (rect.height - qrSize) / 2,
                width: qrSize,
                height: qrSize
            )
            qrImage.draw(in: qrRect)

            contentX = qrRect.maxX + 2
            contentWidth = rect.maxX - paddingRight - contentX
        }

        // Draw text fields
        let textAlignment: NSTextAlignment = {
            switch config.textAlignment {
            case .left: return .left
            case .center: return .center
            case .right: return .right
            }
        }()

        // Calculate total text height for vertical centering
        var totalTextHeight: CGFloat = 0
        for field in config.textFields {
            let fieldFormat = config.format(for: field)
            let font: UIFont = fieldFormat.bold ? .boldSystemFont(ofSize: fieldFormat.fontSize * fontScale) : .systemFont(ofSize: fieldFormat.fontSize * fontScale)

            let shouldShow: Bool = {
                switch field {
                case .manufacturer: return labelData.manufacturer != nil
                case .sku: return labelData.sku != nil
                case .colorName: return labelData.colorName != nil
                case .coe: return labelData.coe != nil
                case .location: return labelData.location != nil
                case .owner: return labelData.owner != nil
                }
            }()

            if shouldShow {
                totalTextHeight += font.lineHeight + 1
            }
        }

        let availableHeight = rect.height - paddingTop - paddingBottom
        var yPosition = rect.minY + paddingTop + max(0, (availableHeight - totalTextHeight) / 2)

        // Draw each text field
        for field in config.textFields {
            let fieldFormat = config.format(for: field)
            let font: UIFont = fieldFormat.bold ? .boldSystemFont(ofSize: fieldFormat.fontSize * fontScale) : .systemFont(ofSize: fieldFormat.fontSize * fontScale)

            switch field {
            case .manufacturer:
                if let manufacturer = labelData.manufacturer {
                    let fullName = GlassManufacturers.fullName(for: manufacturer) ?? manufacturer
                    yPosition = drawText(fullName, at: CGPoint(x: contentX, y: yPosition), width: contentWidth, font: font, alignment: textAlignment, context: context, italic: fieldFormat.italic)
                }
            case .sku:
                if let sku = labelData.sku {
                    yPosition = drawText(sku, at: CGPoint(x: contentX, y: yPosition), width: contentWidth, font: font, alignment: textAlignment, context: context, italic: fieldFormat.italic)
                }
            case .colorName:
                if let colorName = labelData.colorName {
                    yPosition = drawText(colorName, at: CGPoint(x: contentX, y: yPosition), width: contentWidth, font: font, alignment: textAlignment, context: context, italic: fieldFormat.italic)
                }
            case .coe:
                if let coe = labelData.coe {
                    yPosition = drawText("COE \(coe)", at: CGPoint(x: contentX, y: yPosition), width: contentWidth, font: font, color: .darkGray, alignment: textAlignment, context: context, italic: fieldFormat.italic)
                }
            case .location:
                if let location = labelData.location {
                    yPosition = drawText(location, at: CGPoint(x: contentX, y: yPosition), width: contentWidth, font: font, alignment: textAlignment, context: context, italic: fieldFormat.italic)
                }
            case .owner:
                if let owner = labelData.owner {
                    yPosition = drawText(owner, at: CGPoint(x: contentX, y: yPosition), width: contentWidth, font: font, color: .darkGray, alignment: textAlignment, context: context, italic: fieldFormat.italic)
                }
            }
        }

        context.restoreGState()
    }

    private func drawText(
        _ text: String,
        at point: CGPoint,
        width: CGFloat,
        font: UIFont,
        color: UIColor = .black,
        alignment: NSTextAlignment = .left,
        context: CGContext,
        italic: Bool = false
    ) -> CGFloat {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = .byClipping  // Cut off at edge, no ellipsis

        // Apply italic if requested by creating italic font descriptor
        let finalFont: UIFont
        if italic {
            let descriptor = font.fontDescriptor.withSymbolicTraits(.traitItalic) ?? font.fontDescriptor
            finalFont = UIFont(descriptor: descriptor, size: font.pointSize)
        } else {
            finalFont = font
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: finalFont,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textRect = CGRect(x: point.x, y: point.y, width: width, height: font.lineHeight)

        attributedString.draw(in: textRect)

        return point.y + font.lineHeight + 1
    }
}
#else
// macOS stub - Label printing is iOS-only
@preconcurrency
class LabelPrintingService {
    // Label printing requires UIKit (UIImage, UIFont, UIColor) which is iOS-only
    // On macOS, this service is non-functional
}
#endif

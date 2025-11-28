//
//  LabelPreviewView.swift
//  Molten
//
//  Visual preview of label appearance based on format and template
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

#if os(iOS)
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

    /// Effective QR size (preset override or format default)
    private var effectiveQRSize: CGFloat {
        return config.qrSize ?? format.defaultQRSize
    }

    /// Effective manufacturer image size (config override or default 0.6)
    private var effectiveManufacturerImageSize: CGFloat {
        return config.manufacturerImageSize ?? 0.6
    }

    /// Manufacturer image view (if enabled and not overlapping)
    @ViewBuilder
    private func manufacturerImageView(size: CGFloat) -> some View {
        if config.manufacturerImagePosition != .none && !config.manufacturerImageOverlapsQR() {
            if let manufacturer = sampleData.manufacturer {
                // Manufacturer codes are uppercase (e.g., "EF", "BE"), but files are lowercase
                let imageName = "\(manufacturer.lowercased())_print.png"
                let _ = print("🖼️ Looking for manufacturer image: \(imageName)")

                if let image = UIImage(named: imageName) {
                    let _ = print("✅ Found manufacturer image: \(imageName)")
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: size * effectiveManufacturerImageSize)
                } else {
                    let _ = print("❌ Failed to load manufacturer image: \(imageName)")
                    // Debug: Show a placeholder to verify the space is there
                    Rectangle()
                        .fill(DesignSystem.Colors.accentDanger.opacity(0.3))
                        .frame(height: size * effectiveManufacturerImageSize)
                        .overlay(
                            Text("IMG?")
                                .font(.caption2)
                                .foregroundColor(.white)
                        )
                }
            }
        }
    }

    private var previewWidth: CGFloat {
        format.labelWidth * scaleFactor
    }

    private var previewHeight: CGFloat {
        format.labelHeight * scaleFactor
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Text("Label Preview")
                    .fontWeight(.semibold)
                Text("•")
                    .foregroundColor(.secondary)
                Text(format.name)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("•")
                    .foregroundColor(.secondary)
                Text(formattedDimensions)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }

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
        }
        .padding()
        .background(Color(.systemGray6))
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
            // No QR code, optional manufacturer images on sides, text in middle
            HStack(alignment: .top, spacing: 0) {
                // Manufacturer image on left (if enabled and left/both position)
                if config.manufacturerImagePosition == .left || config.manufacturerImagePosition == .both {
                    VStack {
                        Spacer()
                        manufacturerImageView(size: previewHeight)
                            .padding(.leading, 4)
                        Spacer()
                    }
                }

                VStack(alignment: alignmentFromConfig, spacing: 0) {
                    Spacer()
                    buildTextContent()
                        .padding(.horizontal, 4)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: frameAlignmentFromConfig)

                // Manufacturer image on right (if enabled and right/both position)
                if config.manufacturerImagePosition == .right || config.manufacturerImagePosition == .both {
                    VStack {
                        Spacer()
                        manufacturerImageView(size: previewHeight)
                            .padding(.trailing, 4)
                        Spacer()
                    }
                }
            }

        case .left:
            // QR code on left, text on right, optional manufacturer image on right
            HStack(alignment: .top, spacing: 0) {
                if let service = labelService {
                    let qrSize = previewHeight * effectiveQRSize
                    VStack {
                        Spacer()
                        QRCodeView(labelData: sampleData, service: service)
                            .frame(width: qrSize * 0.9, height: qrSize * 0.9)
                            .padding(.leading, 4)
                        Spacer()
                    }
                }

                VStack(alignment: alignmentFromConfig, spacing: 0) {
                    Spacer()
                    buildTextContent()
                        .padding(.leading, 4)
                        .padding(.trailing, 4)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: frameAlignmentFromConfig)

                // Manufacturer image on right (if enabled and right/both position)
                if config.manufacturerImagePosition == .right || config.manufacturerImagePosition == .both {
                    VStack {
                        Spacer()
                        manufacturerImageView(size: previewHeight)
                            .padding(.trailing, 4)
                        Spacer()
                    }
                }
            }

        case .right:
            // Optional manufacturer image on left, text in middle, QR code on right
            HStack(alignment: .top, spacing: 0) {
                // Manufacturer image on left (if enabled and left/both position)
                if config.manufacturerImagePosition == .left || config.manufacturerImagePosition == .both {
                    VStack {
                        Spacer()
                        manufacturerImageView(size: previewHeight)
                            .padding(.leading, 4)
                        Spacer()
                    }
                }

                VStack(alignment: alignmentFromConfig, spacing: 0) {
                    Spacer()
                    buildTextContent()
                        .padding(.leading, 4)
                        .padding(.trailing, 4)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: frameAlignmentFromConfig)

                if let service = labelService {
                    let qrSize = previewHeight * effectiveQRSize
                    VStack {
                        Spacer()
                        QRCodeView(labelData: sampleData, service: service)
                            .frame(width: qrSize * 0.9, height: qrSize * 0.9)
                            .padding(.trailing, 4)
                        Spacer()
                    }
                }
            }

        case .both:
            // QR codes on both sides, text in middle
            HStack(alignment: .top, spacing: 0) {
                if let service = labelService {
                    let qrSize = previewHeight * effectiveQRSize
                    VStack {
                        Spacer()
                        QRCodeView(labelData: sampleData, service: service)
                            .frame(width: qrSize * 0.9, height: qrSize * 0.9)
                            .padding(.leading, 4)
                        Spacer()
                    }
                }

                VStack(alignment: alignmentFromConfig, spacing: 0) {
                    Spacer()
                    buildTextContent()
                        .padding(.leading, 4)
                        .padding(.trailing, 4)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: frameAlignmentFromConfig)

                if let service = labelService {
                    let qrSize = previewHeight * effectiveQRSize
                    VStack {
                        Spacer()
                        QRCodeView(labelData: sampleData, service: service)
                            .frame(width: qrSize * 0.9, height: qrSize * 0.9)
                            .padding(.trailing, 4)
                        Spacer()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func buildTextContent() -> some View {
        VStack(alignment: .leading, spacing: 1) {
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
                // Convert manufacturer abbreviation to full name first
                let fullName = GlassManufacturers.fullName(for: manufacturer) ?? manufacturer

                // Check if SKU already starts with full manufacturer name (case-insensitive)
                // Only hide manufacturer if SKU literally starts with the full name (not just abbreviation)
                let skuStartsWithManufacturer: Bool = {
                    guard let sku = sampleData.sku,
                          config.textFields.contains(.sku) else {
                        return false
                    }
                    return sku.lowercased().hasPrefix(fullName.lowercased())
                }()

                // Only show manufacturer if SKU doesn't already start with it
                if !skuStartsWithManufacturer {
                    let fieldFormat = config.format(for: .manufacturer)
                    let displayFontSize = fieldFormat.fontSize * scaleFactor * fontScale
                    let actualFontSize = fieldFormat.fontSize * fontScale  // Font size on actual PDF (no scaleFactor)
                    let actualFont = fieldFormat.bold ? UIFont.boldSystemFont(ofSize: actualFontSize) : UIFont.systemFont(ofSize: actualFontSize)
                    let willTruncate = textWillTruncate(fullName, font: actualFont)

                    Text(fullName)
                        .font(.system(size: displayFontSize, weight: fieldFormat.bold ? .bold : .regular))
                        .italic(fieldFormat.italic)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .background(willTruncate ? DesignSystem.Colors.accentDanger.opacity(0.2) : Color.clear)
                }
            }

        case .sku:
            if let sku = sampleData.sku {
                let fieldFormat = config.format(for: .sku)
                let displayFontSize = fieldFormat.fontSize * scaleFactor * fontScale
                let actualFontSize = fieldFormat.fontSize * fontScale
                let actualFont = fieldFormat.bold ? UIFont.boldSystemFont(ofSize: actualFontSize) : UIFont.systemFont(ofSize: actualFontSize)
                let willTruncate = textWillTruncate(sku, font: actualFont)

                Text(sku)
                    .font(.system(size: displayFontSize, weight: fieldFormat.bold ? .bold : .regular))
                    .italic(fieldFormat.italic)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .background(willTruncate ? DesignSystem.Colors.accentDanger.opacity(0.2) : Color.clear)
            }

        case .colorName:
            if let colorName = sampleData.colorName {
                let fieldFormat = config.format(for: .colorName)
                let displayFontSize = fieldFormat.fontSize * scaleFactor * fontScale
                let actualFontSize = fieldFormat.fontSize * fontScale
                let actualFont = fieldFormat.bold ? UIFont.boldSystemFont(ofSize: actualFontSize) : UIFont.systemFont(ofSize: actualFontSize)
                let willTruncate = textWillTruncate(colorName, font: actualFont)

                Text(colorName)
                    .font(.system(size: displayFontSize, weight: fieldFormat.bold ? .bold : .regular))
                    .italic(fieldFormat.italic)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .background(willTruncate ? DesignSystem.Colors.accentDanger.opacity(0.2) : Color.clear)
            }

        case .coe:
            if let coe = sampleData.coe {
                let text = "COE \(coe)"
                let fieldFormat = config.format(for: .coe)
                let displayFontSize = fieldFormat.fontSize * scaleFactor * fontScale
                let actualFontSize = fieldFormat.fontSize * fontScale
                let actualFont = fieldFormat.bold ? UIFont.boldSystemFont(ofSize: actualFontSize) : UIFont.systemFont(ofSize: actualFontSize)
                let willTruncate = textWillTruncate(text, font: actualFont)

                Text(text)
                    .font(.system(size: displayFontSize, weight: fieldFormat.bold ? .bold : .regular))
                    .italic(fieldFormat.italic)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .background(willTruncate ? DesignSystem.Colors.accentDanger.opacity(0.2) : Color.clear)
            }

        case .location:
            if let location = sampleData.location {
                let text = "📍 \(location)"
                let fieldFormat = config.format(for: .location)
                let displayFontSize = fieldFormat.fontSize * scaleFactor * fontScale
                let actualFontSize = fieldFormat.fontSize * fontScale
                let actualFont = fieldFormat.bold ? UIFont.boldSystemFont(ofSize: actualFontSize) : UIFont.systemFont(ofSize: actualFontSize)
                let willTruncate = textWillTruncate(text, font: actualFont)

                Text(text)
                    .font(.system(size: displayFontSize, weight: fieldFormat.bold ? .bold : .regular))
                    .italic(fieldFormat.italic)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .background(willTruncate ? DesignSystem.Colors.accentDanger.opacity(0.2) : Color.clear)
            }

        case .owner:
            if let owner = sampleData.owner {
                let fieldFormat = config.format(for: .owner)
                let displayFontSize = fieldFormat.fontSize * scaleFactor * fontScale
                let actualFontSize = fieldFormat.fontSize * fontScale
                let actualFont = fieldFormat.bold ? UIFont.boldSystemFont(ofSize: actualFontSize) : UIFont.systemFont(ofSize: actualFontSize)
                let willTruncate = textWillTruncate(owner, font: actualFont)

                Text(owner)
                    .font(.system(size: displayFontSize, weight: fieldFormat.bold ? .bold : .regular))
                    .italic(fieldFormat.italic)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .background(willTruncate ? DesignSystem.Colors.accentDanger.opacity(0.2) : Color.clear)
            }
        }
    }

    /// Check if text will be truncated given the available width
    private func textWillTruncate(_ text: String, font: UIFont) -> Bool {
        // Calculate available width based on QR position and manufacturer image
        let padding: CGFloat = 4
        var availableWidth = format.labelWidth - (padding * 2)

        // Account for QR code space
        if config.qrPosition != .none {
            let qrSize = format.labelHeight * effectiveQRSize

            switch config.qrPosition {
            case .left, .right:
                availableWidth -= (qrSize + padding)
            case .both:
                availableWidth -= (2 * qrSize + 2 * padding)
            case .none:
                break
            }
        }

        // Account for manufacturer image space (if enabled and not overlapping)
        if config.manufacturerImagePosition != .none && !config.manufacturerImageOverlapsQR() {
            let imageSize = format.labelHeight * effectiveManufacturerImageSize

            switch config.manufacturerImagePosition {
            case .left, .right:
                availableWidth -= (imageSize + padding)
            case .both:
                availableWidth -= (2 * imageSize + 2 * padding)
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

    /// Convert config text alignment to SwiftUI HorizontalAlignment
    private var alignmentFromConfig: HorizontalAlignment {
        switch config.textAlignment {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }

    /// Convert config text alignment to SwiftUI Alignment (for frame)
    private var frameAlignmentFromConfig: Alignment {
        switch config.textAlignment {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }
}

/// QR Code generator view
private struct QRCodeView: View {
    let labelData: LabelData
    let service: LabelPrintingService

    @State private var qrImage: UIImage?

    /// Cache key for detecting changes
    private var cacheKey: String {
        [labelData.stableId, labelData.inventoryType, labelData.inventorySubtype, labelData.inventorySubsubtype]
            .compactMap { $0 }
            .joined(separator: ":")
    }

    var body: some View {
        Group {
            if let qrImage = qrImage {
                Image(uiImage: qrImage)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
            }
        }
        .onAppear {
            qrImage = service.generateQRCode(for: labelData)
        }
        .onChange(of: cacheKey) { _, _ in
            // Regenerate QR code when label data changes
            qrImage = service.generateQRCode(for: labelData)
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
            location: nil,
            owner: nil
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
            location: nil,
            owner: nil
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
            location: nil,
            owner: nil
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
            location: "Studio Shelf A2",
            owner: nil
        )
    )
}
#endif

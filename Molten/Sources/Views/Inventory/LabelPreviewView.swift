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
    let format: LabelGeometry
    let config: LabelBuilderConfig
    let sampleData: LabelData
    var fontScale: Double = 1.0

    // Position offsets now come from config.positionHorizontal/positionVertical
    private var offsetX: Double { Double(config.positionHorizontal) }
    private var offsetY: Double { Double(config.positionVertical) }

    // CRITICAL: Cache service instance in @State to prevent recreation on every body evaluation
    @State private var labelService: LabelPrintingService?

    // Scale factor to make labels visible on screen
    private var scaleFactor: CGFloat {
        // Scale to fit nicely in preview area (roughly 200-300pt wide)
        let targetWidth: CGFloat = 280
        return targetWidth / format.labelWidth
    }

    // MARK: - QR Code Sizing Constants (must match LabelPrintingService)

    /// Minimum QR code size in points (must be scannable)
    private let minQRSize: CGFloat = 36  // ~0.5 inch

    /// Maximum QR code size in points (no need to be huge on large labels)
    private let maxQRSize: CGFloat = 108  // ~1.5 inches

    /// Effective QR size in points (clamped to min/max bounds)
    /// This matches the logic in LabelPrintingService.calculateQRSize
    private var effectiveQRSize: CGFloat {
        let qrPercent = config.qrSize ?? format.defaultQRSize
        let desiredSize = format.labelHeight * qrPercent
        return min(max(desiredSize, minQRSize), maxQRSize)
    }

    /// Effective QR size as percentage for compatibility (some places still use percentage)
    private var effectiveQRPercent: CGFloat {
        return config.qrSize ?? format.defaultQRSize
    }

    // MARK: - Font Scaling Constants (must match LabelPrintingService)

    /// Reference label height for font sizing (1 inch = 72pt)
    private let referenceLabelHeight: CGFloat = 72

    /// Maximum font scale multiplier for large labels
    private let maxFontScaleMultiplier: CGFloat = 2.5

    /// Label-based font scale multiplier
    /// Larger labels get proportionally larger text, capped at maxFontScaleMultiplier
    private var labelBasedFontScale: CGFloat {
        let ratio = format.labelHeight / referenceLabelHeight
        return min(max(ratio, 1.0), maxFontScaleMultiplier)
    }

    /// Effective font scale combining user setting with label-based scaling
    private var effectiveFontScale: CGFloat {
        return fontScale * labelBasedFontScale
    }

    /// Effective manufacturer image size (config override or default 0.6)
    private var effectiveManufacturerImageSize: CGFloat {
        return config.manufacturerImageSize ?? 0.6
    }

    /// Computed barbell dimensions with defaults
    /// For p-style-folded, these are reinterpreted for vertical orientation
    private var barbellFlagWidthScaled: CGFloat {
        (format.barbellFlagWidth ?? format.labelWidth / 3) * scaleFactor
    }

    private var barbellWrapHeightScaled: CGFloat {
        (format.barbellWrapHeight ?? format.labelHeight * 0.4) * scaleFactor
    }

    /// Returns the appropriate shape for the barbell style
    private func barbellShapeView() -> AnyShape {
        switch format.barbellStyle {
        case .tStyle:
            return AnyShape(TStyleShape(flagWidth: barbellFlagWidthScaled, wrapHeight: barbellWrapHeightScaled))
        case .pStyle:
            return AnyShape(PStyleShape(flagWidth: barbellFlagWidthScaled, wrapHeight: barbellWrapHeightScaled))
        case .pStyleFolded:
            // Short stub tail to show where wrap attaches
            return AnyShape(PStyleFoldedShape(flagWidth: barbellFlagWidthScaled, wrapHeight: barbellWrapHeightScaled))
        case .wrap:
            return AnyShape(WrapShape(wrapHeight: barbellWrapHeightScaled))
        case .symmetric, .none:
            return AnyShape(BarbellShape(flagWidth: barbellFlagWidthScaled, wrapHeight: barbellWrapHeightScaled))
        }
    }

    /// Returns the clip shape for the label
    private func labelClipShape() -> AnyShape {
        if format.isCircular {
            return AnyShape(Circle())
        } else if format.isBarbell {
            switch format.barbellStyle {
            case .tStyle:
                return AnyShape(TStyleShape(flagWidth: barbellFlagWidthScaled, wrapHeight: barbellWrapHeightScaled))
            case .pStyle:
                return AnyShape(PStyleShape(flagWidth: barbellFlagWidthScaled, wrapHeight: barbellWrapHeightScaled))
            case .pStyleFolded:
                return AnyShape(PStyleFoldedShape(flagWidth: barbellFlagWidthScaled, wrapHeight: barbellWrapHeightScaled))
            case .wrap:
                return AnyShape(WrapShape(wrapHeight: barbellWrapHeightScaled))
            case .symmetric, .none:
                return AnyShape(BarbellShape(flagWidth: barbellFlagWidthScaled, wrapHeight: barbellWrapHeightScaled))
            }
        } else {
            return AnyShape(RoundedRectangle(cornerRadius: 4))
        }
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
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                Text(format.name)
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                Text("•")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                Text(formattedDimensions)
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                Spacer()
            }

            // Label preview with border (circular, barbell, or rectangular)
            // Red border indicates content will be clipped (overflow)
            let hasOverflow = format.isBarbell ? barbellContentWillOverflowVertically : contentWillOverflowVertically
            let borderColor = hasOverflow ? DesignSystem.Colors.accentDanger : Color.gray.opacity(0.3)
            let borderWidth: CGFloat = hasOverflow ? 2 : 1

            ZStack {
                if format.isCircular {
                    Circle()
                        .stroke(borderColor, lineWidth: borderWidth)
                        .background(
                            Circle()
                                .fill(Color.white)
                        )
                } else if format.isBarbell {
                    // Barbell/flag shape: varies by style
                    barbellShapeView()
                        .stroke(borderColor, lineWidth: borderWidth)
                        .background(barbellShapeView().fill(Color.white))
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(borderColor, lineWidth: borderWidth)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white)
                        )
                }

                // Label content based on shape and QR position
                if format.isBarbell {
                    // For barbell labels, show content in the left flag area only
                    buildBarbellContent()
                } else if format.isCircular {
                    // For circular labels, use vertical layout (top/bottom)
                    buildCircularLabelContent()
                        .frame(width: previewWidth * 0.7, height: previewHeight * 0.7)
                        .offset(x: offsetX * scaleFactor, y: offsetY * scaleFactor)
                } else if format.shape == .portrait || format.shape == .square {
                    // For portrait/tall and square labels, use vertical layout (top/bottom)
                    // Text expands horizontally, so QR codes go at top/bottom
                    buildPortraitLabelContent()
                        .frame(width: previewWidth - 8, height: previewHeight - 8)
                        .padding(4)
                        .offset(x: offsetX * scaleFactor, y: offsetY * scaleFactor)
                } else {
                    buildLabelContent()
                        .frame(height: previewHeight - 8)
                        .padding(.vertical, 4)
                        .offset(x: offsetX * scaleFactor, y: offsetY * scaleFactor)
                }
            }
            .frame(width: previewWidth, height: previewHeight)
            .clipShape(labelClipShape())
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
                    let qrSize = effectiveQRSize * scaleFactor  // effectiveQRSize is in points, scale for preview
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
                    let qrSize = effectiveQRSize * scaleFactor  // effectiveQRSize is in points, scale for preview
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
                    let qrSize = effectiveQRSize * scaleFactor  // effectiveQRSize is in points, scale for preview
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
                    let qrSize = effectiveQRSize * scaleFactor  // effectiveQRSize is in points, scale for preview
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

    // MARK: - Circular Label Content Builder

    /// Build content for circular/oval labels with vertical layout (top/bottom QR positions)
    @ViewBuilder
    private func buildCircularLabelContent() -> some View {
        let qrSize = effectiveQRSize * scaleFactor * 0.8  // Slightly smaller for circular labels

        switch config.qrPosition {
        case .none:
            // Just text centered
            VStack(alignment: .center, spacing: 2) {
                Spacer()
                buildTextContent()
                Spacer()
            }

        case .left:  // "Top" for circular
            // QR at top, text below
            VStack(alignment: .center, spacing: 4) {
                if let service = labelService {
                    QRCodeView(labelData: sampleData, service: service)
                        .frame(width: qrSize, height: qrSize)
                }
                Spacer()
                buildTextContent()
                Spacer()
            }

        case .right:  // "Bottom" for circular
            // Text at top, QR at bottom
            VStack(alignment: .center, spacing: 4) {
                Spacer()
                buildTextContent()
                Spacer()
                if let service = labelService {
                    QRCodeView(labelData: sampleData, service: service)
                        .frame(width: qrSize, height: qrSize)
                }
            }

        case .both:  // "Top & Bottom" for circular
            // QR at top, text in middle, QR at bottom
            VStack(alignment: .center, spacing: 2) {
                if let service = labelService {
                    QRCodeView(labelData: sampleData, service: service)
                        .frame(width: qrSize * 0.8, height: qrSize * 0.8)
                }
                Spacer()
                buildTextContent()
                Spacer()
                if let service = labelService {
                    QRCodeView(labelData: sampleData, service: service)
                        .frame(width: qrSize * 0.8, height: qrSize * 0.8)
                }
            }
        }
    }

    // MARK: - Portrait Label Content Builder

    /// Build content for portrait/tall labels with vertical layout (top/bottom QR positions)
    @ViewBuilder
    private func buildPortraitLabelContent() -> some View {
        let qrSize = effectiveQRSize * scaleFactor

        switch config.qrPosition {
        case .none:
            // Just text centered
            VStack(alignment: alignmentFromConfig, spacing: 2) {
                Spacer()
                buildTextContent()
                Spacer()
            }

        case .left:  // "Top" for portrait
            // QR at top, text below
            VStack(alignment: .center, spacing: 4) {
                if let service = labelService {
                    QRCodeView(labelData: sampleData, service: service)
                        .frame(width: qrSize, height: qrSize)
                }
                Spacer()
                VStack(alignment: alignmentFromConfig, spacing: 1) {
                    buildTextContent()
                }
                .frame(maxWidth: .infinity, alignment: frameAlignmentFromConfig)
                Spacer()
            }

        case .right:  // "Bottom" for portrait
            // Text at top, QR at bottom
            VStack(alignment: .center, spacing: 4) {
                Spacer()
                VStack(alignment: alignmentFromConfig, spacing: 1) {
                    buildTextContent()
                }
                .frame(maxWidth: .infinity, alignment: frameAlignmentFromConfig)
                Spacer()
                if let service = labelService {
                    QRCodeView(labelData: sampleData, service: service)
                        .frame(width: qrSize, height: qrSize)
                }
            }

        case .both:  // "Top & Bottom" for portrait
            // QR at top, text in middle, QR at bottom
            VStack(alignment: .center, spacing: 2) {
                if let service = labelService {
                    QRCodeView(labelData: sampleData, service: service)
                        .frame(width: qrSize * 0.85, height: qrSize * 0.85)
                }
                Spacer()
                VStack(alignment: alignmentFromConfig, spacing: 1) {
                    buildTextContent()
                }
                .frame(maxWidth: .infinity, alignment: frameAlignmentFromConfig)
                Spacer()
                if let service = labelService {
                    QRCodeView(labelData: sampleData, service: service)
                        .frame(width: qrSize * 0.85, height: qrSize * 0.85)
                }
            }
        }
    }

    /// Build content for barbell/flag labels - varies by style
    @ViewBuilder
    private func buildBarbellContent() -> some View {
        switch format.barbellStyle {
        case .tStyle, .pStyle:
            // Single flag styles - only one printable area on the left
            buildSingleFlagContent()
        case .pStyleFolded:
            // P-style folded: flag split horizontally with fold line (top=Area A, bottom=Area B)
            buildFoldedFlagContent()
        case .wrap:
            // Wrap style - content centered in the strip
            buildWrapContent()
        case .symmetric, .none:
            // Symmetric barbell - two flag areas
            buildSymmetricBarbellContent()
        }
    }

    /// Build content for symmetric barbell (two flags)
    @ViewBuilder
    private func buildSymmetricBarbellContent() -> some View {
        // Use user's font scale directly - they can adjust if text doesn't fit
        let barbellFontScale: CGFloat = effectiveFontScale

        HStack(spacing: 0) {
            // Left flag area - text content
            VStack(alignment: .center, spacing: 0) {
                Spacer()
                buildBarbellTextContent(fontScale: barbellFontScale)
                    .padding(.horizontal, 2)
                Spacer()
            }
            .frame(width: barbellFlagWidthScaled, height: previewHeight)

            // Middle wrap section (narrow, shows structure)
            Rectangle()
                .fill(Color.clear)
                .frame(width: previewWidth - (2 * barbellFlagWidthScaled))

            // Right flag area - QR code (if enabled) or mirrored text
            VStack {
                Spacer()
                if config.qrPosition != .none, let service = labelService {
                    // Match PDF logic: qrSize = label_height * qrPercent, clamped to fit flag
                    let qrPercent = config.qrSize ?? 0.65
                    let desiredQRSize = format.labelHeight * qrPercent
                    let maxFlagSize = min(format.barbellFlagWidth ?? format.labelWidth / 3, format.labelHeight) - 4  // 4pt = padding * 2
                    let actualQRSize = min(desiredQRSize, maxFlagSize)
                    let qrSizeScaled = actualQRSize * scaleFactor
                    QRCodeView(labelData: sampleData, service: service)
                        .frame(width: qrSizeScaled, height: qrSizeScaled)
                } else {
                    // Mirror text content on right flag
                    buildBarbellTextContent(fontScale: barbellFontScale)
                        .padding(.horizontal, 2)
                }
                Spacer()
            }
            .frame(width: barbellFlagWidthScaled, height: previewHeight)
        }
    }

    /// Build text content for barbell labels with custom font scaling
    @ViewBuilder
    private func buildBarbellTextContent(fontScale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(config.textFields, id: \.self) { field in
                buildBarbellTextField(field, fontScale: fontScale)
            }
        }
    }

    /// Build a single text field for barbell labels with truncation warning
    @ViewBuilder
    private func buildBarbellTextField(_ field: LabelTextField, fontScale: CGFloat) -> some View {
        let fieldFormat = config.format(for: field)
        // Use the passed-in fontScale (user's effective font scale)
        let displayFontSize = fieldFormat.fontSize * scaleFactor * fontScale
        // Calculate actual font size for truncation check (matches PDF rendering)
        let actualFontSize = fieldFormat.fontSize * fontScale
        let actualFont = fieldFormat.bold ? UIFont.boldSystemFont(ofSize: actualFontSize) : UIFont.systemFont(ofSize: actualFontSize)

        switch field {
        case .manufacturer:
            if let manufacturer = sampleData.manufacturer {
                let fullName = GlassManufacturers.fullName(for: manufacturer) ?? manufacturer
                let skuStartsWithManufacturer: Bool = {
                    guard let sku = sampleData.sku, config.textFields.contains(.sku) else { return false }
                    return sku.lowercased().hasPrefix(fullName.lowercased())
                }()
                if !skuStartsWithManufacturer {
                    let willTruncate = barbellTextWillTruncate(fullName, font: actualFont)
                    Text(fullName)
                        .font(.system(size: displayFontSize, weight: fieldFormat.bold ? .bold : .regular))
                        .italic(fieldFormat.italic)
                        .lineLimit(1)
                        .background(willTruncate ? DesignSystem.Colors.accentDanger.opacity(0.2) : Color.clear)
                }
            }
        case .sku:
            if let sku = sampleData.sku {
                let willTruncate = barbellTextWillTruncate(sku, font: actualFont)
                Text(sku)
                    .font(.system(size: displayFontSize, weight: fieldFormat.bold ? .bold : .regular))
                    .italic(fieldFormat.italic)
                    .lineLimit(1)
                    .background(willTruncate ? DesignSystem.Colors.accentDanger.opacity(0.2) : Color.clear)
            }
        case .colorName:
            if let colorName = sampleData.colorName {
                let willTruncate = barbellTextWillTruncate(colorName, font: actualFont)
                Text(colorName)
                    .font(.system(size: displayFontSize, weight: fieldFormat.bold ? .bold : .regular))
                    .italic(fieldFormat.italic)
                    .lineLimit(1)
                    .background(willTruncate ? DesignSystem.Colors.accentDanger.opacity(0.2) : Color.clear)
            }
        case .coe:
            if let coe = sampleData.coe {
                let text = "COE \(coe)"
                let willTruncate = barbellTextWillTruncate(text, font: actualFont)
                Text(text)
                    .font(.system(size: displayFontSize, weight: fieldFormat.bold ? .bold : .regular))
                    .italic(fieldFormat.italic)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .lineLimit(1)
                    .background(willTruncate ? DesignSystem.Colors.accentDanger.opacity(0.2) : Color.clear)
            }
        case .location:
            if let location = sampleData.location {
                let willTruncate = barbellTextWillTruncate(location, font: actualFont)
                Text(location)
                    .font(.system(size: displayFontSize, weight: fieldFormat.bold ? .bold : .regular))
                    .italic(fieldFormat.italic)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .lineLimit(1)
                    .background(willTruncate ? DesignSystem.Colors.accentDanger.opacity(0.2) : Color.clear)
            }
        case .owner:
            if let owner = sampleData.owner {
                let willTruncate = barbellTextWillTruncate(owner, font: actualFont)
                Text(owner)
                    .font(.system(size: displayFontSize, weight: fieldFormat.bold ? .bold : .regular))
                    .italic(fieldFormat.italic)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .lineLimit(1)
                    .background(willTruncate ? DesignSystem.Colors.accentDanger.opacity(0.2) : Color.clear)
            }
        }
    }

    /// Check if text will be truncated in barbell flag area
    private func barbellTextWillTruncate(_ text: String, font: UIFont) -> Bool {
        // For barbell labels, available width is the flag width minus padding
        let padding: CGFloat = 2
        let flagWidth = format.barbellFlagWidth ?? format.labelWidth / 3
        let availableWidth = flagWidth - (padding * 2)

        // Calculate text width using actual font metrics (matches PDF rendering)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (text as NSString).size(withAttributes: attributes)

        return textSize.width > availableWidth
    }

    /// Build content for T-style and P-style (single flag)
    @ViewBuilder
    private func buildSingleFlagContent() -> some View {
        HStack(spacing: 0) {
            // Flag area - contains both text and optional QR
            VStack(alignment: .center, spacing: 1) {
                Spacer()
                if config.qrPosition != .none, let service = labelService {
                    // Stack QR and text vertically in the single flag
                    HStack(spacing: 2) {
                        let qrSize = min(barbellFlagWidthScaled * 0.4, previewHeight * 0.8)
                        QRCodeView(labelData: sampleData, service: service)
                            .frame(width: qrSize, height: qrSize)
                        buildTextContent()
                            .padding(.horizontal, 2)
                    }
                } else {
                    buildTextContent()
                        .padding(.horizontal, 2)
                }
                Spacer()
            }
            .frame(width: barbellFlagWidthScaled, height: previewHeight)

            // Wrap tail section (narrow, non-printable area)
            Rectangle()
                .fill(Color.clear)
                .frame(width: previewWidth - barbellFlagWidthScaled)
        }
    }

    /// Build content for P-style folded cable labels
    /// Layout: [Print Area A (top)] [fold line] [Print Area B (bottom, rotated)] + [stub centered on right]
    @ViewBuilder
    private func buildFoldedFlagContent() -> some View {
        // Print area width must match the shape's flagWidth (barbellFlagWidthScaled)
        let printAreaWidth = barbellFlagWidthScaled
        let halfFlagHeight = previewHeight / 2
        let stubWidth = previewWidth - printAreaWidth
        let stubHeight = barbellWrapHeightScaled  // Stub is narrower than full height
        let stubY: CGFloat = 0  // P-style: stub at TOP right

        HStack(alignment: .top, spacing: 0) {
            // LEFT SIDE: Print Areas A and B
            VStack(spacing: 0) {
                // Print Area A (top half)
                ZStack {
                    if config.qrPosition != .none, let service = labelService {
                        HStack(spacing: 2) {
                            let qrSize = min(printAreaWidth * 0.35, halfFlagHeight * 0.85)
                            QRCodeView(labelData: sampleData, service: service)
                                .frame(width: qrSize, height: qrSize)
                            buildTextContent()
                                .padding(.horizontal, 2)
                        }
                    } else {
                        buildTextContent()
                            .padding(.horizontal, 2)
                    }
                }
                .frame(width: printAreaWidth, height: halfFlagHeight)
                .border(Color.gray.opacity(0.6), width: 1)

                // Dashed fold line between A and B
                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundColor(Color.gray.opacity(0.5))
                    .frame(width: printAreaWidth, height: 1)

                // Print Area B (bottom half) - content rotated 180°
                ZStack {
                    Group {
                        if config.qrPosition != .none, let service = labelService {
                            HStack(spacing: 2) {
                                let qrSize = min(printAreaWidth * 0.35, halfFlagHeight * 0.85)
                                QRCodeView(labelData: sampleData, service: service)
                                    .frame(width: qrSize, height: qrSize)
                                buildTextContent()
                                    .padding(.horizontal, 2)
                            }
                        } else {
                            buildTextContent()
                                .padding(.horizontal, 2)
                        }
                    }
                    .rotationEffect(.degrees(180))
                }
                .frame(width: printAreaWidth, height: halfFlagHeight)
                .border(Color.gray.opacity(0.6), width: 1)
            }
            .frame(width: printAreaWidth, height: previewHeight)

            // RIGHT SIDE: Stub at top (P-style)
            VStack(spacing: 0) {
                // Stub with diagonal stripes
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.08))
                        .overlay(
                            DiagonalStripePattern()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .clipped()
                    Rectangle()
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                }
                .frame(height: stubHeight)

                Spacer()
            }
            .frame(width: stubWidth, height: previewHeight)
        }
        .frame(width: previewWidth, height: previewHeight)
    }

    /// Diagonal stripe pattern for non-printable areas
    struct DiagonalStripePattern: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            let spacing: CGFloat = 6
            let diagonal = sqrt(rect.width * rect.width + rect.height * rect.height)

            for offset in stride(from: -diagonal, through: diagonal, by: spacing) {
                path.move(to: CGPoint(x: offset, y: 0))
                path.addLine(to: CGPoint(x: offset + rect.height, y: rect.height))
            }
            return path
        }
    }

    /// Simple tapered stub shape (starts at left edge, tapers toward right)
    struct TaperedStubShape: Shape {
        let wrapY: CGFloat
        let wrapHeight: CGFloat
        let taperAmount: CGFloat

        func path(in rect: CGRect) -> Path {
            var path = Path()

            path.move(to: CGPoint(x: 0, y: wrapY))
            path.addLine(to: CGPoint(x: rect.width, y: wrapY + taperAmount))
            path.addLine(to: CGPoint(x: rect.width, y: wrapY + wrapHeight - taperAmount))
            path.addLine(to: CGPoint(x: 0, y: wrapY + wrapHeight))
            path.closeSubpath()

            return path
        }
    }

    /// Build content for wrap-style labels (content in center strip)
    @ViewBuilder
    private func buildWrapContent() -> some View {
        // Content centered in the narrow wrap area
        HStack(spacing: 2) {
            Spacer()
            if config.qrPosition != .none, let service = labelService {
                let qrSize = barbellWrapHeightScaled * 0.9
                QRCodeView(labelData: sampleData, service: service)
                    .frame(width: qrSize, height: qrSize)
            }
            buildTextContent()
                .padding(.horizontal, 2)
            Spacer()
        }
        .frame(height: barbellWrapHeightScaled)
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
                    let displayFontSize = fieldFormat.fontSize * scaleFactor * effectiveFontScale
                    let actualFontSize = fieldFormat.fontSize * effectiveFontScale  // Font size on actual PDF (no scaleFactor)
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
                let displayFontSize = fieldFormat.fontSize * scaleFactor * effectiveFontScale
                let actualFontSize = fieldFormat.fontSize * effectiveFontScale
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
                let displayFontSize = fieldFormat.fontSize * scaleFactor * effectiveFontScale
                let actualFontSize = fieldFormat.fontSize * effectiveFontScale
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
                let displayFontSize = fieldFormat.fontSize * scaleFactor * effectiveFontScale
                let actualFontSize = fieldFormat.fontSize * effectiveFontScale
                let actualFont = fieldFormat.bold ? UIFont.boldSystemFont(ofSize: actualFontSize) : UIFont.systemFont(ofSize: actualFontSize)
                let willTruncate = textWillTruncate(text, font: actualFont)

                Text(text)
                    .font(.system(size: displayFontSize, weight: fieldFormat.bold ? .bold : .regular))
                    .italic(fieldFormat.italic)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .background(willTruncate ? DesignSystem.Colors.accentDanger.opacity(0.2) : Color.clear)
            }

        case .location:
            if let location = sampleData.location {
                let text = "📍 \(location)"
                let fieldFormat = config.format(for: .location)
                let displayFontSize = fieldFormat.fontSize * scaleFactor * effectiveFontScale
                let actualFontSize = fieldFormat.fontSize * effectiveFontScale
                let actualFont = fieldFormat.bold ? UIFont.boldSystemFont(ofSize: actualFontSize) : UIFont.systemFont(ofSize: actualFontSize)
                let willTruncate = textWillTruncate(text, font: actualFont)

                Text(text)
                    .font(.system(size: displayFontSize, weight: fieldFormat.bold ? .bold : .regular))
                    .italic(fieldFormat.italic)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .background(willTruncate ? DesignSystem.Colors.accentDanger.opacity(0.2) : Color.clear)
            }

        case .owner:
            if let owner = sampleData.owner {
                let fieldFormat = config.format(for: .owner)
                let displayFontSize = fieldFormat.fontSize * scaleFactor * effectiveFontScale
                let actualFontSize = fieldFormat.fontSize * effectiveFontScale
                let actualFont = fieldFormat.bold ? UIFont.boldSystemFont(ofSize: actualFontSize) : UIFont.systemFont(ofSize: actualFontSize)
                let willTruncate = textWillTruncate(owner, font: actualFont)

                Text(owner)
                    .font(.system(size: displayFontSize, weight: fieldFormat.bold ? .bold : .regular))
                    .italic(fieldFormat.italic)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .background(willTruncate ? DesignSystem.Colors.accentDanger.opacity(0.2) : Color.clear)
            }
        }
    }

    /// Check if content will overflow vertically (be clipped)
    private var contentWillOverflowVertically: Bool {
        let padding: CGFloat = 4

        // Calculate available height based on label shape and QR position
        var availableHeight: CGFloat

        // Determine if this label uses vertical layout (top/bottom QR positioning)
        // Circular, portrait, and square labels all use vertical layout since text expands horizontally
        let usesVerticalLayout = format.isCircular || format.shape == .portrait || format.shape == .square

        if format.isCircular {
            // For circular labels, the usable area is smaller (inscribed content area)
            // Use ~70% of diameter for content to stay within the circle
            availableHeight = format.labelHeight * 0.7 - (padding * 2)

            // For circular labels, QR codes take vertical space (top/bottom)
            if config.qrPosition != .none {
                let qrSize = effectiveQRSize
                switch config.qrPosition {
                case .left, .right:  // Top or Bottom for circular
                    availableHeight -= (qrSize + padding)
                case .both:  // Top & Bottom for circular
                    availableHeight -= (2 * qrSize + 2 * padding)
                case .none:
                    break
                }
            }
        } else if usesVerticalLayout {
            // Portrait labels - QR codes take vertical space (top/bottom)
            availableHeight = format.labelHeight - (padding * 2)

            if config.qrPosition != .none {
                let qrSize = effectiveQRSize
                switch config.qrPosition {
                case .left, .right:  // Top or Bottom for portrait
                    availableHeight -= (qrSize + padding)
                case .both:  // Top & Bottom for portrait
                    availableHeight -= (2 * qrSize + 2 * padding)
                case .none:
                    break
                }
            }
        } else {
            // Landscape and square labels - QR codes take horizontal space, not vertical
            availableHeight = format.labelHeight - (padding * 2)
        }

        // Calculate total text height
        var totalTextHeight: CGFloat = 0
        for field in config.textFields {
            let fieldFormat = config.format(for: field)
            let actualFontSize = fieldFormat.fontSize * effectiveFontScale
            let font = fieldFormat.bold ? UIFont.boldSystemFont(ofSize: actualFontSize) : UIFont.systemFont(ofSize: actualFontSize)

            // Only count if the field has data
            let hasData: Bool = {
                switch field {
                case .manufacturer: return sampleData.manufacturer != nil
                case .sku: return sampleData.sku != nil
                case .colorName: return sampleData.colorName != nil
                case .coe: return sampleData.coe != nil
                case .location: return sampleData.location != nil
                case .owner: return sampleData.owner != nil
                }
            }()

            if hasData {
                totalTextHeight += font.lineHeight + 1
            }
        }

        return totalTextHeight > availableHeight
    }

    /// Check if barbell content will overflow vertically
    private var barbellContentWillOverflowVertically: Bool {
        let padding: CGFloat = 2
        let availableHeight = format.labelHeight - (padding * 2)

        // Calculate total text height with user's font scale
        let barbellFontScale = effectiveFontScale
        var totalTextHeight: CGFloat = 0
        for field in config.textFields {
            let fieldFormat = config.format(for: field)
            let actualFontSize = fieldFormat.fontSize * barbellFontScale
            let font = fieldFormat.bold ? UIFont.boldSystemFont(ofSize: actualFontSize) : UIFont.systemFont(ofSize: actualFontSize)

            let hasData: Bool = {
                switch field {
                case .manufacturer: return sampleData.manufacturer != nil
                case .sku: return sampleData.sku != nil
                case .colorName: return sampleData.colorName != nil
                case .coe: return sampleData.coe != nil
                case .location: return sampleData.location != nil
                case .owner: return sampleData.owner != nil
                }
            }()

            if hasData {
                totalTextHeight += font.lineHeight + 1
            }
        }

        return totalTextHeight > availableHeight
    }

    /// Check if text will be truncated given the available width
    private func textWillTruncate(_ text: String, font: UIFont) -> Bool {
        // Calculate available width based on label shape, QR position and manufacturer image
        let padding: CGFloat = 4
        var availableWidth: CGFloat

        // Determine if this label uses vertical layout (top/bottom QR positioning)
        // Circular, portrait, and square labels all use vertical layout since text expands horizontally
        let usesVerticalLayout = format.isCircular || format.shape == .portrait || format.shape == .square

        if format.isCircular {
            // Circular labels: text is centered, use ~70% of diameter for content width
            // QR codes are at top/bottom and don't reduce horizontal space
            availableWidth = format.labelWidth * 0.7 - (padding * 2)
        } else if usesVerticalLayout {
            // Portrait labels: QR codes are at top/bottom and don't reduce horizontal space
            availableWidth = format.labelWidth - (padding * 2)
        } else {
            // Landscape and square labels: full width minus padding
            availableWidth = format.labelWidth - (padding * 2)

            // Account for QR code space (left/right positioning)
            if config.qrPosition != .none {
                let qrSize = effectiveQRSize

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

        if format.isCircular {
            return "\(widthFraction)\" diameter"
        }
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
        format: .defaultFormat,
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

#Preview("QR Focused") {
    LabelPreviewView(
        format: .defaultFormat,
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

#Preview("Dual QR") {
    LabelPreviewView(
        format: .defaultFormat,
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

#Preview("Location Based") {
    LabelPreviewView(
        format: .defaultFormat,
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

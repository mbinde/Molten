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

    /// Effective QR size (preset override or format default)
    private var effectiveQRSize: CGFloat {
        return config.qrSize ?? format.defaultQRSize
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

            // Label preview with border (circular, barbell, or rectangular)
            ZStack {
                if format.isCircular {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        .background(
                            Circle()
                                .fill(Color.white)
                        )
                } else if format.isBarbell {
                    // Barbell/flag shape: varies by style
                    barbellShapeView()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        .background(barbellShapeView().fill(Color.white))
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white)
                        )
                }

                // Label content based on QR position
                if format.isBarbell {
                    // For barbell labels, show content in the left flag area only
                    buildBarbellContent()
                } else {
                    buildLabelContent()
                        .frame(width: format.isCircular ? previewWidth * 0.7 : nil, height: previewHeight - 8)
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
        HStack(spacing: 0) {
            // Left flag area - text content
            VStack(alignment: .center, spacing: 1) {
                Spacer()
                buildTextContent()
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
                    let qrSize = min(barbellFlagWidthScaled, previewHeight) * 0.85
                    QRCodeView(labelData: sampleData, service: service)
                        .frame(width: qrSize, height: qrSize)
                } else {
                    // Mirror text content on right flag
                    buildTextContent()
                        .padding(.horizontal, 2)
                }
                Spacer()
            }
            .frame(width: barbellFlagWidthScaled, height: previewHeight)
        }
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
        // For p-style-folded: print area is ~44% of width (37mm/84mm), stub is ~56%
        // Use format.barbellFlagWidth if set, otherwise calculate from proportions
        let printAreaWidth = format.barbellFlagWidth.map { $0 * scaleFactor } ?? (previewWidth * 0.44)
        let halfFlagHeight = previewHeight / 2
        let stubWidth = previewWidth - printAreaWidth
        let stubHeight = barbellWrapHeightScaled  // Stub is narrower than full height
        let stubY = (previewHeight - stubHeight) / 2  // Centered vertically

        HStack(spacing: 0) {
            // Main printable area with two zones (LEFT side)
            ZStack {
                VStack(spacing: 0) {
                    // Print Area A (top half) - bordered
                    ZStack {
                        Rectangle()
                            .stroke(Color.gray.opacity(0.6), lineWidth: 1.5)

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
                    .frame(height: halfFlagHeight)

                    // Print Area B (bottom half) - bordered, content rotated 180°
                    ZStack {
                        Rectangle()
                            .stroke(Color.gray.opacity(0.6), lineWidth: 1.5)

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
                    .frame(height: halfFlagHeight)
                }

                // Dashed fold line between areas
                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundColor(Color.gray.opacity(0.6))
                    .frame(height: 1)
            }
            .frame(width: printAreaWidth, height: previewHeight)

            // Stub/handle on right - centered vertically (P-style), with stripes
            VStack {
                Spacer()
                    .frame(height: stubY)
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.08))
                        .overlay(
                            DiagonalStripePattern()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )

                    Rectangle()
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                }
                .frame(width: stubWidth, height: stubHeight)
                Spacer()
                    .frame(height: stubY)
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

// MARK: - Barbell/Cable Label Shapes

/// Shape for symmetric barbell/flag labels (two rectangles connected by narrow strip)
/// Used for standard cable labels like Avery 94749
struct BarbellShape: Shape {
    let flagWidth: CGFloat
    let wrapHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Calculate dimensions
        let totalWidth = rect.width
        let totalHeight = rect.height
        let wrapWidth = totalWidth - (2 * flagWidth)
        let wrapY = (totalHeight - wrapHeight) / 2

        // Left flag (full height rectangle on left)
        path.addRect(CGRect(x: 0, y: 0, width: flagWidth, height: totalHeight))

        // Narrow wrap section in middle
        path.addRect(CGRect(x: flagWidth, y: wrapY, width: wrapWidth, height: wrapHeight))

        // Right flag (full height rectangle on right)
        path.addRect(CGRect(x: totalWidth - flagWidth, y: 0, width: flagWidth, height: totalHeight))

        return path
    }
}

/// Shape for T-style cable labels (single flag with narrow tail)
/// Like Avery 61539 - one printable flag area, with narrow wrap extending from one end
struct TStyleShape: Shape {
    let flagWidth: CGFloat
    let wrapHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let totalWidth = rect.width
        let totalHeight = rect.height
        let wrapWidth = totalWidth - flagWidth
        let wrapY = (totalHeight - wrapHeight) / 2

        // Flag area on left (full height)
        path.addRect(CGRect(x: 0, y: 0, width: flagWidth, height: totalHeight))

        // Narrow wrap tail extending to the right
        path.addRect(CGRect(x: flagWidth, y: wrapY, width: wrapWidth, height: wrapHeight))

        return path
    }
}

/// Shape for P-style cable labels (flag with curved loop tail)
/// Like Avery 61540 - one printable flag with a curved/tapered tail for wrapping
struct PStyleShape: Shape {
    let flagWidth: CGFloat
    let wrapHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let totalWidth = rect.width
        let totalHeight = rect.height
        let wrapY = (totalHeight - wrapHeight) / 2

        // Flag area on left (full height)
        path.addRect(CGRect(x: 0, y: 0, width: flagWidth, height: totalHeight))

        // Curved wrap section - tapers from flag to a narrower tail
        // Create a trapezoid shape that narrows toward the right
        let startY = wrapY
        let endY = wrapY + wrapHeight
        let taperAmount = wrapHeight * 0.3  // Taper by 30%

        path.move(to: CGPoint(x: flagWidth, y: startY))
        path.addLine(to: CGPoint(x: totalWidth, y: startY + taperAmount))
        path.addLine(to: CGPoint(x: totalWidth, y: endY - taperAmount))
        path.addLine(to: CGPoint(x: flagWidth, y: endY))
        path.closeSubpath()

        return path
    }
}

/// Shape for P-style folded cable labels (flag with wrap stub on right)
/// Like Mr-Label - shows flag split horizontally with wrap tail indicator
struct PStyleFoldedShape: Shape {
    let flagWidth: CGFloat
    let wrapHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let totalHeight = rect.height
        let wrapY = (totalHeight - wrapHeight) / 2

        // Flag area on left (full height) - takes most of the space
        path.addRect(CGRect(x: 0, y: 0, width: flagWidth, height: totalHeight))

        // Wrap stub on right - visible tail showing where it attaches
        let stubLength = flagWidth * 0.5  // Longer stub for clarity
        let taperAmount = wrapHeight * 0.15

        path.move(to: CGPoint(x: flagWidth, y: wrapY))
        path.addLine(to: CGPoint(x: flagWidth + stubLength, y: wrapY + taperAmount))
        path.addLine(to: CGPoint(x: flagWidth + stubLength, y: wrapY + wrapHeight - taperAmount))
        path.addLine(to: CGPoint(x: flagWidth, y: wrapY + wrapHeight))
        path.closeSubpath()

        return path
    }
}

/// Shape for just the wrap stub portion (for overlay effects)
struct PStyleFoldedStubShape: Shape {
    let flagWidth: CGFloat
    let wrapHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let totalHeight = rect.height
        let wrapY = (totalHeight - wrapHeight) / 2
        let stubLength = flagWidth * 0.5
        let taperAmount = wrapHeight * 0.15

        path.move(to: CGPoint(x: flagWidth, y: wrapY))
        path.addLine(to: CGPoint(x: flagWidth + stubLength, y: wrapY + taperAmount))
        path.addLine(to: CGPoint(x: flagWidth + stubLength, y: wrapY + wrapHeight - taperAmount))
        path.addLine(to: CGPoint(x: flagWidth, y: wrapY + wrapHeight))
        path.closeSubpath()

        return path
    }
}

/// Shape for self-laminating wrap labels (simple strip, no flags)
/// The entire label wraps around the cable with a clear overlay
struct WrapShape: Shape {
    let wrapHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let totalWidth = rect.width
        let totalHeight = rect.height
        let wrapY = (totalHeight - wrapHeight) / 2

        // Simple strip across the full width at the wrap height
        path.addRect(CGRect(x: 0, y: wrapY, width: totalWidth, height: wrapHeight))

        return path
    }
}
#endif

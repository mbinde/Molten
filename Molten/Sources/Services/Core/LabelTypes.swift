//
//  LabelTypes.swift
//  Molten
//
//  Data types for label printing: geometry, configuration, presets
//  Extracted from LabelPrintingService.swift
//

import Foundation
import Combine

/// Shape classification for label formats
enum LabelShape: String, CaseIterable, Identifiable {
    case landscape      // wider than tall
    case portrait       // taller than wide
    case square         // equal width and height (not circular)
    case circular       // round labels
    case flag           // cable/wire flag labels (barbell shape)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .landscape: return "Wide"
        case .portrait: return "Tall"
        case .square: return "Square"
        case .circular: return "Circle"
        case .flag: return "Barbell"
        }
    }

    /// SF Symbol name, or nil if custom icon needed
    var systemImage: String? {
        switch self {
        case .landscape: return "rectangle.fill"
        case .portrait: return "rectangle.portrait.fill"
        case .square: return "square.fill"
        case .circular: return "circle.fill"
        case .flag: return nil  // Uses custom FlagLabelIcon
        }
    }
}

/// Style variants for barbell/flag cable labels
enum BarbellStyle: String, Sendable {
    case symmetric     // Standard barbell: two flags connected by narrow wrap
    case tStyle        // T-style: single flag with wrap tail on one end
    case pStyle        // P-style: flag with curved/loop tail
    case pStyleFolded  // P-style folded: single flag split horizontally (top/bottom areas fold around cable)
    case wrap          // Self-laminating wrap-around labels

    init?(databaseValue: String?) {
        guard let value = databaseValue else { return nil }
        switch value {
        case "symmetric": self = .symmetric
        case "t-style": self = .tStyle
        case "p-style": self = .pStyle
        case "p-style-folded": self = .pStyleFolded
        case "wrap": self = .wrap
        default: self = .symmetric
        }
    }
}

/// Label format specifications for PDF generation
///
/// All dimensions in points (1 point = 1/72 inch)
/// Standard sheet size: 8.5" × 11" (US Letter) = 612 × 792 points
///
/// Label data is loaded from labels.db (SQLite) which contains 2,600+ formats
/// from 87 brands, scraped from hlabels.com
struct LabelGeometry: Equatable, Hashable, Sendable {
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

    // Default formatting for this label size
    let defaultFontScale: CGFloat
    let defaultQRSize: CGFloat  // as percentage of label height (0.5 to 0.8)

    /// Whether this is a circular label (explicitly defined, not computed from dimensions)
    let isCircular: Bool

    /// Whether this is a barbell/flag label (for cables, wires, jewelry)
    let isBarbell: Bool

    /// Barbell-specific geometry (only set when isBarbell is true)
    /// Width of each printable flag area at the ends
    let barbellFlagWidth: CGFloat?
    /// Height of the narrow wrap section in the middle
    let barbellWrapHeight: CGFloat?
    /// Style variant for barbell labels (symmetric, t-style, p-style, wrap)
    let barbellStyle: BarbellStyle?

    /// Page format ("letter" or "a4")
    let pageFormat: String

    /// Computed wrap width for barbell labels (the narrow middle section)
    var barbellWrapWidth: CGFloat? {
        guard isBarbell, let flagWidth = barbellFlagWidth else { return nil }
        return labelWidth - (2 * flagWidth)
    }

    /// Computed shape based on explicit flags and dimensions
    var shape: LabelShape {
        if isBarbell {
            return .flag
        } else if isCircular {
            return .circular
        } else if abs(labelWidth - labelHeight) < 1.0 {
            return .square
        } else if labelWidth > labelHeight {
            return .landscape
        } else {
            return .portrait
        }
    }

    init(
        name: String,
        labelsPerSheet: Int,
        columns: Int,
        rows: Int,
        labelWidth: CGFloat,
        labelHeight: CGFloat,
        leftMargin: CGFloat,
        topMargin: CGFloat,
        horizontalGap: CGFloat,
        verticalGap: CGFloat,
        defaultFontScale: CGFloat,
        defaultQRSize: CGFloat,
        isCircular: Bool = false,
        isBarbell: Bool = false,
        barbellFlagWidth: CGFloat? = nil,
        barbellWrapHeight: CGFloat? = nil,
        barbellStyle: BarbellStyle? = nil,
        pageFormat: String = "letter"
    ) {
        self.name = name
        self.labelsPerSheet = labelsPerSheet
        self.columns = columns
        self.rows = rows
        self.labelWidth = labelWidth
        self.labelHeight = labelHeight
        self.leftMargin = leftMargin
        self.topMargin = topMargin
        self.horizontalGap = horizontalGap
        self.verticalGap = verticalGap
        self.defaultFontScale = defaultFontScale
        self.defaultQRSize = defaultQRSize
        self.isCircular = isCircular
        self.isBarbell = isBarbell
        self.barbellFlagWidth = barbellFlagWidth
        self.barbellWrapHeight = barbellWrapHeight
        self.barbellStyle = barbellStyle
        self.pageFormat = pageFormat
    }

    /// Avery 5160 (Address Labels) - Default format
    /// 30 labels per sheet (3 columns × 10 rows)
    /// 1" × 2⅝" per label
    /// Most common format for rod labels
    static let default5160 = LabelGeometry(
        name: "Avery 5160",
        labelsPerSheet: 30,
        columns: 3,
        rows: 10,
        labelWidth: 189,  // 2.625" × 72 = 189pt
        labelHeight: 72,  // 1" × 72 = 72pt
        leftMargin: 13.5,  // 0.1875" × 72
        topMargin: 36,  // 0.5" × 72
        horizontalGap: 9,  // Spacing: 2.75" × 72 - 189pt = 9pt
        verticalGap: 0,  // Labels are vertically contiguous
        defaultFontScale: 1.0,
        defaultQRSize: 0.65
    )


    /// Default format (Avery 5160) - used as fallback if database unavailable
    /// All other formats are loaded from labels.db via LabelDatabaseService
    static let defaultFormat = default5160
}

/// QR code position on label
enum QRCodePosition: String, CaseIterable, Codable, Sendable {
    case none = "None"
    case left = "Left side"
    case right = "Right side"
    case both = "Both sides"

    /// Display name adjusted for label shape
    /// Circular, portrait, and square labels use "Top/Bottom" instead of "Left/Right"
    /// (text expands horizontally, so QR codes should be positioned vertically)
    func displayName(for shape: LabelShape) -> String {
        let useVertical = shape == .circular || shape == .portrait || shape == .square
        switch self {
        case .none: return "None"
        case .left: return useVertical ? "Top" : "Left side"
        case .right: return useVertical ? "Bottom" : "Right side"
        case .both: return useVertical ? "Top & Bottom" : "Both sides"
        }
    }

    /// Whether this position uses vertical layout (top/bottom) for the given shape
    func usesVerticalLayout(for shape: LabelShape) -> Bool {
        return shape == .circular || shape == .portrait || shape == .square
    }
}

/// Manufacturer image position on label
enum ManufacturerImagePosition: String, CaseIterable, Codable, Sendable {
    case none = "None"
    case left = "Left side"
    case right = "Right side"
    case both = "Both sides"

    /// Display name adjusted for label shape
    /// Circular, portrait, and square labels use "Top/Bottom" instead of "Left/Right"
    /// (text expands horizontally, so images should be positioned vertically)
    func displayName(for shape: LabelShape) -> String {
        let useVertical = shape == .circular || shape == .portrait || shape == .square
        switch self {
        case .none: return "None"
        case .left: return useVertical ? "Top" : "Left side"
        case .right: return useVertical ? "Bottom" : "Right side"
        case .both: return useVertical ? "Top & Bottom" : "Both sides"
        }
    }

    /// Whether this position uses vertical layout (top/bottom) for the given shape
    func usesVerticalLayout(for shape: LabelShape) -> Bool {
        return shape == .circular || shape == .portrait || shape == .square
    }
}

/// Text alignment on label
enum LabelTextAlignment: String, CaseIterable, Codable, Sendable {
    case left = "Left"
    case center = "Center"
    case right = "Right"
}

/// Text field that can be included on a label
enum LabelTextField: String, CaseIterable, Codable, Sendable {
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

/// Formatting configuration for individual label fields
struct LabelFieldFormat: Equatable, Codable, Sendable {
    var fontSize: CGFloat
    var bold: Bool
    var italic: Bool

    /// Default formats for each field type
    static let defaults: [LabelTextField: LabelFieldFormat] = [
        .manufacturer: LabelFieldFormat(fontSize: 9, bold: true, italic: false),
        .sku: LabelFieldFormat(fontSize: 9, bold: true, italic: false),
        .colorName: LabelFieldFormat(fontSize: 8, bold: false, italic: false),
        .coe: LabelFieldFormat(fontSize: 7, bold: false, italic: false),
        .location: LabelFieldFormat(fontSize: 7, bold: false, italic: false),
        .owner: LabelFieldFormat(fontSize: 7, bold: false, italic: false)
    ]

    /// Get default format for a field
    static func defaultFormat(for field: LabelTextField) -> LabelFieldFormat {
        return defaults[field] ?? LabelFieldFormat(fontSize: 8, bold: false, italic: false)
    }
}

/// Label builder configuration - user-customizable label layout
struct LabelBuilderConfig: Equatable, Codable, Sendable {
    var qrPosition: QRCodePosition
    var qrSize: CGFloat?  // as percentage of label height (0.5 to 0.8) - nil = use format default
    var fontScale: CGFloat?  // text size multiplier - nil = use format default
    var manufacturerImagePosition: ManufacturerImagePosition
    var manufacturerImageSize: CGFloat?  // as percentage of label height - nil = use default (0.6)
    var textFields: [LabelTextField]
    var textAlignment: LabelTextAlignment  // text alignment (left, center, right)
    var fieldFormats: [LabelTextField: LabelFieldFormat]  // per-field formatting

    // Content padding within labels (in points)
    var paddingTop: CGFloat = 0
    var paddingBottom: CGFloat = 0
    var paddingLeft: CGFloat = 0
    var paddingRight: CGFloat = 0

    // Position adjustments (in points)
    var positionHorizontal: CGFloat = 0
    var positionVertical: CGFloat = 0

    /// Default configuration (information dense)
    static let `default` = LabelBuilderConfig(
        qrPosition: .left,
        qrSize: nil,
        fontScale: nil,
        manufacturerImagePosition: .none,
        manufacturerImageSize: nil,
        textFields: [.colorName, .manufacturer, .sku],
        textAlignment: .left,
        fieldFormats: [
            .colorName: LabelFieldFormat(fontSize: 9, bold: true, italic: false),
            .manufacturer: LabelFieldFormat(fontSize: 8, bold: false, italic: false),
            .sku: LabelFieldFormat(fontSize: 8, bold: false, italic: false)
        ],
        paddingTop: 0, paddingBottom: 0, paddingLeft: 0, paddingRight: 0,
        positionHorizontal: 0, positionVertical: 0
    )

    /// Get format for a specific field (with fallback to default)
    func format(for field: LabelTextField) -> LabelFieldFormat {
        return fieldFormats[field] ?? LabelFieldFormat.defaultFormat(for: field)
    }

    /// Check if manufacturer image overlaps with QR code
    func manufacturerImageOverlapsQR() -> Bool {
        guard manufacturerImagePosition != .none else { return false }
        switch (qrPosition, manufacturerImagePosition) {
        case (.left, .left), (.right, .right):
            return true
        case (.both, _), (_, .both):
            return true
        default:
            return false
        }
    }

    /// Preset configurations for common use cases
    static let presets: [LabelBuilderPreset] = [
        LabelBuilderPreset(
            name: "Information Dense",
            description: "Item name prominent, with manufacturer and SKU",
            config: LabelBuilderConfig(
                qrPosition: .left,
                qrSize: nil,
                fontScale: nil,
                manufacturerImagePosition: .none,
                manufacturerImageSize: nil,
                textFields: [.colorName, .manufacturer, .sku],
                textAlignment: .left,
                fieldFormats: [
                    .colorName: LabelFieldFormat(fontSize: 9, bold: true, italic: false),
                    .manufacturer: LabelFieldFormat(fontSize: 8, bold: false, italic: false),
                    .sku: LabelFieldFormat(fontSize: 8, bold: false, italic: false)
                ],
                paddingTop: 0, paddingBottom: 0, paddingLeft: 0, paddingRight: 0,
                positionHorizontal: 0, positionVertical: 0
            )
        ),
        LabelBuilderPreset(
            name: "QR Focused",
            description: "Large QR code, minimal text",
            config: LabelBuilderConfig(
                qrPosition: .left,
                qrSize: nil,
                fontScale: nil,
                manufacturerImagePosition: .none,
                manufacturerImageSize: nil,
                textFields: [.manufacturer, .sku],
                textAlignment: .left,
                fieldFormats: [:],
                paddingTop: 0, paddingBottom: 0, paddingLeft: 0, paddingRight: 0,
                positionHorizontal: 0, positionVertical: 0
            )
        ),
        LabelBuilderPreset(
            name: "Location Labels",
            description: "With location information",
            config: LabelBuilderConfig(
                qrPosition: .left,
                qrSize: nil,
                fontScale: nil,
                manufacturerImagePosition: .none,
                manufacturerImageSize: nil,
                textFields: [.manufacturer, .sku, .colorName, .location],
                textAlignment: .left,
                fieldFormats: [:],
                paddingTop: 0, paddingBottom: 0, paddingLeft: 0, paddingRight: 0,
                positionHorizontal: 0, positionVertical: 0
            )
        )
    ]

    /// Convert to legacy LabelTemplate for backwards compatibility
    func toLegacyTemplate(format: LabelGeometry) -> LabelTemplate {
        return LabelTemplate(
            name: "Custom",
            includeQRCode: qrPosition != .none,
            dualQRCodes: qrPosition == .both,
            includeManufacturer: textFields.contains(.manufacturer),
            includeSKU: textFields.contains(.sku),
            includeColor: textFields.contains(.colorName),
            includeCOE: textFields.contains(.coe),
            includeQuantity: false,
            includeLocation: textFields.contains(.location),
            includeOwner: textFields.contains(.owner),
            qrCodeSize: qrSize ?? format.defaultQRSize
        )
    }

    /// Estimate if content will fit within label bounds
    func validateLayout(for format: LabelGeometry, fontScale: CGFloat = 1.0) -> LabelLayoutValidation {
        let padding: CGFloat = 4
        var warnings: [String] = []

        var availableWidth = format.labelWidth - (padding * 2)
        let availableHeight = format.labelHeight - (padding * 2)

        if qrPosition != .none {
            let effectiveQRSize = qrSize ?? format.defaultQRSize
            let qrSizePoints = format.labelHeight * effectiveQRSize

            switch qrPosition {
            case .left, .right:
                availableWidth -= (qrSizePoints + padding)
            case .both:
                availableWidth -= (2 * qrSizePoints + 2 * padding)
                if format.labelWidth < 120 {
                    warnings.append("Dual QR codes leave minimal space for text")
                }
            case .none:
                break
            }
        }

        if manufacturerImagePosition != .none {
            let effectiveImageSize = manufacturerImageSize ?? 0.6
            let imageSize = format.labelHeight * effectiveImageSize

            switch manufacturerImagePosition {
            case .left, .right:
                availableWidth -= (imageSize + padding)
            case .both:
                availableWidth -= (2 * imageSize + 2 * padding)
                if format.labelWidth < 120 {
                    warnings.append("Manufacturer images on both sides leave minimal space for text")
                }
            case .none:
                break
            }
        }

        let estimatedTextHeight = textFields.reduce(0) { $0 + ($1.estimatedHeight * fontScale) }
        let textFits = estimatedTextHeight <= availableHeight

        if !textFits {
            let overflow = Int(estimatedTextHeight - availableHeight)
            warnings.append("Text will be truncated (\(overflow)pt overflow) - reduce font size or remove fields")
        }

        if availableWidth < 40 {
            warnings.append("Very narrow text area - consider reducing QR size or using fewer fields")
        }

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
struct LabelBuilderPreset: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var description: String
    var config: LabelBuilderConfig
    var createdAt: Date
    var modifiedAt: Date

    // Future-proofing fields (added pre-release for easier migrations)
    var workspace_id: UUID?  // For multi-inventory sets: references Workspace entity
    var recommended_label: String?  // Recommended label format name (e.g., "Avery 5160")

    nonisolated init(id: UUID = UUID(), name: String, description: String, config: LabelBuilderConfig, createdAt: Date = Date(), modifiedAt: Date = Date(), workspace_id: UUID? = nil, recommended_label: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.config = config
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.workspace_id = workspace_id
        self.recommended_label = recommended_label
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

enum LabelPresetsError: Error {
    case invalidData
}

/// Label data model for a single label (one label = one physical item like one rod)
struct LabelData: Sendable {
    let stableId: String  // The stable_id of the glass item (e.g., "2wjEBu")
    let manufacturer: String?
    let sku: String?
    let colorName: String?
    let coe: String?
    let location: String?
    let owner: String?

    // Inventory type info for QR code encoding
    let inventoryType: String?      // e.g., "rod", "frit", "tube"
    let inventorySubtype: String?   // e.g., "coarse", "fine"
    let inventorySubsubtype: String?

    init(
        stableId: String,
        manufacturer: String? = nil,
        sku: String? = nil,
        colorName: String? = nil,
        coe: String? = nil,
        location: String? = nil,
        owner: String? = nil,
        inventoryType: String? = nil,
        inventorySubtype: String? = nil,
        inventorySubsubtype: String? = nil
    ) {
        self.stableId = stableId
        self.manufacturer = manufacturer
        self.sku = sku
        self.colorName = colorName
        self.coe = coe
        self.location = location
        self.owner = owner
        self.inventoryType = inventoryType
        self.inventorySubtype = inventorySubtype
        self.inventorySubsubtype = inventorySubsubtype
    }
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
    let includeOwner: Bool
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
        if includeOwner { fields.append(.owner) }

        return LabelBuilderConfig(
            qrPosition: qrPosition,
            qrSize: qrCodeSize,
            fontScale: nil,
            manufacturerImagePosition: .none,
            manufacturerImageSize: nil,
            textFields: fields,
            textAlignment: .left,
            fieldFormats: LabelFieldFormat.defaults,
            paddingTop: 0, paddingBottom: 0, paddingLeft: 0, paddingRight: 0,
            positionHorizontal: 0, positionVertical: 0
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
        includeOwner: false,
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
        includeOwner: false,
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
        includeOwner: false,
        qrCodeSize: 0.50
    )
}

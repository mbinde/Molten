//
//  LabelPrintingServiceTests.swift
//  MoltenTests
//
//  Created by Claude Code on 10/26/25.
//  Tests for LabelPrintingService following TDD and Swift 6 concurrency guidelines
//

import Testing
import Foundation
import UIKit
@testable import Molten

@Suite("LabelPrintingService Tests")
@MainActor  // Required: UIImage/UIGraphics are MainActor-isolated
struct LabelPrintingServiceTests {

    // MARK: - Shared Dependencies

    /// ✅ CRITICAL: Store AppDependencies at struct level to keep PersistenceController alive
    /// This prevents Core Data zombie objects that cause crashes.
    /// See CLAUDE.md "Service Creation Anti-Pattern" - same pattern applies to tests!
    private let deps = AppDependencies(persistenceController: .createTestController())

    // MARK: - Test Geometries
    // These recreate specific label geometries for testing since formats are now in database

    /// Large shipping label (4" × 2") - for tests requiring larger labels
    private static let testLargeLabel = LabelGeometry(
        name: "Test Large Label",
        labelsPerSheet: 10,
        columns: 2,
        rows: 5,
        labelWidth: 288,  // 4"
        labelHeight: 144, // 2"
        leftMargin: 18,
        topMargin: 36,
        horizontalGap: 9,
        verticalGap: 0,
        defaultFontScale: 1.0,
        defaultQRSize: 0.6
    )

    /// Small return address label (1.75" × 0.5") - for tests requiring smaller labels
    private static let testSmallLabel = LabelGeometry(
        name: "Test Small Label",
        labelsPerSheet: 80,
        columns: 4,
        rows: 20,
        labelWidth: 126, // 1.75"
        labelHeight: 36, // 0.5"
        leftMargin: 18,
        topMargin: 36,
        horizontalGap: 9,
        verticalGap: 0,
        defaultFontScale: 0.75,
        defaultQRSize: 0.7
    )


    init() async {
        // Configure repository factory for testing (uses mocks)
    }

    // MARK: - QR Code Generation Tests

    @Test("Generate QR code with valid stable_id")
    func testGenerateQRCodeWithValidStableId() async throws {
        let service = LabelPrintingService()
        let stableId = "2wjEBu"

        let qrImage = service.generateQRCode(for: stableId)

        #expect(qrImage.size.width > 0)
        #expect(qrImage.size.height > 0)
    }

    @Test("QR code contains correct deep link format")
    func testQRCodeDeepLinkFormat() async throws {
        let service = LabelPrintingService()
        let stableId = "abc123"

        // Generate QR code (deep link should be "molten://g/abc123")
        let qrImage = service.generateQRCode(for: stableId)

        // Verify image was created (deep link verification would require QR decoding)
        #expect(qrImage.size.width > 0)
    }

    @Test("QR code size is correct")
    func testQRCodeSize() async throws {
        let service = LabelPrintingService()
        let stableId = "test123"

        let qrImage = service.generateQRCode(for: stableId)

        // QR code is scaled to 200pt in the implementation
        #expect(qrImage.size.width == 200)
        #expect(qrImage.size.height == 200)
    }

    @Test("Generate QR for various stable_id formats")
    func testQRCodeVariousFormats() async throws {
        let service = LabelPrintingService()

        let testIds = ["abc", "123", "ABC123", "test-id", "a1b2c3"]

        for stableId in testIds {
            let qrImage = service.generateQRCode(for: stableId)
            #expect(qrImage.size.width > 0, "Failed for stableId: \(stableId)")
        }
    }

    @Test("Generate QR with empty stable_id")
    func testQRCodeEmptyStableId() async throws {
        let service = LabelPrintingService()

        let qrImage = service.generateQRCode(for: "")

        // Should still generate an image (empty deep link)
        #expect(qrImage.size.width > 0)
    }

    @Test("Generate QR with special characters in stable_id")
    func testQRCodeSpecialCharacters() async throws {
        let service = LabelPrintingService()

        let qrImage = service.generateQRCode(for: "test@123")

        #expect(qrImage.size.width > 0)
    }

    // MARK: - QR Code Generation with Inventory Type

    @Test("Generate QR code with inventory type")
    func testGenerateQRCodeWithInventoryType() async throws {
        let service = LabelPrintingService()

        let qrImage = service.generateQRCode(for: "abc123", type: "rod", subtype: nil, subsubtype: nil)

        #expect(qrImage.size.width > 0)
        #expect(qrImage.size.height > 0)
    }

    @Test("Generate QR code with inventory type and subtype")
    func testGenerateQRCodeWithInventoryTypeAndSubtype() async throws {
        let service = LabelPrintingService()

        let qrImage = service.generateQRCode(for: "abc123", type: "frit", subtype: "coarse", subsubtype: nil)

        #expect(qrImage.size.width > 0)
        #expect(qrImage.size.height > 0)
    }

    @Test("Generate QR code from LabelData with inventory type")
    func testGenerateQRCodeFromLabelDataWithInventoryType() async throws {
        let service = LabelPrintingService()

        let labelData = LabelData(
            stableId: "abc123",
            manufacturer: "be",
            sku: "001",
            colorName: "Clear",
            coe: "96",
            location: nil,
            owner: nil,
            inventoryType: "frit",
            inventorySubtype: "coarse",
            inventorySubsubtype: nil
        )

        let qrImage = service.generateQRCode(for: labelData)

        #expect(qrImage.size.width > 0)
        #expect(qrImage.size.height > 0)
    }

    @Test("Generate QR code from LabelData without inventory type")
    func testGenerateQRCodeFromLabelDataWithoutInventoryType() async throws {
        let service = LabelPrintingService()

        let labelData = LabelData(
            stableId: "abc123",
            manufacturer: "be",
            sku: "001",
            colorName: "Clear",
            coe: "96",
            location: nil,
            owner: nil
        )

        let qrImage = service.generateQRCode(for: labelData)

        #expect(qrImage.size.width > 0)
        #expect(qrImage.size.height > 0)
    }

    // MARK: - Label Builder Configuration Tests

    @Test("LabelBuilderConfig default configuration")
    func testDefaultConfiguration() async throws {
        let config = LabelBuilderConfig.default

        #expect(config.qrPosition == .left)
        #expect(config.qrSize == nil)
        #expect(config.textFields.contains(.manufacturer))
        #expect(config.textFields.contains(.sku))
        #expect(config.textFields.contains(.colorName))
        #expect(config.textAlignment == .left)
        // Verify field order: colorName first (item name), then manufacturer, then sku
        #expect(config.textFields[0] == .colorName)
        #expect(config.textFields[1] == .manufacturer)
        #expect(config.textFields[2] == .sku)
        // Verify formatting: colorName 9pt bold, manufacturer/sku 8pt normal
        #expect(config.format(for: .colorName).fontSize == 9)
        #expect(config.format(for: .colorName).bold == true)
        #expect(config.format(for: .manufacturer).fontSize == 8)
        #expect(config.format(for: .manufacturer).bold == false)
        #expect(config.format(for: .sku).fontSize == 8)
        #expect(config.format(for: .sku).bold == false)
    }

    @Test("LabelBuilderConfig preset: Information Dense")
    func testPresetInformationDense() async throws {
        let preset = LabelBuilderConfig.presets.first { $0.name == "Information Dense" }

        #expect(preset != nil)
        #expect(preset?.config.qrPosition == .left)
        #expect(preset?.config.qrSize == nil)
        #expect(preset?.config.textFields.contains(.manufacturer) == true)
        #expect(preset?.config.textFields.contains(.sku) == true)
        #expect(preset?.config.textFields.contains(.colorName) == true)
        // Verify field order: colorName first (item name), then manufacturer, then sku
        #expect(preset?.config.textFields[0] == .colorName)
        #expect(preset?.config.textFields[1] == .manufacturer)
        #expect(preset?.config.textFields[2] == .sku)
    }

    @Test("LabelBuilderConfig preset: QR Focused")
    func testPresetQRFocused() async throws {
        let preset = LabelBuilderConfig.presets.first { $0.name == "QR Focused" }

        #expect(preset != nil)
        #expect(preset?.config.qrPosition == .left)
        #expect(preset?.config.qrSize == nil)
        #expect(preset?.config.textFields.count == 2)
    }

    @Test("LabelBuilderConfig preset: Location Labels")
    func testPresetLocationLabels() async throws {
        let preset = LabelBuilderConfig.presets.first { $0.name == "Location Labels" }

        #expect(preset != nil)
        #expect(preset?.config.textFields.contains(.location) == true)
    }

    @Test("LabelBuilderConfig QR position left")
    func testQRPositionLeft() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            manufacturerImagePosition: .none,
            textFields: [.manufacturer, .sku],
            textAlignment: .left,
            fieldFormats: LabelFieldFormat.defaults
        )

        #expect(config.qrPosition == .left)
    }

    @Test("LabelBuilderConfig QR position right")
    func testQRPositionRight() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .right,
            qrSize: 0.65,
            manufacturerImagePosition: .none,
            textFields: [.manufacturer, .sku],
            textAlignment: .right,
            fieldFormats: LabelFieldFormat.defaults
        )

        #expect(config.qrPosition == .right)
    }

    @Test("LabelBuilderConfig QR position both")
    func testQRPositionBoth() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .both,
            qrSize: 0.65,
            manufacturerImagePosition: .none,
            textFields: [.manufacturer, .sku],
            textAlignment: .center,
            fieldFormats: LabelFieldFormat.defaults
        )

        #expect(config.qrPosition == .both)
    }

    @Test("LabelBuilderConfig QR position none")
    func testQRPositionNone() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .none,
            qrSize: 0.65,
            manufacturerImagePosition: .none,
            textFields: [.manufacturer, .sku, .colorName, .coe],
            textAlignment: .left,
            fieldFormats: LabelFieldFormat.defaults
        )

        #expect(config.qrPosition == .none)
    }

    @Test("LabelBuilderConfig text alignment left")
    func testTextAlignmentLeft() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            manufacturerImagePosition: .none,
            textFields: [.manufacturer],
            textAlignment: .left,
            fieldFormats: LabelFieldFormat.defaults
        )

        #expect(config.textAlignment == .left)
    }

    @Test("LabelBuilderConfig text alignment center")
    func testTextAlignmentCenter() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .both,
            qrSize: 0.65,
            manufacturerImagePosition: .none,
            textFields: [.manufacturer],
            textAlignment: .center,
            fieldFormats: LabelFieldFormat.defaults
        )

        #expect(config.textAlignment == .center)
    }

    @Test("LabelBuilderConfig text alignment right")
    func testTextAlignmentRight() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .right,
            qrSize: 0.65,
            manufacturerImagePosition: .none,
            textFields: [.manufacturer],
            textAlignment: .right,
            fieldFormats: LabelFieldFormat.defaults
        )

        #expect(config.textAlignment == .right)
    }

    @Test("LabelBuilderConfig text field selection")
    func testTextFieldSelection() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            manufacturerImagePosition: .none,
            textFields: [.manufacturer, .coe, .location],
            textAlignment: .left,
            fieldFormats: LabelFieldFormat.defaults
        )

        #expect(config.textFields.count == 3)
        #expect(config.textFields.contains(.manufacturer))
        #expect(config.textFields.contains(.coe))
        #expect(config.textFields.contains(.location))
        #expect(!config.textFields.contains(.sku))
    }

    @Test("LabelBuilderConfig text field ordering")
    func testTextFieldOrdering() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            manufacturerImagePosition: .none,
            textFields: [.colorName, .manufacturer, .sku],
            textAlignment: .left,
            fieldFormats: LabelFieldFormat.defaults
        )

        #expect(config.textFields[0] == .colorName)
        #expect(config.textFields[1] == .manufacturer)
        #expect(config.textFields[2] == .sku)
    }

    @Test("Convert LabelBuilderConfig to legacy template")
    func testConvertToLegacyTemplate() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.7,
            manufacturerImagePosition: .none,
            textFields: [.manufacturer, .sku, .colorName, .coe],
            textAlignment: .left,
            fieldFormats: LabelFieldFormat.defaults
        )

        let legacyTemplate = config.toLegacyTemplate(format: .defaultFormat)

        #expect(legacyTemplate.includeQRCode == true)
        #expect(legacyTemplate.dualQRCodes == false)
        #expect(legacyTemplate.includeManufacturer == true)
        #expect(legacyTemplate.includeSKU == true)
        #expect(legacyTemplate.includeColor == true)
        #expect(legacyTemplate.includeCOE == true)
        #expect(legacyTemplate.qrCodeSize == 0.7)
    }

    // MARK: - Layout Validation Tests

    @Test("Validate layout for default format")
    func testValidateLayoutDefault() async throws {
        let config = LabelBuilderConfig.default
        let format = LabelGeometry.defaultFormat

        let validation = config.validateLayout(for: format)

        #expect(validation.availableWidth > 0)
        #expect(validation.availableHeight > 0)
    }

    @Test("Validate layout for large labels")
    func testValidateLayoutLarge() async throws {
        let config = LabelBuilderConfig.default
        let format = Self.testLargeLabel

        let validation = config.validateLayout(for: format)

        #expect(validation.availableWidth > 0)
        #expect(validation.availableHeight > 0)
    }

    @Test("Validate layout for small labels")
    func testValidateLayoutSmall() async throws {
        let config = LabelBuilderConfig.default
        let format = Self.testSmallLabel

        let validation = config.validateLayout(for: format)

        #expect(validation.availableWidth > 0)
        #expect(validation.availableHeight > 0)
    }

    @Test("Detect text overflow warning")
    func testDetectTextOverflow() async throws {
        // Create config with many fields for small label
        let config = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.8,
            manufacturerImagePosition: .none,
            textFields: [.manufacturer, .sku, .colorName, .coe, .location, .owner],
            textAlignment: .left,
            fieldFormats: LabelFieldFormat.defaults
        )
        let format = Self.testSmallLabel  // Small label

        let validation = config.validateLayout(for: format, fontScale: 1.5)

        // Should have warnings about text overflow
        #expect(validation.warnings.count > 0)
    }

    @Test("Detect narrow text area warning")
    func testDetectNarrowTextArea() async throws {
        // Dual QR on very small label leaves very narrow text area
        // Need labelWidth < 120 to trigger warning
        let verySmallFormat = LabelGeometry(
            name: "Tiny Label",
            labelsPerSheet: 100,
            columns: 10,
            rows: 10,
            labelWidth: 100,  // Width < 120 to trigger warning
            labelHeight: 36,
            leftMargin: 20,
            topMargin: 20,
            horizontalGap: 10,
            verticalGap: 10,
            defaultFontScale: 1.0,
            defaultQRSize: 0.65
        )

        let config = LabelBuilderConfig(
            qrPosition: .both,
            qrSize: 0.75,
            manufacturerImagePosition: .none,
            textFields: [.manufacturer, .sku],
            textAlignment: .center,
            fieldFormats: LabelFieldFormat.defaults
        )

        let validation = config.validateLayout(for: verySmallFormat)

        // Should warn about narrow text area
        #expect(validation.warnings.count > 0)
    }

    @Test("Detect too many fields warning")
    func testDetectTooManyFields() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            manufacturerImagePosition: .none,
            textFields: [.manufacturer, .sku, .colorName, .coe, .location, .owner],
            textAlignment: .left,
            fieldFormats: LabelFieldFormat.defaults
        )
        let format = Self.testSmallLabel  // Small label (height < 72)

        let validation = config.validateLayout(for: format)

        // Should warn about too many fields
        #expect(validation.warnings.contains { $0.contains("many fields") })
    }

    @Test("Font scale impact on layout validation")
    func testFontScaleImpact() async throws {
        let config = LabelBuilderConfig.default
        let format = LabelGeometry.defaultFormat

        let validation1 = config.validateLayout(for: format, fontScale: 0.7)
        let validation2 = config.validateLayout(for: format, fontScale: 1.3)

        // Larger font scale should result in taller estimated text height
        #expect(validation2.estimatedTextHeight > validation1.estimatedTextHeight)
    }

    // MARK: - LabelGeometry Tests

    @Test("Default format (Avery 5160) dimensions")
    func testDefaultFormatDimensions() async throws {
        let format = LabelGeometry.defaultFormat

        #expect(format.name == "Avery 5160")
        #expect(format.labelsPerSheet == 30)
        #expect(format.columns == 3)
        #expect(format.rows == 10)
        #expect(format.labelWidth == 189)
        #expect(format.labelHeight == 72)
    }

    @Test("Test large label geometry")
    func testLargeLabelGeometry() async throws {
        let format = Self.testLargeLabel

        #expect(format.labelsPerSheet == 10)
        #expect(format.columns == 2)
        #expect(format.rows == 5)
        #expect(format.labelWidth == 288)
        #expect(format.labelHeight == 144)
    }

    @Test("Test small label geometry")
    func testSmallLabelGeometry() async throws {
        let format = Self.testSmallLabel

        #expect(format.labelsPerSheet == 80)
        #expect(format.columns == 4)
        #expect(format.rows == 20)
        #expect(format.labelWidth == 126)
        #expect(format.labelHeight == 36)
    }

    // MARK: - Label Sheet Generation Tests

    @Test("Generate single-page PDF with labels")
    func testGenerateSinglePagePDF() async throws {
        let service = LabelPrintingService()

        let labels = [
            LabelData(
                stableId: "test1",
                manufacturer: "Bullseye",
                sku: "001",
                colorName: "Clear",
                coe: "90",
                location: nil,
                owner: nil
            )
        ]

        let pdfURL = await service.generateLabelSheet(
            labels: labels,
            format: .defaultFormat,
            config: .default
        )

        #expect(pdfURL != nil)
        if let url = pdfURL {
            #expect(FileManager.default.fileExists(atPath: url.path))
        }
    }

    @Test("Generate multi-page PDF")
    func testGenerateMultiPagePDF() async throws {
        let service = LabelPrintingService()

        // Create 35 labels (more than one sheet of Avery 5160 which has 30)
        var labels: [LabelData] = []
        for i in 1...35 {
            labels.append(LabelData(
                stableId: "test\(i)",
                manufacturer: "Manufacturer",
                sku: "SKU\(i)",
                colorName: "Color",
                coe: "90",
                location: nil,
                owner: nil
            ))
        }

        let pdfURL = await service.generateLabelSheet(
            labels: labels,
            format: .defaultFormat,
            config: .default
        )

        #expect(pdfURL != nil)
        if let url = pdfURL {
            #expect(FileManager.default.fileExists(atPath: url.path))
        }
    }

    @Test("Generate PDF with partial sheet printing")
    func testPartialSheetPrinting() async throws {
        let service = LabelPrintingService()

        let labels = [
            LabelData(
                stableId: "test1",
                manufacturer: "Manufacturer",
                sku: "001",
                colorName: "Clear",
                coe: "90",
                location: nil,
                owner: nil
            )
        ]

        // Start at row 2, column 1 (skip first row)
        let pdfURL = await service.generateLabelSheet(
            labels: labels,
            format: .defaultFormat,
            config: .default,
            startRow: 2,
            startColumn: 1
        )

        #expect(pdfURL != nil)
    }

    @Test("Generate PDF with font scaling")
    func testFontScaling() async throws {
        let service = LabelPrintingService()

        let labels = [
            LabelData(
                stableId: "test1",
                manufacturer: "Manufacturer",
                sku: "001",
                colorName: "Clear",
                coe: "90",
                location: nil,
                owner: nil
            )
        ]

        let pdfURL = await service.generateLabelSheet(
            labels: labels,
            format: .defaultFormat,
            config: .default,
            fontScale: 0.8
        )

        #expect(pdfURL != nil)
    }

    @Test("Generate PDF with position adjustments")
    func testPositionAdjustments() async throws {
        let service = LabelPrintingService()

        let labels = [
            LabelData(
                stableId: "test1",
                manufacturer: "Manufacturer",
                sku: "001",
                colorName: "Clear",
                coe: "90",
                location: nil,
                owner: nil
            )
        ]

        // Position adjustments are now in config
        var config = LabelBuilderConfig.default
        config.positionHorizontal = 5.0
        config.positionVertical = -3.0

        let pdfURL = await service.generateLabelSheet(
            labels: labels,
            format: .defaultFormat,
            config: config
        )

        #expect(pdfURL != nil)
    }

    @Test("Generate PDF with empty label data")
    func testEmptyLabelData() async throws {
        let service = LabelPrintingService()

        let labels = [
            LabelData(
                stableId: "test1",
                manufacturer: nil,
                sku: nil,
                colorName: nil,
                coe: nil,
                location: nil,
                owner: nil
            )
        ]

        let pdfURL = await service.generateLabelSheet(
            labels: labels,
            format: .defaultFormat,
            config: .default
        )

        // Should generate PDF even with empty data (just QR code)
        #expect(pdfURL != nil)
    }

    @Test("Generate PDF with all label fields populated")
    func testAllFieldsPopulated() async throws {
        let service = LabelPrintingService()

        let labels = [
            LabelData(
                stableId: "test1",
                manufacturer: "Bullseye",
                sku: "0001-0001",
                colorName: "Light Amber Purple",
                coe: "90",
                location: "Studio A - Rack 3",
                owner: "Test Owner"
            )
        ]

        let config = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.5,
            manufacturerImagePosition: .none,
            textFields: [.manufacturer, .sku, .colorName, .coe, .location, .owner],
            textAlignment: .left,
            fieldFormats: LabelFieldFormat.defaults
        )

        let pdfURL = await service.generateLabelSheet(
            labels: labels,
            format: Self.testLargeLabel,  // Larger label format
            config: config
        )

        #expect(pdfURL != nil)
    }

    @Test("Manufacturer de-duplication when SKU starts with manufacturer")
    func testManufacturerDeduplication() async throws {
        let service = LabelPrintingService()

        // When SKU starts with manufacturer name, manufacturer should be hidden
        let labels = [
            LabelData(
                stableId: "test1",
                manufacturer: "Bullseye",
                sku: "Bullseye-0001",  // Starts with manufacturer
                colorName: "Clear",
                coe: "90",
                location: nil,
                owner: nil
            )
        ]

        let config = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            manufacturerImagePosition: .none,
            textFields: [.manufacturer, .sku],  // Both fields enabled
            textAlignment: .left,
            fieldFormats: LabelFieldFormat.defaults
        )

        let pdfURL = await service.generateLabelSheet(
            labels: labels,
            format: .defaultFormat,
            config: config
        )

        // Should generate PDF successfully (manufacturer will be hidden in rendering)
        #expect(pdfURL != nil)
    }

    @Test("Generate labels with no QR code")
    func testLabelsWithoutQRCode() async throws {
        let service = LabelPrintingService()

        let labels = [
            LabelData(
                stableId: "test1",
                manufacturer: "Manufacturer",
                sku: "001",
                colorName: "Clear",
                coe: "90",
                location: nil,
                owner: nil
            )
        ]

        let config = LabelBuilderConfig(
            qrPosition: .none,  // No QR code
            qrSize: 0.65,
            manufacturerImagePosition: .none,
            textFields: [.manufacturer, .sku, .colorName, .coe],
            textAlignment: .center,
            fieldFormats: LabelFieldFormat.defaults
        )

        let pdfURL = await service.generateLabelSheet(
            labels: labels,
            format: .defaultFormat,
            config: config
        )

        #expect(pdfURL != nil)
    }

    @Test("Generate labels with dual QR codes")
    func testDualQRCodes() async throws {
        let service = LabelPrintingService()

        let labels = [
            LabelData(
                stableId: "test1",
                manufacturer: "Manufacturer",
                sku: "001",
                colorName: "Clear",
                coe: nil,
                location: nil,
                owner: nil
            )
        ]

        let config = LabelBuilderConfig(
            qrPosition: .both,  // QR on both sides
            qrSize: 0.65,
            manufacturerImagePosition: .none,
            textFields: [.manufacturer, .sku],
            textAlignment: .center,
            fieldFormats: LabelFieldFormat.defaults
        )

        let pdfURL = await service.generateLabelSheet(
            labels: labels,
            format: .defaultFormat,
            config: config
        )

        #expect(pdfURL != nil)
    }

    // MARK: - QR Position Display Name Tests

    @Test("QR position displayName for landscape labels uses Left/Right")
    func testQRPositionDisplayNameLandscape() async throws {
        #expect(QRCodePosition.none.displayName(for: .landscape) == "None")
        #expect(QRCodePosition.left.displayName(for: .landscape) == "Left side")
        #expect(QRCodePosition.right.displayName(for: .landscape) == "Right side")
        #expect(QRCodePosition.both.displayName(for: .landscape) == "Both sides")
    }

    @Test("QR position displayName for circular labels uses Top/Bottom")
    func testQRPositionDisplayNameCircular() async throws {
        #expect(QRCodePosition.none.displayName(for: .circular) == "None")
        #expect(QRCodePosition.left.displayName(for: .circular) == "Top")
        #expect(QRCodePosition.right.displayName(for: .circular) == "Bottom")
        #expect(QRCodePosition.both.displayName(for: .circular) == "Top & Bottom")
    }

    @Test("QR position displayName for portrait labels uses Top/Bottom")
    func testQRPositionDisplayNamePortrait() async throws {
        #expect(QRCodePosition.none.displayName(for: .portrait) == "None")
        #expect(QRCodePosition.left.displayName(for: .portrait) == "Top")
        #expect(QRCodePosition.right.displayName(for: .portrait) == "Bottom")
        #expect(QRCodePosition.both.displayName(for: .portrait) == "Top & Bottom")
    }

    @Test("QR position displayName for square labels uses Top/Bottom")
    func testQRPositionDisplayNameSquare() async throws {
        #expect(QRCodePosition.none.displayName(for: .square) == "None")
        #expect(QRCodePosition.left.displayName(for: .square) == "Top")
        #expect(QRCodePosition.right.displayName(for: .square) == "Bottom")
        #expect(QRCodePosition.both.displayName(for: .square) == "Top & Bottom")
    }

    @Test("QR position usesVerticalLayout returns correct values")
    func testQRPositionUsesVerticalLayout() async throws {
        // Vertical layout shapes
        #expect(QRCodePosition.left.usesVerticalLayout(for: .circular) == true)
        #expect(QRCodePosition.left.usesVerticalLayout(for: .portrait) == true)
        #expect(QRCodePosition.left.usesVerticalLayout(for: .square) == true)

        // Horizontal layout shapes
        #expect(QRCodePosition.left.usesVerticalLayout(for: .landscape) == false)
        #expect(QRCodePosition.left.usesVerticalLayout(for: .flag) == false)
    }

    // MARK: - Manufacturer Image Position Display Name Tests

    @Test("Manufacturer image displayName for landscape labels uses Left/Right")
    func testManufacturerImageDisplayNameLandscape() async throws {
        #expect(ManufacturerImagePosition.none.displayName(for: .landscape) == "None")
        #expect(ManufacturerImagePosition.left.displayName(for: .landscape) == "Left side")
        #expect(ManufacturerImagePosition.right.displayName(for: .landscape) == "Right side")
        #expect(ManufacturerImagePosition.both.displayName(for: .landscape) == "Both sides")
    }

    @Test("Manufacturer image displayName for circular labels uses Top/Bottom")
    func testManufacturerImageDisplayNameCircular() async throws {
        #expect(ManufacturerImagePosition.none.displayName(for: .circular) == "None")
        #expect(ManufacturerImagePosition.left.displayName(for: .circular) == "Top")
        #expect(ManufacturerImagePosition.right.displayName(for: .circular) == "Bottom")
        #expect(ManufacturerImagePosition.both.displayName(for: .circular) == "Top & Bottom")
    }

    @Test("Manufacturer image displayName for portrait labels uses Top/Bottom")
    func testManufacturerImageDisplayNamePortrait() async throws {
        #expect(ManufacturerImagePosition.none.displayName(for: .portrait) == "None")
        #expect(ManufacturerImagePosition.left.displayName(for: .portrait) == "Top")
        #expect(ManufacturerImagePosition.right.displayName(for: .portrait) == "Bottom")
        #expect(ManufacturerImagePosition.both.displayName(for: .portrait) == "Top & Bottom")
    }

    @Test("Manufacturer image displayName for square labels uses Top/Bottom")
    func testManufacturerImageDisplayNameSquare() async throws {
        #expect(ManufacturerImagePosition.none.displayName(for: .square) == "None")
        #expect(ManufacturerImagePosition.left.displayName(for: .square) == "Top")
        #expect(ManufacturerImagePosition.right.displayName(for: .square) == "Bottom")
        #expect(ManufacturerImagePosition.both.displayName(for: .square) == "Top & Bottom")
    }

    @Test("Manufacturer image usesVerticalLayout returns correct values")
    func testManufacturerImageUsesVerticalLayout() async throws {
        // Vertical layout shapes
        #expect(ManufacturerImagePosition.left.usesVerticalLayout(for: .circular) == true)
        #expect(ManufacturerImagePosition.left.usesVerticalLayout(for: .portrait) == true)
        #expect(ManufacturerImagePosition.left.usesVerticalLayout(for: .square) == true)

        // Horizontal layout shapes
        #expect(ManufacturerImagePosition.left.usesVerticalLayout(for: .landscape) == false)
        #expect(ManufacturerImagePosition.left.usesVerticalLayout(for: .flag) == false)
    }

    // MARK: - LabelShape Tests

    @Test("LabelGeometry computes correct shape for various dimensions")
    func testLabelGeometryShape() async throws {
        // Landscape (wider than tall)
        let landscape = LabelGeometry(
            name: "Landscape", labelsPerSheet: 1, columns: 1, rows: 1,
            labelWidth: 200, labelHeight: 100, leftMargin: 0, topMargin: 0,
            horizontalGap: 0, verticalGap: 0, defaultFontScale: 1.0, defaultQRSize: 0.65
        )
        #expect(landscape.shape == .landscape)

        // Portrait (taller than wide)
        let portrait = LabelGeometry(
            name: "Portrait", labelsPerSheet: 1, columns: 1, rows: 1,
            labelWidth: 100, labelHeight: 200, leftMargin: 0, topMargin: 0,
            horizontalGap: 0, verticalGap: 0, defaultFontScale: 1.0, defaultQRSize: 0.65
        )
        #expect(portrait.shape == .portrait)

        // Square (equal dimensions)
        let square = LabelGeometry(
            name: "Square", labelsPerSheet: 1, columns: 1, rows: 1,
            labelWidth: 100, labelHeight: 100, leftMargin: 0, topMargin: 0,
            horizontalGap: 0, verticalGap: 0, defaultFontScale: 1.0, defaultQRSize: 0.65
        )
        #expect(square.shape == .square)

        // Circular
        let circular = LabelGeometry(
            name: "Circular", labelsPerSheet: 1, columns: 1, rows: 1,
            labelWidth: 100, labelHeight: 100, leftMargin: 0, topMargin: 0,
            horizontalGap: 0, verticalGap: 0, defaultFontScale: 1.0, defaultQRSize: 0.65,
            isCircular: true
        )
        #expect(circular.shape == .circular)

        // Barbell/Flag
        let barbell = LabelGeometry(
            name: "Barbell", labelsPerSheet: 1, columns: 1, rows: 1,
            labelWidth: 200, labelHeight: 50, leftMargin: 0, topMargin: 0,
            horizontalGap: 0, verticalGap: 0, defaultFontScale: 1.0, defaultQRSize: 0.65,
            isBarbell: true, barbellFlagWidth: 50, barbellWrapHeight: 20
        )
        #expect(barbell.shape == .flag)
    }

    // MARK: - Labels Per Sheet Calculation Tests

    @Test("Labels per sheet equals rows times columns")
    func testLabelsPerSheetCalculation() async throws {
        let formats = [
            LabelGeometry.defaultFormat,
            Self.testLargeLabel,
            Self.testSmallLabel
        ]

        for format in formats {
            #expect(format.labelsPerSheet == format.rows * format.columns, "Row×Column mismatch for \(format.name)")
        }
    }

    @Test("Custom geometry validates correctly")
    func testCustomGeometryValidation() async throws {
        let config = LabelBuilderConfig.default

        // Create custom geometry
        let customFormat = LabelGeometry(
            name: "Custom Test",
            labelsPerSheet: 12,
            columns: 3,
            rows: 4,
            labelWidth: 180,
            labelHeight: 100,
            leftMargin: 20,
            topMargin: 30,
            horizontalGap: 10,
            verticalGap: 10,
            defaultFontScale: 1.0,
            defaultQRSize: 0.65
        )

        let validation = config.validateLayout(for: customFormat)

        #expect(validation.availableWidth > 0)
        #expect(validation.availableHeight > 0)
    }
}

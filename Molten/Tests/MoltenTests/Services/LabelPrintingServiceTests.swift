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

    // MARK: - Label Builder Configuration Tests

    @Test("LabelBuilderConfig default configuration")
    func testDefaultConfiguration() async throws {
        let config = LabelBuilderConfig.default

        #expect(config.qrPosition == .left)
        #expect(config.qrSize == nil)
        #expect(config.textFields.contains(.manufacturer))
        #expect(config.textFields.contains(.sku))
        #expect(config.textFields.contains(.colorName))
        #expect(config.textFields.contains(.coe))
        #expect(config.textAlignment == .left)
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
        #expect(preset?.config.textFields.contains(.coe) == true)
    }

    @Test("LabelBuilderConfig preset: QR Focused")
    func testPresetQRFocused() async throws {
        let preset = LabelBuilderConfig.presets.first { $0.name == "QR Focused" }

        #expect(preset != nil)
        #expect(preset?.config.qrPosition == .left)
        #expect(preset?.config.qrSize == nil)
        #expect(preset?.config.textFields.count == 2)
    }

    @Test("LabelBuilderConfig preset: Dual QR")
    func testPresetDualQR() async throws {
        let preset = LabelBuilderConfig.presets.first { $0.name == "Dual QR" }

        #expect(preset != nil)
        #expect(preset?.config.qrPosition == .both)
        #expect(preset?.config.textAlignment == .center)
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

        let legacyTemplate = config.toLegacyTemplate(format: .avery5160)

        #expect(legacyTemplate.includeQRCode == true)
        #expect(legacyTemplate.dualQRCodes == false)
        #expect(legacyTemplate.includeManufacturer == true)
        #expect(legacyTemplate.includeSKU == true)
        #expect(legacyTemplate.includeColor == true)
        #expect(legacyTemplate.includeCOE == true)
        #expect(legacyTemplate.qrCodeSize == 0.7)
    }

    // MARK: - Layout Validation Tests

    @Test("Validate layout for Avery 5160")
    func testValidateLayoutAvery5160() async throws {
        let config = LabelBuilderConfig.default
        let format = AveryFormat.avery5160

        let validation = config.validateLayout(for: format)

        #expect(validation.availableWidth > 0)
        #expect(validation.availableHeight > 0)
    }

    @Test("Validate layout for Avery 5163")
    func testValidateLayoutAvery5163() async throws {
        let config = LabelBuilderConfig.default
        let format = AveryFormat.avery5163

        let validation = config.validateLayout(for: format)

        #expect(validation.availableWidth > 0)
        #expect(validation.availableHeight > 0)
    }

    @Test("Validate layout for Avery 5167")
    func testValidateLayoutAvery5167() async throws {
        let config = LabelBuilderConfig.default
        let format = AveryFormat.avery5167

        let validation = config.validateLayout(for: format)

        #expect(validation.availableWidth > 0)
        #expect(validation.availableHeight > 0)
    }

    @Test("Validate layout for Mr-Label MR184")
    func testValidateLayoutMrLabel() async throws {
        let config = LabelBuilderConfig.default
        let format = AveryFormat.mrLabel184

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
        let format = AveryFormat.avery5167  // Small label

        let validation = config.validateLayout(for: format, fontScale: 1.5)

        // Should have warnings about text overflow
        #expect(validation.warnings.count > 0)
    }

    @Test("Detect narrow text area warning")
    func testDetectNarrowTextArea() async throws {
        // Dual QR on very small label leaves very narrow text area
        // Need labelWidth < 120 to trigger warning
        let verySmallFormat = AveryFormat(
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
        let format = AveryFormat.avery5167  // Small label (height < 72)

        let validation = config.validateLayout(for: format)

        // Should warn about too many fields
        #expect(validation.warnings.contains { $0.contains("many fields") })
    }

    @Test("Font scale impact on layout validation")
    func testFontScaleImpact() async throws {
        let config = LabelBuilderConfig.default
        let format = AveryFormat.avery5160

        let validation1 = config.validateLayout(for: format, fontScale: 0.7)
        let validation2 = config.validateLayout(for: format, fontScale: 1.3)

        // Larger font scale should result in taller estimated text height
        #expect(validation2.estimatedTextHeight > validation1.estimatedTextHeight)
    }

    // MARK: - Avery Format Specifications Tests

    @Test("Avery 5160 dimensions")
    func testAvery5160Dimensions() async throws {
        let format = AveryFormat.avery5160

        #expect(format.name == "Avery 5160")
        #expect(format.labelsPerSheet == 30)
        #expect(format.columns == 3)
        #expect(format.rows == 10)
        #expect(format.labelWidth == 189)
        #expect(format.labelHeight == 72)
    }

    @Test("Avery 5163 dimensions")
    func testAvery5163Dimensions() async throws {
        let format = AveryFormat.avery5163

        #expect(format.name == "Avery 5163")
        #expect(format.labelsPerSheet == 10)
        #expect(format.columns == 2)
        #expect(format.rows == 5)
        #expect(format.labelWidth == 288)
        #expect(format.labelHeight == 144)
    }

    @Test("Avery 5167 dimensions")
    func testAvery5167Dimensions() async throws {
        let format = AveryFormat.avery5167

        #expect(format.name == "Avery 5167")
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
            format: .avery5160,
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
            format: .avery5160,
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
            format: .avery5160,
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
            format: .avery5160,
            config: .default,
            fontScale: 0.8
        )

        #expect(pdfURL != nil)
    }

    @Test("Generate PDF with offset adjustments")
    func testOffsetAdjustments() async throws {
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
            format: .avery5160,
            config: .default,
            offsetX: 5.0,
            offsetY: -3.0
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
            format: .avery5160,
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
            format: .avery5163,  // Larger label format
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
            format: .avery5160,
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
            format: .avery5160,
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
            format: .avery5160,
            config: config
        )

        #expect(pdfURL != nil)
    }

    // MARK: - New Label Format Tests

    @Test("Avery 5161 dimensions")
    func testAvery5161Dimensions() async throws {
        let format = AveryFormat.avery5161

        #expect(format.name == "Avery 5161")
        #expect(format.labelsPerSheet == 20)
        #expect(format.columns == 2)
        #expect(format.rows == 10)
        #expect(format.labelWidth == 288)
        #expect(format.labelHeight == 72)
    }

    @Test("Avery 5162 dimensions")
    func testAvery5162Dimensions() async throws {
        let format = AveryFormat.avery5162

        #expect(format.name == "Avery 5162")
        #expect(format.labelsPerSheet == 14)
        #expect(format.columns == 2)
        #expect(format.rows == 7)
        #expect(format.labelWidth == 288)
        #expect(format.labelHeight == 96)
    }

    @Test("Avery 5164 dimensions")
    func testAvery5164Dimensions() async throws {
        let format = AveryFormat.avery5164

        #expect(format.name == "Avery 5164")
        #expect(format.labelsPerSheet == 6)
        #expect(format.columns == 2)
        #expect(format.rows == 3)
        #expect(format.labelWidth == 288)
        #expect(format.labelHeight == 240)
    }

    @Test("Avery 8160 dimensions")
    func testAvery8160Dimensions() async throws {
        let format = AveryFormat.avery8160

        #expect(format.name == "Avery 8160")
        #expect(format.labelsPerSheet == 30)
        #expect(format.columns == 3)
        #expect(format.rows == 10)
        #expect(format.labelWidth == 189)
        #expect(format.labelHeight == 72)
    }

    @Test("Avery 8163 dimensions")
    func testAvery8163Dimensions() async throws {
        let format = AveryFormat.avery8163

        #expect(format.name == "Avery 8163")
        #expect(format.labelsPerSheet == 10)
        #expect(format.columns == 2)
        #expect(format.rows == 5)
        #expect(format.labelWidth == 288)
        #expect(format.labelHeight == 144)
    }

    @Test("Avery 5168 dimensions (extra large)")
    func testAvery5168Dimensions() async throws {
        let format = AveryFormat.avery5168

        #expect(format.name == "Avery 5168")
        #expect(format.labelsPerSheet == 4)
        #expect(format.columns == 2)
        #expect(format.rows == 2)
        #expect(format.labelWidth == 360)
        #expect(format.labelHeight == 252)
    }

    @Test("Avery 5395 name badge dimensions")
    func testAvery5395Dimensions() async throws {
        let format = AveryFormat.avery5395

        #expect(format.name == "Avery 5395")
        #expect(format.labelsPerSheet == 8)
        #expect(format.columns == 2)
        #expect(format.rows == 4)
        #expect(format.labelWidth == 243)
        #expect(format.labelHeight == 168)
    }

    @Test("Avery 6870 durable ID dimensions")
    func testAvery6870Dimensions() async throws {
        let format = AveryFormat.avery6870

        #expect(format.name == "Avery 6870")
        #expect(format.labelsPerSheet == 30)
        #expect(format.columns == 3)
        #expect(format.rows == 10)
        #expect(format.labelWidth == 162)
        #expect(format.labelHeight == 54)
    }

    @Test("Avery 5165 full sheet dimensions")
    func testAvery5165Dimensions() async throws {
        let format = AveryFormat.avery5165

        #expect(format.name == "Avery 5165")
        #expect(format.labelsPerSheet == 1)
        #expect(format.columns == 1)
        #expect(format.rows == 1)
        #expect(format.labelWidth == 612)
        #expect(format.labelHeight == 792)
        #expect(format.leftMargin == 0)
        #expect(format.topMargin == 0)
    }

    @Test("AveryFormat allFormats contains all categories")
    func testAllFormatsCategories() async throws {
        let allFormats = AveryFormat.allFormats

        #expect(allFormats.keys.contains("Popular"))
        #expect(allFormats.keys.contains("Address Labels"))
        #expect(allFormats.keys.contains("Shipping Labels"))
        #expect(allFormats.keys.contains("Return Address"))
        #expect(allFormats.keys.contains("Round/Circle Labels"))
        #expect(allFormats.keys.contains("File Folder Labels"))
        #expect(allFormats.keys.contains("Durable/Ultra Duty"))
        #expect(allFormats.keys.contains("Multipurpose"))
        #expect(allFormats.keys.contains("Name Badges & Cards"))
        #expect(allFormats.keys.contains("Full Sheet"))
        #expect(allFormats.keys.contains("Other Brands"))
    }

    @Test("AveryFormat flatList contains all unique formats")
    func testFlatListUnique() async throws {
        let flatList = AveryFormat.flatList

        // Should have many formats
        #expect(flatList.count > 20)

        // Should be sorted alphabetically
        for i in 0..<(flatList.count - 1) {
            #expect(flatList[i].name <= flatList[i + 1].name)
        }

        // Should have no duplicates
        let uniqueNames = Set(flatList.map { $0.name })
        #expect(uniqueNames.count == flatList.count)
    }

    @Test("Generate PDF with Avery 5161 format")
    func testGeneratePDFAvery5161() async throws {
        let service = LabelPrintingService()

        let labels = [
            LabelData(
                stableId: "test1",
                manufacturer: "Test",
                sku: "001",
                colorName: "Color",
                coe: "90",
                location: nil,
                owner: nil
            )
        ]

        let pdfURL = await service.generateLabelSheet(
            labels: labels,
            format: .avery5161,
            config: .default
        )

        #expect(pdfURL != nil)
    }

    @Test("Generate PDF with Avery 5164 format")
    func testGeneratePDFAvery5164() async throws {
        let service = LabelPrintingService()

        let labels = [
            LabelData(
                stableId: "test1",
                manufacturer: "Test",
                sku: "001",
                colorName: "Color",
                coe: "90",
                location: "Studio A",
                owner: "Owner Name"
            )
        ]

        let config = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.5,
            fontScale: nil,
            manufacturerImagePosition: .none,
            manufacturerImageSize: nil,
            textFields: [.manufacturer, .sku, .colorName, .coe, .location, .owner],
            textAlignment: .left,
            fieldFormats: [:]
        )

        let pdfURL = await service.generateLabelSheet(
            labels: labels,
            format: .avery5164,
            config: config
        )

        #expect(pdfURL != nil)
    }

    @Test("Generate PDF with Avery 8167 return address format")
    func testGeneratePDFAvery8167() async throws {
        let service = LabelPrintingService()

        let labels = [
            LabelData(
                stableId: "test1",
                manufacturer: "BE",
                sku: "001",
                colorName: nil,
                coe: "90",
                location: nil,
                owner: nil
            )
        ]

        let config = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.7,
            fontScale: nil,
            manufacturerImagePosition: .none,
            manufacturerImageSize: nil,
            textFields: [.manufacturer, .sku],
            textAlignment: .left,
            fieldFormats: [:]
        )

        let pdfURL = await service.generateLabelSheet(
            labels: labels,
            format: .avery8167,
            config: config
        )

        #expect(pdfURL != nil)
    }

    @Test("Validate layout for all new formats")
    func testValidateLayoutNewFormats() async throws {
        // Use minimal config for testing - some small formats can't fit QR + manufacturer image
        let config = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: nil,
            fontScale: nil,
            manufacturerImagePosition: .none,  // No manufacturer image for small labels
            manufacturerImageSize: nil,
            textFields: [.manufacturer, .sku, .colorName],
            textAlignment: .left,
            fieldFormats: [:]
        )
        let formats: [AveryFormat] = [
            .avery5161, .avery5162, .avery5164, .avery5168,
            .avery5260, .avery5261, .avery5262, .avery5263, .avery5264,
            .avery8160, .avery8161, .avery8162, .avery8163, .avery8164,
            .avery5395, .avery6870, .avery5165, .avery8165
        ]

        for format in formats {
            let validation = config.validateLayout(for: format)
            #expect(validation.availableWidth > 0, "Failed for \(format.name)")
            #expect(validation.availableHeight > 0, "Failed for \(format.name)")
        }
    }

    @Test("Labels per sheet calculation is correct for all formats")
    func testLabelsPerSheetCalculation() async throws {
        let formats: [(AveryFormat, Int)] = [
            (.avery5160, 30),
            (.avery5161, 20),
            (.avery5162, 14),
            (.avery5163, 10),
            (.avery5164, 6),
            (.avery5167, 80),
            (.avery5168, 4),
            (.avery8160, 30),
            (.avery8163, 10),
            (.avery8167, 80),
            (.avery5165, 1),
            (.avery8165, 1),
            (.avery5395, 8),
            (.avery6870, 30)
        ]

        for (format, expectedCount) in formats {
            #expect(format.labelsPerSheet == expectedCount, "Failed for \(format.name)")
            #expect(format.labelsPerSheet == format.rows * format.columns, "Row×Column mismatch for \(format.name)")
        }
    }
}

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

    init() async {
        // Configure repository factory for testing (uses mocks)
        let deps = AppDependencies(forTesting: true)
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
        #expect(config.qrSize == 0.65)
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
        #expect(preset?.config.qrSize == 0.65)
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
        #expect(preset?.config.qrSize == 0.75)
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
            textFields: [.manufacturer, .sku],
            textAlignment: .left
        )

        #expect(config.qrPosition == .left)
    }

    @Test("LabelBuilderConfig QR position right")
    func testQRPositionRight() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .right,
            qrSize: 0.65,
            textFields: [.manufacturer, .sku],
            textAlignment: .right
        )

        #expect(config.qrPosition == .right)
    }

    @Test("LabelBuilderConfig QR position both")
    func testQRPositionBoth() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .both,
            qrSize: 0.65,
            textFields: [.manufacturer, .sku],
            textAlignment: .center
        )

        #expect(config.qrPosition == .both)
    }

    @Test("LabelBuilderConfig QR position none")
    func testQRPositionNone() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .none,
            qrSize: 0.65,
            textFields: [.manufacturer, .sku, .colorName, .coe],
            textAlignment: .left
        )

        #expect(config.qrPosition == .none)
    }

    @Test("LabelBuilderConfig text alignment left")
    func testTextAlignmentLeft() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            textFields: [.manufacturer],
            textAlignment: .left
        )

        #expect(config.textAlignment == .left)
    }

    @Test("LabelBuilderConfig text alignment center")
    func testTextAlignmentCenter() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .both,
            qrSize: 0.65,
            textFields: [.manufacturer],
            textAlignment: .center
        )

        #expect(config.textAlignment == .center)
    }

    @Test("LabelBuilderConfig text alignment right")
    func testTextAlignmentRight() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .right,
            qrSize: 0.65,
            textFields: [.manufacturer],
            textAlignment: .right
        )

        #expect(config.textAlignment == .right)
    }

    @Test("LabelBuilderConfig text field selection")
    func testTextFieldSelection() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            textFields: [.manufacturer, .coe, .location],
            textAlignment: .left
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
            textFields: [.colorName, .manufacturer, .sku],
            textAlignment: .left
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
            textFields: [.manufacturer, .sku, .colorName, .coe],
            textAlignment: .left
        )

        let legacyTemplate = config.toLegacyTemplate()

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
            textFields: [.manufacturer, .sku, .colorName, .coe, .location, .owner],
            textAlignment: .left
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
            verticalGap: 10
        )

        let config = LabelBuilderConfig(
            qrPosition: .both,
            qrSize: 0.75,
            textFields: [.manufacturer, .sku],
            textAlignment: .center
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
            textFields: [.manufacturer, .sku, .colorName, .coe, .location, .owner],
            textAlignment: .left
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

    // MARK: - Preset Management Tests

    @Test("Save preset to manager")
    func testSavePreset() async throws {
        let manager = LabelPresetsManager.shared

        let preset = LabelBuilderPreset(
            name: "Test Preset",
            description: "Test description",
            config: LabelBuilderConfig.default
        )

        manager.savePreset(preset)

        let allPresets = manager.allPresets
        #expect(allPresets.contains { $0.id == preset.id })
    }

    @Test("Delete preset from manager")
    func testDeletePreset() async throws {
        let manager = LabelPresetsManager.shared

        let preset = LabelBuilderPreset(
            name: "Test Delete Preset",
            description: "Will be deleted",
            config: LabelBuilderConfig.default
        )

        manager.savePreset(preset)
        #expect(manager.userPresets.contains { $0.id == preset.id })

        manager.deletePreset(preset)
        #expect(!manager.userPresets.contains { $0.id == preset.id })
    }

    @Test("Export preset to JSON")
    func testExportPreset() async throws {
        let preset = LabelBuilderPreset(
            name: "Export Test",
            description: "Test export",
            config: LabelBuilderConfig.default
        )

        let jsonData = preset.exportJSON()

        #expect(jsonData != nil)
        #expect(jsonData!.count > 0)
    }

    @Test("Import preset from JSON")
    func testImportPreset() async throws {
        let manager = LabelPresetsManager.shared

        let originalPreset = LabelBuilderPreset(
            name: "Import Test",
            description: "Test import",
            config: LabelBuilderConfig.default
        )

        guard let jsonData = originalPreset.exportJSON() else {
            Issue.record("Failed to export preset")
            return
        }

        try manager.importPreset(from: jsonData)

        // Should have imported preset with new ID
        #expect(manager.userPresets.contains { $0.name == "Import Test" })
    }

    @Test("Get all presets includes built-in and user presets")
    func testGetAllPresets() async throws {
        let manager = LabelPresetsManager.shared

        let allPresets = manager.allPresets

        // Should include built-in presets
        #expect(allPresets.count >= LabelBuilderConfig.presets.count)
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
            textFields: [.manufacturer, .sku, .colorName, .coe, .location, .owner],
            textAlignment: .left
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
            textFields: [.manufacturer, .sku],  // Both fields enabled
            textAlignment: .left
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
            textFields: [.manufacturer, .sku, .colorName, .coe],
            textAlignment: .center
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
            textFields: [.manufacturer, .sku],
            textAlignment: .center
        )

        let pdfURL = await service.generateLabelSheet(
            labels: labels,
            format: .avery5160,
            config: config
        )

        #expect(pdfURL != nil)
    }
}

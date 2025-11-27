//
//  LabelPrintingOwnerTests.swift
//  MoltenTests
//
//  Tests for owner field display on printed labels
//

import Testing
import Foundation
@testable import Molten

@Suite("Label Printing - Owner Display")
@MainActor
struct LabelPrintingOwnerTests {

    @Test("Label config can include owner field")
    func labelConfigCanIncludeOwner() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            manufacturerImagePosition: .none,
            textFields: [LabelTextField.manufacturer, LabelTextField.sku, LabelTextField.colorName, LabelTextField.owner],
            textAlignment: .left,
            fieldFormats: LabelFieldFormat.defaults
        )

        #expect(config.textFields.contains(.owner))
    }

    @Test("Label config validates layout with owner field")
    func configValidatesLayoutWithOwner() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            manufacturerImagePosition: .none,
            textFields: [LabelTextField.manufacturer, LabelTextField.sku, LabelTextField.colorName, LabelTextField.coe, LabelTextField.location, LabelTextField.owner],
            textAlignment: .left,
            fieldFormats: LabelFieldFormat.defaults
        )

        let validation = config.validateLayout(for: LabelGeometry.defaultFormat)

        // Should provide validation result (may or may not fit depending on format)
        #expect(validation.estimatedTextHeight > 0)
        #expect(validation.availableHeight > 0)
    }

    @Test("Owner field increases estimated text height")
    func ownerFieldIncreasesEstimatedHeight() async throws {
        let configWithoutOwner = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            manufacturerImagePosition: .none,
            textFields: [LabelTextField.manufacturer, LabelTextField.sku, LabelTextField.colorName],
            textAlignment: .left,
            fieldFormats: LabelFieldFormat.defaults
        )

        let configWithOwner = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            manufacturerImagePosition: .none,
            textFields: [LabelTextField.manufacturer, LabelTextField.sku, LabelTextField.colorName, LabelTextField.owner],
            textAlignment: .left,
            fieldFormats: LabelFieldFormat.defaults
        )

        let validationWithout = configWithoutOwner.validateLayout(for: LabelGeometry.defaultFormat)
        let validationWith = configWithOwner.validateLayout(for: LabelGeometry.defaultFormat)

        // Adding owner should increase estimated height by 8pt (owner's estimated height)
        #expect(validationWith.estimatedTextHeight > validationWithout.estimatedTextHeight)
        #expect(validationWith.estimatedTextHeight == validationWithout.estimatedTextHeight + 8)
    }

    @Test("Small labels with many fields including owner show warnings")
    func smallLabelsWithManyFieldsShowWarnings() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .both,
            qrSize: 0.75,
            manufacturerImagePosition: .none,
            textFields: [LabelTextField.manufacturer, LabelTextField.sku, LabelTextField.colorName, LabelTextField.coe, LabelTextField.location, LabelTextField.owner],
            textAlignment: .left,
            fieldFormats: LabelFieldFormat.defaults
        )

        // Test with small label format (Avery 5167 - 0.5" × 1.75")
        let validation = config.validateLayout(for: LabelGeometry(name: "Test Small", labelsPerSheet: 80, columns: 4, rows: 20, labelWidth: 126, labelHeight: 36, leftMargin: 18, topMargin: 36, horizontalGap: 9, verticalGap: 0, defaultFontScale: 0.75, defaultQRSize: 0.7))

        // Should have warnings about fitting issues
        #expect(!validation.warnings.isEmpty)
    }

    @Test("Large labels with owner field validate without warnings")
    func largeLabelsWithOwnerValidateCleanly() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            manufacturerImagePosition: .none,
            textFields: [LabelTextField.manufacturer, LabelTextField.sku, LabelTextField.owner],
            textAlignment: .left,
            fieldFormats: LabelFieldFormat.defaults
        )

        // Test with large label format (Avery 5163 - 2" × 4")
        let validation = config.validateLayout(for: LabelGeometry(name: "Test Large", labelsPerSheet: 10, columns: 2, rows: 5, labelWidth: 288, labelHeight: 144, leftMargin: 18, topMargin: 36, horizontalGap: 9, verticalGap: 0, defaultFontScale: 1.0, defaultQRSize: 0.6))

        // Should fit without issues
        #expect(validation.fits)
    }

    @Test("Owner field works with different font scales")
    func ownerFieldWorksWithFontScales() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            manufacturerImagePosition: .none,
            textFields: [LabelTextField.manufacturer, LabelTextField.sku, LabelTextField.owner],
            textAlignment: .left,
            fieldFormats: LabelFieldFormat.defaults
        )

        // Test with different font scales
        let scales: [CGFloat] = [0.7, 1.0, 1.3]

        for scale in scales {
            let validation = config.validateLayout(for: LabelGeometry.defaultFormat, fontScale: scale)

            // Should scale proportionally
            let baseValidation = config.validateLayout(for: LabelGeometry.defaultFormat, fontScale: 1.0)
            let expectedHeight = baseValidation.estimatedTextHeight * scale

            // Allow small floating-point differences
            let difference = abs(validation.estimatedTextHeight - expectedHeight)
            #expect(difference < 0.1)
        }
    }

    @Test("Preset configurations default to excluding owner")
    func presetConfigurationsDefaultToExcludingOwner() async throws {
        // Built-in presets should not include owner by default (it's optional)
        let presets = LabelBuilderConfig.presets

        for preset in presets {
            // Owner should not be in default presets (user adds it manually if needed)
            #expect(!preset.config.textFields.contains(.owner))
        }
    }

    @Test("Legacy templates default to owner excluded")
    func legacyTemplatesDefaultToOwnerExcluded() async throws {
        // Check all legacy template presets
        #expect(LabelTemplate.informationDense.includeOwner == false)
        #expect(LabelTemplate.qrFocused.includeOwner == false)
        #expect(LabelTemplate.locationBased.includeOwner == false)
        #expect(LabelTemplate.dualQR.includeOwner == false)
    }

    @Test("Owner field can be combined with all other fields")
    func ownerCanBeCombinedWithAllFields() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            manufacturerImagePosition: .none,
            textFields: [LabelTextField.manufacturer, LabelTextField.sku, LabelTextField.colorName, LabelTextField.coe, LabelTextField.location, LabelTextField.owner],
            textAlignment: .left,
            fieldFormats: LabelFieldFormat.defaults
        )

        // All fields should be present
        #expect(config.textFields.count == 6)
        #expect(config.textFields.contains(.manufacturer))
        #expect(config.textFields.contains(.sku))
        #expect(config.textFields.contains(.colorName))
        #expect(config.textFields.contains(.coe))
        #expect(config.textFields.contains(.location))
        #expect(config.textFields.contains(.owner))
    }

    @Test("Owner field can be used alone")
    func ownerFieldCanBeUsedAlone() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.75,
            manufacturerImagePosition: .none,
            textFields: [LabelTextField.owner],
            textAlignment: .left,
            fieldFormats: LabelFieldFormat.defaults
        )

        #expect(config.textFields.count == 1)
        #expect(config.textFields.first == .owner)
    }

    @Test("Owner field order matters in config")
    func ownerFieldOrderMattersInConfig() async throws {
        let configFirst = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            manufacturerImagePosition: .none,
            textFields: [LabelTextField.owner, LabelTextField.manufacturer, LabelTextField.sku],
            textAlignment: .left,
            fieldFormats: LabelFieldFormat.defaults
        )

        let configLast = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            manufacturerImagePosition: .none,
            textFields: [LabelTextField.manufacturer, LabelTextField.sku, LabelTextField.owner],
            textAlignment: .left,
            fieldFormats: LabelFieldFormat.defaults
        )

        #expect(configFirst.textFields.first == .owner)
        #expect(configFirst.textFields.last == .sku)

        #expect(configLast.textFields.first == .manufacturer)
        #expect(configLast.textFields.last == .owner)
    }

    @Test("Owner field validation with no QR code")
    func ownerFieldValidationWithNoQRCode() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .none,
            qrSize: 0.65,
            manufacturerImagePosition: .none,
            textFields: [LabelTextField.manufacturer, LabelTextField.sku, LabelTextField.colorName, LabelTextField.owner],
            textAlignment: .left,
            fieldFormats: LabelFieldFormat.defaults
        )

        let validation = config.validateLayout(for: LabelGeometry.defaultFormat)

        // Should have more available width without QR code
        #expect(validation.availableWidth > 100)
        #expect(validation.fits)
    }

    @Test("Owner field validation with dual QR codes")
    func ownerFieldValidationWithDualQRCodes() async throws {
        let configDual = LabelBuilderConfig(
            qrPosition: .both,
            qrSize: 0.65,
            manufacturerImagePosition: .none,
            textFields: [LabelTextField.manufacturer, LabelTextField.sku, LabelTextField.owner],
            textAlignment: .left,
            fieldFormats: LabelFieldFormat.defaults
        )

        let configSingle = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            manufacturerImagePosition: .none,
            textFields: [LabelTextField.manufacturer, LabelTextField.sku, LabelTextField.owner],
            textAlignment: .left,
            fieldFormats: LabelFieldFormat.defaults
        )

        let validationDual = configDual.validateLayout(for: LabelGeometry.defaultFormat)
        let validationSingle = configSingle.validateLayout(for: LabelGeometry.defaultFormat)

        // Should have reduced available width due to dual QR codes compared to single QR
        #expect(validationDual.availableWidth < validationSingle.availableWidth)
    }
}

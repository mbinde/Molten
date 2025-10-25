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
            textFields: [.manufacturer, .sku, .colorName, .owner]
        )

        #expect(config.textFields.contains(.owner))
    }

    @Test("Label config validates layout with owner field")
    func configValidatesLayoutWithOwner() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            textFields: [.manufacturer, .sku, .colorName, .coe, .location, .owner]
        )

        let validation = config.validateLayout(for: .avery5160)

        // Should provide validation result (may or may not fit depending on format)
        #expect(validation.estimatedTextHeight > 0)
        #expect(validation.availableHeight > 0)
    }

    @Test("Owner field increases estimated text height")
    func ownerFieldIncreasesEstimatedHeight() async throws {
        let configWithoutOwner = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            textFields: [.manufacturer, .sku, .colorName]
        )

        let configWithOwner = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            textFields: [.manufacturer, .sku, .colorName, .owner]
        )

        let validationWithout = configWithoutOwner.validateLayout(for: .avery5160)
        let validationWith = configWithOwner.validateLayout(for: .avery5160)

        // Adding owner should increase estimated height by 8pt (owner's estimated height)
        #expect(validationWith.estimatedTextHeight > validationWithout.estimatedTextHeight)
        #expect(validationWith.estimatedTextHeight == validationWithout.estimatedTextHeight + 8)
    }

    @Test("Small labels with many fields including owner show warnings")
    func smallLabelsWithManyFieldsShowWarnings() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .both,
            qrSize: 0.75,
            textFields: [.manufacturer, .sku, .colorName, .coe, .location, .owner]
        )

        // Test with small label format (Avery 5167 - 0.5" × 1.75")
        let validation = config.validateLayout(for: .avery5167)

        // Should have warnings about fitting issues
        #expect(!validation.warnings.isEmpty)
    }

    @Test("Large labels with owner field validate without warnings")
    func largeLabelsWithOwnerValidateCleanly() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            textFields: [.manufacturer, .sku, .owner]
        )

        // Test with large label format (Avery 5163 - 2" × 4")
        let validation = config.validateLayout(for: .avery5163)

        // Should fit without issues
        #expect(validation.fits)
    }

    @Test("Owner field works with different font scales")
    func ownerFieldWorksWithFontScales() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            textFields: [.manufacturer, .sku, .owner]
        )

        // Test with different font scales
        let scales: [CGFloat] = [0.7, 1.0, 1.3]

        for scale in scales {
            let validation = config.validateLayout(for: .avery5160, fontScale: scale)

            // Should scale proportionally
            let baseValidation = config.validateLayout(for: .avery5160, fontScale: 1.0)
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
            textFields: [.manufacturer, .sku, .colorName, .coe, .location, .owner]
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
            textFields: [.owner]
        )

        #expect(config.textFields.count == 1)
        #expect(config.textFields.first == .owner)
    }

    @Test("Owner field order matters in config")
    func ownerFieldOrderMattersInConfig() async throws {
        let configFirst = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            textFields: [.owner, .manufacturer, .sku]
        )

        let configLast = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            textFields: [.manufacturer, .sku, .owner]
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
            textFields: [.manufacturer, .sku, .colorName, .owner]
        )

        let validation = config.validateLayout(for: .avery5160)

        // Should have more available width without QR code
        #expect(validation.availableWidth > 100)
        #expect(validation.fits)
    }

    @Test("Owner field validation with dual QR codes")
    func ownerFieldValidationWithDualQRCodes() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .both,
            qrSize: 0.65,
            textFields: [.manufacturer, .sku, .owner]
        )

        let validation = config.validateLayout(for: .avery5160)

        // Should have reduced available width due to dual QR codes
        #expect(validation.availableWidth < validation.availableHeight)
    }
}

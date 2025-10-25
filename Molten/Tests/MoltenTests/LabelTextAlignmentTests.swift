//
//  LabelTextAlignmentTests.swift
//  MoltenTests
//
//  Tests for LabelTextAlignment enum and text alignment functionality
//

import Testing
import Foundation
@testable import Molten

@Suite("Label Text Alignment")
@MainActor
struct LabelTextAlignmentTests {

    @Test("LabelTextAlignment has all expected cases")
    func labelTextAlignmentHasAllCases() async throws {
        let allCases = LabelTextAlignment.allCases

        #expect(allCases.contains(.left))
        #expect(allCases.contains(.center))
        #expect(allCases.contains(.right))
        #expect(allCases.count == 3)
    }

    @Test("LabelTextAlignment cases have correct raw values")
    func alignmentCasesHaveCorrectRawValues() async throws {
        #expect(LabelTextAlignment.left.rawValue == "Left")
        #expect(LabelTextAlignment.center.rawValue == "Center")
        #expect(LabelTextAlignment.right.rawValue == "Right")
    }

    @Test("LabelBuilderConfig can be created with left alignment")
    func configCanBeCreatedWithLeftAlignment() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            textFields: [.manufacturer, .sku],
            textAlignment: .left
        )

        #expect(config.textAlignment == .left)
    }

    @Test("LabelBuilderConfig can be created with center alignment")
    func configCanBeCreatedWithCenterAlignment() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .both,
            qrSize: 0.65,
            textFields: [.manufacturer, .sku],
            textAlignment: .center
        )

        #expect(config.textAlignment == .center)
    }

    @Test("LabelBuilderConfig can be created with right alignment")
    func configCanBeCreatedWithRightAlignment() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .right,
            qrSize: 0.65,
            textFields: [.manufacturer, .sku],
            textAlignment: .right
        )

        #expect(config.textAlignment == .right)
    }

    @Test("Default LabelBuilderConfig has left alignment")
    func defaultConfigHasLeftAlignment() async throws {
        let config = LabelBuilderConfig.default

        #expect(config.textAlignment == .left)
    }

    @Test("Information Dense preset has left alignment")
    func informationDensePresetHasLeftAlignment() async throws {
        let preset = LabelBuilderConfig.presets[0]

        #expect(preset.name == "Information Dense")
        #expect(preset.config.textAlignment == .left)
    }

    @Test("QR Focused preset has left alignment")
    func qrFocusedPresetHasLeftAlignment() async throws {
        let preset = LabelBuilderConfig.presets[1]

        #expect(preset.name == "QR Focused")
        #expect(preset.config.textAlignment == .left)
    }

    @Test("Dual QR preset has center alignment")
    func dualQRPresetHasCenterAlignment() async throws {
        let preset = LabelBuilderConfig.presets[2]

        #expect(preset.name == "Dual QR")
        #expect(preset.config.textAlignment == .center)
    }

    @Test("Location Labels preset has left alignment")
    func locationLabelsPresetHasLeftAlignment() async throws {
        let preset = LabelBuilderConfig.presets[3]

        #expect(preset.name == "Location Labels")
        #expect(preset.config.textAlignment == .left)
    }

    @Test("Text alignment works with all QR positions")
    func textAlignmentWorksWithAllQRPositions() async throws {
        for qrPosition in QRCodePosition.allCases {
            for alignment in LabelTextAlignment.allCases {
                let config = LabelBuilderConfig(
                    qrPosition: qrPosition,
                    qrSize: 0.65,
                    textFields: [.manufacturer, .sku],
                    textAlignment: alignment
                )

                #expect(config.qrPosition == qrPosition)
                #expect(config.textAlignment == alignment)
            }
        }
    }

    @Test("Legacy template conversion defaults to left alignment")
    func legacyTemplateConversionDefaultsToLeftAlignment() async throws {
        let template = LabelTemplate(
            name: "Test",
            includeQRCode: true,
            dualQRCodes: false,
            includeManufacturer: true,
            includeSKU: true,
            includeColor: true,
            includeCOE: true,
            includeQuantity: false,
            includeLocation: false,
            includeOwner: false,
            qrCodeSize: 0.65
        )

        let config = template.toBuilderConfig()

        #expect(config.textAlignment == .left)
    }

    @Test("LabelBuilderConfig equality includes text alignment")
    func configEqualityIncludesTextAlignment() async throws {
        let config1 = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            textFields: [.manufacturer, .sku],
            textAlignment: .left
        )

        let config2 = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            textFields: [.manufacturer, .sku],
            textAlignment: .left
        )

        let config3 = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            textFields: [.manufacturer, .sku],
            textAlignment: .center
        )

        #expect(config1 == config2)
        #expect(config1 != config3)
    }

    @Test("LabelBuilderConfig is Codable with text alignment")
    func configIsCodeableWithTextAlignment() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .both,
            qrSize: 0.70,
            textFields: [.manufacturer, .sku, .colorName],
            textAlignment: .center
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(config)
        let decoded = try decoder.decode(LabelBuilderConfig.self, from: data)

        #expect(decoded.qrPosition == config.qrPosition)
        #expect(decoded.qrSize == config.qrSize)
        #expect(decoded.textFields == config.textFields)
        #expect(decoded.textAlignment == config.textAlignment)
    }

    @Test("Text alignment is independent of QR position")
    func textAlignmentIsIndependentOfQRPosition() async throws {
        // Test that you can have center alignment with left QR
        let config1 = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            textFields: [.manufacturer, .sku],
            textAlignment: .center
        )
        #expect(config1.qrPosition == .left)
        #expect(config1.textAlignment == .center)

        // Test that you can have left alignment with no QR
        let config2 = LabelBuilderConfig(
            qrPosition: .none,
            qrSize: 0.65,
            textFields: [.manufacturer, .sku, .colorName],
            textAlignment: .left
        )
        #expect(config2.qrPosition == .none)
        #expect(config2.textAlignment == .left)

        // Test that you can have right alignment with dual QR
        let config3 = LabelBuilderConfig(
            qrPosition: .both,
            qrSize: 0.65,
            textFields: [.manufacturer, .sku],
            textAlignment: .right
        )
        #expect(config3.qrPosition == .both)
        #expect(config3.textAlignment == .right)
    }

    @Test("All presets have valid text alignment")
    func allPresetsHaveValidTextAlignment() async throws {
        for preset in LabelBuilderConfig.presets {
            // Every preset should have a text alignment
            #expect(LabelTextAlignment.allCases.contains(preset.config.textAlignment))
        }
    }

    @Test("LabelTextAlignment is Codable")
    func labelTextAlignmentIsCodeable() async throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for alignment in LabelTextAlignment.allCases {
            let data = try encoder.encode(alignment)
            let decoded = try decoder.decode(LabelTextAlignment.self, from: data)

            #expect(decoded == alignment)
        }
    }
}

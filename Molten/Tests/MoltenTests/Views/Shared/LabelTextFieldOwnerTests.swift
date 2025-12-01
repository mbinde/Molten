//
//  LabelTextFieldOwnerTests.swift
//  MoltenTests
//
//  Tests for LabelTextField owner enum case
//

import Testing
import Foundation
@testable import Molten

@Suite("LabelTextField - Owner Enum")
@MainActor
struct LabelTextFieldOwnerTests {

    @Test("LabelTextField includes owner case")
    func labelTextFieldIncludesOwnerCase() async throws {
        let allCases = LabelTextField.allCases

        #expect(allCases.contains(.owner))
    }

    @Test("Owner field has correct raw value")
    func ownerFieldHasCorrectRawValue() async throws {
        #expect(LabelTextField.owner.rawValue == "Owner")
    }

    @Test("Owner field has correct estimated height")
    func ownerFieldHasCorrectEstimatedHeight() async throws {
        // Owner should be same size as location and COE (8pt)
        #expect(LabelTextField.owner.estimatedHeight == 8)
        #expect(LabelTextField.owner.estimatedHeight == LabelTextField.location.estimatedHeight)
        #expect(LabelTextField.owner.estimatedHeight == LabelTextField.coe.estimatedHeight)
    }

    @Test("Owner can be included in label builder config")
    func ownerCanBeIncludedInConfig() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            manufacturerImagePosition: .none,
            textFields: [.manufacturer, .sku, .colorName, .owner],
            textAlignment: .left,
            fieldFormats: LabelFieldFormat.defaults
        )

        #expect(config.textFields.contains(LabelTextField.owner))
    }

    @Test("Owner can be excluded from label builder config")
    func ownerCanBeExcludedFromConfig() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            manufacturerImagePosition: .none,
            textFields: [.manufacturer, .sku, .colorName, .coe],
            textAlignment: .left,
            fieldFormats: LabelFieldFormat.defaults
        )

        #expect(!config.textFields.contains(LabelTextField.owner))
    }

    @Test("Owner field can be in any position in textFields array")
    func ownerFieldCanBeInAnyPosition() async throws {
        let configFirst = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            manufacturerImagePosition: .none,
            textFields: [.owner, .manufacturer, .sku],
            textAlignment: .left,
            fieldFormats: LabelFieldFormat.defaults
        )
        #expect(configFirst.textFields.first == LabelTextField.owner)

        let configMiddle = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            manufacturerImagePosition: .none,
            textFields: [.manufacturer, .owner, .sku],
            textAlignment: .left,
            fieldFormats: LabelFieldFormat.defaults
        )
        #expect(configMiddle.textFields[1] == LabelTextField.owner)

        let configLast = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            manufacturerImagePosition: .none,
            textFields: [.manufacturer, .sku, .owner],
            textAlignment: .left,
            fieldFormats: LabelFieldFormat.defaults
        )
        #expect(configLast.textFields.last == LabelTextField.owner)
    }

    @Test("Legacy template can include owner")
    func legacyTemplateCanIncludeOwner() async throws {
        let template = LabelTemplate(
            name: "Test",
            includeQRCode: true,
            dualQRCodes: false,
            includeManufacturer: true,
            includeSKU: true,
            includeColor: true,
            includeCOE: true,
            includeQuantity: false,
            includeLocation: true,
            includeOwner: true,
            qrCodeSize: 0.65
        )

        #expect(template.includeOwner == true)
    }

    @Test("Legacy template conversion to builder config includes owner")
    func legacyTemplateConversionIncludesOwner() async throws {
        let template = LabelTemplate(
            name: "Test",
            includeQRCode: true,
            dualQRCodes: false,
            includeManufacturer: true,
            includeSKU: true,
            includeColor: false,
            includeCOE: false,
            includeQuantity: false,
            includeLocation: false,
            includeOwner: true,
            qrCodeSize: 0.65
        )

        let config = template.toBuilderConfig()

        #expect(config.textFields.contains(.owner))
    }

    @Test("Builder config conversion to legacy template includes owner")
    func builderConfigConversionIncludesOwner() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            manufacturerImagePosition: .none,
            textFields: [.manufacturer, .sku, .owner],
            textAlignment: .left,
            fieldFormats: LabelFieldFormat.defaults
        )

        let template = config.toLegacyTemplate(format: .defaultFormat)

        #expect(template.includeOwner == true)
    }

    @Test("Builder config without owner converts to legacy template correctly")
    func builderConfigWithoutOwnerConvertsCorrectly() async throws {
        let config = LabelBuilderConfig(
            qrPosition: .left,
            qrSize: 0.65,
            manufacturerImagePosition: .none,
            textFields: [.manufacturer, .sku, .colorName],
            textAlignment: .left,
            fieldFormats: LabelFieldFormat.defaults
        )

        let template = config.toLegacyTemplate(format: .defaultFormat)

        #expect(template.includeOwner == false)
    }

    @Test("All LabelTextField cases are accounted for")
    func allLabelTextFieldCasesAccountedFor() async throws {
        let allCases = LabelTextField.allCases

        // Verify we have all expected fields
        #expect(allCases.contains(.manufacturer))
        #expect(allCases.contains(.sku))
        #expect(allCases.contains(.colorName))
        #expect(allCases.contains(.coe))
        #expect(allCases.contains(.location))
        #expect(allCases.contains(.owner))

        // Verify count (should be 6 fields total)
        #expect(allCases.count == 6)
    }

    @Test("Owner field works with all QR positions")
    func ownerFieldWorksWithAllQRPositions() async throws {
        for qrPosition in QRCodePosition.allCases {
            let config = LabelBuilderConfig(
                qrPosition: qrPosition,
                qrSize: 0.65,
                manufacturerImagePosition: .none,
                textFields: [.owner],
                textAlignment: .left,
                fieldFormats: LabelFieldFormat.defaults
            )

            #expect(config.textFields.contains(LabelTextField.owner))
            #expect(config.qrPosition == qrPosition)
        }
    }
}

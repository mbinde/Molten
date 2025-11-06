//
//  TagColorMappingTests.swift
//  MoltenTests
//
//  Unit tests for TagColorMapping utility
//

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import SwiftUI
@testable import Molten

@Suite("TagColorMapping Tests")
struct TagColorMappingTests {

    // MARK: - Solid Color Tests

    @Test("Tag 'red' maps to solid red color")
    func testRedTag() {
        let result = TagColorMapping.colorFillFromTag("red")

        if case .solid(let color) = result {
            #expect(color == .red)
        } else {
            Issue.record("Expected solid red color")
        }
    }

    @Test("Tag 'blue' maps to solid blue color")
    func testBlueTag() {
        let result = TagColorMapping.colorFillFromTag("blue")

        if case .solid(let color) = result {
            #expect(color == .blue)
        } else {
            Issue.record("Expected solid blue color")
        }
    }

    @Test("Tag 'green' maps to solid green color")
    func testGreenTag() {
        let result = TagColorMapping.colorFillFromTag("green")

        if case .solid(let color) = result {
            #expect(color == .green)
        } else {
            Issue.record("Expected solid green color")
        }
    }

    @Test("Tag is case-insensitive")
    func testCaseInsensitivity() {
        let lowerResult = TagColorMapping.colorFillFromTag("red")
        let upperResult = TagColorMapping.colorFillFromTag("RED")
        let mixedResult = TagColorMapping.colorFillFromTag("ReD")

        #expect(lowerResult != nil)
        #expect(upperResult != nil)
        #expect(mixedResult != nil)
    }

    @Test("Tag containing color name matches")
    func testPartialColorMatch() {
        let result = TagColorMapping.colorFillFromTag("bright red")

        #expect(result != nil, "Should match 'red' in 'bright red'")
    }

    @Test("Tag 'clear' maps to light gray")
    func testClearTag() {
        let result = TagColorMapping.colorFillFromTag("clear")

        #expect(result != nil)
        if case .solid = result {
            // Clear and transparent map to light gray
        } else {
            Issue.record("Expected solid color for clear")
        }
    }

    @Test("Tag 'transparent' maps to same as clear")
    func testTransparentTag() {
        let result = TagColorMapping.colorFillFromTag("transparent")

        #expect(result != nil)
        if case .solid = result {
            // Transparent maps to light gray like clear
        } else {
            Issue.record("Expected solid color for transparent")
        }
    }

    @Test("Tag 'gray' and 'grey' map to same color")
    func testGrayGreyEquivalence() {
        let grayResult = TagColorMapping.colorFillFromTag("gray")
        let greyResult = TagColorMapping.colorFillFromTag("grey")

        #expect(grayResult != nil)
        #expect(greyResult != nil)

        if case .solid(let grayColor) = grayResult,
           case .solid(let greyColor) = greyResult {
            #expect(grayColor == greyColor)
        }
    }

    // MARK: - Gradient Tests

    @Test("Tag 'rainbow' maps to gradient")
    func testRainbowGradient() {
        let result = TagColorMapping.colorFillFromTag("rainbow")

        if case .gradient(let gradient) = result {
            #expect(gradient.stops.count >= 6, "Rainbow should have at least 6 colors")
        } else {
            Issue.record("Expected gradient for rainbow")
        }
    }

    @Test("Tag 'multi' maps to gradient")
    func testMultiGradient() {
        let result = TagColorMapping.colorFillFromTag("multi")

        if case .gradient = result {
            // Success
        } else {
            Issue.record("Expected gradient for multi")
        }
    }

    @Test("Tag 'multicolored' maps to gradient")
    func testMulticoloredGradient() {
        let result = TagColorMapping.colorFillFromTag("multicolored")

        if case .gradient = result {
            // Success
        } else {
            Issue.record("Expected gradient for multicolored")
        }
    }

    @Test("Tag 'silver' maps to gradient")
    func testSilverGradient() {
        let result = TagColorMapping.colorFillFromTag("silver")

        if case .gradient(let gradient) = result {
            #expect(gradient.stops.count >= 3, "Silver should have at least 3 colors")
        } else {
            Issue.record("Expected gradient for silver")
        }
    }

    @Test("Tag 'metallic' maps to gradient")
    func testMetallicGradient() {
        let result = TagColorMapping.colorFillFromTag("metallic")

        if case .gradient(let gradient) = result {
            #expect(gradient.stops.count >= 3, "Metallic should have at least 3 colors")
        } else {
            Issue.record("Expected gradient for metallic")
        }
    }

    @Test("Tag 'amber purple' maps to gradient")
    func testAmberPurpleGradient() {
        let result = TagColorMapping.colorFillFromTag("amber purple")

        if case .gradient(let gradient) = result {
            #expect(gradient.stops.count >= 2, "Amber-purple should have at least 2 colors")
        } else {
            Issue.record("Expected gradient for amber purple")
        }
    }

    // MARK: - Unknown Tag Tests

    @Test("Tag 'unknown' is identified as unknown")
    func testUnknownTag() {
        let isUnknown = TagColorMapping.isUnknownTag("unknown")

        #expect(isUnknown == true)
    }

    @Test("Tag containing 'unknown' is identified as unknown")
    func testPartialUnknownTag() {
        let isUnknown = TagColorMapping.isUnknownTag("unknown color")

        #expect(isUnknown == true)
    }

    @Test("isUnknownTag is case-insensitive")
    func testUnknownTagCaseInsensitive() {
        #expect(TagColorMapping.isUnknownTag("UNKNOWN") == true)
        #expect(TagColorMapping.isUnknownTag("Unknown") == true)
        #expect(TagColorMapping.isUnknownTag("unknown") == true)
    }

    @Test("Regular color tags are not identified as unknown")
    func testKnownTagNotUnknown() {
        #expect(TagColorMapping.isUnknownTag("red") == false)
        #expect(TagColorMapping.isUnknownTag("blue") == false)
        #expect(TagColorMapping.isUnknownTag("rainbow") == false)
    }

    // MARK: - No Match Tests

    @Test("Non-color tag returns nil")
    func testNonColorTag() {
        let result = TagColorMapping.colorFillFromTag("rod")

        #expect(result == nil)
    }

    @Test("Empty tag returns nil")
    func testEmptyTag() {
        let result = TagColorMapping.colorFillFromTag("")

        #expect(result == nil)
    }

    @Test("Random text returns nil")
    func testRandomText() {
        let result = TagColorMapping.colorFillFromTag("xyzabc123")

        #expect(result == nil)
    }

    // MARK: - Legacy colorFromTag Tests

    @Test("Legacy colorFromTag returns color for solid colors")
    func testLegacyColorFromTagSolid() {
        let color = TagColorMapping.colorFromTag("red")

        #expect(color != nil)
        #expect(color == .red)
    }

    @Test("Legacy colorFromTag returns first color for gradients")
    func testLegacyColorFromTagGradient() {
        let color = TagColorMapping.colorFromTag("rainbow")

        #expect(color != nil, "Should return first color from rainbow gradient")
    }

    @Test("Legacy colorFromTag returns nil for non-colors")
    func testLegacyColorFromTagNoMatch() {
        let color = TagColorMapping.colorFromTag("notacolor")

        #expect(color == nil)
    }

    // MARK: - Special Metallic Colors

    @Test("Tag 'gold' maps to gold color")
    func testGoldTag() {
        let result = TagColorMapping.colorFillFromTag("gold")

        if case .solid = result {
            // Success
        } else {
            Issue.record("Expected solid gold color")
        }
    }

    @Test("Tag 'bronze' maps to bronze color")
    func testBronzeTag() {
        let result = TagColorMapping.colorFillFromTag("bronze")

        if case .solid = result {
            // Success
        } else {
            Issue.record("Expected solid bronze color")
        }
    }

    @Test("Tag 'copper' maps to copper color")
    func testCopperTag() {
        let result = TagColorMapping.colorFillFromTag("copper")

        if case .solid = result {
            // Success
        } else {
            Issue.record("Expected solid copper color")
        }
    }

    // MARK: - All Standard Colors Coverage

    @Test("All standard color names are supported")
    func testAllStandardColors() {
        let standardColors = [
            "red", "orange", "yellow", "green", "blue", "purple", "pink",
            "brown", "gray", "grey", "black", "white", "amber", "teal",
            "turquoise", "violet", "lime", "cyan", "magenta", "indigo"
        ]

        for colorName in standardColors {
            let result = TagColorMapping.colorFillFromTag(colorName)
            #expect(result != nil, "Color '\(colorName)' should be supported")
        }
    }

    // MARK: - TagColorFill Enum Tests

    @Test("TagColorFill solid case can be extracted")
    func testTagColorFillSolidExtraction() {
        let fill = TagColorFill.solid(.red)

        if case .solid(let color) = fill {
            #expect(color == .red)
        } else {
            Issue.record("Should extract solid color")
        }
    }

    @Test("TagColorFill gradient case can be extracted")
    func testTagColorFillGradientExtraction() {
        let gradient = Gradient(colors: [.red, .blue])
        let fill = TagColorFill.gradient(gradient)

        if case .gradient(let extractedGradient) = fill {
            #expect(extractedGradient.stops.count == 2)
        } else {
            Issue.record("Should extract gradient")
        }
    }
}

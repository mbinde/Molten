//
//  SheetBreakdownHelperTests.swift
//  MoltenTests
//
//  Tests for SheetBreakdownHelper - sheet size hierarchy and breakdown logic
//

import Testing
import Foundation
@testable import Molten

@Suite("SheetBreakdownHelper Tests")
@MainActor
struct SheetBreakdownHelperTests {

    // MARK: - Size Order Tests

    @Test("Size order is correct from largest to smallest")
    func sizeOrderIsCorrect() async throws {
        let expected = ["full", "half", "12x12", "10x10", "4x4", "other"]
        #expect(SheetBreakdownHelper.sizeOrder == expected)
    }

    // MARK: - Smaller Subtypes Tests

    @Test("Full sheet can break into all smaller sizes")
    func fullSheetBreaksIntoAllSizes() async throws {
        let smaller = SheetBreakdownHelper.smallerSubtypes(than: "full")
        #expect(smaller == ["half", "12x12", "10x10", "4x4", "other"])
    }

    @Test("Half sheet can break into sizes smaller than half")
    func halfSheetBreaksIntoSmallerSizes() async throws {
        let smaller = SheetBreakdownHelper.smallerSubtypes(than: "half")
        #expect(smaller == ["12x12", "10x10", "4x4", "other"])
    }

    @Test("12x12 sheet can break into sizes smaller than 12x12")
    func twelveByTwelveBreaksIntoSmallerSizes() async throws {
        let smaller = SheetBreakdownHelper.smallerSubtypes(than: "12x12")
        #expect(smaller == ["10x10", "4x4", "other"])
    }

    @Test("10x10 sheet can break into sizes smaller than 10x10")
    func tenByTenBreaksIntoSmallerSizes() async throws {
        let smaller = SheetBreakdownHelper.smallerSubtypes(than: "10x10")
        #expect(smaller == ["4x4", "other"])
    }

    @Test("4x4 sheet can only break into other")
    func fourByFourBreaksIntoOther() async throws {
        let smaller = SheetBreakdownHelper.smallerSubtypes(than: "4x4")
        #expect(smaller == ["other"])
    }

    @Test("Other sheet has no smaller sizes")
    func otherHasNoSmallerSizes() async throws {
        let smaller = SheetBreakdownHelper.smallerSubtypes(than: "other")
        #expect(smaller.isEmpty)
    }

    @Test("Nil subtype defaults to full sheet")
    func nilSubtypeDefaultsToFull() async throws {
        let smaller = SheetBreakdownHelper.smallerSubtypes(than: nil)
        #expect(smaller == ["half", "12x12", "10x10", "4x4", "other"])
    }

    @Test("Unknown subtype returns all sizes")
    func unknownSubtypeReturnsAllSizes() async throws {
        let smaller = SheetBreakdownHelper.smallerSubtypes(than: "unknown")
        #expect(smaller == SheetBreakdownHelper.sizeOrder)
    }

    @Test("Case insensitive subtype matching")
    func caseInsensitiveMatching() async throws {
        let smallerLower = SheetBreakdownHelper.smallerSubtypes(than: "full")
        let smallerUpper = SheetBreakdownHelper.smallerSubtypes(than: "FULL")
        let smallerMixed = SheetBreakdownHelper.smallerSubtypes(than: "Full")

        #expect(smallerLower == smallerUpper)
        #expect(smallerLower == smallerMixed)
    }

    // MARK: - Supports Breakdown Tests

    @Test("Sheet type supports breakdown")
    func sheetTypeSupportsBreakdown() async throws {
        #expect(SheetBreakdownHelper.supportsBreakdown(type: "sheet", subtype: "full") == true)
        #expect(SheetBreakdownHelper.supportsBreakdown(type: "sheet", subtype: "half") == true)
        #expect(SheetBreakdownHelper.supportsBreakdown(type: "sheet", subtype: "12x12") == true)
        #expect(SheetBreakdownHelper.supportsBreakdown(type: "sheet", subtype: "10x10") == true)
        #expect(SheetBreakdownHelper.supportsBreakdown(type: "sheet", subtype: "4x4") == true)
    }

    @Test("Sheet other does not support breakdown")
    func sheetOtherDoesNotSupportBreakdown() async throws {
        #expect(SheetBreakdownHelper.supportsBreakdown(type: "sheet", subtype: "other") == false)
    }

    @Test("Non-sheet types do not support breakdown")
    func nonSheetTypesDoNotSupportBreakdown() async throws {
        #expect(SheetBreakdownHelper.supportsBreakdown(type: "rod", subtype: nil) == false)
        #expect(SheetBreakdownHelper.supportsBreakdown(type: "frit", subtype: "coarse") == false)
        #expect(SheetBreakdownHelper.supportsBreakdown(type: "tube", subtype: nil) == false)
        #expect(SheetBreakdownHelper.supportsBreakdown(type: nil, subtype: nil) == false)
    }

    @Test("Sheet type is case insensitive")
    func sheetTypeCaseInsensitive() async throws {
        #expect(SheetBreakdownHelper.supportsBreakdown(type: "SHEET", subtype: "full") == true)
        #expect(SheetBreakdownHelper.supportsBreakdown(type: "Sheet", subtype: "full") == true)
    }

    @Test("Sheet with nil subtype supports breakdown (defaults to full)")
    func sheetNilSubtypeSupportsBreakdown() async throws {
        #expect(SheetBreakdownHelper.supportsBreakdown(type: "sheet", subtype: nil) == true)
    }

    // MARK: - Display Names Tests

    @Test("Display names are defined for all sizes")
    func displayNamesDefinedForAllSizes() async throws {
        for size in SheetBreakdownHelper.sizeOrder {
            let displayName = SheetBreakdownHelper.displayNames[size]
            #expect(displayName != nil, "Missing display name for \(size)")
            #expect(!displayName!.isEmpty, "Empty display name for \(size)")
        }
    }

    @Test("Display names are human readable")
    func displayNamesAreHumanReadable() async throws {
        #expect(SheetBreakdownHelper.displayNames["full"] == "Full Sheet")
        #expect(SheetBreakdownHelper.displayNames["half"] == "Half Sheet")
        #expect(SheetBreakdownHelper.displayNames["12x12"] == "12×12")
        #expect(SheetBreakdownHelper.displayNames["10x10"] == "10×10")
        #expect(SheetBreakdownHelper.displayNames["4x4"] == "4×4")
        #expect(SheetBreakdownHelper.displayNames["other"] == "Other")
    }
}

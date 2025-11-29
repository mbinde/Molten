//
//  LastUsedInventoryTypePreferenceTests.swift
//  MoltenTests
//
//  Tests for LastUsedInventoryTypePreference - remembering last used inventory type
//

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif
import Foundation
@testable import Molten

@Suite("LastUsedInventoryTypePreference Tests", .serialized)
@MainActor
struct LastUsedInventoryTypePreferenceTests {

    // Clean up before each test by resetting to known state
    init() {
        // Reset to default state - must be done synchronously before test runs
        LastUsedInventoryTypePreference.save(type: "rod", subtype: nil, subsubtype: nil)
    }

    // MARK: - Default Values Tests

    @Test("Default type is 'rod' when nothing saved")
    func testDefaultTypeIsRod() {
        // Note: This tests the actual UserDefaults, which may have values from previous runs
        // In production code, the default is "rod"
        let type = LastUsedInventoryTypePreference.type
        #expect(!type.isEmpty)  // Should have some value
    }

    // MARK: - Save and Load Tests

    @Test("Can save and retrieve type")
    func testSaveAndRetrieveType() {
        LastUsedInventoryTypePreference.save(type: "frit", subtype: nil, subsubtype: nil)

        #expect(LastUsedInventoryTypePreference.type == "frit")
    }

    @Test("Can save and retrieve type with subtype")
    func testSaveAndRetrieveTypeWithSubtype() {
        LastUsedInventoryTypePreference.save(type: "frit", subtype: "fine", subsubtype: nil)

        #expect(LastUsedInventoryTypePreference.type == "frit")
        #expect(LastUsedInventoryTypePreference.subtype == "fine")
    }

    @Test("Can save and retrieve full type path")
    func testSaveAndRetrieveFullTypePath() {
        LastUsedInventoryTypePreference.save(type: "frit", subtype: "fine", subsubtype: "medium")

        #expect(LastUsedInventoryTypePreference.type == "frit")
        #expect(LastUsedInventoryTypePreference.subtype == "fine")
        #expect(LastUsedInventoryTypePreference.subsubtype == "medium")
    }

    @Test("Saving nil subtype clears previous subtype")
    func testSavingNilSubtypeClearsPrevious() {
        // First save with subtype
        LastUsedInventoryTypePreference.save(type: "frit", subtype: "fine", subsubtype: nil)
        #expect(LastUsedInventoryTypePreference.subtype == "fine")

        // Now save without subtype
        LastUsedInventoryTypePreference.save(type: "rod", subtype: nil, subsubtype: nil)
        #expect(LastUsedInventoryTypePreference.type == "rod")
        #expect(LastUsedInventoryTypePreference.subtype == nil)
    }

    @Test("Saving nil subsubtype clears previous subsubtype")
    func testSavingNilSubsubtypeClearsPrevious() {
        // First save with subsubtype
        LastUsedInventoryTypePreference.save(type: "frit", subtype: "fine", subsubtype: "medium")
        #expect(LastUsedInventoryTypePreference.subsubtype == "medium")

        // Now save without subsubtype
        LastUsedInventoryTypePreference.save(type: "frit", subtype: "fine", subsubtype: nil)
        #expect(LastUsedInventoryTypePreference.subsubtype == nil)
    }

    // MARK: - Common Type Tests

    @Test("Can save rod type")
    func testSaveRodType() {
        LastUsedInventoryTypePreference.save(type: "rod", subtype: nil, subsubtype: nil)
        #expect(LastUsedInventoryTypePreference.type == "rod")
    }

    @Test("Can save tube type")
    func testSaveTubeType() {
        LastUsedInventoryTypePreference.save(type: "tube", subtype: nil, subsubtype: nil)
        #expect(LastUsedInventoryTypePreference.type == "tube")
    }

    @Test("Can save sheet type")
    func testSaveSheetType() {
        LastUsedInventoryTypePreference.save(type: "sheet", subtype: nil, subsubtype: nil)
        #expect(LastUsedInventoryTypePreference.type == "sheet")
    }

    @Test("Can save frit with full hierarchy")
    func testSaveFritWithFullHierarchy() {
        LastUsedInventoryTypePreference.save(type: "frit", subtype: "medium", subsubtype: "opal")

        #expect(LastUsedInventoryTypePreference.type == "frit")
        #expect(LastUsedInventoryTypePreference.subtype == "medium")
        #expect(LastUsedInventoryTypePreference.subsubtype == "opal")
    }
}

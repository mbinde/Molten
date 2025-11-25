//
//  CoatingItemTypeSystemTests.swift
//  MoltenTests
//
//  Tests for CoatingItemTypeSystem (powder, flakes types for coatings)
//

import Testing
import Foundation
@testable import Molten

@Suite("CoatingItemTypeSystem Tests")
@MainActor
struct CoatingItemTypeSystemTests {

    // MARK: - Type Definition Tests

    @Test("Powder type has correct properties")
    func testPowderTypeProperties() {
        let powder = CoatingItemTypeSystem.powder

        #expect(powder.name == "powder")
        #expect(powder.displayName == "Powder")
        #expect(powder.subtypes.isEmpty)
        #expect(powder.dimensionFields.isEmpty)
    }

    @Test("Flakes type has correct properties")
    func testFlakesTypeProperties() {
        let flakes = CoatingItemTypeSystem.flakes

        #expect(flakes.name == "flakes")
        #expect(flakes.displayName == "Flakes")
        #expect(flakes.subtypes.isEmpty)
        #expect(flakes.dimensionFields.isEmpty)
    }

    // MARK: - Type Registry Tests

    @Test("All types are registered")
    func testAllTypesRegistered() {
        let allTypes = CoatingItemTypeSystem.allTypes

        #expect(allTypes.count == 2)
        #expect(allTypes.contains { $0.name == "powder" })
        #expect(allTypes.contains { $0.name == "flakes" })
    }

    @Test("All type names are available")
    func testAllTypeNames() {
        let typeNames = CoatingItemTypeSystem.allTypeNames

        #expect(typeNames.count == 2)
        #expect(typeNames.contains("powder"))
        #expect(typeNames.contains("flakes"))
    }

    @Test("All display names are available")
    func testAllDisplayNames() {
        let displayNames = CoatingItemTypeSystem.allTypeDisplayNames

        #expect(displayNames.count == 2)
        #expect(displayNames.contains("Powder"))
        #expect(displayNames.contains("Flakes"))
    }

    // MARK: - Lookup Tests

    @Test("Can lookup type by name")
    func testGetTypeByName() {
        let powder = CoatingItemTypeSystem.getType(named: "powder")
        let flakes = CoatingItemTypeSystem.getType(named: "flakes")

        #expect(powder?.name == "powder")
        #expect(flakes?.name == "flakes")
    }

    @Test("Lookup is case-insensitive")
    func testLookupCaseInsensitive() {
        let powder = CoatingItemTypeSystem.getType(named: "POWDER")
        let flakes = CoatingItemTypeSystem.getType(named: "Flakes")

        #expect(powder?.name == "powder")
        #expect(flakes?.name == "flakes")
    }

    @Test("Invalid type returns nil")
    func testInvalidTypeReturnsNil() {
        let invalid = CoatingItemTypeSystem.getType(named: "rod")
        let empty = CoatingItemTypeSystem.getType(named: "")

        #expect(invalid == nil)
        #expect(empty == nil)
    }

    // MARK: - Default Type Tests

    @Test("Default type is powder")
    func testDefaultTypeIsPowder() {
        #expect(CoatingItemTypeSystem.defaultType == "powder")
    }

    // MARK: - Weight-Based Tests

    @Test("All coating types are weight-based")
    func testAllTypesAreWeightBased() {
        #expect(CoatingItemTypeSystem.isWeightBasedType("powder") == true)
        #expect(CoatingItemTypeSystem.isWeightBasedType("flakes") == true)
    }

    @Test("Even unknown types are treated as weight-based for coatings")
    func testUnknownTypesAreWeightBased() {
        // CoatingItemTypeSystem returns true for all types since all coatings are weight-based
        #expect(CoatingItemTypeSystem.isWeightBasedType("unknown") == true)
    }
}

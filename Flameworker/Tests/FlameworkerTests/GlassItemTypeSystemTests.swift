//
//  GlassItemTypeSystemTests.swift
//  FlameworkerTests
//
//  Comprehensive tests for the glass item type system
//

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import Foundation
@testable import Flameworker

@Suite("Glass Item Type System Tests")
struct GlassItemTypeSystemTests {

    // MARK: - Type Definition Tests

    @Test("All 9 types are registered in the system")
    func testAllTypesRegistered() {
        let allTypes = GlassItemTypeSystem.allTypes

        #expect(allTypes.count == 9, "Should have exactly 9 glass item types")

        let typeNames = Set(allTypes.map { $0.name })
        let expectedTypes: Set<String> = ["rod", "stringer", "sheet", "frit", "tube", "powder", "scrap", "murrini", "enamel"]

        #expect(typeNames == expectedTypes, "Should have all expected type names")
    }

    @Test("Each type has correct display name")
    func testTypeDisplayNames() {
        #expect(GlassItemTypeSystem.rod.displayName == "Rod")
        #expect(GlassItemTypeSystem.stringer.displayName == "Stringer")
        #expect(GlassItemTypeSystem.sheet.displayName == "Sheet")
        #expect(GlassItemTypeSystem.frit.displayName == "Frit")
        #expect(GlassItemTypeSystem.tube.displayName == "Tube")
        #expect(GlassItemTypeSystem.powder.displayName == "Powder")
        #expect(GlassItemTypeSystem.scrap.displayName == "Scrap")
        #expect(GlassItemTypeSystem.murrini.displayName == "Murrini")
        #expect(GlassItemTypeSystem.enamel.displayName == "Enamel")
    }

    @Test("Rod type has correct subtypes")
    func testRodSubtypes() {
        let rod = GlassItemTypeSystem.rod

        #expect(rod.subtypes == ["standard", "cane", "pull"])
        #expect(rod.hasSubtypes == true)
    }

    @Test("Stringer type has correct subtypes")
    func testStringerSubtypes() {
        let stringer = GlassItemTypeSystem.stringer

        #expect(stringer.subtypes == ["fine", "medium", "thick"])
        #expect(stringer.hasSubtypes == true)
    }

    @Test("Sheet type has correct subtypes")
    func testSheetSubtypes() {
        let sheet = GlassItemTypeSystem.sheet

        #expect(sheet.subtypes == ["clear", "transparent", "opaque", "opalescent"])
        #expect(sheet.hasSubtypes == true)
    }

    @Test("Scrap type has no subtypes")
    func testScrapHasNoSubtypes() {
        let scrap = GlassItemTypeSystem.scrap

        #expect(scrap.subtypes.isEmpty)
        #expect(scrap.hasSubtypes == false)
    }

    @Test("Rod type has correct dimension fields")
    func testRodDimensionFields() {
        let rod = GlassItemTypeSystem.rod

        #expect(rod.dimensionFields.count == 2)
        #expect(rod.hasDimensions == true)

        let diameterField = rod.dimensionFields.first { $0.name == "diameter" }
        #expect(diameterField != nil)
        #expect(diameterField?.displayName == "Diameter")
        #expect(diameterField?.unit == "mm")
        #expect(diameterField?.isRequired == false)

        let lengthField = rod.dimensionFields.first { $0.name == "length" }
        #expect(lengthField != nil)
        #expect(lengthField?.displayName == "Length")
        #expect(lengthField?.unit == "cm")
    }

    @Test("Tube type has correct dimension fields")
    func testTubeDimensionFields() {
        let tube = GlassItemTypeSystem.tube

        #expect(tube.dimensionFields.count == 3)

        let outerDiameter = tube.dimensionFields.first { $0.name == "outer_diameter" }
        #expect(outerDiameter?.displayName == "Outer Diameter")
        #expect(outerDiameter?.unit == "mm")

        let innerDiameter = tube.dimensionFields.first { $0.name == "inner_diameter" }
        #expect(innerDiameter?.displayName == "Inner Diameter")
        #expect(innerDiameter?.unit == "mm")

        let length = tube.dimensionFields.first { $0.name == "length" }
        #expect(length?.displayName == "Length")
        #expect(length?.unit == "cm")
    }

    @Test("Scrap type has no dimension fields")
    func testScrapHasNoDimensions() {
        let scrap = GlassItemTypeSystem.scrap

        #expect(scrap.dimensionFields.isEmpty)
        #expect(scrap.hasDimensions == false)
    }

    // MARK: - Type Lookup Tests

    @Test("getType(named:) returns correct type")
    func testGetTypeByName() {
        let rod = GlassItemTypeSystem.getType(named: "rod")
        #expect(rod != nil)
        #expect(rod?.name == "rod")
        #expect(rod?.displayName == "Rod")

        let stringer = GlassItemTypeSystem.getType(named: "stringer")
        #expect(stringer != nil)
        #expect(stringer?.name == "stringer")
    }

    @Test("getType(named:) is case-insensitive")
    func testGetTypeCaseInsensitive() {
        let rodLower = GlassItemTypeSystem.getType(named: "rod")
        let rodUpper = GlassItemTypeSystem.getType(named: "ROD")
        let rodMixed = GlassItemTypeSystem.getType(named: "RoD")

        #expect(rodLower != nil)
        #expect(rodUpper != nil)
        #expect(rodMixed != nil)
        #expect(rodLower == rodUpper)
        #expect(rodUpper == rodMixed)
    }

    @Test("getType(named:) returns nil for invalid type")
    func testGetTypeInvalidName() {
        let invalid = GlassItemTypeSystem.getType(named: "nonexistent")
        #expect(invalid == nil)
    }

    @Test("allTypeNames returns all type names")
    func testAllTypeNames() {
        let names = GlassItemTypeSystem.allTypeNames

        #expect(names.count == 9)
        #expect(names.contains("rod"))
        #expect(names.contains("stringer"))
        #expect(names.contains("sheet"))
        #expect(names.contains("frit"))
        #expect(names.contains("tube"))
        #expect(names.contains("powder"))
        #expect(names.contains("scrap"))
        #expect(names.contains("murrini"))
        #expect(names.contains("enamel"))
    }

    @Test("allTypeDisplayNames returns display names")
    func testAllTypeDisplayNames() {
        let displayNames = GlassItemTypeSystem.allTypeDisplayNames

        #expect(displayNames.count == 9)
        #expect(displayNames.contains("Rod"))
        #expect(displayNames.contains("Stringer"))
        #expect(displayNames.contains("Sheet"))
    }

    @Test("getSubtypes(for:) returns correct subtypes")
    func testGetSubtypes() {
        let rodSubtypes = GlassItemTypeSystem.getSubtypes(for: "rod")
        #expect(rodSubtypes == ["standard", "cane", "pull"])

        let stringerSubtypes = GlassItemTypeSystem.getSubtypes(for: "stringer")
        #expect(stringerSubtypes == ["fine", "medium", "thick"])

        let scrapSubtypes = GlassItemTypeSystem.getSubtypes(for: "scrap")
        #expect(scrapSubtypes.isEmpty)
    }

    @Test("getSubtypes(for:) returns empty array for invalid type")
    func testGetSubtypesInvalidType() {
        let subtypes = GlassItemTypeSystem.getSubtypes(for: "nonexistent")
        #expect(subtypes.isEmpty)
    }

    @Test("getDimensionFields(for:) returns correct fields")
    func testGetDimensionFields() {
        let rodFields = GlassItemTypeSystem.getDimensionFields(for: "rod")
        #expect(rodFields.count == 2)

        let tubeFields = GlassItemTypeSystem.getDimensionFields(for: "tube")
        #expect(tubeFields.count == 3)

        let scrapFields = GlassItemTypeSystem.getDimensionFields(for: "scrap")
        #expect(scrapFields.isEmpty)
    }

    @Test("hasSubtypes returns correct value")
    func testHasSubtypes() {
        #expect(GlassItemTypeSystem.hasSubtypes("rod") == true)
        #expect(GlassItemTypeSystem.hasSubtypes("stringer") == true)
        #expect(GlassItemTypeSystem.hasSubtypes("scrap") == false)
        #expect(GlassItemTypeSystem.hasSubtypes("nonexistent") == false)
    }

    @Test("hasDimensions returns correct value")
    func testHasDimensions() {
        #expect(GlassItemTypeSystem.hasDimensions("rod") == true)
        #expect(GlassItemTypeSystem.hasDimensions("tube") == true)
        #expect(GlassItemTypeSystem.hasDimensions("scrap") == false)
        #expect(GlassItemTypeSystem.hasDimensions("enamel") == false)
        #expect(GlassItemTypeSystem.hasDimensions("nonexistent") == false)
    }

    // MARK: - Validation Tests

    @Test("isValidType validates type names correctly")
    func testIsValidType() {
        #expect(GlassItemTypeSystem.isValidType("rod") == true)
        #expect(GlassItemTypeSystem.isValidType("ROD") == true)
        #expect(GlassItemTypeSystem.isValidType("Rod") == true)
        #expect(GlassItemTypeSystem.isValidType("stringer") == true)
        #expect(GlassItemTypeSystem.isValidType("nonexistent") == false)
        #expect(GlassItemTypeSystem.isValidType("") == false)
    }

    @Test("isValidSubtype validates subtypes correctly")
    func testIsValidSubtype() {
        #expect(GlassItemTypeSystem.isValidSubtype("standard", for: "rod") == true)
        #expect(GlassItemTypeSystem.isValidSubtype("cane", for: "rod") == true)
        #expect(GlassItemTypeSystem.isValidSubtype("pull", for: "rod") == true)
        #expect(GlassItemTypeSystem.isValidSubtype("invalid", for: "rod") == false)

        #expect(GlassItemTypeSystem.isValidSubtype("fine", for: "stringer") == true)
        #expect(GlassItemTypeSystem.isValidSubtype("medium", for: "stringer") == true)
        #expect(GlassItemTypeSystem.isValidSubtype("thick", for: "stringer") == true)

        // Invalid type
        #expect(GlassItemTypeSystem.isValidSubtype("standard", for: "nonexistent") == false)
    }

    @Test("isValidSubtype is case-insensitive for subtype")
    func testIsValidSubtypeCaseInsensitive() {
        #expect(GlassItemTypeSystem.isValidSubtype("STANDARD", for: "rod") == true)
        #expect(GlassItemTypeSystem.isValidSubtype("Standard", for: "rod") == true)
        #expect(GlassItemTypeSystem.isValidSubtype("sTaNdArD", for: "rod") == true)
    }

    @Test("validateDimensions catches missing required dimensions")
    func testValidateDimensionsMissingRequired() {
        // Note: Currently no dimensions are marked as required in the system
        // This test verifies the validation logic works when required fields are present

        let emptyDimensions: [String: Double] = [:]
        let errors = GlassItemTypeSystem.validateDimensions(emptyDimensions, for: "rod")

        // Should not have errors because no dimensions are required
        #expect(errors.isEmpty)
    }

    @Test("validateDimensions catches negative values")
    func testValidateDimensionsNegativeValues() {
        let negativeDimensions: [String: Double] = [
            "diameter": -5.0,
            "length": 10.0
        ]

        let errors = GlassItemTypeSystem.validateDimensions(negativeDimensions, for: "rod")

        #expect(errors.count == 1)
        #expect(errors.first?.contains("diameter") == true)
        #expect(errors.first?.contains("cannot be negative") == true)
    }

    @Test("validateDimensions catches multiple negative values")
    func testValidateDimensionsMultipleNegative() {
        let negativeDimensions: [String: Double] = [
            "diameter": -5.0,
            "length": -10.0
        ]

        let errors = GlassItemTypeSystem.validateDimensions(negativeDimensions, for: "rod")

        #expect(errors.count == 2)
    }

    @Test("validateDimensions accepts valid dimensions")
    func testValidateDimensionsValid() {
        let validDimensions: [String: Double] = [
            "diameter": 5.0,
            "length": 30.0
        ]

        let errors = GlassItemTypeSystem.validateDimensions(validDimensions, for: "rod")

        #expect(errors.isEmpty)
    }

    @Test("validateDimensions accepts zero values")
    func testValidateDimensionsZero() {
        let zeroDimensions: [String: Double] = [
            "diameter": 0.0,
            "length": 0.0
        ]

        let errors = GlassItemTypeSystem.validateDimensions(zeroDimensions, for: "rod")

        #expect(errors.isEmpty)
    }

    @Test("validateDimensions returns error for invalid type")
    func testValidateDimensionsInvalidType() {
        let dimensions: [String: Double] = ["diameter": 5.0]

        let errors = GlassItemTypeSystem.validateDimensions(dimensions, for: "nonexistent")

        #expect(errors.count == 1)
        #expect(errors.first?.contains("Invalid type") == true)
    }

    // MARK: - Display Formatting Tests

    @Test("formatDimension formats whole numbers without decimals")
    func testFormatDimensionWholeNumber() {
        let field = DimensionField(name: "diameter", displayName: "Diameter", unit: "mm")
        let formatted = GlassItemTypeSystem.formatDimension(value: 5.0, field: field)

        #expect(formatted == "5 mm")
    }

    @Test("formatDimension formats decimals with one place")
    func testFormatDimensionDecimal() {
        let field = DimensionField(name: "diameter", displayName: "Diameter", unit: "mm")
        let formatted = GlassItemTypeSystem.formatDimension(value: 5.5, field: field)

        #expect(formatted == "5.5 mm")
    }

    @Test("formatDimension includes unit")
    func testFormatDimensionUnit() {
        let field = DimensionField(name: "length", displayName: "Length", unit: "cm")
        let formatted = GlassItemTypeSystem.formatDimension(value: 30.0, field: field)

        #expect(formatted == "30 cm")
    }

    @Test("formatDimensions creates proper display string")
    func testFormatDimensions() {
        let dimensions: [String: Double] = [
            "diameter": 5.0,
            "length": 30.0
        ]

        let formatted = GlassItemTypeSystem.formatDimensions(dimensions, for: "rod")

        #expect(formatted.contains("Diameter: 5 mm"))
        #expect(formatted.contains("Length: 30 cm"))
    }

    @Test("formatDimensions returns empty string for invalid type")
    func testFormatDimensionsInvalidType() {
        let dimensions: [String: Double] = ["diameter": 5.0]
        let formatted = GlassItemTypeSystem.formatDimensions(dimensions, for: "nonexistent")

        #expect(formatted.isEmpty)
    }

    @Test("formatDimensions handles empty dimensions")
    func testFormatDimensionsEmpty() {
        let dimensions: [String: Double] = [:]
        let formatted = GlassItemTypeSystem.formatDimensions(dimensions, for: "rod")

        #expect(formatted.isEmpty)
    }

    @Test("formatDimensions only shows defined dimensions")
    func testFormatDimensionsPartial() {
        let dimensions: [String: Double] = [
            "diameter": 5.0
            // length is missing
        ]

        let formatted = GlassItemTypeSystem.formatDimensions(dimensions, for: "rod")

        #expect(formatted.contains("Diameter: 5 mm"))
        #expect(!formatted.contains("Length"))
    }

    @Test("shortDescription shows type only")
    func testShortDescriptionTypeOnly() {
        let description = GlassItemTypeSystem.shortDescription(type: "rod", subtype: nil, dimensions: nil)

        #expect(description == "Rod")
    }

    @Test("shortDescription shows type and subtype")
    func testShortDescriptionWithSubtype() {
        let description = GlassItemTypeSystem.shortDescription(type: "rod", subtype: "standard", dimensions: nil)

        #expect(description == "Rod (Standard)")
    }

    @Test("shortDescription shows type, subtype and first dimension")
    func testShortDescriptionWithDimensions() {
        let dimensions: [String: Double] = [
            "diameter": 5.0,
            "length": 30.0
        ]

        let description = GlassItemTypeSystem.shortDescription(type: "rod", subtype: "standard", dimensions: dimensions)

        #expect(description.contains("Rod"))
        #expect(description.contains("(Standard)"))
        #expect(description.contains("5 mm")) // First dimension is diameter
    }

    @Test("shortDescription handles empty subtype string")
    func testShortDescriptionEmptySubtype() {
        let description = GlassItemTypeSystem.shortDescription(type: "rod", subtype: "", dimensions: nil)

        #expect(description == "Rod")
    }

    @Test("shortDescription handles empty dimensions dictionary")
    func testShortDescriptionEmptyDimensions() {
        let dimensions: [String: Double] = [:]
        let description = GlassItemTypeSystem.shortDescription(type: "rod", subtype: "standard", dimensions: dimensions)

        #expect(description == "Rod (Standard)")
    }

    // MARK: - Edge Cases

    @Test("Type with no subtypes works correctly")
    func testTypeWithNoSubtypes() {
        let scrap = GlassItemTypeSystem.getType(named: "scrap")

        #expect(scrap != nil)
        #expect(scrap?.subtypes.isEmpty == true)
        #expect(scrap?.hasSubtypes == false)

        let subtypes = GlassItemTypeSystem.getSubtypes(for: "scrap")
        #expect(subtypes.isEmpty)
    }

    @Test("Type with no dimensions works correctly")
    func testTypeWithNoDimensions() {
        let scrap = GlassItemTypeSystem.getType(named: "scrap")

        #expect(scrap != nil)
        #expect(scrap?.dimensionFields.isEmpty == true)
        #expect(scrap?.hasDimensions == false)

        let fields = GlassItemTypeSystem.getDimensionFields(for: "scrap")
        #expect(fields.isEmpty)
    }

    @Test("DimensionField has default placeholder")
    func testDimensionFieldDefaultPlaceholder() {
        let field = DimensionField(name: "diameter", displayName: "Diameter", unit: "mm")

        #expect(field.placeholder == "Enter diameter")
    }

    @Test("DimensionField accepts custom placeholder")
    func testDimensionFieldCustomPlaceholder() {
        let field = DimensionField(
            name: "diameter",
            displayName: "Diameter",
            unit: "mm",
            placeholder: "Custom placeholder"
        )

        #expect(field.placeholder == "Custom placeholder")
    }

    @Test("GlassItemType Equatable works correctly")
    func testGlassItemTypeEquatable() {
        let type1 = GlassItemTypeSystem.rod
        let type2 = GlassItemTypeSystem.rod
        let type3 = GlassItemTypeSystem.stringer

        #expect(type1 == type2)
        #expect(type1 != type3)
    }

    @Test("DimensionField Equatable works correctly")
    func testDimensionFieldEquatable() {
        let field1 = DimensionField(name: "diameter", displayName: "Diameter", unit: "mm")
        let field2 = DimensionField(name: "diameter", displayName: "Diameter", unit: "mm")
        let field3 = DimensionField(name: "length", displayName: "Length", unit: "cm")

        #expect(field1 == field2)
        #expect(field1 != field3)
    }

    @Test("typesByName dictionary contains all types")
    func testTypesByNameDictionary() {
        let typesByName = GlassItemTypeSystem.typesByName

        #expect(typesByName.count == 9)
        #expect(typesByName["rod"] != nil)
        #expect(typesByName["stringer"] != nil)
        #expect(typesByName["sheet"] != nil)
        #expect(typesByName["frit"] != nil)
        #expect(typesByName["tube"] != nil)
        #expect(typesByName["powder"] != nil)
        #expect(typesByName["scrap"] != nil)
        #expect(typesByName["murrini"] != nil)
        #expect(typesByName["enamel"] != nil)
    }

    @Test("getSubsubtypes returns empty for types without subsubtypes")
    func testGetSubsubtypesEmpty() {
        // Currently no types have subsubtypes defined
        let subsubtypes = GlassItemTypeSystem.getSubsubtypes(for: "rod", subtype: "standard")
        #expect(subsubtypes.isEmpty)
    }

    @Test("isValidSubsubtype returns false for undefined subsubtypes")
    func testIsValidSubsubtypeUndefined() {
        // Currently no types have subsubtypes defined
        let isValid = GlassItemTypeSystem.isValidSubsubtype("anything", for: "rod", subtype: "standard")
        #expect(isValid == false)
    }
}

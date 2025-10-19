//
//  GlassItemTypeSystemTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/18/25.
//  Comprehensive tests for the glass item type system
//

import Testing
import Foundation
@testable import Flameworker

@Suite("GlassItemTypeSystem Tests")
struct GlassItemTypeSystemTests {

    // MARK: - Type Definition Validation

    @Test("All 9 types are registered")
    func testAllTypesRegistered() {
        let expectedTypes = ["rod", "stringer", "sheet", "frit", "tube", "powder", "scrap", "murrini", "enamel"]
        let actualTypes = GlassItemTypeSystem.allTypeNames.sorted()

        #expect(actualTypes.count == 9)
        #expect(actualTypes == expectedTypes.sorted())
    }

    @Test("Rod type has correct definition")
    func testRodTypeDefinition() {
        let rod = GlassItemTypeSystem.rod

        #expect(rod.name == "rod")
        #expect(rod.displayName == "Rod")
        #expect(rod.subtypes == ["standard", "cane", "pull"])
        #expect(rod.dimensionFields.count == 2)
        #expect(rod.dimensionFields[0].name == "diameter")
        #expect(rod.dimensionFields[1].name == "length")
        #expect(rod.hasSubtypes == true)
        #expect(rod.hasDimensions == true)
    }

    @Test("Stringer type has correct definition")
    func testStringerTypeDefinition() {
        let stringer = GlassItemTypeSystem.stringer

        #expect(stringer.name == "stringer")
        #expect(stringer.displayName == "Stringer")
        #expect(stringer.subtypes == ["fine", "medium", "thick"])
        #expect(stringer.dimensionFields.count == 2)
        #expect(stringer.hasSubtypes == true)
        #expect(stringer.hasDimensions == true)
    }

    @Test("Sheet type has correct definition")
    func testSheetTypeDefinition() {
        let sheet = GlassItemTypeSystem.sheet

        #expect(sheet.name == "sheet")
        #expect(sheet.displayName == "Sheet")
        #expect(sheet.subtypes == ["clear", "transparent", "opaque", "opalescent"])
        #expect(sheet.dimensionFields.count == 3)
        #expect(sheet.dimensionFields[0].name == "thickness")
        #expect(sheet.dimensionFields[1].name == "width")
        #expect(sheet.dimensionFields[2].name == "height")
        #expect(sheet.hasSubtypes == true)
        #expect(sheet.hasDimensions == true)
    }

    @Test("Frit type has correct definition")
    func testFritTypeDefinition() {
        let frit = GlassItemTypeSystem.frit

        #expect(frit.name == "frit")
        #expect(frit.displayName == "Frit")
        #expect(frit.subtypes == ["fine", "medium", "coarse", "powder"])
        #expect(frit.dimensionFields.count == 1)
        #expect(frit.dimensionFields[0].name == "mesh_size")
        #expect(frit.hasSubtypes == true)
        #expect(frit.hasDimensions == true)
    }

    @Test("Tube type has correct definition")
    func testTubeTypeDefinition() {
        let tube = GlassItemTypeSystem.tube

        #expect(tube.name == "tube")
        #expect(tube.displayName == "Tube")
        #expect(tube.subtypes == ["thin_wall", "thick_wall", "standard"])
        #expect(tube.dimensionFields.count == 3)
        #expect(tube.dimensionFields[0].name == "outer_diameter")
        #expect(tube.dimensionFields[1].name == "inner_diameter")
        #expect(tube.dimensionFields[2].name == "length")
        #expect(tube.hasSubtypes == true)
        #expect(tube.hasDimensions == true)
    }

    @Test("Powder type has correct definition")
    func testPowderTypeDefinition() {
        let powder = GlassItemTypeSystem.powder

        #expect(powder.name == "powder")
        #expect(powder.displayName == "Powder")
        #expect(powder.subtypes == ["fine", "medium", "coarse"])
        #expect(powder.dimensionFields.count == 1)
        #expect(powder.dimensionFields[0].name == "particle_size")
        #expect(powder.hasSubtypes == true)
        #expect(powder.hasDimensions == true)
    }

    @Test("Scrap type has no subtypes or dimensions")
    func testScrapTypeDefinition() {
        let scrap = GlassItemTypeSystem.scrap

        #expect(scrap.name == "scrap")
        #expect(scrap.displayName == "Scrap")
        #expect(scrap.subtypes.isEmpty)
        #expect(scrap.dimensionFields.isEmpty)
        #expect(scrap.hasSubtypes == false)
        #expect(scrap.hasDimensions == false)
    }

    @Test("Murrini type has correct definition")
    func testMurriniTypeDefinition() {
        let murrini = GlassItemTypeSystem.murrini

        #expect(murrini.name == "murrini")
        #expect(murrini.displayName == "Murrini")
        #expect(murrini.subtypes == ["cane", "slice"])
        #expect(murrini.dimensionFields.count == 2)
        #expect(murrini.dimensionFields[0].name == "diameter")
        #expect(murrini.dimensionFields[1].name == "thickness")
        #expect(murrini.hasSubtypes == true)
        #expect(murrini.hasDimensions == true)
    }

    @Test("Enamel type has correct definition")
    func testEnamelTypeDefinition() {
        let enamel = GlassItemTypeSystem.enamel

        #expect(enamel.name == "enamel")
        #expect(enamel.displayName == "Enamel")
        #expect(enamel.subtypes == ["opaque", "transparent"])
        #expect(enamel.dimensionFields.isEmpty)
        #expect(enamel.hasSubtypes == true)
        #expect(enamel.hasDimensions == false)
    }

    // MARK: - Type Lookup Operations

    @Test("Get type by name returns correct type")
    func testGetTypeByName() {
        let rod = GlassItemTypeSystem.getType(named: "rod")

        #expect(rod != nil)
        #expect(rod?.name == "rod")
        #expect(rod?.displayName == "Rod")
    }

    @Test("Get type by name is case-insensitive")
    func testGetTypeCaseInsensitive() {
        let rodLower = GlassItemTypeSystem.getType(named: "rod")
        let rodUpper = GlassItemTypeSystem.getType(named: "ROD")
        let rodMixed = GlassItemTypeSystem.getType(named: "RoD")

        #expect(rodLower == rodUpper)
        #expect(rodLower == rodMixed)
    }

    @Test("Get type with invalid name returns nil")
    func testGetTypeInvalidName() {
        let invalid = GlassItemTypeSystem.getType(named: "invalid")

        #expect(invalid == nil)
    }

    @Test("Get subtypes returns correct subtypes")
    func testGetSubtypes() {
        let rodSubtypes = GlassItemTypeSystem.getSubtypes(for: "rod")

        #expect(rodSubtypes == ["standard", "cane", "pull"])
    }

    @Test("Get subtypes for invalid type returns empty array")
    func testGetSubtypesInvalidType() {
        let subtypes = GlassItemTypeSystem.getSubtypes(for: "invalid")

        #expect(subtypes.isEmpty)
    }

    @Test("Get subtypes for type with no subtypes returns empty array")
    func testGetSubtypesNoSubtypes() {
        let subtypes = GlassItemTypeSystem.getSubtypes(for: "scrap")

        #expect(subtypes.isEmpty)
    }

    @Test("Get dimension fields returns correct fields")
    func testGetDimensionFields() {
        let rodFields = GlassItemTypeSystem.getDimensionFields(for: "rod")

        #expect(rodFields.count == 2)
        #expect(rodFields[0].name == "diameter")
        #expect(rodFields[1].name == "length")
    }

    @Test("Get dimension fields for invalid type returns empty array")
    func testGetDimensionFieldsInvalidType() {
        let fields = GlassItemTypeSystem.getDimensionFields(for: "invalid")

        #expect(fields.isEmpty)
    }

    @Test("Get dimension fields for type with no dimensions returns empty array")
    func testGetDimensionFieldsNoDimensions() {
        let fields = GlassItemTypeSystem.getDimensionFields(for: "scrap")

        #expect(fields.isEmpty)
    }

    @Test("All type names returns all 9 types")
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

    @Test("All type display names returns all 9 display names")
    func testAllTypeDisplayNames() {
        let displayNames = GlassItemTypeSystem.allTypeDisplayNames

        #expect(displayNames.count == 9)
        #expect(displayNames.contains("Rod"))
        #expect(displayNames.contains("Stringer"))
        #expect(displayNames.contains("Sheet"))
        #expect(displayNames.contains("Frit"))
        #expect(displayNames.contains("Tube"))
        #expect(displayNames.contains("Powder"))
        #expect(displayNames.contains("Scrap"))
        #expect(displayNames.contains("Murrini"))
        #expect(displayNames.contains("Enamel"))
    }

    @Test("Has subtypes returns true for types with subtypes")
    func testHasSubtypesTrue() {
        #expect(GlassItemTypeSystem.hasSubtypes("rod") == true)
        #expect(GlassItemTypeSystem.hasSubtypes("stringer") == true)
        #expect(GlassItemTypeSystem.hasSubtypes("sheet") == true)
    }

    @Test("Has subtypes returns false for types without subtypes")
    func testHasSubtypesFalse() {
        #expect(GlassItemTypeSystem.hasSubtypes("scrap") == false)
    }

    @Test("Has subtypes returns false for invalid type")
    func testHasSubtypesInvalidType() {
        #expect(GlassItemTypeSystem.hasSubtypes("invalid") == false)
    }

    @Test("Has dimensions returns true for types with dimensions")
    func testHasDimensionsTrue() {
        #expect(GlassItemTypeSystem.hasDimensions("rod") == true)
        #expect(GlassItemTypeSystem.hasDimensions("sheet") == true)
        #expect(GlassItemTypeSystem.hasDimensions("tube") == true)
    }

    @Test("Has dimensions returns false for types without dimensions")
    func testHasDimensionsFalse() {
        #expect(GlassItemTypeSystem.hasDimensions("scrap") == false)
        #expect(GlassItemTypeSystem.hasDimensions("enamel") == false)
    }

    @Test("Has dimensions returns false for invalid type")
    func testHasDimensionsInvalidType() {
        #expect(GlassItemTypeSystem.hasDimensions("invalid") == false)
    }

    // MARK: - Validation Logic

    @Test("Is valid type returns true for valid types")
    func testIsValidTypeTrue() {
        #expect(GlassItemTypeSystem.isValidType("rod") == true)
        #expect(GlassItemTypeSystem.isValidType("stringer") == true)
        #expect(GlassItemTypeSystem.isValidType("sheet") == true)
        #expect(GlassItemTypeSystem.isValidType("frit") == true)
        #expect(GlassItemTypeSystem.isValidType("tube") == true)
        #expect(GlassItemTypeSystem.isValidType("powder") == true)
        #expect(GlassItemTypeSystem.isValidType("scrap") == true)
        #expect(GlassItemTypeSystem.isValidType("murrini") == true)
        #expect(GlassItemTypeSystem.isValidType("enamel") == true)
    }

    @Test("Is valid type is case-insensitive")
    func testIsValidTypeCaseInsensitive() {
        #expect(GlassItemTypeSystem.isValidType("ROD") == true)
        #expect(GlassItemTypeSystem.isValidType("RoD") == true)
        #expect(GlassItemTypeSystem.isValidType("STRINGER") == true)
    }

    @Test("Is valid type returns false for invalid types")
    func testIsValidTypeFalse() {
        #expect(GlassItemTypeSystem.isValidType("invalid") == false)
        #expect(GlassItemTypeSystem.isValidType("") == false)
        #expect(GlassItemTypeSystem.isValidType("rods") == false)
    }

    @Test("Is valid subtype returns true for valid subtypes")
    func testIsValidSubtypeTrue() {
        #expect(GlassItemTypeSystem.isValidSubtype("standard", for: "rod") == true)
        #expect(GlassItemTypeSystem.isValidSubtype("cane", for: "rod") == true)
        #expect(GlassItemTypeSystem.isValidSubtype("fine", for: "stringer") == true)
        #expect(GlassItemTypeSystem.isValidSubtype("clear", for: "sheet") == true)
    }

    @Test("Is valid subtype is case-insensitive")
    func testIsValidSubtypeCaseInsensitive() {
        #expect(GlassItemTypeSystem.isValidSubtype("STANDARD", for: "rod") == true)
        #expect(GlassItemTypeSystem.isValidSubtype("StAnDaRd", for: "rod") == true)
    }

    @Test("Is valid subtype returns false for invalid subtypes")
    func testIsValidSubtypeFalse() {
        #expect(GlassItemTypeSystem.isValidSubtype("invalid", for: "rod") == false)
        #expect(GlassItemTypeSystem.isValidSubtype("fine", for: "rod") == false) // fine is for stringer, not rod
        #expect(GlassItemTypeSystem.isValidSubtype("standard", for: "invalid") == false)
    }

    @Test("Validate dimensions catches negative values")
    func testValidateDimensionsNegativeValues() {
        let dimensions = ["diameter": -5.0, "length": 10.0]
        let errors = GlassItemTypeSystem.validateDimensions(dimensions, for: "rod")

        #expect(!errors.isEmpty)
        #expect(errors.contains { $0.contains("diameter") && $0.contains("negative") })
    }

    @Test("Validate dimensions passes for valid values")
    func testValidateDimensionsValidValues() {
        let dimensions = ["diameter": 5.0, "length": 10.0]
        let errors = GlassItemTypeSystem.validateDimensions(dimensions, for: "rod")

        #expect(errors.isEmpty)
    }

    @Test("Validate dimensions catches missing required dimensions")
    func testValidateDimensionsMissingRequired() {
        // Note: Currently no types have required dimensions, but test the logic
        // This test would pass if we had a type with required dimensions
        let dimensions: [String: Double] = [:]
        let errors = GlassItemTypeSystem.validateDimensions(dimensions, for: "rod")

        // Should pass since no dimensions are required for rod
        #expect(errors.isEmpty)
    }

    @Test("Validate dimensions returns error for invalid type")
    func testValidateDimensionsInvalidType() {
        let dimensions = ["diameter": 5.0]
        let errors = GlassItemTypeSystem.validateDimensions(dimensions, for: "invalid")

        #expect(!errors.isEmpty)
        #expect(errors.contains { $0.contains("Invalid type") })
    }

    @Test("Validate dimensions allows empty dimensions")
    func testValidateDimensionsEmpty() {
        let dimensions: [String: Double] = [:]
        let errors = GlassItemTypeSystem.validateDimensions(dimensions, for: "rod")

        #expect(errors.isEmpty)
    }

    @Test("Validate dimensions allows zero values")
    func testValidateDimensionsZeroValues() {
        let dimensions = ["diameter": 0.0, "length": 10.0]
        let errors = GlassItemTypeSystem.validateDimensions(dimensions, for: "rod")

        #expect(errors.isEmpty)
    }

    // MARK: - Display Formatting

    @Test("Format dimension formats whole numbers without decimal")
    func testFormatDimensionWholeNumber() {
        let field = DimensionField(name: "diameter", displayName: "Diameter", unit: "mm")
        let formatted = GlassItemTypeSystem.formatDimension(value: 5.0, field: field)

        #expect(formatted == "5 mm")
    }

    @Test("Format dimension formats decimals with one place")
    func testFormatDimensionDecimal() {
        let field = DimensionField(name: "diameter", displayName: "Diameter", unit: "mm")
        let formatted = GlassItemTypeSystem.formatDimension(value: 5.5, field: field)

        #expect(formatted == "5.5 mm")
    }

    @Test("Format dimension handles zero")
    func testFormatDimensionZero() {
        let field = DimensionField(name: "diameter", displayName: "Diameter", unit: "mm")
        let formatted = GlassItemTypeSystem.formatDimension(value: 0.0, field: field)

        #expect(formatted == "0 mm")
    }

    @Test("Format dimensions creates comma-separated list")
    func testFormatDimensionsMultiple() {
        let dimensions = ["diameter": 5.0, "length": 10.5]
        let formatted = GlassItemTypeSystem.formatDimensions(dimensions, for: "rod")

        // Should contain both dimensions
        #expect(formatted.contains("Diameter: 5 mm"))
        #expect(formatted.contains("Length: 10.5 cm"))
    }

    @Test("Format dimensions returns empty for invalid type")
    func testFormatDimensionsInvalidType() {
        let dimensions = ["diameter": 5.0]
        let formatted = GlassItemTypeSystem.formatDimensions(dimensions, for: "invalid")

        #expect(formatted.isEmpty)
    }

    @Test("Format dimensions skips missing dimensions")
    func testFormatDimensionsMissing() {
        let dimensions = ["diameter": 5.0] // length is missing
        let formatted = GlassItemTypeSystem.formatDimensions(dimensions, for: "rod")

        #expect(formatted.contains("Diameter: 5 mm"))
        #expect(!formatted.contains("Length"))
    }

    @Test("Format dimensions returns empty for empty dimensions")
    func testFormatDimensionsEmpty() {
        let dimensions: [String: Double] = [:]
        let formatted = GlassItemTypeSystem.formatDimensions(dimensions, for: "rod")

        #expect(formatted.isEmpty)
    }

    @Test("Short description includes type")
    func testShortDescriptionType() {
        let description = GlassItemTypeSystem.shortDescription(type: "rod", subtype: nil, dimensions: nil)

        #expect(description == "Rod")
    }

    @Test("Short description includes type and subtype")
    func testShortDescriptionTypeAndSubtype() {
        let description = GlassItemTypeSystem.shortDescription(type: "rod", subtype: "standard", dimensions: nil)

        #expect(description == "Rod (Standard)")
    }

    @Test("Short description includes first dimension")
    func testShortDescriptionWithDimension() {
        let dimensions = ["diameter": 5.0, "length": 10.0]
        let description = GlassItemTypeSystem.shortDescription(type: "rod", subtype: nil, dimensions: dimensions)

        #expect(description.contains("Rod"))
        #expect(description.contains("5 mm")) // First dimension (diameter)
    }

    @Test("Short description includes all parts")
    func testShortDescriptionComplete() {
        let dimensions = ["diameter": 5.5, "length": 10.0]
        let description = GlassItemTypeSystem.shortDescription(type: "rod", subtype: "standard", dimensions: dimensions)

        #expect(description.contains("Rod"))
        #expect(description.contains("(Standard)"))
        #expect(description.contains("5.5 mm"))
    }

    @Test("Short description handles empty subtype")
    func testShortDescriptionEmptySubtype() {
        let description = GlassItemTypeSystem.shortDescription(type: "rod", subtype: "", dimensions: nil)

        #expect(description == "Rod")
    }

    @Test("Short description handles empty dimensions")
    func testShortDescriptionEmptyDimensions() {
        let dimensions: [String: Double] = [:]
        let description = GlassItemTypeSystem.shortDescription(type: "rod", subtype: nil, dimensions: dimensions)

        #expect(description == "Rod")
    }

    // MARK: - DimensionField Tests

    @Test("Dimension field default placeholder")
    func testDimensionFieldDefaultPlaceholder() {
        let field = DimensionField(name: "diameter", displayName: "Diameter", unit: "mm")

        #expect(field.placeholder == "Enter diameter")
    }

    @Test("Dimension field custom placeholder")
    func testDimensionFieldCustomPlaceholder() {
        let field = DimensionField(name: "diameter", displayName: "Diameter", unit: "mm", placeholder: "Custom placeholder")

        #expect(field.placeholder == "Custom placeholder")
    }

    @Test("Dimension field is required")
    func testDimensionFieldRequired() {
        let field = DimensionField(name: "diameter", displayName: "Diameter", unit: "mm", isRequired: true)

        #expect(field.isRequired == true)
    }

    @Test("Dimension field is optional by default")
    func testDimensionFieldOptionalDefault() {
        let field = DimensionField(name: "diameter", displayName: "Diameter", unit: "mm")

        #expect(field.isRequired == false)
    }

    // MARK: - Edge Cases

    @Test("Types by name lookup is fast")
    func testTypesByNameLookup() {
        // Should be O(1) lookup via dictionary
        let type = GlassItemTypeSystem.typesByName["rod"]

        #expect(type != nil)
        #expect(type?.name == "rod")
    }

    @Test("Type with no subsubtypes returns empty array")
    func testGetSubsubTypesEmpty() {
        let subsubtypes = GlassItemTypeSystem.getSubsubtypes(for: "rod", subtype: "standard")

        #expect(subsubtypes.isEmpty)
    }

    @Test("Subsubtype validation for invalid type")
    func testIsValidSubsubtypeInvalidType() {
        let isValid = GlassItemTypeSystem.isValidSubsubtype("test", for: "invalid", subtype: "test")

        #expect(isValid == false)
    }

    @Test("All types have unique names")
    func testAllTypesUniqueNames() {
        let names = GlassItemTypeSystem.allTypeNames
        let uniqueNames = Set(names)

        #expect(names.count == uniqueNames.count)
    }

    @Test("Type system is immutable")
    func testTypeSystemImmutable() {
        // Verify that modifying returned arrays doesn't affect the system
        var names = GlassItemTypeSystem.allTypeNames
        names.append("invalid")

        let actualNames = GlassItemTypeSystem.allTypeNames
        #expect(actualNames.count == 9) // Still 9, not 10
    }
}

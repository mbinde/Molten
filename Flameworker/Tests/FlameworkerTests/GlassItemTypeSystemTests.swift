//
//  GlassItemTypeSystemTests.swift
//  FlameworkerTests
//
//  Tests for the GlassItemTypeSystem domain model
//  Tests type hierarchy, validation, and formatting logic
//

import Testing
import Foundation
@testable import Flameworker

@Suite("GlassItemTypeSystem Tests")
struct GlassItemTypeSystemTests {

    // MARK: - Type Definition Tests

    @Test("All 9 types are registered")
    func testAllTypesRegistered() {
        let expectedTypes = ["rod", "stringer", "sheet", "frit", "tube", "powder", "scrap", "murrini", "enamel"]
        let actualTypes = GlassItemTypeSystem.allTypeNames

        #expect(actualTypes.count == 9)
        for expectedType in expectedTypes {
            #expect(actualTypes.contains(expectedType))
        }
    }

    @Test("Each type has correct subtypes - rod")
    func testRodSubtypes() {
        let subtypes = GlassItemTypeSystem.getSubtypes(for: "rod")
        #expect(subtypes == ["standard", "cane", "pull"])
    }

    @Test("Each type has correct subtypes - stringer")
    func testStringerSubtypes() {
        let subtypes = GlassItemTypeSystem.getSubtypes(for: "stringer")
        #expect(subtypes == ["fine", "medium", "thick"])
    }

    @Test("Each type has correct subtypes - sheet")
    func testSheetSubtypes() {
        let subtypes = GlassItemTypeSystem.getSubtypes(for: "sheet")
        #expect(subtypes == ["clear", "transparent", "opaque", "opalescent"])
    }

    @Test("Each type has correct subtypes - frit")
    func testFritSubtypes() {
        let subtypes = GlassItemTypeSystem.getSubtypes(for: "frit")
        #expect(subtypes == ["fine", "medium", "coarse", "powder"])
    }

    @Test("Each type has correct subtypes - tube")
    func testTubeSubtypes() {
        let subtypes = GlassItemTypeSystem.getSubtypes(for: "tube")
        #expect(subtypes == ["thin_wall", "thick_wall", "standard"])
    }

    @Test("Each type has correct subtypes - powder")
    func testPowderSubtypes() {
        let subtypes = GlassItemTypeSystem.getSubtypes(for: "powder")
        #expect(subtypes == ["fine", "medium", "coarse"])
    }

    @Test("Each type has correct subtypes - scrap")
    func testScrapSubtypes() {
        let subtypes = GlassItemTypeSystem.getSubtypes(for: "scrap")
        #expect(subtypes.isEmpty)
    }

    @Test("Each type has correct subtypes - murrini")
    func testMurriniSubtypes() {
        let subtypes = GlassItemTypeSystem.getSubtypes(for: "murrini")
        #expect(subtypes == ["cane", "slice"])
    }

    @Test("Each type has correct subtypes - enamel")
    func testEnamelSubtypes() {
        let subtypes = GlassItemTypeSystem.getSubtypes(for: "enamel")
        #expect(subtypes == ["opaque", "transparent"])
    }

    @Test("Rod has correct dimension fields")
    func testRodDimensions() {
        let fields = GlassItemTypeSystem.getDimensionFields(for: "rod")
        #expect(fields.count == 2)
        #expect(fields.contains { $0.name == "diameter" && $0.unit == "mm" })
        #expect(fields.contains { $0.name == "length" && $0.unit == "cm" })
    }

    @Test("Sheet has correct dimension fields")
    func testSheetDimensions() {
        let fields = GlassItemTypeSystem.getDimensionFields(for: "sheet")
        #expect(fields.count == 3)
        #expect(fields.contains { $0.name == "thickness" && $0.unit == "mm" })
        #expect(fields.contains { $0.name == "width" && $0.unit == "cm" })
        #expect(fields.contains { $0.name == "height" && $0.unit == "cm" })
    }

    @Test("Tube has correct dimension fields")
    func testTubeDimensions() {
        let fields = GlassItemTypeSystem.getDimensionFields(for: "tube")
        #expect(fields.count == 3)
        #expect(fields.contains { $0.name == "outer_diameter" && $0.unit == "mm" })
        #expect(fields.contains { $0.name == "inner_diameter" && $0.unit == "mm" })
        #expect(fields.contains { $0.name == "length" && $0.unit == "cm" })
    }

    @Test("Scrap has no dimension fields")
    func testScrapNoDimensions() {
        let fields = GlassItemTypeSystem.getDimensionFields(for: "scrap")
        #expect(fields.isEmpty)
    }

    @Test("Enamel has no dimension fields")
    func testEnamelNoDimensions() {
        let fields = GlassItemTypeSystem.getDimensionFields(for: "enamel")
        #expect(fields.isEmpty)
    }

    // MARK: - Type Lookup Tests

    @Test("getType(named:) returns correct type for rod")
    func testGetTypeRod() {
        let type = GlassItemTypeSystem.getType(named: "rod")
        #expect(type != nil)
        #expect(type?.name == "rod")
        #expect(type?.displayName == "Rod")
    }

    @Test("getType(named:) returns correct type for stringer")
    func testGetTypeStringer() {
        let type = GlassItemTypeSystem.getType(named: "stringer")
        #expect(type != nil)
        #expect(type?.name == "stringer")
        #expect(type?.displayName == "Stringer")
    }

    @Test("getType(named:) is case-insensitive")
    func testGetTypeCaseInsensitive() {
        let type1 = GlassItemTypeSystem.getType(named: "ROD")
        let type2 = GlassItemTypeSystem.getType(named: "Rod")
        let type3 = GlassItemTypeSystem.getType(named: "rod")

        #expect(type1 != nil)
        #expect(type2 != nil)
        #expect(type3 != nil)
        #expect(type1?.name == type2?.name)
        #expect(type2?.name == type3?.name)
    }

    @Test("getType(named:) returns nil for invalid type")
    func testGetTypeInvalid() {
        let type = GlassItemTypeSystem.getType(named: "invalid-type")
        #expect(type == nil)
    }

    @Test("getSubtypes(for:) returns correct subtypes")
    func testGetSubtypes() {
        let rodSubtypes = GlassItemTypeSystem.getSubtypes(for: "rod")
        #expect(rodSubtypes.count == 3)
        #expect(rodSubtypes.contains("standard"))
    }

    @Test("getSubtypes(for:) returns empty for invalid type")
    func testGetSubtypesInvalid() {
        let subtypes = GlassItemTypeSystem.getSubtypes(for: "invalid")
        #expect(subtypes.isEmpty)
    }

    @Test("getDimensionFields(for:) returns correct fields")
    func testGetDimensionFields() {
        let rodFields = GlassItemTypeSystem.getDimensionFields(for: "rod")
        #expect(rodFields.count == 2)
    }

    @Test("getDimensionFields(for:) returns empty for invalid type")
    func testGetDimensionFieldsInvalid() {
        let fields = GlassItemTypeSystem.getDimensionFields(for: "invalid")
        #expect(fields.isEmpty)
    }

    // MARK: - Validation Tests

    @Test("isValidType() correctly validates type names")
    func testIsValidType() {
        #expect(GlassItemTypeSystem.isValidType("rod") == true)
        #expect(GlassItemTypeSystem.isValidType("stringer") == true)
        #expect(GlassItemTypeSystem.isValidType("sheet") == true)
        #expect(GlassItemTypeSystem.isValidType("invalid") == false)
    }

    @Test("isValidType() is case-insensitive")
    func testIsValidTypeCaseInsensitive() {
        #expect(GlassItemTypeSystem.isValidType("ROD") == true)
        #expect(GlassItemTypeSystem.isValidType("Rod") == true)
        #expect(GlassItemTypeSystem.isValidType("rod") == true)
    }

    @Test("isValidSubtype() validates subtype for given type")
    func testIsValidSubtype() {
        #expect(GlassItemTypeSystem.isValidSubtype("standard", for: "rod") == true)
        #expect(GlassItemTypeSystem.isValidSubtype("cane", for: "rod") == true)
        #expect(GlassItemTypeSystem.isValidSubtype("fine", for: "stringer") == true)
        #expect(GlassItemTypeSystem.isValidSubtype("invalid", for: "rod") == false)
    }

    @Test("isValidSubtype() returns false for invalid type")
    func testIsValidSubtypeInvalidType() {
        #expect(GlassItemTypeSystem.isValidSubtype("standard", for: "invalid") == false)
    }

    @Test("isValidSubtype() is case-insensitive")
    func testIsValidSubtypeCaseInsensitive() {
        #expect(GlassItemTypeSystem.isValidSubtype("STANDARD", for: "rod") == true)
        #expect(GlassItemTypeSystem.isValidSubtype("Standard", for: "rod") == true)
        #expect(GlassItemTypeSystem.isValidSubtype("standard", for: "rod") == true)
    }

    @Test("validateDimensions() catches negative values")
    func testValidateDimensionsNegative() {
        let dimensions = ["diameter": -5.0, "length": 10.0]
        let errors = GlassItemTypeSystem.validateDimensions(dimensions, for: "rod")

        #expect(!errors.isEmpty)
        #expect(errors.contains { $0.contains("negative") })
    }

    @Test("validateDimensions() validates empty dimensions")
    func testValidateDimensionsEmpty() {
        let dimensions: [String: Double] = [:]
        let errors = GlassItemTypeSystem.validateDimensions(dimensions, for: "rod")

        // Rod has no required dimensions, so empty should be valid
        #expect(errors.isEmpty)
    }

    @Test("validateDimensions() returns error for invalid type")
    func testValidateDimensionsInvalidType() {
        let dimensions = ["diameter": 5.0]
        let errors = GlassItemTypeSystem.validateDimensions(dimensions, for: "invalid")

        #expect(!errors.isEmpty)
        #expect(errors.contains { $0.contains("Invalid type") })
    }

    @Test("validateDimensions() accepts valid dimensions")
    func testValidateDimensionsValid() {
        let dimensions = ["diameter": 5.0, "length": 30.0]
        let errors = GlassItemTypeSystem.validateDimensions(dimensions, for: "rod")

        #expect(errors.isEmpty)
    }

    // MARK: - Display Formatting Tests

    @Test("formatDimension() formats integer values without decimal")
    func testFormatDimensionInteger() {
        let field = DimensionField(name: "diameter", displayName: "Diameter", unit: "mm")
        let formatted = GlassItemTypeSystem.formatDimension(value: 5.0, field: field)

        #expect(formatted == "5 mm")
    }

    @Test("formatDimension() formats decimal values with one decimal place")
    func testFormatDimensionDecimal() {
        let field = DimensionField(name: "diameter", displayName: "Diameter", unit: "mm")
        let formatted = GlassItemTypeSystem.formatDimension(value: 5.5, field: field)

        #expect(formatted == "5.5 mm")
    }

    @Test("formatDimensions() creates proper display strings")
    func testFormatDimensions() {
        let dimensions = ["diameter": 5.0, "length": 30.0]
        let formatted = GlassItemTypeSystem.formatDimensions(dimensions, for: "rod")

        #expect(formatted.contains("Diameter"))
        #expect(formatted.contains("5 mm"))
        #expect(formatted.contains("Length"))
        #expect(formatted.contains("30 cm"))
    }

    @Test("formatDimensions() returns empty for invalid type")
    func testFormatDimensionsInvalidType() {
        let dimensions = ["diameter": 5.0]
        let formatted = GlassItemTypeSystem.formatDimensions(dimensions, for: "invalid")

        #expect(formatted.isEmpty)
    }

    @Test("formatDimensions() handles empty dimensions")
    func testFormatDimensionsEmpty() {
        let dimensions: [String: Double] = [:]
        let formatted = GlassItemTypeSystem.formatDimensions(dimensions, for: "rod")

        #expect(formatted.isEmpty)
    }

    @Test("shortDescription() creates compact descriptions")
    func testShortDescription() {
        let description = GlassItemTypeSystem.shortDescription(
            type: "rod",
            subtype: "standard",
            dimensions: ["diameter": 5.0]
        )

        #expect(description.contains("Rod"))
        #expect(description.contains("Standard"))
        #expect(description.contains("5 mm"))
    }

    @Test("shortDescription() handles nil subtype")
    func testShortDescriptionNilSubtype() {
        let description = GlassItemTypeSystem.shortDescription(
            type: "rod",
            subtype: nil,
            dimensions: ["diameter": 5.0]
        )

        #expect(description.contains("Rod"))
        #expect(!description.contains("("))
        #expect(description.contains("5 mm"))
    }

    @Test("shortDescription() handles nil dimensions")
    func testShortDescriptionNilDimensions() {
        let description = GlassItemTypeSystem.shortDescription(
            type: "rod",
            subtype: "standard",
            dimensions: nil
        )

        #expect(description.contains("Rod"))
        #expect(description.contains("Standard"))
        #expect(!description.contains("mm"))
    }

    @Test("shortDescription() handles empty subtype")
    func testShortDescriptionEmptySubtype() {
        let description = GlassItemTypeSystem.shortDescription(
            type: "rod",
            subtype: "",
            dimensions: nil
        )

        #expect(description.contains("Rod"))
        #expect(!description.contains("("))
    }

    // MARK: - Edge Cases

    @Test("Case-insensitive type lookup")
    func testCaseInsensitiveTypeLookup() {
        let type1 = GlassItemTypeSystem.getType(named: "rod")
        let type2 = GlassItemTypeSystem.getType(named: "ROD")
        let type3 = GlassItemTypeSystem.getType(named: "RoD")

        #expect(type1 != nil)
        #expect(type2 != nil)
        #expect(type3 != nil)
        #expect(type1 == type2)
        #expect(type2 == type3)
    }

    @Test("Empty dimension dictionaries")
    func testEmptyDimensionDictionaries() {
        let dimensions: [String: Double] = [:]

        let errors = GlassItemTypeSystem.validateDimensions(dimensions, for: "rod")
        #expect(errors.isEmpty)

        let formatted = GlassItemTypeSystem.formatDimensions(dimensions, for: "rod")
        #expect(formatted.isEmpty)
    }

    @Test("Types with no subtypes")
    func testTypesWithNoSubtypes() {
        let scrapSubtypes = GlassItemTypeSystem.getSubtypes(for: "scrap")
        #expect(scrapSubtypes.isEmpty)

        let hasSubtypes = GlassItemTypeSystem.hasSubtypes("scrap")
        #expect(hasSubtypes == false)
    }

    @Test("Types with no dimensions")
    func testTypesWithNoDimensions() {
        let scrapFields = GlassItemTypeSystem.getDimensionFields(for: "scrap")
        #expect(scrapFields.isEmpty)

        let hasDimensions = GlassItemTypeSystem.hasDimensions("scrap")
        #expect(hasDimensions == false)
    }

    @Test("hasSubtypes() correctly identifies types with subtypes")
    func testHasSubtypes() {
        #expect(GlassItemTypeSystem.hasSubtypes("rod") == true)
        #expect(GlassItemTypeSystem.hasSubtypes("scrap") == false)
        #expect(GlassItemTypeSystem.hasSubtypes("invalid") == false)
    }

    @Test("hasDimensions() correctly identifies types with dimensions")
    func testHasDimensions() {
        #expect(GlassItemTypeSystem.hasDimensions("rod") == true)
        #expect(GlassItemTypeSystem.hasDimensions("scrap") == false)
        #expect(GlassItemTypeSystem.hasDimensions("invalid") == false)
    }

    @Test("allTypeDisplayNames returns correct display names")
    func testAllTypeDisplayNames() {
        let displayNames = GlassItemTypeSystem.allTypeDisplayNames

        #expect(displayNames.count == 9)
        #expect(displayNames.contains("Rod"))
        #expect(displayNames.contains("Stringer"))
        #expect(displayNames.contains("Sheet"))
    }

    @Test("DimensionField placeholder defaults correctly")
    func testDimensionFieldPlaceholder() {
        let field1 = DimensionField(name: "diameter", displayName: "Diameter", unit: "mm")
        #expect(field1.placeholder == "Enter diameter")

        let field2 = DimensionField(name: "length", displayName: "Length", unit: "cm", placeholder: "Custom placeholder")
        #expect(field2.placeholder == "Custom placeholder")
    }

    @Test("GlassItemType hasSubtypes property")
    func testGlassItemTypeHasSubtypes() {
        let rodType = GlassItemTypeSystem.rod
        #expect(rodType.hasSubtypes == true)

        let scrapType = GlassItemTypeSystem.scrap
        #expect(scrapType.hasSubtypes == false)
    }

    @Test("GlassItemType hasDimensions property")
    func testGlassItemTypeHasDimensions() {
        let rodType = GlassItemTypeSystem.rod
        #expect(rodType.hasDimensions == true)

        let scrapType = GlassItemTypeSystem.scrap
        #expect(scrapType.hasDimensions == false)
    }

    // MARK: - Complex Validation Scenarios

    @Test("Validate dimensions with multiple negative values")
    func testValidateMultipleNegativeValues() {
        let dimensions = ["diameter": -5.0, "length": -10.0]
        let errors = GlassItemTypeSystem.validateDimensions(dimensions, for: "rod")

        #expect(errors.count >= 2)
    }

    @Test("Validate dimensions with mixed valid and negative values")
    func testValidateMixedValues() {
        let dimensions = ["diameter": 5.0, "length": -10.0]
        let errors = GlassItemTypeSystem.validateDimensions(dimensions, for: "rod")

        #expect(errors.count == 1)
        #expect(errors.first?.contains("length") == true)
    }

    @Test("Format dimensions with partial data")
    func testFormatPartialDimensions() {
        // Only diameter, no length
        let dimensions = ["diameter": 5.0]
        let formatted = GlassItemTypeSystem.formatDimensions(dimensions, for: "rod")

        #expect(formatted.contains("Diameter"))
        #expect(!formatted.contains("Length"))
    }
}

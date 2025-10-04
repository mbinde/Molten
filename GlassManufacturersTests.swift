//  GlassManufacturersTests.swift
//  FlameworkerTests
//
//  Extracted from FlameworkerTests.swift on 10/3/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Testing
import Foundation
import SwiftUI
@testable import Flameworker

@Suite("GlassManufacturers Tests")
struct GlassManufacturersTests {
    
    @Test("Full name lookup works correctly")
    func testFullNameLookup() {
        #expect(GlassManufacturers.fullName(for: "EF") == "Effetre", "Should return correct full name for EF")
        #expect(GlassManufacturers.fullName(for: "DH") == "Double Helix", "Should return correct full name for DH")
        #expect(GlassManufacturers.fullName(for: "INVALID") == nil, "Should return nil for invalid code")
    }
    
    @Test("Code validation works correctly")
    func testCodeValidation() {
        #expect(GlassManufacturers.isValid(code: "EF") == true, "Should validate existing code")
        #expect(GlassManufacturers.isValid(code: "INVALID") == false, "Should not validate non-existent code")
    }
    
    @Test("Reverse lookup works correctly")
    func testReverseLookup() {
        #expect(GlassManufacturers.code(for: "Effetre") == "EF", "Should find code for full name")
        #expect(GlassManufacturers.code(for: "Double Helix") == "DH", "Should find code for full name")
        #expect(GlassManufacturers.code(for: "Invalid Name") == nil, "Should return nil for invalid name")
    }
    
    @Test("Case insensitive lookup works")
    func testCaseInsensitiveLookup() {
        #expect(GlassManufacturers.code(for: "effetre") == "EF", "Should work with lowercase")
        #expect(GlassManufacturers.code(for: "EFFETRE") == "EF", "Should work with uppercase")
        #expect(GlassManufacturers.code(for: "  Effetre  ") == "EF", "Should trim whitespace")
    }
    
    @Test("COE values lookup works correctly")
    func testCOEValuesLookup() {
        #expect(GlassManufacturers.coeValues(for: "EF") == [104], "Effetre should have COE 104")
        #expect(GlassManufacturers.coeValues(for: "TAG")?.contains(33) ?? false == true, "TAG should support COE 33")
        #expect(GlassManufacturers.coeValues(for: "TAG")?.contains(104) ?? false == true, "TAG should support COE 104")
        #expect(GlassManufacturers.coeValues(for: "INVALID") == nil, "Should return nil for invalid code")
    }
    
    @Test("Primary COE lookup works correctly")
    func testPrimaryCOELookup() {
        #expect(GlassManufacturers.primaryCOE(for: "EF") == 104, "Effetre primary COE should be 104")
        #expect(GlassManufacturers.primaryCOE(for: "BB") == 33, "Boro Batch primary COE should be 33")
        #expect(GlassManufacturers.primaryCOE(for: "INVALID") == nil, "Should return nil for invalid code")
    }
    
    @Test("COE support check works correctly")
    func testCOESupport() {
        #expect(GlassManufacturers.supports(code: "EF", coe: 104) == true, "Effetre should support COE 104")
        #expect(GlassManufacturers.supports(code: "EF", coe: 33) == false, "Effetre should not support COE 33")
        #expect(GlassManufacturers.supports(code: "TAG", coe: 33) == true, "TAG should support COE 33")
        #expect(GlassManufacturers.supports(code: "TAG", coe: 104) == true, "TAG should support COE 104")
    }
    
    @Test("Manufacturers by COE works correctly")
    func testManufacturersByCOE() {
        let coe33Manufacturers = GlassManufacturers.manufacturers(for: 33)
        #expect(coe33Manufacturers.contains("BB"), "Should include Boro Batch for COE 33")
        #expect(coe33Manufacturers.contains("NS"), "Should include Northstar for COE 33")
        #expect(coe33Manufacturers.contains("TAG"), "Should include TAG for COE 33")
        
        let coe104Manufacturers = GlassManufacturers.manufacturers(for: 104)
        #expect(coe104Manufacturers.contains("EF"), "Should include Effetre for COE 104")
        #expect(coe104Manufacturers.contains("DH"), "Should include Double Helix for COE 104")
        #expect(coe104Manufacturers.contains("TAG"), "Should include TAG for COE 104")
    }
    
    @Test("All COE values includes expected values")
    func testAllCOEValues() {
        let allCOEs = GlassManufacturers.allCOEValues
        #expect(allCOEs.contains(33), "Should include COE 33")
        #expect(allCOEs.contains(90), "Should include COE 90")
        #expect(allCOEs.contains(104), "Should include COE 104")
        #expect(allCOEs.sorted() == allCOEs, "Should be sorted")
    }
    
    @Test("Color mapping works for all manufacturers")
    func testColorMapping() {
        // Test that all manufacturer codes have colors
        for code in GlassManufacturers.allCodes {
            let color = GlassManufacturers.colorForManufacturer(code)
            #expect(color != Color.clear, "Should have a color for manufacturer \(code)")
        }
        
        // Test consistency between code and full name
        let efColorFromCode = GlassManufacturers.colorForManufacturer("EF")
        let efColorFromName = GlassManufacturers.colorForManufacturer("Effetre")
        #expect(efColorFromCode == efColorFromName, "Color should be consistent between code and full name")
    }
    
    @Test("Normalize function works correctly")
    func testNormalizeFunction() {
        let efFromCode = GlassManufacturers.normalize("EF")
        #expect(efFromCode?.code == "EF", "Should normalize code correctly")
        #expect(efFromCode?.fullName == "Effetre", "Should provide full name")
        
        let efFromName = GlassManufacturers.normalize("Effetre")
        #expect(efFromName?.code == "EF", "Should find code from name")
        #expect(efFromName?.fullName == "Effetre", "Should normalize name correctly")
        
        let invalid = GlassManufacturers.normalize("INVALID")
        #expect(invalid == nil, "Should return nil for invalid input")
        
        let empty = GlassManufacturers.normalize("")
        #expect(empty == nil, "Should return nil for empty input")
        
        let whitespace = GlassManufacturers.normalize("   ")
        #expect(whitespace == nil, "Should return nil for whitespace input")
    }
    
    @Test("Manufacturer info provides comprehensive data")
    func testManufacturerInfo() {
        let efInfo = GlassManufacturers.info(for: "EF")
        #expect(efInfo?.code == "EF", "Should provide correct code")
        #expect(efInfo?.fullName == "Effetre", "Should provide correct full name")
        #expect(efInfo?.coeValues == [104], "Should provide correct COE values")
        #expect(efInfo?.primaryCOE == 104, "Should provide correct primary COE")
        #expect(efInfo?.supports(coe: 104) == true, "Should correctly identify COE support")
        #expect(efInfo?.supports(coe: 33) == false, "Should correctly identify COE non-support")
        
        let tagInfo = GlassManufacturers.info(for: "TAG")
        #expect(tagInfo?.coeValues.count == 2, "TAG should support multiple COE values")
        #expect(tagInfo?.displayNameWithCOE.contains("33") ?? false, "Display name should include COE values")
        #expect(tagInfo?.displayNameWithCOE.contains("104") ?? false, "Display name should include COE values")
    }
    
    @Test("Search function works correctly")
    func testSearchFunction() {
        let glassResults = GlassManufacturers.search("glass")
        #expect(glassResults.contains("GA"), "Should find Glass Alchemy")
        #expect(glassResults.contains("TAG"), "Should find Trautmann Art Glass")
        
        let helixResults = GlassManufacturers.search("helix")
        #expect(helixResults.contains("DH"), "Should find Double Helix")
        
        let efResults = GlassManufacturers.search("ef")
        #expect(efResults.contains("EF"), "Should find code matches")
        
        let noResults = GlassManufacturers.search("xyz123")
        #expect(noResults.isEmpty, "Should return empty array for no matches")
    }
    
    @Test("Manufacturers by COE grouping works correctly")
    func testManufacturersByCOEGrouping() {
        let groupedByCOE = GlassManufacturers.manufacturersByCOE
        
        #expect(groupedByCOE[33] != nil, "Should have COE 33 group")
        #expect(groupedByCOE[90] != nil, "Should have COE 90 group")
        #expect(groupedByCOE[104] != nil, "Should have COE 104 group")
        
        #expect(groupedByCOE[33]?.contains("BB") ?? false == true, "COE 33 should include Boro Batch")
        #expect(groupedByCOE[104]?.contains("EF") ?? false == true, "COE 104 should include Effetre")
        #expect(groupedByCOE[90]?.contains("BE") ?? false == true, "COE 90 should include Bullseye")
    }
}
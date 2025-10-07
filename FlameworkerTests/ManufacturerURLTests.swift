//
//  ManufacturerURLTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/6/25.
//

import Testing
import Foundation
@testable import Flameworker

@Suite("Manufacturer Information Tests")
struct ManufacturerInfoTests {
    
    @Test("Should return manufacturer full names for known manufacturers")
    func testManufacturerFullNamesForKnownManufacturers() {
        // Test that we can get full names for major manufacturers
        let efName = GlassManufacturers.fullName(for: "EF")
        #expect(efName == "Effetre", "EF should map to Effetre")
        
        let dhName = GlassManufacturers.fullName(for: "DH")
        #expect(dhName == "Double Helix", "DH should map to Double Helix")
        
        let cimName = GlassManufacturers.fullName(for: "CiM")
        #expect(cimName == "Creation is Messy", "CiM should map to Creation is Messy")
    }
    
    @Test("Should return nil for unknown manufacturers")
    func testManufacturerInfoForUnknownManufacturer() {
        let unknownName = GlassManufacturers.fullName(for: "UNKNOWN")
        #expect(unknownName == nil, "Unknown manufacturer should return nil")
    }
    
    @Test("Should return valid COE values for manufacturers")
    func testManufacturerCOEValues() {
        let efCOE = GlassManufacturers.primaryCOE(for: "EF")
        #expect(efCOE == 104, "Effetre should have COE 104")
        
        let cimCOE = GlassManufacturers.primaryCOE(for: "CiM")
        #expect(cimCOE == 33, "Creation is Messy should have COE 33")
    }
    
    @Test("Should work with both manufacturer codes and full names for normalization")
    func testManufacturerNormalization() {
        let codeResult = GlassManufacturers.normalize("EF")
        let nameResult = GlassManufacturers.normalize("Effetre")
        
        #expect(codeResult?.code == nameResult?.code, "Code and name should normalize to same result")
        #expect(codeResult?.fullName == "Effetre", "Should return full name")
    }
}

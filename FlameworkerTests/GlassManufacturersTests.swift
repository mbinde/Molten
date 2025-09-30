import Testing
import Foundation
import SwiftUI

@testable import Flameworker

@Suite("Glass Manufacturers Tests")
struct GlassManufacturersTests {
    
    @Test("Verify manufacturer mappings work correctly")
    func testManufacturerMappings() async throws {
        // Test known mappings
        #expect(GlassManufacturers.fullName(for: "EF") == "Effetre")
        #expect(GlassManufacturers.fullName(for: "DH") == "Double Helix")
        #expect(GlassManufacturers.fullName(for: "BB") == "Boro Batch")
        #expect(GlassManufacturers.fullName(for: "CiM") == "Creation is Messy")
        #expect(GlassManufacturers.fullName(for: "GA") == "Glass Alchemy")
        #expect(GlassManufacturers.fullName(for: "RE") == "Reichenbach")
        #expect(GlassManufacturers.fullName(for: "TAG") == "Trautmann Art Glass")
        #expect(GlassManufacturers.fullName(for: "VF") == "Vetrofond")
        #expect(GlassManufacturers.fullName(for: "NS") == "Northstar Glassworks")
    }
    
    @Test("Handle unknown manufacturer codes")
    func testUnknownCodes() async throws {
        // Test that unknown codes return nil
        #expect(GlassManufacturers.fullName(for: "UNKNOWN") == nil)
        #expect(GlassManufacturers.fullName(for: "XYZ") == nil)
        #expect(GlassManufacturers.fullName(for: "") == nil)
    }
    
    @Test("Verify all codes are valid")
    func testCodeValidation() async throws {
        #expect(GlassManufacturers.isValid(code: "EF") == true)
        #expect(GlassManufacturers.isValid(code: "DH") == true)
        #expect(GlassManufacturers.isValid(code: "UNKNOWN") == false)
    }
    
    @Test("Check all codes and names are available")
    func testAllCodesAndNames() async throws {
        let allCodes = GlassManufacturers.allCodes
        let allNames = GlassManufacturers.allNames
        
        #expect(allCodes.count == 9, "Should have 9 manufacturer codes")
        #expect(allNames.count == 9, "Should have 9 manufacturer names")
        
        #expect(allCodes.contains("EF"))
        #expect(allNames.contains("Effetre"))
    }
    
    @Test("Test fallback behavior in UI context")
    func testUIFallback() async throws {
        // Test the fallback pattern used in the UI
        let knownCode = "EF"
        let unknownCode = "UNKNOWN"
        
        // Known code should return the full name
        let knownResult = GlassManufacturers.fullName(for: knownCode) ?? knownCode
        #expect(knownResult == "Effetre")
        
        // Unknown code should fall back to the original code
        let unknownResult = GlassManufacturers.fullName(for: unknownCode) ?? unknownCode
        #expect(unknownResult == "UNKNOWN")
    }
    
    @Test("Verify manufacturer color mappings")
    func testManufacturerColors() async throws {
        // Test colors for known manufacturers (using codes)
        #expect(GlassManufacturers.colorForManufacturer("EF") == .blue)
        #expect(GlassManufacturers.colorForManufacturer("DH") == .orange)
        #expect(GlassManufacturers.colorForManufacturer("VF") == .green)
        #expect(GlassManufacturers.colorForManufacturer("RE") == .purple)
        #expect(GlassManufacturers.colorForManufacturer("NS") == .red)
        
        // Test colors for full names
        #expect(GlassManufacturers.colorForManufacturer("Effetre") == .blue)
        #expect(GlassManufacturers.colorForManufacturer("Double Helix") == .orange)
        #expect(GlassManufacturers.colorForManufacturer("Vetrofond") == .green)
        
        // Test that codes and full names return the same color
        #expect(GlassManufacturers.colorForManufacturer("EF") == 
                GlassManufacturers.colorForManufacturer("Effetre"))
        #expect(GlassManufacturers.colorForManufacturer("DH") == 
                GlassManufacturers.colorForManufacturer("Double Helix"))
    }
    
    @Test("Handle edge cases for colors")
    func testColorEdgeCases() async throws {
        // Test nil manufacturer
        #expect(GlassManufacturers.colorForManufacturer(nil) == .secondary)
        
        // Test empty string
        #expect(GlassManufacturers.colorForManufacturer("") == .secondary)
        
        // Test whitespace
        #expect(GlassManufacturers.colorForManufacturer("   ") == .secondary)
        
        // Test unknown manufacturer gets a consistent color
        let unknownColor1 = GlassManufacturers.colorForManufacturer("Unknown Brand")
        let unknownColor2 = GlassManufacturers.colorForManufacturer("Unknown Brand")
        #expect(unknownColor1 == unknownColor2, "Unknown manufacturers should get consistent colors")
    }
}
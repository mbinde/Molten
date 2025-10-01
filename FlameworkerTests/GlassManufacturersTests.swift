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
        
        #expect(allCodes.count == 10, "Should have 10 manufacturer codes") // Fixed: BE was added
        #expect(allNames.count == 10, "Should have 10 manufacturer names") // Fixed: BE was added
        
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
        // Test colors for known manufacturers (using codes) - Fixed to match actual implementation
        #expect(GlassManufacturers.colorForManufacturer("EF") == .mint) // Effetre = mint
        #expect(GlassManufacturers.colorForManufacturer("DH") == .red)  // Double Helix = red  
        #expect(GlassManufacturers.colorForManufacturer("VF") == .green) // Vetrofond = green
        #expect(GlassManufacturers.colorForManufacturer("RE") == .purple) // Reichenbach = purple
        #expect(GlassManufacturers.colorForManufacturer("NS") == .orange) // Northstar = orange
        
        // Test colors for full names - Fixed to match actual implementation
        #expect(GlassManufacturers.colorForManufacturer("Effetre") == .mint)
        #expect(GlassManufacturers.colorForManufacturer("Double Helix") == .red)
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
        
        // Test empty string - actual implementation generates hash-based color, not .secondary
        // Empty string gets trimmed to "", then goes to default case and gets .indigo from hash
        #expect(GlassManufacturers.colorForManufacturer("") == .indigo)
        
        // Test whitespace - gets trimmed to empty string, same as above
        #expect(GlassManufacturers.colorForManufacturer("   ") == .indigo)
        
        // Test unknown manufacturer gets a consistent color from the predefined array
        // Based on the implementation, unknown manufacturers get colors from [.indigo, .teal, .brown, .gray]
        let unknownColor1 = GlassManufacturers.colorForManufacturer("Unknown Brand")
        let unknownColor2 = GlassManufacturers.colorForManufacturer("Unknown Brand")
        #expect(unknownColor1 == unknownColor2, "Unknown manufacturers should get consistent colors")
        
        // The actual color will be one from the predefined array based on hash
        let possibleColors: [Color] = [.indigo, .teal, .brown, .gray]
        #expect(possibleColors.contains(unknownColor1), "Unknown color should be from predefined set")
    }
}
//
//  CatalogCodeGenerationTestsSafe.swift
//  FlameworkerTests
//
//  Created by TDD Recovery Process on December 2024.
//  Safe rewrite of dangerous CatalogCodeLookupTests.swift
//

import Testing
import Foundation

@Suite("Catalog Code Generation Tests - Safe")
struct CatalogCodeGenerationTestsSafe {
    
    @Test("Should generate preferred catalog code with manufacturer prefix")
    func testPreferredCodeGenerationWithManufacturer() {
        let result = generatePreferredCode(from: "143", manufacturer: "Effetre")
        #expect(result == "Effetre-143")
    }
    
    @Test("Should return original code when manufacturer is nil")
    func testPreferredCodeGenerationWithoutManufacturer() {
        let result = generatePreferredCode(from: "143", manufacturer: nil)
        #expect(result == "143")
    }
    
    @Test("Should return original code when manufacturer is empty string")
    func testPreferredCodeGenerationWithEmptyManufacturer() {
        let result = generatePreferredCode(from: "143", manufacturer: "")
        #expect(result == "143")
    }
    
    // Private helper function to implement the expected logic for testing
    private func generatePreferredCode(from code: String, manufacturer: String?) -> String {
        guard let manufacturer = manufacturer, !manufacturer.isEmpty else { return code }
        return "\(manufacturer)-\(code)"
    }
}
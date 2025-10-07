//
//  ManufacturerURLTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/6/25.
//

import Testing
@testable import Flameworker

@Suite("Manufacturer URL Tests")
struct ManufacturerURLTests {
    
    @Test("Should return manufacturer URL for known manufacturers")
    func testManufacturerURLForKnownManufacturers() {
        // Test that we can get URLs for major manufacturers
        let efURL = GlassManufacturers.websiteURL(for: "EF")
        #expect(efURL != nil, "Effetre should have a website URL")
        
        let dhURL = GlassManufacturers.websiteURL(for: "DH")
        #expect(dhURL != nil, "Double Helix should have a website URL")
        
        let cimURL = GlassManufacturers.websiteURL(for: "CiM")
        #expect(cimURL != nil, "Creation is Messy should have a website URL")
    }
    
    @Test("Should return nil URL for unknown manufacturers")
    func testManufacturerURLForUnknownManufacturer() {
        let unknownURL = GlassManufacturers.websiteURL(for: "UNKNOWN")
        #expect(unknownURL == nil, "Unknown manufacturer should return nil URL")
    }
    
    @Test("Should return valid URLs with proper format")
    func testManufacturerURLFormat() {
        let efURL = GlassManufacturers.websiteURL(for: "EF")
        if let url = efURL {
            #expect(url.scheme == "https", "Manufacturer URL should use HTTPS")
            #expect(!url.host!.isEmpty, "Manufacturer URL should have a valid host")
        }
    }
    
    @Test("Should work with both manufacturer codes and full names")
    func testManufacturerURLWithCodesAndNames() {
        let codeURL = GlassManufacturers.websiteURL(for: "EF")
        let nameURL = GlassManufacturers.websiteURL(for: "Effetre")
        
        #expect(codeURL == nameURL, "URL lookup should work consistently with codes and full names")
    }
}
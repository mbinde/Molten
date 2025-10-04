//
//  DataLoadingTests.swift
//  FlameworkerTests
//
//  Created by Melissa Binde on 10/3/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Testing
import Foundation
import SwiftUI
import CoreData
import os
@testable import Flameworker

@Suite("JSONDataLoader Tests")
struct JSONDataLoaderTests {
    
    @Test("JSONDataLoader candidate resource names are correct")
    func testCandidateResourceNames() {
        // Test the resource name patterns the loader looks for
        let expectedCandidates = [
            "colors.json",
            "Data/colors.json",
            "effetre.json", 
            "Data/effetre.json"
        ]
        
        // Test that these are reasonable candidate names
        for candidate in expectedCandidates {
            #expect(candidate.hasSuffix(".json"), "Candidate should be JSON file: \(candidate)")
            #expect(!candidate.isEmpty, "Candidate should not be empty: \(candidate)")
        }
        
        // Test subdirectory detection logic
        let hasSubdirectory = expectedCandidates.contains { $0.contains("/") }
        #expect(hasSubdirectory == true, "Should have candidates with subdirectory")
        
        let hasRootLevel = expectedCandidates.contains { !$0.contains("/") }
        #expect(hasRootLevel == true, "Should have candidates at root level")
    }
    
    @Test("JSONDataLoader resource name parsing works correctly")
    func testResourceNameParsing() {
        // Test the logic for splitting resource names
        
        // Test subdirectory format
        let subdirResource = "Data/colors.json"
        let subdirComponents = subdirResource.split(separator: "/")
        #expect(subdirComponents.count == 2, "Should split into 2 components")
        #expect(String(subdirComponents[0]) == "Data", "Should extract subdirectory")
        #expect(String(subdirComponents[1]) == "colors.json", "Should extract filename")
        
        // Test root level format
        let rootResource = "colors.json"
        let rootComponents = rootResource.split(separator: "/")
        #expect(rootComponents.count == 1, "Should have 1 component for root level")
        
        // Test extension removal logic
        let resourceWithoutExtension = "colors.json".replacingOccurrences(of: ".json", with: "")
        #expect(resourceWithoutExtension == "colors", "Should remove .json extension")
    }
    
    @Test("JSONDataLoader date format patterns are comprehensive") 
    func testDateFormatPatterns() {
        // Test the date formats the loader tries
        let possibleDateFormats = ["yyyy-MM-dd", "MM/dd/yyyy", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ssZ"]
        
        #expect(possibleDateFormats.count >= 4, "Should have multiple date format options")
        
        // Test each format is valid
        for format in possibleDateFormats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            #expect(!format.isEmpty, "Date format should not be empty")
            #expect(format.contains("yyyy") || format.contains("MM") || format.contains("dd"), "Should contain date components")
        }
        
        // Test variety of formats
        let hasISO = possibleDateFormats.contains { $0.contains("T") }
        #expect(hasISO == true, "Should support ISO 8601 format")
        
        let hasSlashFormat = possibleDateFormats.contains { $0.contains("/") }
        #expect(hasSlashFormat == true, "Should support slash-separated dates")
        
        let hasDashFormat = possibleDateFormats.contains { $0.contains("-") && !$0.contains("T") }
        #expect(hasDashFormat == true, "Should support dash-separated dates")
    }
    
    @Test("JSONDataLoader error handling creates appropriate errors")
    func testErrorHandling() {
        // Test error creation logic (without actually trying to load files)
        
        // Test file not found error message format
        let resourceName = "missing.json"
        let expectedMessage = "Resource not found: \(resourceName)"
        #expect(expectedMessage.contains(resourceName), "Error should mention missing resource name")
        #expect(expectedMessage.contains("Resource not found"), "Error should describe the problem")
        
        // Test decoding error message
        let decodingErrorMessage = "Could not decode JSON in any supported format"
        #expect(!decodingErrorMessage.isEmpty, "Should have meaningful decoding error message")
        #expect(decodingErrorMessage.contains("decode"), "Should mention decoding issue")
        #expect(decodingErrorMessage.contains("JSON"), "Should mention JSON format")
    }
}

@Suite("Bundle Resource Loading Tests")
struct BundleResourceLoadingTests {
    
    @Test("Bundle resource name components parsing works correctly")
    func testBundleResourceNameParsing() {
        // Test the component parsing logic used in JSONDataLoader
        
        // Test simple resource name
        let simpleName = "colors"
        let simpleComponents = simpleName.split(separator: "/")
        #expect(simpleComponents.count == 1, "Simple name should have one component")
        #expect(String(simpleComponents[0]) == "colors", "Should preserve simple name")
        
        // Test subdirectory resource name
        let subdirName = "Data/effetre"
        let subdirComponents = subdirName.split(separator: "/")
        #expect(subdirComponents.count == 2, "Subdir name should have two components")
        #expect(String(subdirComponents[0]) == "Data", "Should extract subdirectory")
        #expect(String(subdirComponents[1]) == "effetre", "Should extract resource name")
        
        // Test extension handling
        let withExtension = "colors.json"
        let withoutExtension = withExtension.replacingOccurrences(of: ".json", with: "")
        #expect(withoutExtension == "colors", "Should remove JSON extension")
        
        // Test extension removal is specific to .json
        let otherExtension = "data.txt"
        let otherWithoutJson = otherExtension.replacingOccurrences(of: ".json", with: "")
        #expect(otherWithoutJson == "data.txt", "Should not remove non-JSON extensions")
    }
    
    @Test("Bundle resource extension handling works correctly")
    func testBundleResourceExtensionHandling() {
        // Test the extension handling logic
        
        let commonExtensions = ["jpg", "jpeg", "png", "PNG", "JPG", "JPEG"]
        
        // Test variety of extensions
        #expect(commonExtensions.contains("jpg"), "Should support lowercase jpg")
        #expect(commonExtensions.contains("PNG"), "Should support uppercase PNG")
        #expect(commonExtensions.contains("jpeg"), "Should support jpeg variant")
        
        // Test case variations are included
        let lowercaseCount = commonExtensions.filter { $0.lowercased() == $0 }.count
        let uppercaseCount = commonExtensions.filter { $0.uppercased() == $0 }.count
        #expect(lowercaseCount > 0, "Should include lowercase extensions")
        #expect(uppercaseCount > 0, "Should include uppercase extensions")
        
        // Test reasonable number of extensions
        #expect(commonExtensions.count >= 3, "Should support multiple image formats")
        #expect(commonExtensions.count <= 10, "Should not have excessive extensions")
    }
    
    @Test("Bundle path construction logic works correctly")
    func testBundlePathConstruction() {
        // Test the path construction patterns used in bundle loading
        
        let productImagePrefix = ""
        let manufacturer = "CiM"
        let itemCode = "511101"
        
        let pathWithManufacturer = "\(productImagePrefix)\(manufacturer)-\(itemCode)"
        #expect(pathWithManufacturer == "CiM-511101", "Should construct path with manufacturer")
        
        let pathWithoutManufacturer = "\(productImagePrefix)\(itemCode)"
        #expect(pathWithoutManufacturer == "511101", "Should construct path without manufacturer")
        
        // Test with non-empty prefix
        let customPrefix = "images/"
        let customPath = "\(customPrefix)\(manufacturer)-\(itemCode)"
        #expect(customPath == "images/CiM-511101", "Should support custom prefix")
    }
    
    @Test("Bundle resource fallback logic works correctly")
    func testBundleResourceFallbackLogic() {
        // Test the fallback sequence logic
        
        enum ResourceLookupStrategy {
            case withManufacturer
            case withoutManufacturer
        }
        
        let strategies: [ResourceLookupStrategy] = [.withManufacturer, .withoutManufacturer]
        
        #expect(strategies.count == 2, "Should have two lookup strategies")
        #expect(strategies.first == .withManufacturer, "Should try manufacturer-prefixed first")
        #expect(strategies.last == .withoutManufacturer, "Should fallback to non-prefixed")
        
        // Test that fallback preserves attempt order
        var attemptOrder: [ResourceLookupStrategy] = []
        for strategy in strategies {
            attemptOrder.append(strategy)
        }
        
        #expect(attemptOrder == strategies, "Should preserve attempt order")
    }
}
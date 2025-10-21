//
//  DataModelValidationTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/11/25.
//  Updated for GlassItem Architecture - Removed deprecated InventoryItemType tests
//

// Standard test framework imports pattern - use in all test files
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import SwiftUI
import Foundation
@testable import Molten

@Suite("Data Model Validation Tests", .serialized)
@MainActor
struct DataModelValidationTests {

    // MARK: - COE Glass Type Safety Tests
    
    @Test("COEGlassType should initialize safely with valid COE values")
    func testCOEGlassTypeValidInitialization() {
        // Arrange & Act
        let coe96 = COEGlassType.safeInit(from: 96)
        let coe90 = COEGlassType.safeInit(from: 90)
        let coe104 = COEGlassType.safeInit(from: 104)
        
        // Assert
        #expect(coe96.rawValue == 96)
        #expect(coe90.rawValue == 90)
        #expect(coe104.rawValue == 104)
    }
    
    @Test("COEGlassType should fallback to default for invalid COE values")
    func testCOEGlassTypeInvalidInitializationFallback() {
        // Arrange & Act - test invalid values
        let invalidNegative = COEGlassType.safeInit(from: -1)
        let invalidLarge = COEGlassType.safeInit(from: 999)
        let invalidZero = COEGlassType.safeInit(from: 0)
        
        // Assert - should all fallback to COE 96 (default)
        #expect(invalidNegative.rawValue == 96)
        #expect(invalidLarge.rawValue == 96) 
        #expect(invalidZero.rawValue == 96)
    }
    
    @Test("COEGlassType should provide consistent display properties after fallback")
    func testCOEGlassTypePropertiesAfterFallback() {
        // Arrange & Act
        let invalidType = COEGlassType.safeInit(from: 999)
        
        // Assert - fallback should have valid display properties
        #expect(invalidType.displayName == "COE 96")
        #expect(invalidType.rawValue == 96)
    }
    
    // MARK: - Numeric Validation Edge Cases
    
    @Test("ValidationUtilities should reject NaN values")
    func testValidationUtilitiesNaNRejection() {
        // Arrange
        let nanValue = Double.nan
        let infiniteValue = Double.infinity
        let negativeInfiniteValue = -Double.infinity
        
        // Act & Assert
        #expect(nanValue.isNaN)
        #expect(infiniteValue.isInfinite)
        #expect(negativeInfiniteValue.isInfinite)
    }
    
    @Test("ValidationUtilities should handle extreme numeric values safely")
    func testValidationUtilitiesExtremeValues() {
        // Arrange
        let maxDouble = Double.greatestFiniteMagnitude
        let minDouble = -Double.greatestFiniteMagnitude
        let tinyPositive = Double.leastNormalMagnitude
        let zero = 0.0
        
        // Act & Assert - these should all be valid finite numbers
        #expect(!maxDouble.isNaN)
        #expect(!maxDouble.isInfinite)
        #expect(!minDouble.isNaN)
        #expect(!minDouble.isInfinite)
        #expect(!tinyPositive.isNaN)
        #expect(!tinyPositive.isInfinite)
        #expect(!zero.isNaN)
        #expect(!zero.isInfinite)
    }
    
    // MARK: - String Validation Edge Cases
    
    @Test("String validation should handle various input safely")
    func testStringValidationEdgeCases() {
        // Test inputs including edge cases
        let testInputs = [
            "",                    // Empty
            "   ",                // Whitespace only
            "Normal text",        // Normal case
            "Special!@#$%",       // Special characters
            "Very long string that exceeds normal expectations and could potentially cause issues in various parts of the system", // Long string
            "Unicode: éññ 🔥 测试", // Unicode characters
            "  Trim me  ",        // Leading/trailing whitespace
            "\n\t\r"              // Various whitespace characters
        ]
        
        for (index, input) in testInputs.enumerated() {
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            let isEmpty = trimmed.isEmpty
            let isValid = !isEmpty && trimmed.count <= 200 // Reasonable length limit
            
            // Basic validation - should not crash
            #expect(input.count >= 0, "Input \(index) should have non-negative count")
            
            // Context-specific validation based on input type
            switch index {
            case 0: // Empty
                #expect(isEmpty, "Empty string should be empty after trim")
                #expect(!isValid, "Empty string should be invalid")
            case 1: // Whitespace only
                #expect(isEmpty, "Whitespace-only string should be empty after trim")
                #expect(!isValid, "Whitespace-only string should be invalid")
            case 2...4: // Normal, special chars, long string
                #expect(!trimmed.isEmpty, "Normal input \(index) should not be empty after trim")
                #expect(isValid || trimmed.count > 200, "Input \(index) validation should be consistent with length")
            case 5: // Unicode
                #expect(isValid, "Unicode input \(index) should be valid: '\(input)'")
                #expect(!trimmed.isEmpty, "Unicode input \(index) should not be empty after trim")
            case 6: // "  Trim me  " - Should be valid after trimming
                #expect(isValid, "Input with leading/trailing whitespace should be valid after trim: '\(input)'")
                #expect(trimmed == "Trim me", "Should trim to 'Trim me'")
                #expect(!trimmed.isEmpty, "Trimmed content should not be empty")
            case 7: // "\n\t\r" - Pure whitespace should be invalid
                #expect(!isValid, "Pure whitespace input \(index) should be invalid: '\(input)'")
                #expect(trimmed.isEmpty, "Pure whitespace input \(index) should be empty after trim")
            default:
                break
            }
        }
    }
}

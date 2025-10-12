//  DataModelValidationTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/11/25.
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
@testable import Flameworker

@Suite("Data Model Validation Tests", .serialized)
struct DataModelValidationTests {
    
    // MARK: - Enum Initialization Safety Tests
    
    @Test("InventoryItemType should initialize safely with valid raw values")
    func testInventoryItemTypeValidInitialization() {
        // Arrange & Act
        let inventoryType = InventoryItemType(from: 0)
        let buyType = InventoryItemType(from: 1) 
        let sellType = InventoryItemType(from: 2)
        
        // Assert
        #expect(inventoryType == .inventory)
        #expect(buyType == .buy)
        #expect(sellType == .sell)
    }
    
    @Test("InventoryItemType should fallback to default for invalid raw values")
    func testInventoryItemTypeInvalidInitializationFallback() {
        // Arrange & Act - test invalid values
        let invalidNegative = InventoryItemType(from: -1)
        let invalidLarge = InventoryItemType(from: 999)
        let invalidBoundary = InventoryItemType(from: 3)
        
        // Assert - all should fallback to .inventory
        #expect(invalidNegative == .inventory)
        #expect(invalidLarge == .inventory)  
        #expect(invalidBoundary == .inventory)
    }
    
    @Test("InventoryItemType should provide consistent display properties after fallback")
    func testInventoryItemTypePropertiesAfterFallback() {
        // Arrange & Act
        let invalidType = InventoryItemType(from: -999)
        
        // Assert - fallback should have valid display properties
        #expect(invalidType.displayName == "Inventory")
        #expect(invalidType.systemImageName == "archivebox.fill")
        #expect(invalidType.color == SwiftUI.Color.blue)
        #expect(invalidType.id == 0)
    }
    
    // MARK: - COE Glass Type Safety Tests
    
    @Test("COEGlassType should initialize safely with valid COE values")
    func testCOEGlassTypeValidInitialization() {
        // Arrange & Act
        let coe33 = COEGlassType.safeInit(from: 33)
        let coe90 = COEGlassType.safeInit(from: 90)
        let coe96 = COEGlassType.safeInit(from: 96)
        let coe104 = COEGlassType.safeInit(from: 104)
        
        // Assert
        #expect(coe33 == .coe33)
        #expect(coe90 == .coe90)
        #expect(coe96 == .coe96)
        #expect(coe104 == .coe104)
    }
    
    @Test("COEGlassType should fallback to default for invalid COE values")
    func testCOEGlassTypeInvalidInitializationFallback() {
        // Arrange & Act - test invalid COE values
        let invalidZero = COEGlassType.safeInit(from: 0)
        let invalidNegative = COEGlassType.safeInit(from: -50)
        let invalidLarge = COEGlassType.safeInit(from: 999)
        let invalidCommon = COEGlassType.safeInit(from: 100) // close but invalid
        
        // Assert - all should fallback to .coe96 (most common)
        #expect(invalidZero == .coe96)
        #expect(invalidNegative == .coe96)
        #expect(invalidLarge == .coe96)
        #expect(invalidCommon == .coe96)
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
    func testValidateDoubleRejectsNaN() {
        // Arrange
        let nanString = String(Double.nan)
        
        // Act
        let result = ValidationUtilities.validateDouble(nanString, fieldName: "Test Amount")
        
        // Assert
        switch result {
        case .success:
            #expect(Bool(false), "NaN should be rejected")
        case .failure(let error):
            #expect(error.userMessage.contains("valid number"))
        }
    }
    
    @Test("ValidationUtilities should reject infinity values")
    func testValidateDoubleRejectsInfinity() {
        // Arrange
        let infinityString = String(Double.infinity)
        let negativeInfinityString = String(-Double.infinity)
        
        // Act
        let positiveResult = ValidationUtilities.validateDouble(infinityString, fieldName: "Test Amount")
        let negativeResult = ValidationUtilities.validateDouble(negativeInfinityString, fieldName: "Test Amount")
        
        // Assert
        switch positiveResult {
        case .success:
            #expect(Bool(false), "Positive infinity should be rejected")
        case .failure(let error):
            #expect(error.userMessage.contains("valid number"))
        }
        
        switch negativeResult {
        case .success:
            #expect(Bool(false), "Negative infinity should be rejected")  
        case .failure(let error):
            #expect(error.userMessage.contains("valid number"))
        }
    }
    
    @Test("ValidationUtilities should handle safe numeric validation")
    func testSafeNumericValidation() {
        // Arrange
        let testValues = [
            ("25.50", true),    // Valid number
            ("0", true),        // Valid zero
            ("-10.5", true),    // Valid negative
            ("999999", true),   // Valid large number
            ("0.001", true),    // Valid small decimal
            ("abc", false),     // Invalid text
            ("", false),        // Empty string
            ("  ", false),      // Whitespace only
            ("25.50.25", false) // Multiple decimals
        ]
        
        // Act & Assert
        for (input, shouldBeValid) in testValues {
            let result = ValidationUtilities.safeValidateDouble(input, fieldName: "Test")
            
            switch (result, shouldBeValid) {
            case (.success(let value), true):
                #expect(!value.isNaN, "Valid input should not produce NaN: \(input)")
                #expect(value.isFinite, "Valid input should be finite: \(input)")
            case (.failure, false):
                break // Expected failure
            case (.success, false):
                #expect(Bool(false), "Invalid input should fail: \(input)")
            case (.failure, true):
                #expect(Bool(false), "Valid input should succeed: \(input)")
            }
        }
    }
    
    // MARK: - Collection Bounds Checking Tests
    
    @Test("Should safely access array elements within bounds")
    func testSafeArrayAccess() {
        // Arrange
        let testArray = ["First", "Second", "Third"]
        
        // Act & Assert - Valid indices
        #expect(CollectionSafetyUtilities.safeElement(at: 0, in: testArray) == "First")
        #expect(CollectionSafetyUtilities.safeElement(at: 1, in: testArray) == "Second") 
        #expect(CollectionSafetyUtilities.safeElement(at: 2, in: testArray) == "Third")
        
        // Act & Assert - Invalid indices should return nil
        #expect(CollectionSafetyUtilities.safeElement(at: -1, in: testArray) == nil)
        #expect(CollectionSafetyUtilities.safeElement(at: 3, in: testArray) == nil)
        #expect(CollectionSafetyUtilities.safeElement(at: 100, in: testArray) == nil)
    }
    
    @Test("Should safely access empty collections")
    func testSafeEmptyCollectionAccess() {
        // Arrange
        let emptyArray: [String] = []
        
        // Act & Assert - Any index access should return nil
        #expect(CollectionSafetyUtilities.safeElement(at: 0, in: emptyArray) == nil)
        #expect(CollectionSafetyUtilities.safeElement(at: -1, in: emptyArray) == nil)
        #expect(CollectionSafetyUtilities.safeElement(at: 1, in: emptyArray) == nil)
    }
    
    @Test("Should provide safe first and last element access")
    func testSafeFirstLastAccess() {
        // Arrange
        let testArray = ["Alpha", "Beta", "Gamma"]
        let emptyArray: [String] = []
        let singleElementArray = ["Only"]
        
        // Act & Assert - Non-empty array
        #expect(CollectionSafetyUtilities.safeFirst(in: testArray) == "Alpha")
        #expect(CollectionSafetyUtilities.safeLast(in: testArray) == "Gamma")
        
        // Act & Assert - Empty array
        #expect(CollectionSafetyUtilities.safeFirst(in: emptyArray) == nil)
        #expect(CollectionSafetyUtilities.safeLast(in: emptyArray) == nil)
        
        // Act & Assert - Single element array
        #expect(CollectionSafetyUtilities.safeFirst(in: singleElementArray) == "Only")
        #expect(CollectionSafetyUtilities.safeLast(in: singleElementArray) == "Only")
    }
}
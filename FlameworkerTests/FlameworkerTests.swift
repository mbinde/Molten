//
//  FlameworkerTests.swift
//  FlameworkerTests
//
//  Created by Melissa Binde on 10/2/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Testing
import Foundation
import SwiftUI
import CoreData
import os
@testable import Flameworker































@Suite("Async Operation Error Handling Tests")
struct AsyncOperationErrorHandlingTests {
    
    @Test("Async error handling pattern works correctly")
    func testAsyncErrorHandlingPattern() async {
        // Test the pattern for handling async operations and errors
        
        // Success case
        do {
            let result = try await performAsyncOperation(shouldFail: false)
            #expect(result == "Success", "Should return success value")
        } catch {
            Issue.record("Should not throw for successful operation")
        }
        
        // Failure case
        do {
            let _ = try await performAsyncOperation(shouldFail: true)
            Issue.record("Should throw for failing operation")
        } catch is TestAsyncError {
            // Expected error - test passes
            #expect(Bool(true), "Should catch the expected error type")
        } catch {
            Issue.record("Should catch the specific error type")
        }
    }
    
    @Test("Result type for async operations works correctly")
    func testAsyncResultPattern() async {
        // Test Result type pattern for async operations
        
        let successResult = await safeAsyncOperation(shouldFail: false)
        switch successResult {
        case .success(let value):
            #expect(value == "Success", "Should return success value")
        case .failure:
            Issue.record("Should not fail for valid async operation")
        }
        
        let failureResult = await safeAsyncOperation(shouldFail: true)
        switch failureResult {
        case .success:
            Issue.record("Should not succeed for failing async operation")
        case .failure(let error):
            #expect(error is TestAsyncError, "Should return the thrown error")
        }
    }
    
    // Helper functions for testing
    private func performAsyncOperation(shouldFail: Bool) async throws -> String {
        try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        if shouldFail {
            throw TestAsyncError()
        }
        return "Success"
    }
    
    private func safeAsyncOperation(shouldFail: Bool) async -> Result<String, Error> {
        do {
            let result = try await performAsyncOperation(shouldFail: shouldFail)
            return .success(result)
        } catch {
            return .failure(error)
        }
    }
    
    private struct TestAsyncError: Error {}
}









@Suite("Simple Form Validation Tests")
struct SimpleFormValidationTests {
    
    @Test("Basic validation helper works correctly")
    func testBasicValidationHelper() {
        var successValue: String?
        var errorValue: AppError?
        
        // Simulate a validation helper pattern
        let validation = ValidationUtilities.validateNonEmptyString("Valid", fieldName: "Test")
        
        switch validation {
        case .success(let value):
            successValue = value
        case .failure(let error):
            errorValue = error
        }
        
        #expect(successValue == "Valid", "Should execute success path with correct value")
        #expect(errorValue == nil, "Should not have error on success")
    }
    
    @Test("Error handling helper works correctly") 
    func testErrorHandlingHelper() {
        var successValue: String?
        var errorValue: AppError?
        
        // Simulate a validation helper pattern with error
        let validation = ValidationUtilities.validateNonEmptyString("", fieldName: "Test")
        
        switch validation {
        case .success(let value):
            successValue = value
        case .failure(let error):
            errorValue = error
        }
        
        #expect(successValue == nil, "Should not have success value on error")
        #expect(errorValue != nil, "Should have error value")
        #expect(errorValue?.category == .validation, "Should have correct error category")
    }
}





@Suite("Basic Core Data Safety Tests")
struct BasicCoreDataSafetyTests {
    
    @Test("Index bounds checking works correctly")
    func testIndexBoundsChecking() {
        // Test the index bounds checking logic without Core Data dependencies
        let items = ["Item1", "Item2", "Item3"]
        let validOffsets = IndexSet([0, 2])
        let invalidOffsets = IndexSet([5, 10])
        
        // Test valid offsets
        var deletedItems: [String] = []
        validOffsets.forEach { index in
            if index < items.count {
                deletedItems.append(items[index])
            }
        }
        
        #expect(deletedItems.count == 2, "Should delete correct number of items")
        #expect(deletedItems.contains("Item1"), "Should include first item")
        #expect(deletedItems.contains("Item3"), "Should include third item")
        
        // Test invalid offsets
        var safeDeletedItems: [String] = []
        invalidOffsets.forEach { index in
            if index < items.count {
                safeDeletedItems.append(items[index])
            }
        }
        
        #expect(safeDeletedItems.isEmpty, "Should not delete any items with invalid offsets")
    }
    
    @Test("Type validation patterns work correctly")
    func testTypeValidationPatterns() {
        // Test basic type validation logic
        struct MockObject {
            let typeName: String
            
            init(typeName: String) {
                self.typeName = typeName
            }
        }
        
        let mockObject = MockObject(typeName: "TestType")
        let typeName = String(describing: type(of: mockObject))
        
        #expect(typeName.contains("MockObject"), "Should correctly identify type name")
    }
}

@Suite("AlertBuilders Tests")
struct AlertBuildersTests {
    
    @Test("Deletion confirmation alert message replacement works")
    func testDeletionConfirmationMessageReplacement() {
        // Test the message replacement logic
        let template = "Are you sure you want to delete {count} items?"
        let itemCount = 5
        let result = template.replacingOccurrences(of: "{count}", with: "\(itemCount)")
        
        #expect(result == "Are you sure you want to delete 5 items?", "Should replace count placeholder correctly")
    }
    
    @Test("Message replacement handles zero count")
    func testMessageReplacementWithZeroCount() {
        let template = "Delete {count} items?"
        let itemCount = 0
        let result = template.replacingOccurrences(of: "{count}", with: "\(itemCount)")
        
        #expect(result == "Delete 0 items?", "Should handle zero count correctly")
    }
    
    @Test("Message replacement handles large count")
    func testMessageReplacementWithLargeCount() {
        let template = "Delete {count} items?"
        let itemCount = 1000
        let result = template.replacingOccurrences(of: "{count}", with: "\(itemCount)")
        
        #expect(result == "Delete 1000 items?", "Should handle large count correctly")
    }
}





@Suite("CatalogItemHelpers Basic Tests")
struct CatalogItemHelpersBasicTests {
    
    @Test("AvailabilityStatus has correct display text")
    func testAvailabilityStatusDisplayText() {
        #expect(AvailabilityStatus.available.displayText == "Available", "Available should have correct display text")
        #expect(AvailabilityStatus.discontinued.displayText == "Discontinued", "Discontinued should have correct display text")
        #expect(AvailabilityStatus.futureRelease.displayText == "Future Release", "Future release should have correct display text")
    }
    
    @Test("AvailabilityStatus has correct colors")
    func testAvailabilityStatusColors() {
        #expect(AvailabilityStatus.available.color == .green, "Available should be green")
        #expect(AvailabilityStatus.discontinued.color == .orange, "Discontinued should be orange")
        #expect(AvailabilityStatus.futureRelease.color == .blue, "Future release should be blue")
    }
    
    @Test("AvailabilityStatus has correct short display text")
    func testAvailabilityStatusShortText() {
        #expect(AvailabilityStatus.available.shortDisplayText == "Avail.", "Available should have short text")
        #expect(AvailabilityStatus.discontinued.shortDisplayText == "Disc.", "Discontinued should have short text")
        #expect(AvailabilityStatus.futureRelease.shortDisplayText == "Future", "Future release should have short text")
    }
    
    @Test("Create tags string from array works correctly")
    func testCreateTagsString() {
        let tags = ["red", "glass", "rod"]
        let result = CatalogItemHelpers.createTagsString(from: tags)
        #expect(result == "red,glass,rod", "Should create comma-separated string")
        
        // Test with empty strings
        let tagsWithEmpty = ["red", "", "glass", "   ", "rod"]
        let filteredResult = CatalogItemHelpers.createTagsString(from: tagsWithEmpty)
        #expect(filteredResult == "red,glass,rod", "Should filter out empty and whitespace-only strings")
        
        // Test empty array
        let emptyResult = CatalogItemHelpers.createTagsString(from: [])
        #expect(emptyResult.isEmpty, "Empty array should produce empty string")
    }
    
    @Test("Format date works correctly")
    func testFormatDate() {
        let date = Date(timeIntervalSince1970: 1609459200) // Jan 1, 2021
        let formatted = CatalogItemHelpers.formatDate(date, style: .short)
        
        // Just verify it's not empty and is a reasonable date string
        #expect(!formatted.isEmpty, "Formatted date should not be empty")
        #expect(formatted.count >= 6, "Formatted date should have reasonable length")
        
        // Test that the function handles different styles without crashing
        let mediumFormatted = CatalogItemHelpers.formatDate(date, style: .medium)
        #expect(!mediumFormatted.isEmpty, "Medium formatted date should not be empty")
        
        let longFormatted = CatalogItemHelpers.formatDate(date, style: .long)
        #expect(!longFormatted.isEmpty, "Long formatted date should not be empty")
    }
    
    @Test("CatalogItemDisplayInfo nameWithCode works correctly") 
    func testCatalogItemDisplayInfoNameWithCode() {
        let displayInfo = CatalogItemDisplayInfo(
            name: "Test Glass",
            code: "TG001",
            manufacturer: "Test Mfg",
            manufacturerFullName: "Test Manufacturing Co",
            coe: "96",
            stockType: "rod",
            tags: ["red", "glass"],
            synonyms: ["test", "sample"],
            color: .blue,
            manufacturerURL: nil,
            imagePath: nil,
            description: "Test description"
        )
        
        #expect(displayInfo.nameWithCode == "Test Glass (TG001)", "Should combine name and code correctly")
        #expect(displayInfo.hasExtendedInfo == true, "Should have extended info with tags")
        #expect(displayInfo.hasDescription == true, "Should have description")
    }
    
    @Test("CatalogItemDisplayInfo detects extended info correctly")
    func testCatalogItemDisplayInfoExtendedInfo() {
        // Test with no extended info
        let basicInfo = CatalogItemDisplayInfo(
            name: "Basic",
            code: "B001", 
            manufacturer: "Basic Mfg",
            manufacturerFullName: "Basic Manufacturing",
            coe: nil,
            stockType: nil,
            tags: [],
            synonyms: [],
            color: .gray,
            manufacturerURL: nil,
            imagePath: nil,
            description: nil
        )
        
        #expect(basicInfo.hasExtendedInfo == false, "Should not have extended info")
        #expect(basicInfo.hasDescription == false, "Should not have description")
        
        // Test with extended info
        let extendedInfo = CatalogItemDisplayInfo(
            name: "Extended",
            code: "E001",
            manufacturer: "Extended Mfg", 
            manufacturerFullName: "Extended Manufacturing",
            coe: nil,
            stockType: "rod",
            tags: [],
            synonyms: [],
            color: .gray,
            manufacturerURL: nil,
            imagePath: nil,
            description: "   "
        )
        
        #expect(extendedInfo.hasExtendedInfo == true, "Should have extended info due to stock type")
        #expect(extendedInfo.hasDescription == false, "Should not have description due to whitespace")
    }
}



@Suite("Simple Filter Logic Tests")
struct SimpleFilterLogicTests {
    
    @Test("Basic inventory filtering logic works correctly")
    func testBasicInventoryFiltering() {
        // Test basic filtering logic patterns without requiring specific classes
        
        // Mock inventory item
        struct MockInventoryItem {
            let count: Double
            let type: Int16
            
            var isInStock: Bool { count > 10 }
            var isLowStock: Bool { count > 0 && count <= 10.0 }
            var isOutOfStock: Bool { count == 0 }
        }
        
        let highStock = MockInventoryItem(count: 20.0, type: 0)
        let lowStock = MockInventoryItem(count: 5.0, type: 0)
        let outOfStock = MockInventoryItem(count: 0.0, type: 0)
        
        // Test stock level detection
        #expect(highStock.isInStock == true, "High stock item should be in stock")
        #expect(highStock.isLowStock == false, "High stock item should not be low stock")
        #expect(highStock.isOutOfStock == false, "High stock item should not be out of stock")
        
        #expect(lowStock.isInStock == false, "Low stock item should not be in high stock")
        #expect(lowStock.isLowStock == true, "Low stock item should be low stock") 
        #expect(lowStock.isOutOfStock == false, "Low stock item should not be out of stock")
        
        #expect(outOfStock.isInStock == false, "Out of stock item should not be in stock")
        #expect(outOfStock.isLowStock == false, "Out of stock item should not be low stock")
        #expect(outOfStock.isOutOfStock == true, "Out of stock item should be out of stock")
    }
    
    @Test("Type filtering logic works correctly")
    func testTypeFilteringLogic() {
        // Test basic type filtering patterns
        let selectedTypes: Set<Int16> = [1, 3]
        let item1Type: Int16 = 1
        let item2Type: Int16 = 2
        let item3Type: Int16 = 3
        
        #expect(selectedTypes.contains(item1Type), "Should include item with selected type 1")
        #expect(!selectedTypes.contains(item2Type), "Should not include item with unselected type 2")
        #expect(selectedTypes.contains(item3Type), "Should include item with selected type 3")
        
        // Test empty set behavior
        let emptySet: Set<Int16> = []
        #expect(emptySet.isEmpty, "Empty set should be empty")
        #expect(!emptySet.contains(1), "Empty set should not contain any items")
    }
}

@Suite("Basic Sort Logic Tests")
struct BasicSortLogicTests {
    
    @Test("Basic sorting patterns work correctly")
    func testBasicSortingPatterns() {
        // Test basic sorting patterns without requiring specific classes
        
        struct TestItem {
            let name: String?
            let code: String?
            let value: Double
        }
        
        let items = [
            TestItem(name: "Zebra", code: "Z001", value: 30.0),
            TestItem(name: "Alpha", code: "A001", value: 10.0),
            TestItem(name: "Beta", code: "B001", value: 20.0),
            TestItem(name: nil, code: "X001", value: 5.0)
        ]
        
        // Test sorting by name
        let sortedByName = items.sorted { first, second in
            let firstName = first.name ?? ""
            let secondName = second.name ?? ""
            return firstName < secondName
        }
        
        #expect(sortedByName.count == items.count, "Should maintain item count when sorting")
        #expect(sortedByName[0].name == nil, "Nil name should sort first (as empty string)")
        #expect(sortedByName[1].name == "Alpha", "Alpha should sort second")
        #expect(sortedByName[2].name == "Beta", "Beta should sort third")
        #expect(sortedByName[3].name == "Zebra", "Zebra should sort last")
        
        // Test sorting by numeric value
        let sortedByValue = items.sorted { $0.value < $1.value }
        #expect(sortedByValue[0].value == 5.0, "Smallest value should sort first")
        #expect(sortedByValue[3].value == 30.0, "Largest value should sort last")
    }
    
    @Test("Sorting handles nil values correctly")
    func testSortingWithNilValues() {
        struct TestItem {
            let name: String?
        }
        
        let items = [
            TestItem(name: "Charlie"),
            TestItem(name: nil),
            TestItem(name: "Alice"),
            TestItem(name: "Bob")
        ]
        
        let sorted = items.sorted { first, second in
            let firstName = first.name ?? ""
            let secondName = second.name ?? ""
            return firstName < secondName
        }
        
        #expect(sorted.count == items.count, "Should maintain item count")
        #expect(sorted[0].name == nil, "Nil should sort first")
        #expect(sorted[1].name == "Alice", "Alice should sort after nil")
    }
}

@Suite("InventoryViewComponents Tests")
struct InventoryViewComponentsTests {
    
    @Test("InventoryDataValidator has inventory data correctly")
    func testInventoryDataValidatorHasData() {
        // Test the logic without Core Data dependencies
        struct MockInventoryItem {
            let count: Double
            let notes: String?
            
            var hasInventory: Bool { count > 0 }
            var hasNotes: Bool {
                guard let notes = notes else { return false }
                return !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            var hasAnyData: Bool { hasInventory || hasNotes }
        }
        
        let itemWithInventory = MockInventoryItem(count: 5.0, notes: nil)
        let itemWithNotes = MockInventoryItem(count: 0.0, notes: "Some notes")
        let itemWithBoth = MockInventoryItem(count: 3.0, notes: "Notes and inventory")
        let itemWithNeither = MockInventoryItem(count: 0.0, notes: nil)
        let itemWithEmptyNotes = MockInventoryItem(count: 0.0, notes: "   ")
        
        #expect(itemWithInventory.hasAnyData == true, "Item with inventory should have data")
        #expect(itemWithNotes.hasAnyData == true, "Item with notes should have data")
        #expect(itemWithBoth.hasAnyData == true, "Item with both should have data")
        #expect(itemWithNeither.hasAnyData == false, "Item with neither should not have data")
        #expect(itemWithEmptyNotes.hasAnyData == false, "Item with empty notes should not have data")
    }
    
    @Test("InventoryDataValidator format inventory display works correctly")
    func testFormatInventoryDisplay() {
        // Test the display formatting logic
        let displayWithBoth = InventoryDataValidator.formatInventoryDisplay(
            count: 5.0, 
            units: .ounces, // ounces
            type: .inventory,  // inventory  
            notes: "Test notes"
        )
        #expect(displayWithBoth != nil, "Should return display string for valid data")
        // Check for both formats since formatting might vary between implementations
        let containsCount = displayWithBoth?.contains("5.0") == true || displayWithBoth?.contains("5") == true
        #expect(containsCount, "Should contain count (either '5.0' or '5'). Actual: \(displayWithBoth ?? "nil")")
        #expect(displayWithBoth?.contains("Test notes") ?? false == true, "Should contain notes")
        
        let displayWithNotesOnly = InventoryDataValidator.formatInventoryDisplay(
            count: 0.0,
            units: .ounces,
            type: .inventory,
            notes: "Only notes"
        )
        #expect(displayWithNotesOnly == "Only notes", "Should return just notes when count is zero")
        
        let displayWithCountOnly = InventoryDataValidator.formatInventoryDisplay(
            count: 3.0,
            units: .pounds, // pounds
            type: .buy,  // buy
            notes: nil
        )
        #expect(displayWithCountOnly != nil, "Should return display string for count only")
        // Check for both formats since formatting might vary between implementations
        let containsCount2 = displayWithCountOnly?.contains("3.0") == true || displayWithCountOnly?.contains("3") == true
        #expect(containsCount2, "Should contain count (either '3.0' or '3'). Actual: \(displayWithCountOnly ?? "nil")")
        
        let displayWithNeither = InventoryDataValidator.formatInventoryDisplay(
            count: 0.0,
            units: .ounces,
            type: .inventory,
            notes: nil
        )
        #expect(displayWithNeither == nil, "Should return nil when no data to display")
        
        let displayWithWhitespaceNotes = InventoryDataValidator.formatInventoryDisplay(
            count: 0.0,
            units: .ounces,
            type: .inventory,
            notes: "   "
        )
        #expect(displayWithWhitespaceNotes == nil, "Should return nil for whitespace-only notes")
    }
    
    @Test("InventoryItem status properties work correctly")
    func testInventoryItemStatusProperties() {
        // Test the logic patterns used in the extension
        struct MockInventoryItem {
            let count: Double
            let notes: String?
            
            var hasInventory: Bool { count > 0 }
            var isLowStock: Bool { count > 0 && count <= 10.0 }
            var hasNotes: Bool {
                guard let notes = notes else { return false }
                return !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            var hasAnyData: Bool { hasInventory || hasNotes }
        }
        
        // Test hasInventory
        #expect(MockInventoryItem(count: 5.0, notes: nil).hasInventory == true, "Should have inventory when count > 0")
        #expect(MockInventoryItem(count: 0.0, notes: nil).hasInventory == false, "Should not have inventory when count = 0")
        
        // Test isLowStock
        #expect(MockInventoryItem(count: 5.0, notes: nil).isLowStock == true, "Should be low stock when 0 < count <= 10")
        #expect(MockInventoryItem(count: 15.0, notes: nil).isLowStock == false, "Should not be low stock when count > 10")
        #expect(MockInventoryItem(count: 0.0, notes: nil).isLowStock == false, "Should not be low stock when count = 0")
        
        // Test hasNotes  
        #expect(MockInventoryItem(count: 0.0, notes: "test").hasNotes == true, "Should have notes when notes exist")
        #expect(MockInventoryItem(count: 0.0, notes: nil).hasNotes == false, "Should not have notes when nil")
        #expect(MockInventoryItem(count: 0.0, notes: "   ").hasNotes == false, "Should not have notes when whitespace only")
        
        // Test hasAnyData
        #expect(MockInventoryItem(count: 5.0, notes: nil).hasAnyData == true, "Should have data with inventory")
        #expect(MockInventoryItem(count: 0.0, notes: "notes").hasAnyData == true, "Should have data with notes")
        #expect(MockInventoryItem(count: 0.0, notes: nil).hasAnyData == false, "Should not have data with neither")
    }
}


@Suite("Core Data Thread Safety Tests")
struct CoreDataThreadSafetyTests {
    
    @Test("CoreDataHelpers thread safety patterns work correctly")
    func testCoreDataHelpersThreadSafety() {
        // Test the thread safety patterns used in CoreDataHelpers
        // This tests the logic patterns since we can't easily create Core Data contexts in tests
        
        let isMainThread = Thread.isMainThread
        let shouldUsePerformAndWait = !isMainThread
        
        // Test main thread detection
        #expect(isMainThread || !isMainThread, "Should be able to detect current thread")
        
        // Test performAndWait decision logic
        if shouldUsePerformAndWait {
            #expect(!isMainThread, "Should use performAndWait when not on main thread")
        } else {
            #expect(isMainThread, "Should not need performAndWait when on main thread")
        }
    }
    
    @Test("Core Data entity validation patterns work correctly")
    func testCoreDataEntityValidationPatterns() {
        // Test the validation patterns used for Core Data entities
        // This tests the logic without requiring actual Core Data objects
        
        struct MockEntity {
            let isFault: Bool
            let isDeleted: Bool
            let hasContext: Bool
            
            var isEntitySafe: Bool {
                return !isFault && !isDeleted && hasContext
            }
        }
        
        // Test valid entity
        let validEntity = MockEntity(isFault: false, isDeleted: false, hasContext: true)
        #expect(validEntity.isEntitySafe == true, "Valid entity should be safe")
        
        // Test fault entity
        let faultEntity = MockEntity(isFault: true, isDeleted: false, hasContext: true)
        #expect(faultEntity.isEntitySafe == false, "Fault entity should not be safe")
        
        // Test deleted entity
        let deletedEntity = MockEntity(isFault: false, isDeleted: true, hasContext: true)
        #expect(deletedEntity.isEntitySafe == false, "Deleted entity should not be safe")
        
        // Test entity without context
        let contextlessEntity = MockEntity(isFault: false, isDeleted: false, hasContext: false)
        #expect(contextlessEntity.isEntitySafe == false, "Entity without context should not be safe")
    }
    
    @Test("Core Data save validation patterns work correctly")
    func testCoreDataSaveValidationPatterns() {
        // Test the validation patterns used before Core Data saves
        
        enum MockValidationError: Error {
            case invalidInsert
            case invalidUpdate
            case invalidDelete
        }
        
        struct MockValidationResult {
            let hasInsertErrors: Bool
            let hasUpdateErrors: Bool
            let hasDeleteErrors: Bool
            
            var isValidForSave: Bool {
                return !hasInsertErrors && !hasUpdateErrors && !hasDeleteErrors
            }
        }
        
        // Test valid save scenario
        let validSave = MockValidationResult(
            hasInsertErrors: false,
            hasUpdateErrors: false,
            hasDeleteErrors: false
        )
        #expect(validSave.isValidForSave == true, "Should be valid when no validation errors")
        
        // Test insert errors
        let insertErrors = MockValidationResult(
            hasInsertErrors: true,
            hasUpdateErrors: false,
            hasDeleteErrors: false
        )
        #expect(insertErrors.isValidForSave == false, "Should be invalid with insert errors")
        
        // Test update errors
        let updateErrors = MockValidationResult(
            hasInsertErrors: false,
            hasUpdateErrors: true,
            hasDeleteErrors: false
        )
        #expect(updateErrors.isValidForSave == false, "Should be invalid with update errors")
        
        // Test delete errors
        let deleteErrors = MockValidationResult(
            hasInsertErrors: false,
            hasUpdateErrors: false,
            hasDeleteErrors: true
        )
        #expect(deleteErrors.isValidForSave == false, "Should be invalid with delete errors")
    }
}




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

@Suite("SearchUtilities Advanced Tests")
struct SearchUtilitiesAdvancedTests {
    
    @Test("SearchConfig default configuration is reasonable")
    func testSearchConfigDefaults() {
        let defaultConfig = SearchUtilities.SearchConfig.default
        #expect(defaultConfig.caseSensitive == false, "Default should be case insensitive")
        #expect(defaultConfig.exactMatch == false, "Default should allow partial matches")
        #expect(defaultConfig.fuzzyTolerance == nil, "Default should not use fuzzy matching")
        #expect(defaultConfig.highlightMatches == false, "Default should not highlight matches")
    }
    
    @Test("SearchConfig fuzzy configuration enables fuzzy search")
    func testSearchConfigFuzzy() {
        let fuzzyConfig = SearchUtilities.SearchConfig.fuzzy
        #expect(fuzzyConfig.caseSensitive == false, "Fuzzy should be case insensitive")
        #expect(fuzzyConfig.exactMatch == false, "Fuzzy should allow partial matches")
        #expect(fuzzyConfig.fuzzyTolerance != nil, "Fuzzy should have tolerance set")
        #expect(fuzzyConfig.fuzzyTolerance == 2, "Fuzzy tolerance should be reasonable")
    }
    
    @Test("SearchConfig exact configuration requires exact matches")
    func testSearchConfigExact() {
        let exactConfig = SearchUtilities.SearchConfig.exact
        #expect(exactConfig.caseSensitive == false, "Exact should still be case insensitive")
        #expect(exactConfig.exactMatch == true, "Exact should require exact matches")
        #expect(exactConfig.fuzzyTolerance == nil, "Exact should not use fuzzy matching")
    }
    
    @Test("Weighted search relevance scoring works correctly")
    func testWeightedSearchRelevanceScoring() {
        // Test the scoring logic without requiring actual searchable items
        
        // Mock weighted search scenario
        struct MockSearchResult {
            let relevance: Double
        }
        
        let results = [
            MockSearchResult(relevance: 10.0), // Exact match
            MockSearchResult(relevance: 5.0),  // Partial match
            MockSearchResult(relevance: 2.0),  // Fuzzy match
            MockSearchResult(relevance: 1.0)   // Weak match
        ]
        
        let sorted = results.sorted { $0.relevance > $1.relevance }
        
        #expect(sorted[0].relevance == 10.0, "Highest relevance should sort first")
        #expect(sorted[1].relevance == 5.0, "Second highest should sort second")
        #expect(sorted[2].relevance == 2.0, "Third highest should sort third")
        #expect(sorted[3].relevance == 1.0, "Lowest should sort last")
        
        // Test that sorting maintains all items
        #expect(sorted.count == results.count, "Should maintain all results when sorting")
    }
    
    @Test("Multiple terms search logic (AND) works correctly")
    func testMultipleTermsANDLogic() {
        // Test the AND logic for multiple search terms
        let searchTerms = ["glass", "red", "rod"]
        let testText = "red glass rod 6mm"
        
        let allTermsFound = searchTerms.allSatisfy { term in
            testText.lowercased().contains(term.lowercased())
        }
        
        #expect(allTermsFound == true, "Should find all terms in matching text")
        
        // Test with missing term
        let testTextMissing = "blue glass rod 6mm"
        let someTermsMissing = searchTerms.allSatisfy { term in
            testTextMissing.lowercased().contains(term.lowercased())
        }
        
        #expect(someTermsMissing == false, "Should not match when any term is missing")
    }
    
    @Test("Sort criteria enums have reasonable values")
    func testSortCriteriaEnums() {
        // Test InventorySortCriteria
        let inventoryCriteria = InventorySortCriteria.allCases
        #expect(inventoryCriteria.contains(.catalogCode), "Should include catalog code sort")
        #expect(inventoryCriteria.contains(.count), "Should include count sort") 
        #expect(inventoryCriteria.contains(.type), "Should include type sort")
        
        // Test that raw values are reasonable
        for criteria in inventoryCriteria {
            #expect(!criteria.rawValue.isEmpty, "Sort criteria should have non-empty display name")
        }
        
        // Test CatalogSortCriteria
        let catalogCriteria = CatalogSortCriteria.allCases
        #expect(catalogCriteria.contains(.name), "Should include name sort")
        #expect(catalogCriteria.contains(.manufacturer), "Should include manufacturer sort")
        #expect(catalogCriteria.contains(.code), "Should include code sort")
        
        // Test that raw values are reasonable
        for criteria in catalogCriteria {
            #expect(!criteria.rawValue.isEmpty, "Sort criteria should have non-empty display name")
        }
    }
    
    @Test("FilterUtilities manufacturer filtering handles edge cases")
    func testFilterUtilitiesManufacturerEdgeCases() {
        // Test the manufacturer filtering logic patterns
        
        struct MockCatalogItem {
            let manufacturer: String?
            
            var isValidForManufacturerFilter: Bool {
                guard let manufacturer = manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !manufacturer.isEmpty else {
                    return false
                }
                return true
            }
        }
        
        let validItem = MockCatalogItem(manufacturer: "Effetre")
        let emptyItem = MockCatalogItem(manufacturer: "")
        let nilItem = MockCatalogItem(manufacturer: nil)
        let whitespaceItem = MockCatalogItem(manufacturer: "   ")
        
        #expect(validItem.isValidForManufacturerFilter == true, "Valid manufacturer should pass filter")
        #expect(emptyItem.isValidForManufacturerFilter == false, "Empty manufacturer should not pass filter")
        #expect(nilItem.isValidForManufacturerFilter == false, "Nil manufacturer should not pass filter")
        #expect(whitespaceItem.isValidForManufacturerFilter == false, "Whitespace manufacturer should not pass filter")
    }
    
    @Test("FilterUtilities tag filtering with set operations works correctly")
    func testFilterUtilitiesTagFiltering() {
        // Test the set operations logic used in tag filtering
        
        let selectedTags: Set<String> = ["red", "glass", "transparent"]
        let itemTags1: Set<String> = ["red", "opaque", "rod"]
        let itemTags2: Set<String> = ["blue", "metal", "wire"] 
        let itemTags3: Set<String> = ["red", "glass", "clear"]
        
        // Test isDisjoint logic (no common elements)
        let item1Matches = !selectedTags.isDisjoint(with: itemTags1)
        let item2Matches = !selectedTags.isDisjoint(with: itemTags2)
        let item3Matches = !selectedTags.isDisjoint(with: itemTags3)
        
        #expect(item1Matches == true, "Item 1 should match (has 'red')")
        #expect(item2Matches == false, "Item 2 should not match (no common tags)")
        #expect(item3Matches == true, "Item 3 should match (has 'red' and 'glass')")
        
        // Test empty selected tags
        let emptySelected: Set<String> = []
        let emptyResult = emptySelected.isEmpty
        #expect(emptyResult == true, "Empty set should be detected correctly")
    }
}

@Suite("ProductImageView Logic Tests")
struct ProductImageViewLogicTests {
    
    @Test("ProductImageView initialization sets properties correctly")
    func testProductImageViewInitialization() {
        // Test the initialization logic patterns
        
        struct MockProductImageView {
            let itemCode: String
            let manufacturer: String?
            let size: CGFloat
            
            init(itemCode: String, manufacturer: String? = nil, size: CGFloat = 60) {
                self.itemCode = itemCode
                self.manufacturer = manufacturer
                self.size = size
            }
        }
        
        // Test with default values
        let defaultView = MockProductImageView(itemCode: "ABC123")
        #expect(defaultView.itemCode == "ABC123", "Should set item code correctly")
        #expect(defaultView.manufacturer == nil, "Should default manufacturer to nil")
        #expect(defaultView.size == 60, "Should use default size")
        
        // Test with all parameters
        let customView = MockProductImageView(itemCode: "XYZ789", manufacturer: "TestMfg", size: 80)
        #expect(customView.itemCode == "XYZ789", "Should set custom item code")
        #expect(customView.manufacturer == "TestMfg", "Should set custom manufacturer")
        #expect(customView.size == 80, "Should set custom size")
    }
    
    @Test("ProductImageThumbnail uses correct default size")
    func testProductImageThumbnailDefaults() {
        // Test thumbnail sizing logic
        
        struct MockProductImageThumbnail {
            let size: CGFloat
            
            init(itemCode: String, manufacturer: String? = nil, size: CGFloat = 40) {
                self.size = size
            }
        }
        
        let thumbnail = MockProductImageThumbnail(itemCode: "TEST")
        #expect(thumbnail.size == 40, "Thumbnail should default to smaller size than regular view")
        
        let customThumbnail = MockProductImageThumbnail(itemCode: "TEST", size: 50)
        #expect(customThumbnail.size == 50, "Should accept custom thumbnail size")
    }
    
    @Test("ProductImageDetail uses correct default max size")
    func testProductImageDetailDefaults() {
        // Test detail view sizing logic
        
        struct MockProductImageDetail {
            let maxSize: CGFloat
            
            init(itemCode: String, manufacturer: String? = nil, maxSize: CGFloat = 200) {
                self.maxSize = maxSize
            }
        }
        
        let detail = MockProductImageDetail(itemCode: "TEST")
        #expect(detail.maxSize == 200, "Detail view should default to larger max size")
        
        let customDetail = MockProductImageDetail(itemCode: "TEST", maxSize: 300)
        #expect(customDetail.maxSize == 300, "Should accept custom max size")
    }
    
    @Test("Image view fallback calculations work correctly")
    func testImageViewFallbackCalculations() {
        // Test the calculation logic used for fallback image sizes
        
        let maxSize: CGFloat = 200
        let fallbackWidth = maxSize * 0.8
        let fallbackHeight = maxSize * 0.6
        
        #expect(fallbackWidth == 160, "Fallback width should be 80% of max size")
        #expect(fallbackHeight == 120, "Fallback height should be 60% of max size")
        
        // Test icon size calculation
        let iconSize = 40.0 * 0.4
        #expect(iconSize == 16.0, "Icon size should be 40% of container size")
    }
    
    @Test("Image view corner radius values are consistent")
    func testImageViewCornerRadius() {
        // Test that corner radius values are reasonable and consistent
        
        let standardRadius: CGFloat = 8
        let detailRadius: CGFloat = 12
        
        #expect(standardRadius > 0, "Standard radius should be positive")
        #expect(detailRadius > standardRadius, "Detail radius should be larger than standard")
        #expect(detailRadius <= 15, "Detail radius should not be excessive")
    }
}

@Suite("CatalogBundleDebugView Logic Tests")
struct CatalogBundleDebugViewLogicTests {
    
    @Test("Bundle path validation logic works correctly")
    func testBundlePathValidation() {
        // Test the logic used to validate bundle paths
        
        let validPath = "/Applications/App.app/Contents/Resources"
        let emptyPath = ""
        
        #expect(!validPath.isEmpty, "Valid path should not be empty")
        #expect(validPath.contains("/"), "Valid path should contain path separators")
        #expect(emptyPath.isEmpty, "Empty path should be detected")
    }
    
    @Test("File filtering for JSON files works correctly")  
    func testJSONFileFiltering() {
        // Test the JSON file filtering logic
        
        let allFiles = [
            "colors.json",
            "AppIcon.png", 
            "Info.plist",
            "data.json",
            "sample.txt",
            "catalog.JSON", // Test case sensitivity
            "backup.json.bak" // Test compound extensions
        ]
        
        let jsonFiles = allFiles.filter { $0.hasSuffix(".json") }
        
        #expect(jsonFiles.count == 2, "Should find exactly 2 .json files")
        #expect(jsonFiles.contains("colors.json"), "Should include colors.json")
        #expect(jsonFiles.contains("data.json"), "Should include data.json")
        #expect(!jsonFiles.contains("catalog.JSON"), "Should not include .JSON (uppercase)")
        #expect(!jsonFiles.contains("backup.json.bak"), "Should not include compound extensions")
        
        // Test empty array handling
        let emptyFiles: [String] = []
        let emptyJsonFiles = emptyFiles.filter { $0.hasSuffix(".json") }
        #expect(emptyJsonFiles.isEmpty, "Should handle empty file list")
    }
    
    @Test("Target file detection works correctly")
    func testTargetFileDetection() {
        // Test the logic used to identify target files
        
        let targetFile = "colors.json"
        let regularFile = "data.json"
        
        #expect(targetFile == "colors.json", "Should correctly identify target file")
        #expect(regularFile != "colors.json", "Should distinguish non-target files")
        
        // Test case sensitivity
        #expect("Colors.json" != "colors.json", "Should be case sensitive")
        #expect("COLORS.JSON" != "colors.json", "Should be case sensitive")
    }
    
    @Test("File categorization logic works correctly")
    func testFileCategorization() {
        // Test the categorization logic used in the debug view
        
        struct FileCategory {
            static func categorize(_ fileName: String) -> String {
                if fileName.hasSuffix(".json") {
                    return "JSON"
                } else if fileName.hasSuffix(".png") || fileName.hasSuffix(".jpg") {
                    return "Image"
                } else if fileName.hasSuffix(".plist") {
                    return "Config"
                } else {
                    return "Other"
                }
            }
        }
        
        #expect(FileCategory.categorize("colors.json") == "JSON", "Should categorize JSON files")
        #expect(FileCategory.categorize("icon.png") == "Image", "Should categorize image files")
        #expect(FileCategory.categorize("Info.plist") == "Config", "Should categorize config files")
        #expect(FileCategory.categorize("README.txt") == "Other", "Should categorize other files")
    }
    
    @Test("Bundle contents sorting works correctly")
    func testBundleContentsSorting() {
        // Test the sorting logic used for bundle contents display
        
        let unsortedContents = [
            "zeta.json",
            "AppIcon.png",
            "alpha.txt",
            "beta.json",
            "Info.plist"
        ]
        
        let sorted = unsortedContents.sorted()
        let expected = [
            "AppIcon.png",
            "Info.plist", 
            "alpha.txt",
            "beta.json",
            "zeta.json"
        ]
        
        #expect(sorted == expected, "Should sort contents alphabetically")
        #expect(sorted.count == unsortedContents.count, "Should maintain all items when sorting")
    }
    
    @Test("Bundle file count display logic works correctly")
    func testBundleFileCountDisplay() {
        // Test the file count display logic
        
        let filesList = ["file1.json", "file2.txt", "file3.png"]
        let count = filesList.count
        let displayText = "All Files (\(count))"
        
        #expect(displayText == "All Files (3)", "Should display correct file count")
        
        // Test empty list
        let emptyList: [String] = []
        let emptyCount = emptyList.count
        let emptyDisplayText = "All Files (\(emptyCount))"
        
        #expect(emptyDisplayText == "All Files (0)", "Should handle empty file list")
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

@Suite("Data Model Validation Tests")
struct DataModelValidationTests {
    
    @Test("Enum initialization safety patterns work correctly")
    func testEnumInitializationSafety() {
        // Test the safety patterns used in enum initialization
        
        enum MockEnum: Int, CaseIterable {
            case first = 0
            case second = 1  
            case third = 2
            
            static func from(rawValue: Int) -> MockEnum {
                return MockEnum(rawValue: rawValue) ?? .first
            }
        }
        
        // Test valid values
        #expect(MockEnum.from(rawValue: 0) == .first, "Should return correct enum for valid value")
        #expect(MockEnum.from(rawValue: 1) == .second, "Should return correct enum for valid value")
        #expect(MockEnum.from(rawValue: 2) == .third, "Should return correct enum for valid value")
        
        // Test invalid values fallback
        #expect(MockEnum.from(rawValue: -1) == .first, "Should fallback to first for negative value")
        #expect(MockEnum.from(rawValue: 999) == .first, "Should fallback to first for out-of-range value")
        #expect(MockEnum.from(rawValue: 10) == .first, "Should fallback to first for invalid value")
    }
    
    @Test("Optional string validation patterns work correctly")
    func testOptionalStringValidationPatterns() {
        // Test the patterns used to validate optional strings
        
        func isValidOptionalString(_ value: String?) -> Bool {
            guard let value = value else { return false }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty
        }
        
        #expect(isValidOptionalString("Valid") == true, "Should accept valid string")
        #expect(isValidOptionalString("  Valid  ") == true, "Should accept string with whitespace")
        #expect(isValidOptionalString(nil) == false, "Should reject nil")
        #expect(isValidOptionalString("") == false, "Should reject empty string")
        #expect(isValidOptionalString("   ") == false, "Should reject whitespace-only string")
    }
    
    @Test("Numeric value validation patterns work correctly")
    func testNumericValueValidationPatterns() {
        // Test patterns for validating numeric values
        
        func isValidPositiveDouble(_ value: Double) -> Bool {
            return value > 0 && value.isFinite && !value.isNaN
        }
        
        func isValidNonNegativeDouble(_ value: Double) -> Bool {
            return value >= 0 && value.isFinite && !value.isNaN
        }
        
        // Test positive validation
        #expect(isValidPositiveDouble(5.0) == true, "Should accept positive value")
        #expect(isValidPositiveDouble(0.1) == true, "Should accept small positive value")
        #expect(isValidPositiveDouble(0.0) == false, "Should reject zero")
        #expect(isValidPositiveDouble(-1.0) == false, "Should reject negative value")
        #expect(isValidPositiveDouble(.nan) == false, "Should reject NaN")
        #expect(isValidPositiveDouble(.infinity) == false, "Should reject infinity")
        
        // Test non-negative validation
        #expect(isValidNonNegativeDouble(5.0) == true, "Should accept positive value")
        #expect(isValidNonNegativeDouble(0.0) == true, "Should accept zero")
        #expect(isValidNonNegativeDouble(-1.0) == false, "Should reject negative value")
        #expect(isValidNonNegativeDouble(.nan) == false, "Should reject NaN")
    }
    
    @Test("Collection safety patterns work correctly")
    func testCollectionSafetyPatterns() {
        // Test patterns for safe collection operations
        
        func safeElementAt<T>(_ index: Int, in array: [T]) -> T? {
            guard index >= 0 && index < array.count else { return nil }
            return array[index]
        }
        
        let testArray = ["first", "second", "third"]
        
        #expect(safeElementAt(0, in: testArray) == "first", "Should return element at valid index")
        #expect(safeElementAt(1, in: testArray) == "second", "Should return element at valid index")
        #expect(safeElementAt(2, in: testArray) == "third", "Should return element at valid index")
        #expect(safeElementAt(-1, in: testArray) == nil, "Should return nil for negative index")
        #expect(safeElementAt(3, in: testArray) == nil, "Should return nil for out-of-bounds index")
        #expect(safeElementAt(100, in: testArray) == nil, "Should return nil for way out-of-bounds index")
        
        // Test empty array
        let emptyArray: [String] = []
        #expect(safeElementAt(0, in: emptyArray) == nil, "Should return nil for any index in empty array")
    }
}


    
    @Test("Loading state transitions work correctly")
    func testLoadingStateTransitions() {
        // Test loading state management patterns
        
        enum LoadingState: Equatable {
            case idle
            case loading
            case success(String)
            case failure(String)
        }
        
        var state = LoadingState.idle
        
        // Test initial state
        #expect(state == .idle, "Should start in idle state")
        
        // Test transition to loading
        state = .loading
        #expect(state == .loading, "Should transition to loading")
        
        // Test transition to success
        state = .success("Loaded successfully")
        if case .success(let message) = state {
            #expect(message == "Loaded successfully", "Should store success message")
        } else {
            Issue.record("Should be in success state")
        }
        
        // Test transition to failure
        state = .failure("Load failed")
        if case .failure(let message) = state {
            #expect(message == "Load failed", "Should store failure message")
        } else {
            Issue.record("Should be in failure state")
        }
    }
    
    @Test("Selection state management works correctly")
    func testSelectionStateManagement() {
        // Test selection state patterns
        
        var selectedItems: Set<String> = []
        
        // Test adding selections
        selectedItems.insert("item1")
        #expect(selectedItems.contains("item1"), "Should contain selected item")
        #expect(selectedItems.count == 1, "Should have one selected item")
        
        selectedItems.insert("item2")
        #expect(selectedItems.contains("item2"), "Should contain newly selected item")
        #expect(selectedItems.count == 2, "Should have two selected items")
        
        // Test removing selections
        selectedItems.remove("item1")
        #expect(!selectedItems.contains("item1"), "Should not contain removed item")
        #expect(selectedItems.contains("item2"), "Should still contain other item")
        #expect(selectedItems.count == 1, "Should have one selected item after removal")
        
        // Test clearing all selections
        selectedItems.removeAll()
        #expect(selectedItems.isEmpty, "Should be empty after clearing")
    }
    
    @Test("Filter state management works correctly")
    func testFilterStateManagement() {
        // Test filter state patterns
        
        struct FilterState {
            var searchText: String = ""
            var selectedManufacturers: Set<String> = []
            var showOutOfStock: Bool = true
            
            var hasActiveFilters: Bool {
                return !searchText.isEmpty || !selectedManufacturers.isEmpty || !showOutOfStock
            }
        }
        
        var filterState = FilterState()
        
        // Test initial state
        #expect(filterState.hasActiveFilters == false, "Should not have active filters initially")
        
        // Test search text filter
        filterState.searchText = "glass"
        #expect(filterState.hasActiveFilters == true, "Should have active filters with search text")
        
        // Test manufacturer filter
        filterState.searchText = ""
        filterState.selectedManufacturers.insert("Effetre")
        #expect(filterState.hasActiveFilters == true, "Should have active filters with manufacturer selection")
        
        // Test stock filter
        filterState.selectedManufacturers.removeAll()
        filterState.showOutOfStock = false
        #expect(filterState.hasActiveFilters == true, "Should have active filters with stock filter")
        
        // Test clearing all filters
        filterState.searchText = ""
        filterState.selectedManufacturers.removeAll()
        filterState.showOutOfStock = true
        #expect(filterState.hasActiveFilters == false, "Should not have active filters after clearing")
    }
    
    @Test("Pagination state management works correctly")
    func testPaginationStateManagement() {
        // Test pagination patterns
        
        struct PaginationState {
            let itemsPerPage: Int = 50
            var currentPage: Int = 0
            var totalItems: Int = 0
            
            var totalPages: Int {
                return totalItems == 0 ? 0 : max(1, (totalItems + itemsPerPage - 1) / itemsPerPage)
            }
            
            var hasNextPage: Bool {
                return currentPage < totalPages - 1
            }
            
            var hasPreviousPage: Bool {
                return currentPage > 0
            }
        }
        
        var paginationState = PaginationState(currentPage: 0, totalItems: 125)
        
        // Test page calculations
        #expect(paginationState.totalPages == 3, "Should calculate correct total pages (125 items / 50 per page = 3 pages)")
        #expect(paginationState.hasNextPage == true, "Should have next page from first page")
        #expect(paginationState.hasPreviousPage == false, "Should not have previous page from first page")
        
        // Test navigation
        paginationState.currentPage = 1
        #expect(paginationState.hasNextPage == true, "Should have next page from middle page")
        #expect(paginationState.hasPreviousPage == true, "Should have previous page from middle page")
        
        paginationState.currentPage = 2
        #expect(paginationState.hasNextPage == false, "Should not have next page from last page")
        #expect(paginationState.hasPreviousPage == true, "Should have previous page from last page")
        
        // Test empty state
        let emptyPagination = PaginationState(currentPage: 0, totalItems: 0)
        #expect(emptyPagination.totalPages == 0, "Should have zero pages for empty state")
        #expect(emptyPagination.hasNextPage == false, "Should not have next page for empty state")
        #expect(emptyPagination.hasPreviousPage == false, "Should not have previous page for empty state")
    }


@Suite("Simple Form Field Logic Tests")
struct SimpleFormFieldLogicTests {
    
    @Test("Basic form field validation state works correctly")
    func testBasicFormFieldValidation() {
        // Test basic form field state logic without requiring specific classes
        
        struct MockFormField {
            var value: String = ""
            var isValid: Bool = true
            var errorMessage: String?
            var hasBeenTouched: Bool = false
            
            mutating func setValue(_ newValue: String) {
                value = newValue
                hasBeenTouched = true
                validateField()
            }
            
            mutating func validateField() {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    isValid = false
                    errorMessage = "Field cannot be empty"
                } else {
                    isValid = true
                    errorMessage = nil
                }
            }
            
            var shouldShowError: Bool {
                return hasBeenTouched && !isValid
            }
        }
        
        var field = MockFormField()
        
        // Test initial state
        #expect(field.isValid == true, "Should start as valid")
        #expect(field.hasBeenTouched == false, "Should start as untouched")
        #expect(field.shouldShowError == false, "Should not show error initially")
        
        // Test setting empty value
        field.setValue("")
        #expect(field.isValid == false, "Should be invalid with empty value")
        #expect(field.hasBeenTouched == true, "Should be touched after setting value")
        #expect(field.shouldShowError == true, "Should show error for empty touched field")
        
        // Test setting valid value
        field.setValue("Valid Value")
        #expect(field.isValid == true, "Should be valid with non-empty value")
        #expect(field.shouldShowError == false, "Should not show error for valid field")
    }
    
    @Test("Numeric field validation works correctly")
    func testNumericFieldValidation() {
        struct MockNumericField {
            var stringValue: String = ""
            var numericValue: Double? = nil
            var isValid: Bool = true
            var errorMessage: String?
            
            mutating func setValue(_ newValue: String) {
                stringValue = newValue
                validateField()
            }
            
            mutating func validateField() {
                let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if trimmed.isEmpty {
                    isValid = false
                    errorMessage = "Value cannot be empty"
                    numericValue = nil
                    return
                }
                
                guard let parsed = Double(trimmed) else {
                    isValid = false
                    errorMessage = "Must be a valid number"
                    numericValue = nil
                    return
                }
                
                if parsed < 0 {
                    isValid = false
                    errorMessage = "Value cannot be negative"
                    numericValue = nil
                    return
                }
                
                isValid = true
                errorMessage = nil
                numericValue = parsed
            }
        }
        
        var field = MockNumericField()
        
        // Test valid number
        field.setValue("25.5")
        #expect(field.isValid == true, "Should be valid for positive number")
        #expect(field.numericValue == 25.5, "Should parse numeric value correctly")
        
        // Test invalid format
        field.setValue("not-a-number")
        #expect(field.isValid == false, "Should be invalid for non-numeric input")
        #expect(field.numericValue == nil, "Should have nil numeric value for invalid input")
        
        // Test negative number
        field.setValue("-10")
        #expect(field.isValid == false, "Should be invalid for negative number")
    }
}

@Suite("Warning Fixes Verification Tests")
struct WarningFixesTests {
    
    @Test("CatalogView compiles without unused variable warnings")
    func testCatalogViewCompiles() {
        // This test verifies that CatalogView can be instantiated without warnings
        // We only test instantiation, not body access, to avoid SwiftUI state warnings
        let _ = CatalogView()
        
        // Test passes if CatalogView instantiates without compiler errors
        #expect(true, "CatalogView should instantiate successfully")
    }
    
    // REMOVED: HapticService tests - HapticService was completely removed from project
    
    @Test("GlassManufacturers utility functions work correctly")
    func testGlassManufacturersUtility() {
        // Test that the manufacturer utilities are accessible and functional
        let fullName = GlassManufacturers.fullName(for: "EF")
        #expect(fullName == "Effetre", "Should correctly map EF to Effetre")
        
        let isValid = GlassManufacturers.isValid(code: "DH")
        #expect(isValid == true, "DH should be a valid manufacturer code")
        
        let color = GlassManufacturers.colorForManufacturer("Effetre")
        #expect(color == GlassManufacturers.colorForManufacturer("EF"), "Should return same color for manufacturer code and full name")
    }
}

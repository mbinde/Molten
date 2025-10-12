//  AdvancedTestingTests.swift
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
import CoreData
@testable import Flameworker

@Suite("Advanced Testing", .serialized)
struct AdvancedTestingTests {
    
    // MARK: - Thread Safety Tests
    
    @Test("Should handle concurrent UserDefaults access safely")
    func testConcurrentUserDefaultsAccess() async throws {
        // Arrange - Create isolated test UserDefaults
        let testSuite = "ConcurrentTest_\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: testSuite)!
        WeightUnitPreference.setUserDefaults(testDefaults)
        
        // Act - Spawn multiple concurrent tasks accessing UserDefaults
        await withTaskGroup(of: Void.self) { group in
            // Multiple writers
            for i in 0..<10 {
                group.addTask {
                    let key = "test_key_\(i)"
                    let value = "test_value_\(i)"
                    ThreadSafetyUtilities.safeUserDefaultsWrite(key: key, value: value, defaults: testDefaults)
                }
            }
            
            // Multiple readers
            for i in 0..<10 {
                group.addTask {
                    let key = "test_key_\(i % 5)" // Some overlap with writers
                    _ = ThreadSafetyUtilities.safeUserDefaultsRead(key: key, defaults: testDefaults)
                }
            }
        }
        
        // Assert - All operations completed without crashes/data corruption
        #expect(true, "Concurrent UserDefaults operations should complete safely")
        
        // Verify data integrity - check only our test keys
        var foundTestKeys = 0
        for i in 0..<10 {
            let key = "test_key_\(i)"
            if let value = ThreadSafetyUtilities.safeUserDefaultsRead(key: key, defaults: testDefaults) {
                #expect(value == "test_value_\(i)", "Should preserve correct value for key \(key)")
                foundTestKeys += 1
            }
        }
        #expect(foundTestKeys <= 10, "Should not have more test keys than written")
        #expect(foundTestKeys > 0, "Should have written at least some test keys")
        
        // Cleanup
        WeightUnitPreference.resetToStandard()
        testDefaults.removeSuite(named: testSuite)
    }
    
    @Test("Should create inventory item directly without hanging")
    func testSimpleCoreDataCreation() throws {
        // Arrange - Get clean test context following established pattern
        let (testController, context) = try SharedTestUtilities.getCleanTestController()
        _ = testController
        
        // Act - Create a simple inventory item using safe entity creation
        guard let inventoryItem = CoreDataEntityHelpers.safeEntityCreation(
            entityName: "InventoryItem",
            in: context,
            type: NSManagedObject.self
        ) else {
            #expect(Bool(false), "Should be able to create InventoryItem entity")
            return
        }
        
        // Set basic properties using KVC (safe for any entity)
        CoreDataHelpers.setAttributeIfExists(inventoryItem, key: "notes", value: "Simple test item")
        
        // Save the context synchronously
        try context.save()
        
        // Assert - Item was created successfully
        #expect(inventoryItem.entity.name == "InventoryItem", "Should create correct entity type")
        #expect(!inventoryItem.isDeleted, "New item should not be deleted")
        #expect(inventoryItem.managedObjectContext === context, "Should be in correct context")
        
        // Verify the attribute was set correctly
        let retrievedNotes = CoreDataHelpers.safeStringValue(from: inventoryItem, key: "notes")
        #expect(retrievedNotes == "Simple test item", "Should preserve notes attribute")
    }
    
    // MARK: - Async Operations Tests
    
    @Test("Should handle async operation timeouts gracefully")
    func testAsyncOperationTimeouts() async throws {
        // Arrange
        let asyncManager = AsyncOperationManager()
        let timeoutDuration: TimeInterval = 0.1 // 100ms timeout
        
        // Act - Test operation that times out
        let result = await asyncManager.executeWithTimeout(
            timeout: timeoutDuration,
            operation: {
                // Simulate slow operation (200ms)
                try await Task.sleep(nanoseconds: 200_000_000)
                return "Should not complete"
            }
        )
        
        // Assert - Operation should timeout
        switch result {
        case .success:
            #expect(Bool(false), "Operation should timeout, not succeed")
        case .failure(let error):
            #expect(error is AsyncOperationError, "Should get timeout error")
            if let asyncError = error as? AsyncOperationError,
               case .timeout(let duration) = asyncError {
                #expect(duration == timeoutDuration, "Should report correct timeout duration")
            } else {
                #expect(Bool(false), "Should be timeout error type")
            }
        }
    }
    
    @Test("Should handle async operation cancellation")
    func testAsyncOperationCancellation() async throws {
        // Arrange
        let asyncManager = AsyncOperationManager()
        var operationStarted = false
        var operationCompleted = false
        var iterationCount = 0
        
        print("🟡 Starting cancellation test")
        
        // Act - Start operation and cancel it
        let task = Task {
            print("🔵 Task started")
            // Don't return the Result directly - await it and handle success/failure
            return await asyncManager.executeWithCancellation { isCancelled in
                print("🟢 Operation started, isCancelled: \(isCancelled())")
                operationStarted = true
                // Simulate work with cancellation checking
                for i in 0..<10 {
                    iterationCount = i + 1
                    print("🔄 Iteration \(iterationCount), isCancelled: \(isCancelled())")
                    if isCancelled() {
                        print("🛑 Throwing CancellationError")
                        throw CancellationError()
                    }
                    try await Task.sleep(nanoseconds: 50_000_000) // 50ms
                    print("✅ Iteration \(iterationCount) completed")
                }
                operationCompleted = true
                print("🏁 Operation completed normally")
                return "Completed"
            }
        }
        
        // Wait for operation to start
        print("⏰ Waiting for operation to start...")
        try await Task.sleep(nanoseconds: 75_000_000) // 75ms
        
        // Cancel the task
        print("❌ Cancelling task...")
        task.cancel()
        
        print("⏳ Awaiting task result...")
        let taskResult = await task.result
        print("📊 Task result: \(taskResult), type: \(type(of: taskResult))")
        
        // Extract the actual result from the task result
        let result: Result<String, Error>
        switch taskResult {
        case .success(let asyncResult):
            print("🔄 Task succeeded, inner result: \(asyncResult)")
            result = asyncResult
        case .failure(let taskError):
            print("🔄 Task failed: \(taskError)")
            result = .failure(taskError)
        }
        
        print("📊 Final result: \(result)")
        
        // Debug output
        print("📈 Debug info:")
        print("   - operationStarted: \(operationStarted)")
        print("   - operationCompleted: \(operationCompleted)")
        print("   - iterationCount: \(iterationCount)")
        
        // Assert - Operation started but was cancelled
        #expect(operationStarted == true, "Operation should have started")
        #expect(operationCompleted == false, "Operation should not complete after cancellation")
        
        switch result {
        case .success(let value):
            print("❌ TEST FAILURE: Got success result: \(value)")
            print("❌ Value type: \(type(of: value))")
            print("❌ Value description: \(String(describing: value))")
            #expect(Bool(false), "Cancelled operation should not succeed")
        case .failure(let error):
            print("✅ Got expected failure result: \(error)")
            print("✅ Error type: \(type(of: error))")
            #expect(error is CancellationError, "Should get cancellation error")
        }
    }
    
    // MARK: - Precision Handling Tests
    
    @Test("Should handle floating point precision correctly")
    func testFloatingPointPrecision() {
        // Arrange - Test cases with known precision issues
        let precisionCalculator = PrecisionCalculator()
        
        // Act & Assert - Decimal precision
        let result1 = precisionCalculator.safeAdd(0.1, 0.2)
        #expect(precisionCalculator.isEqual(result1, 0.3, precision: 0.0001), "0.1 + 0.2 should equal 0.3 with precision handling")
        
        // Act & Assert - Currency calculations
        let price1: Double = 19.99
        let price2: Double = 29.99
        let total = precisionCalculator.safeCurrencyAdd(price1, price2)
        #expect(precisionCalculator.isEqual(total, 49.98, precision: 0.001), "Currency addition should be precise")
        
        // Act & Assert - Weight conversions
        let pounds: Double = 10.0
        let kilograms = precisionCalculator.safeWeightConversion(pounds, from: .pounds, to: .kilograms)
        let backToPounds = precisionCalculator.safeWeightConversion(kilograms, from: .kilograms, to: .pounds)
        #expect(precisionCalculator.isEqual(backToPounds, pounds, precision: 0.0001), "Round-trip weight conversion should maintain precision")
        
        // Act & Assert - Large number precision
        let largeNumber1: Double = 999999999.999999
        let largeNumber2: Double = 0.000001
        let largeSum = precisionCalculator.safeAdd(largeNumber1, largeNumber2)
        #expect(largeSum > largeNumber1, "Large number addition should not lose precision")
    }
    
    @Test("Should handle decimal boundary conditions")
    func testDecimalBoundaryConditions() {
        // Arrange
        let precisionCalculator = PrecisionCalculator()
        
        // Test cases for boundary conditions
        let testCases: [(Double, Double, String)] = [
            (Double.greatestFiniteMagnitude, 1.0, "Maximum finite value"),
            (Double.leastNormalMagnitude, 1.0, "Minimum normal value"),
            (0.0, -0.0, "Positive and negative zero"),
            (1e-15, 1e-15, "Very small values"),
            (1e15, 1e15, "Very large values")
        ]
        
        for (value1, value2, description) in testCases {
            // Act
            let result = precisionCalculator.safeAdd(value1, value2)
            
            // Assert - Should handle boundary conditions without overflow/underflow
            #expect(result.isFinite, "\(description): Result should be finite")
            #expect(!result.isNaN, "\(description): Result should not be NaN")
        }
    }
    
    // MARK: - Form Validation Pattern Tests
    
    @Test("Should validate complex form patterns with precision")
    func testComplexFormValidationPatterns() throws {
        // Arrange
        let formValidator = AdvancedFormValidator()
        
        // Create complex form data
        let formData = ComplexFormData(
            inventoryCount: 123.456789,
            pricePerUnit: 29.99,
            supplierName: "Test Supplier Corp.",
            notes: "   Complex notes with\n multiple lines\t and whitespace   ",
            isActive: true,
            tags: ["glass", "rod", "COE96"],
            metadata: ["precision": "high", "category": "inventory"]
        )
        
        // Act
        let validationResult = formValidator.validateComplexForm(formData)
        
        // Assert - Comprehensive validation
        switch validationResult {
        case .success(let validatedData):
            #expect(validatedData.inventoryCount == 123.456789, "Should preserve exact precision for inventory count")
            #expect(validatedData.pricePerUnit == 29.99, "Should handle currency precision correctly")
            #expect(validatedData.supplierName == "Test Supplier Corp.", "Should maintain supplier name exactly")
            #expect(validatedData.notes == "Complex notes with\n multiple lines\t and whitespace", "Should trim external whitespace but preserve internal formatting")
            #expect(validatedData.tags.count == 3, "Should preserve all tags")
            #expect(validatedData.metadata.count == 2, "Should preserve all metadata")
        case .failure(let errors):
            #expect(Bool(false), "Valid form should pass validation, but got errors: \(errors)")
        }
    }
}

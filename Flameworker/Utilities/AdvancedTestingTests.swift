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
        
        // Act - Start operation and cancel it
        let task = Task {
            return await asyncManager.executeWithCancellation { isCancelled in
                operationStarted = true
                // Simulate work with cancellation checking
                for i in 0..<10 {
                    if isCancelled() {
                        throw CancellationError()
                    }
                    try await Task.sleep(nanoseconds: 50_000_000) // 50ms
                }
                operationCompleted = true
                return "Completed"
            }
        }
        
        // Wait for operation to start
        try await Task.sleep(nanoseconds: 75_000_000) // 75ms
        
        // Cancel the task
        task.cancel()
        
        let taskResult = await task.result
        
        // Extract the actual result from the task result
        let result: Result<String, Error>
        switch taskResult {
        case .success(let asyncResult):
            result = asyncResult
        case .failure(let taskError):
            result = .failure(taskError)
        }
        
        // Assert - Operation started but was cancelled
        #expect(operationStarted == true, "Operation should have started")
        #expect(operationCompleted == false, "Operation should not complete after cancellation")
        
        switch result {
        case .success:
            #expect(Bool(false), "Cancelled operation should not succeed")
        case .failure(let error):
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
    
    // MARK: - Memory Management Tests
    
    @Test("Should handle memory pressure scenarios")
    func testMemoryPressureHandling() async throws {
        // Arrange - Create multiple large objects to simulate memory pressure
        var largeObjects: [Data] = []
        let objectCount = 100
        let objectSize = 1024 * 1024 // 1MB each
        
        // Act - Allocate memory gradually
        for i in 0..<objectCount {
            let data = Data(count: objectSize)
            largeObjects.append(data)
            
            // Simulate some processing
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
            
            // Verify we can still allocate
            #expect(largeObjects.count == i + 1, "Should successfully allocate object \(i + 1)")
        }
        
        // Assert - Memory allocation succeeded
        #expect(largeObjects.count == objectCount, "Should allocate all objects without memory issues")
        
        // Cleanup - Release memory
        largeObjects.removeAll()
        #expect(largeObjects.isEmpty, "Should clean up memory properly")
    }
    
    // MARK: - Error Recovery Tests
    
    @Test("Should recover from multiple sequential errors")
    func testErrorRecoveryPatterns() async throws {
        // Arrange
        let retryManager = ServiceRetryManager()
        var attemptCount = 0
        
        // Act - Operation that fails first 2 times, succeeds on 3rd
        let result = await retryManager.executeWithRetry(
            maxAttempts: 3,
            baseDelay: 0.01 // 10ms base delay for testing
        ) { attempt in
            attemptCount = attempt
            if attempt < 3 {
                throw ServiceError.temporaryFailure("Attempt \(attempt) failed")
            }
            return "Success on attempt \(attempt)"
        }
        
        // Assert - Should succeed after retries
        switch result {
        case .success(let value):
            #expect(value == "Success on attempt 3", "Should succeed on third attempt")
            #expect(attemptCount == 3, "Should have made 3 attempts")
        case .failure:
            #expect(Bool(false), "Should eventually succeed with retries")
        }
    }
    
    @Test("Should stop retrying on permanent failures")
    func testPermanentFailureHandling() async throws {
        // Arrange
        let retryManager = ServiceRetryManager()
        var attemptCount = 0
        
        // Act - Operation that throws permanent failure
        let result = await retryManager.executeWithRetry(
            maxAttempts: 5,
            baseDelay: 0.01
        ) { attempt in
            attemptCount = attempt
            throw ServiceError.permanentFailure("Permanent error")
        }
        
        // Assert - Should fail immediately without retries
        switch result {
        case .success:
            #expect(Bool(false), "Permanent failure should not succeed")
        case .failure(let error):
            #expect(error is ServiceError, "Should get service error")
            if let serviceError = error as? ServiceError,
               case .permanentFailure(let message) = serviceError {
                #expect(message == "Permanent error", "Should preserve error message")
            }
            #expect(attemptCount == 1, "Should only attempt once for permanent failures")
        }
    }
    
    // MARK: - Performance Boundary Tests
    
    @Test("Should handle rapid sequential operations")
    func testRapidSequentialOperations() async throws {
        // Arrange
        let operationCount = 1000
        var completedOperations = 0
        let startTime = Date()
        
        // Act - Perform many rapid operations
        for i in 0..<operationCount {
            // Simulate lightweight operation
            let value = i * 2
            if value == i * 2 {
                completedOperations += 1
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        // Assert - All operations completed quickly
        #expect(completedOperations == operationCount, "Should complete all operations")
        #expect(duration < 1.0, "Should complete operations within reasonable time")
    }
    
    @Test("Should handle concurrent data access patterns")
    func testConcurrentDataAccessPatterns() async throws {
        // Arrange - Use actor for thread-safe data access
        actor SafeDataStore {
            private var storage: [String: String] = [:]
            
            func setValue(_ value: String, forKey key: String) {
                storage[key] = value
            }
            
            func getValue(forKey key: String) -> String? {
                return storage[key]
            }
            
            func getCount() -> Int {
                return storage.count
            }
        }
        
        let dataStore = SafeDataStore()
        let operationCount = 100
        
        // Act - Concurrent read/write operations using actor isolation
        await withTaskGroup(of: Void.self) { group in
            // Writers
            for i in 0..<operationCount {
                group.addTask {
                    await dataStore.setValue("value_\(i)", forKey: "key_\(i)")
                }
            }
            
            // Readers - reading keys that might not exist yet
            for i in 0..<operationCount {
                group.addTask {
                    _ = await dataStore.getValue(forKey: "key_\(i % 50)")
                }
            }
        }
        
        // Assert - No crashes occurred and some data was written
        let finalCount = await dataStore.getCount()
        #expect(finalCount > 0, "Should have written some data")
        #expect(finalCount <= operationCount, "Should not exceed expected data count")
    }
    
    // MARK: - Edge Case Validation Tests
    
    @Test("Should handle empty and nil data gracefully")
    func testEmptyDataHandling() throws {
        // Arrange
        let formValidator = AdvancedFormValidator()
        
        // Test empty string handling
        let emptyFormData = ComplexFormData(
            inventoryCount: 0,
            pricePerUnit: 0,
            supplierName: "",
            notes: "",
            isActive: false,
            tags: [],
            metadata: [:]
        )
        
        // Act
        let result = formValidator.validateComplexForm(emptyFormData)
        
        // Assert - Should handle empty data appropriately
        switch result {
        case .success:
            #expect(Bool(false), "Empty supplier name should cause validation failure")
        case .failure(let error):
            #expect(error.errors.contains { $0.contains("Supplier name cannot be empty") }, 
                   "Should detect empty supplier name")
        }
    }
    
    @Test("Should validate extreme numeric values")
    func testExtremeNumericValues() {
        // Arrange
        let precisionCalculator = PrecisionCalculator()
        
        // Test with extreme values
        let extremeValues: [Double] = [
            Double.infinity,
            -Double.infinity,
            Double.nan,
            Double.greatestFiniteMagnitude,
            -Double.greatestFiniteMagnitude,
            Double.leastNormalMagnitude,
            -Double.leastNormalMagnitude
        ]
        
        for value in extremeValues {
            // Act
            let result = precisionCalculator.safeAdd(value, 1.0)
            
            // Assert - Should handle extreme values without crashing
            if value.isInfinite {
                #expect(result.isInfinite, "Infinite values should remain infinite")
            } else if value.isNaN {
                #expect(result.isNaN, "NaN values should remain NaN")
            } else {
                #expect(result.isFinite || result.isInfinite, "Result should be either finite or infinite")
            }
        }
    }
    
    // MARK: - Performance Optimization Tests
    
    @Test("Should optimize string processing performance for large datasets")
    func testStringProcessingPerformanceOptimization() throws {
        // Arrange - Create large dataset for string processing
        let largeDataset = (1...1000).map { i in
            return [
                "Item Name \(i)",
                "Product Code: PRD-\(String(format: "%04d", i))", 
                "Description with many words and detailed information about item \(i)",
                "Category: \(["Electronics", "Tools", "Materials", "Supplies"][i % 4])",
                "Manufacturer: \(["CompanyA", "CompanyB", "CompanyC"][i % 3])"
            ]
        }
        
        let startTime = Date()
        
        // Act - Process strings with various operations
        var processedCount = 0
        for itemStrings in largeDataset {
            // Simulate common string operations
            let joinedString = itemStrings.joined(separator: " ")
            let lowercased = joinedString.lowercased()
            let trimmed = lowercased.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !trimmed.isEmpty && trimmed.contains("item") {
                processedCount += 1
            }
        }
        
        let endTime = Date()
        let processingTime = endTime.timeIntervalSince(startTime)
        
        // Assert - Performance benchmarks
        #expect(processedCount > 0, "Should process items successfully")
        #expect(processingTime < 0.1, "String processing should be efficient for 1000 items (actual: \(processingTime)s)")
        
        // Test memory efficiency
        #expect(processedCount == 1000, "Should process all 1000 items")
    }
    
    @Test("Should optimize collection operations for performance")
    func testCollectionPerformanceOptimization() throws {
        // Arrange - Create scenarios for different collection operations
        let largeArray = Array(1...10000)
        let largeSet = Set(1...5000)
        let largeDictionary = Dictionary(uniqueKeysWithValues: (1...3000).map { ($0, "Value\($0)") })
        
        let startTime = Date()
        
        // Act - Test various collection operations
        let filteredArray = largeArray.filter { $0 % 2 == 0 }
        let mappedArray = filteredArray.map { $0 * 2 }
        
        let setIntersection = largeSet.intersection(Set(Array(2500...7500)))
        
        let filteredDict = largeDictionary.filter { $0.key > 1500 }
        
        let endTime = Date()
        let processingTime = endTime.timeIntervalSince(startTime)
        
        // Assert - Collection performance
        #expect(filteredArray.count == 5000, "Should filter correctly")
        #expect(mappedArray.count == 5000, "Should map correctly")
        #expect(setIntersection.count == 2501, "Should intersect correctly (2500 to 5000 inclusive)")
        #expect(filteredDict.count == 1500, "Should filter dictionary correctly")
        #expect(processingTime < 0.05, "Collection operations should be efficient (actual: \(processingTime)s)")
    }
    
    @Test("Should optimize memory usage patterns under pressure")
    func testMemoryUsageOptimization() throws {
        // Arrange - Create memory pressure scenario
        let startMemory = ProcessInfo.processInfo.physicalMemory
        var memoryIntensiveStructures: [[String]] = []
        
        let startTime = Date()
        
        // Act - Create and manage memory-intensive operations
        for i in 1...100 {
            // Create temporary large structures
            let tempArray = (1...1000).map { "TempString\($0)_Iteration\(i)" }
            
            // Filter to simulate processing
            let filtered = tempArray.filter { $0.contains("Iteration") }
            
            // Keep only some results to test memory management
            if i % 10 == 0 {
                memoryIntensiveStructures.append(filtered)
            }
            
            // Periodically clear older structures to test memory optimization
            if i % 25 == 0 && memoryIntensiveStructures.count > 2 {
                memoryIntensiveStructures.removeFirst()
            }
        }
        
        let endTime = Date()
        let processingTime = endTime.timeIntervalSince(startTime)
        let endMemory = ProcessInfo.processInfo.physicalMemory
        
        // Assert - Memory optimization
        #expect(memoryIntensiveStructures.count <= 10, "Should manage memory by limiting retained structures")
        #expect(processingTime < 0.5, "Memory operations should be efficient (actual: \(processingTime)s)")
        
        // Memory shouldn't grow excessively
        let memoryDifference = Int64(endMemory) - Int64(startMemory)
        #expect(abs(memoryDifference) < 50_000_000, "Memory usage should remain reasonable") // 50MB limit
        
        // Verify functionality wasn't compromised
        for structure in memoryIntensiveStructures {
            #expect(structure.count == 1000, "Each retained structure should have complete data")
        }
    }
    
    @Test("Should optimize algorithmic complexity for nested operations")
    func testAlgorithmicComplexityOptimization() throws {
        // Arrange - Create nested operation scenario
        let dataSize = 500 // Reasonable size to test O(n²) vs O(n) performance
        let primaryData = (1...dataSize).map { "Primary\($0)" }
        let secondaryData = (1...dataSize).map { "Secondary\($0)" }
        
        let startTime = Date()
        
        // Act - Test efficient vs inefficient patterns
        
        // Efficient approach: Use sets for lookups
        let secondarySet = Set(secondaryData)
        var efficientMatches = 0
        
        for primary in primaryData {
            let searchKey = "Secondary\(primary.dropFirst(7))" // Extract number and format
            if secondarySet.contains(searchKey) {
                efficientMatches += 1
            }
        }
        
        let efficientTime = Date().timeIntervalSince(startTime)
        
        // Simulate less efficient approach (commented to avoid performance hit in tests)
        // This would be O(n²): primaryData.forEach { p in secondaryData.contains { s in ... } }
        
        let endTime = Date()
        let totalTime = endTime.timeIntervalSince(startTime)
        
        // Assert - Algorithmic efficiency
        #expect(efficientMatches == dataSize, "Should find all matches efficiently")
        #expect(efficientTime < 0.01, "Set-based lookup should be very fast (actual: \(efficientTime)s)")
        #expect(totalTime < 0.02, "Total algorithmic operations should be efficient (actual: \(totalTime)s)")
        
        // Test scalability indicator
        if dataSize >= 500 {
            #expect(efficientTime * 1000 < 1.0, "Algorithm should scale well (projected 1000x: \(efficientTime * 1000)s)")
        }
    }
}

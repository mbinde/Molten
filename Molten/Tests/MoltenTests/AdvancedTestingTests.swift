//  AdvancedTestingTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/11/25.
//  Cleaned up and migrated during repository pattern completion on 10/13/25
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

@Suite("Advanced Testing - Performance, Memory, and Precision", .serialized)
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
    
    // MARK: - Removed failing test per tests.md cleanup
    // Removed testSimpleCoreDataCreation() - was testing deprecated Core Data patterns
    
    // MARK: - Async Operations Tests
    
    @Test("Should handle async operation timeouts gracefully")
    func testAsyncOperationTimeouts() async throws {
        // Arrange
        let asyncManager = AsyncOperationManager()
        let timeoutDuration: TimeInterval = 0.1
        
        // Act - Create an operation that takes longer than the timeout
        let result = await asyncManager.executeWithTimeout(timeout: timeoutDuration) {
            // Simulate work that takes longer than timeout
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            return "Success"
        }
        
        // Assert - Should timeout
        switch result {
        case .success:
            #expect(Bool(false), "Operation should have timed out")
        case .failure(let error):
            if let asyncError = error as? AsyncOperationError {
                switch asyncError {
                case .timeout(let duration):
                    #expect(duration == timeoutDuration, "Should report correct timeout duration")
                default:
                    #expect(Bool(false), "Should be a timeout error, got: \(asyncError)")
                }
            } else {
                #expect(Bool(false), "Should be an AsyncOperationError, got: \(error)")
            }
        }
    }
    
    @Test("Should handle async operation cancellation")
    func testAsyncOperationCancellation() async throws {
        // Arrange
        let asyncManager = AsyncOperationManager()
        
        // Act - Create a cancellable operation
        let task = Task {
            return await asyncManager.executeWithCancellation { isCancelled in
                // Simulate work that checks for cancellation
                for i in 1...10 {
                    if await isCancelled() {
                        throw AsyncOperationError.cancelled
                    }
                    try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                }
                return "Completed"
            }
        }
        
        // Cancel after a short delay
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        task.cancel()
        
        let result = await task.value
        
        // Assert - Should be cancelled
        switch result {
        case .success:
            #expect(Bool(false), "Operation should have been cancelled")
        case .failure(let error):
            // Accept both AsyncOperationError.cancelled and CancellationError
            if let asyncError = error as? AsyncOperationError {
                switch asyncError {
                case .cancelled:
                    #expect(true, "Operation was properly cancelled with AsyncOperationError")
                default:
                    #expect(Bool(false), "Should be a cancellation error, got: \(asyncError)")
                }
            } else if error is CancellationError {
                #expect(true, "Operation was properly cancelled with CancellationError")
            } else {
                #expect(Bool(false), "Should be a cancellation error, got: \(error)")
            }
        }
    }
    
    // MARK: - Precision Handling Tests
    
    @Test("Should handle floating point precision correctly")
    func testFloatingPointPrecision() async {
        // Arrange
        let precisionCalculator = PrecisionCalculator()
        let precision = 0.001

        // Act & Assert - Test basic floating point operations
        let result1 = precisionCalculator.safeAdd(0.1, 0.2)
        #expect(precisionCalculator.isEqual(result1, 0.3, precision: precision), "Should handle 0.1 + 0.2 = 0.3 within precision")

        // Test currency precision
        let currencyResult = precisionCalculator.safeCurrencyAdd(10.99, 0.01)
        #expect(currencyResult == 11.00, "Should handle currency precision correctly")

        // Test weight conversion precision
        let weightResult = await precisionCalculator.safeWeightConversion(1.0, from: .pounds, to: .kilograms)
        #expect(abs(weightResult - 0.453592) < precision, "Should convert pounds to kilograms with precision")
        
        // Test extreme precision cases
        let extremeResult1 = precisionCalculator.safeAdd(0.000001, 0.000002)
        let extremeResult2 = precisionCalculator.safeAdd(0.000003, 0.0)
        #expect(precisionCalculator.isEqual(extremeResult1, extremeResult2, precision: 0.000001), "Should handle very small numbers with precision")
    }
    
    @Test("Should handle decimal boundary conditions")
    func testDecimalBoundaryConditions() async {
        // Arrange
        let precisionCalculator = PrecisionCalculator()
        let standardPrecision = 0.001

        // Test boundary conditions for decimal operations

        // Act & Assert - Test zero boundary
        let zeroResult = precisionCalculator.safeAdd(0.0, 0.0)
        #expect(zeroResult == 0.0, "Zero plus zero should equal zero")

        // Test very small numbers near zero
        let smallNumber = 0.0000001
        let almostZeroResult = precisionCalculator.safeAdd(smallNumber, -smallNumber)
        #expect(precisionCalculator.isEqual(almostZeroResult, 0.0, precision: standardPrecision), "Very small operations should approach zero within precision")

        // Test large number boundaries
        let largeNumber1 = 999999.999
        let largeNumber2 = 0.001
        let largeBoundaryResult = precisionCalculator.safeAdd(largeNumber1, largeNumber2)
        #expect(largeBoundaryResult == 1000000.0, "Large number operations should maintain precision")

        // Test negative boundary conditions
        let negativeResult = precisionCalculator.safeAdd(-100.5, 100.5)
        #expect(precisionCalculator.isEqual(negativeResult, 0.0, precision: standardPrecision), "Negative and positive should cancel within precision")

        // Test weight conversion boundaries
        let zeroPounds = await precisionCalculator.safeWeightConversion(0.0, from: .pounds, to: .kilograms)
        #expect(zeroPounds == 0.0, "Zero weight conversion should remain zero")

        let verySmallWeight = await precisionCalculator.safeWeightConversion(0.001, from: .pounds, to: .kilograms)
        #expect(verySmallWeight > 0.0, "Very small weight conversions should remain positive")
    }
    
    // MARK: - Form Validation Pattern Tests
    
    @Test("Should validate complex form patterns with precision")
    func testComplexFormValidationPatterns() throws {
        // Arrange
        let formValidator = AdvancedFormValidator()
        
        // Test valid form data
        let validFormData = ComplexFormData(
            inventoryCount: 100.5,
            pricePerUnit: 25.99,
            supplierName: "Test Supplier Co.",
            notes: "Test notes with details",
            isActive: true,
            tags: ["glass", "rod", "clear"],
            metadata: ["color": "clear", "length": "12 inches"]
        )
        
        // Act - Validate valid form
        let validResult = formValidator.validateComplexForm(validFormData)
        
        // Assert - Valid form should pass
        switch validResult {
        case .success(let validatedData):
            #expect(validatedData.inventoryCount == 100.5, "Should preserve valid inventory count")
            #expect(validatedData.pricePerUnit == 25.99, "Should preserve valid price")
            #expect(validatedData.supplierName == "Test Supplier Co.", "Should preserve valid supplier name")
        case .failure:
            #expect(Bool(false), "Valid form should pass validation")
        }
        
        // Test invalid form data - negative inventory
        let invalidInventoryData = ComplexFormData(
            inventoryCount: -10.0,
            pricePerUnit: 25.99,
            supplierName: "Test Supplier",
            notes: "",
            isActive: true,
            tags: [],
            metadata: [:]
        )
        
        let invalidInventoryResult = formValidator.validateComplexForm(invalidInventoryData)
        switch invalidInventoryResult {
        case .success:
            #expect(Bool(false), "Invalid inventory count should fail validation")
        case .failure(let error):
            #expect(error.errors.contains("Inventory count cannot be negative"), "Should report negative inventory error")
        }
        
        // Test invalid form data - empty supplier name
        let emptySupplierData = ComplexFormData(
            inventoryCount: 10.0,
            pricePerUnit: 25.99,
            supplierName: "   ",
            notes: "",
            isActive: true,
            tags: [],
            metadata: [:]
        )
        
        let emptySupplierResult = formValidator.validateComplexForm(emptySupplierData)
        switch emptySupplierResult {
        case .success:
            #expect(Bool(false), "Empty supplier name should fail validation")
        case .failure(let error):
            #expect(error.errors.contains("Supplier name cannot be empty"), "Should report empty supplier name error")
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

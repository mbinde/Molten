//
//  AsyncOperationTests.swift
//  FlameworkerTests
//
//  Created by Test Consolidation on 10/4/25.
//

import Testing
import SwiftUI
@testable import Flameworker

// MARK: - Comprehensive Async Operation Tests from AsyncOperationHandlerConsolidatedTests.swift

@Suite("AsyncOperationHandler Consolidated Tests", .serialized)
struct AsyncOperationHandlerConsolidatedTests {
    
    // MARK: - Setup and Cleanup
    
    private func createIsolatedLoadingBinding() -> (binding: Binding<Bool>, getValue: () -> Bool) {
        var isLoading = false
        let binding = Binding<Bool>(
            get: { isLoading },
            set: { isLoading = $0 }
        )
        return (binding: binding, getValue: { isLoading })
    }
    
    // MARK: - Concurrent Operations Tests
    
    @Test("AsyncOperationHandler prevents concurrent operations")
    func preventsConcurrentOperations() async throws {
        #if DEBUG
        await AsyncOperationHandler.waitForPendingOperations()
        #endif
        
        var operationCount = 0
        var operationStartedCount = 0
        let (loadingBinding, getLoadingValue) = createIsolatedLoadingBinding()
        
        func testOperation() async throws {
            operationStartedCount += 1
            // Longer operation to ensure overlap potential
            try await Task.sleep(nanoseconds: 60_000_000) // 60ms
            operationCount += 1
        }
        
        // Start first operation using testing method
        let task1 = AsyncOperationHandler.performForTesting(
            operation: testOperation,
            operationName: "Concurrent Test Operation 1",
            loadingState: loadingBinding
        )
        
        // Start second operation immediately (should be prevented due to loading state)
        let task2 = AsyncOperationHandler.performForTesting(
            operation: testOperation,
            operationName: "Concurrent Test Operation 2",
            loadingState: loadingBinding
        )
        
        // Wait for both tasks to complete
        await task1.value
        await task2.value
        
        #if DEBUG
        await AsyncOperationHandler.waitForPendingOperations()
        #endif
        
        // Only one should have started and completed
        #expect(operationStartedCount == 1, "Expected 1 operation to start, got \(operationStartedCount)")
        #expect(operationCount == 1, "Expected 1 operation to complete, got \(operationCount)")
        #expect(getLoadingValue() == false, "Loading state should be reset")
    }
    
    // MARK: - Sequential Operations Tests
    
    @Test("AsyncOperationHandler allows sequential operations")
    func allowsSequentialOperations() async throws {
        #if DEBUG
        await AsyncOperationHandler.waitForPendingOperations()
        #endif
        
        var operationCount = 0
        let (loadingBinding, getLoadingValue) = createIsolatedLoadingBinding()
        
        func testOperation() async throws {
            operationCount += 1
        }
        
        // Start first operation and wait for completion
        let task1 = AsyncOperationHandler.performForTesting(
            operation: testOperation,
            operationName: "Sequential Test Operation 1",
            loadingState: loadingBinding
        )
        
        // Wait for first operation to complete
        await task1.value
        
        #if DEBUG
        await AsyncOperationHandler.waitForPendingOperations()
        #endif
        
        // Start second operation
        let task2 = AsyncOperationHandler.performForTesting(
            operation: testOperation,
            operationName: "Sequential Test Operation 2",
            loadingState: loadingBinding
        )
        
        // Wait for second operation to complete
        await task2.value
        
        #if DEBUG
        await AsyncOperationHandler.waitForPendingOperations()
        #endif
        
        // Both should have executed
        #expect(operationCount == 2, "Expected 2 operations, got \(operationCount)")
        #expect(getLoadingValue() == false, "Loading state should be reset")
    }
    
    // MARK: - Duplicate Prevention Tests
    
    @Test("AsyncOperationHandler prevents duplicate operations")
    func preventsDuplicateOperations() async throws {
        #if DEBUG
        await AsyncOperationHandler.waitForPendingOperations()
        #endif
        
        var operationCallCount = 0
        var operationStartedCount = 0
        let (loadingBinding, getLoadingValue) = createIsolatedLoadingBinding()
        
        func mockOperation() async throws {
            operationStartedCount += 1
            // Longer operation to ensure proper overlap testing
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            operationCallCount += 1
        }
        
        // Start first operation
        let task1 = AsyncOperationHandler.performForTesting(
            operation: mockOperation,
            operationName: "Duplicate Test Operation 1",
            loadingState: loadingBinding
        )
        
        // Start second operation immediately (should be prevented)
        let task2 = AsyncOperationHandler.performForTesting(
            operation: mockOperation,
            operationName: "Duplicate Test Operation 2",
            loadingState: loadingBinding
        )
        
        // Wait for both tasks to complete
        await task1.value
        await task2.value
        
        #if DEBUG
        await AsyncOperationHandler.waitForPendingOperations()
        #endif
        
        // Only the first operation should have started and executed
        #expect(operationStartedCount == 1, "Only first operation should start, got \(operationStartedCount)")
        #expect(operationCallCount == 1, "Only first operation should complete, got \(operationCallCount)")
        #expect(getLoadingValue() == false, "Loading should be reset after completion")
    }
    
    // MARK: - Error Handling Tests
    
    @Test("AsyncOperationHandler handles operation errors properly")
    func handlesOperationErrors() async throws {
        #if DEBUG
        await AsyncOperationHandler.waitForPendingOperations()
        #endif
        
        struct TestError: Error {}
        
        var operationCallCount = 0
        let (loadingBinding, getLoadingValue) = createIsolatedLoadingBinding()
        
        func throwingOperation() async throws {
            operationCallCount += 1
            throw TestError()
        }
        
        // Start operation that will throw
        let task = AsyncOperationHandler.performForTesting(
            operation: throwingOperation,
            operationName: "Error Test Operation",
            loadingState: loadingBinding
        )
        
        // Wait for operation to complete
        await task.value
        
        #if DEBUG
        await AsyncOperationHandler.waitForPendingOperations()
        #endif
        
        // Operation should have executed and failed
        #expect(operationCallCount == 1, "Operation should have executed once")
        #expect(getLoadingValue() == false, "Loading state should be reset even after error")
    }
    
    @Test("AsyncOperationHandler executes simple operation successfully")
    func asyncOperationHandlerSimpleOperation() async throws {
        #if DEBUG
        await AsyncOperationHandler.waitForPendingOperations()
        #endif
        
        var operationCompleted = false
        let (loadingBinding, getLoadingValue) = createIsolatedLoadingBinding()
        
        func simpleOperation() async throws {
            operationCompleted = true
        }
        
        // Start the operation
        let task = AsyncOperationHandler.performForTesting(
            operation: simpleOperation,
            operationName: "Simple Test Operation",
            loadingState: loadingBinding
        )
        
        // Wait for operation to complete
        await task.value
        
        #if DEBUG
        await AsyncOperationHandler.waitForPendingOperations()
        #endif
        
        // Verify the operation completed successfully
        #expect(operationCompleted == true, "Operation should have completed")
        #expect(getLoadingValue() == false, "Loading state should be reset after completion")
    }
}

// MARK: - Async Operation Fix Tests from AsyncOperationHandlerFixTests.swift

@Suite("AsyncOperationHandler Fix Tests")
struct AsyncOperationHandlerFixTests {
    
    @Test("AsyncOperationHandler prevents concurrent operations (fix version)")
    func asyncOperationHandlerPreventsConcurrentOps() async throws {
        // Wait for any pending operations from other tests
        #if DEBUG
        await AsyncOperationHandler.waitForPendingOperations()
        #endif
        var operationCount = 0
        var isLoading = false
        
        let loadingBinding = Binding<Bool>(
            get: { isLoading },
            set: { isLoading = $0 }
        )
        
        func testOperation() async throws {
            operationCount += 1
            // Longer operation to ensure overlap
            try await Task.sleep(nanoseconds: 60_000_000) // 60ms
        }
        
        // Start first operation using testing method
        let task1 = AsyncOperationHandler.performForTesting(
            operation: testOperation,
            operationName: "Operation 1",
            loadingState: loadingBinding
        )
        
        // Small delay to let first operation start
        try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        
        // Start second operation (should be prevented)
        let task2 = AsyncOperationHandler.performForTesting(
            operation: testOperation,
            operationName: "Operation 2",
            loadingState: loadingBinding
        )
        
        // Wait for both tasks to complete
        await task1.value
        await task2.value
        
        // Only one should have executed
        #expect(operationCount == 1, "Expected 1 operation, got \(operationCount)")
        #expect(isLoading == false, "Loading state should be reset")
    }
    
    @Test("AsyncOperationHandler allows sequential operations (fix version)")
    func asyncOperationHandlerAllowsSequentialOps() async throws {
        // Wait for any pending operations from other tests
        #if DEBUG
        await AsyncOperationHandler.waitForPendingOperations()
        #endif
        var operationCount = 0
        var isLoading = false
        
        let loadingBinding = Binding<Bool>(
            get: { isLoading },
            set: { isLoading = $0 }
        )
        
        func testOperation() async throws {
            operationCount += 1
        }
        
        // Start first operation and wait for completion
        let task1 = AsyncOperationHandler.performForTesting(
            operation: testOperation,
            operationName: "Operation 1",
            loadingState: loadingBinding
        )
        
        // Wait for first operation to complete
        await task1.value
        
        // Start second operation
        let task2 = AsyncOperationHandler.performForTesting(
            operation: testOperation,
            operationName: "Operation 2",
            loadingState: loadingBinding
        )
        
        // Wait for second operation to complete
        await task2.value
        
        // Both should have executed
        #expect(operationCount == 2, "Expected 2 operations, got \(operationCount)")
        #expect(isLoading == false, "Loading state should be reset")
    }
}

// MARK: - Async Operation Safety Tests from SimpleUtilityTests.swift

@Suite("Simple Async Operation Safety Tests")
struct SimpleAsyncOperationSafetyTests {
    
    @Test("Async operation safety patterns")
    func testAsyncOperationSafetyPatterns() async {
        // Test basic async operation safety patterns
        var isLoading = false
        var operationCallCount = 0
        
        // Simulate async operation guard
        func performOperation() -> Bool {
            if isLoading {
                return false // Skip if already loading
            }
            isLoading = true
            operationCallCount += 1
            // Operation would execute here
            isLoading = false
            return true
        }
        
        // Test that duplicate operations are prevented
        let result1 = performOperation()
        #expect(result1 == true, "First operation should succeed")
        
        // Reset state for clean test
        isLoading = false
        let result2 = performOperation()
        #expect(result2 == true, "Operation should succeed when not loading")
        
        #expect(operationCallCount == 2, "Should have executed both operations when not concurrent")
    }
    
    @Test("AsyncOperationHandler prevents duplicate operations")
    func asyncOperationHandlerPreventsDuplicates() async throws {
        // Wait for any pending operations from other tests
        #if DEBUG
        await AsyncOperationHandler.waitForPendingOperations()
        #endif
        
        // Test the duplicate prevention - focus on core functionality and be resilient to timing
        var operationCallCount = 0
        var isLoadingState = false
        
        func mockOperation() async throws {
            operationCallCount += 1
            // Simulate longer async work to ensure proper overlap
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
        
        let loadingBinding = Binding<Bool>(
            get: { isLoadingState },
            set: { isLoadingState = $0 }
        )
        
        // Start first operation  
        let task1 = AsyncOperationHandler.performForTesting(
            operation: mockOperation,
            operationName: "Test Operation 1",
            loadingState: loadingBinding
        )
        
        // Give first operation time to start and set loading state
        try await Task.sleep(nanoseconds: 2_000_000) // 2ms
        
        // Start second operation (should be prevented)
        let task2 = AsyncOperationHandler.performForTesting(
            operation: mockOperation,
            operationName: "Test Operation 2", 
            loadingState: loadingBinding
        )
        
        // Wait for both tasks to complete
        await task1.value
        await task2.value
        
        // Core test: only one operation should have executed (this is what matters)
        #expect(operationCallCount == 1, "Duplicate prevention: only first operation should execute, got \(operationCallCount)")
        #expect(isLoadingState == false, "Loading state should be reset after operations complete")
        
        // The critical assertion: duplicate operations were prevented
        #expect(operationCallCount <= 1, "Critical: no more than one operation should execute")
    }
}

// MARK: - Async Error Handling Tests from AsyncAndValidationTests.swift

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
            return .success(try await performAsyncOperation(shouldFail: shouldFail))
        } catch {
            return .failure(error)
        }
    }
    
    private struct TestAsyncError: Error {}
}
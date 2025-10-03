//
//  AsyncOperationHandlerConsolidatedTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/3/25.
//

import Testing
import SwiftUI
@testable import Flameworker

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
        let (loadingBinding, getLoadingValue) = createIsolatedLoadingBinding()
        
        func testOperation() async throws {
            operationCount += 1
            // Longer operation to ensure overlap potential
            try await Task.sleep(nanoseconds: 60_000_000) // 60ms
        }
        
        // Start first operation using testing method
        let task1 = AsyncOperationHandler.performForTesting(
            operation: testOperation,
            operationName: "Concurrent Test Operation 1",
            loadingState: loadingBinding
        )
        
        // Wait for the loading state to be set by the first operation
        var attempts = 0
        while !getLoadingValue() && attempts < 50 { // Wait up to 50ms
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
            attempts += 1
        }
        
        // Verify the loading state is now true (first operation started)
        #expect(getLoadingValue() == true, "Loading state should be true when first operation is running")
        
        // Start second operation (should be prevented)
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
        
        // Only one should have executed
        #expect(operationCount == 1, "Expected 1 operation, got \(operationCount)")
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
        let (loadingBinding, getLoadingValue) = createIsolatedLoadingBinding()
        
        func mockOperation() async throws {
            operationCallCount += 1
            // Longer operation to ensure proper overlap testing
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
        
        // Start first operation
        let task1 = AsyncOperationHandler.performForTesting(
            operation: mockOperation,
            operationName: "Duplicate Test Operation 1",
            loadingState: loadingBinding
        )
        
        // Wait for the loading state to be set by the first operation
        // This ensures the first operation has started before we try the second
        var attempts = 0
        while !getLoadingValue() && attempts < 50 { // Wait up to 50ms
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
            attempts += 1
        }
        
        // Verify the loading state is now true (first operation started)
        #expect(getLoadingValue() == true, "Loading state should be true when first operation is running")
        
        // Now try to start second operation (should be prevented)
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
        
        // Only the first operation should have executed
        #expect(operationCallCount == 1, "Only first operation should execute, got \(operationCallCount)")
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
    
    // MARK: - Additional AsyncOperationHandler Tests
    
    @Test("AsyncOperationHandler prevents duplicate operations (alternative implementation)")
    func preventsDuplicateOperationsAlternative() async throws {
        #if DEBUG
        await AsyncOperationHandler.waitForPendingOperations()
        #endif
        
        var operationCallCount = 0
        let (loadingBinding, getLoadingValue) = createIsolatedLoadingBinding()
        
        func mockOperation() async throws {
            operationCallCount += 1
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
        
        // Start first operation
        let task1 = AsyncOperationHandler.performForTesting(
            operation: mockOperation,
            operationName: "test operation",
            loadingState: loadingBinding
        )
        
        // Wait for the loading state to be set by the first operation
        var attempts = 0
        while !getLoadingValue() && attempts < 50 { // Wait up to 50ms
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
            attempts += 1
        }
        
        // Verify the loading state is now true (first operation started)
        #expect(getLoadingValue() == true, "Loading state should be true when first operation is running")
        
        // Try to start second operation (should be prevented)
        let task2 = AsyncOperationHandler.performForTesting(
            operation: {
                operationCallCount += 1
            },
            operationName: "duplicate operation",
            loadingState: loadingBinding
        )
        
        // Wait for both tasks to complete
        await task1.value
        await task2.value
        
        #if DEBUG
        await AsyncOperationHandler.waitForPendingOperations()
        #endif
        
        // Only the first operation should have executed
        #expect(operationCallCount == 1, "Only first operation should execute, got \(operationCallCount)")
        #expect(getLoadingValue() == false, "Loading should be reset after completion")
    }
    
    // MARK: - Simple Operation Tests
    
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
    
    // MARK: - Warning Fix Tests (moved from ViewUtilitiesWarningFixTests)
    
    @Test("AsyncOperationHandler can perform simple operation (warning fix test)")
    func asyncOperationHandlerSimpleOperationWarningFix() async throws {
        #if DEBUG
        await AsyncOperationHandler.waitForPendingOperations()
        #endif
        
        var operationCompleted = false
        let (loadingBinding, getLoadingValue) = createIsolatedLoadingBinding()
        
        // Start the operation
        let task = AsyncOperationHandler.performForTesting(
            operation: {
                operationCompleted = true
            },
            operationName: "Warning Fix Test Operation",
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
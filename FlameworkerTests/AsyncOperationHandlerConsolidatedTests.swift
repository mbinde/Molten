//
//  AsyncOperationHandlerConsolidatedTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/3/25.
//

import Testing
import SwiftUI
@testable import Flameworker

@Suite("AsyncOperationHandler Consolidated Tests")
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
    
    @Test("AsyncOperationHandler prevents concurrent operations", .serialized)
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
        
        // Start first operation
        let task1 = Task {
            AsyncOperationHandler.perform(
                operation: testOperation,
                operationName: "Concurrent Test Operation 1",
                loadingState: loadingBinding
            )
        }
        
        // Small delay to let first operation start
        try await Task.sleep(nanoseconds: 5_000_000) // 5ms
        
        // Start second operation (should be prevented)
        let task2 = Task {
            AsyncOperationHandler.perform(
                operation: testOperation,
                operationName: "Concurrent Test Operation 2",
                loadingState: loadingBinding
            )
        }
        
        // Wait for both task dispatches
        await task1.value
        await task2.value
        
        // Wait for operations to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        #if DEBUG
        await AsyncOperationHandler.waitForPendingOperations()
        #endif
        
        // Only one should have executed
        #expect(operationCount == 1, "Expected 1 operation, got \(operationCount)")
        #expect(getLoadingValue() == false, "Loading state should be reset")
    }
    
    // MARK: - Sequential Operations Tests
    
    @Test("AsyncOperationHandler allows sequential operations", .serialized)
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
        AsyncOperationHandler.perform(
            operation: testOperation,
            operationName: "Sequential Test Operation 1",
            loadingState: loadingBinding
        )
        
        // Wait for first operation to complete
        try await Task.sleep(nanoseconds: 30_000_000) // 30ms
        
        #if DEBUG
        await AsyncOperationHandler.waitForPendingOperations()
        #endif
        
        // Start second operation
        AsyncOperationHandler.perform(
            operation: testOperation,
            operationName: "Sequential Test Operation 2",
            loadingState: loadingBinding
        )
        
        // Wait for second operation to complete
        try await Task.sleep(nanoseconds: 30_000_000) // 30ms
        
        #if DEBUG
        await AsyncOperationHandler.waitForPendingOperations()
        #endif
        
        // Both should have executed
        #expect(operationCount == 2, "Expected 2 operations, got \(operationCount)")
        #expect(getLoadingValue() == false, "Loading state should be reset")
    }
    
    // MARK: - Duplicate Prevention Tests
    
    @Test("AsyncOperationHandler prevents duplicate operations", .serialized)
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
        AsyncOperationHandler.perform(
            operation: mockOperation,
            operationName: "Duplicate Test Operation 1",
            loadingState: loadingBinding
        )
        
        // Small delay to let first operation start
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        // Try to start second operation (should be prevented)
        AsyncOperationHandler.perform(
            operation: mockOperation,
            operationName: "Duplicate Test Operation 2",
            loadingState: loadingBinding
        )
        
        // Wait for operations to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        #if DEBUG
        await AsyncOperationHandler.waitForPendingOperations()
        #endif
        
        // Only the first operation should have executed
        #expect(operationCallCount == 1, "Only first operation should execute, got \(operationCallCount)")
        #expect(getLoadingValue() == false, "Loading should be reset after completion")
    }
    
    // MARK: - Error Handling Tests
    
    @Test("AsyncOperationHandler handles operation errors properly", .serialized)
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
        AsyncOperationHandler.perform(
            operation: throwingOperation,
            operationName: "Error Test Operation",
            loadingState: loadingBinding
        )
        
        // Wait for operation to complete
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        #if DEBUG
        await AsyncOperationHandler.waitForPendingOperations()
        #endif
        
        // Operation should have executed and failed
        #expect(operationCallCount == 1, "Operation should have executed once")
        #expect(getLoadingValue() == false, "Loading state should be reset even after error")
    }
}
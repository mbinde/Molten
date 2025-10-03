//
//  AsyncOperationHandlerFixTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/3/25.
//

import Testing
import SwiftUI
@testable import Flameworker

@Suite("AsyncOperationHandler Fix Tests")
struct AsyncOperationHandlerFixTests {
    
    @Test("AsyncOperationHandler prevents concurrent operations")
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
    
    @Test("AsyncOperationHandler allows sequential operations")
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
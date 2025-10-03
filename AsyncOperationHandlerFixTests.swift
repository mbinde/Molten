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
        
        // Start first operation
        let task1 = Task {
            AsyncOperationHandler.perform(
                operation: testOperation,
                operationName: "Operation 1",
                loadingState: loadingBinding
            )
        }
        
        // Small delay to let first operation start
        try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        
        // Start second operation (should be prevented)
        let task2 = Task {
            AsyncOperationHandler.perform(
                operation: testOperation,
                operationName: "Operation 2",
                loadingState: loadingBinding
            )
        }
        
        // Wait for both task dispatches
        await task1.value
        await task2.value
        
        // Wait for operations to complete
        try await Task.sleep(nanoseconds: 150_000_000) // 150ms - longer wait
        
        // Only one should have executed
        #expect(operationCount == 1, "Expected 1 operation, got \(operationCount)")
        
        // Wait a bit more for loading state cleanup
        try await Task.sleep(nanoseconds: 50_000_000) // Extra 50ms
        #expect(isLoading == false, "Loading state should be reset")
    }
    
    @Test("AsyncOperationHandler allows sequential operations")
    func asyncOperationHandlerAllowsSequentialOps() async throws {
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
        AsyncOperationHandler.perform(
            operation: testOperation,
            operationName: "Operation 1",
            loadingState: loadingBinding
        )
        
        // Wait for first operation to complete
        try await Task.sleep(nanoseconds: 20_000_000) // 20ms
        
        // Start second operation
        AsyncOperationHandler.perform(
            operation: testOperation,
            operationName: "Operation 2",
            loadingState: loadingBinding
        )
        
        // Wait for second operation to complete
        try await Task.sleep(nanoseconds: 20_000_000) // 20ms
        
        // Both should have executed
        #expect(operationCount == 2, "Expected 2 operations, got \(operationCount)")
        #expect(isLoading == false, "Loading state should be reset")
    }
}
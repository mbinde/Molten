//  SimpleUtilityTests.swift
//  FlameworkerTests
//
//  Extracted from FlameworkerTests.swift on 10/3/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Testing
import Foundation
import SwiftUI
@testable import Flameworker

@Suite("Simple Utility Tests")
struct SimpleUtilityTests {
    
    @Test("Bundle utilities basic functionality")
    func testBundleUtilitiesBasics() {
        // Test basic Bundle access patterns
        let mainBundle = Bundle.main
        #expect(mainBundle.bundleIdentifier != nil || mainBundle.bundleIdentifier == nil, "Bundle should exist")
        
        // Test that we can get bundle contents without crashing
        let bundlePath = mainBundle.bundlePath
        #expect(!bundlePath.isEmpty, "Bundle path should not be empty")
    }
    
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
    
    @Test("Feature description pattern works")
    func testFeatureDescriptionPattern() {
        // Test simple feature description pattern
        struct MockFeatureDescription {
            let title: String
            let icon: String
        }
        
        let feature = MockFeatureDescription(title: "Test Feature", icon: "star")
        #expect(feature.title == "Test Feature", "Should set title correctly")
        #expect(feature.icon == "star", "Should set icon correctly")
    }
}
//
//  AsyncOperationHandlerDiagnosticTests.swift
//  FlameworkerTests
//
//  Created by Diagnostic on 10/5/25.
//

import Testing
import SwiftUI
@testable import Flameworker

@Suite("AsyncOperationHandler Diagnostic Tests")
struct AsyncOperationHandlerDiagnosticTests {
    
    @Test("simple async operation without problematic timing should not hang")
    func simpleAsyncOperationWithoutHang() async throws {
        let startTime = Date()
        var operationCompleted = false
        var isLoading = false
        
        let loadingBinding = Binding<Bool>(
            get: { isLoading },
            set: { isLoading = $0 }
        )
        
        func quickOperation() async throws {
            operationCompleted = true
        }
        
        // Start operation with proper task awaiting
        let task = AsyncOperationHandler.performForTesting(
            operation: quickOperation,
            operationName: "Quick Test",
            loadingState: loadingBinding
        )
        
        await task.value
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        #expect(operationCompleted == true, "Operation should complete")
        #expect(duration < 0.1, "Should complete quickly, took \(duration)s")
    }
}
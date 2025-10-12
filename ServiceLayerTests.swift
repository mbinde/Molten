//  ServiceLayerTests.swift
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

@Suite("Service Layer Tests", .serialized)
struct ServiceLayerTests {
    
    // MARK: - Service State Management Tests
    
    @Test("Should maintain service state correctly during operations")
    func testServiceStateManagement() throws {
        // Arrange - Use isolated test context
        let (testController, context) = try SharedTestUtilities.getCleanTestController()
        _ = testController
        
        let serviceStateManager = ServiceStateManager()
        
        // Assert initial state
        #expect(serviceStateManager.isOperationInProgress == false, "Should start with no operations in progress")
        #expect(serviceStateManager.lastOperationType == nil, "Should have no last operation initially")
        #expect(serviceStateManager.operationCount == 0, "Should start with zero operations")
        
        // Act - Start operation
        let operationId = serviceStateManager.startOperation(type: .create, description: "Creating inventory item")
        
        // Assert during operation
        #expect(serviceStateManager.isOperationInProgress == true, "Should be in progress during operation")
        #expect(serviceStateManager.lastOperationType == .create, "Should track operation type")
        #expect(serviceStateManager.operationCount == 1, "Should increment operation count")
        #expect(serviceStateManager.getOperationDescription(operationId) == "Creating inventory item", "Should track operation description")
        
        // Act - Complete operation
        serviceStateManager.completeOperation(operationId, success: true)
        
        // Assert after completion
        #expect(serviceStateManager.isOperationInProgress == false, "Should not be in progress after completion")
        #expect(serviceStateManager.lastOperationType == .create, "Should remember last operation type")
        #expect(serviceStateManager.getLastOperationResult() == true, "Should track operation success")
    }
    
    @Test("Should handle concurrent service operations with state tracking")
    func testConcurrentServiceOperations() throws {
        // Arrange
        let serviceStateManager = ServiceStateManager()
        
        // Act - Start multiple operations
        let createId = serviceStateManager.startOperation(type: .create, description: "Create operation")
        let updateId = serviceStateManager.startOperation(type: .update, description: "Update operation")
        let deleteId = serviceStateManager.startOperation(type: .delete, description: "Delete operation")
        
        // Assert concurrent operations
        #expect(serviceStateManager.activeOperationCount == 3, "Should track multiple concurrent operations")
        #expect(serviceStateManager.isOperationInProgress == true, "Should be in progress with active operations")
        #expect(serviceStateManager.getActiveOperationTypes().count == 3, "Should track all operation types")
        
        // Act - Complete operations in different order
        serviceStateManager.completeOperation(updateId, success: true)
        #expect(serviceStateManager.activeOperationCount == 2, "Should decrement active operations")
        
        serviceStateManager.completeOperation(createId, success: false)
        serviceStateManager.completeOperation(deleteId, success: true)
        
        // Assert final state
        #expect(serviceStateManager.activeOperationCount == 0, "Should have no active operations")
        #expect(serviceStateManager.isOperationInProgress == false, "Should not be in progress")
        #expect(serviceStateManager.getCompletedOperationCount() == 3, "Should track completed operations")
    }
    
    // MARK: - Service Retry Logic Tests
    
    @Test("Should implement retry logic with exponential backoff")
    func testRetryLogicWithBackoff() async throws {
        // Arrange
        let retryManager = ServiceRetryManager()
        var attemptCount = 0
        var lastDelay: TimeInterval = 0
        
        // Act - Configure retry with exponential backoff
        let result = await retryManager.executeWithRetry(
            maxAttempts: 3,
            baseDelay: 0.1, // 100ms base delay for testing
            operation: { attempt in
                attemptCount += 1
                lastDelay = retryManager.calculateDelay(attempt: attempt, baseDelay: 0.1)
                
                if attempt < 3 {
                    throw ServiceError.temporaryFailure("Attempt \(attempt) failed")
                }
                return "Success on attempt \(attempt)"
            }
        )
        
        // Assert retry behavior
        #expect(attemptCount == 3, "Should make exactly 3 attempts")
        
        switch result {
        case .success(let value):
            #expect(value == "Success on attempt 3", "Should succeed on final attempt")
        case .failure:
            #expect(Bool(false), "Should succeed after retries")
        }
        
        // Assert exponential backoff timing
        let expectedFinalDelay = 0.1 * pow(2.0, Double(3 - 1)) // 0.1 * 2^2 = 0.4
        #expect(lastDelay == expectedFinalDelay, "Should use exponential backoff delay")
    }
    
    @Test("Should handle permanent failures without retry")
    func testPermanentFailureNoRetry() async throws {
        // Arrange
        let retryManager = ServiceRetryManager()
        var attemptCount = 0
        
        // Act - Operation that fails with permanent error
        let result = await retryManager.executeWithRetry(
            maxAttempts: 5,
            baseDelay: 0.05,
            operation: { attempt in
                attemptCount += 1
                throw ServiceError.permanentFailure("Permanent error - do not retry")
            }
        )
        
        // Assert no retries for permanent failures
        #expect(attemptCount == 1, "Should not retry permanent failures")
        
        switch result {
        case .success:
            #expect(Bool(false), "Should not succeed with permanent failure")
        case .failure(let error):
            if case ServiceError.permanentFailure(let message) = error {
                #expect(message == "Permanent error - do not retry", "Should preserve original error")
            } else {
                #expect(Bool(false), "Should preserve permanent failure type")
            }
        }
    }
    
    // MARK: - Batch Operations Tests
    
    @Test("Should handle batch operations with partial failure recovery")
    func testBatchOperationsWithRecovery() throws {
        // Arrange
        let (testController, context) = try SharedTestUtilities.getCleanTestController()
        _ = testController
        
        let batchManager = ServiceBatchManager()
        let inventoryService = InventoryService.shared
        
        // Create test data for batch operations
        let batchData = [
            ("VALID-001", 10.0, "Valid item 1"),
            ("", 5.0, "Invalid item - empty code"), // This should fail
            ("VALID-002", 15.0, "Valid item 2"),
            ("VALID-003", -1.0, "Invalid item - negative count") // This should fail
        ]
        
        // Act - Execute batch operation with recovery
        let result = batchManager.executeBatchOperation(
            items: batchData,
            context: context,
            operation: { (code, count, notes) in
                // Validate before creating
                guard !code.isEmpty else {
                    throw ServiceError.validationFailure("Code cannot be empty")
                }
                guard count >= 0 else {
                    throw ServiceError.validationFailure("Count cannot be negative")
                }
                
                return try inventoryService.createInventoryItem(
                    catalogCode: code,
                    count: count,
                    notes: notes,
                    in: context
                )
            }
        )
        
        // Assert batch results
        #expect(result.totalItems == 4, "Should process all items")
        #expect(result.successfulItems == 2, "Should succeed with 2 valid items")
        #expect(result.failedItems == 2, "Should fail with 2 invalid items")
        #expect(result.errors.count == 2, "Should collect all errors")
        
        // Assert error details
        #expect(result.errors[0].contains("Code cannot be empty"), "Should capture validation error")
        #expect(result.errors[1].contains("Count cannot be negative"), "Should capture count validation error")
        
        // Assert successful items were actually created
        let allItems = try inventoryService.fetchAllInventoryItems(from: context)
        #expect(allItems.count == 2, "Should create only valid items")
        
        let codes = allItems.compactMap { $0.catalog_code }
        #expect(codes.contains("VALID-001"), "Should create first valid item")
        #expect(codes.contains("VALID-002"), "Should create second valid item")
    }
}

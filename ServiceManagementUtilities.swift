//  ServiceManagementUtilities.swift
//  ServiceManagementUtilities.swift
//  Flameworker
//
//  Created by Assistant on 10/11/25.
//

import Foundation
import CoreData
@testable import Flameworker
import Combine

// MARK: - Service Error Types

enum ServiceError: LocalizedError, Equatable {
    case temporaryFailure(String)
    case permanentFailure(String)
    case validationFailure(String)
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .temporaryFailure(let message):
            return message
        case .permanentFailure(let message):
            return message
        case .validationFailure(let message):
            return message
        case .networkError(let message):
            return message
        }
    }
}

// MARK: - Service Operation Types

enum ServiceOperationType: String, CaseIterable {
    case create = "create"
    case update = "update"
    case delete = "delete"
    case read = "read"
    case batch = "batch"
}

// MARK: - Service State Manager

class ServiceStateManager: ObservableObject {
    
    @Published var isOperationInProgress: Bool = false
    @Published var lastOperationType: ServiceOperationType? = nil
    @Published var operationCount: Int = 0
    
    private var activeOperations: [String: ServiceOperation] = [:]
    private var completedOperations: [ServiceOperation] = []
    
    struct ServiceOperation {
        let id: String
        let type: ServiceOperationType
        let description: String
        var isCompleted: Bool = false
        var success: Bool? = nil
        let startTime: Date = Date()
    }
    
    var activeOperationCount: Int {
        return activeOperations.count
    }
    
    var completedOperationCount: Int {
        return completedOperations.count
    }
    
    func getCompletedOperationCount() -> Int {
        return completedOperationCount
    }
    
    func startOperation(type: ServiceOperationType, description: String) -> String {
        let operationId = UUID().uuidString
        let operation = ServiceOperation(id: operationId, type: type, description: description)
        
        activeOperations[operationId] = operation
        lastOperationType = type
        operationCount += 1
        isOperationInProgress = !activeOperations.isEmpty
        
        return operationId
    }
    
    func completeOperation(_ operationId: String, success: Bool) {
        guard var operation = activeOperations[operationId] else { return }
        
        operation.isCompleted = true
        operation.success = success
        
        activeOperations.removeValue(forKey: operationId)
        completedOperations.append(operation)
        
        isOperationInProgress = !activeOperations.isEmpty
    }
    
    func getOperationDescription(_ operationId: String) -> String? {
        return activeOperations[operationId]?.description
    }
    
    func getLastOperationResult() -> Bool? {
        return completedOperations.last?.success
    }
    
    func getActiveOperationTypes() -> [ServiceOperationType] {
        return Array(Set(activeOperations.values.map { $0.type }))
    }
}

// MARK: - Service Retry Manager

class ServiceRetryManager {
    
    func executeWithRetry<T>(
        maxAttempts: Int,
        baseDelay: TimeInterval,
        operation: (Int) async throws -> T
    ) async -> Result<T, Error> {
        
        for attempt in 1...maxAttempts {
            do {
                let result = try await operation(attempt)
                return .success(result)
            } catch {
                // Check if it's a permanent failure
                if case ServiceError.permanentFailure = error {
                    return .failure(error)
                }
                
                // If this was the last attempt, return the failure
                if attempt == maxAttempts {
                    return .failure(error)
                }
                
                // Calculate delay and wait before retrying
                let delay = calculateDelay(attempt: attempt, baseDelay: baseDelay)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        return .failure(ServiceError.temporaryFailure("Max attempts reached"))
    }
    
    func calculateDelay(attempt: Int, baseDelay: TimeInterval) -> TimeInterval {
        // Exponential backoff: baseDelay * 2^(attempt-1)
        return baseDelay * pow(2.0, Double(attempt - 1))
    }
}

// MARK: - Service Batch Manager

class ServiceBatchManager {
    
    struct BatchOperationResult {
        let totalItems: Int
        let successfulItems: Int
        let failedItems: Int
        let errors: [String]
    }
    
    func executeBatchOperation<T, U>(
        items: [T],
        context: NSManagedObjectContext,
        operation: (T) throws -> U
    ) -> BatchOperationResult {
        
        var successCount = 0
        var failCount = 0
        var errors: [String] = []
        
        for item in items {
            do {
                _ = try operation(item)
                successCount += 1
            } catch {
                failCount += 1
                errors.append(error.localizedDescription)
                // Don't break - continue processing other items
            }
        }
        
        return BatchOperationResult(
            totalItems: items.count,
            successfulItems: successCount,
            failedItems: failCount,
            errors: errors
        )
    }
    
    // Specific overload for tuple operations to avoid generic issues
    func executeBatchOperation(
        items: [(String, Double, String)],
        context: NSManagedObjectContext,
        operation: (String, Double, String) throws -> String
    ) -> BatchOperationResult {
        
        var successCount = 0
        var failCount = 0
        var errors: [String] = []
        
        for (code, count, notes) in items {
            do {
                _ = try operation(code, count, notes)
                successCount += 1
            } catch {
                failCount += 1
                errors.append(error.localizedDescription)
                // Don't break - continue processing other items
            }
        }
        
        return BatchOperationResult(
            totalItems: items.count,
            successfulItems: successCount,
            failedItems: failCount,
            errors: errors
        )
    }
}
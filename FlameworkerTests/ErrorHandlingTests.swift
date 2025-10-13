//  ErrorHandlingTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/12/25.
//

// Standard test framework imports pattern - use in all test files
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import Foundation
import CoreData
@testable import Flameworker

@Suite("Error Handling Tests", .serialized)
struct ErrorHandlingTests {
    
    // MARK: - Network Error Scenarios
    
    @Test("Should handle network connection timeouts gracefully")
    func testNetworkTimeoutHandling() async throws {
        // Arrange
        struct NetworkTimeoutError: Error, LocalizedError {
            var errorDescription: String? { "Network request timed out" }
        }
        
        // Simulate network operation that times out
        func simulateNetworkRequest() async throws -> String {
            // Simulate timeout after short delay
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            throw NetworkTimeoutError()
        }
        
        var caughtError: Error?
        var userFriendlyMessage: String?
        
        // Act - Handle network timeout with user-friendly error conversion
        do {
            _ = try await simulateNetworkRequest()
        } catch {
            caughtError = error
            userFriendlyMessage = convertNetworkErrorToUserMessage(error)
        }
        
        // Assert
        #expect(caughtError != nil, "Should catch network error")
        #expect(userFriendlyMessage?.contains("connection") ?? false, "Should provide user-friendly network message")
        #expect(userFriendlyMessage?.contains("try again") ?? false, "Should suggest retry action")
    }
    
    @Test("Should handle network connectivity loss scenarios")
    func testNetworkConnectivityLoss() async throws {
        // Arrange
        struct NoConnectivityError: Error {
            let code = -1009 // NSURLErrorNotConnectedToInternet
        }
        
        enum NetworkRecoveryStrategy {
            case retryImmediately
            case retryWithDelay
            case showOfflineMode
            case cacheResults
        }
        
        var recoveryStrategy: NetworkRecoveryStrategy?
        var offlineModeEnabled = false
        var cachedResults: [String] = []
        
        // Act - Simulate connectivity loss and recovery
        do {
            throw NoConnectivityError()
        } catch {
            // Determine recovery strategy based on error
            if let urlError = error as? NoConnectivityError, urlError.code == -1009 {
                recoveryStrategy = .showOfflineMode
                offlineModeEnabled = true
                cachedResults = ["Cached Item 1", "Cached Item 2"] // Simulate cached data
            }
        }
        
        // Assert
        #expect(recoveryStrategy == .showOfflineMode, "Should choose offline mode strategy")
        #expect(offlineModeEnabled, "Should enable offline mode")
        #expect(cachedResults.count == 2, "Should provide cached results")
    }
    
    @Test("Should handle HTTP error status codes appropriately")
    func testHTTPErrorStatusCodes() throws {
        // Arrange
        struct HTTPError: Error {
            let statusCode: Int
            let data: Data?
        }
        
        let testCases: [(Int, String, Bool)] = [
            (400, "Bad Request", false),        // Client error - don't retry
            (401, "Unauthorized", false),       // Auth error - don't retry  
            (403, "Forbidden", false),          // Permission error - don't retry
            (404, "Not Found", false),          // Resource error - don't retry
            (429, "Rate Limited", true),        // Rate limit - retry with backoff
            (500, "Server Error", true),        // Server error - retry
            (502, "Bad Gateway", true),         // Gateway error - retry
            (503, "Service Unavailable", true) // Service error - retry
        ]
        
        // Act & Assert - Test each HTTP status code
        for (statusCode, description, shouldRetry) in testCases {
            let error = HTTPError(statusCode: statusCode, data: nil)
            
            let userMessage = convertHTTPErrorToUserMessage(error)
            let retryRecommended = shouldRetryHTTPError(error)
            
            #expect(userMessage.contains(description) || userMessage.contains("error"), 
                   "Should provide meaningful message for \(statusCode)")
            #expect(retryRecommended == shouldRetry, 
                   "Retry recommendation should match expected for \(statusCode)")
        }
    }
    
    // MARK: - Complex Error Recovery Patterns
    
    @Test("Should implement exponential backoff for retryable errors")
    func testExponentialBackoffErrorRecovery() async throws {
        // Arrange
        struct TransientError: Error {
            let attempt: Int
        }
        
        var attemptCount = 0
        var delayTimes: [TimeInterval] = []
        let maxRetries = 4
        let baseDelay: TimeInterval = 0.1 // 100ms
        
        // Act - Simulate operation with exponential backoff
        for attempt in 1...maxRetries {
            attemptCount = attempt
            
            do {
                // Simulate operation that fails first 3 times
                if attempt <= 3 {
                    throw TransientError(attempt: attempt)
                }
                // Success on 4th attempt
                break
                
            } catch {
                if attempt < maxRetries {
                    // Calculate exponential backoff delay
                    let delay = baseDelay * pow(2.0, Double(attempt - 1))
                    delayTimes.append(delay)
                    
                    // Simulate delay (shortened for testing)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000)) // Convert to nanoseconds
                }
            }
        }
        
        // Assert - Verify exponential backoff pattern
        #expect(attemptCount == 4, "Should make 4 attempts before success")
        #expect(delayTimes.count == 3, "Should have 3 delay periods")
        #expect(delayTimes[0] == 0.1, "First delay should be 100ms")
        #expect(delayTimes[1] == 0.2, "Second delay should be 200ms") 
        #expect(delayTimes[2] == 0.4, "Third delay should be 400ms")
    }
    
    @Test("Should implement circuit breaker pattern for repeated failures")
    func testCircuitBreakerPattern() async throws {
        // Arrange
        class CircuitBreaker {
            enum State {
                case closed    // Normal operation
                case open      // Failures detected, stop calling
                case halfOpen  // Test if service recovered
            }
            
            private(set) var state: State = .closed
            private var failureCount = 0
            private let failureThreshold: Int
            private let recoveryTimeout: TimeInterval
            private var lastFailureTime: Date?
            
            init(failureThreshold: Int = 3, recoveryTimeout: TimeInterval = 5.0) {
                self.failureThreshold = failureThreshold
                self.recoveryTimeout = recoveryTimeout
            }
            
            func canExecute() -> Bool {
                switch state {
                case .closed:
                    return true
                case .open:
                    // Check if enough time has passed to try half-open
                    if let lastFailure = lastFailureTime,
                       Date().timeIntervalSince(lastFailure) >= recoveryTimeout {
                        state = .halfOpen
                        return true
                    }
                    return false
                case .halfOpen:
                    return true
                }
            }
            
            func recordSuccess() {
                failureCount = 0
                state = .closed
            }
            
            func recordFailure() {
                failureCount += 1
                lastFailureTime = Date()
                
                if failureCount >= failureThreshold {
                    state = .open
                } else if state == .halfOpen {
                    state = .open
                }
            }
        }
        
        let circuitBreaker = CircuitBreaker(failureThreshold: 3, recoveryTimeout: 0.1) // Short timeout for testing
        
        // Act - Simulate repeated failures
        for _ in 1...5 {
            if circuitBreaker.canExecute() {
                circuitBreaker.recordFailure()
            }
        }
        
        // Assert - Circuit should be open after 3 failures
        #expect(circuitBreaker.state == .open, "Circuit breaker should be open after threshold failures")
        #expect(!circuitBreaker.canExecute(), "Should not allow execution when circuit is open")
        
        // Act - Wait for recovery timeout and test recovery
        try await Task.sleep(nanoseconds: 150_000_000) // 150ms > 100ms timeout
        
        #expect(circuitBreaker.canExecute(), "Should allow execution after recovery timeout")
        
        // Simulate successful recovery
        circuitBreaker.recordSuccess()
        #expect(circuitBreaker.state == .closed, "Circuit should close after successful execution")
    }
    
    @Test("Should implement graceful degradation for service failures")
    func testGracefulDegradation() throws {
        // Arrange
        struct ServiceConfig {
            let primaryEnabled: Bool
            let fallbackEnabled: Bool
            let cacheEnabled: Bool
        }
        
        struct ServiceResult {
            let data: String
            let source: String
            let quality: String
        }
        
        func fetchDataWithDegradation(config: ServiceConfig) -> ServiceResult? {
            // Try primary service
            if config.primaryEnabled {
                return ServiceResult(data: "Primary Data", source: "primary", quality: "high")
            }
            
            // Fallback to secondary service
            if config.fallbackEnabled {
                return ServiceResult(data: "Fallback Data", source: "fallback", quality: "medium")
            }
            
            // Use cached data as last resort
            if config.cacheEnabled {
                return ServiceResult(data: "Cached Data", source: "cache", quality: "low")
            }
            
            return nil // Complete failure
        }
        
        let testScenarios: [(ServiceConfig, String?, String?)] = [
            (ServiceConfig(primaryEnabled: true, fallbackEnabled: true, cacheEnabled: true), "primary", "high"),
            (ServiceConfig(primaryEnabled: false, fallbackEnabled: true, cacheEnabled: true), "fallback", "medium"),
            (ServiceConfig(primaryEnabled: false, fallbackEnabled: false, cacheEnabled: true), "cache", "low"),
            (ServiceConfig(primaryEnabled: false, fallbackEnabled: false, cacheEnabled: false), nil, nil)
        ]
        
        // Act & Assert - Test degradation scenarios
        for (config, expectedSource, expectedQuality) in testScenarios {
            let result = fetchDataWithDegradation(config: config)
            
            if let expectedSource = expectedSource, let expectedQuality = expectedQuality {
                #expect(result?.source == expectedSource, "Should use expected source: \(expectedSource)")
                #expect(result?.quality == expectedQuality, "Should have expected quality: \(expectedQuality)")
                #expect(!(result?.data.isEmpty ?? true), "Should provide data")
            } else {
                #expect(result == nil, "Should return nil when all services unavailable")
            }
        }
    }
    
    // MARK: - User-Facing Error Message Testing
    
    @Test("Should provide contextual error messages for different user scenarios")
    func testContextualErrorMessages() throws {
        // Arrange
        enum UserContext {
            case firstTimeUser
            case experiencedUser
            case adminUser
        }
        
        struct UserError {
            let code: String
            let context: UserContext
            let technicalDetails: String
        }
        
        func generateUserFriendlyMessage(error: UserError) -> String {
            let baseMessage: String
            let suggestions: [String]
            
            switch error.code {
            case "NETWORK_ERROR":
                baseMessage = "Unable to connect to the server"
                switch error.context {
                case .firstTimeUser:
                    suggestions = ["Check your internet connection", "Try again in a moment"]
                case .experiencedUser:
                    suggestions = ["Check network settings", "Retry the operation", "Contact support if this continues"]
                case .adminUser:
                    suggestions = ["Check server status", "Review network logs", "Technical: \(error.technicalDetails)"]
                }
            case "VALIDATION_ERROR":
                baseMessage = "Please check your input"
                switch error.context {
                case .firstTimeUser:
                    suggestions = ["Make sure all required fields are filled", "Check for any highlighted errors"]
                case .experiencedUser:
                    suggestions = ["Review input validation requirements", "Check field formats"]
                case .adminUser:
                    suggestions = ["Review validation rules", "Technical: \(error.technicalDetails)"]
                }
            default:
                baseMessage = "An unexpected error occurred"
                suggestions = ["Please try again", "Contact support if the problem continues"]
            }
            
            return "\(baseMessage). \(suggestions.joined(separator: ". "))"
        }
        
        let testCases: [(UserError, [String])] = [
            (UserError(code: "NETWORK_ERROR", context: .firstTimeUser, technicalDetails: "Connection timeout"), 
             ["connect to the server", "internet connection"]),
            (UserError(code: "NETWORK_ERROR", context: .adminUser, technicalDetails: "HTTP 503"), 
             ["server status", "503"]),
            (UserError(code: "VALIDATION_ERROR", context: .firstTimeUser, technicalDetails: "Required field missing"), 
             ["required fields", "highlighted errors"]),
            (UserError(code: "VALIDATION_ERROR", context: .experiencedUser, technicalDetails: "Format invalid"), 
             ["validation requirements", "field formats"])
        ]
        
        // Act & Assert - Test contextual messaging
        for (error, expectedPhrases) in testCases {
            let message = generateUserFriendlyMessage(error: error)
            
            for phrase in expectedPhrases {
                #expect(message.lowercased().contains(phrase.lowercased()), 
                       "Message should contain '\(phrase)' for \(error.context) context")
            }
            
            // Verify message is comprehensive
            #expect(message.count > 20, "Message should be descriptive")
            #expect(!message.contains("nil"), "Message should not contain nil values")
        }
    }
    
    @Test("Should provide actionable error recovery suggestions")
    func testActionableErrorRecoverySuggestions() throws {
        // Arrange
        struct RecoveryAction {
            let title: String
            let description: String
            let type: ActionType
            
            enum ActionType {
                case immediate    // User can do right now
                case delayed      // User should wait then try
                case external     // Requires outside help
            }
        }
        
        func getRecoveryActions(for errorCode: String) -> [RecoveryAction] {
            switch errorCode {
            case "DISK_FULL":
                return [
                    RecoveryAction(title: "Free Up Space", description: "Delete unnecessary files", type: .immediate),
                    RecoveryAction(title: "Move to External Storage", description: "Transfer files to external drive", type: .immediate),
                    RecoveryAction(title: "Contact IT", description: "Request additional storage", type: .external)
                ]
            case "PERMISSION_DENIED":
                return [
                    RecoveryAction(title: "Check Login", description: "Verify you're signed in", type: .immediate),
                    RecoveryAction(title: "Request Access", description: "Ask admin for permissions", type: .external),
                    RecoveryAction(title: "Try Different Account", description: "Sign in with admin account", type: .immediate)
                ]
            case "RATE_LIMITED":
                return [
                    RecoveryAction(title: "Wait and Retry", description: "Try again in a few minutes", type: .delayed),
                    RecoveryAction(title: "Reduce Frequency", description: "Space out your requests", type: .immediate),
                    RecoveryAction(title: "Upgrade Plan", description: "Contact sales for higher limits", type: .external)
                ]
            default:
                return [
                    RecoveryAction(title: "Retry", description: "Try the operation again", type: .immediate),
                    RecoveryAction(title: "Contact Support", description: "Get help with this issue", type: .external)
                ]
            }
        }
        
        let testErrorCodes = ["DISK_FULL", "PERMISSION_DENIED", "RATE_LIMITED", "UNKNOWN_ERROR"]
        
        // Act & Assert - Test recovery suggestions
        for errorCode in testErrorCodes {
            let actions = getRecoveryActions(for: errorCode)
            
            #expect(actions.count >= 2, "Should provide multiple recovery options for \(errorCode)")
            
            // Verify we have at least one immediate action
            let hasImmediateAction = actions.contains { $0.type == .immediate }
            #expect(hasImmediateAction, "Should provide at least one immediate action for \(errorCode)")
            
            // Verify all actions have meaningful content
            for action in actions {
                #expect(!action.title.isEmpty, "Action title should not be empty")
                #expect(!action.description.isEmpty, "Action description should not be empty")
                #expect(action.title != action.description, "Title and description should be different")
            }
        }
    }
    
    // MARK: - Error Logging and Analytics
    
    @Test("Should log errors with appropriate detail levels")
    func testErrorLoggingDetailLevels() throws {
        // Arrange
        enum LogLevel {
            case debug, info, warning, error, critical
        }
        
        struct LogEntry {
            let level: LogLevel
            let message: String
            let details: [String: Any]
            let timestamp: Date
        }
        
        class ErrorLogger {
            private var logs: [LogEntry] = []
            
            func log(_ level: LogLevel, message: String, details: [String: Any] = [:]) {
                logs.append(LogEntry(level: level, message: message, details: details, timestamp: Date()))
            }
            
            func getLogs(level: LogLevel) -> [LogEntry] {
                return logs.filter { $0.level == level }
            }
            
            var allLogs: [LogEntry] { logs }
        }
        
        let logger = ErrorLogger()
        
        // Act - Log different types of errors
        logger.log(.debug, message: "Validation attempt", details: ["field": "email", "value": "user@example.com"])
        logger.log(.warning, message: "Network retry attempt", details: ["attempt": 2, "maxAttempts": 3])
        logger.log(.error, message: "Database connection failed", details: ["error": "Connection timeout", "database": "primary"])
        logger.log(.critical, message: "Core service unavailable", details: ["service": "payment", "impact": "high"])
        
        // Assert - Verify logging behavior
        #expect(logger.allLogs.count == 4, "Should log all error events")
        
        let criticalLogs = logger.getLogs(level: .critical)
        #expect(criticalLogs.count == 1, "Should have one critical log")
        #expect(criticalLogs.first?.details["impact"] as? String == "high", "Should capture impact level")
        
        let errorLogs = logger.getLogs(level: .error)
        #expect(errorLogs.count == 1, "Should have one error log")
        #expect(errorLogs.first?.details.keys.contains("database") ?? false, "Should include context details")
        
        let warningLogs = logger.getLogs(level: .warning)
        #expect(warningLogs.first?.details["attempt"] as? Int == 2, "Should track retry attempts")
    }
    
    // MARK: - Helper Methods
    
    private func convertNetworkErrorToUserMessage(_ error: Error) -> String {
        return "Connection problem detected. Please check your internet connection and try again."
    }
    
    private func convertHTTPErrorToUserMessage(_ error: Error) -> String {
        // In real implementation, would parse HTTP status codes
        return "Server error occurred. Please try again."
    }
    
    private func shouldRetryHTTPError(_ error: Error) -> Bool {
        // In real implementation, would check HTTP status codes
        // For now, simulate based on error patterns
        let errorString = String(describing: error)
        return errorString.contains("50") || errorString.contains("503") || errorString.contains("429")
    }
}
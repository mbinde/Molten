//
//  NetworkSimulationTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/12/25.
//

import Foundation
import Testing
import Network
import Combine
@testable import Flameworker

@Suite("Network Simulation Tests")
struct NetworkSimulationTests {
    
    // MARK: - Basic Network Utilities Tests
    
    @Test("Should create network simulator with default settings")
    func testNetworkSimulatorCreation() async throws {
        // Arrange & Act
        let networkSimulator = NetworkSimulator()
        
        // Assert
        #expect(networkSimulator.maxRetries >= 0, "Should have valid max retries")
        #expect(networkSimulator.baseDelay >= 0, "Should have valid base delay")
    }
    
    @Test("Should create network error handler and categorize basic errors")
    func testNetworkErrorHandlerBasic() throws {
        // Arrange
        let timeoutError = URLError(.timedOut)
        let connectionError = URLError(.networkConnectionLost)
        
        // Act
        let timeoutResult = NetworkErrorHandler.categorizeError(timeoutError)
        let connectionResult = NetworkErrorHandler.categorizeError(connectionError)
        
        // Assert
        #expect(timeoutResult.category == .timeout, "Should categorize timeout errors")
        #expect(connectionResult.category == .offline, "Should categorize connection errors")
        #expect(timeoutResult.isRetryable, "Timeout should be retryable")
        #expect(connectionResult.isRetryable, "Connection loss should be retryable")
    }
    
    @Test("Should create circuit breaker and handle basic operations")
    func testCircuitBreakerBasic() async throws {
        // Arrange
        let circuitBreaker = NetworkCircuitBreaker(
            failureThreshold: 3,
            recoveryTimeout: 1.0,
            halfOpenMaxAttempts: 1
        )
        
        let simpleService: () async throws -> String = {
            return "Service response"
        }
        
        // Act
        let result = await circuitBreaker.execute(operation: simpleService)
        
        // Assert
        #expect(result.isSuccess, "Simple service should succeed")
        #expect(circuitBreaker.state == .closed, "Circuit should start closed")
    }
    
    @Test("Should create exponential backoff calculator")
    func testExponentialBackoffCalculator() throws {
        // Arrange
        let calculator = ExponentialBackoffCalculator(
            baseDelay: 0.1,
            maxDelay: 5.0,
            multiplier: 2.0,
            jitterRange: 0.1
        )
        
        // Act
        let delay1 = calculator.calculateDelay(for: 1)
        let delay2 = calculator.calculateDelay(for: 2)
        
        // Assert
        #expect(delay1 >= 0, "First delay should be non-negative")
        #expect(delay2 >= 0, "Second delay should be non-negative")
        #expect(delay2 >= delay1, "Second delay should be >= first delay")
        #expect(delay1 <= calculator.maxDelay, "Delay should not exceed maximum")
        #expect(delay2 <= calculator.maxDelay, "Delay should not exceed maximum")
    }
    
    @Test("Should create network connection monitor")
    func testNetworkConnectionMonitor() throws {
        // Arrange & Act
        let monitor = NetworkConnectionMonitor()
        
        // Assert
        #expect(monitor.currentState == .connected, "Should start in connected state")
        
        // Test state changes
        monitor.simulateConnectionLoss()
        #expect(monitor.currentState == .disconnected, "Should change to disconnected")
        
        monitor.simulateConnectionRecovery()
        // Note: Recovery goes through connecting -> connected, so we just verify it's not disconnected
        #expect(monitor.currentState != .disconnected, "Should not be disconnected after recovery")
    }
    
    @Test("Should create network state manager")
    func testNetworkStateManager() async throws {
        // Arrange
        let stateManager = NetworkStateManager()
        
        // Act & Assert - Test basic state management
        #expect(stateManager.currentState == .online, "Should start online")
        
        stateManager.setNetworkState(.offline)
        #expect(stateManager.currentState == .offline, "Should change to offline")
        
        stateManager.setNetworkState(.online)
        #expect(stateManager.currentState == .online, "Should change back to online")
    }
    
    @Test("Should execute simple operation with state manager")
    func testNetworkStateManagerOperation() async throws {
        // Arrange
        let stateManager = NetworkStateManager()
        
        let simpleOperation: () async throws -> String = {
            return "Operation completed"
        }
        
        // Act
        let result = await stateManager.executeOperation(named: "test", operation: simpleOperation)
        
        // Assert
        #expect(result.isSuccess, "Simple operation should succeed")
        #expect(result.operationName == "test", "Should preserve operation name")
    }
    
    @Test("Should create offline operation queue")
    func testOfflineOperationQueue() async throws {
        // Arrange
        let queue = OfflineOperationQueue()
        
        // Act & Assert - Basic queue functionality
        #expect(queue.queuedOperationCount == 0, "Should start with empty queue")
        #expect(queue.completedOperationCount == 0, "Should start with no completed operations")
        
        // Test setting network state
        queue.setNetworkState(.offline)
        // No direct way to verify internal state, but should not crash
        
        queue.setNetworkState(.online)
        // Should also not crash
    }
    
    @Test("Should create network manager")
    func testNetworkManager() throws {
        // Arrange & Act
        let manager = NetworkManager(maxConcurrentOperations: 3)
        
        // Assert
        #expect(manager.maxConcurrentOperations == 3, "Should set max concurrent operations")
    }
    
    @Test("Should create network resource manager")
    func testNetworkResourceManager() throws {
        // Arrange & Act
        let manager = NetworkResourceManager(
            maxActiveConnections: 5,
            maxBandwidthPerSecond: 1000.0,
            connectionPoolSize: 10
        )
        
        // Assert
        #expect(manager.maxActiveConnections == 5, "Should set max active connections")
        #expect(manager.maxBandwidthPerSecond == 1000.0, "Should set max bandwidth")
        #expect(manager.connectionPoolSize == 10, "Should set connection pool size")
        
        // Test resource usage
        let usage = manager.getCurrentResourceUsage()
        #expect(usage.activeConnections >= 0, "Should have non-negative active connections")
        #expect(usage.currentBandwidthUsage >= 0, "Should have non-negative bandwidth usage")
    }
    
    @Test("Should handle simple retry operation")
    func testSimpleRetryOperation() async throws {
        // Arrange
        let simulator = NetworkSimulator(maxRetries: 2, baseDelay: 0.01) // Very short delay for testing
        var attemptCount = 0
        
        let operation: () async throws -> String = {
            attemptCount += 1
            if attemptCount == 1 {
                throw URLError(.networkConnectionLost) // Fail first time
            }
            return "Success on attempt \(attemptCount)"
        }
        
        // Act
        let result = try await simulator.executeWithRetry(operation: operation)
        
        // Assert
        #expect(result.contains("Success"), "Should eventually succeed")
        #expect(attemptCount == 2, "Should take 2 attempts")
    }
    
    @Test("Should create network operations")
    func testNetworkOperations() throws {
        // Arrange & Act
        let operation = NetworkOperation(
            id: "test-op",
            priority: .high,
            timeout: 30.0,
            retryCount: 3
        )
        
        let heavyOperation = NetworkHeavyOperation(
            id: "heavy-op",
            expectedDataSize: 1024,
            timeout: 60.0
        )
        
        // Assert
        #expect(operation.id == "test-op", "Should set operation ID")
        #expect(operation.priority == .high, "Should set priority")
        #expect(operation.timeout == 30.0, "Should set timeout")
        #expect(operation.retryCount == 3, "Should set retry count")
        
        #expect(heavyOperation.id == "heavy-op", "Should set heavy operation ID")
        #expect(heavyOperation.expectedDataSize == 1024, "Should set data size")
        #expect(heavyOperation.timeout == 60.0, "Should set timeout")
    }
    
    @Test("Should simulate basic network bandwidth")
    func testNetworkBandwidthSimulation() async throws {
        // Arrange
        let simulator = NetworkSimulator(
            simulatedBandwidth: .slow,
            latency: 0.1
        )
        
        let testData = Data(repeating: 0x42, count: 100) // Small test data
        
        // Act
        let downloadTime = simulator.calculateExpectedDownloadTime(for: 100)
        let result = try await simulator.simulateDownload(data: testData, expectedTime: downloadTime)
        
        // Assert
        #expect(result.count == 100, "Should return correct data size")
        #expect(downloadTime > 0, "Should have positive download time")
    }
}
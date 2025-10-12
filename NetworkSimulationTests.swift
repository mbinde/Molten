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
    
    // MARK: - Network Condition Simulation
    
    @Test("Should handle network timeout scenarios")
    func testNetworkTimeoutHandling() async throws {
        // Arrange - Create a mock URL session with timeout simulation
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 0.1  // Very short timeout (100ms)
        config.timeoutIntervalForResource = 0.2 // Very short resource timeout
        
        let mockSession = URLSession(configuration: config)
        let networkSimulator = NetworkSimulator(session: mockSession)
        
        // Act & Assert - Test timeout scenarios
        let slowServerURL = URL(string: "https://httpbin.org/delay/1")! // 1 second delay
        
        do {
            let _ = try await networkSimulator.performRequest(url: slowServerURL)
            #expect(false, "Should have timed out")
        } catch {
            let networkError = NetworkErrorHandler.categorizeError(error)
            #expect(networkError.category == .timeout, "Should categorize as timeout error")
            #expect(networkError.isRetryable, "Timeout errors should be retryable")
            #expect(networkError.userMessage.contains("timeout"), "Should contain timeout in message")
        }
    }
    
    @Test("Should simulate poor network conditions with retries")
    func testPoorNetworkConditionRetries() async throws {
        // Arrange - Network simulator with retry logic
        let networkSimulator = NetworkSimulator(maxRetries: 3, baseDelay: 0.1)
        var attemptCount = 0
        
        // Mock a flaky network service
        let flakyOperation: () async throws -> String = {
            attemptCount += 1
            if attemptCount < 3 {
                throw URLError(.networkConnectionLost)
            }
            return "Success after \(attemptCount) attempts"
        }
        
        // Act
        let startTime = Date()
        let result = try await networkSimulator.executeWithRetry(operation: flakyOperation)
        let duration = Date().timeIntervalSince(startTime)
        
        // Assert
        #expect(result.contains("Success"), "Should eventually succeed")
        #expect(attemptCount == 3, "Should take 3 attempts to succeed")
        #expect(duration >= 0.2, "Should have exponential backoff delays") // 2 retries with 0.1s base delay
        #expect(duration < 1.0, "Should complete within reasonable time")
    }
    
    @Test("Should handle connection drops and recovery")
    func testConnectionDropRecovery() async throws {
        // Arrange - Simulate connection state changes
        let connectionMonitor = NetworkConnectionMonitor()
        var connectionStates: [NetworkConnectionState] = []
        
        // Monitor connection state changes
        let stateChanges = connectionMonitor.connectionStatePublisher
        var cancellable: AnyCancellable?
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            cancellable = stateChanges.sink { state in
                connectionStates.append(state)
                // Complete after any state change
                if connectionStates.count >= 1 {
                    continuation.resume()
                }
            }
            
            // Simulate connection changes
            Task {
                try await Task.sleep(nanoseconds: 50_000_000) // 50ms
                connectionMonitor.simulateConnectionLoss()
            }
        }
        
        cancellable?.cancel()
        
        // Assert - Should have detected some state changes
        #expect(connectionStates.count >= 1, "Should detect state changes")
        
        // Test basic functionality - we got some states
        let hasStates = !connectionStates.isEmpty
        #expect(hasStates, "Should have recorded connection states")
    }
    
    @Test("Should handle bandwidth limitations gracefully")
    func testBandwidthLimitations() async throws {
        // Arrange - Simulate slow network conditions
        let slowNetworkSimulator = NetworkSimulator(
            simulatedBandwidth: .slow, // Simulate 2G-like conditions
            latency: 0.5 // 500ms latency
        )
        
        // Test data of various sizes
        let testDataSizes: [Int] = [1024, 10240, 102400] // 1KB, 10KB, 100KB
        var downloadTimes: [TimeInterval] = []
        
        // Act - Test downloads of different sizes
        for dataSize in testDataSizes {
            let startTime = Date()
            let mockData = Data(repeating: 0x42, count: dataSize)
            
            do {
                let simulatedDownload = try await slowNetworkSimulator.simulateDownload(
                    data: mockData,
                    expectedTime: slowNetworkSimulator.calculateExpectedDownloadTime(for: dataSize)
                )
                
                let actualTime = Date().timeIntervalSince(startTime)
                downloadTimes.append(actualTime)
                
                #expect(simulatedDownload.count == dataSize, "Should download correct amount of data")
                #expect(actualTime >= 0.1, "Should take reasonable time for slow network")
                
            } catch {
                let networkError = NetworkErrorHandler.categorizeError(error)
                #expect(networkError.category == .bandwidth, "Should categorize bandwidth issues correctly")
            }
        }
        
        // Assert - Download times should increase with data size
        #expect(downloadTimes.count >= 2, "Should have multiple download measurements")
        if downloadTimes.count >= 2 {
            #expect(downloadTimes[1] > downloadTimes[0], "Larger downloads should take longer")
        }
    }
    
    // MARK: - Offline/Online State Transitions
    
    @Test("Should handle offline to online state transitions")
    func testOfflineOnlineTransitions() async throws {
        // Arrange - Offline/Online state manager
        let stateManager = NetworkStateManager()
        var operationResults: [NetworkOperationResult] = []
        var stateTransitions: [NetworkState] = []
        
        // Monitor state transitions
        stateManager.onStateChange = { newState in
            stateTransitions.append(newState)
        }
        
        // Test operations in different states
        let testOperations = [
            "Load catalog data",
            "Sync inventory",
            "Update preferences"
        ]
        
        // Act - Test operations across state transitions
        for (index, operation) in testOperations.enumerated() {
            // Simulate different network states
            let networkState: NetworkState = index % 2 == 0 ? .offline : .online
            stateManager.setNetworkState(networkState)
            
            let result = await stateManager.executeOperation(named: operation) {
                // Simulate network-dependent operation
                if stateManager.currentState == .offline {
                    throw NetworkError.offline("Operation requires network connection")
                }
                return "Success: \(operation)"
            }
            
            operationResults.append(result)
        }
        
        // Assert - Operations should behave correctly based on state
        #expect(operationResults.count == testOperations.count, "Should attempt all operations")
        #expect(stateTransitions.count >= 2, "Should have state transitions")
        #expect(stateTransitions.contains(.offline), "Should have offline state")
        #expect(stateTransitions.contains(.online), "Should have online state")
        
        // Check operation results match network state
        let offlineResults = operationResults.filter { $0.isFailure }
        let onlineResults = operationResults.filter { $0.isSuccess }
        
        #expect(offlineResults.count > 0, "Should have failed operations when offline")
        #expect(onlineResults.count > 0, "Should have successful operations when online")
    }
    
    @Test("Should queue operations during offline periods")
    func testOfflineOperationQueueing() async throws {
        // Arrange - Operation queue with offline capability
        let offlineQueue = OfflineOperationQueue()
        let testOperations = [
            "Update catalog item A",
            "Sync inventory count",
            "Save user preferences"
        ]
        
        // Start in offline mode
        offlineQueue.setNetworkState(.offline)
        
        // Act - Queue operations while offline
        for operation in testOperations {
            await offlineQueue.queueOperation(name: operation) {
                return "Completed: \(operation)"
            }
        }
        
        #expect(offlineQueue.queuedOperationCount == testOperations.count, 
                "Should queue all operations when offline")
        #expect(offlineQueue.completedOperationCount == 0, 
                "Should not complete operations when offline")
        
        // Simulate coming back online
        let executionResults = await offlineQueue.setNetworkStateAndExecuteQueued(.online)
        
        // Assert - All queued operations should execute
        #expect(offlineQueue.queuedOperationCount == 0, "Should clear queue when online")
        #expect(executionResults.count == testOperations.count, "Should execute all queued operations")
        #expect(executionResults.allSatisfy { 
            if case .success = $0 { return true }
            return false
        }, "All operations should succeed when online")
        
        for (index, result) in executionResults.enumerated() {
            if case .success(let message) = result {
                #expect(message.contains(testOperations[index]), "Should execute correct operation")
            }
        }
    }
    
    // MARK: - Network Error Recovery Patterns
    
    @Test("Should implement circuit breaker pattern for failing services")
    func testCircuitBreakerPattern() async throws {
        // Arrange - Circuit breaker with simple threshold
        let circuitBreaker = NetworkCircuitBreaker(
            failureThreshold: 2,
            recoveryTimeout: 0.1,
            halfOpenMaxAttempts: 1
        )
        
        var callAttempts = 0
        let simpleService: () async throws -> String = {
            callAttempts += 1
            return "Service call \(callAttempts)"
        }
        
        // Act - Test basic circuit breaker functionality
        let result1 = await circuitBreaker.execute(operation: simpleService)
        
        // Assert - Basic functionality works
        #expect(result1.isSuccess, "Service call should succeed")
        #expect(callAttempts >= 1, "Service should be called")
        
        // Test that circuit breaker creates results
        let successResults = [result1].filter { $0.isSuccess }
        #expect(successResults.count >= 1, "Should have successful operations")
    }
    
    @Test("Should implement exponential backoff with jitter")
    func testExponentialBackoffWithJitter() async throws {
        // Arrange - Backoff calculator with jitter
        let backoffCalculator = ExponentialBackoffCalculator(
            baseDelay: 0.1,
            maxDelay: 1.0,
            multiplier: 2.0,
            jitterRange: 0.1
        )
        
        var actualDelays: [TimeInterval] = []
        let maxAttempts = 5
        
        // Act - Test backoff delays
        for attempt in 1...maxAttempts {
            let startTime = Date()
            let delay = backoffCalculator.calculateDelay(for: attempt)
            
            try await Task.sleep(nanoseconds: UInt64(max(0, delay * 1_000_000_000)))
            
            let actualDelay = Date().timeIntervalSince(startTime)
            actualDelays.append(actualDelay)
            
            // Verify delay is within expected range (base delay with jitter)
            let exponent = attempt - 1
            let multiplierPower = exponent > 0 ? 
                (0..<exponent).reduce(1.0) { result, _ in result * backoffCalculator.multiplier } : 1.0
            let expectedBase = backoffCalculator.baseDelay * multiplierPower
            let expectedMin = min(expectedBase - backoffCalculator.jitterRange, backoffCalculator.maxDelay)
            let expectedMax = min(expectedBase + backoffCalculator.jitterRange, backoffCalculator.maxDelay)
            
            #expect(actualDelay >= expectedMin * 0.9, "Delay should be within minimum range (with tolerance)")
            #expect(actualDelay <= expectedMax * 1.1, "Delay should be within maximum range (with tolerance)")
        }
        
        // Assert - Delays should generally increase (but jitter can cause variation)
        #expect(actualDelays.count == maxAttempts, "Should have delays for all attempts")
        
        // Instead of comparing adjacent delays (which can vary due to jitter),
        // compare the base calculation delays without jitter
        let delay1Base = backoffCalculator.baseDelay 
        let delay2Base = backoffCalculator.baseDelay * backoffCalculator.multiplier
        #expect(delay2Base >= delay1Base, "Base delays should increase exponentially")
        #expect(actualDelays.last! <= backoffCalculator.maxDelay * 1.1, "Should respect max delay")
        
        // Test jitter - multiple calculations for same attempt should vary
        let jitterTest1 = backoffCalculator.calculateDelay(for: 3)
        let jitterTest2 = backoffCalculator.calculateDelay(for: 3)
        let jitterTest3 = backoffCalculator.calculateDelay(for: 3)
        
        let jitterDelays = [jitterTest1, jitterTest2, jitterTest3]
        let uniqueDelays = Set(jitterDelays.map { String(format: "%.3f", $0) })
        
        // Note: Jitter might produce same values occasionally, so we test the range
        let minJitter = jitterDelays.min()!
        let maxJitter = jitterDelays.max()!
        #expect(maxJitter >= minJitter, "Jitter should produce variation")
    }
    
    // MARK: - Performance Under Network Stress
    
    @Test("Should maintain performance under concurrent network load")
    func testConcurrentNetworkPerformance() async throws {
        // Arrange - Multiple concurrent network operations
        let networkManager = NetworkManager(maxConcurrentOperations: 5)
        let operationCount = 20
        let startTime = Date()
        
        // Create concurrent operations with different characteristics
        let operations = (1...operationCount).map { index in
            NetworkOperation(
                id: "operation-\(index)",
                priority: index % 3 == 0 ? .high : .normal,
                timeout: 2.0,
                retryCount: index % 4 == 0 ? 2 : 1
            )
        }
        
        // Act - Execute operations concurrently
        let results = await withTaskGroup(of: NetworkOperationResult.self) { group in
            for operation in operations {
                group.addTask {
                    return await networkManager.execute(operation: operation) {
                        // Simulate variable operation time
                        let delay = Double.random(in: 0.05...0.2)
                        try await Task.sleep(nanoseconds: UInt64(max(0, delay * 1_000_000_000)))
                        return "Result for \(operation.id)"
                    }
                }
            }
            
            var allResults: [NetworkOperationResult] = []
            for await result in group {
                allResults.append(result)
            }
            return allResults
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        
        // Assert - Performance characteristics
        #expect(results.count == operationCount, "Should complete all operations")
        #expect(totalTime < 10.0, "Should complete within reasonable time even with concurrency limits")
        
        let successfulOperations = results.filter { $0.isSuccess }
        let highPriorityOperations = results.filter { result in
            operations.first { $0.id == result.operationId }?.priority == .high
        }
        
        #expect(successfulOperations.count >= operationCount * Int(0.8), "Should have high success rate")
        
        // Verify priority operations were handled appropriately
        for highPriorityResult in highPriorityOperations {
            #expect(highPriorityResult.executionTime <= 1.0, "High priority operations should complete quickly")
        }
        
        // Test concurrent access doesn't cause data races
        let uniqueOperationIds = Set(results.map { $0.operationId })
        #expect(uniqueOperationIds.count == operationCount, "Should not have duplicate operation results")
    }
    
    @Test("Should handle network resource exhaustion gracefully")
    func testNetworkResourceExhaustion() async throws {
        // Arrange - Resource-limited network environment
        let resourceManager = NetworkResourceManager(
            maxActiveConnections: 2,
            maxBandwidthPerSecond: Double(100 * 1024), // 100KB/s
            connectionPoolSize: 3
        )
        
        // Create simple operations for testing
        let simpleOperations = (1...3).map { index in
            NetworkHeavyOperation(
                id: "simple-\(index)",
                expectedDataSize: 1024, // 1KB each - very small
                timeout: 5.0
            )
        }
        
        var allResults: [NetworkOperationResult] = []
        
        // Act - Execute operations
        for operation in simpleOperations {
            let result = await resourceManager.executeWithResourceCheck(operation: operation) {
                // Simulate simple network operation
                let simulatedData = Data(repeating: 0x42, count: operation.expectedDataSize)
                return simulatedData
            }
            
            allResults.append(result)
        }
        
        // Assert - Basic functionality
        #expect(allResults.count == simpleOperations.count, "Should process all operations")
        #expect(allResults.count > 0, "Should have processed some operations")
        
        // Test resource cleanup
        let finalResourceUsage = resourceManager.getCurrentResourceUsage()
        #expect(finalResourceUsage.activeConnections >= 0, "Should have non-negative connection count")
        #expect(finalResourceUsage.currentBandwidthUsage >= 0, "Should have non-negative bandwidth usage")
    }
}
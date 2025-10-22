//
//  NetworkSimulationUtilities.swift
//  Flameworker
//
//  Created by Assistant on 10/12/25.
//

import Foundation
import Network
import Combine

#if canImport(Darwin)
import Darwin
#endif

// MARK: - Network Error Handling

enum NetworkErrorCategory {
    case timeout, bandwidth, offline, serverError, circuitOpen, resourceExhaustion
}

struct NetworkErrorInfo {
    let category: NetworkErrorCategory
    let isRetryable: Bool
    let userMessage: String
    let technicalDetails: String
    let suggestedDelay: TimeInterval?
}

struct NetworkErrorHandler {
    static func categorizeError(_ error: Error) -> NetworkErrorInfo {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return NetworkErrorInfo(
                    category: .timeout,
                    isRetryable: true,
                    userMessage: "Request timeout - please check your connection",
                    technicalDetails: "URLError.timedOut",
                    suggestedDelay: 2.0
                )
            case .networkConnectionLost, .notConnectedToInternet:
                return NetworkErrorInfo(
                    category: .offline,
                    isRetryable: true,
                    userMessage: "No internet connection available",
                    technicalDetails: "URLError network connection issues",
                    suggestedDelay: 5.0
                )
            case .badServerResponse:
                return NetworkErrorInfo(
                    category: .serverError,
                    isRetryable: true,
                    userMessage: "Server error - please try again later",
                    technicalDetails: "URLError.badServerResponse",
                    suggestedDelay: 10.0
                )
            default:
                return NetworkErrorInfo(
                    category: .serverError,
                    isRetryable: false,
                    userMessage: "Network error occurred",
                    technicalDetails: "URLError: \(urlError.localizedDescription)",
                    suggestedDelay: nil
                )
            }
        }
        
        if let networkError = error as? NetworkError {
            switch networkError {
            case .offline:
                return NetworkErrorInfo(
                    category: .offline,
                    isRetryable: true,
                    userMessage: "Operation requires internet connection",
                    technicalDetails: "NetworkError.offline",
                    suggestedDelay: 5.0
                )
            case .circuitOpen:
                return NetworkErrorInfo(
                    category: .circuitOpen,
                    isRetryable: false,
                    userMessage: "Service temporarily unavailable",
                    technicalDetails: "Circuit breaker is open",
                    suggestedDelay: 30.0
                )
            case .resourceExhaustion:
                return NetworkErrorInfo(
                    category: .resourceExhaustion,
                    isRetryable: true,
                    userMessage: "System busy - please try again",
                    technicalDetails: "Network resources exhausted",
                    suggestedDelay: 1.0
                )
            }
        }
        
        return NetworkErrorInfo(
            category: .serverError,
            isRetryable: false,
            userMessage: "An error occurred",
            technicalDetails: error.localizedDescription,
            suggestedDelay: nil
        )
    }
}

enum NetworkError: Error, LocalizedError {
    case offline(String)
    case circuitOpen(String)
    case resourceExhaustion(String)
    
    var errorDescription: String? {
        switch self {
        case .offline(let message): return message
        case .circuitOpen(let message): return message
        case .resourceExhaustion(let message): return message
        }
    }
    
    var isResourceExhaustion: Bool {
        if case .resourceExhaustion = self { return true }
        return false
    }
}

// MARK: - Network Simulator

enum SimulatedBandwidth: Double {
    case fast = 10.0      // 10 MB/s
    case medium = 1.0     // 1 MB/s
    case slow = 0.1       // 100 KB/s (2G-like)
}

class NetworkSimulator {
    let session: URLSession
    let maxRetries: Int
    let baseDelay: TimeInterval
    let simulatedBandwidth: SimulatedBandwidth
    let latency: TimeInterval
    
    init(
        session: URLSession = .shared,
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 0.5,
        simulatedBandwidth: SimulatedBandwidth = .medium,
        latency: TimeInterval = 0.1
    ) {
        self.session = session
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.simulatedBandwidth = simulatedBandwidth
        self.latency = latency
    }
    
    func performRequest(url: URL) async throws -> Data {
        // Simulate network latency
        try await Task.sleep(nanoseconds: UInt64(max(0, latency * 1_000_000_000)))
        
        let (data, response) = try await session.data(from: url)
        
        // Simulate bandwidth limitations
        let dataSize = Double(data.count)
        let transferTime = dataSize / (simulatedBandwidth.rawValue * 1_024_000) // Convert MB/s to bytes/s
        
        if transferTime > 0.01 { // Only simulate if transfer time is significant
            try await Task.sleep(nanoseconds: UInt64(max(0, transferTime * 1_000_000_000)))
        }
        
        return data
    }
    
    func executeWithRetry<T>(operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                if attempt < maxRetries {
                    // Calculate exponential backoff: baseDelay * 2^(attempt-1)
                    let exponent = attempt - 1
                    let multiplier = exponent > 0 ? (0..<exponent).reduce(1.0) { result, _ in result * 2.0 } : 1.0
                    let delay = baseDelay * multiplier
                    try await Task.sleep(nanoseconds: UInt64(max(0, delay * 1_000_000_000)))
                }
            }
        }
        
        throw lastError ?? URLError(.unknown)
    }
    
    func calculateExpectedDownloadTime(for dataSize: Int) -> TimeInterval {
        let sizeInMB = Double(dataSize) / (1024 * 1024)
        return sizeInMB / simulatedBandwidth.rawValue + latency
    }
    
    func simulateDownload(data: Data, expectedTime: TimeInterval) async throws -> Data {
        // Simulate the expected download time
        try await Task.sleep(nanoseconds: UInt64(max(0, expectedTime * 1_000_000_000)))
        return data
    }
}

// MARK: - Network Connection Monitoring

enum NetworkConnectionState: Equatable {
    case connected, disconnected, connecting
}

@MainActor
class NetworkConnectionMonitor: ObservableObject {
    @Published var currentState: NetworkConnectionState = .connected
    private let stateSubject = PassthroughSubject<NetworkConnectionState, Never>()

    var connectionStatePublisher: AnyPublisher<NetworkConnectionState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    func simulateConnectionLoss() {
        currentState = .disconnected
        stateSubject.send(.disconnected)
    }

    func simulateConnectionRecovery() {
        currentState = .connecting
        stateSubject.send(.connecting)

        // Simulate connection establishment delay
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            self.currentState = .connected
            self.stateSubject.send(.connected)
        }
    }
}

// MARK: - Network State Management

enum NetworkState {
    case online, offline
}

struct NetworkOperationResult {
    let operationName: String
    let operationId: String
    let result: Result<String, Error>
    let timestamp: Date
    let executionTime: TimeInterval
    
    init(operationName: String, operationId: String? = nil, result: Result<String, Error>, timestamp: Date, executionTime: TimeInterval) {
        self.operationName = operationName
        self.operationId = operationId ?? operationName
        self.result = result
        self.timestamp = timestamp
        self.executionTime = executionTime
    }
    
    var isSuccess: Bool {
        if case .success = result { return true }
        return false
    }
    
    var isFailure: Bool { !isSuccess }
    
    var error: Error? {
        if case .failure(let error) = result { return error }
        return nil
    }
}

class NetworkStateManager {
    private(set) var currentState: NetworkState = .online
    var onStateChange: ((NetworkState) -> Void)?
    
    func setNetworkState(_ state: NetworkState) {
        if currentState != state {
            currentState = state
            onStateChange?(state)
        }
    }
    
    func executeOperation<T>(named name: String, operation: @escaping () async throws -> T) async -> NetworkOperationResult {
        let startTime = Date()
        let result: Result<String, Error>
        
        do {
            let operationResult = try await operation()
            result = .success(String(describing: operationResult))
        } catch {
            result = .failure(error)
        }
        
        let executionTime = Date().timeIntervalSince(startTime)
        
        return NetworkOperationResult(
            operationName: name,
            result: result,
            timestamp: Date(),
            executionTime: executionTime
        )
    }
}

// MARK: - Offline Operation Queue

class OfflineOperationQueue {
    private var queuedOperations: [QueuedOperation] = []
    private var completedOperations: [NetworkOperationResult] = []
    private var currentState: NetworkState = .online
    
    struct QueuedOperation {
        let name: String
        let operation: () async throws -> String
        let timestamp: Date
    }
    
    var queuedOperationCount: Int { queuedOperations.count }
    var completedOperationCount: Int { completedOperations.count }
    
    func setNetworkState(_ state: NetworkState) {
        currentState = state
    }
    
    func queueOperation(name: String, operation: @escaping () async throws -> String) async {
        if currentState == .offline {
            queuedOperations.append(QueuedOperation(
                name: name,
                operation: operation,
                timestamp: Date()
            ))
        } else {
            // Execute immediately if online
            let result = await executeOperation(name: name, operation: operation)
            completedOperations.append(result)
        }
    }
    
    func setNetworkStateAndExecuteQueued(_ state: NetworkState) async -> [Result<String, Error>] {
        currentState = state
        
        guard state == .online else {
            return []
        }
        
        var results: [Result<String, Error>] = []
        let operationsToExecute = queuedOperations
        queuedOperations.removeAll()
        
        for queuedOp in operationsToExecute {
            let result = await executeOperation(name: queuedOp.name, operation: queuedOp.operation)
            completedOperations.append(result)
            results.append(result.result)
        }
        
        return results
    }
    
    private func executeOperation(name: String, operation: @escaping () async throws -> String) async -> NetworkOperationResult {
        let startTime = Date()
        let result: Result<String, Error>
        
        do {
            let operationResult = try await operation()
            result = .success(operationResult)
        } catch {
            result = .failure(error)
        }
        
        let executionTime = Date().timeIntervalSince(startTime)
        
        return NetworkOperationResult(
            operationName: name,
            result: result,
            timestamp: Date(),
            executionTime: executionTime
        )
    }
}

// MARK: - Circuit Breaker Pattern

enum CircuitBreakerState {
    case closed, open, halfOpen
}

struct CircuitBreakerResult {
    let result: Result<String, Error>
    let state: CircuitBreakerState
    let timestamp: Date
    
    var isSuccess: Bool {
        if case .success = result { return true }
        return false
    }
    
    var isFailure: Bool {
        if case .failure = result { return true }
        return false
    }
    
    var isCircuitOpen: Bool {
        state == .open && isFailure
    }
}

class NetworkCircuitBreaker {
    private(set) var state: CircuitBreakerState = .closed
    private var failureCount = 0
    private var lastFailureTime: Date?
    private var halfOpenAttempts = 0
    
    let failureThreshold: Int
    let recoveryTimeout: TimeInterval
    let halfOpenMaxAttempts: Int
    
    init(failureThreshold: Int = 5, recoveryTimeout: TimeInterval = 30.0, halfOpenMaxAttempts: Int = 3) {
        self.failureThreshold = failureThreshold
        self.recoveryTimeout = recoveryTimeout
        self.halfOpenMaxAttempts = halfOpenMaxAttempts
    }
    
    func execute<T>(operation: @escaping () async throws -> T) async -> CircuitBreakerResult {
        let currentState = determineCurrentState()
        self.state = currentState
        
        switch currentState {
        case .open:
            let error = NetworkError.circuitOpen("Circuit breaker is open")
            return CircuitBreakerResult(
                result: .failure(error),
                state: .open,
                timestamp: Date()
            )
            
        case .halfOpen:
            return await executeInHalfOpenState(operation: operation)
            
        case .closed:
            return await executeInClosedState(operation: operation)
        }
    }
    
    private func determineCurrentState() -> CircuitBreakerState {
        switch state {
        case .closed:
            return failureCount >= failureThreshold ? .open : .closed
            
        case .open:
            guard let lastFailure = lastFailureTime,
                  Date().timeIntervalSince(lastFailure) >= recoveryTimeout else {
                return .open
            }
            return .halfOpen
            
        case .halfOpen:
            return .halfOpen
        }
    }
    
    private func executeInClosedState<T>(operation: @escaping () async throws -> T) async -> CircuitBreakerResult {
        do {
            let result = try await operation()
            failureCount = 0 // Reset on success
            return CircuitBreakerResult(
                result: .success(String(describing: result)),
                state: .closed,
                timestamp: Date()
            )
        } catch {
            failureCount += 1
            lastFailureTime = Date()
            return CircuitBreakerResult(
                result: .failure(error),
                state: .closed,
                timestamp: Date()
            )
        }
    }
    
    private func executeInHalfOpenState<T>(operation: @escaping () async throws -> T) async -> CircuitBreakerResult {
        do {
            let result = try await operation()
            // Success in half-open state closes the circuit
            state = .closed
            failureCount = 0
            halfOpenAttempts = 0
            return CircuitBreakerResult(
                result: .success(String(describing: result)),
                state: .closed,
                timestamp: Date()
            )
        } catch {
            halfOpenAttempts += 1
            
            if halfOpenAttempts >= halfOpenMaxAttempts {
                // Too many failures in half-open, go back to open
                state = .open
                lastFailureTime = Date()
                halfOpenAttempts = 0
            }
            
            return CircuitBreakerResult(
                result: .failure(error),
                state: state,
                timestamp: Date()
            )
        }
    }
}

// MARK: - Exponential Backoff with Jitter

class ExponentialBackoffCalculator {
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval
    let multiplier: Double
    let jitterRange: TimeInterval
    
    init(baseDelay: TimeInterval = 1.0, maxDelay: TimeInterval = 60.0, multiplier: Double = 2.0, jitterRange: TimeInterval = 0.5) {
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.multiplier = multiplier
        self.jitterRange = jitterRange
    }
    
    func calculateDelay(for attempt: Int) -> TimeInterval {
        // Calculate exponential delay: baseDelay * multiplier^(attempt-1)
        let exponent = attempt - 1
        let exponentialMultiplier = exponent > 0 ? 
            (0..<exponent).reduce(1.0) { result, _ in result * multiplier } : 1.0
        let exponentialDelay = baseDelay * exponentialMultiplier
        let cappedDelay = min(exponentialDelay, maxDelay)
        
        // Add jitter, but ensure final result doesn't exceed maxDelay
        let jitter = Double.random(in: -jitterRange...jitterRange)
        let delayWithJitter = cappedDelay + jitter
        let finalDelay = max(0.0, min(delayWithJitter, maxDelay))
        
        return finalDelay
    }
}

// MARK: - Network Performance Management

enum OperationPriority {
    case high, normal, low
}

struct NetworkOperation {
    let id: String
    let priority: OperationPriority
    let timeout: TimeInterval
    let retryCount: Int
}

class NetworkManager: @unchecked Sendable {
    let maxConcurrentOperations: Int
    private let semaphore: DispatchSemaphore

    init(maxConcurrentOperations: Int = 10) {
        self.maxConcurrentOperations = maxConcurrentOperations
        self.semaphore = DispatchSemaphore(value: maxConcurrentOperations)
    }
    
    func execute<T>(operation: NetworkOperation, task: @escaping () async throws -> T) async -> NetworkOperationResult {
        let startTime = Date()
        
        // Wait for available slot
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                self.semaphore.wait()
                continuation.resume()
            }
        }
        
        defer {
            semaphore.signal()
        }
        
        let result: Result<String, Error>
        do {
            let taskResult = try await task()
            result = .success(String(describing: taskResult))
        } catch {
            result = .failure(error)
        }
        
        let executionTime = Date().timeIntervalSince(startTime)
        
        return NetworkOperationResult(
            operationName: operation.id,
            operationId: operation.id,
            result: result,
            timestamp: Date(),
            executionTime: executionTime
        )
    }
}

// MARK: - Network Resource Management

struct NetworkResourceUsage {
    let activeConnections: Int
    let currentBandwidthUsage: Double
    let memoryUsage: Int
}

struct NetworkHeavyOperation {
    let id: String
    let expectedDataSize: Int
    let timeout: TimeInterval
}

actor NetworkResourceManager {
    let maxActiveConnections: Int
    let maxBandwidthPerSecond: Double
    let connectionPoolSize: Int

    private var currentConnections = 0
    private var currentBandwidthUsage: Double = 0

    init(maxActiveConnections: Int = 10, maxBandwidthPerSecond: Double = 10_000_000, connectionPoolSize: Int = 20) {
        self.maxActiveConnections = maxActiveConnections
        self.maxBandwidthPerSecond = maxBandwidthPerSecond
        self.connectionPoolSize = connectionPoolSize
    }

    func executeWithResourceCheck<T>(operation: NetworkHeavyOperation, task: @escaping @Sendable () async throws -> T) async -> NetworkOperationResult {
        let startTime = Date()

        // Check resource availability
        let canExecute = currentConnections < maxActiveConnections &&
                        currentBandwidthUsage + Double(operation.expectedDataSize) < maxBandwidthPerSecond

        if canExecute {
            currentConnections += 1
            currentBandwidthUsage += Double(operation.expectedDataSize)
        }

        guard canExecute else {
            let error = NetworkError.resourceExhaustion("Network resources exhausted")
            return NetworkOperationResult(
                operationName: operation.id,
                operationId: operation.id,
                result: .failure(error),
                timestamp: Date(),
                executionTime: 0
            )
        }

        let result: Result<String, Error>
        do {
            let taskResult = try await task()
            result = .success(String(describing: taskResult))
        } catch {
            result = .failure(error)
        }

        // Clean up resources
        currentConnections -= 1
        currentBandwidthUsage = max(0, currentBandwidthUsage - Double(operation.expectedDataSize))

        let executionTime = Date().timeIntervalSince(startTime)

        return NetworkOperationResult(
            operationName: operation.id,
            operationId: operation.id,
            result: result,
            timestamp: Date(),
            executionTime: executionTime
        )
    }

    func getCurrentResourceUsage() -> NetworkResourceUsage {
        return NetworkResourceUsage(
            activeConnections: currentConnections,
            currentBandwidthUsage: currentBandwidthUsage,
            memoryUsage: 0 // Placeholder for memory tracking
        )
    }
}
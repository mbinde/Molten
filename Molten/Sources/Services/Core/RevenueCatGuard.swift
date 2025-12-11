//
//  RevenueCatGuard.swift
//  Molten
//
//  Actor that serializes all RevenueCat operations to prevent deadlocks.
//  RevenueCat's internal SynchronizedUserDefaults lock can deadlock when
//  concurrent operations trigger UserDefaults.didChangeNotification.
//  See: https://github.com/RevenueCat/purchases-ios/issues/4137
//
//  ⚠️ IMPORTANT: ALL RevenueCat SDK calls MUST go through this guard!
//  ⚠️ Do NOT call Purchases.shared.customerInfo() or restorePurchases() directly.
//  ⚠️ Use RevenueCatGuard.shared.getCustomerInfo() or .restorePurchases() instead.
//
//  To find violations, run:
//    grep -r "Purchases\.shared\.\(customerInfo\|restorePurchases\)" Molten/Sources --include="*.swift" | grep -v RevenueCatGuard
//

import Foundation
import RevenueCat

/// Actor that serializes RevenueCat SDK operations to prevent deadlocks.
/// All RevenueCat calls should go through this guard to ensure only one
/// operation is in flight at a time.
///
/// IMPORTANT: RevenueCat is configured in AppDelegate.didFinishLaunchingWithOptions,
/// which runs AFTER SwiftUI App.init(). The guard waits for `markInitialized()` to be
/// called before allowing any SDK operations.
public actor RevenueCatGuard {

    /// Shared singleton instance
    public static let shared = RevenueCatGuard()

    /// Minimum delay between RevenueCat operations to prevent lock contention
    private let minimumOperationDelay: TimeInterval = 0.1

    /// Tracks when the last operation completed
    private var lastOperationTime: Date = .distantPast

    /// Whether SDK has been properly initialized (set by AppDelegate after Purchases.configure)
    private var isInitialized = false

    /// Maximum time to wait for initialization (seconds)
    private let maxInitWait: TimeInterval = 5.0

    /// Time when the guard was created
    private let launchTime = Date()

    private init() {
        print("🔐 [RevenueCatGuard] Guard created, waiting for SDK initialization...")
    }

    /// Mark the SDK as initialized (call after Purchases.configure in AppDelegate)
    public func markInitialized() {
        isInitialized = true
        print("🔐 [RevenueCatGuard] SDK marked as initialized")
    }

    /// Wait for the SDK to be initialized
    private func waitForInitialization() async throws {
        let startTime = Date()
        while !isInitialized {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > maxInitWait {
                print("🔐 [RevenueCatGuard] WARNING: Timed out waiting for SDK initialization after \(elapsed)s")
                throw RevenueCatGuardError.initializationTimeout
            }
            // Check every 50ms
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        let waitTime = Date().timeIntervalSince(startTime)
        if waitTime > 0.1 {
            print("🔐 [RevenueCatGuard] SDK ready after waiting \(String(format: "%.2f", waitTime))s")
        }
    }

    /// Execute a RevenueCat operation with serialization and initialization wait
    public func execute<T>(_ operation: @Sendable () async throws -> T) async throws -> T {
        // Wait for SDK to be initialized (set by AppDelegate)
        try await waitForInitialization()

        // Ensure minimum delay between operations to prevent lock contention
        let timeSinceLastOperation = Date().timeIntervalSince(lastOperationTime)
        if timeSinceLastOperation < minimumOperationDelay {
            let remainingDelay = minimumOperationDelay - timeSinceLastOperation
            try await Task.sleep(nanoseconds: UInt64(remainingDelay * 1_000_000_000))
        }

        // Execute the operation
        defer {
            lastOperationTime = Date()
        }

        return try await operation()
    }
}

/// Errors that can occur with the RevenueCat guard
public enum RevenueCatGuardError: Error, LocalizedError {
    case initializationTimeout

    public var errorDescription: String? {
        switch self {
        case .initializationTimeout:
            return "RevenueCat SDK initialization timed out"
        }
    }
}

// MARK: - Convenience Extensions

extension RevenueCatGuard {

    /// Safely get customer info through the guard
    public func getCustomerInfo() async throws -> RevenueCat.CustomerInfo {
        try await execute {
            try await Purchases.shared.customerInfo()
        }
    }

    /// Safely restore purchases through the guard
    public func restorePurchases() async throws -> RevenueCat.CustomerInfo {
        try await execute {
            try await Purchases.shared.restorePurchases()
        }
    }
}

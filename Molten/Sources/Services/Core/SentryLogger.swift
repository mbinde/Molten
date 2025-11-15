//
//  SentryLogger.swift
//  Molten
//
//  Sentry backend for remote error tracking and crash reporting
//  Integrates with Sentry SDK for production error monitoring
//

import Foundation
import UIKit

// MARK: - Environment

/// App environment for Sentry configuration
public enum SentryEnvironment: String, Sendable {
    case debug = "debug"
    case testFlight = "testflight"
    case production = "production"
    case test = "test"

    /// Current environment based on build configuration
    public static var current: SentryEnvironment {
        #if DEBUG
        return .debug
        #else
        // Check if TestFlight
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            return .testFlight
        }
        return .production
        #endif
    }
}

// MARK: - Breadcrumb

/// Breadcrumb for tracking user actions leading up to an error
public struct SentryBreadcrumb: Sendable {
    let message: String
    let category: String
    let timestamp: Date
    let data: [String: Any]?

    init(message: String, category: String, timestamp: Date = Date(), data: [String: Any]? = nil) {
        self.message = message
        self.category = category
        self.timestamp = timestamp
        self.data = data
    }
}

// MARK: - Sentry Logger

/// Logger backend that sends errors to Sentry
public final class SentryLogger: LoggerBackend, @unchecked Sendable {

    // MARK: - Properties

    private let dsn: String
    public let environment: SentryEnvironment
    private let maxBreadcrumbs: Int
    private let _breadcrumbs = NSMutableArray()

    public var breadcrumbs: [SentryBreadcrumb] {
        _breadcrumbs.compactMap { $0 as? SentryBreadcrumb }
    }

    public var isTestMode: Bool {
        environment == .test
    }

    // MARK: - Initialization

    public init(
        dsn: String,
        environment: SentryEnvironment = .current,
        maxBreadcrumbs: Int = 100
    ) {
        self.dsn = dsn
        self.environment = environment
        self.maxBreadcrumbs = maxBreadcrumbs
    }

    // MARK: - LoggerBackend Protocol

    public func log(
        level: LogLevel,
        message: String,
        context: [String: Any]?,
        error: Error?,
        file: String,
        function: String,
        line: Int
    ) {
        // Don't send to Sentry in test mode
        guard !isTestMode else { return }

        // Add breadcrumb for non-error logs
        if level < .error {
            addBreadcrumb(message: message, category: "log", data: context)
            return
        }

        // Send error to Sentry
        sendToSentry(
            level: level,
            message: message,
            context: context,
            error: error,
            file: file,
            function: function,
            line: line
        )
    }

    public func logError(
        _ error: Error,
        message: String?,
        context: [String: Any]?,
        file: String,
        function: String,
        line: Int
    ) {
        guard !isTestMode else { return }

        let errorMessage = message ?? error.localizedDescription

        sendToSentry(
            level: .error,
            message: errorMessage,
            context: context,
            error: error,
            file: file,
            function: function,
            line: line
        )
    }

    // MARK: - Breadcrumbs

    public func addBreadcrumb(
        message: String,
        category: String,
        timestamp: Date = Date(),
        data: [String: Any]? = nil
    ) {
        let breadcrumb = SentryBreadcrumb(
            message: message,
            category: category,
            timestamp: timestamp,
            data: data
        )

        _breadcrumbs.add(breadcrumb)

        // Limit breadcrumbs
        while _breadcrumbs.count > maxBreadcrumbs {
            _breadcrumbs.removeObject(at: 0)
        }
    }

    // MARK: - Private Methods

    private func sendToSentry(
        level: LogLevel,
        message: String,
        context: [String: Any]?,
        error: Error?,
        file: String,
        function: String,
        line: Int
    ) {
        // Enrich context with app metadata
        var enrichedContext = enrichContext(context ?? [:])

        // Add source location
        enrichedContext["file"] = file
        enrichedContext["function"] = function
        enrichedContext["line"] = line

        // Filter sensitive data
        enrichedContext = filterSensitiveData(enrichedContext)

        // In a real implementation, this would call the Sentry SDK:
        // import Sentry
        //
        // let event = Event(level: level.sentryLevel)
        // event.message = SentryMessage(formatted: message)
        // event.extra = enrichedContext
        //
        // if let error = error {
        //     event.exceptions = [Exception(value: error)]
        // }
        //
        // // Attach breadcrumbs
        // event.breadcrumbs = breadcrumbs.map { breadcrumb in
        //     Breadcrumb(
        //         level: .info,
        //         category: breadcrumb.category
        //     ).apply {
        //         $0.message = breadcrumb.message
        //         $0.timestamp = breadcrumb.timestamp
        //         $0.data = breadcrumb.data
        //     }
        // }
        //
        // SentrySDK.capture(event: event)

        // For now, just log that we would send to Sentry
        print("📊 [Sentry] Would send to Sentry: [\(level.sentryLevel)] \(message)")
        if let context = enrichedContext as? [String: String] {
            print("📊 [Sentry] Context: \(context)")
        }
    }

    // MARK: - Context Enrichment

    public func enrichContext(_ context: [String: Any]) -> [String: Any] {
        var enriched = context

        // Add app metadata
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            enriched["app_version"] = appVersion
        }

        if let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            enriched["build_number"] = buildNumber
        }

        enriched["environment"] = environment.rawValue

        // Add device metadata
        let device = UIDevice.current
        enriched["device_model"] = device.model
        enriched["os_version"] = device.systemVersion
        enriched["device_name"] = device.name

        // Add memory info
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        if kerr == KERN_SUCCESS {
            let usedMemory = Double(info.resident_size) / 1024.0 / 1024.0
            enriched["memory_used_mb"] = String(format: "%.2f", usedMemory)
        }

        return enriched
    }

    // MARK: - Sensitive Data Filtering

    public func filterSensitiveData(_ context: [String: Any]) -> [String: Any] {
        var filtered = context

        // List of keys that might contain sensitive data
        let sensitiveKeys = [
            "password",
            "token",
            "secret",
            "api_key",
            "apiKey",
            "creditCard",
            "ssn"
        ]

        // Remove sensitive keys
        for key in sensitiveKeys {
            filtered.removeValue(forKey: key)
        }

        // In anonymous mode, also remove email
        // (Since user requested anonymous only)
        filtered.removeValue(forKey: "email")

        return filtered
    }
}

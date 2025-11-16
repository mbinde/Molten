//
//  LoggingService.swift
//  Molten
//
//  Unified logging system with configurable backends (OSLog, Sentry)
//  Supports structured logging, pattern detection, and remote error tracking
//

import Foundation
import OSLog

// MARK: - Log Level

/// Log severity levels, ordered from least to most severe
public enum LogLevel: Int, Comparable, Sendable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case critical = 4

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Whether this level should send to remote logging by default
    var shouldSendRemotelyByDefault: Bool {
        switch self {
        case .debug, .info, .warning:
            return false
        case .error, .critical:
            return true
        }
    }

    /// Convert to OSLog type
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }

    /// Convert to Sentry level string
    var sentryLevel: String {
        switch self {
        case .debug: return "debug"
        case .info: return "info"
        case .warning: return "warning"
        case .error: return "error"
        case .critical: return "fatal"
        }
    }

    var description: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }
}

// MARK: - Log Entry

/// A captured log entry with all metadata
public struct LogEntry: Sendable {
    let level: LogLevel
    let message: String
    let timestamp: Date
    let context: [String: Any]?
    let error: Error?
    let file: String
    let function: String
    let line: Int

    init(
        level: LogLevel,
        message: String,
        timestamp: Date = Date(),
        context: [String: Any]? = nil,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        self.level = level
        self.message = message
        self.timestamp = timestamp
        self.context = context
        self.error = error
        self.file = file
        self.function = function
        self.line = line
    }
}

// MARK: - Logger Protocol

/// Protocol for logging backends (OSLog, Sentry, Mock)
public protocol LoggerBackend: Sendable {
    func log(level: LogLevel, message: String, context: [String: Any]?, error: Error?, file: String, function: String, line: Int)
    func logError(_ error: Error, message: String?, context: [String: Any]?, file: String, function: String, line: Int)
}

// MARK: - Logging Service

/// Main logging service that coordinates multiple backends
@MainActor
public final class LoggingService {

    // MARK: - Properties

    private let backends: [LoggerBackend]
    private let minimumLocalLevel: LogLevel
    private let minimumRemoteLevel: LogLevel
    private let osLogger: Logger

    // MARK: - Initialization

    public init(
        backends: [LoggerBackend],
        minimumLocalLevel: LogLevel = .debug,
        minimumRemoteLevel: LogLevel = .error
    ) {
        self.backends = backends
        self.minimumLocalLevel = minimumLocalLevel
        self.minimumRemoteLevel = minimumRemoteLevel
        self.osLogger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "com.flameworker.molten",
            category: "Application"
        )
    }

    // MARK: - Public API

    /// Log a message at the specified level
    public func log(
        level: LogLevel,
        message: String,
        context: [String: Any]? = nil,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        // Filter by minimum level
        guard level >= minimumLocalLevel else { return }

        // Log to OSLog (local)
        osLogger.log(level: level.osLogType, "\(level.description): \(message)")

        // Log to all backends
        for backend in backends {
            backend.log(
                level: level,
                message: message,
                context: context,
                error: error,
                file: file,
                function: function,
                line: line
            )
        }
    }

    /// Log an error with additional context
    public func logError(
        _ error: Error,
        message: String? = nil,
        context: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let errorMessage = message ?? error.localizedDescription

        // Extract additional context from AppError if available
        var enrichedContext = context ?? [:]
        if let appError = error as? AppError {
            enrichedContext["error_category"] = appError.category.rawValue
            enrichedContext["error_severity"] = appError.severity.logLevelString
            if let technicalDetails = appError.technicalDetails {
                enrichedContext["technical_details"] = technicalDetails
            }
            if !appError.suggestions.isEmpty {
                enrichedContext["suggestions"] = appError.suggestions.joined(separator: "; ")
            }
        }

        // Log at error level
        log(
            level: .error,
            message: errorMessage,
            context: enrichedContext,
            error: error,
            file: file,
            function: function,
            line: line
        )

        // Also log to all backends
        for backend in backends {
            backend.logError(
                error,
                message: errorMessage,
                context: enrichedContext,
                file: file,
                function: function,
                line: line
            )
        }
    }

    // MARK: - Convenience Methods

    public func debug(
        _ message: String,
        context: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .debug, message: message, context: context, file: file, function: function, line: line)
    }

    public func info(
        _ message: String,
        context: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .info, message: message, context: context, file: file, function: function, line: line)
    }

    public func warning(
        _ message: String,
        context: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .warning, message: message, context: context, file: file, function: function, line: line)
    }

    public func error(
        _ message: String,
        context: [String: Any]? = nil,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .error, message: message, context: context, error: error, file: file, function: function, line: line)
    }

    public func critical(
        _ message: String,
        context: [String: Any]? = nil,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .critical, message: message, context: context, error: error, file: file, function: function, line: line)
    }
}

// MARK: - Mock Logger (for testing)

/// Mock logger backend that captures log entries for testing
public final class MockLogger: LoggerBackend, @unchecked Sendable {
    private let _logs = NSMutableArray()

    public var logs: [LogEntry] {
        _logs.compactMap { $0 as? LogEntry }
    }

    public init() {}

    public func log(
        level: LogLevel,
        message: String,
        context: [String: Any]?,
        error: Error?,
        file: String,
        function: String,
        line: Int
    ) {
        let entry = LogEntry(
            level: level,
            message: message,
            context: context,
            error: error,
            file: file,
            function: function,
            line: line
        )
        _logs.add(entry)
    }

    public func logError(
        _ error: Error,
        message: String?,
        context: [String: Any]?,
        file: String,
        function: String,
        line: Int
    ) {
        let errorMessage = message ?? error.localizedDescription
        log(
            level: .error,
            message: errorMessage,
            context: context,
            error: error,
            file: file,
            function: function,
            line: line
        )
    }

    // Convenience methods for testing
    public func debug(_ message: String, context: [String: Any]? = nil) {
        log(level: .debug, message: message, context: context, error: nil, file: "", function: "", line: 0)
    }

    public func info(_ message: String, context: [String: Any]? = nil) {
        log(level: .info, message: message, context: context, error: nil, file: "", function: "", line: 0)
    }

    public func warning(_ message: String, context: [String: Any]? = nil) {
        log(level: .warning, message: message, context: context, error: nil, file: "", function: "", line: 0)
    }

    public func error(_ message: String, context: [String: Any]? = nil) {
        log(level: .error, message: message, context: context, error: nil, file: "", function: "", line: 0)
    }

    public func critical(_ message: String, context: [String: Any]? = nil) {
        log(level: .critical, message: message, context: context, error: nil, file: "", function: "", line: 0)
    }

    public func clear() {
        _logs.removeAllObjects()
    }
}

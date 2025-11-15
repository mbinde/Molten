//
//  LoggingServiceTests.swift
//  MoltenTests
//
//  Tests for the unified logging system with Sentry integration
//

import XCTest
@testable import Molten

@MainActor
final class LoggingServiceTests: XCTestCase {

    // MARK: - LogLevel Tests

    func testLogLevelOrdering() {
        // Debug < Info < Warning < Error < Critical
        XCTAssertLessThan(LogLevel.debug.rawValue, LogLevel.info.rawValue)
        XCTAssertLessThan(LogLevel.info.rawValue, LogLevel.warning.rawValue)
        XCTAssertLessThan(LogLevel.warning.rawValue, LogLevel.error.rawValue)
        XCTAssertLessThan(LogLevel.error.rawValue, LogLevel.critical.rawValue)
    }

    func testLogLevelShouldSendRemotely() {
        // By default, only errors and critical should send remotely
        XCTAssertFalse(LogLevel.debug.shouldSendRemotelyByDefault)
        XCTAssertFalse(LogLevel.info.shouldSendRemotelyByDefault)
        XCTAssertFalse(LogLevel.warning.shouldSendRemotelyByDefault)
        XCTAssertTrue(LogLevel.error.shouldSendRemotelyByDefault)
        XCTAssertTrue(LogLevel.critical.shouldSendRemotelyByDefault)
    }

    // MARK: - Mock Logger Tests

    func testMockLoggerCapturesLogs() {
        let logger = MockLogger()

        logger.log(level: .info, message: "Test message", context: ["key": "value"])

        XCTAssertEqual(logger.logs.count, 1)
        XCTAssertEqual(logger.logs[0].level, .info)
        XCTAssertEqual(logger.logs[0].message, "Test message")
        XCTAssertEqual(logger.logs[0].context?["key"] as? String, "value")
    }

    func testMockLoggerConvenienceMethods() {
        let logger = MockLogger()

        logger.debug("Debug message")
        logger.info("Info message")
        logger.warning("Warning message")
        logger.error("Error message")
        logger.critical("Critical message")

        XCTAssertEqual(logger.logs.count, 5)
        XCTAssertEqual(logger.logs[0].level, .debug)
        XCTAssertEqual(logger.logs[1].level, .info)
        XCTAssertEqual(logger.logs[2].level, .warning)
        XCTAssertEqual(logger.logs[3].level, .error)
        XCTAssertEqual(logger.logs[4].level, .critical)
    }

    func testMockLoggerCapturesErrors() {
        let logger = MockLogger()
        let testError = NSError(domain: "test", code: 123)

        logger.logError(testError, message: "Test error", context: ["source": "test"])

        XCTAssertEqual(logger.logs.count, 1)
        XCTAssertEqual(logger.logs[0].level, .error)
        XCTAssertTrue(logger.logs[0].message.contains("Test error"))
        XCTAssertNotNil(logger.logs[0].error)
    }

    // MARK: - LoggingService Configuration Tests

    func testLoggingServiceDefaultConfiguration() async throws {
        let mockBackend = MockLogger()
        let service = LoggingService(
            backends: [mockBackend],
            minimumLocalLevel: .debug,
            minimumRemoteLevel: .error
        )

        // Debug should log locally but not remotely
        service.debug("Debug message")
        XCTAssertEqual(mockBackend.logs.count, 1)

        // Error should log both locally and remotely
        service.error("Error message")
        XCTAssertEqual(mockBackend.logs.count, 2)
    }

    func testLoggingServiceFiltersByMinimumLevel() {
        let mockBackend = MockLogger()
        let service = LoggingService(
            backends: [mockBackend],
            minimumLocalLevel: .warning, // Only warning and above
            minimumRemoteLevel: .error
        )

        service.debug("Should be filtered")
        service.info("Should be filtered")
        service.warning("Should appear")
        service.error("Should appear")

        XCTAssertEqual(mockBackend.logs.count, 2)
        XCTAssertEqual(mockBackend.logs[0].level, .warning)
        XCTAssertEqual(mockBackend.logs[1].level, .error)
    }

    func testLoggingServiceMultipleBackends() {
        let backend1 = MockLogger()
        let backend2 = MockLogger()
        let service = LoggingService(
            backends: [backend1, backend2],
            minimumLocalLevel: .debug,
            minimumRemoteLevel: .error
        )

        service.info("Test message")

        XCTAssertEqual(backend1.logs.count, 1)
        XCTAssertEqual(backend2.logs.count, 1)
    }

    func testLoggingServiceWithContext() {
        let mockBackend = MockLogger()
        let service = LoggingService(
            backends: [mockBackend],
            minimumLocalLevel: .debug,
            minimumRemoteLevel: .error
        )

        let context: [String: Any] = [
            "userId": "test-user",
            "action": "catalog-download",
            "itemCount": 100
        ]

        service.log(level: .info, message: "Catalog downloaded", context: context)

        XCTAssertEqual(mockBackend.logs.count, 1)
        XCTAssertEqual(mockBackend.logs[0].context?["userId"] as? String, "test-user")
        XCTAssertEqual(mockBackend.logs[0].context?["action"] as? String, "catalog-download")
        XCTAssertEqual(mockBackend.logs[0].context?["itemCount"] as? Int, 100)
    }

    // MARK: - Pattern Detection Tests

    func testLoggingServiceCapturesPatterns() {
        let mockBackend = MockLogger()
        let service = LoggingService(
            backends: [mockBackend],
            minimumLocalLevel: .debug,
            minimumRemoteLevel: .error
        )

        // Simulate catalog download failures
        for i in 1...5 {
            service.error("Catalog download failed", context: [
                "operation": "catalog-download",
                "attempt": i
            ])
        }

        // All 5 errors should be logged
        XCTAssertEqual(mockBackend.logs.count, 5)

        // All should have the pattern marker
        let catalogErrors = mockBackend.logs.filter {
            ($0.context?["operation"] as? String) == "catalog-download"
        }
        XCTAssertEqual(catalogErrors.count, 5)
    }

    func testLoggingServiceWithAppError() {
        let mockBackend = MockLogger()
        let service = LoggingService(
            backends: [mockBackend],
            minimumLocalLevel: .debug,
            minimumRemoteLevel: .error
        )

        let appError = AppError(
            category: .network,
            severity: .error,
            userMessage: "Network connection failed",
            technicalDetails: "Timeout after 30s",
            suggestions: ["Check your internet connection"]
        )

        service.logError(appError, message: "Failed to load data", context: ["source": "DataLoadingService"])

        XCTAssertEqual(mockBackend.logs.count, 1)
        XCTAssertNotNil(mockBackend.logs[0].error)
        XCTAssertTrue(mockBackend.logs[0].message.contains("Failed to load data"))
    }

    // MARK: - Integration with ErrorHandler Tests

    func testLoggingServiceIntegrationWithErrorHandler() {
        let mockBackend = MockLogger()
        let logger = LoggingService(
            backends: [mockBackend],
            minimumLocalLevel: .debug,
            minimumRemoteLevel: .error
        )

        // Simulate an error being logged through the system
        let error = AppError(
            category: .data,
            severity: .critical,
            userMessage: "Database corruption detected",
            technicalDetails: "Core Data integrity check failed"
        )

        logger.critical("Critical database error", context: [
            "error": error.localizedDescription,
            "category": error.category.rawValue
        ])

        XCTAssertEqual(mockBackend.logs.count, 1)
        XCTAssertEqual(mockBackend.logs[0].level, .critical)
    }
}

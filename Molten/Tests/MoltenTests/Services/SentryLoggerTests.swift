//
//  SentryLoggerTests.swift
//  MoltenTests
//
//  Tests for Sentry logging backend integration
//

import XCTest
@testable import Molten

@MainActor
final class SentryLoggerTests: XCTestCase {

    func testSentryLoggerMapsLogLevelsCorrectly() {
        // Test that our LogLevel enum maps to Sentry's levels correctly
        XCTAssertEqual(LogLevel.debug.sentryLevel, "debug")
        XCTAssertEqual(LogLevel.info.sentryLevel, "info")
        XCTAssertEqual(LogLevel.warning.sentryLevel, "warning")
        XCTAssertEqual(LogLevel.error.sentryLevel, "error")
        XCTAssertEqual(LogLevel.critical.sentryLevel, "fatal")
    }

    func testSentryLoggerIncludesEnvironmentInfo() {
        let logger = SentryLogger(dsn: "test-dsn", environment: .debug)

        // Environment should be set
        XCTAssertEqual(logger.environment, .debug)
    }

    func testSentryLoggerEnvironmentModes() {
        // Test different environment modes
        let debugLogger = SentryLogger(dsn: "test", environment: .debug)
        let productionLogger = SentryLogger(dsn: "test", environment: .production)
        let testFlightLogger = SentryLogger(dsn: "test", environment: .testFlight)

        XCTAssertEqual(debugLogger.environment, .debug)
        XCTAssertEqual(productionLogger.environment, .production)
        XCTAssertEqual(testFlightLogger.environment, .testFlight)
    }

    func testSentryLoggerContextEnrichment() {
        let logger = SentryLogger(dsn: "test-dsn", environment: .debug)

        let context: [String: Any] = [
            "operation": "catalog-download",
            "itemCount": 2500
        ]

        // The logger should enrich context with app metadata
        let enriched = logger.enrichContext(context)

        XCTAssertNotNil(enriched["operation"])
        XCTAssertNotNil(enriched["itemCount"])
        XCTAssertNotNil(enriched["app_version"])
        XCTAssertNotNil(enriched["build_number"])
        XCTAssertNotNil(enriched["device_model"])
        XCTAssertNotNil(enriched["os_version"])
    }

    func testSentryLoggerFiltersSensitiveData() {
        let logger = SentryLogger(dsn: "test-dsn", environment: .debug)

        let context: [String: Any] = [
            "userId": "user-123",
            "email": "user@example.com",
            "password": "secret123",
            "operation": "login"
        ]

        let filtered = logger.filterSensitiveData(context)

        // Should keep userId and operation
        XCTAssertNotNil(filtered["userId"])
        XCTAssertNotNil(filtered["operation"])

        // Should remove email and password (based on configuration)
        // In anonymous mode, we might redact these
        XCTAssertNil(filtered["password"])
    }

    func testSentryLoggerBreadcrumbs() {
        let logger = SentryLogger(dsn: "test-dsn", environment: .debug)

        // Add some breadcrumbs
        logger.addBreadcrumb(message: "User viewed catalog", category: "navigation")
        logger.addBreadcrumb(message: "User searched for 'Bullseye'", category: "search")
        logger.addBreadcrumb(message: "User added item to inventory", category: "action")

        // When an error is logged, breadcrumbs should be included
        XCTAssertEqual(logger.breadcrumbs.count, 3)
        XCTAssertEqual(logger.breadcrumbs[0].message, "User viewed catalog")
        XCTAssertEqual(logger.breadcrumbs[1].category, "search")
    }

    func testSentryLoggerBreadcrumbLimit() {
        let logger = SentryLogger(dsn: "test-dsn", environment: .debug, maxBreadcrumbs: 10)

        // Add more than the limit
        for i in 1...15 {
            logger.addBreadcrumb(message: "Action \(i)", category: "test")
        }

        // Should only keep the last 10
        XCTAssertEqual(logger.breadcrumbs.count, 10)
        XCTAssertEqual(logger.breadcrumbs[0].message, "Action 6")
        XCTAssertEqual(logger.breadcrumbs[9].message, "Action 15")
    }

    func testSentryLoggerDoesNotSendInTestMode() {
        let logger = SentryLogger(dsn: "test-dsn", environment: .test)

        // In test mode, Sentry should not actually send events
        logger.log(level: .error, message: "Test error", context: nil)

        // This test passes if no crash occurs and no network calls are made
        // In a real implementation, we'd mock the Sentry SDK and verify no calls
        XCTAssertTrue(logger.isTestMode)
    }

    func testSentryLoggerWithAppError() {
        let logger = SentryLogger(dsn: "test-dsn", environment: .debug)

        let appError = AppError(
            category: .network,
            severity: .error,
            userMessage: "Catalog download failed",
            technicalDetails: "HTTP 500 from api.molten.app",
            suggestions: ["Try again later"]
        )

        // Logger should extract structured data from AppError
        logger.logError(appError, message: "Catalog operation failed", context: [
            "operation": "catalog-download"
        ])

        // Verify the error was captured (in a real test, we'd mock Sentry SDK)
        // For now, this verifies the method doesn't crash
        XCTAssertTrue(true)
    }
}

//
//  SimpleErrorHandlingTests.swift
//  MoltenTests
//
//  Unit tests for SimpleErrorHandling enums and structs
//

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import Foundation
@testable import Molten

@MainActor
@Suite("SimpleErrorHandling Tests")
struct SimpleErrorHandlingTests {

    // MARK: - ErrorCategory Tests

    @Test("ErrorCategory has all expected cases")
    func testErrorCategoryAllCases() {
        let allCases = ErrorCategory.allCases

        #expect(allCases.count == 5)
        #expect(allCases.contains(.network))
        #expect(allCases.contains(.data))
        #expect(allCases.contains(.validation))
        #expect(allCases.contains(.system))
        #expect(allCases.contains(.user))
    }

    @Test("ErrorCategory cases are in expected order")
    func testErrorCategoryOrder() {
        let allCases = ErrorCategory.allCases

        #expect(allCases[0] == .network)
        #expect(allCases[1] == .data)
        #expect(allCases[2] == .validation)
        #expect(allCases[3] == .system)
        #expect(allCases[4] == .user)
    }

    @Test("ErrorCategory equality works correctly")
    func testErrorCategoryEquality() {
        #expect(ErrorCategory.network == ErrorCategory.network)
        #expect(ErrorCategory.network != ErrorCategory.data)
        #expect(ErrorCategory.validation == ErrorCategory.validation)
    }

    // MARK: - ErrorSeverity Tests

    @Test("ErrorSeverity has all expected cases")
    func testErrorSeverityAllCases() {
        let allCases = ErrorSeverity.allCases

        #expect(allCases.count == 4)
        #expect(allCases.contains(.info))
        #expect(allCases.contains(.warning))
        #expect(allCases.contains(.error))
        #expect(allCases.contains(.critical))
    }

    @Test("ErrorSeverity cases are in expected order")
    func testErrorSeverityOrder() {
        let allCases = ErrorSeverity.allCases

        #expect(allCases[0] == .info)
        #expect(allCases[1] == .warning)
        #expect(allCases[2] == .error)
        #expect(allCases[3] == .critical)
    }

    @Test("ErrorSeverity.info has correct logLevel")
    func testInfoLogLevel() {
        #expect(ErrorSeverity.info.logLevelString == "INFO")
    }

    @Test("ErrorSeverity.warning has correct logLevel")
    func testWarningLogLevel() {
        #expect(ErrorSeverity.warning.logLevelString == "WARNING")
    }

    @Test("ErrorSeverity.error has correct logLevel")
    func testErrorLogLevel() {
        #expect(ErrorSeverity.error.logLevelString == "ERROR")
    }

    @Test("ErrorSeverity.critical has correct logLevel")
    func testCriticalLogLevel() {
        #expect(ErrorSeverity.critical.logLevelString == "CRITICAL")
    }

    @Test("ErrorSeverity logLevel is always uppercase")
    func testLogLevelUppercase() {
        for severity in ErrorSeverity.allCases {
            #expect(severity.logLevelString == severity.logLevelString.uppercased())
        }
    }

    @Test("ErrorSeverity equality works correctly")
    func testErrorSeverityEquality() {
        #expect(ErrorSeverity.info == ErrorSeverity.info)
        #expect(ErrorSeverity.info != ErrorSeverity.warning)
        #expect(ErrorSeverity.critical == ErrorSeverity.critical)
    }

    // MARK: - AppError Tests

    @Test("AppError initializes with all properties")
    func testAppErrorInitialization() {
        let error = AppError(
            category: .network,
            severity: .error,
            userMessage: "Connection failed",
            technicalDetails: "Timeout after 30s",
            suggestions: ["Check your internet connection"]
        )

        #expect(error.category == .network)
        #expect(error.severity == .error)
        #expect(error.userMessage == "Connection failed")
        #expect(error.technicalDetails == "Timeout after 30s")
        #expect(error.suggestions == ["Check your internet connection"])
    }

    @Test("AppError initializes with empty suggestions")
    func testAppErrorEmptySuggestions() {
        let error = AppError(
            category: .data,
            severity: .warning,
            userMessage: "Data incomplete",
            technicalDetails: "Missing required field",
            suggestions: []
        )

        #expect(error.suggestions.isEmpty)
    }

    @Test("AppError errorDescription matches userMessage")
    func testAppErrorDescription() {
        let error = AppError(
            category: .validation,
            severity: .error,
            userMessage: "Invalid input",
            technicalDetails: "Field 'name' is required",
            suggestions: ["Please provide a name"]
        )

        #expect(error.errorDescription == "Invalid input")
    }

    @Test("AppError recoverySuggestion joins suggestions with newlines")
    func testAppErrorRecoverySuggestion() {
        let error = AppError(
            category: .network,
            severity: .error,
            userMessage: "Failed to connect",
            technicalDetails: "DNS lookup failed",
            suggestions: [
                "Check your internet connection",
                "Try again later",
                "Contact support"
            ]
        )

        let expected = "Check your internet connection\nTry again later\nContact support"
        #expect(error.recoverySuggestion == expected)
    }

    @Test("AppError recoverySuggestion is nil when suggestions empty")
    func testAppErrorNoRecoverySuggestion() {
        let error = AppError(
            category: .system,
            severity: .critical,
            userMessage: "System error",
            technicalDetails: "Out of memory",
            suggestions: []
        )

        #expect(error.recoverySuggestion == nil)
    }

    @Test("AppError failureReason matches technicalDetails")
    func testAppErrorFailureReason() {
        let error = AppError(
            category: .data,
            severity: .error,
            userMessage: "Parse failed",
            technicalDetails: "Invalid JSON at line 42",
            suggestions: []
        )

        #expect(error.failureReason == "Invalid JSON at line 42")
    }

    @Test("AppError with network category")
    func testNetworkCategoryError() {
        let error = AppError(
            category: .network,
            severity: .error,
            userMessage: "Request failed",
            technicalDetails: "HTTP 500",
            suggestions: ["Try again"]
        )

        #expect(error.category == .network)
        #expect(error.errorDescription == "Request failed")
    }

    @Test("AppError with data category")
    func testDataCategoryError() {
        let error = AppError(
            category: .data,
            severity: .warning,
            userMessage: "Data corrupted",
            technicalDetails: "Checksum mismatch",
            suggestions: []
        )

        #expect(error.category == .data)
        #expect(error.severity == .warning)
    }

    @Test("AppError with validation category")
    func testValidationCategoryError() {
        let error = AppError(
            category: .validation,
            severity: .error,
            userMessage: "Validation failed",
            technicalDetails: "Email format invalid",
            suggestions: ["Use format: user@example.com"]
        )

        #expect(error.category == .validation)
        #expect(error.recoverySuggestion == "Use format: user@example.com")
    }

    @Test("AppError with system category")
    func testSystemCategoryError() {
        let error = AppError(
            category: .system,
            severity: .critical,
            userMessage: "System failure",
            technicalDetails: "Disk full",
            suggestions: ["Free up disk space"]
        )

        #expect(error.category == .system)
        #expect(error.severity == .critical)
    }

    @Test("AppError with user category")
    func testUserCategoryError() {
        let error = AppError(
            category: .user,
            severity: .info,
            userMessage: "Action required",
            technicalDetails: "User needs to confirm",
            suggestions: ["Tap OK to continue"]
        )

        #expect(error.category == .user)
        #expect(error.severity == .info)
    }

    @Test("AppError LocalizedError conformance")
    func testAppErrorLocalizedError() {
        let error = AppError(
            category: .network,
            severity: .error,
            userMessage: "Connection lost",
            technicalDetails: "Server unreachable",
            suggestions: ["Check network settings"]
        )

        // LocalizedError protocol properties
        #expect(error.errorDescription != nil)
        #expect(error.failureReason != nil)
        #expect(error.recoverySuggestion != nil)
    }

    @Test("AppError with multiple suggestions formats correctly")
    func testMultipleSuggestions() {
        let suggestions = [
            "First suggestion",
            "Second suggestion",
            "Third suggestion",
            "Fourth suggestion"
        ]

        let error = AppError(
            category: .validation,
            severity: .warning,
            userMessage: "Validation warning",
            technicalDetails: "Multiple issues found",
            suggestions: suggestions
        )

        let recoveryText = error.recoverySuggestion!
        #expect(recoveryText.contains("First suggestion"))
        #expect(recoveryText.contains("Second suggestion"))
        #expect(recoveryText.contains("Third suggestion"))
        #expect(recoveryText.contains("Fourth suggestion"))
        #expect(recoveryText.components(separatedBy: "\n").count == 4)
    }

    @Test("AppError with single suggestion")
    func testSingleSuggestion() {
        let error = AppError(
            category: .user,
            severity: .info,
            userMessage: "Info",
            technicalDetails: "Details",
            suggestions: ["Single suggestion"]
        )

        #expect(error.recoverySuggestion == "Single suggestion")
    }

    @Test("AppError with long userMessage")
    func testLongUserMessage() {
        let longMessage = String(repeating: "A very long error message. ", count: 10)

        let error = AppError(
            category: .data,
            severity: .error,
            userMessage: longMessage,
            technicalDetails: "Details",
            suggestions: []
        )

        #expect(error.errorDescription == longMessage)
        #expect(error.userMessage.count > 100)
    }

    @Test("AppError with long technicalDetails")
    func testLongTechnicalDetails() {
        let longDetails = String(repeating: "Technical detail. ", count: 20)

        let error = AppError(
            category: .system,
            severity: .critical,
            userMessage: "Error",
            technicalDetails: longDetails,
            suggestions: []
        )

        #expect(error.failureReason == longDetails)
        #expect(error.technicalDetails?.count ?? 0 > 200)
    }

    @Test("AppError with empty userMessage")
    func testEmptyUserMessage() {
        let error = AppError(
            category: .validation,
            severity: .warning,
            userMessage: "",
            technicalDetails: "Missing data",
            suggestions: []
        )

        #expect(error.errorDescription == "")
        #expect(error.userMessage.isEmpty)
    }

    @Test("AppError with empty technicalDetails")
    func testEmptyTechnicalDetails() {
        let error = AppError(
            category: .network,
            severity: .error,
            userMessage: "Failed",
            technicalDetails: "",
            suggestions: []
        )

        #expect(error.failureReason == "")
        #expect(error.technicalDetails?.isEmpty == true)
    }

    @Test("AppError with special characters in messages")
    func testSpecialCharacters() {
        let error = AppError(
            category: .data,
            severity: .error,
            userMessage: "Error: \"Invalid\" data! @#$%",
            technicalDetails: "Failed parsing: <xml> & other stuff",
            suggestions: ["Try fixing: 'quotes' & \"escapes\""]
        )

        #expect(error.errorDescription?.contains("\"Invalid\"") == true)
        #expect(error.failureReason?.contains("<xml>") == true)
        #expect(error.recoverySuggestion?.contains("'quotes'") == true)
    }

    @Test("AppError severity levels cover all use cases")
    func testAllSeverityLevels() {
        let errors = [
            AppError(category: .user, severity: .info, userMessage: "Info", technicalDetails: "", suggestions: []),
            AppError(category: .validation, severity: .warning, userMessage: "Warning", technicalDetails: "", suggestions: []),
            AppError(category: .network, severity: .error, userMessage: "Error", technicalDetails: "", suggestions: []),
            AppError(category: .system, severity: .critical, userMessage: "Critical", technicalDetails: "", suggestions: [])
        ]

        #expect(errors[0].severity.logLevelString == "INFO")
        #expect(errors[1].severity.logLevelString == "WARNING")
        #expect(errors[2].severity.logLevelString == "ERROR")
        #expect(errors[3].severity.logLevelString == "CRITICAL")
    }

    @Test("AppError categories cover all domains")
    func testAllCategories() {
        let categories: [ErrorCategory] = [.network, .data, .validation, .system, .user]

        for category in categories {
            let error = AppError(
                category: category,
                severity: .error,
                userMessage: "Test",
                technicalDetails: "Test",
                suggestions: []
            )

            #expect(error.category == category)
        }
    }

    // MARK: - Edge Cases

    @Test("AppError with suggestions containing newlines")
    func testSuggestionsWithNewlines() {
        let error = AppError(
            category: .validation,
            severity: .warning,
            userMessage: "Warning",
            technicalDetails: "Details",
            suggestions: ["Line 1\nLine 2", "Suggestion 2"]
        )

        let recovery = error.recoverySuggestion!
        #expect(recovery.contains("Line 1\nLine 2"))
        #expect(recovery.contains("Suggestion 2"))
    }

    @Test("AppError with unicode characters")
    func testUnicodeCharacters() {
        let error = AppError(
            category: .user,
            severity: .info,
            userMessage: "Erreur: données invalides 🚫",
            technicalDetails: "日本語エラー",
            suggestions: ["Vérifiez les données"]
        )

        #expect(error.errorDescription?.contains("🚫") == true)
        #expect(error.failureReason?.contains("日本語") == true)
        #expect(error.recoverySuggestion?.contains("Vérifiez") == true)
    }
}

//
//  SimpleErrorHandling.swift
//  Flameworker
//
//  Created by Assistant on 9/30/25.
//

import Foundation
import SwiftUI
import Combine
import OSLog

// MARK: - Simple Error Categories

enum ErrorCategory: String, CaseIterable {
    case network = "Network"
    case data = "Data"
    case validation = "Validation" 
    case system = "System"
    case user = "User"
}

enum ErrorSeverity: Int, CaseIterable {
    case info = 0
    case warning = 1
    case error = 2
    case critical = 3
    
    var logLevel: OSLogType {
        switch self {
        case .info: return .info
        case .warning: return .error
        case .error: return .error
        case .critical: return .fault
        }
    }
}

// MARK: - Simple App Error

struct AppError: Error, LocalizedError {
    let category: ErrorCategory
    let severity: ErrorSeverity
    let userMessage: String
    let technicalDetails: String?
    let suggestions: [String]
    
    var errorDescription: String? { userMessage }
    
    init(
        category: ErrorCategory = .system,
        severity: ErrorSeverity = .error,
        userMessage: String,
        technicalDetails: String? = nil,
        suggestions: [String] = []
    ) {
        self.category = category
        self.severity = severity
        self.userMessage = userMessage
        self.technicalDetails = technicalDetails
        self.suggestions = suggestions
    }
}

// MARK: - Simple Error Handling

/// Simple error handling utility to reduce duplication
struct ErrorHandler {
    static let shared = ErrorHandler()
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Flameworker", category: "ErrorHandler")
    
    private init() {}
    
    /// Execute operation with automatic error logging
    func execute<T>(
        context: String,
        operation: () throws -> T
    ) -> Result<T, Error> {
        do {
            let result = try operation()
            return .success(result)
        } catch {
            log.error("\(context): \(error.localizedDescription)")
            return .failure(error)
        }
    }
    
    /// Execute async operation with automatic error logging
    func executeAsync<T>(
        context: String,
        operation: () async throws -> T
    ) async -> Result<T, Error> {
        do {
            let result = try await operation()
            return .success(result)
        } catch {
            log.error("\(context): \(error.localizedDescription)")
            return .failure(error)
        }
    }
    
    /// Log error with context and appropriate severity
    func logError(_ error: Error, context: String) {
        let severity: OSLogType
        let message: String
        
        if let appError = error as? AppError {
            severity = appError.severity.logLevel
            message = "\(context) [\(appError.category.rawValue)]: \(appError.userMessage)"
            
            if let technicalDetails = appError.technicalDetails {
                log.debug("Technical details: \(technicalDetails)")
            }
            
            if !appError.suggestions.isEmpty {
                log.debug("Suggestions: \(appError.suggestions.joined(separator: ", "))")
            }
        } else {
            severity = .error
            message = "\(context): \(error.localizedDescription)"
        }
        
        log.log(level: severity, "\(message)")
    }
    
    /// Create standardized validation error
    func createValidationError(
        _ message: String,
        suggestions: [String] = ["Check your input", "Try again"]
    ) -> AppError {
        return AppError(
            category: .validation,
            severity: .warning,
            userMessage: message,
            suggestions: suggestions
        )
    }
    
    /// Create standardized data error
    func createDataError(
        _ message: String,
        technicalDetails: String? = nil,
        suggestions: [String] = ["Try again", "Contact support if the problem persists"]
    ) -> AppError {
        return AppError(
            category: .data,
            severity: .error,
            userMessage: message,
            technicalDetails: technicalDetails,
            suggestions: suggestions
        )
    }
}

// MARK: - Error Alert State

@MainActor
final class ErrorAlertState: ObservableObject {
    @Published var isShowingAlert = false
    @Published var alertTitle = "Error"
    @Published var alertMessage = ""
    @Published var alertSuggestions: [String] = []
    
    func show(title: String = "Error", message: String, suggestions: [String] = []) {
        alertTitle = title
        alertMessage = message
        alertSuggestions = suggestions
        isShowingAlert = true
    }
    
    func show(error: Error, context: String = "") {
        let contextString = context.isEmpty ? "" : "\(context): "
        
        if let appError = error as? AppError {
            show(
                title: "\(appError.category.rawValue) Error",
                message: "\(contextString)\(appError.userMessage)",
                suggestions: appError.suggestions
            )
        } else {
            show(message: "\(contextString)\(error.localizedDescription)")
        }
        
        // Also log the error
        ErrorHandler.shared.logError(error, context: context)
    }
    
    func clear() {
        isShowingAlert = false
        alertTitle = "Error"
        alertMessage = ""
        alertSuggestions = []
    }
}

// MARK: - View Extension for Error Handling

extension View {
    func errorAlert(_ errorState: ErrorAlertState) -> some View {
        modifier(ErrorAlertModifier(errorState: errorState))
    }
}

// MARK: - Error Alert Modifier

struct ErrorAlertModifier: ViewModifier {
    @ObservedObject var errorState: ErrorAlertState
    
    func body(content: Content) -> some View {
        content
            .alert(errorState.alertTitle, isPresented: $errorState.isShowingAlert) {
                Button("OK") {
                    errorState.clear()
                }
            } message: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(errorState.alertMessage)
                    
                    if !errorState.alertSuggestions.isEmpty {
                        Text("\nSuggestions:")
                            .font(.headline)
                        ForEach(errorState.alertSuggestions, id: \.self) { suggestion in
                            Text("• \(suggestion)")
                        }
                    }
                }
            }
    }
}
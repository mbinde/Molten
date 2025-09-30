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
    
    /// Log error with context
    func logError(_ error: Error, context: String) {
        log.error("\(context): \(error.localizedDescription)")
    }
}

// MARK: - Error Alert State

@MainActor
final class ErrorAlertState: ObservableObject {
    @Published var isShowingAlert = false
    @Published var alertTitle = "Error"
    @Published var alertMessage = ""
    
    func show(title: String = "Error", message: String) {
        alertTitle = title
        alertMessage = message
        isShowingAlert = true
    }
    
    func show(error: Error, context: String = "") {
        let contextString = context.isEmpty ? "" : "\(context): "
        show(message: "\(contextString)\(error.localizedDescription)")
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
                    errorState.isShowingAlert = false
                }
            } message: {
                Text(errorState.alertMessage)
            }
    }
}
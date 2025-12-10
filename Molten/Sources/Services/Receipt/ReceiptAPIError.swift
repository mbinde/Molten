//
//  ReceiptAPIError.swift
//  Molten
//
//  Errors for receipt API operations
//

import Foundation

/// Errors that can occur during receipt API operations
enum ReceiptAPIError: Error, LocalizedError {
    case networkError(Error)
    case serverError(Int)
    case invalidResponse
    case invalidData
    case notFound
    case unauthorized
    case conflict  // User ID already registered
    case rateLimitExceeded(resetAt: Date)
    case badRequest(String)  // Client error with message

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code):
            return "Server error: \(code)"
        case .invalidResponse:
            return "Invalid server response"
        case .invalidData:
            return "Invalid data format"
        case .notFound:
            return "Receipt not found"
        case .unauthorized:
            return "Authentication failed"
        case .conflict:
            return "User ID already registered"
        case .rateLimitExceeded(let resetAt):
            return "Rate limit exceeded. Try again after \(resetAt)"
        case .badRequest(let message):
            return message
        }
    }
}

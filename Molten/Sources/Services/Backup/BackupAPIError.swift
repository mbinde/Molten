//
//  BackupAPIError.swift
//  Molten
//
//  Errors for backup API operations
//

import Foundation

/// Errors that can occur during backup API operations
enum BackupAPIError: Error, LocalizedError {
    case networkError(Error)
    case serverError(Int)
    case invalidResponse
    case invalidData
    case notFound
    case unauthorized
    case conflict  // Key already registered
    case rateLimitExceeded(resetAt: Date)

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
            return "Backup not found"
        case .unauthorized:
            return "Authentication failed"
        case .conflict:
            return "Backup key already registered"
        case .rateLimitExceeded(let resetAt):
            return "Rate limit exceeded. Try again after \(resetAt)"
        }
    }
}

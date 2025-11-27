//
//  SharingAPIError.swift
//  Molten
//
//  Errors for inventory sharing API operations
//

import Foundation

/// Errors that can occur during API operations
enum SharingAPIError: Error, LocalizedError {
    case networkError(Error)
    case invalidResponse
    case serverError(Int)
    case notFound
    case conflict
    case unauthorized
    case invalidData
    case rateLimitExceeded

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let code):
            return "Server error: \(code)"
        case .notFound:
            return "Share code not found"
        case .conflict:
            return "Share code already exists"
        case .unauthorized:
            return "Unauthorized access"
        case .invalidData:
            return "Invalid data format"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        }
    }
}

//
//  PurchaseRecordRepositoryErrors.swift
//  Molten
//
//  Errors for PurchaseRecord repository operations
//

import Foundation

enum PurchaseRecordRepositoryError: Error, LocalizedError, Equatable {
    case recordNotFound(String)
    case invalidData(String)
    case saveFailed(String)
    case deleteFailed(String)

    var errorDescription: String? {
        switch self {
        case .recordNotFound(let id):
            return "Purchase record not found: \(id)"
        case .invalidData(let reason):
            return "Invalid data: \(reason)"
        case .saveFailed(let reason):
            return "Save failed: \(reason)"
        case .deleteFailed(let reason):
            return "Delete failed: \(reason)"
        }
    }
}

//
//  KilnScheduleRepositoryErrors.swift
//  Molten
//
//  Errors for kiln schedule repository operations
//

import Foundation

enum KilnScheduleRepositoryError: Error, LocalizedError, Equatable {
    case scheduleNotFound
    case invalidData(String)
    case saveFailed(String)
    case deleteFailed(String)

    var errorDescription: String? {
        switch self {
        case .scheduleNotFound:
            return "Kiln schedule not found"
        case .invalidData(let reason):
            return "Invalid data: \(reason)"
        case .saveFailed(let reason):
            return "Save failed: \(reason)"
        case .deleteFailed(let reason):
            return "Delete failed: \(reason)"
        }
    }
}

//
//  ProjectRepositoryErrors.swift
//  Flameworker
//
//  Errors for Project repository operations
//

import Foundation

enum ProjectRepositoryError: Error, LocalizedError, Equatable {
    case planNotFound
    case logNotFound
    case imageNotFound
    case stepNotFound
    case urlNotFound
    case invalidData(String)
    case saveFailed(String)
    case deleteFailed(String)

    var errorDescription: String? {
        switch self {
        case .planNotFound:
            return "Project plan not found"
        case .logNotFound:
            return "Project log not found"
        case .imageNotFound:
            return "Project image not found"
        case .stepNotFound:
            return "Project step not found"
        case .urlNotFound:
            return "Reference URL not found"
        case .invalidData(let reason):
            return "Invalid data: \(reason)"
        case .saveFailed(let reason):
            return "Save failed: \(reason)"
        case .deleteFailed(let reason):
            return "Delete failed: \(reason)"
        }
    }
}

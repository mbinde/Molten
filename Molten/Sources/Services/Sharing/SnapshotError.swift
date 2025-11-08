//
//  SnapshotError.swift
//  Molten
//
//  Errors for inventory snapshot operations
//

import Foundation

/// Errors that can occur during snapshot operations
enum SnapshotError: Error, LocalizedError {
    case serializationFailed
    case deserializationFailed
    case invalidFormat
    case invalidSignature
    case missingData

    var errorDescription: String? {
        switch self {
        case .serializationFailed:
            return "Failed to serialize inventory snapshot"
        case .deserializationFailed:
            return "Failed to deserialize inventory snapshot"
        case .invalidFormat:
            return "Invalid snapshot data format"
        case .invalidSignature:
            return "Snapshot signature verification failed"
        case .missingData:
            return "Required data missing from snapshot"
        }
    }
}

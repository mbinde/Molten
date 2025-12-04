//
//  LabelUpdateModels.swift
//  Molten
//
//  Data models for label database updates
//

import Foundation

/// Metadata about the latest label database version from the server
struct LabelVersionMetadata: Codable, Sendable {
    let version: Int
    let releaseDate: Date
    let fileSize: Int
    let checksum: String
    let changelog: String?
    let minAppVersion: String

    /// Check if this version is compatible with the current app
    func isCompatibleWithApp(version appVersion: String) -> Bool {
        // Simple semantic version comparison (major.minor.patch)
        let minComponents = minAppVersion.split(separator: ".").compactMap { Int($0) }
        let appComponents = appVersion.split(separator: ".").compactMap { Int($0) }

        // Pad arrays to same length
        let maxLength = max(minComponents.count, appComponents.count)
        let paddedMin = minComponents + Array(repeating: 0, count: maxLength - minComponents.count)
        let paddedApp = appComponents + Array(repeating: 0, count: maxLength - appComponents.count)

        // Compare component by component
        for i in 0..<maxLength {
            if paddedApp[i] > paddedMin[i] { return true }
            if paddedApp[i] < paddedMin[i] { return false }
        }

        return true  // Equal versions
    }
}

/// Information about an available label database update
struct LabelUpdateInfo: Sendable {
    let currentVersion: Int?  // nil if no version exists (pre-versioning)
    let availableVersion: Int
    let releaseDate: Date
    let changelog: String?
    let fileSize: Int
    let checksum: String

    /// Whether this is the first versioned update (upgrading from unversioned)
    var isInitialVersionedUpdate: Bool {
        currentVersion == nil
    }
}

/// Result of applying a label database update
struct LabelUpdateResult: Sendable {
    let version: Int
    let layoutCount: Int
    let productCount: Int
    let brandCount: Int
    let appliedAt: Date
}

/// Errors that can occur during label updates
enum LabelUpdateError: Error, LocalizedError {
    case updateNotAvailable
    case incompatibleVersion(required: String, current: String)
    case downloadFailed(underlying: Error)
    case checksumMismatch
    case invalidResponse
    case invalidDatabase
    case serverError(statusCode: Int)
    case storageError(underlying: Error)
    case networkPolicyRestricted
    case databaseSwapFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .updateNotAvailable:
            return "No label database update available"
        case .incompatibleVersion(let required, let current):
            return "Label database requires app version \(required), but current version is \(current)"
        case .downloadFailed(let underlying):
            return "Failed to download label database: \(underlying.localizedDescription)"
        case .checksumMismatch:
            return "Downloaded label database failed integrity check"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidDatabase:
            return "Downloaded file is not a valid label database"
        case .serverError(let statusCode):
            return "Server error (HTTP \(statusCode))"
        case .storageError(let underlying):
            return "Storage error: \(underlying.localizedDescription)"
        case .networkPolicyRestricted:
            return "Download blocked by network policy"
        case .databaseSwapFailed(let underlying):
            return "Failed to install label database: \(underlying.localizedDescription)"
        }
    }
}

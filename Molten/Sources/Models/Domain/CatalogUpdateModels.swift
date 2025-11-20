//
//  CatalogUpdateModels.swift
//  Molten
//
//  Created by Assistant on 11/8/25.
//  Models for OTA catalog update system
//

import Foundation

// MARK: - Catalog Version Metadata

/// Metadata about a catalog version from server
struct CatalogVersionMetadata: Codable, Equatable {
    let version: Int
    let itemCount: Int
    let releaseDate: Date
    let fileSize: Int64
    let checksum: String
    let minAppVersion: String
    let changelog: String

    enum CodingKeys: String, CodingKey {
        case version
        case itemCount = "item_count"
        case releaseDate = "release_date"
        case fileSize = "file_size"
        case checksum
        case minAppVersion = "min_app_version"
        case changelog
    }

    var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    /// Check if this version is compatible with current app
    func isCompatibleWithApp(version: String) -> Bool {
        // Simple semantic version comparison
        return minAppVersion.compare(version, options: .numeric) != .orderedDescending
    }
}

// MARK: - Update Info

/// Information about an available catalog update
struct CatalogUpdateInfo: Equatable, Identifiable {
    let id = UUID()
    let currentVersion: Int
    let availableVersion: Int
    let itemsAdded: Int
    let releaseDate: Date
    let changelog: String
    let fileSize: Int64
    let checksum: String

    var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var isNewVersion: Bool {
        availableVersion > currentVersion
    }
}

// MARK: - Update Result

/// Result of applying a catalog update
struct CatalogUpdateResult: Equatable {
    let version: Int
    let itemsCreated: Int
    let itemsUpdated: Int
    let itemsRemoved: Int
    let appliedAt: Date

    var totalChanges: Int {
        itemsCreated + itemsUpdated + itemsRemoved
    }
}

// MARK: - Download Strategy

/// Strategy for downloading catalog updates
enum CatalogDownloadStrategy {
    case full(version: Int)
    case delta(from: Int, to: Int)  // v2.0 feature

    var downloadType: String {
        switch self {
        case .full: return "full"
        case .delta: return "delta"
        }
    }
}

// MARK: - Delta Update (v2.0)

// NOTE: Delta updates not implemented yet - commented out due to CatalogItemData removal
// Uncomment and update to use GlassItemModel (with Codable conformance) when implementing v2.0

/*
/// Incremental catalog update (not implemented in v1.5)
struct CatalogDelta: Codable {
    let fromVersion: Int
    let toVersion: Int
    let generated: Date
    let added: [GlassItemModel]
    let updated: [CatalogItemUpdate]
    let removed: [String]  // stable_ids

    enum CodingKeys: String, CodingKey {
        case fromVersion = "from_version"
        case toVersion = "to_version"
        case generated
        case added
        case updated
        case removed
    }
}

struct CatalogItemUpdate: Codable {
    let stableId: String
    let changes: [String: AnyCodable]  // Field name -> new value

    enum CodingKeys: String, CodingKey {
        case stableId = "stable_id"
        case changes
    }
}
*/

// Helper for dynamic JSON decoding
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable value cannot be decoded"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case is NSNull:
            try container.encodeNil()
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "AnyCodable value cannot be encoded"
                )
            )
        }
    }
}

// MARK: - Errors

enum CatalogUpdateError: LocalizedError, Equatable {
    case networkPolicyRestricted
    case updateNotAvailable
    case downloadFailed(underlying: Error)
    case checksumMismatch
    case incompatibleVersion(required: String, current: String)
    case storageError(underlying: Error)
    case parseError(underlying: Error)
    case serverError(statusCode: Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .networkPolicyRestricted:
            return "Download restricted by network policy. Enable cellular downloads or connect to WiFi."
        case .updateNotAvailable:
            return "No catalog update is available."
        case .downloadFailed(let error):
            return "Download failed: \(error.localizedDescription)"
        case .checksumMismatch:
            return "Downloaded catalog is corrupted. Please try again."
        case .incompatibleVersion(let required, let current):
            return "This catalog requires app version \(required) or later. Current: \(current)"
        case .storageError(let error):
            return "Storage error: \(error.localizedDescription)"
        case .parseError(let error):
            return "Failed to parse catalog: \(error.localizedDescription)"
        case .serverError(let code):
            return "Server error (\(code)). Please try again later."
        case .invalidResponse:
            return "Invalid response from server."
        }
    }

    // MARK: - Equatable

    static func == (lhs: CatalogUpdateError, rhs: CatalogUpdateError) -> Bool {
        switch (lhs, rhs) {
        case (.networkPolicyRestricted, .networkPolicyRestricted),
             (.updateNotAvailable, .updateNotAvailable),
             (.checksumMismatch, .checksumMismatch),
             (.invalidResponse, .invalidResponse):
            return true

        case (.downloadFailed, .downloadFailed),
             (.storageError, .storageError),
             (.parseError, .parseError):
            // Compare only the case, not the underlying error
            return true

        case (.incompatibleVersion(let lhsRequired, let lhsCurrent),
              .incompatibleVersion(let rhsRequired, let rhsCurrent)):
            return lhsRequired == rhsRequired && lhsCurrent == rhsCurrent

        case (.serverError(let lhsCode), .serverError(let rhsCode)):
            return lhsCode == rhsCode

        default:
            return false
        }
    }
}

//
//  WigWagModels.swift
//  Molten
//
//  Domain models for cane designs - twist canes, wigwag patterns, and glass palettes
//

import Foundation

// MARK: - TwistCaneModel

/// A saved twist cane design with palette reference and twist/width settings
/// Named TwistCaneModel to avoid collision with Core Data entity TwistCane
nonisolated struct TwistCaneModel: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let name: String
    let createdAt: Date
    let updatedAt: Date

    /// Reference to the glass palette used for this cane
    let glassPaletteId: UUID

    /// Twist amount in rotations
    let twist: Double

    /// Width/stretch factor (1.0 = original, smaller = stretched thinner)
    let width: Double

    nonisolated init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        glassPaletteId: UUID,
        twist: Double = 1.0,
        width: Double = 1.0
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.glassPaletteId = glassPaletteId
        self.twist = twist
        self.width = width
    }

    /// Create a copy with updated timestamp
    nonisolated func withUpdatedTimestamp() -> TwistCaneModel {
        TwistCaneModel(
            id: id,
            name: name,
            createdAt: createdAt,
            updatedAt: Date(),
            glassPaletteId: glassPaletteId,
            twist: twist,
            width: width
        )
    }
}

// MARK: - TwistPatternModel

/// A saved twist pattern that can be applied to different color palettes
/// Named TwistPatternModel to avoid collision with Core Data entity WigWagTwistPattern
nonisolated struct TwistPatternModel: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let name: String
    let createdAt: Date
    let updatedAt: Date

    /// The twist history as an array of radians
    let twistHistory: [Double]

    nonisolated init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        twistHistory: [Double] = [0.0]
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.twistHistory = twistHistory
    }

    /// Create a copy with updated timestamp
    nonisolated func withUpdatedTimestamp() -> TwistPatternModel {
        TwistPatternModel(
            id: id,
            name: name,
            createdAt: createdAt,
            updatedAt: Date(),
            twistHistory: twistHistory
        )
    }
}

// MARK: - GlassPaletteModel

/// A reusable palette of glass colors from the catalog
/// Named GlassPaletteModel to avoid collision with Core Data entity GlassPalette
nonisolated struct GlassPaletteModel: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let name: String
    let type: String  // e.g., "wigwag", "twist"
    let createdAt: Date
    let updatedAt: Date
    let coe: Int16

    /// Stable IDs of catalog items actually used in this palette (ordered)
    let catalogItemIds: [String]

    /// All catalog item IDs that were available when this palette was saved
    /// (includes items not directly used in the pattern, for reference)
    let allCatalogItemIds: [String]

    nonisolated init(
        id: UUID = UUID(),
        name: String,
        type: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        coe: Int16,
        catalogItemIds: [String] = [],
        allCatalogItemIds: [String] = []
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.coe = coe
        self.catalogItemIds = catalogItemIds
        self.allCatalogItemIds = allCatalogItemIds
    }

    /// Create a copy with updated timestamp
    nonisolated func withUpdatedTimestamp() -> GlassPaletteModel {
        GlassPaletteModel(
            id: id,
            name: name,
            type: type,
            createdAt: createdAt,
            updatedAt: Date(),
            coe: coe,
            catalogItemIds: catalogItemIds,
            allCatalogItemIds: allCatalogItemIds
        )
    }
}

// MARK: - JSON Encoding Helpers

/// Helpers for encoding/decoding JSON strings stored in Core Data
enum WigWagJSONHelper {
    /// Encode twist history to JSON string for Core Data storage
    nonisolated static func encodeHistory(_ history: [Double]) -> String {
        guard let data = try? JSONEncoder().encode(history),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    /// Decode twist history from JSON string
    nonisolated static func decodeHistory(_ json: String?) -> [Double] {
        guard let json = json,
              let data = json.data(using: .utf8),
              let history = try? JSONDecoder().decode([Double].self, from: data) else {
            return [0.0]
        }
        return history
    }

    /// Encode catalog item IDs to JSON string for Core Data storage
    nonisolated static func encodeItemIds(_ ids: [String]) -> String {
        guard let data = try? JSONEncoder().encode(ids),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    /// Decode catalog item IDs from JSON string
    nonisolated static func decodeItemIds(_ json: String?) -> [String] {
        guard let json = json,
              let data = json.data(using: .utf8),
              let ids = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return ids
    }
}

//
//  CatalogTagAdminModel.swift
//  Molten
//
//  Admin-created catalog tags for catalog contributions.
//  Stored in CloudKit, exported to JSON for incorporation into catalog.
//

import Foundation

/// Admin-created catalog tag (for catalog contributions)
/// Stored in CloudKit, exported to JSON for incorporation into catalog
/// Can represent either an addition (is_removal = false) or removal (is_removal = true) of a tag
struct CatalogTagAdminModel: Identifiable, Equatable, Hashable, Sendable {
    nonisolated let id: UUID
    nonisolated let item_stable_id: String
    nonisolated let tag: String
    nonisolated let is_removal: Bool
    nonisolated let created_at: Date
    nonisolated let updated_at: Date
    nonisolated let deleted_at: Date?

    nonisolated init(
        id: UUID = UUID(),
        item_stable_id: String,
        tag: String,
        is_removal: Bool = false,
        created_at: Date = Date(),
        updated_at: Date = Date(),
        deleted_at: Date? = nil
    ) {
        self.id = id
        self.item_stable_id = item_stable_id
        self.tag = tag
        self.is_removal = is_removal
        self.created_at = created_at
        self.updated_at = updated_at
        self.deleted_at = deleted_at
    }

    // MARK: - Validation

    nonisolated var isValid: Bool {
        !item_stable_id.isEmpty && !tag.isEmpty
    }
}

// MARK: - Export Model

/// Export format for admin tags (for molten-data pipeline)
struct CatalogTagExport: Codable, Sendable {
    nonisolated let version: String
    nonisolated let exported_at: String
    nonisolated let tags: [ExportedTag]
    nonisolated let tag_removals: [ExportedTag]

    struct ExportedTag: Codable, Sendable {
        nonisolated let item_stable_id: String
        nonisolated let tag: String
    }

    nonisolated init(tags: [CatalogTagAdminModel]) {
        self.version = "1.0"
        let formatter = ISO8601DateFormatter()
        self.exported_at = formatter.string(from: Date())

        // Separate additions from removals
        let additions = tags.filter { !$0.is_removal }
        let removals = tags.filter { $0.is_removal }

        self.tags = additions.map { tag in
            ExportedTag(
                item_stable_id: tag.item_stable_id,
                tag: tag.tag
            )
        }
        self.tag_removals = removals.map { tag in
            ExportedTag(
                item_stable_id: tag.item_stable_id,
                tag: tag.tag
            )
        }
    }
}

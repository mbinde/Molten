//
//  SQLiteCoatingItemRepository.swift
//  Molten
//
//  SQLite-based implementation for CoatingItemModel using generic base class
//

import Foundation
import SQLite3

/// SQLite-based read-only repository for catalog coating items
final class SQLiteCoatingItemRepository: BaseSQLiteCatalogItemRepository<CoatingItemModel> {

    // MARK: - Initialization

    nonisolated init(databaseManager: CatalogDatabaseManagerProtocol = CatalogDatabaseManager.shared) {
        super.init(
            databaseManager: databaseManager,
            tableName: "coatings",
            orderByColumns: "manufacturer, name"
        )
    }

    // MARK: - Coating-Specific Parsing

    /// Parse a CoatingItemModel from a SQLite row
    nonisolated override func parseItem(from statement: OpaquePointer) throws -> CoatingItemModel {
        // Column indices from schema:
        // 0=stable_id, 1=code, 2=name, 3=manufacturer, 4=manufacturer_description,
        // 5=tags, 6=image_url, 7=image_path, 8=image_thumb_path, 9=dominant_colors,
        // 10=manufacturer_url, 11=product_type, 12=coe

        guard let stable_id = getText(from: statement, column: 0) else {
            throw SQLiteError.invalidData("Missing stable_id")
        }

        guard let name = getText(from: statement, column: 2) else {
            throw SQLiteError.invalidData("Missing name")
        }

        guard let manufacturer = getText(from: statement, column: 3) else {
            throw SQLiteError.invalidData("Missing manufacturer")
        }

        let sku = getText(from: statement, column: 1)  // code -> sku
        let mfr_notes = getText(from: statement, column: 4)  // manufacturer_description -> mfr_notes
        let url = getText(from: statement, column: 10)  // manufacturer_url -> url
        let mfr_status = "available"  // Default since no status column in database
        let image_url = getText(from: statement, column: 6)
        let image_path = getText(from: statement, column: 7)
        let image_thumb_path = getText(from: statement, column: 8)
        let tags = getText(from: statement, column: 5)
        let dominant_colors = getText(from: statement, column: 9)

        return CoatingItemModel(
            stable_id: stable_id,
            name: name,
            sku: sku,
            manufacturer: manufacturer,
            mfr_notes: mfr_notes,
            url: url,
            mfr_status: mfr_status,
            image_url: image_url,
            image_path: image_path,
            image_thumb_path: image_thumb_path,
            tags: tags,
            dominant_colors: dominant_colors
        )
    }

    // MARK: - Override fetchItems(byStatus:) (Coatings Table Lacks Status Column)

    override func fetchItems(byStatus status: String) async throws -> [CoatingItemModel] {
        // Since coatings table doesn't have a status column, return all items for "available"
        // and empty array for other statuses
        if status == "available" {
            return try await fetchItems(matching: nil)
        }
        return []
    }

    // MARK: - Override getDistinctStatuses() (Coatings Table Lacks Status Column)

    override func getDistinctStatuses() async throws -> [String] {
        // Since coatings table doesn't have a status column, return default
        return ["available"]
    }

    // MARK: - Override searchItems to include manufacturer_description field

    override func searchItems(text: String) async throws -> [CoatingItemModel] {
        let searchPattern = "%\(text)%"
        let query = """
            SELECT * FROM coatings
            WHERE name LIKE ? OR manufacturer LIKE ? OR manufacturer_description LIKE ?
            ORDER BY manufacturer, name
            """

        return try databaseManager.performDatabaseOperation { db in
            try executeQuery(db: db, query: query, parameters: [searchPattern, searchPattern, searchPattern])
        }
    }
}

//
//  SQLiteGlassItemRepository.swift
//  Molten
//
//  SQLite-based implementation for GlassItemModel using generic base class
//

import Foundation
import SQLite3

/// SQLite-based read-only repository for catalog glass items
final class SQLiteGlassItemRepository: BaseSQLiteCatalogItemRepository<GlassItemModel>, GlassItemRepositoryProtocol, @unchecked Sendable {

    // MARK: - Initialization

    nonisolated init(databaseManager: CatalogDatabaseManagerProtocol = CatalogDatabaseManager.shared) {
        super.init(
            databaseManager: databaseManager,
            tableName: "glass_items",
            orderByColumns: "manufacturer, code"
        )
    }

    // MARK: - Glass-Specific Parsing

    // MARK: - Manufacturer Filtering

    /// Filter out manufacturers that shouldn't ship with the bundled catalog
    private func filterByShippedManufacturers(_ items: [GlassItemModel]) -> [GlassItemModel] {
        return items.filter { item in
            GlassManufacturers.shipsWithBundledCatalog(for: item.manufacturer)
        }
    }

    // MARK: - Glass-Specific Parsing

    /// Parse a GlassItemModel from a SQLite row
    nonisolated override func parseItem(from statement: OpaquePointer) throws -> GlassItemModel {
        // Column indices (match schema from build script):
        // 0=stable_id, 1=status, 2=added_date, 3=last_seen, 4=discontinued_date,
        // 5=manufacturer, 6=code, 7=name, 8=full_name, 9=start_date, 10=end_date,
        // 11=manufacturer_description, 12=tags, 13=synonyms, 14=coe, 15=type,
        // 16=manufacturer_url, 17=image_path, 18=image_thumb_path, 19=image_url,
        // 20=stock_type, 21=dominant_colors

        guard let stable_id = getText(from: statement, column: 0) else {
            throw SQLiteError.invalidData("Missing stable_id")
        }

        guard let name = getText(from: statement, column: 7) else {
            throw SQLiteError.invalidData("Missing name")
        }

        guard let manufacturer = getText(from: statement, column: 5) else {
            throw SQLiteError.invalidData("Missing manufacturer")
        }

        let full_name = getText(from: statement, column: 8)  // Full manufacturer product name
        let sku = getText(from: statement, column: 6)  // code -> sku
        let mfr_notes = getText(from: statement, column: 11)  // manufacturer_description -> mfr_notes

        // Parse COE (required field, default to 90 if missing)
        let coe: Int32
        if let coeText = getText(from: statement, column: 14), let coeValue = Int32(coeText) {
            coe = coeValue
        } else {
            coe = 90  // Default COE
        }

        let url = getText(from: statement, column: 16)  // manufacturer_url -> url
        let mfr_status = getText(from: statement, column: 1) ?? "available"  // status -> mfr_status
        let image_path = getText(from: statement, column: 17)
        let image_thumb_path = getText(from: statement, column: 18)
        let image_url = getText(from: statement, column: 19)

        // Parse dominant_colors from JSON array format: ["#2E5E41", "#1D4030", "#0C2219"]
        let dominant_colors: [String]?
        if let colorsJSON = getText(from: statement, column: 21), !colorsJSON.isEmpty {
            // Parse JSON array of hex color strings
            if let data = colorsJSON.data(using: .utf8),
               let colors = try? JSONDecoder().decode([String].self, from: data) {
                dominant_colors = colors
            } else {
                dominant_colors = nil
            }
        } else {
            dominant_colors = nil
        }

        return GlassItemModel(
            stable_id: stable_id,
            name: name,
            full_name: full_name,
            sku: sku,
            manufacturer: manufacturer,
            mfr_notes: mfr_notes,
            coe: coe,
            url: url,
            mfr_status: mfr_status,
            image_url: image_url,
            image_path: image_path,
            image_thumb_path: image_thumb_path,
            dominant_colors: dominant_colors
        )
    }

    // MARK: - Overridden Methods with Manufacturer Filtering

    override func fetchItems(matching predicate: NSPredicate?) async throws -> [GlassItemModel] {
        let items = try await super.fetchItems(matching: predicate)
        return filterByShippedManufacturers(items)
    }

    override func fetchItem(byStableId stableId: String) async throws -> GlassItemModel? {
        guard let item = try await super.fetchItem(byStableId: stableId) else {
            return nil
        }
        return GlassManufacturers.shipsWithBundledCatalog(for: item.manufacturer) ? item : nil
    }

    override func searchItems(text: String) async throws -> [GlassItemModel] {
        let searchPattern = "%\(text)%"
        let query = """
            SELECT * FROM glass_items
            WHERE name LIKE ? OR manufacturer LIKE ? OR code LIKE ? OR full_name LIKE ?
            ORDER BY manufacturer, code
            """

        let items = try databaseManager.performDatabaseOperation { db in
            try executeQuery(db: db, query: query, parameters: [searchPattern, searchPattern, searchPattern, searchPattern])
        }
        return filterByShippedManufacturers(items)
    }

    override func fetchItems(byManufacturer manufacturer: String) async throws -> [GlassItemModel] {
        // Check if this manufacturer should even be queried
        guard GlassManufacturers.shipsWithBundledCatalog(for: manufacturer) else {
            return []
        }
        return try await super.fetchItems(byManufacturer: manufacturer)
    }

    // MARK: - Glass-Specific Query Methods

    /// Fetch glass items by COE (coefficient of expansion)
    func fetchItems(byCOE coe: Int32) async throws -> [GlassItemModel] {
        let query = "SELECT * FROM glass_items WHERE coe = ? ORDER BY manufacturer, code"

        let items = try databaseManager.performDatabaseOperation { db in
            try executeQuery(db: db, query: query, parameters: [String(coe)])
        }

        return filterByShippedManufacturers(items)
    }

    /// Get all distinct COE values in the system
    func getDistinctCOEValues() async throws -> [Int32] {
        let query = "SELECT DISTINCT coe FROM glass_items WHERE coe IS NOT NULL AND coe != '' ORDER BY CAST(coe AS INTEGER)"

        return try databaseManager.performDatabaseOperation { db in
            var coeValues: [Int32] = []
            var statement: OpaquePointer?

            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                throw SQLiteError.queryFailed(String(cString: sqlite3_errmsg(db)))
            }

            defer {
                sqlite3_finalize(statement)
            }

            while sqlite3_step(statement) == SQLITE_ROW {
                if let coeText = sqlite3_column_text(statement, 0) {
                    let coeString = String(cString: coeText)
                    if let coeValue = Int32(coeString) {
                        coeValues.append(coeValue)
                    }
                }
            }

            return coeValues
        }
    }

    // MARK: - Kiln Schedule Operations (Not Supported for Bundled Catalog)

    /// Get recommended kiln schedules for a glass item
    func getRecommendedSchedules(forGlassItem stableId: String) async throws -> [UUID] {
        // Bundled catalog doesn't support kiln schedule relationships
        return []
    }

    /// Add a kiln schedule to a glass item's recommended schedules
    func addRecommendedSchedule(scheduleId: UUID, toGlassItem stableId: String) async throws {
        throw SQLiteError.writeOperationNotSupported("Kiln schedules not supported in bundled catalog")
    }

    /// Remove a kiln schedule from a glass item's recommended schedules
    func removeRecommendedSchedule(scheduleId: UUID, fromGlassItem stableId: String) async throws {
        throw SQLiteError.writeOperationNotSupported("Kiln schedules not supported in bundled catalog")
    }
}

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

    // MARK: - Query with Image Aggregation

    /// Query that joins glass_items with glass_item_images to get all image filenames
    /// Uses GROUP_CONCAT to aggregate multiple image filenames into a comma-separated string
    private var queryWithImages: String {
        """
        SELECT gi.*,
               GROUP_CONCAT(gii.filename) as image_filenames
        FROM glass_items gi
        LEFT JOIN glass_item_images gii ON gi.stable_id = gii.stable_id
        GROUP BY gi.stable_id
        ORDER BY gi.manufacturer, gi.code
        """
    }

    /// Query for single item with images
    private func queryWithImagesForItem(stableId: String) -> String {
        """
        SELECT gi.*,
               GROUP_CONCAT(gii.filename) as image_filenames
        FROM glass_items gi
        LEFT JOIN glass_item_images gii ON gi.stable_id = gii.stable_id
        WHERE gi.stable_id = ?
        GROUP BY gi.stable_id
        """
    }

    // MARK: - Manufacturer Filtering

    /// Filter out manufacturers that shouldn't ship with the bundled catalog
    private func filterByShippedManufacturers(_ items: [GlassItemModel]) -> [GlassItemModel] {
        return items.filter { item in
            GlassManufacturers.shipsWithBundledCatalog(for: item.manufacturer)
        }
    }

    // MARK: - Glass-Specific Parsing

    /// Parse a GlassItemModel from a SQLite row
    /// Actual column indices from glass_items schema:
    /// 0=stable_id, 1=status, 2=added_date, 3=last_seen, 4=discontinued_date,
    /// 5=manufacturer, 6=code, 7=name, 8=full_name, 9=start_date, 10=end_date,
    /// 11=manufacturer_description, 12=tags, 13=synonyms, 14=coe, 15=type,
    /// 16=manufacturer_url, 17=image_path, 18=image_thumb_path, 19=image_url,
    /// 20=stock_type, 21=dominant_colors, 22=representative_color, 23=color_spread,
    /// 24=color_clusters, 25=color_confidence, 26=color_flags, 27=last_reviewed,
    /// 28=image_count, 29=hero_image
    /// 30=image_filenames (from GROUP_CONCAT join, only present when using queryWithImages)
    nonisolated override func parseItem(from statement: OpaquePointer) throws -> GlassItemModel {
        guard let stable_id = getText(from: statement, column: 0) else {
            throw SQLiteError.invalidData("Missing stable_id")
        }

        guard let name = getText(from: statement, column: 7) else {
            throw SQLiteError.invalidData("Missing name")
        }

        guard let manufacturer = getText(from: statement, column: 5) else {
            throw SQLiteError.invalidData("Missing manufacturer")
        }

        let full_name = getText(from: statement, column: 8)
        let sku = getText(from: statement, column: 6)
        let mfr_notes = getText(from: statement, column: 11)

        // Parse COE (required field, default to 90 if missing)
        let coe: Int32
        if let coeText = getText(from: statement, column: 14), let coeValue = Int32(coeText) {
            coe = coeValue
        } else {
            coe = 90
        }

        let url = getText(from: statement, column: 16)
        let mfr_status = getText(from: statement, column: 1) ?? "available"
        let image_url = getText(from: statement, column: 19)

        // Parse dominant_colors from JSON array format: ["#2E5E41", "#1D4030", "#0C2219"]
        let dominant_colors = parseJSONStringArray(from: statement, column: 21)

        // Get hero_image (column 29) - this is the primary image filename
        let hero_image = getText(from: statement, column: 29)

        // Get aggregated image filenames from GROUP_CONCAT (column 30)
        // This will be a comma-separated list like "abc_123.jpg,abc_456.jpg"
        let imageFilenamesStr = getText(from: statement, column: 30)
        var image_paths: [String]? = nil
        var image_thumb_paths: [String]? = nil
        var image_path: String? = nil
        var image_thumb_path: String? = nil

        if let filenamesStr = imageFilenamesStr, !filenamesStr.isEmpty {
            var filenames = filenamesStr.split(separator: ",").map { String($0) }

            // Sort so hero_image comes first if it exists
            if let hero = hero_image {
                filenames.sort { f1, f2 in
                    if f1 == hero { return true }
                    if f2 == hero { return false }
                    return f1 < f2
                }
            }

            if !filenames.isEmpty {
                image_paths = filenames

                // Generate thumbnail paths by inserting _thumb before extension
                image_thumb_paths = filenames.map { filename in
                    let nsFilename = filename as NSString
                    let ext = nsFilename.pathExtension
                    let nameWithoutExt = nsFilename.deletingPathExtension
                    return "\(nameWithoutExt)_thumb.\(ext)"
                }

                // Set primary image_path and image_thumb_path
                image_path = filenames.first
                image_thumb_path = image_thumb_paths?.first
            }
        } else {
            // Fallback to columns 17/18 if no images in glass_item_images table
            image_path = getText(from: statement, column: 17)
            image_thumb_path = getText(from: statement, column: 18)
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
            dominant_colors: dominant_colors,
            image_urls: nil,
            image_paths: image_paths,
            image_thumb_paths: image_thumb_paths
        )
    }

    /// Helper to parse JSON string array from a column
    private nonisolated func parseJSONStringArray(from statement: OpaquePointer, column: Int32) -> [String]? {
        guard let jsonString = getText(from: statement, column: column), !jsonString.isEmpty else {
            return nil
        }
        guard let data = jsonString.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            return nil
        }
        return array.isEmpty ? nil : array
    }

    // MARK: - Overridden Methods with Image Aggregation

    override func fetchItems(matching predicate: NSPredicate?) async throws -> [GlassItemModel] {
        let items = try databaseManager.performDatabaseOperation { db in
            try executeQuery(db: db, query: queryWithImages)
        }

        let filtered = filterByShippedManufacturers(items)

        if let predicate = predicate {
            return filtered.filter { predicate.evaluate(with: $0) }
        }

        return filtered
    }

    override func fetchItem(byStableId stableId: String) async throws -> GlassItemModel? {
        let query = queryWithImagesForItem(stableId: stableId)
        let items = try databaseManager.performDatabaseOperation { db in
            try executeQuery(db: db, query: query, parameters: [stableId])
        }

        guard let item = items.first else {
            return nil
        }
        return GlassManufacturers.shipsWithBundledCatalog(for: item.manufacturer) ? item : nil
    }

    override func searchItems(text: String) async throws -> [GlassItemModel] {
        let searchPattern = "%\(text)%"
        let query = """
            SELECT gi.*,
                   GROUP_CONCAT(gii.filename) as image_filenames
            FROM glass_items gi
            LEFT JOIN glass_item_images gii ON gi.stable_id = gii.stable_id
            WHERE gi.name LIKE ? OR gi.manufacturer LIKE ? OR gi.code LIKE ? OR gi.full_name LIKE ?
            GROUP BY gi.stable_id
            ORDER BY gi.manufacturer, gi.code
            """

        let items = try databaseManager.performDatabaseOperation { db in
            try executeQuery(db: db, query: query, parameters: [searchPattern, searchPattern, searchPattern, searchPattern])
        }
        return filterByShippedManufacturers(items)
    }

    override func fetchItems(byManufacturer manufacturer: String) async throws -> [GlassItemModel] {
        guard GlassManufacturers.shipsWithBundledCatalog(for: manufacturer) else {
            return []
        }

        let query = """
            SELECT gi.*,
                   GROUP_CONCAT(gii.filename) as image_filenames
            FROM glass_items gi
            LEFT JOIN glass_item_images gii ON gi.stable_id = gii.stable_id
            WHERE gi.manufacturer = ?
            GROUP BY gi.stable_id
            ORDER BY gi.manufacturer, gi.code
            """

        return try databaseManager.performDatabaseOperation { db in
            try executeQuery(db: db, query: query, parameters: [manufacturer])
        }
    }

    // MARK: - Glass-Specific Query Methods

    /// Fetch glass items by COE (coefficient of expansion)
    func fetchItems(byCOE coe: Int32) async throws -> [GlassItemModel] {
        let query = """
            SELECT gi.*,
                   GROUP_CONCAT(gii.filename) as image_filenames
            FROM glass_items gi
            LEFT JOIN glass_item_images gii ON gi.stable_id = gii.stable_id
            WHERE gi.coe = ?
            GROUP BY gi.stable_id
            ORDER BY gi.manufacturer, gi.code
            """

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

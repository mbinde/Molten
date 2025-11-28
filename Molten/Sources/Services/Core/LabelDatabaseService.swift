//
//  LabelDatabaseService.swift
//  Molten
//
//  Service for querying the label database (2,600+ label formats from 87 brands)
//

import Foundation
import SQLite3

// MARK: - Data Models

/// A label brand from the database
struct LabelBrand: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let slug: String
    let isMajor: Bool

    var displayName: String {
        // Remove trailing ® if present for cleaner display
        name.replacingOccurrences(of: "®", with: "").trimmingCharacters(in: .whitespaces)
    }
}

/// A label product (SKU) from the database
struct LabelProduct: Identifiable, Hashable, Sendable {
    let id: Int
    let brandId: Int
    let layoutId: Int
    let sku: String
    let displayName: String
    let description: String
    let sourceUrl: String?

    // Denormalized for convenience
    let brandName: String
    let brandSlug: String
}

/// A unique label layout (physical geometry) from the database
struct LabelLayout: Identifiable, Hashable, Sendable {
    let id: Int

    // Dimensions in points (1/72 inch)
    let labelWidth: Double
    let labelHeight: Double

    // Grid configuration
    let columns: Int
    let rows: Int

    // Margins and gaps in points
    let leftMargin: Double
    let topMargin: Double
    let horizontalGap: Double
    let verticalGap: Double

    // Shape and styling
    let cornerRadius: Double
    let shape: String  // "rectangle", "square", "circle", "oval"

    // Page configuration
    let pageFormat: String  // "letter" or "a4"
    let pageWidth: Double
    let pageHeight: Double

    // Computed
    let labelsPerSheet: Int

    /// Width in inches
    var widthInches: Double { labelWidth / 72.0 }

    /// Height in inches
    var heightInches: Double { labelHeight / 72.0 }

    /// Formatted dimensions string
    var dimensionString: String {
        String(format: "%.2f\" × %.2f\"", widthInches, heightInches)
    }

    /// Shape category for filtering
    var shapeCategory: LabelShape {
        switch shape {
        case "circle": return .circular
        case "oval": return .circular  // Treat ovals as circular for filtering
        case "square": return .square
        default:
            // rectangle - determine by aspect ratio
            if labelWidth > labelHeight {
                return .landscape
            } else if labelHeight > labelWidth {
                return .portrait
            } else {
                return .square
            }
        }
    }
}

/// Complete label format with product and layout info
struct LabelFormat: Identifiable, Hashable, Sendable {
    let product: LabelProduct
    let layout: LabelLayout

    var id: Int { product.id }

    /// Display name for UI
    var displayName: String { product.displayName }

    /// Brand name
    var brandName: String { product.brandName }

    /// SKU
    var sku: String { product.sku }

    /// Labels per sheet
    var labelsPerSheet: Int { layout.labelsPerSheet }

    /// Dimensions string
    var dimensionString: String { layout.dimensionString }

    /// Shape category
    var shape: LabelShape { layout.shapeCategory }

    /// Convert to LabelGeometry for PDF generation
    func toLabelGeometry() -> LabelGeometry {
        // Determine default font scale and QR size based on label area
        let area = layout.labelWidth * layout.labelHeight
        let fontScale: CGFloat
        let qrSize: CGFloat

        if area < 3000 {
            // Small labels (like return address)
            fontScale = 0.75
            qrSize = 0.7
        } else if area < 15000 {
            // Medium labels (like standard address)
            fontScale = 1.0
            qrSize = 0.65
        } else {
            // Large labels (like shipping)
            fontScale = 1.2
            qrSize = 0.6
        }

        return LabelGeometry(
            name: product.displayName,
            labelsPerSheet: layout.labelsPerSheet,
            columns: layout.columns,
            rows: layout.rows,
            labelWidth: CGFloat(layout.labelWidth),
            labelHeight: CGFloat(layout.labelHeight),
            leftMargin: CGFloat(layout.leftMargin),
            topMargin: CGFloat(layout.topMargin),
            horizontalGap: CGFloat(layout.horizontalGap),
            verticalGap: CGFloat(layout.verticalGap),
            defaultFontScale: fontScale,
            defaultQRSize: qrSize,
            isCircular: layout.shape == "circle"
        )
    }
}

// MARK: - Service

/// Service for querying the label database
/// Thread-safe via internal synchronization
final class LabelDatabaseService: @unchecked Sendable {

    // MARK: - Properties

    // Database connection - protected by lock
    private nonisolated(unsafe) var _db: OpaquePointer?
    private let lock = NSLock()

    // Cached data - protected by lock
    private nonisolated(unsafe) var _brands: [LabelBrand]?
    private nonisolated(unsafe) var _layouts: [Int: LabelLayout] = [:]

    // Thread-safe accessor
    private var db: OpaquePointer? {
        lock.lock()
        defer { lock.unlock() }
        return _db
    }

    // MARK: - Initialization

    init() {
        openDatabase()
    }

    deinit {
        lock.lock()
        if let db = _db {
            sqlite3_close(db)
        }
        lock.unlock()
    }

    // MARK: - Database Connection

    private func openDatabase() {
        guard let dbPath = Bundle.main.path(forResource: "labels", ofType: "db") else {
            print("LabelDatabaseService: Could not find labels.db in bundle")
            return
        }

        lock.lock()
        defer { lock.unlock() }

        if sqlite3_open_v2(dbPath, &_db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            print("LabelDatabaseService: Failed to open database")
            _db = nil
        }
    }

    // MARK: - Query Methods

    /// Get all brands, optionally filtered to major brands only
    func getBrands(majorOnly: Bool = false) -> [LabelBrand] {
        if let cached = _brands {
            return majorOnly ? cached.filter { $0.isMajor } : cached
        }

        guard let db = db else { return [] }

        var brands: [LabelBrand] = []
        let sql = "SELECT id, name, slug, is_major FROM brands ORDER BY is_major DESC, name ASC"

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let brand = LabelBrand(
                    id: Int(sqlite3_column_int(stmt, 0)),
                    name: String(cString: sqlite3_column_text(stmt, 1)),
                    slug: String(cString: sqlite3_column_text(stmt, 2)),
                    isMajor: sqlite3_column_int(stmt, 3) == 1
                )
                brands.append(brand)
            }
        }
        sqlite3_finalize(stmt)

        _brands = brands
        return majorOnly ? brands.filter { $0.isMajor } : brands
    }

    /// Get products for a specific brand
    func getProducts(brandSlug: String) -> [LabelFormat] {
        guard db != nil else { return [] }

        let sql = """
            SELECT p.id, p.brand_id, p.layout_id, p.sku, p.display_name, p.description, p.source_url,
                   b.name AS brand_name, b.slug AS brand_slug,
                   l.label_width, l.label_height, l.columns, l.rows,
                   l.left_margin, l.top_margin, l.horizontal_gap, l.vertical_gap,
                   l.corner_radius, l.shape, l.page_format, l.page_width, l.page_height, l.labels_per_sheet
            FROM products p
            JOIN brands b ON p.brand_id = b.id
            JOIN layouts l ON p.layout_id = l.id
            WHERE b.slug = ?
            ORDER BY p.sku ASC
            """

        return executeProductQuery(sql: sql, bindSlug: brandSlug)
    }

    /// Search products by SKU or name
    func searchProducts(query: String, limit: Int = 50) -> [LabelFormat] {
        guard let db = db, !query.isEmpty else { return [] }

        // Use FTS for search
        let searchTerm = query + "*"  // Prefix match
        let sql = """
            SELECT p.id, p.brand_id, p.layout_id, p.sku, p.display_name, p.description, p.source_url,
                   b.name AS brand_name, b.slug AS brand_slug,
                   l.label_width, l.label_height, l.columns, l.rows,
                   l.left_margin, l.top_margin, l.horizontal_gap, l.vertical_gap,
                   l.corner_radius, l.shape, l.page_format, l.page_width, l.page_height, l.labels_per_sheet
            FROM products_fts fts
            JOIN products p ON fts.rowid = p.id
            JOIN brands b ON p.brand_id = b.id
            JOIN layouts l ON p.layout_id = l.id
            WHERE products_fts MATCH ?
            ORDER BY rank
            LIMIT ?
            """

        var results: [LabelFormat] = []
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, searchTerm, -1, nil)
            sqlite3_bind_int(stmt, 2, Int32(limit))

            while sqlite3_step(stmt) == SQLITE_ROW {
                if let format = parseLabelFormat(stmt: stmt) {
                    results.append(format)
                }
            }
        }
        sqlite3_finalize(stmt)

        return results
    }

    /// Get products filtered by geometry
    func getProducts(
        labelsPerSheet: Int? = nil,
        shape: LabelShape? = nil,
        pageFormat: String? = nil,
        minWidth: Double? = nil,
        maxWidth: Double? = nil,
        minHeight: Double? = nil,
        maxHeight: Double? = nil
    ) -> [LabelFormat] {
        guard let db = db else { return [] }

        var conditions: [String] = []
        var params: [Any] = []

        if let labelsPerSheet = labelsPerSheet {
            conditions.append("l.labels_per_sheet = ?")
            params.append(labelsPerSheet)
        }

        if let shape = shape {
            switch shape {
            case .circular:
                conditions.append("l.shape IN ('circle', 'oval')")
            case .square:
                conditions.append("l.shape = 'square'")
            case .landscape:
                conditions.append("l.shape = 'rectangle' AND l.label_width > l.label_height")
            case .portrait:
                conditions.append("l.shape = 'rectangle' AND l.label_height > l.label_width")
            case .flag:
                conditions.append("l.shape = 'flag'")  // Cable/wire flag labels
            }
        }

        if let pageFormat = pageFormat {
            conditions.append("l.page_format = ?")
            params.append(pageFormat)
        }

        if let minWidth = minWidth {
            conditions.append("l.label_width >= ?")
            params.append(minWidth * 72)  // Convert inches to points
        }

        if let maxWidth = maxWidth {
            conditions.append("l.label_width <= ?")
            params.append(maxWidth * 72)
        }

        if let minHeight = minHeight {
            conditions.append("l.label_height >= ?")
            params.append(minHeight * 72)
        }

        if let maxHeight = maxHeight {
            conditions.append("l.label_height <= ?")
            params.append(maxHeight * 72)
        }

        let whereClause = conditions.isEmpty ? "" : "WHERE " + conditions.joined(separator: " AND ")

        let sql = """
            SELECT p.id, p.brand_id, p.layout_id, p.sku, p.display_name, p.description, p.source_url,
                   b.name AS brand_name, b.slug AS brand_slug,
                   l.label_width, l.label_height, l.columns, l.rows,
                   l.left_margin, l.top_margin, l.horizontal_gap, l.vertical_gap,
                   l.corner_radius, l.shape, l.page_format, l.page_width, l.page_height, l.labels_per_sheet
            FROM products p
            JOIN brands b ON p.brand_id = b.id
            JOIN layouts l ON p.layout_id = l.id
            \(whereClause)
            ORDER BY b.is_major DESC, b.name ASC, p.sku ASC
            """

        var results: [LabelFormat] = []
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            // Bind parameters
            for (index, param) in params.enumerated() {
                let bindIndex = Int32(index + 1)
                if let intParam = param as? Int {
                    sqlite3_bind_int(stmt, bindIndex, Int32(intParam))
                } else if let doubleParam = param as? Double {
                    sqlite3_bind_double(stmt, bindIndex, doubleParam)
                } else if let stringParam = param as? String {
                    sqlite3_bind_text(stmt, bindIndex, stringParam, -1, nil)
                }
            }

            while sqlite3_step(stmt) == SQLITE_ROW {
                if let format = parseLabelFormat(stmt: stmt) {
                    results.append(format)
                }
            }
        }
        sqlite3_finalize(stmt)

        return results
    }

    /// Get unique labels per sheet counts available
    func getAvailableLabelsPerSheet() -> [Int] {
        guard let db = db else { return [] }

        var counts: [Int] = []
        let sql = "SELECT DISTINCT labels_per_sheet FROM layouts ORDER BY labels_per_sheet ASC"

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                counts.append(Int(sqlite3_column_int(stmt, 0)))
            }
        }
        sqlite3_finalize(stmt)

        return counts
    }

    /// Get statistics about the database
    func getStatistics() -> (brands: Int, products: Int, layouts: Int) {
        guard let db = db else { return (0, 0, 0) }

        var brands = 0, products = 0, layouts = 0

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM brands", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                brands = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)

        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM products", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                products = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)

        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM layouts", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                layouts = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)

        return (brands, products, layouts)
    }

    // MARK: - Private Helpers

    private func executeProductQuery(sql: String, bindSlug: String? = nil) -> [LabelFormat] {
        guard let db = db else { return [] }

        var results: [LabelFormat] = []
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if let slug = bindSlug {
                sqlite3_bind_text(stmt, 1, slug, -1, nil)
            }

            while sqlite3_step(stmt) == SQLITE_ROW {
                if let format = parseLabelFormat(stmt: stmt) {
                    results.append(format)
                }
            }
        }
        sqlite3_finalize(stmt)

        return results
    }

    private func parseLabelFormat(stmt: OpaquePointer?) -> LabelFormat? {
        guard let stmt = stmt else { return nil }

        let product = LabelProduct(
            id: Int(sqlite3_column_int(stmt, 0)),
            brandId: Int(sqlite3_column_int(stmt, 1)),
            layoutId: Int(sqlite3_column_int(stmt, 2)),
            sku: String(cString: sqlite3_column_text(stmt, 3)),
            displayName: String(cString: sqlite3_column_text(stmt, 4)),
            description: String(cString: sqlite3_column_text(stmt, 5)),
            sourceUrl: sqlite3_column_text(stmt, 6).map { String(cString: $0) },
            brandName: String(cString: sqlite3_column_text(stmt, 7)),
            brandSlug: String(cString: sqlite3_column_text(stmt, 8))
        )

        let layout = LabelLayout(
            id: product.layoutId,
            labelWidth: sqlite3_column_double(stmt, 9),
            labelHeight: sqlite3_column_double(stmt, 10),
            columns: Int(sqlite3_column_int(stmt, 11)),
            rows: Int(sqlite3_column_int(stmt, 12)),
            leftMargin: sqlite3_column_double(stmt, 13),
            topMargin: sqlite3_column_double(stmt, 14),
            horizontalGap: sqlite3_column_double(stmt, 15),
            verticalGap: sqlite3_column_double(stmt, 16),
            cornerRadius: sqlite3_column_double(stmt, 17),
            shape: String(cString: sqlite3_column_text(stmt, 18)),
            pageFormat: String(cString: sqlite3_column_text(stmt, 19)),
            pageWidth: sqlite3_column_double(stmt, 20),
            pageHeight: sqlite3_column_double(stmt, 21),
            labelsPerSheet: Int(sqlite3_column_int(stmt, 22))
        )

        return LabelFormat(product: product, layout: layout)
    }
}

// MARK: - Shared Instance

extension LabelDatabaseService {
    /// Shared instance for app-wide use
    static let shared = LabelDatabaseService()
}

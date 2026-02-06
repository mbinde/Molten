//
//  OnlineStockModels.swift
//  Molten
//
//  Models for online stock availability checking
//

import Foundation

// MARK: - Stock Status

/// Represents the stock availability status at a retailer
enum StockStatus: String, Codable, Sendable, Equatable {
    case inStock = "in_stock"
    case outOfStock = "out_of_stock"
    case lowStock = "low_stock"
    case unknown = "unknown"
    case notCarried = "not_carried"

    /// User-friendly display text
    var displayText: String {
        switch self {
        case .inStock: return "In Stock"
        case .outOfStock: return "Out of Stock"
        case .lowStock: return "Low Stock"
        case .unknown: return "Unknown"
        case .notCarried: return "Not Carried"
        }
    }

    /// Whether this status indicates the item is available for purchase
    var isAvailable: Bool {
        self == .inStock || self == .lowStock
    }
}

// MARK: - Retailer Stock

/// Stock availability information for a single retailer
struct RetailerStockModel: Codable, Equatable, Sendable, Identifiable {
    let retailerCode: String
    let retailerName: String
    let stockStatus: StockStatus
    let lastChecked: Date
    let productUrl: String?

    // Pricing
    let price: Decimal?
    let priceUnit: String?
    let currency: String?

    // Quantity
    let quantityAvailable: Int?

    var id: String { retailerCode }

    /// Formatted price string (e.g., "$4.50/rod" or "$12.99")
    var formattedPrice: String? {
        guard let price = price else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency ?? "USD"
        guard let formatted = formatter.string(from: price as NSDecimalNumber) else { return nil }
        if let unit = priceUnit {
            return "\(formatted)/\(unit)"
        }
        return formatted
    }

    enum CodingKeys: String, CodingKey {
        case retailerCode = "retailer_code"
        case retailerName = "retailer_name"
        case stockStatus = "stock_status"
        case lastChecked = "last_checked"
        case productUrl = "product_url"
        case price
        case priceUnit = "price_unit"
        case currency
        case quantityAvailable = "quantity_available"
    }
}

// MARK: - Online Stock Response

/// Aggregated stock data for an item across all retailers
struct OnlineStockModel: Codable, Equatable, Sendable {
    let itemStableId: String
    let retailers: [RetailerStockModel]
    let lastUpdated: Date

    /// Whether any retailer has the item in stock
    var anyInStock: Bool {
        retailers.contains { $0.stockStatus.isAvailable }
    }

    /// Retailers that have the item in stock (including low stock)
    var inStockRetailers: [RetailerStockModel] {
        retailers.filter { $0.stockStatus.isAvailable }
    }

    /// Count of retailers with stock available
    var inStockCount: Int {
        inStockRetailers.count
    }

    enum CodingKeys: String, CodingKey {
        case itemStableId = "item_stable_id"
        case retailers
        case lastUpdated = "last_updated"
    }
}

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

// MARK: - Price Option

/// A single price/variant option from a retailer
struct PriceOptionModel: Codable, Equatable, Sendable, Identifiable {
    let variantId: String?
    let variantTitle: String?
    let price: Decimal?
    let priceUnit: String?
    let currency: String?
    let available: Bool

    var id: String { variantId ?? variantTitle ?? UUID().uuidString }

    /// Extract the form from variant title (e.g., "Rods - First Quality" -> "Rods")
    var form: String? {
        guard let title = variantTitle else { return nil }
        // If title contains " - ", the form is the first part
        if let dashIndex = title.range(of: " - ") {
            return String(title[..<dashIndex.lowerBound])
        }
        // Otherwise the whole title is the form (e.g., "Frit", "Powder")
        return title
    }

    /// Extract the quality from variant title (e.g., "Rods - First Quality" -> "First Quality")
    var quality: String? {
        guard let title = variantTitle else { return nil }
        if let dashIndex = title.range(of: " - ") {
            return String(title[dashIndex.upperBound...])
        }
        return nil
    }

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
        case variantId = "variant_id"
        case variantTitle = "variant_title"
        case price
        case priceUnit = "price_unit"
        case currency
        case available
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

    // All price options/variants for this retailer
    let priceOptions: [PriceOptionModel]

    // Quantity
    let quantityAvailable: Int?

    var id: String { retailerCode }

    // MARK: - Convenience accessors for backward compatibility

    /// First available price option (for simple display)
    var firstAvailableOption: PriceOptionModel? {
        priceOptions.first { $0.available } ?? priceOptions.first
    }

    /// Price from first available option
    var price: Decimal? { firstAvailableOption?.price }

    /// Price unit from first available option
    var priceUnit: String? { firstAvailableOption?.priceUnit }

    /// Currency from first available option
    var currency: String? { firstAvailableOption?.currency }

    /// Formatted price string (e.g., "$4.50/rod" or "$12.99")
    var formattedPrice: String? { firstAvailableOption?.formattedPrice }

    // MARK: - Form-based grouping

    /// Group price options by form (Rods, Frit, Powder, etc.)
    var optionsByForm: [String: [PriceOptionModel]] {
        Dictionary(grouping: priceOptions.filter { $0.available }) { option in
            option.form ?? "Other"
        }
    }

    /// Available forms for this retailer
    var availableForms: [String] {
        Array(optionsByForm.keys).sorted()
    }

    /// Best (cheapest available) option for each form
    var bestOptionPerForm: [PriceOptionModel] {
        optionsByForm.compactMap { (_, options) in
            options.filter { $0.available }.min { ($0.price ?? .greatestFiniteMagnitude) < ($1.price ?? .greatestFiniteMagnitude) }
        }.sorted { ($0.form ?? "") < ($1.form ?? "") }
    }

    enum CodingKeys: String, CodingKey {
        case retailerCode = "retailer_code"
        case retailerName = "retailer_name"
        case stockStatus = "stock_status"
        case lastChecked = "last_checked"
        case productUrl = "product_url"
        case priceOptions = "price_options"
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

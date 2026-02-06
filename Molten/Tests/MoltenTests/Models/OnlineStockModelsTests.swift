//
//  OnlineStockModelsTests.swift
//  MoltenTests
//
//  Tests for online stock availability models
//

import Foundation
import Testing

@testable import Molten

@Suite("OnlineStockModels Tests")
@MainActor
struct OnlineStockModelsTests {

    // MARK: - StockStatus Tests

    @Test("StockStatus decodes from JSON strings correctly")
    func testStockStatusDecoding() throws {
        let testCases: [(String, StockStatus)] = [
            ("\"in_stock\"", .inStock),
            ("\"out_of_stock\"", .outOfStock),
            ("\"low_stock\"", .lowStock),
            ("\"unknown\"", .unknown),
            ("\"not_carried\"", .notCarried)
        ]

        for (jsonString, expectedStatus) in testCases {
            let data = jsonString.data(using: .utf8)!
            let decoded = try JSONDecoder().decode(StockStatus.self, from: data)
            #expect(decoded == expectedStatus, "Expected \(expectedStatus) for \(jsonString)")
        }
    }

    @Test("StockStatus encodes to JSON strings correctly")
    func testStockStatusEncoding() throws {
        let testCases: [(StockStatus, String)] = [
            (.inStock, "\"in_stock\""),
            (.outOfStock, "\"out_of_stock\""),
            (.lowStock, "\"low_stock\""),
            (.unknown, "\"unknown\""),
            (.notCarried, "\"not_carried\"")
        ]

        for (status, expectedJson) in testCases {
            let data = try JSONEncoder().encode(status)
            let jsonString = String(data: data, encoding: .utf8)!
            #expect(jsonString == expectedJson, "Expected \(expectedJson) for \(status)")
        }
    }

    @Test("StockStatus displayText returns correct values")
    func testStockStatusDisplayText() {
        #expect(StockStatus.inStock.displayText == "In Stock")
        #expect(StockStatus.outOfStock.displayText == "Out of Stock")
        #expect(StockStatus.lowStock.displayText == "Low Stock")
        #expect(StockStatus.unknown.displayText == "Unknown")
        #expect(StockStatus.notCarried.displayText == "Not Carried")
    }

    @Test("StockStatus isAvailable returns true only for in_stock and low_stock")
    func testStockStatusIsAvailable() {
        #expect(StockStatus.inStock.isAvailable == true)
        #expect(StockStatus.lowStock.isAvailable == true)
        #expect(StockStatus.outOfStock.isAvailable == false)
        #expect(StockStatus.unknown.isAvailable == false)
        #expect(StockStatus.notCarried.isAvailable == false)
    }

    // MARK: - RetailerStockModel Tests

    @Test("RetailerStockModel decodes from JSON correctly")
    func testRetailerStockModelDecoding() throws {
        let json = """
        {
            "retailer_code": "bullseye",
            "retailer_name": "Bullseye Glass Co",
            "stock_status": "in_stock",
            "last_checked": "2025-02-05T10:30:00Z",
            "product_url": "https://bullseye.com/product/123",
            "price": 4.50,
            "price_unit": "rod",
            "currency": "USD",
            "quantity_available": 25
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let model = try decoder.decode(RetailerStockModel.self, from: json)

        #expect(model.retailerCode == "bullseye")
        #expect(model.retailerName == "Bullseye Glass Co")
        #expect(model.stockStatus == .inStock)
        #expect(model.productUrl == "https://bullseye.com/product/123")
        #expect(model.price == 4.50)
        #expect(model.priceUnit == "rod")
        #expect(model.currency == "USD")
        #expect(model.quantityAvailable == 25)
    }

    @Test("RetailerStockModel handles optional fields correctly")
    func testRetailerStockModelOptionalFields() throws {
        let json = """
        {
            "retailer_code": "frantz",
            "retailer_name": "Frantz Art Glass",
            "stock_status": "out_of_stock",
            "last_checked": "2025-02-05T10:30:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let model = try decoder.decode(RetailerStockModel.self, from: json)

        #expect(model.retailerCode == "frantz")
        #expect(model.retailerName == "Frantz Art Glass")
        #expect(model.stockStatus == .outOfStock)
        #expect(model.productUrl == nil)
        #expect(model.price == nil)
        #expect(model.priceUnit == nil)
        #expect(model.currency == nil)
        #expect(model.quantityAvailable == nil)
    }

    @Test("RetailerStockModel id returns retailerCode")
    func testRetailerStockModelId() {
        let model = createTestRetailerStock(retailerCode: "testcode")
        #expect(model.id == "testcode")
    }

    @Test("RetailerStockModel formattedPrice formats correctly with unit")
    func testFormattedPriceWithUnit() {
        let model = createTestRetailerStock(price: 4.50, priceUnit: "rod", currency: "USD")
        let formatted = model.formattedPrice

        #expect(formatted != nil)
        #expect(formatted!.contains("4.50") || formatted!.contains("4,50"))
        #expect(formatted!.contains("/rod"))
    }

    @Test("RetailerStockModel formattedPrice formats correctly without unit")
    func testFormattedPriceWithoutUnit() {
        let model = createTestRetailerStock(price: 12.99, priceUnit: nil, currency: "USD")
        let formatted = model.formattedPrice

        #expect(formatted != nil)
        #expect(formatted!.contains("12.99") || formatted!.contains("12,99"))
        #expect(!formatted!.contains("/"))
    }

    @Test("RetailerStockModel formattedPrice returns nil when price is nil")
    func testFormattedPriceNil() {
        let model = createTestRetailerStock(price: nil, priceUnit: nil, currency: nil)
        #expect(model.formattedPrice == nil)
    }

    @Test("RetailerStockModel formattedPrice handles different currencies")
    func testFormattedPriceDifferentCurrencies() {
        let eurModel = createTestRetailerStock(price: 10.00, priceUnit: nil, currency: "EUR")
        let eurFormatted = eurModel.formattedPrice
        #expect(eurFormatted != nil)
        // Currency symbol varies by locale, just check it's formatted
        #expect(eurFormatted!.contains("10") || eurFormatted!.contains("€"))
    }

    // MARK: - OnlineStockModel Tests

    @Test("OnlineStockModel decodes from JSON correctly")
    func testOnlineStockModelDecoding() throws {
        let json = """
        {
            "item_stable_id": "abc123",
            "retailers": [
                {
                    "retailer_code": "bullseye",
                    "retailer_name": "Bullseye Glass Co",
                    "stock_status": "in_stock",
                    "last_checked": "2025-02-05T10:30:00Z"
                },
                {
                    "retailer_code": "frantz",
                    "retailer_name": "Frantz Art Glass",
                    "stock_status": "out_of_stock",
                    "last_checked": "2025-02-05T10:30:00Z"
                }
            ],
            "last_updated": "2025-02-05T08:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let model = try decoder.decode(OnlineStockModel.self, from: json)

        #expect(model.itemStableId == "abc123")
        #expect(model.retailers.count == 2)
        #expect(model.retailers[0].retailerCode == "bullseye")
        #expect(model.retailers[1].retailerCode == "frantz")
    }

    @Test("OnlineStockModel anyInStock returns true when any retailer has stock")
    func testAnyInStockTrue() {
        let retailers = [
            createTestRetailerStock(retailerCode: "a", stockStatus: .outOfStock),
            createTestRetailerStock(retailerCode: "b", stockStatus: .inStock),
            createTestRetailerStock(retailerCode: "c", stockStatus: .unknown)
        ]
        let model = OnlineStockModel(itemStableId: "test", retailers: retailers, lastUpdated: Date())

        #expect(model.anyInStock == true)
    }

    @Test("OnlineStockModel anyInStock returns true for lowStock")
    func testAnyInStockTrueForLowStock() {
        let retailers = [
            createTestRetailerStock(retailerCode: "a", stockStatus: .outOfStock),
            createTestRetailerStock(retailerCode: "b", stockStatus: .lowStock)
        ]
        let model = OnlineStockModel(itemStableId: "test", retailers: retailers, lastUpdated: Date())

        #expect(model.anyInStock == true)
    }

    @Test("OnlineStockModel anyInStock returns false when no retailer has stock")
    func testAnyInStockFalse() {
        let retailers = [
            createTestRetailerStock(retailerCode: "a", stockStatus: .outOfStock),
            createTestRetailerStock(retailerCode: "b", stockStatus: .unknown),
            createTestRetailerStock(retailerCode: "c", stockStatus: .notCarried)
        ]
        let model = OnlineStockModel(itemStableId: "test", retailers: retailers, lastUpdated: Date())

        #expect(model.anyInStock == false)
    }

    @Test("OnlineStockModel inStockRetailers filters correctly")
    func testInStockRetailers() {
        let retailers = [
            createTestRetailerStock(retailerCode: "a", stockStatus: .inStock),
            createTestRetailerStock(retailerCode: "b", stockStatus: .outOfStock),
            createTestRetailerStock(retailerCode: "c", stockStatus: .lowStock),
            createTestRetailerStock(retailerCode: "d", stockStatus: .unknown)
        ]
        let model = OnlineStockModel(itemStableId: "test", retailers: retailers, lastUpdated: Date())

        let inStock = model.inStockRetailers
        #expect(inStock.count == 2)
        #expect(inStock.contains { $0.retailerCode == "a" })
        #expect(inStock.contains { $0.retailerCode == "c" })
    }

    @Test("OnlineStockModel inStockCount returns correct count")
    func testInStockCount() {
        let retailers = [
            createTestRetailerStock(retailerCode: "a", stockStatus: .inStock),
            createTestRetailerStock(retailerCode: "b", stockStatus: .outOfStock),
            createTestRetailerStock(retailerCode: "c", stockStatus: .inStock),
            createTestRetailerStock(retailerCode: "d", stockStatus: .lowStock)
        ]
        let model = OnlineStockModel(itemStableId: "test", retailers: retailers, lastUpdated: Date())

        #expect(model.inStockCount == 3)
    }

    @Test("OnlineStockModel handles empty retailers array")
    func testEmptyRetailers() {
        let model = OnlineStockModel(itemStableId: "test", retailers: [], lastUpdated: Date())

        #expect(model.anyInStock == false)
        #expect(model.inStockRetailers.isEmpty)
        #expect(model.inStockCount == 0)
    }

    // MARK: - Equatable Tests

    @Test("RetailerStockModel equality works correctly")
    func testRetailerStockModelEquality() {
        let model1 = createTestRetailerStock(retailerCode: "bullseye", stockStatus: .inStock)
        let model2 = createTestRetailerStock(retailerCode: "bullseye", stockStatus: .inStock)
        let model3 = createTestRetailerStock(retailerCode: "frantz", stockStatus: .inStock)

        #expect(model1 == model2)
        #expect(model1 != model3)
    }

    @Test("OnlineStockModel equality works correctly")
    func testOnlineStockModelEquality() {
        let date = Date()
        let retailers = [createTestRetailerStock(retailerCode: "test")]

        let model1 = OnlineStockModel(itemStableId: "abc", retailers: retailers, lastUpdated: date)
        let model2 = OnlineStockModel(itemStableId: "abc", retailers: retailers, lastUpdated: date)
        let model3 = OnlineStockModel(itemStableId: "xyz", retailers: retailers, lastUpdated: date)

        #expect(model1 == model2)
        #expect(model1 != model3)
    }

    // MARK: - Test Helpers

    func createTestRetailerStock(
        retailerCode: String = "test",
        retailerName: String = "Test Retailer",
        stockStatus: StockStatus = .inStock,
        productUrl: String? = nil,
        price: Decimal? = nil,
        priceUnit: String? = nil,
        currency: String? = nil,
        quantityAvailable: Int? = nil
    ) -> RetailerStockModel {
        return RetailerStockModel(
            retailerCode: retailerCode,
            retailerName: retailerName,
            stockStatus: stockStatus,
            lastChecked: Date(),
            productUrl: productUrl,
            price: price,
            priceUnit: priceUnit,
            currency: currency,
            quantityAvailable: quantityAvailable
        )
    }
}

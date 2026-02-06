//
//  OnlineStockAPIClientTests.swift
//  MoltenTests
//
//  Tests for online stock API client
//

import Foundation
import Testing

@testable import Molten

@Suite("OnlineStockAPIClient Tests")
@MainActor
struct OnlineStockAPIClientTests {

    // MARK: - Test Helpers

    func createTestStockResponse(itemStableId: String = "abc123") -> Data {
        let json = """
        {
            "item_stable_id": "\(itemStableId)",
            "retailers": [
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
        """
        return json.data(using: .utf8)!
    }

    func createBulkStockResponse(items: [String]) -> Data {
        let itemsJson = items.map { id in
            """
            {
                "item_stable_id": "\(id)",
                "retailers": [
                    {
                        "retailer_code": "bullseye",
                        "retailer_name": "Bullseye Glass Co",
                        "stock_status": "in_stock",
                        "last_checked": "2025-02-05T10:30:00Z"
                    }
                ],
                "last_updated": "2025-02-05T08:00:00Z"
            }
            """
        }.joined(separator: ",")

        let json = """
        {
            "items": [\(itemsJson)]
        }
        """
        return json.data(using: .utf8)!
    }

    // MARK: - Single Item Fetch Tests

    @Test("Fetch stock succeeds with 200 response")
    func testFetchStockSuccess() async throws {
        let responseData = createTestStockResponse(itemStableId: "test123")

        let mockSession = MockStockURLSession()
        mockSession.mockData = responseData
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://www.moltenglass.app/api/v1/stock/test123")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )

        let client = OnlineStockAPIClient(session: mockSession)
        let result = try await client.fetchStock(for: "test123")

        #expect(result.itemStableId == "test123")
        #expect(result.retailers.count == 2)
        #expect(result.retailers[0].retailerCode == "bullseye")
        #expect(result.retailers[0].stockStatus == .inStock)
        #expect(result.retailers[1].retailerCode == "frantz")
        #expect(result.retailers[1].stockStatus == .outOfStock)
    }

    @Test("Fetch stock handles 404 not found")
    func testFetchStock404() async throws {
        let mockSession = MockStockURLSession()
        mockSession.mockData = Data()
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://www.moltenglass.app/api/v1/stock/unknown")!,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        )

        let client = OnlineStockAPIClient(session: mockSession)

        await #expect(throws: OnlineStockAPIError.itemNotFound) {
            _ = try await client.fetchStock(for: "unknown")
        }
    }

    @Test("Fetch stock handles 500 server error")
    func testFetchStock500() async throws {
        let mockSession = MockStockURLSession()
        mockSession.mockData = Data()
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://www.moltenglass.app/api/v1/stock/test")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )

        let client = OnlineStockAPIClient(session: mockSession)

        do {
            _ = try await client.fetchStock(for: "test")
            Issue.record("Expected server error")
        } catch let error as OnlineStockAPIError {
            switch error {
            case .serverError(let statusCode):
                #expect(statusCode == 500)
            default:
                Issue.record("Expected serverError, got: \(error)")
            }
        }
    }

    @Test("Fetch stock handles network error")
    func testFetchStockNetworkError() async throws {
        let mockSession = MockStockURLSession()
        mockSession.mockError = URLError(.notConnectedToInternet)

        let client = OnlineStockAPIClient(session: mockSession)

        await #expect(throws: Error.self) {
            _ = try await client.fetchStock(for: "test")
        }
    }

    @Test("Fetch stock handles invalid JSON")
    func testFetchStockInvalidJSON() async throws {
        let mockSession = MockStockURLSession()
        mockSession.mockData = "{ invalid json }".data(using: .utf8)
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://www.moltenglass.app/api/v1/stock/test")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        let client = OnlineStockAPIClient(session: mockSession)

        await #expect(throws: OnlineStockAPIError.self) {
            _ = try await client.fetchStock(for: "test")
        }
    }

    @Test("Fetch stock uses correct URL path")
    func testFetchStockURLPath() async throws {
        let responseData = createTestStockResponse()

        let mockSession = MockStockURLSession()
        mockSession.mockData = responseData
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://www.moltenglass.app/api/v1/stock/myitem")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        let client = OnlineStockAPIClient(
            session: mockSession,
            baseURL: URL(string: "https://www.moltenglass.app")!
        )

        _ = try await client.fetchStock(for: "myitem")

        let request = try #require(mockSession.lastRequest)
        let url = try #require(request.url)
        #expect(url.path == "/api/v1/stock/myitem")
        #expect(request.httpMethod == "GET")
    }

    // MARK: - Bulk Fetch Tests

    @Test("Bulk fetch succeeds with 200 response")
    func testBulkFetchSuccess() async throws {
        let items = ["item1", "item2", "item3"]
        let responseData = createBulkStockResponse(items: items)

        let mockSession = MockStockURLSession()
        mockSession.mockData = responseData
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://www.moltenglass.app/api/v1/stock/bulk")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )

        let client = OnlineStockAPIClient(session: mockSession)
        let results = try await client.fetchStockBulk(for: items)

        #expect(results.count == 3)
        #expect(results[0].itemStableId == "item1")
        #expect(results[1].itemStableId == "item2")
        #expect(results[2].itemStableId == "item3")
    }

    @Test("Bulk fetch uses POST method with JSON body")
    func testBulkFetchUsesPost() async throws {
        let items = ["item1", "item2"]
        let responseData = createBulkStockResponse(items: items)

        let mockSession = MockStockURLSession()
        mockSession.mockData = responseData
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://www.moltenglass.app/api/v1/stock/bulk")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        let client = OnlineStockAPIClient(session: mockSession)
        _ = try await client.fetchStockBulk(for: items)

        let request = try #require(mockSession.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let url = try #require(request.url)
        #expect(url.path == "/api/v1/stock/bulk")

        // Verify body contains items
        let body = try #require(request.httpBody)
        let bodyJson = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let bodyItems = try #require(bodyJson?["items"] as? [String])
        #expect(bodyItems == items)
    }

    @Test("Bulk fetch handles server error")
    func testBulkFetchServerError() async throws {
        let mockSession = MockStockURLSession()
        mockSession.mockData = Data()
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://www.moltenglass.app/api/v1/stock/bulk")!,
            statusCode: 503,
            httpVersion: nil,
            headerFields: nil
        )

        let client = OnlineStockAPIClient(session: mockSession)

        do {
            _ = try await client.fetchStockBulk(for: ["item1"])
            Issue.record("Expected server error")
        } catch let error as OnlineStockAPIError {
            switch error {
            case .serverError(let statusCode):
                #expect(statusCode == 503)
            default:
                Issue.record("Expected serverError, got: \(error)")
            }
        }
    }

    // MARK: - Error Equality Tests

    @Test("OnlineStockAPIError equality works correctly")
    func testErrorEquality() {
        #expect(OnlineStockAPIError.invalidURL == OnlineStockAPIError.invalidURL)
        #expect(OnlineStockAPIError.invalidResponse == OnlineStockAPIError.invalidResponse)
        #expect(OnlineStockAPIError.itemNotFound == OnlineStockAPIError.itemNotFound)
        #expect(OnlineStockAPIError.serverError(statusCode: 500) == OnlineStockAPIError.serverError(statusCode: 500))
        #expect(OnlineStockAPIError.serverError(statusCode: 500) != OnlineStockAPIError.serverError(statusCode: 404))
        #expect(OnlineStockAPIError.networkError("test") == OnlineStockAPIError.networkError("test"))
        #expect(OnlineStockAPIError.networkError("a") != OnlineStockAPIError.networkError("b"))
        #expect(OnlineStockAPIError.decodingError("test") == OnlineStockAPIError.decodingError("test"))
    }

    @Test("OnlineStockAPIError provides correct descriptions")
    func testErrorDescriptions() {
        let invalidURL = OnlineStockAPIError.invalidURL
        #expect(invalidURL.errorDescription?.contains("Invalid") == true)

        let serverError = OnlineStockAPIError.serverError(statusCode: 429)
        #expect(serverError.errorDescription?.contains("429") == true)

        let notFound = OnlineStockAPIError.itemNotFound
        #expect(notFound.errorDescription?.contains("not found") == true)
    }
}

// MARK: - Mock URLSession

@MainActor
class MockStockURLSession: URLSessionProtocol {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?

    var lastRequest: URLRequest?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request

        if let error = mockError {
            throw error
        }

        guard let data = mockData, let response = mockResponse else {
            throw OnlineStockAPIError.invalidResponse
        }

        return (data, response)
    }

    func download(for request: URLRequest, delegate: URLSessionTaskDelegate?) async throws -> (URL, URLResponse) {
        // Not used for stock API, but required by protocol
        throw OnlineStockAPIError.invalidResponse
    }
}

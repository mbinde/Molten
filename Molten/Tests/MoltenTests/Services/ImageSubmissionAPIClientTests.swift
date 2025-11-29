//
//  ImageSubmissionAPIClientTests.swift
//  MoltenTests
//
//  Tests for ImageSubmissionAPIClient
//

import Testing
import Foundation
@testable import Molten

@Suite("ImageSubmissionAPIClient Tests")
@MainActor
struct ImageSubmissionAPIClientTests {

    // MARK: - Mock URLSession

    class MockURLSession: URLSessionProtocol {
        var mockData: Data?
        var mockResponse: URLResponse?
        var mockError: Error?

        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            if let error = mockError {
                throw error
            }
            return (mockData ?? Data(), mockResponse ?? HTTPURLResponse())
        }

        func download(for request: URLRequest, delegate: URLSessionTaskDelegate?) async throws -> (URL, URLResponse) {
            // Not used for image submission tests
            throw URLError(.unsupportedURL)
        }
    }

    // MARK: - Mock AttestationManager

    class MockAttestationManager: AttestationManagerProtocol {
        var isSupported: Bool = false

        func generateAssertion(requestData: Data) async throws -> Data {
            throw AttestationError.noKeyExists
        }

        func createRequestData(method: String, path: String, body: Data?) -> Data {
            return Data()
        }
    }

    // MARK: - Tests

    @Test("Should return submission ID on success")
    func testSuccessfulSubmission() async throws {
        let mockSession = MockURLSession()
        let responseData = """
        {
            "success": true,
            "submissionId": "test-uuid-12345"
        }
        """.data(using: .utf8)!

        mockSession.mockData = responseData
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://www.moltenglass.app/api/v1/submit-image")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        let client = ImageSubmissionAPIClient(
            session: mockSession,
            baseURL: URL(string: "https://www.moltenglass.app")!,
            attestationManager: MockAttestationManager()
        )

        let testItem = GlassItemModel(
            stable_id: "bullseye-0001-0",
            name: "Bullseye Red Opal",
            sku: "0001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )

        let result = try await client.submitImage(
            image: Data([0x00, 0x01, 0x02]), // Dummy data
            glassItem: testItem,
            email: "test@example.com",
            hasPermission: true,
            offersFreeOfCharge: true
        )

        #expect(result.submissionId == "test-uuid-12345")
    }

    @Test("Should throw error for terms not accepted")
    func testTermsNotAccepted() async throws {
        let mockSession = MockURLSession()
        let client = ImageSubmissionAPIClient(
            session: mockSession,
            baseURL: URL(string: "https://www.moltenglass.app")!,
            attestationManager: MockAttestationManager()
        )

        let testItem = GlassItemModel(
            stable_id: "bullseye-0001-0",
            name: "Bullseye Red Opal",
            sku: "0001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )

        do {
            _ = try await client.submitImage(
                image: Data([0x00]),
                glassItem: testItem,
                email: "test@example.com",
                hasPermission: false,
                offersFreeOfCharge: true
            )
            Issue.record("Should have thrown error")
        } catch let error as ImageSubmissionError {
            if case .termsNotAccepted = error {
                // Expected
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    @Test("Should throw rate limit error on 429")
    func testRateLimitExceeded() async throws {
        let mockSession = MockURLSession()
        let responseData = """
        {
            "success": false,
            "error": "Daily submission limit exceeded",
            "resetAt": "2025-01-01T00:00:00.000Z"
        }
        """.data(using: .utf8)!

        mockSession.mockData = responseData
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://www.moltenglass.app/api/v1/submit-image")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: nil
        )

        let client = ImageSubmissionAPIClient(
            session: mockSession,
            baseURL: URL(string: "https://www.moltenglass.app")!,
            attestationManager: MockAttestationManager()
        )

        let testItem = GlassItemModel(
            stable_id: "bullseye-0001-0",
            name: "Bullseye Red Opal",
            sku: "0001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )

        do {
            _ = try await client.submitImage(
                image: Data([0x00]),
                glassItem: testItem,
                email: "test@example.com",
                hasPermission: true,
                offersFreeOfCharge: true
            )
            Issue.record("Should have thrown error")
        } catch let error as ImageSubmissionError {
            if case .rateLimitExceeded = error {
                // Expected
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    @Test("Should throw error for oversized image")
    func testImageTooLarge() async throws {
        let mockSession = MockURLSession()
        let client = ImageSubmissionAPIClient(
            session: mockSession,
            baseURL: URL(string: "https://www.moltenglass.app")!,
            attestationManager: MockAttestationManager()
        )

        let testItem = GlassItemModel(
            stable_id: "bullseye-0001-0",
            name: "Bullseye Red Opal",
            sku: "0001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )

        // Create 6MB of data (over the 5MB limit)
        let largeData = Data(repeating: 0x00, count: 6 * 1024 * 1024)

        do {
            _ = try await client.submitImage(
                image: largeData,
                glassItem: testItem,
                email: "test@example.com",
                hasPermission: true,
                offersFreeOfCharge: true
            )
            Issue.record("Should have thrown error")
        } catch let error as ImageSubmissionError {
            if case .imageTooLarge(let maxMB) = error {
                #expect(maxMB == 5)
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    @Test("Should handle server error responses")
    func testServerError() async throws {
        let mockSession = MockURLSession()
        let responseData = """
        {
            "success": false,
            "error": "Invalid glass item data"
        }
        """.data(using: .utf8)!

        mockSession.mockData = responseData
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://www.moltenglass.app/api/v1/submit-image")!,
            statusCode: 400,
            httpVersion: nil,
            headerFields: nil
        )

        let client = ImageSubmissionAPIClient(
            session: mockSession,
            baseURL: URL(string: "https://www.moltenglass.app")!,
            attestationManager: MockAttestationManager()
        )

        let testItem = GlassItemModel(
            stable_id: "bullseye-0001-0",
            name: "Bullseye Red Opal",
            sku: "0001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )

        do {
            _ = try await client.submitImage(
                image: Data([0x00]),
                glassItem: testItem,
                email: "test@example.com",
                hasPermission: true,
                offersFreeOfCharge: true
            )
            Issue.record("Should have thrown error")
        } catch let error as ImageSubmissionError {
            if case .serverError(let message) = error {
                #expect(message == "Invalid glass item data")
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }
}

// MARK: - Mock ImageSubmissionAPIClient for View Tests

/// Mock API client for testing views that use ImageSubmissionAPIClient
@MainActor
class MockImageSubmissionAPIClient: ImageSubmissionAPIClientProtocol {
    var mockResult: Result<ImageSubmissionResponse, ImageSubmissionError> = .success(ImageSubmissionResponse(submissionId: "mock-id"))
    var submitImageCallCount = 0
    var lastSubmittedEmail: String?
    var lastSubmittedGlassItem: GlassItemModel?

    func submitImage(
        image: Data,
        glassItem: GlassItemModel,
        email: String,
        hasPermission: Bool,
        offersFreeOfCharge: Bool
    ) async throws -> ImageSubmissionResponse {
        submitImageCallCount += 1
        lastSubmittedEmail = email
        lastSubmittedGlassItem = glassItem

        switch mockResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }
}

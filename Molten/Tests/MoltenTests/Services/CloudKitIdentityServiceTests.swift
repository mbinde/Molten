//
//  CloudKitIdentityServiceTests.swift
//  MoltenTests
//
//  Created by TDD for rating system on 11/13/25.
//

import XCTest
import CloudKit
@testable import Molten

final class CloudKitIdentityServiceTests: XCTestCase {

    // MARK: - Mock CloudKit Container

    class MockCKContainer: CKContainerProtocol {
        var shouldFail = false
        var mockUserRecordID: CKRecord.ID?

        func fetchUserRecordID() async throws -> CKRecord.ID {
            if shouldFail {
                throw NSError(domain: CKErrorDomain, code: CKError.networkUnavailable.rawValue)
            }
            return mockUserRecordID ?? CKRecord.ID(recordName: "test-user-id")
        }
    }

    // MARK: - Tests

    func testGetHashedUserID_Success_ReturnsHashedID() async throws {
        // Given
        let mockContainer = MockCKContainer()
        mockContainer.mockUserRecordID = CKRecord.ID(recordName: "unique-user-123")
        let service = CloudKitIdentityService(container: mockContainer)

        // When
        let hashedID = try await service.getHashedUserID()

        // Then
        XCTAssertFalse(hashedID.isEmpty)
        XCTAssertNotEqual(hashedID, "unique-user-123") // Should be hashed, not plain text
        XCTAssertEqual(hashedID.count, 64) // SHA-256 produces 64 hex characters
    }

    func testGetHashedUserID_CalledTwice_ReturnsSameHash() async throws {
        // Given
        let mockContainer = MockCKContainer()
        mockContainer.mockUserRecordID = CKRecord.ID(recordName: "unique-user-123")
        let service = CloudKitIdentityService(container: mockContainer)

        // When
        let hashedID1 = try await service.getHashedUserID()
        let hashedID2 = try await service.getHashedUserID()

        // Then
        XCTAssertEqual(hashedID1, hashedID2)
    }

    func testGetHashedUserID_DifferentUsers_ReturnsDifferentHashes() async throws {
        // Given
        let mockContainer1 = MockCKContainer()
        mockContainer1.mockUserRecordID = CKRecord.ID(recordName: "user-1")
        let service1 = CloudKitIdentityService(container: mockContainer1)

        let mockContainer2 = MockCKContainer()
        mockContainer2.mockUserRecordID = CKRecord.ID(recordName: "user-2")
        let service2 = CloudKitIdentityService(container: mockContainer2)

        // When
        let hashedID1 = try await service1.getHashedUserID()
        let hashedID2 = try await service2.getHashedUserID()

        // Then
        XCTAssertNotEqual(hashedID1, hashedID2)
    }

    func testGetHashedUserID_NetworkError_ThrowsError() async {
        // Given
        let mockContainer = MockCKContainer()
        mockContainer.shouldFail = true
        let service = CloudKitIdentityService(container: mockContainer)

        // When/Then
        do {
            _ = try await service.getHashedUserID()
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    func testGetHashedUserID_CachesResult() async throws {
        // Given
        let mockContainer = MockCKContainer()
        mockContainer.mockUserRecordID = CKRecord.ID(recordName: "user-123")
        let service = CloudKitIdentityService(container: mockContainer)

        // When
        let hashedID1 = try await service.getHashedUserID()

        // Simulate container changing (shouldn't affect cached result)
        mockContainer.mockUserRecordID = CKRecord.ID(recordName: "different-user")

        let hashedID2 = try await service.getHashedUserID()

        // Then
        XCTAssertEqual(hashedID1, hashedID2) // Should return cached value
    }

    func testClearCache_AllowsRefresh() async throws {
        // Given
        let mockContainer = MockCKContainer()
        mockContainer.mockUserRecordID = CKRecord.ID(recordName: "user-123")
        let service = CloudKitIdentityService(container: mockContainer)

        let hashedID1 = try await service.getHashedUserID()

        // When
        service.clearCache()
        mockContainer.mockUserRecordID = CKRecord.ID(recordName: "different-user")
        let hashedID2 = try await service.getHashedUserID()

        // Then
        XCTAssertNotEqual(hashedID1, hashedID2)
    }

    func testIsAvailable_WithValidContainer_ReturnsTrue() {
        // Given
        let mockContainer = MockCKContainer()
        let service = CloudKitIdentityService(container: mockContainer)

        // When/Then
        XCTAssertTrue(service.isAvailable)
    }
}

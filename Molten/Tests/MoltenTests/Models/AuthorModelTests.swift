//
//  AuthorModelTests.swift
//  MoltenTests
//
//  Unit tests for AuthorModel struct
//

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import Foundation
@testable import Molten

@Suite("AuthorModel Tests")
struct AuthorModelTests {

    // MARK: - Initialization Tests

    @Test("Default initialization creates empty author")
    func testDefaultInit() {
        let author = AuthorModel()

        #expect(author.name == nil)
        #expect(author.email == nil)
        #expect(author.website == nil)
        #expect(author.instagram == nil)
        #expect(author.facebook == nil)
        #expect(author.youtube == nil)
        #expect(author.dateAdded != nil)
    }

    @Test("Initialization with all fields")
    func testFullInit() {
        let date = Date()
        let author = AuthorModel(
            name: "Jane Smith",
            email: "jane@example.com",
            website: "https://janesmith.com",
            instagram: "@janesmith",
            facebook: "janesmith",
            youtube: "@janesmithglass",
            dateAdded: date
        )

        #expect(author.name == "Jane Smith")
        #expect(author.email == "jane@example.com")
        #expect(author.website == "https://janesmith.com")
        #expect(author.instagram == "@janesmith")
        #expect(author.facebook == "janesmith")
        #expect(author.youtube == "@janesmithglass")
        #expect(author.dateAdded == date)
    }

    @Test("Partial initialization")
    func testPartialInit() {
        let author = AuthorModel(
            name: "John Doe",
            email: "john@example.com"
        )

        #expect(author.name == "John Doe")
        #expect(author.email == "john@example.com")
        #expect(author.website == nil)
        #expect(author.instagram == nil)
        #expect(author.facebook == nil)
        #expect(author.youtube == nil)
    }

    // MARK: - hasAnyInfo Tests

    @Test("hasAnyInfo returns false when all fields are nil")
    func testHasAnyInfoAllNil() {
        let author = AuthorModel()

        #expect(author.hasAnyInfo == false)
    }

    @Test("hasAnyInfo returns true when name is set")
    func testHasAnyInfoWithName() {
        let author = AuthorModel(name: "Jane Smith")

        #expect(author.hasAnyInfo == true)
    }

    @Test("hasAnyInfo returns true when email is set")
    func testHasAnyInfoWithEmail() {
        let author = AuthorModel(email: "jane@example.com")

        #expect(author.hasAnyInfo == true)
    }

    @Test("hasAnyInfo returns true when website is set")
    func testHasAnyInfoWithWebsite() {
        let author = AuthorModel(website: "https://example.com")

        #expect(author.hasAnyInfo == true)
    }

    @Test("hasAnyInfo returns true when instagram is set")
    func testHasAnyInfoWithInstagram() {
        let author = AuthorModel(instagram: "@janesmith")

        #expect(author.hasAnyInfo == true)
    }

    @Test("hasAnyInfo returns true when facebook is set")
    func testHasAnyInfoWithFacebook() {
        let author = AuthorModel(facebook: "janesmith")

        #expect(author.hasAnyInfo == true)
    }

    @Test("hasAnyInfo returns true when youtube is set")
    func testHasAnyInfoWithYoutube() {
        let author = AuthorModel(youtube: "@janesmithglass")

        #expect(author.hasAnyInfo == true)
    }

    // MARK: - displayName Tests

    @Test("displayName returns name when set")
    func testDisplayNameWithName() {
        let author = AuthorModel(name: "Jane Smith")

        #expect(author.displayName == "Jane Smith")
    }

    @Test("displayName returns 'Anonymous' when name is nil")
    func testDisplayNameAnonymous() {
        let author = AuthorModel()

        #expect(author.displayName == "Anonymous")
    }

    @Test("displayName returns 'Anonymous' even when other fields are set")
    func testDisplayNameAnonymousWithOtherFields() {
        let author = AuthorModel(
            email: "unknown@example.com",
            website: "https://example.com"
        )

        #expect(author.displayName == "Anonymous")
    }

    // MARK: - Codable Tests

    @Test("AuthorModel can be encoded to JSON")
    func testEncodingToJSON() throws {
        let author = AuthorModel(
            name: "Jane Smith",
            email: "jane@example.com",
            website: "https://janesmith.com"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(author)

        #expect(data.count > 0)

        // Verify JSON contains expected fields
        let jsonString = String(data: data, encoding: .utf8)
        #expect(jsonString?.contains("Jane Smith") == true)
        #expect(jsonString?.contains("jane@example.com") == true)
    }

    @Test("AuthorModel can be decoded from JSON")
    func testDecodingFromJSON() throws {
        let json = """
        {
            "name": "John Doe",
            "email": "john@example.com",
            "website": "https://johndoe.com",
            "instagram": "@johndoe",
            "dateAdded": 704246400.0
        }
        """

        let decoder = JSONDecoder()
        let data = json.data(using: .utf8)!
        let author = try decoder.decode(AuthorModel.self, from: data)

        #expect(author.name == "John Doe")
        #expect(author.email == "john@example.com")
        #expect(author.website == "https://johndoe.com")
        #expect(author.instagram == "@johndoe")
        #expect(author.facebook == nil)
        #expect(author.youtube == nil)
    }

    @Test("AuthorModel round-trip encoding/decoding")
    func testRoundTripCoding() throws {
        let original = AuthorModel(
            name: "Jane Smith",
            email: "jane@example.com",
            website: "https://janesmith.com",
            instagram: "@janesmith",
            facebook: "janesmith",
            youtube: "@janesmithglass"
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AuthorModel.self, from: data)

        #expect(decoded.name == original.name)
        #expect(decoded.email == original.email)
        #expect(decoded.website == original.website)
        #expect(decoded.instagram == original.instagram)
        #expect(decoded.facebook == original.facebook)
        #expect(decoded.youtube == original.youtube)
        // Note: dateAdded comparison might have slight precision differences
    }

    @Test("AuthorModel handles nil fields in JSON")
    func testDecodingWithNilFields() throws {
        let json = """
        {
            "name": "Minimal Author",
            "dateAdded": 704246400.0
        }
        """

        let decoder = JSONDecoder()
        let data = json.data(using: .utf8)!
        let author = try decoder.decode(AuthorModel.self, from: data)

        #expect(author.name == "Minimal Author")
        #expect(author.email == nil)
        #expect(author.website == nil)
        #expect(author.instagram == nil)
        #expect(author.facebook == nil)
        #expect(author.youtube == nil)
    }

    // MARK: - Hashable Tests

    @Test("Authors with same data are equal")
    func testEqualityWithSameData() {
        let date = Date()
        let author1 = AuthorModel(
            name: "Jane Smith",
            email: "jane@example.com",
            dateAdded: date
        )
        let author2 = AuthorModel(
            name: "Jane Smith",
            email: "jane@example.com",
            dateAdded: date
        )

        #expect(author1 == author2)
    }

    @Test("Authors with different names are not equal")
    func testInequalityDifferentNames() {
        let author1 = AuthorModel(name: "Jane Smith")
        let author2 = AuthorModel(name: "John Doe")

        #expect(author1 != author2)
    }

    @Test("Authors with different emails are not equal")
    func testInequalityDifferentEmails() {
        let author1 = AuthorModel(
            name: "Jane Smith",
            email: "jane@example.com"
        )
        let author2 = AuthorModel(
            name: "Jane Smith",
            email: "jane.smith@example.com"
        )

        #expect(author1 != author2)
    }

    @Test("Author can be used in Set")
    func testUsageInSet() {
        let author1 = AuthorModel(name: "Jane Smith")
        let author2 = AuthorModel(name: "John Doe")
        let author3 = AuthorModel(name: "Jane Smith") // Duplicate

        let set: Set<AuthorModel> = [author1, author2, author3]

        // Set should contain 2 unique authors
        #expect(set.count == 2)
        #expect(set.contains(author1))
        #expect(set.contains(author2))
    }

    // MARK: - Edge Cases

    @Test("Empty string fields (edge case)")
    func testEmptyStringFields() {
        // Note: Model doesn't trim or convert empty strings to nil
        // This tests current behavior
        let author = AuthorModel(
            name: "",
            email: "",
            website: ""
        )

        #expect(author.name == "")
        #expect(author.email == "")
        #expect(author.website == "")
        #expect(author.displayName == "Anonymous") // Empty string is falsy
    }

    @Test("Very long field values")
    func testLongFieldValues() {
        let longName = String(repeating: "A", count: 1000)
        let author = AuthorModel(name: longName)

        #expect(author.name?.count == 1000)
        #expect(author.displayName.count == 1000)
    }

    @Test("Special characters in fields")
    func testSpecialCharacters() {
        let author = AuthorModel(
            name: "Jäne Smîth-O'Connör",
            email: "jane+test@example.com",
            website: "https://example.com/~jane?id=123&ref=test",
            instagram: "@jane_smith.glass",
            facebook: "jane.smith.glass.2023",
            youtube: "@JaneSmithGlass-Official"
        )

        #expect(author.name == "Jäne Smîth-O'Connör")
        #expect(author.email == "jane+test@example.com")
        #expect(author.website == "https://example.com/~jane?id=123&ref=test")
        #expect(author.instagram == "@jane_smith.glass")
        #expect(author.facebook == "jane.smith.glass.2023")
        #expect(author.youtube == "@JaneSmithGlass-Official")
    }

    @Test("Date preservation in round-trip")
    func testDatePreservation() throws {
        let specificDate = Date(timeIntervalSince1970: 1704067200) // 2024-01-01 00:00:00 UTC
        let author = AuthorModel(
            name: "Test Author",
            dateAdded: specificDate
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(author)
        let decoded = try decoder.decode(AuthorModel.self, from: data)

        // Compare timestamps (allows for small floating-point differences)
        let diff = abs(decoded.dateAdded.timeIntervalSince1970 - specificDate.timeIntervalSince1970)
        #expect(diff < 0.001)
    }

    // MARK: - Sendable Conformance

    @Test("AuthorModel is Sendable")
    func testSendableConformance() {
        let author = AuthorModel(name: "Jane Smith")

        // This test verifies compile-time Sendable conformance
        // If it compiles, the conformance is correct
        let _: any Sendable = author
        #expect(true)
    }
}

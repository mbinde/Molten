//
//  ProjectReferenceUrlTests.swift
//  FlameworkerTests
//
//  Tests for ProjectReferenceUrl model (tutorial/inspiration URLs)
//

import Foundation
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Flameworker

@Suite("ProjectReferenceUrl Tests")
struct ProjectReferenceUrlTests {

    @Test("Initialize with all properties")
    func testInitialization() {
        let dateAdded = Date()
        let ref = ProjectReferenceUrl(
            id: UUID(),
            url: "https://youtube.com/watch?v=123",
            title: "Boro Fish Tutorial",
            description: "Great beginner tutorial",
            dateAdded: dateAdded
        )

        #expect(ref.url == "https://youtube.com/watch?v=123")
        #expect(ref.title == "Boro Fish Tutorial")
        #expect(ref.description == "Great beginner tutorial")
        #expect(ref.dateAdded == dateAdded)
    }

    @Test("Initialize with defaults")
    func testDefaultInitialization() {
        let ref = ProjectReferenceUrl(url: "https://example.com")

        #expect(ref.url == "https://example.com")
        #expect(ref.title == nil)
        #expect(ref.description == nil)
        // dateAdded should be recent (within last second)
        #expect(Date().timeIntervalSince(ref.dateAdded) < 1.0)
    }

    @Test("Codable encode and decode")
    func testCodable() throws {
        let original = ProjectReferenceUrl(
            id: UUID(),
            url: "https://glassartblog.com/technique",
            title: "Surface Decoration",
            description: "Advanced techniques for surface work"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ProjectReferenceUrl.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.url == original.url)
        #expect(decoded.title == original.title)
        #expect(decoded.description == original.description)
    }

    @Test("Codable with array of URLs")
    func testCodableArray() throws {
        let urls = [
            ProjectReferenceUrl(url: "https://example1.com", title: "Tutorial 1"),
            ProjectReferenceUrl(url: "https://example2.com", title: "Tutorial 2"),
            ProjectReferenceUrl(url: "https://example3.com", description: "Inspiration")
        ]

        let encoder = JSONEncoder()
        let data = try encoder.encode(urls)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode([ProjectReferenceUrl].self, from: data)

        #expect(decoded.count == 3)
        #expect(decoded[0].title == "Tutorial 1")
        #expect(decoded[1].title == "Tutorial 2")
        #expect(decoded[2].description == "Inspiration")
    }

    @Test("Identifiable protocol conformance")
    func testIdentifiable() {
        let ref1 = ProjectReferenceUrl(url: "https://example.com")
        let ref2 = ProjectReferenceUrl(url: "https://example.com")

        // Each URL should have a unique ID
        #expect(ref1.id != ref2.id)
    }

    @Test("Different URL formats")
    func testDifferentUrlFormats() {
        let youtube = ProjectReferenceUrl(url: "https://youtube.com/watch?v=abc123")
        let blog = ProjectReferenceUrl(url: "https://glassartblog.com/post/123")
        let pinterest = ProjectReferenceUrl(url: "https://pinterest.com/pin/456")

        #expect(youtube.url.contains("youtube"))
        #expect(blog.url.contains("blog"))
        #expect(pinterest.url.contains("pinterest"))
    }

    @Test("Optional fields can be nil")
    func testOptionalFields() {
        let ref = ProjectReferenceUrl(url: "https://example.com")

        #expect(ref.title == nil)
        #expect(ref.description == nil)
    }

    @Test("Both optional fields can be set")
    func testBothOptionalFieldsSet() {
        let ref = ProjectReferenceUrl(
            url: "https://example.com",
            title: "Title",
            description: "Description"
        )

        #expect(ref.title == "Title")
        #expect(ref.description == "Description")
    }
}

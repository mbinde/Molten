//
//  ToolItemRepositoryTests.swift
//  MoltenTests
//
//  Unit tests for ToolItemRepository (Mock implementation)
//

import Testing
import Foundation
@testable import Molten

@Suite("ToolItemRepository Tests")
struct ToolItemRepositoryTests {

    // MARK: - Basic CRUD Tests

    @Test("Create and fetch tool item by stable ID")
    func testCreateAndFetchByStableId() async throws {
        let repository = MockToolItemRepository()

        let tool = ToolItemModel(
            stable_id: "abc123",
            name: "Torch",
            sku: "T001",
            manufacturer: "Ronson",
            mfr_status: "available"
        )

        let created = try await repository.createItem(tool)
        #expect(created.stable_id == "abc123")
        #expect(created.name == "Torch")

        let fetched = try await repository.fetchItem(byStableId: "abc123")
        #expect(fetched != nil)
        #expect(fetched?.name == "Torch")
        #expect(fetched?.manufacturer == "Ronson")
        #expect(fetched?.sku == "T001")
    }

    @Test("Fetch non-existent tool returns nil")
    func testFetchNonExistentTool() async throws {
        let repository = MockToolItemRepository()

        let fetched = try await repository.fetchItem(byStableId: "nonexistent")
        #expect(fetched == nil)
    }

    @Test("Update existing tool item")
    func testUpdateToolItem() async throws {
        let repository = MockToolItemRepository()

        let original = ToolItemModel(
            stable_id: "xyz789",
            name: "Pliers",
            sku: "P001",
            manufacturer: "GlassCraft",
            mfr_status: "available"
        )

        _ = try await repository.createItem(original)

        let updated = ToolItemModel(
            stable_id: "xyz789",
            name: "Updated Pliers",
            sku: "P001",
            manufacturer: "GlassCraft",
            mfr_notes: "Updated notes",
            mfr_status: "discontinued"
        )

        let result = try await repository.updateItem(updated)
        #expect(result.name == "Updated Pliers")
        #expect(result.mfr_status == "discontinued")
        #expect(result.mfr_notes == "Updated notes")

        let fetched = try await repository.fetchItem(byStableId: "xyz789")
        #expect(fetched?.name == "Updated Pliers")
    }

    @Test("Delete tool item by stable ID")
    func testDeleteToolItem() async throws {
        let repository = MockToolItemRepository()

        let tool = ToolItemModel(
            stable_id: "del123",
            name: "Temp Tool",
            sku: nil,
            manufacturer: "TestMfr",
            mfr_status: "available"
        )

        _ = try await repository.createItem(tool)

        try await repository.deleteItem(stableId: "del123")

        let fetched = try await repository.fetchItem(byStableId: "del123")
        #expect(fetched == nil)
    }

    @Test("Create multiple tools in batch")
    func testCreateMultipleTools() async throws {
        let repository = MockToolItemRepository()

        let tools = [
            ToolItemModel(stable_id: "t1", name: "Tool 1", sku: "T1", manufacturer: "Mfr1", mfr_status: "available"),
            ToolItemModel(stable_id: "t2", name: "Tool 2", sku: "T2", manufacturer: "Mfr2", mfr_status: "available"),
            ToolItemModel(stable_id: "t3", name: "Tool 3", sku: "T3", manufacturer: "Mfr1", mfr_status: "discontinued")
        ]

        let created = try await repository.createItems(tools)
        #expect(created.count == 3)

        let fetched = try await repository.fetchItems(matching: nil)
        #expect(fetched.count == 3)
    }

    @Test("Delete multiple tools by stable IDs")
    func testDeleteMultipleTools() async throws {
        let repository = MockToolItemRepository()

        let tools = [
            ToolItemModel(stable_id: "d1", name: "Tool 1", sku: nil, manufacturer: "Mfr1", mfr_status: "available"),
            ToolItemModel(stable_id: "d2", name: "Tool 2", sku: nil, manufacturer: "Mfr2", mfr_status: "available"),
            ToolItemModel(stable_id: "d3", name: "Tool 3", sku: nil, manufacturer: "Mfr1", mfr_status: "available")
        ]

        _ = try await repository.createItems(tools)

        try await repository.deleteItems(stableIds: ["d1", "d3"])

        let remaining = try await repository.fetchItems(matching: nil)
        #expect(remaining.count == 1)
        #expect(remaining.first?.stable_id == "d2")
    }

    // MARK: - Search & Filter Tests

    @Test("Search tools by text")
    func testSearchToolsByText() async throws {
        let repository = MockToolItemRepository()

        let tools = [
            ToolItemModel(stable_id: "s1", name: "Diamond Torch", sku: nil, manufacturer: "Ronson", mfr_status: "available"),
            ToolItemModel(stable_id: "s2", name: "Pliers Set", sku: nil, manufacturer: "GlassCraft", mfr_status: "available"),
            ToolItemModel(stable_id: "s3", name: "Torch Lighter", sku: nil, manufacturer: "Ronson", mfr_status: "available")
        ]

        _ = try await repository.createItems(tools)

        let results = try await repository.searchItems(text: "torch")
        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.name.lowercased().contains("torch") })
    }

    @Test("Fetch tools by manufacturer")
    func testFetchToolsByManufacturer() async throws {
        let repository = MockToolItemRepository()

        let tools = [
            ToolItemModel(stable_id: "m1", name: "Tool 1", sku: nil, manufacturer: "Ronson", mfr_status: "available"),
            ToolItemModel(stable_id: "m2", name: "Tool 2", sku: nil, manufacturer: "GlassCraft", mfr_status: "available"),
            ToolItemModel(stable_id: "m3", name: "Tool 3", sku: nil, manufacturer: "Ronson", mfr_status: "available")
        ]

        _ = try await repository.createItems(tools)

        let ronsonTools = try await repository.fetchItems(byManufacturer: "Ronson")
        #expect(ronsonTools.count == 2)
        #expect(ronsonTools.allSatisfy { $0.manufacturer == "Ronson" })
    }

    @Test("Fetch tools by status")
    func testFetchToolsByStatus() async throws {
        let repository = MockToolItemRepository()

        let tools = [
            ToolItemModel(stable_id: "st1", name: "Tool 1", sku: nil, manufacturer: "Mfr1", mfr_status: "available"),
            ToolItemModel(stable_id: "st2", name: "Tool 2", sku: nil, manufacturer: "Mfr2", mfr_status: "discontinued"),
            ToolItemModel(stable_id: "st3", name: "Tool 3", sku: nil, manufacturer: "Mfr3", mfr_status: "available")
        ]

        _ = try await repository.createItems(tools)

        let available = try await repository.fetchItems(byStatus: "available")
        #expect(available.count == 2)
        #expect(available.allSatisfy { $0.mfr_status == "available" })

        let discontinued = try await repository.fetchItems(byStatus: "discontinued")
        #expect(discontinued.count == 1)
        #expect(discontinued.first?.stable_id == "st2")
    }

    // MARK: - Business Query Tests

    @Test("Get distinct manufacturers")
    func testGetDistinctManufacturers() async throws {
        let repository = MockToolItemRepository()

        let tools = [
            ToolItemModel(stable_id: "dm1", name: "Tool 1", sku: nil, manufacturer: "Ronson", mfr_status: "available"),
            ToolItemModel(stable_id: "dm2", name: "Tool 2", sku: nil, manufacturer: "GlassCraft", mfr_status: "available"),
            ToolItemModel(stable_id: "dm3", name: "Tool 3", sku: nil, manufacturer: "Ronson", mfr_status: "available"),
            ToolItemModel(stable_id: "dm4", name: "Tool 4", sku: nil, manufacturer: "ToolCo", mfr_status: "available")
        ]

        _ = try await repository.createItems(tools)

        let manufacturers = try await repository.getDistinctManufacturers()
        #expect(manufacturers.count == 3)
        #expect(manufacturers.contains("Ronson"))
        #expect(manufacturers.contains("GlassCraft"))
        #expect(manufacturers.contains("ToolCo"))
    }

    @Test("Get distinct statuses")
    func testGetDistinctStatuses() async throws {
        let repository = MockToolItemRepository()

        let tools = [
            ToolItemModel(stable_id: "ds1", name: "Tool 1", sku: nil, manufacturer: "Mfr1", mfr_status: "available"),
            ToolItemModel(stable_id: "ds2", name: "Tool 2", sku: nil, manufacturer: "Mfr2", mfr_status: "discontinued"),
            ToolItemModel(stable_id: "ds3", name: "Tool 3", sku: nil, manufacturer: "Mfr3", mfr_status: "available"),
            ToolItemModel(stable_id: "ds4", name: "Tool 4", sku: nil, manufacturer: "Mfr4", mfr_status: "pending")
        ]

        _ = try await repository.createItems(tools)

        let statuses = try await repository.getDistinctStatuses()
        #expect(statuses.count == 3)
        #expect(statuses.contains("available"))
        #expect(statuses.contains("discontinued"))
        #expect(statuses.contains("pending"))
    }

    @Test("Check if stable ID exists")
    func testStableIdExists() async throws {
        let repository = MockToolItemRepository()

        let tool = ToolItemModel(
            stable_id: "exists",
            name: "Test Tool",
            sku: nil,
            manufacturer: "TestMfr",
            mfr_status: "available"
        )

        _ = try await repository.createItem(tool)

        let exists = try await repository.stableIdExists("exists")
        #expect(exists == true)

        let notExists = try await repository.stableIdExists("notexists")
        #expect(notExists == false)
    }

    @Test("Generate next natural key")
    func testGenerateNextNaturalKey() async throws {
        let repository = MockToolItemRepository()

        let key1 = try await repository.generateNextNaturalKey(manufacturer: "Ronson", sku: "T001")
        #expect(!key1.isEmpty)

        let key2 = try await repository.generateNextNaturalKey(manufacturer: "Ronson", sku: "T001")
        #expect(!key2.isEmpty)
        // Should generate different keys
        #expect(key1 != key2)
    }

    // MARK: - Edge Case Tests

    @Test("Create tool with no SKU")
    func testCreateToolWithNoSKU() async throws {
        let repository = MockToolItemRepository()

        let tool = ToolItemModel(
            stable_id: "nosku",
            name: "No SKU Tool",
            sku: nil,
            manufacturer: "NoSKUMfr",
            mfr_status: "available"
        )

        let created = try await repository.createItem(tool)
        #expect(created.sku == nil)

        let fetched = try await repository.fetchItem(byStableId: "nosku")
        #expect(fetched?.sku == nil)
    }

    @Test("Tool URI format is correct")
    func testToolURIFormat() async throws {
        let tool = ToolItemModel(
            stable_id: "abc123",
            name: "Test Tool",
            sku: nil,
            manufacturer: "TestMfr",
            mfr_status: "available"
        )

        #expect(tool.uri == "moltenglass:tool?abc123")
    }

    @Test("Tool equality based on business key")
    func testToolEquality() async throws {
        let tool1 = ToolItemModel(
            stable_id: "id1",
            name: "Tool 1",
            sku: "T001",
            manufacturer: "Mfr1",
            mfr_status: "available"
        )

        let tool2 = ToolItemModel(
            stable_id: "id2",
            name: "Tool 2",
            sku: "T001",
            manufacturer: "Mfr1",
            mfr_status: "discontinued"
        )

        // Same manufacturer + SKU = equal (regardless of stable_id or other fields)
        #expect(tool1 == tool2)
    }

    @Test("Tool equality fallback to stable_id when no SKU")
    func testToolEqualityFallbackToStableId() async throws {
        let tool1 = ToolItemModel(
            stable_id: "id1",
            name: "Tool 1",
            sku: nil,
            manufacturer: "Mfr1",
            mfr_status: "available"
        )

        let tool2 = ToolItemModel(
            stable_id: "id1",
            name: "Different Name",
            sku: nil,
            manufacturer: "Mfr1",
            mfr_status: "discontinued"
        )

        let tool3 = ToolItemModel(
            stable_id: "id2",
            name: "Tool 1",
            sku: nil,
            manufacturer: "Mfr1",
            mfr_status: "available"
        )

        // Same stable_id when no SKU = equal
        #expect(tool1 == tool2)

        // Different stable_id when no SKU = not equal
        #expect(tool1 != tool3)
    }
}

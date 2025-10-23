//
//  CatalogItemDataTests.swift
//  MoltenTests
//
//  Tests for CatalogItemData JSON decoding including stable_id
//

import Testing
import Foundation
@testable import Molten

@Suite("CatalogItemData Decoding Tests")
@MainActor
struct CatalogItemDataTests {

    // MARK: - Basic Decoding Tests

    @Test("Decode item with all fields including stable_id")
    func decodeItemWithAllFields() throws {
        let json = """
        {
            "id": "test-id",
            "code": "001",
            "stable_id": "abc123",
            "name": "Clear Rod",
            "full_name": "Bullseye Clear Rod",
            "manufacturer": "bullseye",
            "manufacturer_description": "High quality clear glass",
            "tags": ["clear", "transparent"],
            "image_path": "/images/001.jpg",
            "synonyms": ["crystal", "clear glass"],
            "coe": "90",
            "stock_type": "available",
            "image_url": "https://example.com/001.jpg",
            "manufacturer_url": "https://example.com/products/001"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let item = try decoder.decode(CatalogItemData.self, from: data)

        #expect(item.id == "test-id")
        #expect(item.code == "001")
        #expect(item.stable_id == "abc123")
        #expect(item.name == "Clear Rod")
        #expect(item.full_name == "Bullseye Clear Rod")
        #expect(item.manufacturer == "bullseye")
        #expect(item.manufacturer_description == "High quality clear glass")
        #expect(item.tags == ["clear", "transparent"])
        #expect(item.image_path == "/images/001.jpg")
        #expect(item.synonyms == ["crystal", "clear glass"])
        #expect(item.coe == "90")
        #expect(item.stock_type == "available")
        #expect(item.image_url == "https://example.com/001.jpg")
        #expect(item.manufacturer_url == "https://example.com/products/001")
    }

    @Test("Decode item without stable_id")
    func decodeItemWithoutStableId() throws {
        let json = """
        {
            "code": "001",
            "name": "Clear Rod",
            "manufacturer": "bullseye",
            "coe": "90"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let item = try decoder.decode(CatalogItemData.self, from: data)

        #expect(item.code == "001")
        #expect(item.name == "Clear Rod")
        #expect(item.stable_id == nil)
    }

    @Test("Decode item with stable_id as snake_case")
    func decodeItemWithSnakeCaseStableId() throws {
        let json = """
        {
            "code": "001",
            "stable_id": "abc123",
            "name": "Clear Rod",
            "manufacturer": "bullseye",
            "coe": "90"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let item = try decoder.decode(CatalogItemData.self, from: data)

        #expect(item.stable_id == "abc123")
    }

    // MARK: - Stable ID Format Tests

    @Test("Decode 6-character stable_id")
    func decode6CharacterStableId() throws {
        let json = """
        {
            "code": "001",
            "stable_id": "3DyUbA",
            "name": "Clear Rod",
            "manufacturer": "bullseye",
            "coe": "90"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let item = try decoder.decode(CatalogItemData.self, from: data)

        #expect(item.stable_id == "3DyUbA")
        #expect(item.stable_id?.count == 6)
    }

    @Test("Decode various stable_id formats from real data")
    func decodeRealStableIdFormats() throws {
        let stableIds = ["3DyUbA", "5fJhrx", "1ya3bn", "5aZhHE", "2bfEjE"]

        for stableId in stableIds {
            let json = """
            {
                "code": "001",
                "stable_id": "\(stableId)",
                "name": "Test Product",
                "manufacturer": "test",
                "coe": "90"
            }
            """

            let data = json.data(using: .utf8)!
            let decoder = JSONDecoder()
            let item = try decoder.decode(CatalogItemData.self, from: data)

            #expect(item.stable_id == stableId)
            #expect(item.stable_id?.count == 6)
        }
    }

    // MARK: - Code Field Tests (required field)

    @Test("Decode code as string")
    func decodeCodeAsString() throws {
        let json = """
        {
            "code": "001",
            "name": "Clear Rod",
            "manufacturer": "bullseye"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let item = try decoder.decode(CatalogItemData.self, from: data)

        #expect(item.code == "001")
    }

    @Test("Decode code as integer")
    func decodeCodeAsInteger() throws {
        let json = """
        {
            "code": 123,
            "name": "Clear Rod",
            "manufacturer": "bullseye"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let item = try decoder.decode(CatalogItemData.self, from: data)

        #expect(item.code == "123")
    }

    // MARK: - COE Field Tests

    @Test("Decode COE as string")
    func decodeCOEAsString() throws {
        let json = """
        {
            "code": "001",
            "name": "Clear Rod",
            "manufacturer": "bullseye",
            "coe": "90"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let item = try decoder.decode(CatalogItemData.self, from: data)

        #expect(item.coe == "90")
    }

    @Test("Decode COE as integer")
    func decodeCOEAsInteger() throws {
        let json = """
        {
            "code": "001",
            "name": "Clear Rod",
            "manufacturer": "bullseye",
            "coe": 90
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let item = try decoder.decode(CatalogItemData.self, from: data)

        #expect(item.coe == "90")
    }

    @Test("Decode COE as double")
    func decodeCOEAsDouble() throws {
        let json = """
        {
            "code": "001",
            "name": "Clear Rod",
            "manufacturer": "bullseye",
            "coe": 104.0
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let item = try decoder.decode(CatalogItemData.self, from: data)

        #expect(item.coe == "104")
    }

    // MARK: - Tags Field Tests

    @Test("Decode tags as array")
    func decodeTagsAsArray() throws {
        let json = """
        {
            "code": "001",
            "name": "Blue Rod",
            "manufacturer": "bullseye",
            "tags": ["blue", "transparent"]
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let item = try decoder.decode(CatalogItemData.self, from: data)

        #expect(item.tags == ["blue", "transparent"])
    }

    @Test("Decode tags as malformed string")
    func decodeTagsAsMalformedString() throws {
        let json = """
        {
            "code": "001",
            "name": "Blue Rod",
            "manufacturer": "bullseye",
            "tags": "\\"blue\\", \\"transparent\\""
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let item = try decoder.decode(CatalogItemData.self, from: data)

        #expect(item.tags == ["blue", "transparent"])
    }

    @Test("Decode tags filters out unknown")
    func decodeTagsFiltersUnknown() throws {
        let json = """
        {
            "code": "001",
            "name": "Rod",
            "manufacturer": "bullseye",
            "tags": "\\"blue\\", \\"unknown\\""
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let item = try decoder.decode(CatalogItemData.self, from: data)

        #expect(item.tags == ["blue"])
    }

    // MARK: - Wrapped Data Tests

    @Test("Decode wrapped glass items with metadata")
    func decodeWrappedGlassItems() throws {
        let json = """
        {
            "version": "1.0",
            "generated": "2025-01-15T10:30:00",
            "item_count": 2,
            "glassitems": [
                {
                    "code": "001",
                    "stable_id": "abc123",
                    "name": "Clear Rod",
                    "manufacturer": "bullseye",
                    "coe": "90"
                },
                {
                    "code": "002",
                    "stable_id": "xyz789",
                    "name": "Blue Rod",
                    "manufacturer": "bullseye",
                    "coe": "90"
                }
            ]
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let wrapped = try decoder.decode(WrappedGlassItemsData.self, from: data)

        #expect(wrapped.metadata.version == "1.0")
        #expect(wrapped.metadata.generated == "2025-01-15T10:30:00")
        #expect(wrapped.metadata.itemCount == 2)
        #expect(wrapped.glassitems.count == 2)
        #expect(wrapped.glassitems[0].stable_id == "abc123")
        #expect(wrapped.glassitems[1].stable_id == "xyz789")
    }

    @Test("Decode wrapped glass items without item_count (backward compatibility)")
    func decodeWrappedGlassItemsWithoutItemCount() throws {
        let json = """
        {
            "version": "1.0",
            "generated": "2025-01-15T10:30:00",
            "glassitems": [
                {
                    "code": "001",
                    "stable_id": "abc123",
                    "name": "Clear Rod",
                    "manufacturer": "bullseye",
                    "coe": "90"
                }
            ]
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let wrapped = try decoder.decode(WrappedGlassItemsData.self, from: data)

        #expect(wrapped.metadata.version == "1.0")
        #expect(wrapped.metadata.itemCount == nil)
        #expect(wrapped.glassitems.count == 1)
        #expect(wrapped.glassitems[0].stable_id == "abc123")
    }

    // MARK: - Backward Compatibility Tests

    @Test("Decode legacy JSON without stable_id field")
    func decodeLegacyJSON() throws {
        let json = """
        {
            "code": "001",
            "name": "Clear Rod",
            "manufacturer": "bullseye",
            "manufacturer_description": "Clear glass rod",
            "tags": ["clear"],
            "coe": "90"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let item = try decoder.decode(CatalogItemData.self, from: data)

        #expect(item.code == "001")
        #expect(item.name == "Clear Rod")
        #expect(item.stable_id == nil)  // Should be nil for legacy data
        #expect(item.manufacturer == "bullseye")
    }

    @Test("Decode new JSON with stable_id field")
    func decodeNewJSONWithStableId() throws {
        let json = """
        {
            "code": "001",
            "stable_id": "3DyUbA",
            "name": "Clear Rod",
            "manufacturer": "bullseye",
            "manufacturer_description": "Clear glass rod",
            "tags": ["clear"],
            "coe": "90"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let item = try decoder.decode(CatalogItemData.self, from: data)

        #expect(item.code == "001")
        #expect(item.name == "Clear Rod")
        #expect(item.stable_id == "3DyUbA")
        #expect(item.manufacturer == "bullseye")
    }
}

//
//  DataGzipTests.swift
//  MoltenTests
//
//  Created by Assistant on 11/9/25.
//  Tests for Data gzip compression/decompression
//

import Foundation
import Testing

@testable import Molten

@Suite("Data Gzip Tests")
struct DataGzipTests {

    @Test("Gzip compression and decompression roundtrip")
    func testGzipRoundtrip() throws {
        let originalString = "Hello, World! This is a test of gzip compression."
        let originalData = originalString.data(using: .utf8)!

        // Compress
        let compressed = try originalData.gzipped()

        // Verify compressed data is different and smaller (for this text)
        #expect(compressed != originalData)

        // Decompress
        let decompressed = try compressed.gunzipped()

        // Verify roundtrip
        #expect(decompressed == originalData)

        let decompressedString = String(data: decompressed, encoding: .utf8)
        #expect(decompressedString == originalString)
    }

    @Test("Gzip detects gzipped data correctly")
    func testIsGzipped() throws {
        let originalData = "Test data".data(using: .utf8)!
        #expect(originalData.isGzipped == false)

        let gzippedData = try originalData.gzipped()
        #expect(gzippedData.isGzipped == true)
    }

    @Test("Gzip handles empty data")
    func testGzipEmptyData() throws {
        let emptyData = Data()

        let compressed = try emptyData.gzipped()
        #expect(compressed.isEmpty == true)

        let decompressed = try emptyData.gunzipped()
        #expect(decompressed.isEmpty == true)
    }

    @Test("Gzip handles large data")
    func testGzipLargeData() throws {
        // Create ~1MB of repeated text
        let repeatedText = String(repeating: "The quick brown fox jumps over the lazy dog. ", count: 20000)
        let originalData = repeatedText.data(using: .utf8)!

        // Compress
        let compressed = try originalData.gzipped()

        // Should be significantly smaller due to repeated content
        #expect(compressed.count < originalData.count)

        // Decompress and verify
        let decompressed = try compressed.gunzipped()
        #expect(decompressed == originalData)
    }

    @Test("Gzip handles JSON data")
    func testGzipJSONData() throws {
        let jsonObject: [String: Any] = [
            "version": "1.0",
            "catalog_data_version": 1,
            "item_count": 100,
            "glassitems": [
                ["name": "Clear", "sku": "001", "manufacturer": "bullseye"],
                ["name": "Black", "sku": "000", "manufacturer": "bullseye"]
            ]
        ]

        let originalData = try JSONSerialization.data(withJSONObject: jsonObject)

        // Compress
        let compressed = try originalData.gzipped()
        #expect(compressed.isGzipped == true)

        // Decompress
        let decompressed = try compressed.gunzipped()

        // Verify can parse JSON again
        let decodedObject = try JSONSerialization.jsonObject(with: decompressed) as! [String: Any]
        #expect(decodedObject["version"] as? String == "1.0")
        #expect(decodedObject["item_count"] as? Int == 100)
    }

    @Test("Gunzip detects invalid gzip data")
    func testGunzipInvalidData() throws {
        // Create data that starts with gzip magic number but isn't valid gzip
        var fakeGzipData = Data([0x1f, 0x8b])  // Gzip magic number
        fakeGzipData.append(contentsOf: [0x00, 0x00, 0x00])  // Invalid header

        // Should throw error
        #expect(throws: CompressionError.self) {
            _ = try fakeGzipData.gunzipped()
        }
    }

    @Test("Gzip magic number detection is correct")
    func testMagicNumberDetection() {
        // Data with gzip magic number
        let gzipMagic = Data([0x1f, 0x8b, 0x00, 0x00])
        #expect(gzipMagic.isGzipped == true)

        // Data without gzip magic number
        let notGzipped = Data([0x00, 0x00, 0x00, 0x00])
        #expect(notGzipped.isGzipped == false)

        // Data too small to have magic number
        let tooSmall = Data([0x1f])
        #expect(tooSmall.isGzipped == false)

        // Empty data
        let empty = Data()
        #expect(empty.isGzipped == false)
    }

    @Test("Compression error descriptions are correct")
    func testCompressionErrorDescriptions() {
        let invalidInputError = CompressionError.invalidInput
        #expect(invalidInputError.errorDescription?.contains("Invalid") == true)

        let streamError = CompressionError.streamInitializationFailed
        #expect(streamError.errorDescription?.contains("stream") == true)

        let decompressionError = CompressionError.decompressionFailed
        #expect(decompressionError.errorDescription?.contains("Decompression") == true)

        let compressionError = CompressionError.compressionFailed
        #expect(compressionError.errorDescription?.contains("Compression") == true)
    }
}

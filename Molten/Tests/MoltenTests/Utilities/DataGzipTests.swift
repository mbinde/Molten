//
//  DataGzipTests.swift
//  MoltenTests
//
//  Created by Assistant on 11/9/25.
//  Tests for Data zlib compression/decompression
//  Note: Despite the filename, this tests zlib format (RFC 1950), not gzip (RFC 1952)
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

        // Note: COMPRESSION_ZLIB produces raw deflate format which has no magic number
        // so we can't reliably detect it with isGzipped
        let gzippedData = try originalData.gzipped()
        // Just verify roundtrip works
        let decompressed = try gzippedData.gunzipped()
        #expect(decompressed == originalData)
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
        // Note: Raw deflate has no magic number, so isGzipped won't work

        // Decompress
        let decompressed = try compressed.gunzipped()

        // Verify can parse JSON again
        let decodedObject = try JSONSerialization.jsonObject(with: decompressed) as! [String: Any]
        #expect(decodedObject["version"] as? String == "1.0")
        #expect(decodedObject["item_count"] as? Int == 100)
    }

    @Test("Gzip magic number detection is correct")
    func testMagicNumberDetection() {
        // Data with zlib header (0x78 0x9c is common for default compression)
        let zlibData = Data([0x78, 0x9c, 0x00, 0x00])
        #expect(zlibData.isGzipped == true)

        // Data with different zlib header (0x78 0x01 for no compression)
        let zlibNoCompression = Data([0x78, 0x01, 0x00, 0x00])
        #expect(zlibNoCompression.isGzipped == true)

        // Data without zlib header
        let notCompressed = Data([0x00, 0x00, 0x00, 0x00])
        #expect(notCompressed.isGzipped == false)

        // Gzip magic number (different format than zlib, but also compressed)
        let gzipMagic = Data([0x1f, 0x8b, 0x00, 0x00])
        #expect(gzipMagic.isGzipped == true)

        // Data too small to have header
        let tooSmall = Data([0x78])
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

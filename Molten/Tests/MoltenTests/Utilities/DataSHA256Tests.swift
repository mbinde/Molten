//
//  DataSHA256Tests.swift
//  MoltenTests
//
//  Created by Assistant on 11/9/25.
//  Tests for Data SHA256 checksum utilities
//

import Foundation
import Testing

@testable import Molten

@Suite("Data SHA256 Tests")
struct DataSHA256Tests {

    @Test("SHA256 checksum is consistent")
    func testChecksumConsistency() {
        let data = "Hello, World!".data(using: .utf8)!

        let checksum1 = data.sha256Checksum()
        let checksum2 = data.sha256Checksum()

        #expect(checksum1 == checksum2)
        #expect(checksum1.hasPrefix("sha256:"))
    }

    @Test("SHA256 checksum format is correct")
    func testChecksumFormat() {
        let data = "Test data".data(using: .utf8)!
        let checksum = data.sha256Checksum()

        // Should start with "sha256:"
        #expect(checksum.hasPrefix("sha256:"))

        // Should have 64 hex characters after prefix (256 bits / 4 bits per hex char)
        let hashPart = String(checksum.dropFirst("sha256:".count))
        #expect(hashPart.count == 64)

        // All characters should be valid hex
        let hexCharacterSet = CharacterSet(charactersIn: "0123456789abcdef")
        #expect(hashPart.lowercased().unicodeScalars.allSatisfy { hexCharacterSet.contains($0) })
    }

    @Test("Different data produces different checksums")
    func testDifferentDataDifferentChecksums() {
        let data1 = "Hello, World!".data(using: .utf8)!
        let data2 = "Goodbye, World!".data(using: .utf8)!

        let checksum1 = data1.sha256Checksum()
        let checksum2 = data2.sha256Checksum()

        #expect(checksum1 != checksum2)
    }

    @Test("Empty data produces valid checksum")
    func testEmptyDataChecksum() {
        let emptyData = Data()
        let checksum = emptyData.sha256Checksum()

        #expect(checksum.hasPrefix("sha256:"))
        #expect(checksum.count == "sha256:".count + 64)
    }

    @Test("Checksum verification works correctly")
    func testChecksumVerification() {
        let data = "Test data for verification".data(using: .utf8)!
        let checksum = data.sha256Checksum()

        // Correct checksum should verify
        #expect(data.verifySHA256Checksum(checksum) == true)

        // Incorrect checksum should not verify
        #expect(data.verifySHA256Checksum("sha256:0000000000000000000000000000000000000000000000000000000000000000") == false)
    }

    @Test("Checksum verification is case sensitive")
    func testChecksumCaseSensitivity() {
        let data = "Test".data(using: .utf8)!
        let checksum = data.sha256Checksum()

        // Uppercase checksum should not match (if original is lowercase)
        let uppercasedHash = checksum.uppercased()
        if checksum != uppercasedHash {
            #expect(data.verifySHA256Checksum(uppercasedHash) == false)
        }
    }

    @Test("Large data checksum calculation")
    func testLargeDataChecksum() {
        // Create ~1MB of data
        let largeData = Data(repeating: 0x42, count: 1_048_576)

        let checksum = largeData.sha256Checksum()

        #expect(checksum.hasPrefix("sha256:"))
        #expect(checksum.count == "sha256:".count + 64)
        #expect(largeData.verifySHA256Checksum(checksum) == true)
    }

    @Test("JSON data checksum")
    func testJSONDataChecksum() throws {
        let jsonObject: [String: Any] = [
            "version": "1.0",
            "item_count": 100,
            "data": ["item1", "item2", "item3"]
        ]

        let data = try JSONSerialization.data(withJSONObject: jsonObject)
        let checksum = data.sha256Checksum()

        #expect(checksum.hasPrefix("sha256:"))
        #expect(data.verifySHA256Checksum(checksum) == true)

        // Same JSON should produce same checksum
        let data2 = try JSONSerialization.data(withJSONObject: jsonObject)
        let checksum2 = data2.sha256Checksum()

        // Note: JSONSerialization may produce different binary representations
        // even for the same object, so we can't guarantee checksums match
        // But verification should still work
        #expect(data2.verifySHA256Checksum(checksum2) == true)
    }

    @Test("Known SHA256 test vector")
    func testKnownVector() {
        // Test with a known input/output pair
        // "abc" should hash to a known value
        let data = "abc".data(using: .utf8)!
        let checksum = data.sha256Checksum()

        // The SHA256 hash of "abc" is well-known
        let expectedHash = "sha256:ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"

        #expect(checksum == expectedHash)
    }
}

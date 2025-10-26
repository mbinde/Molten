//
//  TestHelpers.swift
//  MoltenTests
//
//  Created by Assistant on 10/25/25.
//  Utilities for generating test data with proper stable IDs
//

import Foundation
import CryptoKit

/// Generate a stable 6-character ID from manufacturer and SKU, matching the Python implementation
/// in Tools/Scraping Tools/update_database.py
func generateStableId(manufacturer: String, sku: String) -> String {
    // Combine manufacturer and SKU for hashing (same format as Python)
    let combined = "\(manufacturer):\(sku)"

    // Hash it with SHA-256
    let hash = SHA256.hash(data: combined.data(using: .utf8)!)
    let hashBytes = Data(hash)

    // Base62 character set (excluding confusing chars: I, O, l)
    let base62Chars = "0123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz"

    // Take first 4 bytes (32 bits), convert to base62
    var num = UInt32(bigEndian: hashBytes.withUnsafeBytes { $0.load(as: UInt32.self) })

    // Generate 6-character ID
    var stableId = ""
    for _ in 0..<6 {
        let index = Int(num % UInt32(base62Chars.count))
        let char = base62Chars[base62Chars.index(base62Chars.startIndex, offsetBy: index)]
        stableId = String(char) + stableId
        num /= UInt32(base62Chars.count)
    }

    return stableId
}

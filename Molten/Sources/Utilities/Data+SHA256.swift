//
//  Data+SHA256.swift
//  Molten
//
//  Created by Assistant on 11/9/25.
//  SHA256 checksum utilities for data integrity verification
//

import Foundation
import CryptoKit

extension Data {

    /// Compute SHA256 checksum of data
    /// - Returns: Checksum in format "sha256:hexstring"
    nonisolated func sha256Checksum() -> String {
        let hash = SHA256.hash(data: self)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        return "sha256:\(hashString)"
    }

    /// Verify SHA256 checksum matches expected value
    /// - Parameter expected: Expected checksum in format "sha256:hexstring"
    /// - Returns: True if checksum matches
    nonisolated func verifySHA256Checksum(_ expected: String) -> Bool {
        let actual = sha256Checksum()
        return actual == expected
    }
}

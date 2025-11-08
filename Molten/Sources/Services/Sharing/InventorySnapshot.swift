//
//  InventorySnapshot.swift
//  Molten
//
//  Serializes and signs inventory data for sharing
//  Uses Ed25519 signatures for authenticity (no encryption - data not confidential)
//
//  Format: [JSON length (4 bytes)][JSON data (N bytes)][Signature (64 bytes)]
//

import Foundation
import CryptoKit

/// Serializes and signs inventory snapshots
@MainActor
final class InventorySnapshot {

    // MARK: - Constants

    private static let version = "1.0"
    private static let signatureSize = 64 // Ed25519 signature is 64 bytes
    private static let lengthSize = 4 // Int32 is 4 bytes

    // MARK: - Serialization

    /// Serialize inventory items with signature
    /// - Parameters:
    ///   - items: Inventory items to serialize
    ///   - publicKey: Public key (stored in snapshot for verification)
    ///   - privateKey: Private key (used to sign)
    /// - Returns: Serialized data blob
    func serialize(items: [InventoryItemSnapshot], publicKey: Data, privateKey: Data) throws -> Data {
        // Create snapshot payload
        let payload = SnapshotPayload(
            version: Self.version,
            timestamp: Date(),
            items: items
        )

        // Serialize to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(payload)

        // Sign the JSON data
        let privateSigningKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKey)
        let signature = try privateSigningKey.signature(for: jsonData)

        // Combine: [length][JSON][signature]
        var result = Data()

        // Add JSON length (4 bytes, little-endian Int32)
        var length = Int32(jsonData.count).littleEndian
        result.append(Data(bytes: &length, count: Self.lengthSize))

        // Add JSON data
        result.append(jsonData)

        // Add signature (64 bytes)
        result.append(signature)

        return result
    }

    // MARK: - Deserialization

    /// Deserialize and verify inventory snapshot
    /// - Parameters:
    ///   - data: Serialized data blob
    ///   - publicKey: Public key to verify signature
    /// - Returns: Snapshot result with validity flag
    func deserialize(data: Data, publicKey: Data) throws -> SnapshotResult {
        // Validate minimum size: 4 bytes (length) + 64 bytes (signature)
        guard data.count >= Self.lengthSize + Self.signatureSize else {
            throw SnapshotError.invalidFormat
        }

        // Extract JSON length (first 4 bytes)
        let lengthData = data.prefix(Self.lengthSize)
        let length = lengthData.withUnsafeBytes { $0.load(as: Int32.self).littleEndian }

        guard length >= 0 else {
            throw SnapshotError.invalidFormat
        }

        // Validate total size
        let expectedSize = Self.lengthSize + Int(length) + Self.signatureSize
        guard data.count == expectedSize else {
            throw SnapshotError.invalidFormat
        }

        // Extract JSON data
        let jsonStartIndex = Self.lengthSize
        let jsonEndIndex = jsonStartIndex + Int(length)
        let jsonData = data.subdata(in: jsonStartIndex..<jsonEndIndex)

        // Extract signature (last 64 bytes)
        let signatureData = data.suffix(Self.signatureSize)

        // Verify signature
        let isValid: Bool
        do {
            let publicSigningKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
            isValid = publicSigningKey.isValidSignature(signatureData, for: jsonData)
        } catch {
            // If signature verification fails, mark as invalid but don't throw
            isValid = false
        }

        // Deserialize JSON
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let payload: SnapshotPayload
        do {
            payload = try decoder.decode(SnapshotPayload.self, from: jsonData)
        } catch {
            throw SnapshotError.deserializationFailed
        }

        return SnapshotResult(
            items: payload.items,
            timestamp: payload.timestamp,
            version: payload.version,
            isValid: isValid
        )
    }
}

// MARK: - Supporting Types

/// Internal payload structure for JSON encoding
private struct SnapshotPayload: Codable {
    let version: String
    let timestamp: Date
    let items: [InventoryItemSnapshot]
}

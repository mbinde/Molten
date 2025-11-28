//
//  InventoryTypeEncoder.swift
//  Molten
//
//  Encodes and decodes inventory type/subtype/subsubtype for compact QR code URLs.
//  Format: molten://i/{stableId}/{typeCode}
//  Where typeCode is 1-3 alphanumeric characters encoding type, subtype, and subsubtype.
//

import Foundation

/// Encodes and decodes inventory types for compact QR code representation
enum InventoryTypeEncoder {

    // MARK: - Type Codes (1st character)

    /// Primary inventory type codes
    private static let typeCodes: [String: Character] = [
        "rod": "r",
        "tube": "t",
        "sheet": "s",
        "frit": "f",
        "powder": "p",
        "stringer": "g",  // 'g' for stringer since 's' is sheet
        "accessory": "a",
        "tool": "l",      // 'l' for tool since 't' is tube
        "enamel": "e",
        "billet": "b",
        "cullet": "c",
        "noodle": "n",
        "confetti": "k",  // 'k' for konfetti since 'c' is cullet
        "murrine": "m",
    ]

    /// Reverse lookup for decoding
    private static let typeFromCode: [Character: String] = {
        Dictionary(uniqueKeysWithValues: typeCodes.map { ($1, $0) })
    }()

    // MARK: - Subtype Codes (2nd character)

    /// Subtype codes vary by parent type
    private static let subtypeCodes: [String: [String: Character]] = [
        "frit": [
            "coarse": "c",
            "medium": "m",
            "fine": "f",
            "powder": "p",
        ],
        "powder": [
            "coarse": "c",
            "medium": "m",
            "fine": "f",
        ],
        "sheet": [
            "thin": "t",
            "standard": "s",
            "thick": "k",
        ],
        "rod": [
            "solid": "s",
            "hollow": "h",
        ],
        "stringer": [
            "thin": "t",
            "medium": "m",
            "thick": "k",
        ],
    ]

    /// Reverse lookup for subtypes
    private static func subtypeFromCode(type: String, code: Character) -> String? {
        guard let subtypes = subtypeCodes[type] else { return nil }
        return subtypes.first { $0.value == code }?.key
    }

    // MARK: - Subsubtype Codes (3rd character)

    /// Subsubtype codes (rarely used, for very specific variants)
    private static let subsubtypeCodes: [String: [String: Character]] = [:]

    // MARK: - Encoding

    /// Encode inventory type info into a compact string for QR codes
    /// - Parameters:
    ///   - type: Primary type (e.g., "rod", "frit")
    ///   - subtype: Optional subtype (e.g., "coarse", "fine")
    ///   - subsubtype: Optional subsubtype
    /// - Returns: 1-3 character code, or nil if type is unknown
    static func encode(type: String, subtype: String? = nil, subsubtype: String? = nil) -> String? {
        let normalizedType = type.lowercased()

        guard let typeCode = typeCodes[normalizedType] else {
            print("⚠️ InventoryTypeEncoder: Unknown type '\(type)'")
            return nil
        }

        var result = String(typeCode)

        // Add subtype code if present
        if let subtype = subtype?.lowercased(),
           let subtypeMap = subtypeCodes[normalizedType],
           let subtypeCode = subtypeMap[subtype] {
            result.append(subtypeCode)

            // Add subsubtype code if present
            if let subsubtype = subsubtype?.lowercased(),
               let subsubtypeMap = subsubtypeCodes[normalizedType],
               let subsubtypeCode = subsubtypeMap[subsubtype] {
                result.append(subsubtypeCode)
            }
        }

        return result
    }

    // MARK: - Decoding

    /// Decoded inventory type information
    struct DecodedType {
        let type: String
        let subtype: String?
        let subsubtype: String?
    }

    /// Decode a compact type code back into type/subtype/subsubtype
    /// - Parameter code: 1-3 character code from QR URL
    /// - Returns: Decoded type info, or nil if invalid
    static func decode(_ code: String) -> DecodedType? {
        guard !code.isEmpty else { return nil }

        let chars = Array(code)

        // Decode type (required)
        guard let type = typeFromCode[chars[0]] else {
            print("⚠️ InventoryTypeEncoder: Unknown type code '\(chars[0])'")
            return nil
        }

        var subtype: String?
        var subsubtype: String?

        // Decode subtype if present
        if chars.count >= 2 {
            subtype = subtypeFromCode(type: type, code: chars[1])
        }

        // Decode subsubtype if present
        if chars.count >= 3 {
            if let subsubtypeMap = subsubtypeCodes[type] {
                subsubtype = subsubtypeMap.first { $0.value == chars[2] }?.key
            }
        }

        return DecodedType(type: type, subtype: subtype, subsubtype: subsubtype)
    }

    // MARK: - URL Helpers

    /// Build a complete QR code URL with inventory type
    /// - Parameters:
    ///   - stableId: The item's stable ID
    ///   - type: Primary inventory type
    ///   - subtype: Optional subtype
    ///   - subsubtype: Optional subsubtype
    /// - Returns: Complete URL string (e.g., "molten://i/abc123/rf" for rod fine frit)
    static func buildQRCodeURL(
        stableId: String,
        type: String,
        subtype: String? = nil,
        subsubtype: String? = nil
    ) -> String {
        var url = "molten://i/\(stableId)"

        if let typeCode = encode(type: type, subtype: subtype, subsubtype: subsubtype) {
            url += "/\(typeCode)"
        }

        return url
    }

    /// Parse a QR code URL to extract stable ID and inventory type
    /// - Parameter url: The full URL (e.g., "molten://i/abc123/rf")
    /// - Returns: Tuple of (stableId, decodedType) or nil if invalid
    static func parseQRCodeURL(_ url: URL) -> (stableId: String, type: DecodedType?)? {
        guard url.scheme == "molten",
              url.host == "i" else {
            return nil
        }

        let pathComponents = url.pathComponents.filter { $0 != "/" }

        guard !pathComponents.isEmpty else { return nil }

        let stableId = pathComponents[0]
        var decodedType: DecodedType?

        if pathComponents.count >= 2 {
            decodedType = decode(pathComponents[1])
        }

        return (stableId, decodedType)
    }

    // MARK: - Display Helpers

    /// Get a human-readable description of an inventory type
    /// - Parameters:
    ///   - type: Primary type
    ///   - subtype: Optional subtype
    ///   - subsubtype: Optional subsubtype
    /// - Returns: Display string (e.g., "Coarse Frit", "Rod")
    static func displayName(type: String, subtype: String? = nil, subsubtype: String? = nil) -> String {
        var parts: [String] = []

        if let subsubtype = subsubtype {
            parts.append(subsubtype.capitalized)
        }

        if let subtype = subtype {
            parts.append(subtype.capitalized)
        }

        parts.append(type.capitalized)

        return parts.joined(separator: " ")
    }
}

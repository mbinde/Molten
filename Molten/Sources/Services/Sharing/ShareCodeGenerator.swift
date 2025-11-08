//
//  ShareCodeGenerator.swift
//  Molten
//
//  Generates and validates share codes for inventory sharing
//  Format: GLASS-XXXX-XXXX (8 alphanumeric characters of entropy)
//

import Foundation

/// Generates and validates share codes for inventory sharing
@MainActor
final class ShareCodeGenerator {

    // MARK: - Constants

    private static let prefix = "GLASS"
    private static let separator = "-"
    private static let partLength = 4
    private static let totalLength = 15 // GLASS-XXXX-XXXX
    private static let alphanumerics = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

    // MARK: - Generation

    /// Generate a new unique share code
    /// - Returns: Share code in format GLASS-XXXX-XXXX
    func generate() -> String {
        let part1 = generateRandomPart()
        let part2 = generateRandomPart()
        return "\(Self.prefix)\(Self.separator)\(part1)\(Self.separator)\(part2)"
    }

    /// Generate a random 4-character alphanumeric string
    private func generateRandomPart() -> String {
        return String((0..<Self.partLength).map { _ in
            Self.alphanumerics.randomElement()!
        })
    }

    // MARK: - Validation

    /// Validate if a share code has the correct format
    /// - Parameter code: The share code to validate
    /// - Returns: true if valid, false otherwise
    func isValid(_ code: String) -> Bool {
        // Normalize to uppercase for validation
        let uppercased = code.uppercased()

        // Check total length
        guard uppercased.count == Self.totalLength else {
            return false
        }

        // Split by separator
        let parts = uppercased.split(separator: Character(Self.separator))
        guard parts.count == 3 else {
            return false
        }

        // Check prefix
        guard parts[0] == Self.prefix else {
            return false
        }

        // Check part lengths
        guard parts[1].count == Self.partLength,
              parts[2].count == Self.partLength else {
            return false
        }

        // Check that parts contain only alphanumerics
        let codePart = String(parts[1]) + String(parts[2])
        let alphanumericSet = CharacterSet.alphanumerics
        let codeCharacterSet = CharacterSet(charactersIn: codePart)

        return alphanumericSet.isSuperset(of: codeCharacterSet)
    }

    // MARK: - Normalization

    /// Normalize a share code (uppercase, trim whitespace)
    /// - Parameter code: The share code to normalize
    /// - Returns: Normalized code, or nil if invalid
    func normalize(_ code: String) -> String? {
        // Trim whitespace
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)

        // Convert to uppercase
        let normalized = trimmed.uppercased()

        // Validate
        guard isValid(normalized) else {
            return nil
        }

        return normalized
    }
}

//
//  ShareCodeGenerator.swift
//  Molten
//
//  Generates and validates share codes for inventory sharing
//  Format: 6 random alphanumeric characters (e.g., "A7B2X9")
//  Excludes confusing characters: 0, O, 1, l, I
//

import Foundation

/// Generates and validates share codes for inventory sharing
@MainActor
final class ShareCodeGenerator {

    // MARK: - Constants

    private static let codeLength = 6
    // Alphanumerics excluding confusing characters: 0, O, 1, l, I
    // Letters: A-Z except O, I, L = ABCDEFGHJKMNPQRSTVWXYZ (23 letters)
    // Numbers: 2-9 (no 0 or 1) = 23456789 (8 digits)
    // Total: 31 characters, 31^6 = ~887 million combinations
    private static let safeCharacters = "ABCDEFGHJKMNPQRSTVWXYZ23456789"

    // MARK: - Generation

    /// Generate a new unique share code
    /// - Returns: Share code (e.g., "A7B2X9")
    func generate() -> String {
        return String((0..<Self.codeLength).map { _ in
            Self.safeCharacters.randomElement()!
        })
    }

    // MARK: - Validation

    /// Validate if a share code has the correct format
    /// - Parameter code: The share code to validate
    /// - Returns: true if valid, false otherwise
    func isValid(_ code: String) -> Bool {
        // Normalize to uppercase for validation
        let uppercased = code.uppercased()

        // Check length
        guard uppercased.count == Self.codeLength else {
            return false
        }

        // Check that all characters are in the safe character set
        let safeCharacterSet = CharacterSet(charactersIn: Self.safeCharacters)
        let codeCharacterSet = CharacterSet(charactersIn: uppercased)

        return safeCharacterSet.isSuperset(of: codeCharacterSet)
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

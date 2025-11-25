//
//  BackupKeyGenerator.swift
//  Molten
//
//  Generates and validates backup keys for automatic inventory backups
//  Format: 3 sets of 3 alphanumerics separated by dashes (e.g., "A1B-C2D-E3F")
//  Excludes confusing characters: 0, O, 1, l, I
//

import Foundation

/// Generates and validates backup keys for automatic inventory backups
@MainActor
final class BackupKeyGenerator {

    // MARK: - Constants

    private static let segmentLength = 3
    private static let segmentCount = 3
    // Alphanumerics excluding confusing characters: 0, O, 1, l, I
    // Letters: A-Z except O, I, L = ABCDEFGHJKMNPQRSTVWXYZ (23 letters)
    // Numbers: 2-9 (no 0 or 1) = 23456789 (8 digits)
    // Total: 31 characters, 31^9 = ~26.4 trillion combinations
    private static let safeCharacters = "ABCDEFGHJKMNPQRSTVWXYZ23456789"

    // MARK: - Generation

    /// Generate a new unique backup key
    /// - Returns: Backup key (e.g., "A1B-C2D-E3F")
    func generate() -> String {
        let segments = (0..<Self.segmentCount).map { _ in
            String((0..<Self.segmentLength).map { _ in
                Self.safeCharacters.randomElement()!
            })
        }
        return segments.joined(separator: "-")
    }

    // MARK: - Validation

    /// Validate if a backup key has the correct format
    /// - Parameter key: The backup key to validate
    /// - Returns: true if valid, false otherwise
    func isValid(_ key: String) -> Bool {
        // Normalize to uppercase for validation
        let uppercased = key.uppercased()

        // Check format: XXX-XXX-XXX
        let pattern = "^[A-Z2-9]{3}-[A-Z2-9]{3}-[A-Z2-9]{3}$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return false
        }

        let range = NSRange(uppercased.startIndex..., in: uppercased)
        return regex.firstMatch(in: uppercased, options: [], range: range) != nil
    }

    // MARK: - Normalization

    /// Normalize a backup key (uppercase, trim whitespace)
    /// - Parameter key: The backup key to normalize
    /// - Returns: Normalized key, or nil if invalid
    func normalize(_ key: String) -> String? {
        // Trim whitespace
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)

        // Convert to uppercase
        let normalized = trimmed.uppercased()

        // Validate
        guard isValid(normalized) else {
            return nil
        }

        return normalized
    }
}

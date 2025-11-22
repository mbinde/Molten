//
//  GlassTerminologySettings.swift
//  Flameworker
//
//  Manages glass working terminology - simplified to use default display names.
//  Created by Assistant on 10/19/25.
//

import Foundation
import SwiftUI
import Combine

/// Manages glass working terminology with simple default display names
///
/// Backend storage always uses:
/// - "big-rod" for 12mm+ rods → displays as "Bar"
/// - "rod" for 5-6mm rods → displays as "Rod"
///
/// Users can customize terminology in Settings if desired.
class GlassTerminologySettings: ObservableObject {

    // MARK: - Shared Instance

    static let shared = GlassTerminologySettings()

    // MARK: - Backend Product Types (Never change in storage)

    /// Backend storage type for 12mm+ rods (displays as "Bar")
    static let bigRodType = "big-rod"

    /// Backend storage type for 5-6mm rods (displays as "Rod")
    static let rodType = "rod"

    // MARK: - Display Names (Customizable by user)

    @Published var bigRodDisplayName: String {
        didSet {
            UserDefaults.standard.set(bigRodDisplayName, forKey: "bigRodDisplayName")
        }
    }

    @Published var rodDisplayName: String {
        didSet {
            UserDefaults.standard.set(rodDisplayName, forKey: "rodDisplayName")
        }
    }

    private init() {
        // Load custom display names from UserDefaults, or use defaults
        self.bigRodDisplayName = UserDefaults.standard.string(forKey: "bigRodDisplayName") ?? "Bars"
        self.rodDisplayName = UserDefaults.standard.string(forKey: "rodDisplayName") ?? "Rods"
    }

    // MARK: - Display Logic

    /// Get the display name for a product type
    /// - Parameter backendType: The backend storage type (e.g., "rod", "big-rod", "frit", etc.)
    /// - Returns: The user-facing display name
    func displayName(for backendType: String) -> String {
        switch backendType.lowercased() {
        case Self.rodType:
            return rodDisplayName
        case Self.bigRodType:
            return bigRodDisplayName
        case "tube":
            return "Tubes"
        case "frit":
            return "Frit"
        case "powder":
            return "Powder"
        case "stringer":
            return "Stringers"
        case "sheet":
            return "Sheets"
        case "scrap":
            return "Scrap"
        case "murrini-cane":
            return "Murrini Canes"
        case "murrini-slice":
            return "Murrini Slices"
        default:
            // Fallback: capitalize first letter
            return backendType.capitalized
        }
    }

    /// Get the backend type from a user-facing display name
    /// - Parameter displayName: The display name (e.g., "Rod", "Bar")
    /// - Returns: The backend storage type, or nil if not recognized
    func backendType(from displayName: String) -> String? {
        let normalized = displayName.lowercased()

        // Check if it matches our custom display names
        if normalized == rodDisplayName.lowercased() {
            return Self.rodType
        }
        if normalized == bigRodDisplayName.lowercased() {
            return Self.bigRodType
        }

        // For other types, just return the input lowercased
        return normalized
    }

    /// Reset display names to defaults
    func resetToDefaults() {
        bigRodDisplayName = "Bars"
        rodDisplayName = "Rods"
    }
}

// MARK: - Convenience Extensions

extension GlassTerminologySettings {

    /// Get a user-friendly description of a product type for display
    /// - Parameters:
    ///   - backendType: The backend storage type
    ///   - includeSize: Whether to include size information in parentheses
    /// - Returns: Display string (e.g., "Rods (5-6mm)" or "Bars (12mm+)")
    func detailedDisplayName(for backendType: String, includeSize: Bool = false) -> String {
        let baseName = displayName(for: backendType)

        guard includeSize else {
            return baseName
        }

        switch backendType.lowercased() {
        case Self.rodType:
            return "\(baseName) (5-6mm)"
        case Self.bigRodType:
            return "\(baseName) (12mm+)"
        default:
            return baseName
        }
    }
}

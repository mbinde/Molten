//
//  GlassTerminologySettings.swift
//  Flameworker
//
//  Manages glass working terminology preferences across hot shop and flameworking disciplines.
//  Created by Assistant on 10/19/25.
//

import Foundation
import SwiftUI
import Combine

/// Manages user preferences for glass working terminology
///
/// The glass industry has confusing terminology differences:
/// - Hot shop/Glass blowing: Calls 12mm+ rods "rods" and 5-6mm rods "cane"
/// - Flameworking/Torchwork: Calls 5-6mm rods "rods" (what hot shop calls "cane")
///
/// Backend storage always uses:
/// - "big-rod" for 12mm+ rods (hot shop rods)
/// - "rod" for 5-6mm rods (flameworking rods)
///
/// Display logic adapts based on which discipline(s) the user enabled.
class GlassTerminologySettings: ObservableObject {

    // MARK: - Shared Instance

    static let shared = GlassTerminologySettings()

    // MARK: - User Preferences

    @Published var enableHotShop: Bool {
        didSet {
            UserDefaults.standard.set(enableHotShop, forKey: "enableHotShopTerminology")
        }
    }

    @Published var enableFlameworking: Bool {
        didSet {
            UserDefaults.standard.set(enableFlameworking, forKey: "enableFlameworkingTerminology")
        }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedTerminologyOnboarding")
        }
    }

    private init() {
        // Load initial values from UserDefaults
        self.enableHotShop = UserDefaults.standard.bool(forKey: "enableHotShopTerminology")
        self.enableFlameworking = UserDefaults.standard.object(forKey: "enableFlameworkingTerminology") as? Bool ?? true
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedTerminologyOnboarding")
    }

    // MARK: - Backend Product Types (Never change in storage)

    /// Backend storage type for 12mm+ rods (hot shop rods)
    static let bigRodType = "big-rod"

    /// Backend storage type for 5-6mm rods (flameworking rods)
    static let rodType = "rod"

    // MARK: - Display Logic

    /// Get the display name for a product type based on current terminology settings
    /// - Parameter backendType: The backend storage type (e.g., "rod", "big-rod", "frit", etc.)
    /// - Returns: The user-facing display name
    func displayName(for backendType: String) -> String {
        switch backendType.lowercased() {
        case Self.rodType:
            // Flameworking rods (5-6mm)
            if enableHotShop && enableFlameworking {
                return "Cane"  // Both enabled: disambiguate
            } else {
                return "Rod"   // Either discipline enabled: show as "Rod"
            }

        case Self.bigRodType:
            // Hot shop rods (12mm+)
            return "Rod"  // Always "Rod" when visible

        default:
            // Other types (frit, tube, stringer, sheet, etc.) don't change
            return backendType.capitalized
        }
    }

    /// Get all product types that should be visible based on current terminology settings
    /// - Returns: Array of backend type strings that should be shown to the user
    func visibleProductTypes() -> [String] {
        var types = [
            "frit",
            "tube",
            "stringer",
            "sheet",
            "other"
        ]

        // Add rod types based on enabled disciplines
        if enableFlameworking {
            types.append(Self.rodType)  // Flameworking rods
        }

        if enableHotShop {
            types.append(Self.bigRodType)  // Hot shop rods
        }

        return types
    }

    /// Check if a product type should be visible based on current settings
    /// - Parameter backendType: The backend storage type
    /// - Returns: True if this product type should be shown to the user
    func isVisible(productType backendType: String) -> Bool {
        return visibleProductTypes().contains(backendType.lowercased())
    }

    /// Get the backend type from a user-facing display name
    /// - Parameter displayName: The display name (e.g., "Rod", "Cane")
    /// - Returns: The backend storage type, or nil if not recognized
    func backendType(from displayName: String) -> String? {
        let normalized = displayName.lowercased()

        switch normalized {
        case "rod":
            // "Rod" could mean either type depending on settings
            if enableHotShop && !enableFlameworking {
                return Self.bigRodType  // Hot shop only: "Rod" = big-rod
            } else {
                return Self.rodType  // Flameworking or both: "Rod" = rod
            }

        case "cane":
            // "Cane" always means flameworking rods (when both enabled)
            return Self.rodType

        default:
            // For other types, just return the input lowercased
            return normalized
        }
    }

    // MARK: - Settings Messages

    /// Get the explanatory message for current terminology settings
    var currentSettingsMessage: String {
        switch (enableHotShop, enableFlameworking) {
        case (true, true):
            return """
            When both terminologies are enabled:
            • Hot shop rods (12mm+) will be called "Rods"
            • Flameworking rods (2-10mm) will be called "Cane"

            This lets you work with both types while keeping them distinct.
            """

        case (true, false):
            return """
            "Rod" will mean hot shop rods (12mm+).
            Flameworking rods will be hidden from the interface, though they will still stored in the database for when you re-enable flameworking.
            """

        case (false, true):
            return """
            "Rod" will mean flameworking rods (2-10mm), called "cane" by hot shop users.
            Hot shop rods will be hidden from the interface, though they will still stored in the database for when you re-enable flameworking.
            """

        case (false, false):
            return """
            At least one terminology must be enabled.
            """
        }
    }

    /// Get the warning message when user tries to disable both terminologies
    var bothDisabledWarning: String {
        "At least one terminology must be enabled. Flameworking terminology will be automatically enabled."
    }

    // MARK: - Validation

    /// Ensure at least one terminology is enabled
    func validateSettings() {
        if !enableHotShop && !enableFlameworking {
            // Force flameworking on as default
            enableFlameworking = true
        }
    }
}

// MARK: - Convenience Extensions

extension GlassTerminologySettings {

    /// Get a user-friendly description of a product type for display
    /// - Parameters:
    ///   - backendType: The backend storage type
    ///   - includeSize: Whether to include size information in parentheses
    /// - Returns: Display string (e.g., "Rod (5-6mm)" or "Cane (5-6mm)")
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

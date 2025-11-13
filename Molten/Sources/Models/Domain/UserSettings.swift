//
//  UserSettings.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//

import Foundation
import SwiftUI

/// User preferences and settings for the app
/// Uses @AppStorage for automatic persistence to UserDefaults
@Observable
class UserSettings {

    // MARK: - Singleton

    /// Shared instance for app-wide access
    static let shared = UserSettings()

    // MARK: - Display Settings

    /// Controls whether manufacturer descriptions/notes expand by default in detail views
    /// - Default: false (collapsed)
    /// - When true, descriptions are fully expanded when detail view opens
    /// - When false, descriptions are limited to 4 lines with "Show More" button
    var expandManufacturerDescriptionsByDefault: Bool {
        get {
            UserDefaults.standard.bool(forKey: Keys.expandManufacturerDescriptions)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.expandManufacturerDescriptions)
        }
    }

    /// Controls whether user notes expand by default in detail views
    /// - Default: false (collapsed)
    /// - When true, user notes are fully expanded when detail view opens
    /// - When false, user notes are limited to 4 lines with "Show More" button
    var expandUserNotesByDefault: Bool {
        get {
            UserDefaults.standard.bool(forKey: Keys.expandUserNotes)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.expandUserNotes)
        }
    }

    // MARK: - Appearance Settings

    /// Appearance mode preference
    /// - Default: .system (follows system setting)
    /// - Options: .light, .dark, .system
    var appearanceMode: AppearanceMode {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: Keys.appearanceMode),
               let mode = AppearanceMode(rawValue: rawValue) {
                return mode
            }
            return .system
        }
        set {
            // Use withObservationTracking to ensure SwiftUI observes this change
            withMutation(keyPath: \.appearanceMode) {
                UserDefaults.standard.set(newValue.rawValue, forKey: Keys.appearanceMode)
            }
        }
    }

    /// Color scheme computed from appearance mode
    var colorScheme: ColorScheme? {
        switch appearanceMode {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil // Let system decide
        }
    }

    /// Thumbnail display mode preference
    /// - Default: .fill (cropped square)
    /// - Options: .fit (aspect ratio preserved), .fill (cropped square)
    var thumbnailDisplayMode: ThumbnailDisplayMode {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: Keys.thumbnailDisplayMode),
               let mode = ThumbnailDisplayMode(rawValue: rawValue) {
                return mode
            }
            return .fill
        }
        set {
            withMutation(keyPath: \.thumbnailDisplayMode) {
                UserDefaults.standard.set(newValue.rawValue, forKey: Keys.thumbnailDisplayMode)
            }
        }
    }

    // MARK: - Image Quality Settings

    /// Controls whether to download full-size images instead of thumbnails
    /// - Default: false (use thumbnails for better performance and storage)
    /// - When true, downloads full-size images which use significantly more storage space
    /// - When false, downloads optimized 400px thumbnails
    var downloadFullSizeImages: Bool {
        get {
            UserDefaults.standard.bool(forKey: Keys.downloadFullSizeImages)
        }
        set {
            withMutation(keyPath: \.downloadFullSizeImages) {
                UserDefaults.standard.set(newValue, forKey: Keys.downloadFullSizeImages)
            }
        }
    }

    // MARK: - Tag Filter Settings

    /// Controls whether user-created tags appear in the tag filter menu
    /// - Default: true (shown)
    /// - When false, user tags (tags not in color or technical categories) are hidden from filters
    /// - Note: Tags remain visible on catalog items regardless of this setting
    var showUserTagsInFilter: Bool {
        get {
            // Default to true if not set
            UserDefaults.standard.object(forKey: Keys.showUserTagsInFilter) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.showUserTagsInFilter)
        }
    }

    /// Controls whether technical property tags appear in the tag filter menu
    /// - Default: true (shown)
    /// - Technical tags include: reducing, seeded, reactive, striker, uv, cfl, luster, etc.
    /// - When false, technical tags are hidden from filters
    /// - Note: Tags remain visible on catalog items regardless of this setting
    var showTechnicalTagsInFilter: Bool {
        get {
            // Default to true if not set
            UserDefaults.standard.object(forKey: Keys.showTechnicalTagsInFilter) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.showTechnicalTagsInFilter)
        }
    }

    // MARK: - Label Settings

    /// Inventory owner name (optional)
    /// - Default: nil (not set)
    /// - Used as an optional field on printed inventory labels
    /// - Example: "Studio Name" or "Artist Name"
    var inventoryOwner: String? {
        get {
            UserDefaults.standard.string(forKey: Keys.inventoryOwner)
        }
        set {
            withMutation(keyPath: \.inventoryOwner) {
                UserDefaults.standard.set(newValue, forKey: Keys.inventoryOwner)
            }
        }
    }

    // MARK: - Kiln Settings

    /// Preferred temperature unit for displaying kiln schedules
    /// - Default: .fahrenheit
    /// - Note: All schedules are stored in Celsius and converted for display
    var preferredTemperatureUnit: TemperatureUnit {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: Keys.preferredTemperatureUnit),
               let unit = TemperatureUnit(rawValue: rawValue) {
                return unit
            }
            return .fahrenheit // Default to Fahrenheit
        }
        set {
            withMutation(keyPath: \.preferredTemperatureUnit) {
                UserDefaults.standard.set(newValue.rawValue, forKey: Keys.preferredTemperatureUnit)
            }
        }
    }

    /// Last selected technique when creating a kiln schedule
    /// - Default: .fusing
    /// - Used to pre-populate the technique picker in new schedule forms
    var lastSelectedKilnTechnique: TechniqueType? {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: Keys.lastSelectedKilnTechnique),
               let technique = TechniqueType(rawValue: rawValue) {
                return technique
            }
            return .fusing // Default to fusing
        }
        set {
            withMutation(keyPath: \.lastSelectedKilnTechnique) {
                if let newValue = newValue {
                    UserDefaults.standard.set(newValue.rawValue, forKey: Keys.lastSelectedKilnTechnique)
                } else {
                    UserDefaults.standard.removeObject(forKey: Keys.lastSelectedKilnTechnique)
                }
            }
        }
    }

    // MARK: - Kiln Rate Settings
    // All rates stored in Celsius per hour for consistency
    // Temperature ranges: 20-260°C, 260-540°C, 540-815°C, 815°C+

    /// Max heat up rate for 20-260°C range (°C/hour)
    /// Default: 222 (≈400°F/hour)
    var kilnHeatupRate20to260: Decimal {
        get {
            if let value = UserDefaults.standard.string(forKey: Keys.kilnHeatupRate20to260),
               let decimal = Decimal(string: value) {
                return decimal
            }
            return 222 // ≈400°F/hour
        }
        set {
            withMutation(keyPath: \.kilnHeatupRate20to260) {
                UserDefaults.standard.set(newValue.description, forKey: Keys.kilnHeatupRate20to260)
            }
        }
    }

    /// Max heat up rate for 260-540°C range (°C/hour)
    /// Default: 222 (≈400°F/hour)
    var kilnHeatupRate260to540: Decimal {
        get {
            if let value = UserDefaults.standard.string(forKey: Keys.kilnHeatupRate260to540),
               let decimal = Decimal(string: value) {
                return decimal
            }
            return 222 // ≈400°F/hour
        }
        set {
            withMutation(keyPath: \.kilnHeatupRate260to540) {
                UserDefaults.standard.set(newValue.description, forKey: Keys.kilnHeatupRate260to540)
            }
        }
    }

    /// Max heat up rate for 540-815°C range (°C/hour)
    /// Default: 222 (≈400°F/hour)
    var kilnHeatupRate540to815: Decimal {
        get {
            if let value = UserDefaults.standard.string(forKey: Keys.kilnHeatupRate540to815),
               let decimal = Decimal(string: value) {
                return decimal
            }
            return 222 // ≈400°F/hour
        }
        set {
            withMutation(keyPath: \.kilnHeatupRate540to815) {
                UserDefaults.standard.set(newValue.description, forKey: Keys.kilnHeatupRate540to815)
            }
        }
    }

    /// Max heat up rate for 815°C and above (°C/hour)
    /// Default: 222 (≈400°F/hour)
    var kilnHeatupRate815Plus: Decimal {
        get {
            if let value = UserDefaults.standard.string(forKey: Keys.kilnHeatupRate815Plus),
               let decimal = Decimal(string: value) {
                return decimal
            }
            return 222 // ≈400°F/hour
        }
        set {
            withMutation(keyPath: \.kilnHeatupRate815Plus) {
                UserDefaults.standard.set(newValue.description, forKey: Keys.kilnHeatupRate815Plus)
            }
        }
    }

    /// Max cool down rate for 20-260°C range (°C/hour)
    /// Default: 56 (≈100°F/hour)
    var kilnCooldownRate20to260: Decimal {
        get {
            if let value = UserDefaults.standard.string(forKey: Keys.kilnCooldownRate20to260),
               let decimal = Decimal(string: value) {
                return decimal
            }
            return 56 // ≈100°F/hour
        }
        set {
            withMutation(keyPath: \.kilnCooldownRate20to260) {
                UserDefaults.standard.set(newValue.description, forKey: Keys.kilnCooldownRate20to260)
            }
        }
    }

    /// Max cool down rate for 260-540°C range (°C/hour)
    /// Default: 167 (≈300°F/hour)
    var kilnCooldownRate260to540: Decimal {
        get {
            if let value = UserDefaults.standard.string(forKey: Keys.kilnCooldownRate260to540),
               let decimal = Decimal(string: value) {
                return decimal
            }
            return 167 // ≈300°F/hour
        }
        set {
            withMutation(keyPath: \.kilnCooldownRate260to540) {
                UserDefaults.standard.set(newValue.description, forKey: Keys.kilnCooldownRate260to540)
            }
        }
    }

    /// Max cool down rate for 540-815°C range (°C/hour)
    /// Default: 167 (≈300°F/hour)
    var kilnCooldownRate540to815: Decimal {
        get {
            if let value = UserDefaults.standard.string(forKey: Keys.kilnCooldownRate540to815),
               let decimal = Decimal(string: value) {
                return decimal
            }
            return 167 // ≈300°F/hour
        }
        set {
            withMutation(keyPath: \.kilnCooldownRate540to815) {
                UserDefaults.standard.set(newValue.description, forKey: Keys.kilnCooldownRate540to815)
            }
        }
    }

    /// Max cool down rate for 815°C and above (°C/hour)
    /// Default: 167 (≈300°F/hour)
    var kilnCooldownRate815Plus: Decimal {
        get {
            if let value = UserDefaults.standard.string(forKey: Keys.kilnCooldownRate815Plus),
               let decimal = Decimal(string: value) {
                return decimal
            }
            return 167 // ≈300°F/hour
        }
        set {
            withMutation(keyPath: \.kilnCooldownRate815Plus) {
                UserDefaults.standard.set(newValue.description, forKey: Keys.kilnCooldownRate815Plus)
            }
        }
    }

    /// Get appropriate heat up rate for given temperature (in Celsius)
    nonisolated static func getHeatupRate(forTemperature temp: Decimal) -> Decimal {
        let defaults = UserDefaults.standard

        let rate: String
        if temp < 260 {
            rate = "kilnHeatupRate20to260"
        } else if temp < 540 {
            rate = "kilnHeatupRate260to540"
        } else if temp < 815 {
            rate = "kilnHeatupRate540to815"
        } else {
            rate = "kilnHeatupRate815Plus"
        }

        if let value = defaults.string(forKey: rate),
           let decimal = Decimal(string: value) {
            return decimal
        }
        return 222 // Default: ≈400°F/hour
    }

    /// Get appropriate cool down rate for given temperature (in Celsius)
    nonisolated static func getCooldownRate(forTemperature temp: Decimal) -> Decimal {
        let defaults = UserDefaults.standard

        let rate: String
        if temp < 260 {
            rate = "kilnCooldownRate20to260"
        } else if temp < 540 {
            rate = "kilnCooldownRate260to540"
        } else if temp < 815 {
            rate = "kilnCooldownRate540to815"
        } else {
            rate = "kilnCooldownRate815Plus"
        }

        if let value = defaults.string(forKey: rate),
           let decimal = Decimal(string: value) {
            return decimal
        }
        // Default based on temperature range
        return temp < 260 ? 56 : 167 // ≈100°F/hour or ≈300°F/hour
    }

    // MARK: - Keys

    /// UserDefaults keys for settings
    fileprivate enum Keys {
        static let expandManufacturerDescriptions = "expandManufacturerDescriptionsByDefault"
        static let expandUserNotes = "expandUserNotesByDefault"
        static let appearanceMode = "appearanceMode"
        static let thumbnailDisplayMode = "thumbnailDisplayMode"
        static let showUserTagsInFilter = "showUserTagsInFilter"
        static let showTechnicalTagsInFilter = "showTechnicalTagsInFilter"
        static let inventoryOwner = "inventoryOwner"
        static let preferredTemperatureUnit = "preferredTemperatureUnit"
        static let lastSelectedKilnTechnique = "lastSelectedKilnTechnique"
        static let kilnHeatupRate20to260 = "kilnHeatupRate20to260"
        static let kilnHeatupRate260to540 = "kilnHeatupRate260to540"
        static let kilnHeatupRate540to815 = "kilnHeatupRate540to815"
        static let kilnHeatupRate815Plus = "kilnHeatupRate815Plus"
        static let kilnCooldownRate20to260 = "kilnCooldownRate20to260"
        static let kilnCooldownRate260to540 = "kilnCooldownRate260to540"
        static let kilnCooldownRate540to815 = "kilnCooldownRate540to815"
        static let kilnCooldownRate815Plus = "kilnCooldownRate815Plus"
        static let downloadFullSizeImages = "downloadFullSizeImages"
    }

    // MARK: - Enums

    /// Appearance mode options
    enum AppearanceMode: String, CaseIterable {
        case light = "light"
        case dark = "dark"
        case system = "system"

        var displayName: String {
            switch self {
            case .light:
                return "Light"
            case .dark:
                return "Dark"
            case .system:
                return "System"
            }
        }

        var systemImage: String {
            switch self {
            case .light:
                return "sun.max"
            case .dark:
                return "moon"
            case .system:
                return "circle.lefthalf.filled"
            }
        }
    }

    /// Thumbnail display mode options for project thumbnails
    enum ThumbnailDisplayMode: String, CaseIterable {
        case fit = "fit"
        case fill = "fill"

        var displayName: String {
            switch self {
            case .fit:
                return "Fit (Preserve Aspect Ratio)"
            case .fill:
                return "Fill (Crop to Square)"
            }
        }

        var systemImage: String {
            switch self {
            case .fit:
                return "rectangle"
            case .fill:
                return "square"
            }
        }

        var contentMode: ContentMode {
            switch self {
            case .fit:
                return .fit
            case .fill:
                return .fill
            }
        }
    }

    // MARK: - Initialization

    private init() {
        // Private initializer to enforce singleton pattern
    }

    // MARK: - Reset

    /// Reset all settings to default values
    func resetToDefaults() {
        expandManufacturerDescriptionsByDefault = false
        expandUserNotesByDefault = false
        appearanceMode = .system
        thumbnailDisplayMode = .fill
        inventoryOwner = nil
    }
}

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
    /// - Default: .fit (maintain aspect ratio)
    /// - Options: .fit (aspect ratio preserved), .fill (cropped square)
    var thumbnailDisplayMode: ThumbnailDisplayMode {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: Keys.thumbnailDisplayMode),
               let mode = ThumbnailDisplayMode(rawValue: rawValue) {
                return mode
            }
            return .fit
        }
        set {
            withMutation(keyPath: \.thumbnailDisplayMode) {
                UserDefaults.standard.set(newValue.rawValue, forKey: Keys.thumbnailDisplayMode)
            }
        }
    }

    // MARK: - Keys

    /// UserDefaults keys for settings
    private enum Keys {
        static let expandManufacturerDescriptions = "expandManufacturerDescriptionsByDefault"
        static let expandUserNotes = "expandUserNotesByDefault"
        static let appearanceMode = "appearanceMode"
        static let thumbnailDisplayMode = "thumbnailDisplayMode"
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
        thumbnailDisplayMode = .fit
    }
}

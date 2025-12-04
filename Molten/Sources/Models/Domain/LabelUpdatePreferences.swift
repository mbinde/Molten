//
//  LabelUpdatePreferences.swift
//  Molten
//
//  User preferences and state tracking for label database updates
//

import Foundation
import Combine

/// Preferences and state for label database updates
@MainActor
class LabelUpdatePreferences: ObservableObject {

    static let shared = LabelUpdatePreferences()

    private let defaults = UserDefaults.standard
    private let notificationCenter = NotificationCenter.default

    // MARK: - Keys

    private enum Keys {
        static let currentVersion = "labels.currentVersion"
        static let lastUpdateCheck = "labels.lastUpdateCheck"
        static let lastSuccessfulUpdate = "labels.lastSuccessfulUpdate"
        static let labelSource = "labels.source"
        static let hasUpdateAvailable = "labels.hasUpdateAvailable"
    }

    // MARK: - Published Properties

    @Published var hasUpdateAvailable: Bool {
        didSet {
            defaults.set(hasUpdateAvailable, forKey: Keys.hasUpdateAvailable)
            notificationCenter.post(name: .labelPreferencesChanged, object: nil)
        }
    }

    // MARK: - Non-Published Properties

    /// Current label database version (nil if pre-versioning or never updated)
    var currentLabelVersion: Int? {
        get {
            let value = defaults.integer(forKey: Keys.currentVersion)
            // UserDefaults returns 0 for missing keys, so we use a sentinel
            // We store version + 1, and subtract 1 when reading (0 means nil)
            return value > 0 ? value - 1 : nil
        }
        set {
            if let version = newValue {
                defaults.set(version + 1, forKey: Keys.currentVersion)
            } else {
                defaults.removeObject(forKey: Keys.currentVersion)
            }
            objectWillChange.send()
        }
    }

    var lastUpdateCheck: Date? {
        get { defaults.object(forKey: Keys.lastUpdateCheck) as? Date }
        set {
            defaults.set(newValue, forKey: Keys.lastUpdateCheck)
            objectWillChange.send()
        }
    }

    var lastSuccessfulUpdate: Date? {
        get { defaults.object(forKey: Keys.lastSuccessfulUpdate) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastSuccessfulUpdate) }
    }

    var labelSource: LabelSource {
        get {
            guard let rawValue = defaults.string(forKey: Keys.labelSource),
                  let source = LabelSource(rawValue: rawValue) else {
                return .bundled
            }
            return source
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.labelSource)
            objectWillChange.send()
        }
    }

    enum LabelSource: String {
        case bundled = "Bundled"
        case downloaded = "Downloaded"
    }

    // MARK: - Initialization

    private init() {
        self.hasUpdateAvailable = defaults.bool(forKey: Keys.hasUpdateAvailable)
    }

    // MARK: - Helpers

    /// Check if we should check for label updates
    /// Uses the same frequency as catalog updates for simplicity
    func shouldCheckForUpdates() -> Bool {
        // If we have no version at all, we should definitely check
        guard currentLabelVersion != nil else {
            return true
        }

        guard let lastCheck = lastUpdateCheck else {
            return true  // Never checked
        }

        // Use catalog update frequency for consistency
        let frequency = CatalogUpdatePreferences.shared.updateFrequency
        let timeSinceLastCheck = Date().timeIntervalSince(lastCheck)
        return timeSinceLastCheck >= frequency.checkInterval
    }

    /// Whether the current labels database is unversioned (needs immediate update)
    var needsInitialVersionedUpdate: Bool {
        return currentLabelVersion == nil
    }

    /// Reset preferences to defaults
    func resetToDefaults() {
        currentLabelVersion = nil
        lastUpdateCheck = nil
        lastSuccessfulUpdate = nil
        labelSource = .bundled
        hasUpdateAvailable = false
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let labelPreferencesChanged = Notification.Name("labelPreferencesChanged")
    static let labelUpdateAvailable = Notification.Name("labelUpdateAvailable")
    static let labelUpdateCompleted = Notification.Name("labelUpdateCompleted")
    static let labelUpdateFailed = Notification.Name("labelUpdateFailed")
}

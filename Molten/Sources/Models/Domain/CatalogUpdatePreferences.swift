//
//  CatalogUpdatePreferences.swift
//  Molten
//
//  Created by Assistant on 11/8/25.
//  User preferences for catalog updates
//

import Foundation
import Combine

/// User preferences for catalog updates
@MainActor
class CatalogUpdatePreferences: ObservableObject {

    static let shared = CatalogUpdatePreferences()

    private let defaults = UserDefaults.standard
    private let notificationCenter = NotificationCenter.default

    // MARK: - Settings

    enum DownloadPolicy: String, Codable, CaseIterable {
        case wifiOnly = "WiFi Only"
        case wifiAndCellular = "WiFi & Cellular"
        case manual = "Manual Only"

        func allowsDownload(isOnWiFi: Bool) -> Bool {
            switch self {
            case .wifiOnly:
                return isOnWiFi
            case .wifiAndCellular:
                return true
            case .manual:
                return false
            }
        }

        var description: String {
            switch self {
            case .wifiOnly:
                return "Download updates only when connected to WiFi"
            case .wifiAndCellular:
                return "Download updates on WiFi or cellular"
            case .manual:
                return "Never download automatically"
            }
        }
    }

    enum UpdateFrequency: String, Codable, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"

        var checkInterval: TimeInterval {
            switch self {
            case .daily:
                return 86400  // 24 hours
            case .weekly:
                return 604800  // 7 days
            case .monthly:
                return 2592000  // 30 days
            }
        }
    }

    // MARK: - Published Properties

    @Published var autoUpdateEnabled: Bool {
        didSet {
            defaults.set(autoUpdateEnabled, forKey: Keys.autoUpdate)
            notificationCenter.post(name: .catalogPreferencesChanged, object: nil)
        }
    }

    @Published var downloadPolicy: DownloadPolicy {
        didSet {
            defaults.set(downloadPolicy.rawValue, forKey: Keys.downloadPolicy)
            notificationCenter.post(name: .catalogPreferencesChanged, object: nil)
        }
    }

    @Published var updateFrequency: UpdateFrequency {
        didSet {
            defaults.set(updateFrequency.rawValue, forKey: Keys.updateFrequency)
            notificationCenter.post(name: .catalogPreferencesChanged, object: nil)
        }
    }

    @Published var hasUpdateAvailable: Bool {
        didSet {
            defaults.set(hasUpdateAvailable, forKey: Keys.hasUpdateAvailable)
            notificationCenter.post(name: .catalogPreferencesChanged, object: nil)
        }
    }

    // MARK: - Non-Published Properties

    var lastUpdateCheck: Date? {
        get { defaults.object(forKey: Keys.lastUpdateCheck) as? Date }
        set {
            defaults.set(newValue, forKey: Keys.lastUpdateCheck)
            objectWillChange.send()
        }
    }

    var currentCatalogVersion: Int {
        get { defaults.integer(forKey: Keys.currentVersion) }
        set {
            defaults.set(newValue, forKey: Keys.currentVersion)
            objectWillChange.send()
        }
    }

    var lastSuccessfulUpdate: Date? {
        get { defaults.object(forKey: Keys.lastSuccessfulUpdate) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastSuccessfulUpdate) }
    }

    var catalogSource: CatalogSource {
        get {
            guard let rawValue = defaults.string(forKey: Keys.catalogSource),
                  let source = CatalogSource(rawValue: rawValue) else {
                return .bundled
            }
            return source
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.catalogSource)
            objectWillChange.send()
        }
    }

    enum CatalogSource: String {
        case bundled = "Bundled"
        case downloaded = "Downloaded"
        case unknown = "Unknown"
    }

    // MARK: - Keys

    private enum Keys {
        static let autoUpdate = "catalog.autoUpdate"
        static let downloadPolicy = "catalog.downloadPolicy"
        static let updateFrequency = "catalog.updateFrequency"
        static let hasUpdateAvailable = "catalog.hasUpdateAvailable"
        static let lastUpdateCheck = "catalog.lastUpdateCheck"
        static let currentVersion = "catalog.currentVersion"
        static let lastSuccessfulUpdate = "catalog.lastSuccessfulUpdate"
        static let catalogSource = "catalog.source"
    }

    // MARK: - Initialization

    private init() {
        // Load settings with defaults
        self.autoUpdateEnabled = defaults.bool(forKey: Keys.autoUpdate)

        if let policyRaw = defaults.string(forKey: Keys.downloadPolicy),
           let policy = DownloadPolicy(rawValue: policyRaw) {
            self.downloadPolicy = policy
        } else {
            self.downloadPolicy = .wifiOnly  // Default
        }

        if let frequencyRaw = defaults.string(forKey: Keys.updateFrequency),
           let frequency = UpdateFrequency(rawValue: frequencyRaw) {
            self.updateFrequency = frequency
        } else {
            self.updateFrequency = .weekly  // Default
        }

        self.hasUpdateAvailable = defaults.bool(forKey: Keys.hasUpdateAvailable)
    }

    // MARK: - Helpers

    /// Check if enough time has passed for next update check
    func shouldCheckForUpdates() -> Bool {
        guard let lastCheck = lastUpdateCheck else {
            return true  // Never checked
        }

        let timeSinceLastCheck = Date().timeIntervalSince(lastCheck)
        return timeSinceLastCheck >= updateFrequency.checkInterval
    }

    /// Reset all preferences to defaults
    func resetToDefaults() {
        autoUpdateEnabled = false
        downloadPolicy = .wifiOnly
        updateFrequency = .weekly
        hasUpdateAvailable = false
        lastUpdateCheck = nil
        lastSuccessfulUpdate = nil
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let catalogPreferencesChanged = Notification.Name("catalogPreferencesChanged")
    static let catalogUpdateAvailable = Notification.Name("catalogUpdateAvailable")
    static let catalogUpdateCompleted = Notification.Name("catalogUpdateCompleted")
    static let catalogUpdateFailed = Notification.Name("catalogUpdateFailed")
}

//
//  StockUpdatePreferences.swift
//  Molten
//
//  User preferences and state tracking for stock database updates
//

import Foundation
import Combine

/// User preferences and state tracking for stock database updates
/// Stock updates check every 6 hours (hardcoded, simpler than catalog)
@MainActor
class StockUpdatePreferences: ObservableObject {

    static let shared = StockUpdatePreferences()

    private let defaults = UserDefaults.standard

    /// Fixed check interval of 6 hours for stock updates
    static let checkInterval: TimeInterval = 6 * 3600  // 6 hours

    // MARK: - Properties

    /// Current stock database version (0 = no database downloaded yet)
    var currentVersion: Int {
        get { defaults.integer(forKey: Keys.currentVersion) }
        set {
            defaults.set(newValue, forKey: Keys.currentVersion)
            objectWillChange.send()
        }
    }

    /// When we last checked for updates
    var lastUpdateCheck: Date? {
        get { defaults.object(forKey: Keys.lastUpdateCheck) as? Date }
        set {
            defaults.set(newValue, forKey: Keys.lastUpdateCheck)
            objectWillChange.send()
        }
    }

    /// When we last successfully downloaded and installed an update
    var lastSuccessfulUpdate: Date? {
        get { defaults.object(forKey: Keys.lastSuccessfulUpdate) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastSuccessfulUpdate) }
    }

    // MARK: - Keys

    private enum Keys {
        static let currentVersion = "stock.currentVersion"
        static let lastUpdateCheck = "stock.lastUpdateCheck"
        static let lastSuccessfulUpdate = "stock.lastSuccessfulUpdate"
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Helpers

    /// Check if enough time has passed for next update check (6 hours)
    func shouldCheckForUpdates() -> Bool {
        guard let lastCheck = lastUpdateCheck else {
            return true  // Never checked
        }

        let timeSinceLastCheck = Date().timeIntervalSince(lastCheck)
        return timeSinceLastCheck >= Self.checkInterval
    }

    /// Whether we have a stock database downloaded
    var hasStockDatabase: Bool {
        currentVersion > 0
    }
}

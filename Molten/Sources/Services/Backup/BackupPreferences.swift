//
//  BackupPreferences.swift
//  Molten
//
//  Stores backup preferences and state in UserDefaults
//  Tracks backup key, last backup timestamps, and checksums
//

import Foundation

/// Manages backup preferences and state
@MainActor
final class BackupPreferences {

    // MARK: - Constants

    private static let keyBackupKey = "molten.backup.backupKey"
    private static let keyLastBackupTimestamp = "molten.backup.lastBackupTimestamp"
    private static let keyLastInventoryChecksum = "molten.backup.lastInventoryChecksum"
    private static let keyLastTagsChecksum = "molten.backup.lastTagsChecksum"
    private static let keyBackupEnabled = "molten.backup.enabled"

    // MARK: - Properties

    private let userDefaults: UserDefaults

    // MARK: - Initialization

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Backup Key

    /// The registered backup key (nil if backups not set up)
    var backupKey: String? {
        get { userDefaults.string(forKey: Self.keyBackupKey) }
        set { userDefaults.set(newValue, forKey: Self.keyBackupKey) }
    }

    // MARK: - Enabled State

    /// Whether automatic backups are enabled
    var isEnabled: Bool {
        get { userDefaults.bool(forKey: Self.keyBackupEnabled) }
        set { userDefaults.set(newValue, forKey: Self.keyBackupEnabled) }
    }

    // MARK: - Last Backup Timestamp

    /// Timestamp of the last successful backup
    var lastBackupTimestamp: Date? {
        get { userDefaults.object(forKey: Self.keyLastBackupTimestamp) as? Date }
        set { userDefaults.set(newValue, forKey: Self.keyLastBackupTimestamp) }
    }

    /// Hours since last backup (nil if never backed up)
    var hoursSinceLastBackup: Double? {
        guard let lastBackup = lastBackupTimestamp else { return nil }
        return Date().timeIntervalSince(lastBackup) / 3600.0
    }

    // MARK: - Checksums

    /// Checksum of last backed up inventory data
    var lastInventoryChecksum: String? {
        get { userDefaults.string(forKey: Self.keyLastInventoryChecksum) }
        set { userDefaults.set(newValue, forKey: Self.keyLastInventoryChecksum) }
    }

    /// Checksum of last backed up tags data
    var lastTagsChecksum: String? {
        get { userDefaults.string(forKey: Self.keyLastTagsChecksum) }
        set { userDefaults.set(newValue, forKey: Self.keyLastTagsChecksum) }
    }

    // MARK: - Reset

    /// Clear all backup preferences (for disabling backups or testing)
    func reset() {
        userDefaults.removeObject(forKey: Self.keyBackupKey)
        userDefaults.removeObject(forKey: Self.keyLastBackupTimestamp)
        userDefaults.removeObject(forKey: Self.keyLastInventoryChecksum)
        userDefaults.removeObject(forKey: Self.keyLastTagsChecksum)
        userDefaults.removeObject(forKey: Self.keyBackupEnabled)
    }
}

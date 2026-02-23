//
//  NotificationNames.swift
//  Molten
//
//  Shared notification names used throughout the app
//

import Foundation

extension Notification.Name {
    /// Posted when COE filter selection changes
    nonisolated static let coeSelectionChanged = Notification.Name("coeSelectionChanged")

    /// Posted when CloudKit import completes successfully
    /// Views should refresh their data when this fires
    nonisolated static let cloudKitImportCompleted = Notification.Name("cloudKitImportCompleted")

    /// Posted when user wants to search for items with a similar color
    /// userInfo should contain "color" key with hex color string
    nonisolated static let findSimilarColors = Notification.Name("findSimilarColors")
}

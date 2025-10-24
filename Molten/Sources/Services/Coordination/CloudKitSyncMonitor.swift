//
//  CloudKitSyncMonitor.swift
//  Molten
//
//  Service for monitoring CloudKit sync status and publishing events to the UI
//

import Foundation
import CoreData
import Combine
import CloudKit

/// CloudKit sync status
enum CloudKitSyncStatus: Equatable {
    case idle
    case syncing
    case succeeded
    case failed(Error)
    case quotaExceeded
    case offline

    static func == (lhs: CloudKitSyncStatus, rhs: CloudKitSyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing), (.succeeded, .succeeded), (.quotaExceeded, .quotaExceeded), (.offline, .offline):
            return true
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }

    var isError: Bool {
        if case .failed = self { return true }
        if case .quotaExceeded = self { return true }
        return false
    }
}

/// CloudKit sync event details
struct CloudKitSyncEvent {
    let status: CloudKitSyncStatus
    let timestamp: Date
    let isImport: Bool
    let errorMessage: String?

    init(status: CloudKitSyncStatus, isImport: Bool = true) {
        self.status = status
        self.timestamp = Date()
        self.isImport = isImport

        switch status {
        case .failed(let error):
            self.errorMessage = error.localizedDescription
        case .quotaExceeded:
            self.errorMessage = "iCloud storage quota exceeded"
        case .offline:
            self.errorMessage = "Device is offline"
        default:
            self.errorMessage = nil
        }
    }
}

/// Monitors CloudKit sync status and publishes events
@MainActor
class CloudKitSyncMonitor: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var currentStatus: CloudKitSyncStatus = .idle
    @Published private(set) var lastSyncEvent: CloudKitSyncEvent?
    @Published private(set) var isOnline: Bool = true

    // MARK: - Private Properties

    private let container: NSPersistentCloudKitContainer
    nonisolated(unsafe) private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(container: NSPersistentCloudKitContainer) {
        self.container = container
        setupNotificationObservers()
    }

    // MARK: - Setup

    nonisolated private func setupNotificationObservers() {
        // Observe CloudKit events
        NotificationCenter.default.publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
            .compactMap { notification -> (Bool, Date?, Error?)? in
                guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else {
                    return nil
                }
                // Extract only the Sendable data we need
                let isImport = event.type == .import
                return (isImport, event.endDate, event.error)
            }
            .sink { [weak self] eventData in
                let (isImport, endDate, error) = eventData
                Task { @MainActor [weak self] in
                    await self?.handleCloudKitEventData(isImport: isImport, endDate: endDate, error: error)
                }
            }
            .store(in: &cancellables)

        // Observe network reachability changes (using simple approach)
        NotificationCenter.default.publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.updateOnlineStatus()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Event Handling

    private func handleCloudKitEventData(isImport: Bool, endDate: Date?, error: Error?) {
        if endDate != nil {
            // Event completed
            if let error = error {
                handleSyncError(error, isImport: isImport)
            } else {
                handleSyncSuccess(isImport: isImport)
            }
        } else {
            // Event started
            handleSyncStarted(isImport: isImport)
        }
    }

    // Legacy method kept for compatibility
    private func handleCloudKitEvent(_ event: NSPersistentCloudKitContainer.Event) {
        let isImport = event.type == .import
        handleCloudKitEventData(isImport: isImport, endDate: event.endDate, error: event.error)
    }

    private func handleSyncStarted(isImport: Bool) {
        currentStatus = .syncing
        isOnline = true
    }

    private func handleSyncSuccess(isImport: Bool) {
        currentStatus = .succeeded
        lastSyncEvent = CloudKitSyncEvent(status: .succeeded, isImport: isImport)
        isOnline = true

        // Auto-reset to idle after 2 seconds
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if currentStatus == .succeeded {
                currentStatus = .idle
            }
        }
    }

    private func handleSyncError(_ error: Error, isImport: Bool) {
        // Check for CloudKit-specific errors
        let nsError = error as NSError
        if nsError.domain == CKError.errorDomain {
            // Check for quota exceeded
            if nsError.code == CKError.Code.quotaExceeded.rawValue {
                currentStatus = .quotaExceeded
                lastSyncEvent = CloudKitSyncEvent(status: .quotaExceeded, isImport: isImport)
                return
            }

            // Check for network errors
            if nsError.code == CKError.Code.networkUnavailable.rawValue ||
               nsError.code == CKError.Code.networkFailure.rawValue {
                currentStatus = .offline
                lastSyncEvent = CloudKitSyncEvent(status: .offline, isImport: isImport)
                isOnline = false
                return
            }
        }

        // Generic error
        currentStatus = .failed(error)
        lastSyncEvent = CloudKitSyncEvent(status: .failed(error), isImport: isImport)
    }

    private func updateOnlineStatus() {
        // Simple heuristic: if we're syncing or succeeded recently, we're online
        isOnline = currentStatus == .syncing || currentStatus == .succeeded || currentStatus == .idle
    }

    // MARK: - Public Methods

    /// User-friendly status message
    var statusMessage: String {
        switch currentStatus {
        case .idle:
            return "Up to date"
        case .syncing:
            return "Syncing..."
        case .succeeded:
            return "Sync complete"
        case .failed(let error):
            return "Sync failed: \(error.localizedDescription)"
        case .quotaExceeded:
            return "iCloud storage full"
        case .offline:
            return "Offline"
        }
    }

    /// Whether to show an alert to the user
    var shouldShowAlert: Bool {
        currentStatus.isError
    }
}

//
//  CloudKitSyncStatusView.swift
//  Molten
//
//  UI component showing CloudKit sync status
//

import SwiftUI
import CoreData

/// Displays CloudKit sync status in the UI
struct CloudKitSyncStatusView: View {

    @ObservedObject var monitor: CloudKitSyncMonitor
    @State private var showAlert = false

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            statusIcon
            Text(monitor.statusMessage)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, DesignSystem.Padding.compact)
        .padding(.vertical, DesignSystem.Padding.compact / 2)
        .background(statusBackgroundColor)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .opacity(shouldShow ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.3), value: shouldShow)
        .alert("Sync Error", isPresented: $showAlert, presenting: monitor.lastSyncEvent) { event in
            Button("OK", role: .cancel) {}
        } message: { event in
            if let errorMessage = event.errorMessage {
                Text(errorMessage)
            }
        }
        .onChange(of: monitor.shouldShowAlert) { _, shouldShowAlert in
            if shouldShowAlert {
                showAlert = true
            }
        }
    }

    // MARK: - UI Helpers

    private var shouldShow: Bool {
        // Only show for actionable errors that require user attention
        // Don't show for normal syncing or temporary network issues
        switch monitor.currentStatus {
        case .idle, .syncing, .succeeded, .offline:
            return false
        case .failed, .quotaExceeded:
            return true
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch monitor.currentStatus {
        case .idle:
            Image(systemName: "checkmark.icloud")
        case .syncing:
            ProgressView()
                .controlSize(.small)
        case .succeeded:
            Image(systemName: "checkmark.icloud.fill")
        case .failed:
            Image(systemName: "exclamationmark.icloud")
        case .quotaExceeded:
            Image(systemName: "externaldrive.fill.badge.exclamationmark")
        case .offline:
            Image(systemName: "wifi.slash")
        }
    }

    private var statusColor: Color {
        switch monitor.currentStatus {
        case .idle, .succeeded:
            return DesignSystem.Colors.textSecondary
        case .syncing:
            return DesignSystem.Colors.accentPrimary
        case .failed, .quotaExceeded:
            return .red
        case .offline:
            return .orange
        }
    }

    private var statusBackgroundColor: Color {
        switch monitor.currentStatus {
        case .idle, .succeeded, .syncing:
            return DesignSystem.Colors.backgroundSecondary
        case .failed, .quotaExceeded:
            return Color.red.opacity(0.1)
        case .offline:
            return Color.orange.opacity(0.1)
        }
    }
}

// MARK: - Compact Variant

/// Compact variant showing just an icon
struct CloudKitSyncStatusIconView: View {

    @ObservedObject var monitor: CloudKitSyncMonitor

    var body: some View {
        Group {
            switch monitor.currentStatus {
            case .idle:
                Image(systemName: "checkmark.icloud")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            case .syncing:
                ProgressView()
                    .controlSize(.small)
            case .succeeded:
                Image(systemName: "checkmark.icloud.fill")
                    .foregroundColor(DesignSystem.Colors.accentPrimary)
            case .failed, .quotaExceeded:
                Image(systemName: "exclamationmark.icloud")
                    .foregroundColor(.red)
            case .offline:
                Image(systemName: "wifi.slash")
                    .foregroundColor(.orange)
            }
        }
        .font(.caption)
    }
}

// MARK: - Preview

#Preview("Sync Status") {
    let controller = PersistenceController.preview
    // Preview controller uses CloudKit variant for UI compatibility
    let monitor = CloudKitSyncMonitor(container: controller.container as! NSPersistentCloudKitContainer)
    CloudKitSyncStatusView(monitor: monitor)
        .padding()
}

#Preview("Sync Status Icon") {
    let controller = PersistenceController.preview
    // Preview controller uses CloudKit variant for UI compatibility
    let monitor = CloudKitSyncMonitor(container: controller.container as! NSPersistentCloudKitContainer)
    HStack {
        CloudKitSyncStatusIconView(monitor: monitor)
        Text("Settings")
    }
    .padding()
}

//
//  InventorySharingView.swift
//  Molten
//
//  Main view for inventory sharing feature
//

import SwiftUI
import Combine

struct InventorySharingView: View {

    @State private var viewModel = InventorySharingViewModel()
    @State private var friendToDelete: FriendShare?
    @State private var showingDeleteConfirmation = false
    @State private var myShareExpanded = false
    @State private var expiringSharesExpanded = false
    @State private var friendsExpanded = false
    @State private var hasLoadedInitialData = false

    /// Optional share code to pre-fill when adding a friend (e.g., from QR code deep link)
    let pendingShareCode: String?

    init(pendingShareCode: String? = nil) {
        self.pendingShareCode = pendingShareCode
    }

    var body: some View {
        NavigationStack {
            List {
                myShareSection
                expiringSharesSection
                friendsSection
            }
            .navigationTitle("Inventory Sharing")
            .task {
                await viewModel.onAppear()
                hasLoadedInitialData = true

                // If we have a pending share code from deep link, pre-fill and show add friend sheet
                if let shareCode = pendingShareCode {
                    viewModel.friendShareCode = shareCode
                    viewModel.showingAddFriend = true
                }
            }
            .onAppear {
                // Refresh friend list when returning from viewing a friend's inventory
                // This ensures cached stats (item count, total quantity, weight) are displayed
                if hasLoadedInitialData {
                    viewModel.refreshFriendList()
                }
            }
            .onChange(of: viewModel.myShareCode) { oldValue, newValue in
                // Only auto-expand if share code changed from nil to a value AFTER initial load
                // This ensures we expand when creating a new share, but not when loading an existing one
                if hasLoadedInitialData && oldValue == nil && newValue != nil {
                    myShareExpanded = true
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .sheet(isPresented: $viewModel.showingCreateShare) {
                CreateShareView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingEditMetadata) {
                EditShareMetadataView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingAddFriend) {
                AddFriendView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingCustomizeFriend) {
                if let friend = viewModel.selectedFriendForCustomization {
                    CustomizeFriendView(friend: friend, viewModel: viewModel)
                }
            }
            .sheet(isPresented: $viewModel.showingCreateExpiringShare) {
                CreateExpiringShareView(viewModel: viewModel)
            }
            .alert("Delete Friend?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    friendToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let friend = friendToDelete {
                        viewModel.removeFriend(friend)
                    }
                    friendToDelete = nil
                }
            } message: {
                if let friend = friendToDelete {
                    let name = friend.nickname?.isEmpty == false ? friend.nickname! : friend.friendName
                    Text("Are you sure you want to remove \(name) from your friends list?")
                }
            }
        }
    }

    // MARK: - My Share Section

    private var myShareSection: some View {
        Section {
            if let shareCode = viewModel.myShareCode {
                // Header row using CollapsibleSectionHeader pattern
                Button(action: { withAnimation { myShareExpanded.toggle() } }) {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: myShareExpanded ? "chevron.down" : "chevron.right")
                            .font(DesignSystem.Typography.listItemCaption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .frame(width: 12)

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                            Text("My Inventory")
                                .font(DesignSystem.Typography.listItemTitle)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            Text(myShareExpanded ? "Tap to collapse" : "Tap to show share code")
                                .font(DesignSystem.Typography.listItemCaption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        Spacer()

                        // Show share code preview when collapsed
                        if !myShareExpanded {
                            Text(shareCode.formattedShareCode)
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("inventory_sharing_my_inventory_toggle")

                if myShareExpanded {
                    // Share code display with actions
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        HStack {
                            Text(shareCode.formattedShareCode)
                                .font(.system(.title, design: .monospaced))
                                .fontWeight(DesignSystem.FontWeight.bold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)

                            Button {
                                viewModel.copyShareCode()
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(DesignSystem.Colors.moltenOrange)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityIdentifier("inventory_sharing_copy_code")

                            Spacer()

                            Button {
                                shareDeepLink(shareCode: shareCode.unformattedShareCode)
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(DesignSystem.Colors.moltenOrange)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityIdentifier("inventory_sharing_share_code")
                        }

                        // QR Code for easy scanning
                        let deepLinkURL = "molten://inventory/\(shareCode.unformattedShareCode)"
                        if let qrImage = generateQRCode(from: deepLinkURL) {
                            HStack {
                                Spacer()
                                Image(uiImage: qrImage)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 200, height: 200)
                                    .cornerRadius(DesignSystem.CornerRadius.medium)
                                Spacer()
                            }
                            .padding(.vertical, DesignSystem.Spacing.sm)
                        }
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)

                    // Metadata display
                    if let metadata = viewModel.myShareMetadata {
                        HStack {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                                Text("Display Name: \(metadata.displayName)")
                                    .font(DesignSystem.Typography.listItemSubtitle)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)

                                if let notes = metadata.shareNotes {
                                    Text("Notes: \(notes)")
                                        .font(DesignSystem.Typography.listItemCaption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                }
                            }

                            Spacer()

                            Button {
                                viewModel.showingEditMetadata = true
                            } label: {
                                Image(systemName: "pencil")
                                    .foregroundColor(DesignSystem.Colors.moltenOrange)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityIdentifier("inventory_sharing_edit_metadata")
                        }
                        .padding(.vertical, DesignSystem.Spacing.xs)
                    }

                    // Refresh action
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Button {
                            Task {
                                await viewModel.refreshMyShare()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Update Inventory on Server")
                            }
                            .font(DesignSystem.Typography.listItemSubtitle)
                        }
                        .disabled(viewModel.isLoading)
                        .accessibilityIdentifier("inventory_sharing_refresh")

                        Text("Re-uploads your inventory to update what friends see. Auto-refreshes every 24 hours when you open the app.")
                            .font(DesignSystem.Typography.listItemCaption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .padding(.leading, DesignSystem.Spacing.xl)
                    }

                    // Delete action
                    Button(role: .destructive) {
                        Task {
                            await viewModel.deleteMyShare()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Share")
                        }
                        .font(DesignSystem.Typography.listItemSubtitle)
                        .foregroundColor(DesignSystem.Colors.accentDanger)
                    }
                    .disabled(viewModel.isLoading)
                    .accessibilityIdentifier("inventory_sharing_delete")
                }

            } else {
                // No share code - show clickable row to create
                Button(action: { viewModel.showingCreateShare = true }) {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .foregroundColor(DesignSystem.Colors.moltenOrange)
                            .frame(width: 44, height: 44)
                            .background(DesignSystem.Colors.moltenOrange.opacity(0.1))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                            Text("Share My Inventory")
                                .font(DesignSystem.Typography.listItemTitle)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            Text("Let friends see what glass you have")
                                .font(DesignSystem.Typography.listItemSubtitle)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(DesignSystem.Typography.listItemCaption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helper Functions

    private func generateQRCode(from string: String) -> UIImage? {
        let data = string.data(using: .utf8)

        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let ciImage = filter.outputImage else { return nil }

        // Scale up the QR code for better quality
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledCIImage = ciImage.transformed(by: transform)

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledCIImage, from: scaledCIImage.extent) else { return nil }

        return UIImage(cgImage: cgImage)
    }

    private func shareDeepLink(shareCode: String) {
        let deepLinkURL = "molten://inventory/\(shareCode)"
        let activityViewController = UIActivityViewController(
            activityItems: [deepLinkURL],
            applicationActivities: nil
        )

        // Get the window scene and present the share sheet
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            // Find the topmost view controller
            var topController = rootViewController
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            activityViewController.popoverPresentationController?.sourceView = topController.view
            topController.present(activityViewController, animated: true)
        }
    }

    // MARK: - Expiring Shares Section

    private var expiringSharesSection: some View {
        Section {
            if viewModel.myShareCode != nil {
                // Header row using CollapsibleSectionHeader pattern
                Button(action: { withAnimation { expiringSharesExpanded.toggle() } }) {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: expiringSharesExpanded ? "chevron.down" : "chevron.right")
                            .font(DesignSystem.Typography.listItemCaption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .frame(width: 12)

                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        Text("Temporary Shares")
                            .font(DesignSystem.Typography.listItemTitle)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        Spacer()

                        Text("\(viewModel.expiringShares.count) active")
                            .font(DesignSystem.Typography.listItemCaption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("inventory_sharing_temporary_toggle")

                if expiringSharesExpanded {
                    ForEach(viewModel.expiringShares) { share in
                        ExpiringShareRowView(share: share, viewModel: viewModel)
                    }

                    Button {
                        viewModel.showingCreateExpiringShare = true
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(DesignSystem.Colors.moltenOrange)
                            Text("Create Temporary Share")
                                .font(DesignSystem.Typography.listItemSubtitle)
                        }
                    }
                    .accessibilityIdentifier("inventory_sharing_create_temporary")
                }
            }
        }
    }

    // MARK: - Friends Section

    private var friendsSection: some View {
        Section {
            if viewModel.friendShares.isEmpty {
                // Empty state
                VStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "person.2")
                        .font(.system(size: 40))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .padding(.bottom, DesignSystem.Spacing.xs)

                    Text("No Friends Yet")
                        .font(DesignSystem.Typography.listItemTitle)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text("Add friends to view their glass inventory")
                        .font(DesignSystem.Typography.listItemSubtitle)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)

                    Button {
                        viewModel.showingAddFriend = true
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "person.badge.plus")
                            Text("Add Friend")
                        }
                        .font(DesignSystem.Typography.listItemSubtitle)
                        .fontWeight(DesignSystem.FontWeight.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.moltenOrange)
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("inventory_sharing_add_friend")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.lg)

            } else {
                ForEach(viewModel.friendShares) { friend in
                    NavigationLink {
                        FriendInventoryView(friend: friend)
                    } label: {
                        FriendRowView(friend: friend)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            friendToDelete = friend
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .accessibilityIdentifier("inventory_sharing_friend_delete_swipe")
                    }
                    .contextMenu {
                        Button {
                            viewModel.selectedFriendForCustomization = friend
                            viewModel.showingCustomizeFriend = true
                        } label: {
                            Label("Customize", systemImage: "slider.horizontal.3")
                        }
                        .accessibilityIdentifier("inventory_sharing_friend_customize")

                        Button(role: .destructive) {
                            friendToDelete = friend
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .accessibilityIdentifier("inventory_sharing_friend_delete_context")
                    }
                }

                // Add friend button
                Button {
                    viewModel.showingAddFriend = true
                } label: {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(DesignSystem.Colors.moltenOrange)
                        Text("Add Friend")
                            .font(DesignSystem.Typography.listItemSubtitle)
                    }
                }
                .accessibilityIdentifier("inventory_sharing_add_friend")
            }
        } header: {
            Text("Friends")
        }
    }
}

// MARK: - Friend Row View

struct FriendRowView: View {
    let friend: FriendShare

    // Update timestamp every minute instead of every second
    @State private var currentTime = Date()

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var iconSymbol: String {
        friend.iconSymbol ?? FriendShare.defaultIconSymbol
    }

    private var iconBackground: Color {
        if let hex = friend.iconBackgroundHex {
            return Color(hex: hex)
        }
        return Color(hex: FriendShare.defaultIconBackgroundHex)
    }

    private var iconForeground: Color {
        if let hex = friend.iconForegroundHex {
            return Color(hex: hex)
        }
        return Color(hex: FriendShare.defaultIconForegroundHex)
    }

    private func timeUntilExpiration(_ expiresAt: Date) -> String {
        let seconds = expiresAt.timeIntervalSince(currentTime)

        // Already expired
        if seconds <= 0 {
            return "expired"
        }

        // Less than a minute
        if seconds < 60 {
            return "< 1 min"
        }

        // Minutes (1-59)
        if seconds < 3600 {
            let minutes = Int(seconds / 60)
            return "\(minutes) min"
        }

        // Hours (1-23)
        if seconds < 86400 {
            let hours = Int(seconds / 3600)
            return hours == 1 ? "1 hr" : "\(hours) hrs"
        }

        // Days
        let days = Int(seconds / 86400)
        return days == 1 ? "1 day" : "\(days) days"
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Icon
            Circle()
                .fill(iconBackground)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: iconSymbol)
                        .font(.title3)
                        .foregroundStyle(iconForeground)
                )

            // Friend info
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                if let nickname = friend.nickname, !nickname.isEmpty {
                    Text(nickname)
                        .font(DesignSystem.Typography.listItemTitle)
                    Text(friend.friendName)
                        .font(DesignSystem.Typography.listItemSubtitle)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                } else {
                    Text(friend.friendName)
                        .font(DesignSystem.Typography.listItemTitle)
                }

                // Share code on its own line
                Text(friend.shareCode.formattedShareCode)
                    .font(DesignSystem.Typography.listItemCaption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Spacer()

            // Trailing: Inventory stats badge (if available) and/or expiration badge
            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
                // Inventory stats (cached from last view)
                if let itemCount = friend.itemCount {
                    InventoryStatsBadge(
                        itemCount: itemCount,
                        totalQuantity: friend.totalQuantity,
                        totalWeight: friend.totalWeight
                    )
                }

                // Expiration badge
                if let expiresAt = friend.expiresAt {
                    ExpirationBadge(expiresAt: expiresAt, currentTime: currentTime)
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .onAppear {
            currentTime = Date()
        }
    }
}

// MARK: - Inventory Stats Badge

/// Displays cached inventory stats for a friend's inventory
struct InventoryStatsBadge: View {
    let itemCount: Int
    let totalQuantity: Double?
    let totalWeight: Double?

    private var formattedQuantity: String {
        guard let qty = totalQuantity, qty > 0 else { return "" }
        if qty.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", qty)
        } else {
            return String(format: "%.1f", qty)
        }
    }

    /// Format weight with appropriate unit (converting to lbs/kg if large enough)
    private var formattedWeight: String {
        guard let weight = totalWeight, weight > 0 else { return "" }

        let preferredUnit = WeightUnitPreference.current

        switch preferredUnit {
        case .ounces:
            // Convert to pounds if >= 16 oz
            if weight >= 16 {
                let pounds = weight / 16.0
                if pounds.truncatingRemainder(dividingBy: 1) == 0 {
                    return String(format: "%.0f lbs", pounds)
                } else {
                    return String(format: "%.1f lbs", pounds)
                }
            } else {
                if weight.truncatingRemainder(dividingBy: 1) == 0 {
                    return String(format: "%.0f oz", weight)
                } else {
                    return String(format: "%.1f oz", weight)
                }
            }
        case .grams:
            // Convert to kg if >= 1000 g
            if weight >= 1000 {
                let kg = weight / 1000.0
                if kg.truncatingRemainder(dividingBy: 1) == 0 {
                    return String(format: "%.0f kg", kg)
                } else {
                    return String(format: "%.1f kg", kg)
                }
            } else {
                if weight.truncatingRemainder(dividingBy: 1) == 0 {
                    return String(format: "%.0f g", weight)
                } else {
                    return String(format: "%.1f g", weight)
                }
            }
        }
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xxs) {
            // Unique item count (prominent)
            HStack(spacing: DesignSystem.Spacing.xxs) {
                Text("\(itemCount)")
                    .font(DesignSystem.Typography.prominentNumberSmall)
                    .fontWeight(DesignSystem.FontWeight.semibold)
                    .foregroundColor(DesignSystem.Colors.moltenTeal)

                Text(itemCount == 1 ? "item" : "items")
                    .font(DesignSystem.Typography.listItemCaptionSmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            // Total quantity (secondary) - only show if > 0
            if let qty = totalQuantity, qty > 0 {
                Text("\(formattedQuantity) qty")
                    .font(DesignSystem.Typography.listItemCaptionSmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            // Total weight (secondary) - only show if > 0
            if let weight = totalWeight, weight > 0 {
                Text(formattedWeight)
                    .font(DesignSystem.Typography.listItemCaptionSmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }
}

// MARK: - Expiration Badge

/// Displays time until expiration with appropriate color coding
struct ExpirationBadge: View {
    let expiresAt: Date
    let currentTime: Date

    private var isExpired: Bool {
        expiresAt < currentTime
    }

    private var isExpiringSoon: Bool {
        let hoursRemaining = expiresAt.timeIntervalSince(currentTime) / 3600
        return hoursRemaining > 0 && hoursRemaining < 24
    }

    private var timeString: String {
        let seconds = expiresAt.timeIntervalSince(currentTime)

        if seconds <= 0 {
            return "Expired"
        }

        if seconds < 3600 {
            let minutes = Int(seconds / 60)
            return "\(minutes)m"
        }

        if seconds < 86400 {
            let hours = Int(seconds / 3600)
            return "\(hours)h"
        }

        let days = Int(seconds / 86400)
        return "\(days)d"
    }

    private var displayColor: Color {
        if isExpired {
            return DesignSystem.Colors.accentDanger
        } else if isExpiringSoon {
            return DesignSystem.Colors.moltenAmber
        } else {
            return DesignSystem.Colors.textSecondary
        }
    }

    var body: some View {
        Text(isExpired ? "Expired" : "\(timeString) left")
            .font(DesignSystem.Typography.listItemCaptionSmall)
            .foregroundColor(displayColor)
    }
}

// MARK: - Expiring Share Row View

struct ExpiringShareRowView: View {
    let share: ExpiringShare
    @Bindable var viewModel: InventorySharingViewModel

    @State private var showingDeleteConfirmation = false
    @State private var currentTime = Date()

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Left side: Share info
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                // Display name as title
                Text(share.displayName)
                    .font(DesignSystem.Typography.listItemTitle)

                // Share code - monospaced with copy button
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text(share.shareCode.formattedShareCode)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Button {
                        viewModel.copyExpiringShareCode(share.shareCode)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(DesignSystem.Typography.listItemCaption)
                            .foregroundColor(DesignSystem.Colors.moltenOrange)
                    }
                    .buttonStyle(.borderless)
                }

                // Notes if present
                if let notes = share.shareNotes, !notes.isEmpty {
                    Text(notes)
                        .font(DesignSystem.Typography.listItemCaption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            // Right side: Time remaining badge + delete button
            HStack(spacing: DesignSystem.Spacing.md) {
                ExpirationBadge(expiresAt: share.expiresAt, currentTime: currentTime)

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(DesignSystem.Typography.listItemSubtitle)
                        .foregroundColor(DesignSystem.Colors.accentDanger)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .onAppear {
            currentTime = Date()
        }
        .alert("Delete Temporary Share?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteExpiringShare(share)
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(share.displayName)\"? The share code will stop working immediately.")
        }
    }
}

// MARK: - Preview

#Preview {
    InventorySharingView()
}

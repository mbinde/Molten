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
                // Header row (always visible)
                Button(action: { myShareExpanded.toggle() }) {
                    HStack {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("My Inventory")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Click to show your share code")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: myShareExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("inventory_sharing_my_inventory_toggle")

                if myShareExpanded {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        // Large share code display
                        HStack {
                            Text(shareCode.formattedShareCode)
                                .font(.system(.title, design: .monospaced))
                                .fontWeight(.bold)

                            Button {
                                viewModel.copyShareCode()
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityIdentifier("inventory_sharing_copy_code")

                            Spacer()

                            Button {
                                shareDeepLink(shareCode: shareCode.unformattedShareCode)
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityIdentifier("inventory_sharing_share_code")
                        }

                        // QR Code for easy scanning (deep link to add friend)
                        let deepLinkURL = "molten://inventory/\(shareCode.unformattedShareCode)"
                        if let qrImage = generateQRCode(from: deepLinkURL) {
                            HStack {
                                Spacer()
                                Image(uiImage: qrImage)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 200, height: 200)
                                Spacer()
                            }
                            .padding(.vertical, DesignSystem.Spacing.sm)
                        }
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)

                    if let metadata = viewModel.myShareMetadata {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            HStack {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                    Text("Display Name: \(metadata.displayName)")
                                        .font(.subheadline)

                                    if let notes = metadata.shareNotes {
                                        Text("Notes: \(notes)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                Button {
                                    viewModel.showingEditMetadata = true
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.borderless)
                                .accessibilityIdentifier("inventory_sharing_edit_metadata")
                            }
                        }
                        .padding(.vertical, DesignSystem.Spacing.xs)
                    }

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Button {
                            Task {
                                await viewModel.refreshMyShare()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Update Inventory on Server Immediately")
                            }
                        }
                        .disabled(viewModel.isLoading)
                        .accessibilityIdentifier("inventory_sharing_refresh")

                        Text("Re-uploads your current inventory to update what friends see. If you don't do this, it will refresh every 24 hours as long as you open the app during that time. All refreshes, whether automatic or manual, also reset the 90-day auto-deletion timer.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, DesignSystem.Spacing.md)
                    }

                    Button(role: .destructive) {
                        Task {
                            await viewModel.deleteMyShare()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Share")
                        }
                    }
                    .disabled(viewModel.isLoading)
                    .accessibilityIdentifier("inventory_sharing_delete")
                }

            } else {
                // No share code - show clickable row to create
                Button(action: { viewModel.showingCreateShare = true }) {
                    HStack {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("My Inventory")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Click to share your inventory")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "plus.circle")
                            .foregroundColor(.accentColor)
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
                // Header row (always visible)
                Button(action: { expiringSharesExpanded.toggle() }) {
                    HStack {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Temporary Shares")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("\(viewModel.expiringShares.count) active")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: expiringSharesExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if expiringSharesExpanded {
                    ForEach(viewModel.expiringShares) { share in
                        ExpiringShareRowView(share: share, viewModel: viewModel)
                    }

                    Button {
                        viewModel.showingCreateExpiringShare = true
                    } label: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("Create Temporary Share")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Friends Section

    private var friendsSection: some View {
        Section {
            if viewModel.friendShares.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("No Friends Yet")
                        .font(.headline)

                    Text("Add friends to view their glass inventory")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button {
                        viewModel.showingAddFriend = true
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Add Friend")
                        }
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.xs)

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
                    }
                    .contextMenu {
                        Button {
                            viewModel.selectedFriendForCustomization = friend
                            viewModel.showingCustomizeFriend = true
                        } label: {
                            Label("Customize", systemImage: "slider.horizontal.3")
                        }

                        Button(role: .destructive) {
                            friendToDelete = friend
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }

                Button {
                    viewModel.showingAddFriend = true
                } label: {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("Add Friend")
                    }
                }
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

    private var relativeTimeString: String {
        guard let lastRefreshed = friend.lastRefreshed else { return "" }
        let seconds = currentTime.timeIntervalSince(lastRefreshed)

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

        // Days (1-6)
        if seconds < 604800 {
            let days = Int(seconds / 86400)
            return days == 1 ? "1 day" : "\(days) days"
        }

        // Weeks
        let weeks = Int(seconds / 604800)
        return weeks == 1 ? "1 week" : "\(weeks) weeks"
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
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                if let nickname = friend.nickname, !nickname.isEmpty {
                    Text(nickname)
                        .font(.headline)
                    Text(friend.friendName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text(friend.friendName)
                        .font(.headline)
                }

                HStack {
                    Text(friend.shareCode.formattedShareCode)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // All shares have expiration times (90 days for regular, 7 days for temporary)
                    if let expiresAt = friend.expiresAt {
                        Text("•")
                            .foregroundColor(.secondary)
                        if expiresAt < currentTime {
                            Text("Expired")
                                .font(.caption)
                                .foregroundColor(.red)
                        } else {
                            Text("Expires in \(timeUntilExpiration(expiresAt))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
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

// MARK: - Expiring Share Row View

struct ExpiringShareRowView: View {
    let share: ExpiringShare
    @Bindable var viewModel: InventorySharingViewModel

    @State private var showingDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    // Share code - large and bold at top
                    HStack {
                        Text(share.shareCode.formattedShareCode)
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.bold)

                        Button {
                            viewModel.copyExpiringShareCode(share.shareCode)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                    }

                    // Display name
                    Text(share.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if let notes = share.shareNotes {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    HStack {
                        Image(systemName: share.isExpired ? "clock.badge.xmark" : "clock")
                            .font(.caption)
                            .foregroundColor(share.isExpired ? .red : .secondary)

                        Text(share.expirationDisplayString)
                            .font(.caption)
                            .foregroundColor(share.isExpired ? .red : .secondary)
                    }
                }

                Spacer()

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
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

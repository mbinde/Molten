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

    var body: some View {
        NavigationStack {
            List {
                myShareSection
                friendsSection
            }
            .navigationTitle("Inventory Sharing")
            .task {
                await viewModel.onAppear()
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
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Your Share Code")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        Text(shareCode)
                            .font(.system(.title2, design: .monospaced))
                            .fontWeight(.bold)

                        Spacer()

                        Button {
                            viewModel.copyShareCode()
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                    }

                    Text("Share this code with friends so they can view your inventory")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                            Text("Update Inventory on Server")
                        }
                    }
                    .disabled(viewModel.isLoading)

                    Text("Re-uploads your current inventory to update what friends see. Also resets the 90-day auto-deletion timer.")
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

            } else {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Share Your Inventory")
                        .font(.headline)

                    Text("Create a share code to let friends view your glass inventory")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button {
                        viewModel.showingCreateShare = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Create Share")
                        }
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.xs)
            }
        } header: {
            Text("My Inventory")
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
                    Text(friend.shareCode)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if friend.lastRefreshed != nil {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text("Updated \(relativeTimeString) ago")
                            .font(.caption)
                            .foregroundColor(.secondary)
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

// MARK: - Preview

#Preview {
    InventorySharingView()
}

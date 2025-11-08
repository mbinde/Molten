//
//  InventorySharingView.swift
//  Molten
//
//  Main view for inventory sharing feature
//

import SwiftUI

struct InventorySharingView: View {

    @State private var viewModel = InventorySharingViewModel()

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

                    Text("Re-uploads your current inventory to update what friends see")
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
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.removeFriend(friend)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button {
                            viewModel.selectedFriendForCustomization = friend
                            viewModel.showingCustomizeFriend = true
                        } label: {
                            Label("Customize Icon", systemImage: "paintbrush")
                        }

                        Button(role: .destructive) {
                            viewModel.removeFriend(friend)
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

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Icon
            Circle()
                .fill(iconBackground)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: iconSymbol)
                        .font(.system(size: 20))
                        .foregroundStyle(iconForeground)
                )

            // Friend info
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(friend.friendName)
                    .font(.headline)

                HStack {
                    Text(friend.shareCode)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let lastRefreshed = friend.lastRefreshed {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text("Updated \(lastRefreshed, style: .relative)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

// MARK: - Preview

#Preview {
    InventorySharingView()
}

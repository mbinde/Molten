//
//  FriendInventoryView.swift
//  Molten
//
//  View for displaying a friend's shared inventory
//

import SwiftUI

struct FriendInventoryView: View {

    let friend: FriendShare
    @Bindable var viewModel: InventorySharingViewModel

    var body: some View {
        Group {
            if viewModel.isLoadingFriendInventory {
                ProgressView("Loading inventory...")
            } else if viewModel.friendInventory.isEmpty && viewModel.selectedFriend?.shareCode == friend.shareCode {
                emptyState
            } else if viewModel.selectedFriend?.shareCode == friend.shareCode {
                inventoryList
            } else {
                loadButton
            }
        }
        .navigationTitle(friend.friendName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Subviews

    private var loadButton: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Load \(friend.friendName)'s Inventory")
                .font(.headline)

            Button {
                Task {
                    await viewModel.loadFriendInventory(friend)
                }
            } label: {
                Text("Load Inventory")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("\(friend.friendName) has no inventory")
                .font(.headline)

            Text("They haven't added any glass to their inventory yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var inventoryList: some View {
        List {
            ForEach(viewModel.friendInventory, id: \.stableId) { item in
                FriendInventoryItemRow(item: item)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        await viewModel.loadFriendInventory(friend)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoadingFriendInventory)
            }
        }
    }
}

// MARK: - Friend Inventory Item Row

struct FriendInventoryItemRow: View {
    let item: InventoryItemSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                Text(item.manufacturer.uppercased())
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("•")
                    .foregroundColor(.secondary)

                Text(item.sku)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(alignment: .firstTextBaseline) {
                Text("\(item.quantity, specifier: "%.1f")")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(item.unit)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let location = item.location {
                    Spacer()

                    Label(location, systemImage: "location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

#Preview("With Inventory") {
    NavigationStack {
        FriendInventoryView(
            friend: FriendShare(
                shareCode: "ABC123",
                friendName: "Alice",
                dateAdded: Date(),
                lastRefreshed: Date()
            ),
            viewModel: {
                let vm = InventorySharingViewModel()
                vm.selectedFriend = FriendShare(
                    shareCode: "ABC123",
                    friendName: "Alice",
                    dateAdded: Date(),
                    lastRefreshed: Date()
                )
                vm.friendInventory = [
                    InventoryItemSnapshot(
                        stableId: "abc123",
                        manufacturer: "bullseye",
                        sku: "001",
                        quantity: 5.0,
                        unit: "rod",
                        location: "Studio A"
                    ),
                    InventoryItemSnapshot(
                        stableId: "def456",
                        manufacturer: "cim",
                        sku: "023",
                        quantity: 3.5,
                        unit: "tube",
                        location: nil
                    )
                ]
                return vm
            }()
        )
    }
}

#Preview("Empty") {
    NavigationStack {
        FriendInventoryView(
            friend: FriendShare(
                shareCode: "ABC123",
                friendName: "Bob",
                dateAdded: Date()
            ),
            viewModel: {
                let vm = InventorySharingViewModel()
                vm.selectedFriend = FriendShare(
                    shareCode: "ABC123",
                    friendName: "Bob",
                    dateAdded: Date()
                )
                vm.friendInventory = []
                return vm
            }()
        )
    }
}

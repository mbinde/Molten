//
//  InventorySharingViewModel.swift
//  Molten
//
//  ViewModel for inventory sharing feature
//

import Foundation
import SwiftUI

@MainActor
@Observable
class InventorySharingViewModel {

    // MARK: - Properties

    private let sharingManager: InventorySharingManager
    private let catalogService: CatalogService

    // State
    var myShareCode: String?
    var friendShares: [FriendShare] = []
    var isLoading = false
    var errorMessage: String?

    // Share creation
    var isCreatingShare = false

    // Friend management
    var showingAddFriend = false
    var friendShareCode = ""
    var friendName = ""
    var isAddingFriend = false

    // Friend inventory
    var selectedFriend: FriendShare?
    var friendInventory: [InventoryItemSnapshot] = []
    var isLoadingFriendInventory = false

    // MARK: - Initialization

    init(
        sharingManager: InventorySharingManager = RepositoryFactory.createInventorySharingManager(),
        catalogService: CatalogService = RepositoryFactory.createCatalogService()
    ) {
        self.sharingManager = sharingManager
        self.catalogService = catalogService
    }

    // MARK: - Lifecycle

    func onAppear() async {
        await loadShareData()
    }

    func loadShareData() async {
        myShareCode = sharingManager.getMyShareCode()
        friendShares = sharingManager.getFriendShares()
    }

    // MARK: - My Share

    func createMyShare() async {
        isCreatingShare = true
        errorMessage = nil

        do {
            // Get all inventory items (only items with inventory, no zero quantities)
            let items = try await catalogService.getAllGlassItems(includeWithoutInventory: false)

            // Create share
            let code = try await sharingManager.createMyShare(items: items)
            myShareCode = code

        } catch SharingManagerError.shareAlreadyExists {
            errorMessage = "You already have a share. Delete it first to create a new one."
        } catch {
            errorMessage = "Failed to create share: \(error.localizedDescription)"
        }

        isCreatingShare = false
    }

    func refreshMyShare() async {
        isLoading = true
        errorMessage = nil

        do {
            // Get all inventory items (only items with inventory, no zero quantities)
            let items = try await catalogService.getAllGlassItems(includeWithoutInventory: false)

            // Refresh share
            try await sharingManager.refreshMyShare(items: items)

        } catch SharingManagerError.noShareExists {
            errorMessage = "No share exists. Create one first."
        } catch {
            errorMessage = "Failed to refresh share: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func deleteMyShare() async {
        isLoading = true
        errorMessage = nil

        do {
            try await sharingManager.deleteMyShare()
            myShareCode = nil

        } catch SharingManagerError.noShareExists {
            errorMessage = "No share exists."
        } catch {
            errorMessage = "Failed to delete share: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Friend Shares

    func addFriend() async {
        guard !friendShareCode.isEmpty, !friendName.isEmpty else {
            errorMessage = "Please enter both share code and friend name"
            return
        }

        isAddingFriend = true
        errorMessage = nil

        do {
            let result = try await sharingManager.addFriendShare(
                shareCode: friendShareCode.uppercased(),
                friendName: friendName
            )

            if !result.isValid {
                errorMessage = "Warning: Share signature is invalid. Data may have been tampered with."
            }

            // Reload friend list
            friendShares = sharingManager.getFriendShares()

            // Clear form
            friendShareCode = ""
            friendName = ""
            showingAddFriend = false

        } catch SharingAPIError.notFound {
            errorMessage = "Share code not found. Check the code and try again."
        } catch {
            errorMessage = "Failed to add friend: \(error.localizedDescription)"
        }

        isAddingFriend = false
    }

    func removeFriend(_ friend: FriendShare) {
        do {
            try sharingManager.removeFriendShare(shareCode: friend.shareCode)
            friendShares = sharingManager.getFriendShares()

            // Clear selected friend if it was removed
            if selectedFriend?.shareCode == friend.shareCode {
                selectedFriend = nil
                friendInventory = []
            }
        } catch {
            errorMessage = "Failed to remove friend: \(error.localizedDescription)"
        }
    }

    func loadFriendInventory(_ friend: FriendShare) async {
        selectedFriend = friend
        isLoadingFriendInventory = true
        errorMessage = nil

        do {
            let result = try await sharingManager.refreshFriendShare(shareCode: friend.shareCode)

            if !result.isValid {
                errorMessage = "Warning: Share signature is invalid. Data may have been tampered with."
            }

            friendInventory = result.items

            // Update friend list to show new refresh timestamp
            friendShares = sharingManager.getFriendShares()

        } catch {
            errorMessage = "Failed to load friend's inventory: \(error.localizedDescription)"
        }

        isLoadingFriendInventory = false
    }

    // MARK: - Helpers

    func copyShareCode() {
        #if canImport(UIKit)
        if let code = myShareCode {
            UIPasteboard.general.string = code
        }
        #endif
    }

    func clearError() {
        errorMessage = nil
    }
}

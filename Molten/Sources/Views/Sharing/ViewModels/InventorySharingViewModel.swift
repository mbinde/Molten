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
    private let apiClient: InventorySharingAPIClient
    private let expiringShareRepository: CoreDataExpiringShareRepository

    // State
    var myShareCode: String?
    var myShareMetadata: MyShareMetadata?
    var friendShares: [FriendShare] = []
    var expiringShares: [ExpiringShare] = []
    var isLoading = false
    var errorMessage: String?

    // Share creation/editing
    var isCreatingShare = false
    var showingCreateShare = false
    var showingEditMetadata = false
    var displayName = ""
    var shareNotes = ""

    // Friend management
    var showingAddFriend = false
    var friendShareCode = ""
    var friendNickname = ""
    var isAddingFriend = false

    // Friend inventory
    var selectedFriend: FriendShare?
    var friendInventory: [InventoryItemSnapshot] = []
    var isLoadingFriendInventory = false

    // Friend customization
    var showingCustomizeFriend = false
    var selectedFriendForCustomization: FriendShare?

    // Expiring share creation
    var showingCreateExpiringShare = false
    var expiringShareDisplayName = ""
    var expiringShareNotes = ""
    var expiringShareDays = 7
    var expiringShareHours = 0
    var isCreatingExpiringShare = false

    // MARK: - Initialization

    init(
        sharingManager: InventorySharingManager,
        catalogService: CatalogService,
        apiClient: InventorySharingAPIClient,
        expiringShareRepository: CoreDataExpiringShareRepository
    ) {
        self.sharingManager = sharingManager
        self.catalogService = catalogService
        self.apiClient = apiClient
        self.expiringShareRepository = expiringShareRepository
    }

    /// Convenience init using AppDependencies
    convenience init(deps: AppDependencies = .shared) {
        let persistence = PersistenceController.shared
        let cloudContext = persistence.cloudContext

        self.init(
            sharingManager: deps.inventorySharingManager,
            catalogService: deps.catalogService,
            apiClient: InventorySharingAPIClient(),
            expiringShareRepository: CoreDataExpiringShareRepository(context: cloudContext)
        )
    }

    // MARK: - Lifecycle

    func onAppear() async {
        await loadShareData()
    }

    func loadShareData() async {
        myShareCode = sharingManager.getMyShareCode()
        myShareMetadata = sharingManager.getMyShareMetadata()
        friendShares = sharingManager.getFriendShares()

        // Load expiring shares
        do {
            expiringShares = try await expiringShareRepository.fetchAllExpiringShares()
            // Clean up expired shares
            try await expiringShareRepository.deleteExpiredShares()
            expiringShares = try await expiringShareRepository.fetchAllExpiringShares()
        } catch {
            // Log error but don't fail the whole load
            print("Failed to load expiring shares: \(error)")
        }

        // Populate form fields with existing metadata
        if let metadata = myShareMetadata {
            displayName = metadata.displayName
            shareNotes = metadata.shareNotes ?? ""
        }
    }

    /// Refresh friend list to pick up updated cached stats (item count, quantity, weight)
    func refreshFriendList() {
        friendShares = sharingManager.getFriendShares()
    }

    // MARK: - My Share

    func createMyShare() async {
        isCreatingShare = true
        errorMessage = nil

        do {
            // Validate display name
            guard !displayName.trimmingCharacters(in: .whitespaces).isEmpty else {
                errorMessage = "Please enter a display name"
                isCreatingShare = false
                return
            }

            // Get all inventory items (only items with inventory, no zero quantities)
            let items = try await catalogService.getAllGlassItems(includeWithoutInventory: false)

            // Create metadata
            let metadata = MyShareMetadata(
                displayName: displayName.trimmingCharacters(in: .whitespaces),
                shareNotes: shareNotes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : shareNotes.trimmingCharacters(in: .whitespaces)
            )

            // Create share
            let code = try await sharingManager.createMyShare(items: items, metadata: metadata)
            myShareCode = code
            myShareMetadata = metadata

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

            // Refresh share (keeps existing metadata)
            try await sharingManager.refreshMyShare(items: items)

        } catch SharingManagerError.noShareExists {
            errorMessage = "No share exists. Create one first."
        } catch {
            errorMessage = "Failed to refresh share: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func updateMyShareMetadata() async {
        isLoading = true
        errorMessage = nil

        do {
            // Validate display name
            guard !displayName.trimmingCharacters(in: .whitespaces).isEmpty else {
                errorMessage = "Please enter a display name"
                isLoading = false
                return
            }

            // Get all inventory items (only items with inventory, no zero quantities)
            let items = try await catalogService.getAllGlassItems(includeWithoutInventory: false)

            // Create updated metadata
            let metadata = MyShareMetadata(
                displayName: displayName.trimmingCharacters(in: .whitespaces),
                shareNotes: shareNotes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : shareNotes.trimmingCharacters(in: .whitespaces)
            )

            // Refresh share with new metadata
            try await sharingManager.refreshMyShare(items: items, metadata: metadata)
            myShareMetadata = metadata
            showingEditMetadata = false

        } catch SharingManagerError.noShareExists {
            errorMessage = "No share exists. Create one first."
        } catch {
            errorMessage = "Failed to update metadata: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func deleteMyShare() async {
        isLoading = true
        errorMessage = nil

        do {
            try await sharingManager.deleteMyShare()
            myShareCode = nil
            myShareMetadata = nil

            // Also delete all expiring shares when main share is deleted
            await deleteAllExpiringSharesForMainShare()

        } catch SharingManagerError.noShareExists {
            errorMessage = "No share exists."
        } catch SharingAPIError.notFound {
            // Share doesn't exist on server (never uploaded or already deleted)
            // Delete locally so user can create a new share
            do {
                try sharingManager.deleteLocalShareOnly()
                myShareCode = nil
                myShareMetadata = nil

                // Also delete all expiring shares
                await deleteAllExpiringSharesForMainShare()

                // Don't show error - deletion succeeded from user's perspective
            } catch {
                errorMessage = "Failed to delete local share: \(error.localizedDescription)"
            }
        } catch SharingAPIError.unauthorized {
            // Key pair mismatch - this should be extremely rare with iCloud Keychain sync
            // Only happens if: iCloud Keychain disabled, or manual key deletion during testing
            do {
                try sharingManager.deleteLocalShareOnly()
                myShareCode = nil
                myShareMetadata = nil

                // Also delete all expiring shares
                await deleteAllExpiringSharesForMainShare()

                errorMessage = "Local share deleted. Server deletion failed - your encryption keys are not available. This can happen if iCloud Keychain is disabled. Enable iCloud Keychain in Settings to prevent this issue. You can create a new share now."
            } catch {
                errorMessage = "Failed to delete local share: \(error.localizedDescription)"
            }
        } catch {
            errorMessage = "Failed to delete share: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Friend Shares

    func addFriend() async {
        guard !friendShareCode.isEmpty else {
            errorMessage = "Please enter a share code"
            return
        }

        isAddingFriend = true
        errorMessage = nil

        do {
            let result = try await sharingManager.addFriendShare(
                shareCode: friendShareCode.uppercased(),
                nickname: friendNickname.isEmpty ? nil : friendNickname
            )

            if !result.isValid {
                errorMessage = "Warning: Share signature is invalid. Data may have been tampered with."
            }

            // Reload friend list
            friendShares = sharingManager.getFriendShares()

            // Clear form
            friendShareCode = ""
            friendNickname = ""
            showingAddFriend = false

        } catch SharingAPIError.notFound {
            errorMessage = "Share code '\(friendShareCode.uppercased())' not found. Check the code and try again."
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

    // MARK: - Friend Customization

    func updateFriendNickname(_ friend: FriendShare, nickname: String?) {
        do {
            try sharingManager.updateFriendNickname(shareCode: friend.shareCode, nickname: nickname)
            friendShares = sharingManager.getFriendShares()
        } catch {
            errorMessage = "Failed to update nickname: \(error.localizedDescription)"
        }
    }

    func updateFriendNotes(_ friend: FriendShare, notes: String?) {
        do {
            try sharingManager.updateFriendNotes(shareCode: friend.shareCode, notes: notes)
            friendShares = sharingManager.getFriendShares()
        } catch {
            errorMessage = "Failed to update notes: \(error.localizedDescription)"
        }
    }

    func updateFriendIcon(_ friend: FriendShare, symbol: String?, backgroundHex: String?, foregroundHex: String?) {
        do {
            try sharingManager.updateFriendIcon(
                shareCode: friend.shareCode,
                symbol: symbol,
                backgroundHex: backgroundHex,
                foregroundHex: foregroundHex
            )
            friendShares = sharingManager.getFriendShares()
        } catch {
            errorMessage = "Failed to update icon: \(error.localizedDescription)"
        }
    }

    // MARK: - Expiring Shares

    func createExpiringShare() async {
        guard let mainShareCode = myShareCode else {
            errorMessage = "No main share exists. Create one first."
            return
        }

        guard !expiringShareDisplayName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter a display name for the expiring share"
            return
        }

        // Validate duration
        let duration = ExpiringShareDuration(days: expiringShareDays, hours: expiringShareHours)
        guard duration.isValid else {
            errorMessage = "Invalid duration. Minimum 1 hour, maximum 30 days + 23 hours"
            return
        }

        isCreatingExpiringShare = true
        errorMessage = nil

        do {
            let trimmedDisplayName = expiringShareDisplayName.trimmingCharacters(in: .whitespaces)
            let trimmedNotes = expiringShareNotes.trimmingCharacters(in: .whitespaces)
            let notes = trimmedNotes.isEmpty ? nil : trimmedNotes

            // Use unformatted share code (remove dash)
            let unformattedMainShareCode = mainShareCode.unformattedShareCode

            // Call server to create expiring share
            let (shareCode, expiresAt) = try await apiClient.createExpiringShare(
                mainShareCode: unformattedMainShareCode,
                displayName: trimmedDisplayName,
                shareNotes: notes,
                expirationDuration: duration.timeInterval
            )

            // Save locally
            let expiringShare = ExpiringShare(
                shareCode: shareCode,
                mainShareCode: mainShareCode,
                displayName: trimmedDisplayName,
                shareNotes: notes,
                expiresAt: expiresAt
            )

            try await expiringShareRepository.saveExpiringShare(expiringShare)

            // Reload list
            expiringShares = try await expiringShareRepository.fetchAllExpiringShares()

            // Clear form
            expiringShareDisplayName = ""
            expiringShareNotes = ""
            expiringShareDays = 7
            expiringShareHours = 0
            showingCreateExpiringShare = false

        } catch {
            errorMessage = "Failed to create expiring share: \(error.localizedDescription)"
        }

        isCreatingExpiringShare = false
    }

    func deleteExpiringShare(_ share: ExpiringShare) async {
        isLoading = true
        errorMessage = nil

        do {
            // Delete from server
            try await apiClient.deleteExpiringShare(shareCode: share.shareCode)

            // Delete locally
            try await expiringShareRepository.deleteExpiringShare(byCode: share.shareCode)

            // Reload list
            expiringShares = try await expiringShareRepository.fetchAllExpiringShares()

        } catch {
            errorMessage = "Failed to delete expiring share: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func deleteAllExpiringSharesForMainShare() async {
        guard let mainShareCode = myShareCode else { return }

        do {
            // Delete all expiring shares for this main share
            try await expiringShareRepository.deleteExpiringShares(forMainShareCode: mainShareCode)
            expiringShares = []
        } catch {
            // Log error but don't fail - this is cleanup during main share deletion
            print("Failed to delete expiring shares: \(error)")
        }
    }

    // MARK: - Helpers

    func copyShareCode() {
        #if canImport(UIKit)
        if let code = myShareCode {
            UIPasteboard.general.string = code
        }
        #endif
    }

    func copyExpiringShareCode(_ shareCode: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = shareCode
        #endif
    }

    func clearError() {
        errorMessage = nil
    }
}

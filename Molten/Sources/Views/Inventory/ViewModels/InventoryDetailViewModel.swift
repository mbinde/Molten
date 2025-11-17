//
//  InventoryDetailViewModel.swift
//  Molten
//
//  ViewModel for InventoryDetailView - manages state and data loading
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class InventoryDetailViewModel {
    // MARK: - Published State
    var currentItem: CompleteInventoryItemModel
    var isRefreshing = false
    var isLoadingNotes = false
    var isLoadingTags = false
    var isLoadingShoppingList = false
    var isLoadingImages = false
    var expandedSections: Set<String> = ["glass-item", "inventory"]
    var isManufacturerNotesExpanded: Bool

    // Data state
    var userNotes: UserNotesModel?
    var userTags: [String] = []
    var shoppingListItem: ItemShoppingModel?
    var userImages: [UserImageModel] = []
    var recommendedScheduleIds: [UUID] = []

    #if os(macOS)
    var loadedImages: [UUID: NSImage] = [:]
    var manufacturerImage: NSImage?
    #else
    var loadedImages: [UUID: UIImage] = [:]
    var manufacturerImage: UIImage?
    #endif

    // MARK: - Dependencies
    private let userNotesRepository: UserNotesRepository
    private let userTagsRepository: UserTagsRepository
    private let shoppingListRepository: ShoppingListRepository
    private let userImageRepository: UserImageRepository
    private let kilnScheduleService: KilnScheduleService

    // MARK: - Init
    init(
        item: CompleteInventoryItemModel,
        userNotesRepository: UserNotesRepository,
        userTagsRepository: UserTagsRepository,
        shoppingListRepository: ShoppingListRepository,
        userImageRepository: UserImageRepository,
        kilnScheduleService: KilnScheduleService
    ) {
        self.currentItem = item
        self.isManufacturerNotesExpanded = item.glassItem.notes != nil
        self.userNotesRepository = userNotesRepository
        self.userTagsRepository = userTagsRepository
        self.shoppingListRepository = shoppingListRepository
        self.userImageRepository = userImageRepository
        self.kilnScheduleService = kilnScheduleService
    }

    // MARK: - Actions
    func toggleSection(_ sectionId: String) {
        if expandedSections.contains(sectionId) {
            expandedSections.remove(sectionId)
        } else {
            expandedSections.insert(sectionId)
        }
    }

    func loadUserNotes() async {
        isLoadingNotes = true
        defer { isLoadingNotes = false }

        do {
            userNotes = try await userNotesRepository.getUserNotes(forGlassItem: currentItem.glassItem.stable_id)
        } catch {
            userNotes = nil
        }
    }

    func loadUserTags() async {
        isLoadingTags = true
        defer { isLoadingTags = false }

        do {
            userTags = try await userTagsRepository.getUserTags(forGlassItem: currentItem.glassItem.stable_id)
        } catch {
            userTags = []
        }
    }

    func loadShoppingListItem() async {
        isLoadingShoppingList = true
        defer { isLoadingShoppingList = false }

        do {
            shoppingListItem = try await shoppingListRepository.getShoppingListItem(forGlassItem: currentItem.glassItem.stable_id)
        } catch {
            shoppingListItem = nil
        }
    }

    func loadUserImages() async {
        isLoadingImages = true
        defer { isLoadingImages = false }

        do {
            userImages = try await userImageRepository.getImages(ownerType: .glassItem, ownerId: currentItem.glassItem.stable_id)

            // Load actual image data
            for imageModel in userImages {
                if let image = try? await userImageRepository.loadImage(imageModel) {
                    loadedImages[imageModel.id] = image
                }
            }
        } catch {
            userImages = []
        }
    }

    func loadRecommendedSchedules() async {
        do {
            let schedules = try await kilnScheduleService.getRecommendedSchedules(for: currentItem.glassItem)
            recommendedScheduleIds = schedules.map { $0.id }
        } catch {
            recommendedScheduleIds = []
        }
    }
}

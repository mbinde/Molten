//
//  InventoryDetailView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//  Updated for GlassItem Architecture on 10/14/25.
//  Merged comprehensive view with safe URL handling on 10/16/25.
//

import SwiftUI
import PhotosUI
#if canImport(AppKit)
import AppKit
#endif

/// Wrapper to make String identifiable for sheet presentation
private struct InventoryTypeSelection: Identifiable {
    let id = UUID()
    let type: String
}

/// Comprehensive inventory detail view showing complete item information
/// including inventory breakdown by type, location distribution, and shopping list integration
struct InventoryDetailView: View {
    let item: CompleteInventoryItemModel
    let inventoryTrackingService: InventoryTrackingService?
    let catalogService: CatalogService?
    let userNotesRepository: UserNotesRepository
    let userTagsRepository: UserTagsRepository
    let shoppingListRepository: ShoppingListRepository
    let locationService: UnifiedLocationService
    let userImageRepository: UserImageRepository
    let kilnScheduleService: KilnScheduleService
    let glassItemRepository: GlassItemRepository

    @Environment(\.dismiss) private var dismiss
    @Environment(EntitlementService.self) private var entitlementService
    @State private var isEditing = false

    // State for managing UI interactions
    @State private var selectedInventoryType: InventoryTypeSelection?
    @State private var showingShoppingListOptions = false
    @State private var showingUserNotesEditor = false
    @State private var showingUserTagsEditor = false
    @State private var showingAddInventory = false
    @State private var showingUpgradePrompt = false
    @State private var inventoryItemCount = 0
    @State private var inventoryItemLimit = 0
    @State private var expandedSections: Set<String> = ["glass-item", "inventory"]
    @State private var isManufacturerNotesExpanded: Bool

    // User notes state
    @State private var userNotes: UserNotesModel?
    @State private var isLoadingNotes = false
    @State private var isUserNotesExpanded = false

    // User tags state
    @State private var userTags: [String] = []
    @State private var isLoadingTags = false

    // Shopping list state
    @State private var shoppingListItem: ItemShoppingModel?
    @State private var isLoadingShoppingList = false

    // User images state
    @State private var userImages: [UserImageModel] = []
    #if os(macOS)
    @State private var loadedImages: [UUID: NSImage] = [:]
    @State private var manufacturerImage: NSImage?
    #else
    @State private var loadedImages: [UUID: UIImage] = [:]
    @State private var manufacturerImage: UIImage?
    #endif
    @State private var showingImagePicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isLoadingImages = false

    // Kiln schedules state
    @State private var recommendedScheduleIds: [UUID] = []

    // State for refreshing item data
    @State private var currentItem: CompleteInventoryItemModel
    @State private var isRefreshing = false

    // Editing state
    @State private var editingQuantity = ""
    @State private var selectedType = "rod"
    @State private var selectedinventory_id: UUID?

    @State private var showingError = false
    @State private var errorMessage: String?

    // MARK: - Initializers

    /// Initialize with complete inventory model and service
    init(
        item: CompleteInventoryItemModel,
        inventoryTrackingService: InventoryTrackingService? = nil,
        catalogService: CatalogService? = nil,
        userNotesRepository: UserNotesRepository,
        userTagsRepository: UserTagsRepository,
        shoppingListRepository: ShoppingListRepository,
        locationService: UnifiedLocationService,
        userImageRepository: UserImageRepository,
        kilnScheduleService: KilnScheduleService,
        glassItemRepository: GlassItemRepository
    ) {
        self.item = item
        self.inventoryTrackingService = inventoryTrackingService
        self.catalogService = catalogService
        self.userNotesRepository = userNotesRepository
        self.userTagsRepository = userTagsRepository
        self.shoppingListRepository = shoppingListRepository
        self.locationService = locationService
        self.userImageRepository = userImageRepository
        self.kilnScheduleService = kilnScheduleService
        self.glassItemRepository = glassItemRepository
        // Initialize from user settings
        self._isManufacturerNotesExpanded = State(initialValue: UserSettings.shared.expandManufacturerDescriptionsByDefault)
        self._isUserNotesExpanded = State(initialValue: UserSettings.shared.expandUserNotesByDefault)
        // Initialize currentItem with the passed item
        self._currentItem = State(initialValue: item)
    }

    /// Convenience init using AppDependencies
    init(item: CompleteInventoryItemModel, deps: AppDependencies = AppDependencies()) {
        self.item = item
        self.inventoryTrackingService = deps.inventoryTrackingService
        self.catalogService = deps.catalogService
        self.userNotesRepository = deps.userNotesRepository
        self.userTagsRepository = deps.userTagsRepository
        self.shoppingListRepository = deps.shoppingListRepository
        self.locationService = deps.unifiedLocationService
        self.userImageRepository = deps.userImageRepository
        self.kilnScheduleService = deps.kilnScheduleService
        self.glassItemRepository = deps.glassItemRepository
        // Initialize from user settings
        self._isManufacturerNotesExpanded = State(initialValue: UserSettings.shared.expandManufacturerDescriptionsByDefault)
        self._isUserNotesExpanded = State(initialValue: UserSettings.shared.expandUserNotesByDefault)
        // Initialize currentItem with the passed item
        self._currentItem = State(initialValue: item)
    }

    // MARK: - View Body

    private var scrollableContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    // Header with glass item image and basic info (includes tags)
                    headerSection
                        .id("header")

                    // Rating Words Section
                    RatingWordsSection(itemStableId: currentItem.glassItem.stable_id)

                    // Glass Item Details Section
                    glassItemDetailsSection
                        .id("glass-item-section")

                    // Recommended Kiln Schedules Section - only show if schedules exist
                    if !recommendedScheduleIds.isEmpty {
                        RecommendedSchedulesSection(
                            glassItemId: currentItem.glassItem.stable_id,
                            kilnScheduleService: kilnScheduleService,
                            glassItemRepository: glassItemRepository,
                            onSchedulesChanged: { scheduleIds in
                                recommendedScheduleIds = scheduleIds
                            }
                        )
                    }

                    // Inventory Breakdown Section - only show if inventory exists
                    if !currentItem.inventory.isEmpty {
                        inventoryBreakdownSection
                    }

                    // Shopping List Section - only show if on shopping list
                    if shoppingListItem != nil {
                        shoppingListSection
                    }

                    // Location Distribution Section
                    if !currentItem.locations.isEmpty {
                        locationDistributionSection
                    }

                    // Custom Images Section - only show if images exist
                    if !userImages.isEmpty {
                        customImagesSection
                    }

                    Spacer(minLength: 100)
                }
                .padding()
            }
            .onChange(of: isManufacturerNotesExpanded) { _, newValue in
                // When collapsing, scroll to the top of the view
                if !newValue {
                    withAnimation {
                        proxy.scrollTo("header", anchor: .top)
                    }
                }
            }
            .onChange(of: isUserNotesExpanded) { _, newValue in
                // When collapsing user notes, scroll to the user notes section
                if !newValue {
                    withAnimation {
                        proxy.scrollTo("user-notes", anchor: .top)
                    }
                }
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            scrollableContent
                .navigationTitle(currentItem.glassItem.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                if !isEditing {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button {
                                checkLimitAndShowAddInventory()
                            } label: {
                                Label("Add to Inventory", systemImage: "archivebox.fill")
                            }

                            Button {
                                showingShoppingListOptions = true
                            } label: {
                                Label("Add to Shopping List", systemImage: "cart.fill")
                            }

                            Button {
                                showingImagePicker = true
                            } label: {
                                Label("Add an Image", systemImage: "photo.fill")
                            }

                            Button {
                                showingUserNotesEditor = true
                            } label: {
                                Label("Add a Note", systemImage: "note.text")
                            }

                            Button {
                                showingUserTagsEditor = true
                            } label: {
                                Label("Manage Tags", systemImage: "tag.fill")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .accessibilityLabel("Actions")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingShoppingListOptions, onDismiss: {
            // Reload shopping list after adding
            loadShoppingList()
        }) {
            ShoppingListOptionsView(
                item: item,
                shoppingListRepository: shoppingListRepository,
                locationService: locationService
            )
        }
        .sheet(item: $selectedInventoryType) { selection in
            InventoryStorageDetailView(
                item: currentItem,
                inventoryType: selection.type
            )
            .onDisappear {
                // Refresh item data after location details might have changed
                refreshItemData()
            }
        }
        .sheet(isPresented: $showingUserNotesEditor, onDismiss: {
            // Reload notes after editing
            loadUserNotes()
        }) {
            UserNotesEditor(
                item: item,
                userNotesRepository: userNotesRepository
            )
        }
        .sheet(isPresented: $showingUserTagsEditor, onDismiss: {
            // Reload tags after editing
            loadUserTags()
        }) {
            UserTagsEditor(
                item: item,
                userTagsRepository: userTagsRepository
            )
        }
        .sheet(isPresented: $showingAddInventory, onDismiss: {
            // Refresh item data after adding inventory
            refreshItemData()
        }) {
            if let inventoryTrackingService = inventoryTrackingService,
               let catalogService = catalogService {
                AddInventoryItemView(
                    prefilledNaturalKey: item.glassItem.stable_id,
                    deps: AppDependencies()
                )
            }
        }
        .sheet(isPresented: $showingUpgradePrompt) {
            UpgradePromptView(
                feature: "inventory",
                currentCount: inventoryItemCount,
                limit: inventoryItemLimit
            )
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .photosPicker(
            isPresented: $showingImagePicker,
            selection: $selectedPhotoItems,
            maxSelectionCount: 10,
            matching: .images
        )
        .onChange(of: selectedPhotoItems) { _, newItems in
            if !newItems.isEmpty {
                handleImageSelection(newItems)
            }
        }
        .onAppear {
            loadInitialData()
            loadUserNotes()
            loadUserTags()
            loadShoppingList()
            loadUserImages()
            loadRecommendedSchedules()
        }
    }

    // MARK: - Data Loading

    private func loadInitialData() {
        if let firstInventory = currentItem.inventory.first {
            editingQuantity = String(firstInventory.quantity)
            selectedType = firstInventory.type ?? ""
            selectedinventory_id = firstInventory.id
        }
    }

    private func loadUserNotes() {
        Task {
            isLoadingNotes = true
            defer { isLoadingNotes = false }

            do {
                userNotes = try await userNotesRepository.fetchNotes(forItem: item.glassItem.stable_id)
            } catch {
                // No notes is fine, just leave userNotes as nil
                print("No user notes found or error loading: \(error)")
            }
        }
    }

    private func loadUserTags() {
        Task {
            isLoadingTags = true
            defer { isLoadingTags = false }

            do {
                userTags = try await userTagsRepository.fetchTags(forItem: item.glassItem.stable_id)
            } catch {
                // No tags is fine, just leave empty
                print("No user tags found or error loading: \(error)")
            }
        }
    }

    private func loadShoppingList() {
        Task {
            isLoadingShoppingList = true
            defer { isLoadingShoppingList = false }

            do {
                shoppingListItem = try await shoppingListRepository.fetchItem(forItem: item.glassItem.stable_id)
            } catch {
                // No shopping list item is fine, just leave nil
                print("No shopping list item found or error loading: \(error)")
            }
        }
    }

    private func loadUserImages() {
        Task {
            isLoadingImages = true
            defer { isLoadingImages = false }

            do {
                // Load all user images for this glass item
                userImages = try await userImageRepository.getImages(
                    ownerType: .glassItem,
                    ownerId: currentItem.glassItem.stable_id
                )

                // Load the actual image data
                for imageModel in userImages {
                    if let image = try await userImageRepository.loadImage(imageModel) {
                        await MainActor.run {
                            loadedImages[imageModel.id] = image
                        }
                    }
                }

                // Load manufacturer default image for reference
                await loadManufacturerImage()
            } catch {
                print("Error loading user images: \(error)")
            }
        }
    }

    @MainActor
    private func loadManufacturerImage() async {
        manufacturerImage = ImageHelpers.loadProductImage(
            for: currentItem.glassItem.sku ?? "",
            manufacturer: currentItem.glassItem.manufacturer,
            stableId: currentItem.glassItem.stable_id
        )
    }

    private func loadRecommendedSchedules() {
        Task {
            do {
                recommendedScheduleIds = try await glassItemRepository.getRecommendedSchedules(
                    forGlassItem: currentItem.glassItem.stable_id
                )
            } catch {
                // No schedules is fine, just leave empty
                print("Error loading recommended schedules: \(error)")
                recommendedScheduleIds = []
            }
        }
    }

    /// Check inventory limit and show either the add form or upgrade prompt
    private func checkLimitAndShowAddInventory() {
        guard let inventoryTrackingService = inventoryTrackingService else { return }

        Task {
            do {
                // Count unique items with inventory (not individual inventory records)
                let allItemsWithInventory = try await inventoryTrackingService.searchItems(
                    text: "",
                    hasInventory: true
                )
                let currentInventoryCount = allItemsWithInventory.count
                let canAdd = entitlementService.canAddInventoryItem(currentCount: currentInventoryCount)

                await MainActor.run {
                    if !canAdd {
                        // Hit the limit - show upgrade prompt immediately
                        let limit = entitlementService.getInventoryLimit() ?? 0
                        inventoryItemCount = currentInventoryCount
                        inventoryItemLimit = limit
                        showingUpgradePrompt = true
                    } else {
                        // Under limit - show add inventory form
                        showingAddInventory = true
                    }
                }
            } catch {
                // If we can't check the limit, allow the add to proceed
                print("⚠️ Failed to check inventory limit: \(error)")
                await MainActor.run {
                    showingAddInventory = true
                }
            }
        }
    }

    private func handleImageSelection(_ items: [PhotosPickerItem]) {
        Task {
            for item in items {
                #if os(macOS)
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = NSImage(data: data) else {
                    continue
                }
                #else
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    continue
                }
                #endif

                // No need to resize - UserImageRepository handles this automatically
                let imageToSave = image

                do {
                    // Determine if this should be primary (first image or no primary exists)
                    let shouldBePrimary = userImages.isEmpty || !userImages.contains(where: { $0.imageType == .primary })

                    // Save image (repository handles resizing)
                    let imageModel = try await userImageRepository.saveImage(
                        imageToSave,
                        ownerType: .glassItem,
                        ownerId: currentItem.glassItem.stable_id,
                        type: shouldBePrimary ? .primary : .alternate
                    )

                    await MainActor.run {
                        userImages.append(imageModel)
                        loadedImages[imageModel.id] = image
                    }
                } catch {
                    print("Error saving image: \(error)")
                }
            }

            await MainActor.run {
                selectedPhotoItems = []
            }

            // Clear image cache and reload
            await MainActor.run {
                ImageHelpers.clearCache(
                    for: currentItem.glassItem.sku ?? "",
                    manufacturer: currentItem.glassItem.manufacturer
                )
            }
        }
    }

    private func handlePrimarySelection(_ imageId: UUID?) {
        Task {
            do {
                if let imageId = imageId {
                    // Promote this image to primary, demote others to alternate
                    for image in userImages {
                        if image.id == imageId && image.imageType != .primary {
                            try await userImageRepository.updateImageType(imageId, type: .primary)
                        } else if image.id != imageId && image.imageType == .primary {
                            try await userImageRepository.updateImageType(image.id, type: .alternate)
                        }
                    }
                } else {
                    // Deselect all - demote all to alternate
                    for image in userImages where image.imageType == .primary {
                        try await userImageRepository.updateImageType(image.id, type: .alternate)
                    }
                }

                // Reload images
                await loadUserImages()

                // Clear cache to refresh image display across app
                await MainActor.run {
                    ImageHelpers.clearCache(
                        for: currentItem.glassItem.sku ?? "",
                        manufacturer: currentItem.glassItem.manufacturer
                    )
                }
            } catch {
                print("Error updating primary image: \(error)")
            }
        }
    }

    private func handleDeleteImage(_ imageId: UUID) {
        Task {
            do {
                try await userImageRepository.deleteImage(imageId)

                await MainActor.run {
                    userImages.removeAll { $0.id == imageId }
                    loadedImages.removeValue(forKey: imageId)
                }

                // Clear cache
                await MainActor.run {
                    ImageHelpers.clearCache(
                        for: currentItem.glassItem.sku ?? "",
                        manufacturer: currentItem.glassItem.manufacturer
                    )
                }
            } catch {
                print("Error deleting image: \(error)")
            }
        }
    }

    private func refreshItemData() {
        guard let service = inventoryTrackingService else {
            print("No inventory tracking service available for refresh")
            return
        }

        Task {
            isRefreshing = true
            defer { isRefreshing = false }

            do {
                // Fetch the updated complete item
                if let updatedItem = try await service.getCompleteItem(stableId: item.glassItem.stable_id) {
                    await MainActor.run {
                        currentItem = updatedItem
                    }
                }
            } catch {
                print("Error refreshing item data: \(error)")
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        GlassItemCard(
            item: currentItem.glassItem,
            variant: .large,
            tags: currentItem.tags,
            userTags: userTags,
            onManageTags: {
                showingUserTagsEditor = true
            }
        )
    }

    // MARK: - Glass Item Details Section

    private var glassItemDetailsSection: some View {
        ExpandableSection(
            title: "Glass Item Details",
            systemImage: "info.circle",
            isExpanded: expandedSections.contains("glass-item"),
            onToggle: { toggleSection("glass-item") }
        ) {
            VStack(alignment: .leading, spacing: 12) {
                // Show color approximation notice if no image permission
                if !GlassManufacturers.hasProductImagePermission(for: currentItem.glassItem.manufacturer) {
                    Text("We do not have permission to show glass images from this manufacturer, so have done our best to approximate the color of the glass. If you would like to suggest an image to our catalog, please upload an image to the app and long-press on it to submit it.")
                        .font(.caption)
                        .italic()
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                }

                if let notes = currentItem.glassItem.mfr_notes, !notes.isEmpty {
                    expandableNotesCard(title: "Manufacturer Notes", content: notes)
                }

                // User notes section - only show if notes exist
                if userNotes != nil {
                    userNotesSection
                }

                // Empty state - show when no manufacturer notes and no user notes
                let hasManufacturerNotes = currentItem.glassItem.mfr_notes != nil && !currentItem.glassItem.mfr_notes!.isEmpty
                if !hasManufacturerNotes && userNotes == nil {
                    emptyDetailsMessage
                }
            }
        }
    }

    // MARK: - Empty Details Message

    private var emptyDetailsMessage: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let manufacturerURL = currentItem.glassItem.url, let url = URL(string: manufacturerURL) {
                Text("Please check ") +
                Text("the manufacturer's site")
                    .foregroundColor(.blue) +
                Text(Image(systemName: "arrow.up.forward.square"))
                    .font(.caption)
                    .foregroundColor(.blue) +
                Text(" to see if they have more information available or add notes of your own.")
            } else {
                Text("No more details available here. Add notes of your own using the note button.")
            }
        }
        .font(.body)
        .foregroundColor(.secondary)
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            if let manufacturerURL = currentItem.glassItem.url, let url = URL(string: manufacturerURL) {
                UIApplication.shared.open(url)
            }
        }
    }

    // MARK: - User Notes Section

    private var userNotesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // User Notes
            if let notes = userNotes {
                // Show existing notes
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Your Notes")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Button(action: {
                            showingUserNotesEditor = true
                        }) {
                            Text("Edit")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.accentColor)
                        }
                    }

                    Text(notes.notes)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(isUserNotesExpanded ? nil : 4)

                    // Show More/Less button if notes are long
                    if notes.notes.split(separator: "\n").count > 4 || notes.notes.count > 200 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isUserNotesExpanded.toggle()
                            }
                        }) {
                            Text(isUserNotesExpanded ? "Show Less" : "Show More")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
                .background(Color.accentColor.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .id("user-notes") // Anchor for scrolling
            }
        }
    }

    // MARK: - Inventory Breakdown Section

    private var inventoryBreakdownSection: some View {
        ExpandableSection(
            title: "Inventory Details",
            systemImage: "cube.box",
            isExpanded: expandedSections.contains("inventory"),
            onToggle: { toggleSection("inventory") }
        ) {
            if currentItem.inventory.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "cube.box")
                        .font(.system(size: 30))
                        .foregroundColor(.secondary)
                    Text("No inventory recorded")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("Add Inventory") {
                        checkLimitAndShowAddInventory()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                LazyVStack(spacing: 8) {
                    // Group by type using inventoryByType computed property
                    ForEach(Array(currentItem.inventoryByType.keys.sorted()), id: \.self) { type in
                        let quantity = currentItem.inventoryByType[type] ?? 0
                        let typeInventory = currentItem.inventory.filter { $0.type == type }

                        InventoryDetailTypeRow(
                            type: type,
                            quantity: quantity,
                            inventoryRecords: typeInventory,
                            onTap: {
                                selectedInventoryType = InventoryTypeSelection(type: type)
                            }
                        )
                    }

                    // Add More button when inventory exists
                    Button {
                        checkLimitAndShowAddInventory()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add More Inventory")
                        }
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    // MARK: - Shopping List Section

    private var shoppingListSection: some View {
        ExpandableSection(
            title: "Shopping List",
            systemImage: "cart",
            isExpanded: expandedSections.contains("shopping-list"),
            onToggle: { toggleSection("shopping-list") }
        ) {
            if let shoppingItem = shoppingListItem {
                // Show shopping list item details
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Quantity")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(shoppingItem.formattedQuantity)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        Spacer()

                        if let store = shoppingItem.store {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Store")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(store)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Edit/Remove buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            showingShoppingListOptions = true
                        }) {
                            Label("Edit", systemImage: "pencil")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button(role: .destructive, action: {
                            removeFromShoppingList()
                        }) {
                            Label("Remove", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } else {
                // Empty state - no shopping list item
                VStack(spacing: 12) {
                    Image(systemName: "cart")
                        .font(.system(size: 30))
                        .foregroundColor(.secondary)
                    Text("Not on shopping list")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("Add to Shopping List") {
                        showingShoppingListOptions = true
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Custom Images Section

    private var customImagesSection: some View {
        ExpandableSection(
            title: "Custom Images",
            systemImage: "photo.on.rectangle",
            isExpanded: expandedSections.contains("custom-images"),
            onToggle: { toggleSection("custom-images") }
        ) {
            if isLoadingImages {
                ProgressView()
                    .padding()
            } else {
                GlassItemImageSelector(
                    glassItem: currentItem.glassItem,
                    images: userImages,
                    loadedImages: loadedImages,
                    manufacturerImage: manufacturerImage,
                    currentPrimaryImageId: userImages.first(where: { $0.imageType == .primary })?.id,
                    onSelectPrimary: { imageId in
                        handlePrimarySelection(imageId)
                    },
                    onAddImage: {
                        showingImagePicker = true
                    },
                    onDeleteImage: { imageId in
                        handleDeleteImage(imageId)
                    }
                )
            }
        }
    }

    // MARK: - Location Distribution Section

    private var locationDistributionSection: some View {
        ExpandableSection(
            title: "Location Distribution",
            systemImage: "location",
            isExpanded: expandedSections.contains("locations"),
            onToggle: { toggleSection("locations") }
        ) {
            LazyVStack(spacing: 8) {
                ForEach(Array(currentItem.inventoryByLocation.keys.sorted()), id: \.self) { locationName in
                    let quantity = currentItem.inventoryByLocation[locationName] ?? 0

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(locationName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Qty: \(formatQuantity(quantity))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // Progress bar showing relative quantity
                        let maxQuantity = currentItem.inventoryByLocation.values.max() ?? 1
                        let percentage = quantity / maxQuantity

                        HStack(spacing: 8) {
                            ProgressView(value: percentage)
                                .frame(width: 60)
                            Text("\(Int(percentage * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Primary actions
            HStack(spacing: 12) {
                Button(action: {
                    checkLimitAndShowAddInventory()
                }) {
                    Label("Add Inventory", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button(action: {
                    showingShoppingListOptions = true
                }) {
                    Label("Shopping List", systemImage: "cart.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(.top)
    }

    // MARK: - Helper Methods

    private func removeFromShoppingList() {
        Task {
            do {
                try await shoppingListRepository.deleteItem(forItem: item.glassItem.stable_id)
                await MainActor.run {
                    shoppingListItem = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to remove item from shopping list: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }

    private func toggleSection(_ sectionId: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedSections.contains(sectionId) {
                expandedSections.remove(sectionId)
            } else {
                expandedSections.insert(sectionId)
            }
        }
    }

    private func detailCard(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(content)
                .font(.body)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func expandableNotesCard(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)

            ExpandableText(content: content, lineLimit: 4, isExpanded: $isManufacturerNotesExpanded)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func specificationItem(title: String, value: String) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatQuantity(_ quantity: Double) -> String {
        if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", quantity)
        } else {
            return String(format: "%.1f", quantity)
        }
    }
}

// MARK: - Supporting Views



// MARK: - Preview

#Preview("Inventory Detail - With Data") {
    NavigationStack {
        let sampleGlassItem = GlassItemModel(
            stable_id: "bullseye-0001-0",
            name: "Bullseye Red Opal",
            sku: "0001",
            manufacturer: "bullseye",
            mfr_notes: "A beautiful deep red opal glass with excellent working properties.",
            coe: 90,
            url: "https://www.bullseyeglass.com/color/0001-red-opal",
            mfr_status: "available"
        )

        let sampleInventory = [
            InventoryModel(
                item_stable_id: "bullseye-0001-0",
                type: "rod",
                subtype: "stringer",
                dimensions: ["diameter": 3.0, "length": 40.0],
                quantity: 12.0
            ),
            InventoryModel(
                item_stable_id: "bullseye-0001-0",
                type: "rod",
                subtype: "standard",
                dimensions: ["diameter": 6.0, "length": 50.0],
                quantity: 5.0
            ),
            InventoryModel(
                item_stable_id: "bullseye-0001-0",
                type: "sheet",
                subtype: "transparent",
                dimensions: ["thickness": 3.0, "width": 30.0, "height": 40.0],
                quantity: 3.0
            ),
            InventoryModel(item_stable_id: "bullseye-0001-0", type: "frit", subtype: "medium", quantity: 8.5)
        ]

        let sampleCompleteItem = CompleteInventoryItemModel(
            glassItem: sampleGlassItem,
            inventory: sampleInventory,
            tags: ["red", "opal", "bullseye", "warm"],
            userTags: []
        )

        let deps = AppDependencies(persistenceController: .createTestController())
        InventoryDetailView(
            item: sampleCompleteItem,
            deps: deps
        )
    }
}

#Preview("Inventory Detail - Empty") {
    NavigationStack {
        let sampleGlassItem = GlassItemModel(
            stable_id: "spectrum-clear-0",
            name: "Clear Glass",
            sku: "clear",
            manufacturer: "spectrum",
            coe: 96,
            mfr_status: "available"
        )

        let sampleCompleteItem = CompleteInventoryItemModel(
            glassItem: sampleGlassItem,
            inventory: [],
            tags: [],
            userTags: []
        )

        let deps = AppDependencies(persistenceController: .createTestController())
        InventoryDetailView(
            item: sampleCompleteItem,
            deps: deps
        )
    }
}

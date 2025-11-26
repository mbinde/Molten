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
    let storageLocationDefinitionRepository: StorageLocationDefinitionRepository

    @Environment(\.dismiss) private var dismiss
    @Environment(EntitlementService.self) private var entitlementService
    @State private var isEditing = false

    // State for managing UI interactions
    @State private var editingInventoryRecord: InventoryModel?
    @State private var showingInventoryDetails = false
    @State private var selectedTypeRecords: (records: [InventoryModel], type: String)?
    @State private var showingShoppingListOptions = false
    @State private var showingUserNotesEditor = false
    @State private var showingUserTagsEditor = false
    @State private var showingAddInventory = false
    @State private var showingUpgradePrompt = false
    @State private var inventoryItemCount = 0
    @State private var inventoryItemLimit = 0
    @State private var expandedSections: Set<String> = ["glass-item", "inventory"]
    @State private var isManufacturerNotesExpanded: Bool
    @State private var showNavTitle = false

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
        glassItemRepository: GlassItemRepository,
        storageLocationDefinitionRepository: StorageLocationDefinitionRepository
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
        self.storageLocationDefinitionRepository = storageLocationDefinitionRepository
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
        self.storageLocationDefinitionRepository = deps.storageLocationDefinitionRepository
        // Initialize from user settings
        self._isManufacturerNotesExpanded = State(initialValue: UserSettings.shared.expandManufacturerDescriptionsByDefault)
        self._isUserNotesExpanded = State(initialValue: UserSettings.shared.expandUserNotesByDefault)
        // Initialize currentItem with the passed item
        self._currentItem = State(initialValue: item)
    }

    // MARK: - Computed Properties

    /// Binding for showing type records sheet (converts optional tuple to Bool)
    private var showingTypeRecordsBinding: Binding<Bool> {
        Binding(
            get: { selectedTypeRecords != nil },
            set: { if !$0 { selectedTypeRecords = nil } }
        )
    }

    /// Check if there's any content to show in the Glass Item Details section
    private var hasGlassItemDetails: Bool {
        let hasManufacturerNotes = currentItem.glassItem.mfr_notes != nil && !currentItem.glassItem.mfr_notes!.isEmpty
        let hasUserNotes = userNotes != nil
        return hasManufacturerNotes || hasUserNotes
    }

    // MARK: - View Body

    private var scrollableContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    // Hero header with large product image, with scroll tracking
                    heroHeaderSection
                        .id("header")
                        .background(
                            GeometryReader { geo -> Color in
                                // This runs during layout, updating the scroll position
                                DispatchQueue.main.async {
                                    let minY = geo.frame(in: .named("scroll")).minY
                                    let shouldShow = minY < -270  // Hero is ~280pt tall, show title when title bar scrolls off
                                    if showNavTitle != shouldShow {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            showNavTitle = shouldShow
                                        }
                                    }
                                }
                                return Color.clear
                            }
                        )

                    // Inventory Status Card (only show if there's inventory)
                    if !currentItem.inventory.isEmpty {
                        InventoryStatusCard(
                            inventory: currentItem.inventory,
                            onTapRecord: { record in
                                editingInventoryRecord = record
                            },
                            onTapRecordsForType: { records, type in
                                selectedTypeRecords = (records, type)
                            },
                            onTapDetails: {
                                showingInventoryDetails = true
                            }
                        )
                    }

                    // Specifications tile grid
                    specificationsSection

                    // Rating Words Section
                    RatingWordsSection(itemStableId: currentItem.glassItem.stable_id)

                    // Glass Item Details Section (manufacturer notes, user notes)
                    // Only show if there's content to display
                    if hasGlassItemDetails {
                        glassItemDetailsSection
                            .id("glass-item-section")
                    }

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

                    // Shopping List Section - only show if on shopping list
                    if shoppingListItem != nil {
                        shoppingListSection
                    }

                    // Tags Section
                    if !currentItem.tags.isEmpty || !userTags.isEmpty {
                        tagsSection
                    }

                    // Custom Images Section - only show if images exist
                    if !userImages.isEmpty {
                        customImagesSection
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .coordinateSpace(name: "scroll")
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
                .navigationTitle(showNavTitle ? currentItem.glassItem.name : "")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
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
                            .accessibilityIdentifier("fab_add_inventory")

                            Button {
                                showingShoppingListOptions = true
                            } label: {
                                Label("Add to Shopping List", systemImage: "cart.fill")
                            }
                            .accessibilityIdentifier("fab_add_shopping_list")

                            Button {
                                showingImagePicker = true
                            } label: {
                                Label("Add an Image", systemImage: "photo.fill")
                            }
                            .accessibilityIdentifier("fab_add_image")

                            Button {
                                showingUserNotesEditor = true
                            } label: {
                                Label("Add a Note", systemImage: "note.text")
                            }
                            .accessibilityIdentifier("fab_add_note")

                            Button {
                                showingUserTagsEditor = true
                            } label: {
                                Label("Manage Tags", systemImage: "tag.fill")
                            }
                            .accessibilityIdentifier("fab_manage_tags")
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .accessibilityLabel("Actions")
                        }
                        .accessibilityIdentifier("detail_actions_menu")
                    }
                }
            }
        }
        .sheet(isPresented: $showingShoppingListOptions, onDismiss: {
            // Reload shopping list after adding
            loadShoppingList()
        }) {
            ShoppingListOptionsView(item: item)
        }
        .sheet(isPresented: $showingInventoryDetails) {
            InventoryStorageDetailView(
                item: currentItem,
                inventoryType: ""  // Show all types
            )
            .onDisappear {
                // Refresh item data after details might have changed
                refreshItemData()
            }
        }
        .sheet(item: $editingInventoryRecord) { record in
            if let service = inventoryTrackingService {
                InventoryEditView(
                    record: record,
                    inventoryRepository: service.inventoryRepository,
                    storageLocationDefinitionRepository: storageLocationDefinitionRepository
                )
                .onDisappear {
                    // Refresh item data after editing
                    refreshItemData()
                }
            }
        }
        .sheet(isPresented: showingTypeRecordsBinding, onDismiss: {
            // Refresh item data after potentially editing records
            refreshItemData()
        }) {
            if let typeRecords = selectedTypeRecords,
               let service = inventoryTrackingService {
                InventoryTypeRecordsView(
                    records: typeRecords.records,
                    type: typeRecords.type,
                    itemName: currentItem.glassItem.name,
                    inventoryRepository: service.inventoryRepository
                )
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
            if let _ = inventoryTrackingService,
               let _ = catalogService {
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
        .onReceive(NotificationCenter.default.publisher(for: .inventoryItemAdded)) { _ in
            // Refresh when inventory is added (e.g., from three-dots menu)
            refreshItemData()
        }
    }

    // MARK: - Data Loading

    private func loadInitialData() {
        if let firstInventory = currentItem.inventory.first {
            editingQuantity = String(firstInventory.quantity)
            selectedType = firstInventory.type
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
        // Use the centralized image loading entry point
        manufacturerImage = await ImageHelpers.loadProductImageForDisplay(
            itemCode: currentItem.glassItem.stable_id,
            manufacturer: currentItem.glassItem.manufacturer,
            stableId: currentItem.glassItem.stable_id,
            imagePath: currentItem.glassItem.image_path,
            imageThumbPath: currentItem.glassItem.image_thumb_path,
            dominantColors: currentItem.glassItem.dominant_colors
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
        guard let catalogService = catalogService else { return }

        Task {
            // Use the same counting method as InventoryView for consistency:
            // CatalogDataCache + hasInventory (which checks hasStock)
            let items = await CatalogDataCache.loadItems(using: catalogService)
            let currentInventoryCount = items.filter { $0.hasInventory }.count
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
                loadUserImages()

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
            print("⚠️ No inventory tracking service available for refresh")
            return
        }

        print("🔄 refreshItemData() called for \(item.glassItem.stable_id)")

        Task {
            isRefreshing = true
            defer { isRefreshing = false }

            do {
                // Fetch the updated complete item
                if let updatedItem = try await service.getCompleteItem(stableId: item.glassItem.stable_id) {
                    print("✅ Got updated item with \(updatedItem.inventory.count) inventory records")
                    for inv in updatedItem.inventory {
                        print("   - \(inv.type): qty=\(inv.quantity), containers=\(inv.containerCount ?? 0)")
                    }
                    await MainActor.run {
                        currentItem = updatedItem
                        print("✅ Updated currentItem state")
                    }
                } else {
                    print("⚠️ getCompleteItem returned nil")
                }
            } catch {
                print("❌ Error refreshing item data: \(error)")
            }
        }
    }

    // MARK: - Hero Header Section

    private var heroHeaderSection: some View {
        HeroHeader(item: currentItem.glassItem, extendsToTop: true)
    }

    // MARK: - Specifications Section

    private var specificationsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Specifications")
                .font(DesignSystem.Typography.subsectionTitle)
                .fontWeight(DesignSystem.FontWeight.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            SpecificationTileGrid(tiles: specificationTiles)
        }
    }

    private var specificationTiles: [SpecificationTileGrid.TileData] {
        var tiles: [SpecificationTileGrid.TileData] = []

        // COE Rating for glass items, Temperature Range for coatings
        switch currentItem.catalogItem.itemType {
        case .glass:
            // COE Rating - expansion/contraction compatibility (e.g., "90 COE")
            if let coe = currentItem.catalogItem.coe {
                tiles.append(.init(
                    icon: "arrow.left.and.right",
                    value: "\(coe) COE"
                ))
            }
        case .coating:
            // Temperature range for coatings
            let tempUnit = UserSettings.shared.preferredTemperatureUnit
            let tempDisplay = tempUnit.formatTemperatureRange(
                lowF: currentItem.catalogItem.temperatureRangeLow,
                highF: currentItem.catalogItem.temperatureRangeHigh
            )
            tiles.append(.init(
                icon: "thermometer.medium",
                value: tempDisplay
            ))
        case .tool:
            // Tools don't have COE or temperature range
            break
        }

        // SKU (if available and not synthetic)
        if let sku = currentItem.catalogItem.sku, !sku.isEmpty, !isSyntheticSKU(sku) {
            tiles.append(.init(
                icon: "tag",
                value: sku
            ))
        }

        return tiles
    }

    private func isSyntheticSKU(_ sku: String) -> Bool {
        // Pattern: XXX-[8 hex chars] like "GRE-8bf530c2"
        let syntheticPattern = /^[A-Z]{2,4}-[a-f0-9]{8}$/
        return sku.wholeMatch(of: syntheticPattern) != nil
    }

    // MARK: - Tags Section

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Tags")
                    .font(DesignSystem.Typography.subsectionTitle)
                    .fontWeight(DesignSystem.FontWeight.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                Button(action: { showingUserTagsEditor = true }) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "pencil")
                        Text("Manage")
                    }
                    .font(DesignSystem.Typography.listItemCaption)
                    .foregroundColor(DesignSystem.Colors.accentUser)
                }
            }

            // Tags flow layout
            FlowLayout(spacing: DesignSystem.Spacing.sm) {
                ForEach(allTags, id: \.self) { tag in
                    tagChip(tag: tag, isUserTag: userTags.contains(tag))
                }
            }
        }
        .padding(DesignSystem.Padding.standard)
        .background(DesignSystem.Colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.extraLarge))
    }

    private var allTags: [String] {
        Array(Set(currentItem.tags + userTags)).sorted()
    }

    private func tagChip(tag: String, isUserTag: Bool) -> some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            if isUserTag {
                Image(systemName: "person.fill")
                    .font(.caption2)
            }
            Text(tag)
                .font(DesignSystem.Typography.listItemCaptionSmall)
                .fontWeight(DesignSystem.FontWeight.medium)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(isUserTag ? DesignSystem.Colors.tintUser : DesignSystem.Colors.tintPrimary)
        .foregroundColor(isUserTag ? DesignSystem.Colors.accentUser : DesignSystem.Colors.accentPrimary)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }

    // MARK: - Glass Item Details Section

    private var glassItemDetailsSection: some View {
        ExpandableSection(
            title: "Glass Item Details",
            systemImage: "info.circle",
            isExpanded: expandedSections.contains("glass-item"),
            onToggle: { toggleSection("glass-item") },
            accessibilityId: "section_glass_item"
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                if let notes = currentItem.glassItem.mfr_notes, !notes.isEmpty {
                    expandableNotesCard(title: "Manufacturer Notes", content: notes, accessibilityId: "expand_manufacturer_notes")
                }

                // User notes section - only show if notes exist
                if userNotes != nil {
                    userNotesSection
                }
            }
        }
        .accessibilityIdentifier("manufacturer_website_link")
    }

    // MARK: - User Notes Section

    private var userNotesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // User Notes
            if let notes = userNotes {
                // Show existing notes
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    HStack {
                        Text("Your Notes")
                            .font(DesignSystem.Typography.formLabel)
                            .fontWeight(DesignSystem.FontWeight.semibold)
                        Spacer()
                        Button(action: {
                            showingUserNotesEditor = true
                        }) {
                            Text("Edit")
                                .font(DesignSystem.Typography.listItemCaption)
                                .fontWeight(DesignSystem.FontWeight.medium)
                                .foregroundColor(DesignSystem.Colors.accentPrimary)
                        }
                    }

                    Text(notes.notes)
                        .font(DesignSystem.Typography.formValue)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(isUserNotesExpanded ? nil : 4)

                    // Show More/Less button if notes are long
                    if notes.notes.split(separator: "\n").count > 4 || notes.notes.count > 200 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isUserNotesExpanded.toggle()
                            }
                        }) {
                            Text(isUserNotesExpanded ? "Show Less" : "Show More")
                                .font(DesignSystem.Typography.listItemCaption)
                                .fontWeight(DesignSystem.FontWeight.medium)
                                .foregroundColor(DesignSystem.Colors.accentPrimary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("expand_user_notes")
                    }
                }
                .padding()
                .background(DesignSystem.Colors.tintUser)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .stroke(DesignSystem.Colors.accentUser.opacity(0.2), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                .id("user-notes") // Anchor for scrolling
            }
        }
    }

    // MARK: - Shopping List Section

    private var shoppingListSection: some View {
        ExpandableSection(
            title: "Shopping List",
            systemImage: "cart",
            isExpanded: expandedSections.contains("shopping-list"),
            onToggle: { toggleSection("shopping-list") },
            accessibilityId: "section_shopping_list"
        ) {
            if let shoppingItem = shoppingListItem {
                // Show shopping list item details
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    HStack {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Quantity")
                                .font(DesignSystem.Typography.listItemCaption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            Text(shoppingItem.formattedQuantity)
                                .font(DesignSystem.Typography.formLabel)
                                .fontWeight(DesignSystem.FontWeight.semibold)
                        }

                        Spacer()

                        if let store = shoppingItem.store {
                            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
                                Text("Store")
                                    .font(DesignSystem.Typography.listItemCaption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                Text(store)
                                    .font(DesignSystem.Typography.formLabel)
                                    .fontWeight(DesignSystem.FontWeight.medium)
                            }
                        }
                    }
                    .padding()
                    .background(DesignSystem.Colors.tintWarning.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                            .stroke(DesignSystem.Colors.moltenAmber.opacity(0.3), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))

                    // Edit/Remove buttons
                    HStack(spacing: DesignSystem.Spacing.lg) {
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
                VStack(spacing: DesignSystem.Spacing.lg) {
                    Image(systemName: "cart")
                        .font(.system(size: 30))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                    Text("Not on shopping list")
                        .font(DesignSystem.Typography.formLabel)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Button("Add to Shopping List") {
                        showingShoppingListOptions = true
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(DesignSystem.Colors.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            }
        }
    }

    // MARK: - Custom Images Section

    private var customImagesSection: some View {
        ExpandableSection(
            title: "Custom Images",
            systemImage: "photo.on.rectangle",
            isExpanded: expandedSections.contains("custom-images"),
            onToggle: { toggleSection("custom-images") },
            accessibilityId: "section_images"
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
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(title)
                .font(DesignSystem.Typography.formLabel)
                .fontWeight(DesignSystem.FontWeight.semibold)
            Text(content)
                .font(DesignSystem.Typography.formValue)
        }
        .padding()
        .background(DesignSystem.Colors.backgroundTertiary)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }

    private func expandableNotesCard(title: String, content: String, accessibilityId: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(title)
                .font(DesignSystem.Typography.formLabel)
                .fontWeight(DesignSystem.FontWeight.semibold)

            ExpandableText(content: content, lineLimit: 4, isExpanded: $isManufacturerNotesExpanded, accessibilityId: accessibilityId)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(DesignSystem.Colors.backgroundTertiary)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }

    private func specificationItem(title: String, value: String) -> some View {
        VStack(alignment: .center, spacing: DesignSystem.Spacing.xs) {
            Text(title)
                .font(DesignSystem.Typography.listItemCaptionSmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            Text(value)
                .font(DesignSystem.Typography.listItemCaption)
                .fontWeight(DesignSystem.FontWeight.medium)
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

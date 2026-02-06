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
    let catalogFlagBundledRepository: CatalogFlagBundledRepository
    #if DEBUG
    let catalogFlagAdminRepository: CatalogFlagAdminRepository
    let catalogTagAdminRepository: CatalogTagAdminRepository
    #endif

    /// Optional callback for QR scan workflow - shows "Manage Inventory" button near inventory section
    let onManageInventory: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(EntitlementService.self) private var entitlementService
    @State private var isEditing = false

    // State for managing UI interactions
    @State private var showingInventoryDetails = false
    @State private var showingShoppingListOptions = false
    @State private var showingUserNotesEditor = false
    @State private var showingAddInventory = false
    @State private var showingUpgradePrompt = false
    @State private var showingMoveSheet = false
    @State private var movingInventoryKey: InventoryGroupKey?
    @State private var inventoryItemCount = 0
    @State private var inventoryItemLimit = 0
    @State private var expandedSections: Set<String> = ["glass-item", "inventory", "shopping-list"]
    @State private var isManufacturerNotesExpanded: Bool
    @State private var showNavTitle = false

    // User notes state
    @State private var userNotes: UserNotesModel?
    @State private var isLoadingNotes = false
    @State private var isUserNotesExpanded = false

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
    @State private var heroImageRefreshTrigger = UUID()  // Change to refresh hero image
    @State private var scrollToPhotos = false  // Trigger scroll to Photos section

    // Kiln schedules state
    @State private var recommendedScheduleIds: [UUID] = []

    // Price per rod state (from storage locations with unit prices)
    @State private var averagePricePerRod: Decimal?
    @State private var latestPricePerRod: Decimal?

    // State for refreshing item data
    @State private var currentItem: CompleteInventoryItemModel
    @State private var isRefreshing = false

    // Editing state
    @State private var editingQuantity = ""
    @State private var selectedType = "rod"
    @State private var selectedinventory_id: UUID?

    @State private var showingError = false
    @State private var errorMessage: String?
    @State private var showingShareSheet = false

    // Online stock availability state
    @State private var onlineStock: OnlineStockModel?
    @State private var isLoadingStock = false
    @State private var stockLoadError: Error?

    #if DEBUG
    @State private var isProcessed = false
    #endif

    // MARK: - Initializers

    #if DEBUG
    /// Initialize with complete inventory model and service (DEBUG build with admin flags)
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
        storageLocationDefinitionRepository: StorageLocationDefinitionRepository,
        catalogFlagAdminRepository: CatalogFlagAdminRepository,
        catalogFlagBundledRepository: CatalogFlagBundledRepository,
        catalogTagAdminRepository: CatalogTagAdminRepository,
        onManageInventory: (() -> Void)? = nil
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
        self.catalogFlagBundledRepository = catalogFlagBundledRepository
        self.catalogFlagAdminRepository = catalogFlagAdminRepository
        self.catalogTagAdminRepository = catalogTagAdminRepository
        self.onManageInventory = onManageInventory
        // Initialize from user settings
        self._isManufacturerNotesExpanded = State(initialValue: UserSettings.shared.expandManufacturerDescriptionsByDefault)
        self._isUserNotesExpanded = State(initialValue: UserSettings.shared.expandUserNotesByDefault)
        // Initialize currentItem with the passed item
        self._currentItem = State(initialValue: item)
    }
    #endif

    /// Convenience init using AppDependencies
    init(
        item: CompleteInventoryItemModel,
        deps: AppDependencies = .shared,
        onManageInventory: (() -> Void)? = nil
    ) {
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
        self.catalogFlagBundledRepository = deps.catalogFlagBundledRepository
        #if DEBUG
        self.catalogFlagAdminRepository = deps.catalogFlagAdminRepository
        self.catalogTagAdminRepository = deps.catalogTagAdminRepository
        #endif
        self.onManageInventory = onManageInventory
        // Initialize from user settings
        self._isManufacturerNotesExpanded = State(initialValue: UserSettings.shared.expandManufacturerDescriptionsByDefault)
        self._isUserNotesExpanded = State(initialValue: UserSettings.shared.expandUserNotesByDefault)
        // Initialize currentItem with the passed item
        self._currentItem = State(initialValue: item)
    }

    // MARK: - Computed Properties

    /// Check if we can show descriptions for this item
    private var canShowManufacturerDescription: Bool {
        GlassManufacturers.productDescriptionPermissions[currentItem.glassItem.manufacturer] ?? false
    }

    /// Check if there's any content to show in the Glass Item Details section
    private var hasGlassItemDetails: Bool {
        let hasManufacturerNotes = canShowManufacturerDescription
            && currentItem.glassItem.mfr_notes != nil
            && !currentItem.glassItem.mfr_notes!.isEmpty
        let hasUserNotes = userNotes != nil
        return hasManufacturerNotes || hasUserNotes
    }

    /// Text content for sharing this glass item
    private var shareText: String {
        let glassItem = currentItem.glassItem
        let manufacturerName = GlassManufacturers.fullName(for: glassItem.manufacturer) ?? glassItem.manufacturer

        var text = "\(glassItem.name)\n"
        text += "\(manufacturerName)"

        if let sku = glassItem.sku, !sku.isEmpty {
            text += " • \(sku)"
        }

        text += " • COE \(glassItem.coe)"

        if canShowManufacturerDescription,
           let description = glassItem.mfr_notes, !description.isEmpty {
            text += "\n\n\(description)"
        }

        // Add deep link URL for opening in Molten (view-only, no QR quick actions)
        text += "\n\nmolten://v/\(glassItem.stable_id)"

        return text
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
                            onIncrement: { key in
                                incrementInventory(key: key)
                            },
                            onDecrement: { key in
                                decrementInventory(key: key)
                            },
                            onMove: { key in
                                movingInventoryKey = key
                                showingMoveSheet = true
                            },
                            onTapDetails: {
                                showingInventoryDetails = true
                            }
                        )
                    }

                    // Manage Inventory button (QR scan workflow)
                    if let onManageInventory = onManageInventory {
                        Button {
                            onManageInventory()
                        } label: {
                            HStack {
                                Image(systemName: "plusminus.circle.fill")
                                    .font(.title2)
                                Text("Manage Inventory")
                                    .font(DesignSystem.Typography.listItemTitle)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                            }
                            .padding()
                            .foregroundColor(DesignSystem.Colors.moltenTeal)
                        }
                        .background(DesignSystem.Colors.tintTeal)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                        .padding(.horizontal)
                    }

                    // Specifications tile grid
                    specificationsSection

                    // Online Stock Availability Section
                    if FeatureFlags.ENABLE_ONLINE_STOCK {
                        OnlineStockCard(
                            stockData: onlineStock,
                            isLoading: isLoadingStock,
                            error: stockLoadError,
                            onRetailerTap: { retailer in
                                if let urlString = retailer.productUrl,
                                   let url = URL(string: urlString) {
                                    #if os(iOS)
                                    UIApplication.shared.open(url)
                                    #elseif os(macOS)
                                    NSWorkspace.shared.open(url)
                                    #endif
                                }
                            },
                            onRefresh: {
                                loadOnlineStock(forceRefresh: true)
                            }
                        )
                        .padding(.horizontal)
                    }

                    // Rating Words Section
                    RatingWordsSection(itemStableId: currentItem.glassItem.stable_id)

                    // Glass Item Details Section (description, user notes)
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

                    // Custom Images Section - only show when user has uploaded images
                    if !userImages.isEmpty {
                        customImagesSection
                            .id("your-photos")
                    }

                    // Debug: Catalog Flag Editor (only in DEBUG builds)
                    #if DEBUG
                    // Processed checkbox - always visible, not in a dropdown
                    HStack {
                        Button {
                            isProcessed.toggle()
                            Task {
                                await saveProcessedState()
                            }
                        } label: {
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                Image(systemName: isProcessed ? "checkmark.square.fill" : "square")
                                    .foregroundColor(isProcessed ? DesignSystem.Colors.accentSuccess : DesignSystem.Colors.textSecondary)
                                    .font(.title2)
                                Text("Done")
                                    .font(DesignSystem.Typography.formLabel)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(DesignSystem.Padding.standard)
                    .background(isProcessed ? DesignSystem.Colors.accentSuccess.opacity(0.1) : DesignSystem.Colors.backgroundSecondary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))

                    CatalogTagEditorView(
                        itemStableId: currentItem.glassItem.stable_id
                    )

                    CatalogFlagEditorView(
                        itemStableId: currentItem.glassItem.stable_id,
                        catalogFlagAdminRepository: catalogFlagAdminRepository,
                        catalogFlagBundledRepository: catalogFlagBundledRepository,
                        catalogTagAdminRepository: catalogTagAdminRepository
                    )

                    CatalogDescriptionEditorView(
                        itemStableId: currentItem.glassItem.stable_id,
                        currentDescription: currentItem.glassItem.mfr_notes,
                        catalogFlagAdminRepository: catalogFlagAdminRepository
                    )

                    CatalogOriginalDescriptionView(
                        itemStableId: currentItem.glassItem.stable_id
                    )
                    #endif

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
            .onChange(of: scrollToPhotos) { _, shouldScroll in
                // Scroll to Your Photos section after adding an image
                if shouldScroll {
                    // Small delay to let the section appear first
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation {
                            proxy.scrollTo("your-photos", anchor: .top)
                        }
                        scrollToPhotos = false
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("inventory_detail_share")
                }
            }
            #endif
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [shareText])
        }
        .sheet(isPresented: $showingShoppingListOptions, onDismiss: {
            // Reload shopping list after adding/editing
            loadShoppingList()
        }) {
            AddShoppingListItemView(
                prefilledNaturalKey: item.glassItem.stable_id,
                existingItem: shoppingListItem  // Pass existing item for edit mode
            )
        }
        .sheet(isPresented: $showingInventoryDetails, onDismiss: {
            // Refresh item data after details might have changed
            refreshItemData()
        }) {
            InventoryStorageDetailView(
                item: currentItem,
                inventoryType: ""  // Show all types
            )
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
        .sheet(isPresented: $showingAddInventory, onDismiss: {
            // Refresh item data after adding inventory
            refreshItemData()
        }) {
            if let _ = inventoryTrackingService,
               let _ = catalogService {
                AddInventoryItemView(
                    prefilledNaturalKey: item.glassItem.stable_id,
                    deps: .shared
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
        .sheet(isPresented: $showingMoveSheet, onDismiss: {
            // Refresh data when sheet dismisses to ensure UI is in sync
            // This catches cases where the async move operation completes after dismissal
            refreshItemData()
        }) {
            if let key = movingInventoryKey {
                let quantity = quantityForKey(key)
                MoveInventorySheet(
                    sourceKey: key,
                    itemName: currentItem.glassItem.name,
                    availableQuantity: quantity,
                    storageLocationDefinitionRepository: storageLocationDefinitionRepository,
                    onMove: { destinationLocation, quantityToMove in
                        moveInventory(from: key, to: destinationLocation, quantity: quantityToMove)
                    }
                )
            }
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
            NotificationCenter.default.post(name: .detailViewAppeared, object: nil)
            loadInitialData()
            loadUserNotes()
            loadShoppingList()
            loadUserImages()
            loadRecommendedSchedules()
            loadPricePerRod()
            if FeatureFlags.ENABLE_ONLINE_STOCK {
                loadOnlineStock()
            }
            #if DEBUG
            Task { await loadProcessedState() }
            #endif
        }
        .onDisappear {
            NotificationCenter.default.post(name: .detailViewDisappeared, object: nil)
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

    private func loadShoppingList() {
        Task { @MainActor in
            isLoadingShoppingList = true

            do {
                shoppingListItem = try await shoppingListRepository.fetchItem(forItem: item.glassItem.stable_id)
            } catch {
                // No shopping list item is fine, just leave nil
                shoppingListItem = nil
                print("No shopping list item found or error loading: \(error)")
            }

            isLoadingShoppingList = false
        }
    }

    private func loadOnlineStock(forceRefresh: Bool = false) {
        Task {
            isLoadingStock = true
            stockLoadError = nil
            defer { isLoadingStock = false }

            do {
                onlineStock = try await AppDependencies.shared.onlineStockService.getStock(
                    for: currentItem.catalogItem.stable_id,
                    forceRefresh: forceRefresh
                )
            } catch {
                stockLoadError = error
                // Stock checking is optional - don't show error to user
                print("Error loading online stock: \(error)")
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
        // Load manufacturer-only image (exclude user images)
        // This is used for the "Your Photos" section to show the default alongside user photos
        manufacturerImage = await ImageHelpers.loadProductImageForDisplay(
            itemCode: currentItem.glassItem.stable_id,
            manufacturer: currentItem.glassItem.manufacturer,
            stableId: currentItem.glassItem.stable_id,
            imagePath: currentItem.glassItem.image_path,
            imageThumbPath: currentItem.glassItem.image_thumb_path,
            dominantColors: currentItem.glassItem.dominant_colors,
            excludeUserImages: true
        )
    }

    #if DEBUG
    @MainActor
    private func loadProcessedState() async {
        do {
            let stableId = currentItem.glassItem.stable_id

            // Check admin repository (CloudKit - manually set in app)
            let adminFlags = try await catalogFlagAdminRepository.fetchFlags(for: stableId)
            let adminProcessed = adminFlags.contains { $0.flag_key == kProcessedKey && $0.flag_value }

            // Check bundled repository (SQLite - imported from export)
            let bundledFlags = try await catalogFlagBundledRepository.fetchFlags(for: stableId)
            let bundledProcessed = bundledFlags.contains { $0.flag_key == kProcessedKey && $0.flag_value }

            isProcessed = adminProcessed || bundledProcessed
        } catch {
            print("Error loading processed state: \(error)")
        }
    }

    @MainActor
    private func saveProcessedState() async {
        do {
            if isProcessed {
                // Save the processed flag
                let flag = CatalogFlagAdminModel(
                    item_stable_id: currentItem.glassItem.stable_id,
                    flag_key: kProcessedKey,
                    flag_value: true
                )
                try await catalogFlagAdminRepository.saveFlag(flag)
            } else {
                // Remove the processed flag
                try await catalogFlagAdminRepository.removeAdminFlag(
                    item_stable_id: currentItem.glassItem.stable_id,
                    flag_key: kProcessedKey
                )
            }
            // Notify catalog list to update row styling
            NotificationCenter.default.post(name: .catalogFlagChanged, object: nil)
        } catch {
            print("Error saving processed state: \(error)")
        }
    }
    #endif

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

    private func loadPricePerRod() {
        // Get rod inventory IDs from current item
        let rodInventoryIds = Set(currentItem.inventory
            .filter { $0.type.lowercased() == "rod" }
            .map { $0.id })

        // Filter storage locations for rod inventory with unit prices
        let rodLocationsWithPrice = currentItem.storageLocations
            .filter { rodInventoryIds.contains($0.inventoryId) && $0.unitPrice != nil }
            .sorted { loc1, loc2 in
                // Sort by purchaseDate (most recent first), fall back to dateAdded
                let date1 = loc1.purchaseDate ?? loc1.dateAdded
                let date2 = loc2.purchaseDate ?? loc2.dateAdded
                return date1 > date2
            }

        guard !rodLocationsWithPrice.isEmpty else { return }

        // Calculate average price
        let prices = rodLocationsWithPrice.compactMap { $0.unitPrice }
        let sum = prices.reduce(Decimal(0)) { $0 + $1 }
        let average = sum / Decimal(prices.count)

        // Get latest price (most recent by purchaseDate)
        let latest = rodLocationsWithPrice.first?.unitPrice

        averagePricePerRod = average
        latestPricePerRod = latest
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
                    // New images are always saved as alternate - user must explicitly select as primary
                    // Save image (repository handles resizing)
                    let imageModel = try await userImageRepository.saveImage(
                        imageToSave,
                        ownerType: .glassItem,
                        ownerId: currentItem.glassItem.stable_id,
                        type: .alternate
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

            // Clear image cache and reload, then scroll to photos section
            await MainActor.run {
                ImageHelpers.clearCache(
                    for: currentItem.glassItem.sku ?? "",
                    manufacturer: currentItem.glassItem.manufacturer
                )
                // Scroll to photos section so user sees their new image
                scrollToPhotos = true
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
                    // Trigger hero image refresh
                    heroImageRefreshTrigger = UUID()
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
            print("⚠️ [REFRESH] No inventory tracking service available for refresh")
            return
        }

        print("🔄 [REFRESH] refreshItemData() called for \(item.glassItem.stable_id)")
        print("🔄 [REFRESH] Current inventory before refresh:")
        for inv in currentItem.inventory {
            print("   - \(inv.type): qty=\(inv.quantity), id=\(inv.id)")
        }

        Task {
            isRefreshing = true
            defer { isRefreshing = false }

            do {
                // Fetch the updated complete item
                if let updatedItem = try await service.getCompleteItem(stableId: item.glassItem.stable_id) {
                    print("✅ [REFRESH] Got updated item with \(updatedItem.inventory.count) inventory records")
                    for inv in updatedItem.inventory {
                        print("   - \(inv.type): qty=\(inv.quantity), id=\(inv.id)")
                    }
                    await MainActor.run {
                        currentItem = updatedItem
                        print("✅ [REFRESH] Updated currentItem state on MainActor")
                    }
                } else {
                    print("⚠️ [REFRESH] getCompleteItem returned nil")
                }
            } catch {
                print("❌ [REFRESH] Error refreshing item data: \(error)")
            }
        }
    }

    // MARK: - Inventory Adjustment

    private func incrementInventory(key: InventoryGroupKey) {
        guard let service = inventoryTrackingService else { return }

        Task {
            do {
                _ = try await service.incrementInventory(
                    forItem: item.glassItem.stable_id,
                    type: key.type,
                    subtype: key.subtype,
                    subsubtype: key.subsubtype,
                    atLocation: key.location
                )
                // Update local state immediately
                await refreshItemDataAsync()
            } catch {
                print("❌ Error incrementing inventory: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to add inventory: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }

    private func decrementInventory(key: InventoryGroupKey) {
        guard let service = inventoryTrackingService else { return }

        Task {
            do {
                _ = try await service.decrementInventoryLIFO(
                    forItem: item.glassItem.stable_id,
                    type: key.type,
                    subtype: key.subtype,
                    subsubtype: key.subsubtype,
                    atLocation: key.location
                )
                // Update local state immediately
                await refreshItemDataAsync()
            } catch {
                print("❌ Error decrementing inventory: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to remove inventory: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }

    /// Async version of refreshItemData that can be awaited
    private func refreshItemDataAsync() async {
        guard let service = inventoryTrackingService else { return }

        do {
            if let updatedItem = try await service.getCompleteItem(stableId: item.glassItem.stable_id) {
                await MainActor.run {
                    currentItem = updatedItem
                }
            }
        } catch {
            print("❌ Error refreshing item data: \(error)")
        }
    }

    private func moveInventory(from sourceKey: InventoryGroupKey, to destinationLocation: String?, quantity: Int) {
        guard let service = inventoryTrackingService else { return }

        Task {
            do {
                // Move specified quantity from source to destination
                // Each move decrements from source (LIFO) and increments at destination
                for _ in 0..<quantity {
                    try await service.moveInventory(
                        forItem: item.glassItem.stable_id,
                        type: sourceKey.type,
                        subtype: sourceKey.subtype,
                        subsubtype: sourceKey.subsubtype,
                        fromLocation: sourceKey.location,
                        toLocation: destinationLocation
                    )
                }
                // Update local state
                await refreshItemDataAsync()
            } catch {
                print("❌ Error moving inventory: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to move inventory: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }

    /// Get the total quantity for a given inventory group key
    private func quantityForKey(_ key: InventoryGroupKey) -> Double {
        currentItem.inventory
            .filter { record in
                record.location == key.location &&
                record.type == key.type &&
                record.subtype == key.subtype &&
                record.subsubtype == key.subsubtype
            }
            .reduce(0) { $0 + $1.quantity }
    }

    // MARK: - Hero Header Section

    private var heroHeaderSection: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            HeroHeader(
                item: currentItem.glassItem,
                extendsToTop: true,
                onAddPhoto: {
                    showingImagePicker = true
                },
                imageRefreshTrigger: heroImageRefreshTrigger
            )

            // Quick actions bar for common operations
            QuickActionsBar(actions: [
                QuickAction(title: "Inventory", icon: "archivebox.fill") {
                    checkLimitAndShowAddInventory()
                },
                QuickAction(title: "Shopping", icon: "cart.fill") {
                    showingShoppingListOptions = true
                },
                QuickAction(title: "Note", icon: "note.text") {
                    showingUserNotesEditor = true
                }
            ])
        }
    }

    // MARK: - Specifications Section

    private var specificationsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Specifications")
                .font(DesignSystem.Typography.subsectionTitle)
                .fontWeight(DesignSystem.FontWeight.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            SpecificationTileGrid(tiles: specificationTiles)

            // Price per rod (from storage locations) - only show if price > 0
            if let avgPrice = averagePricePerRod, avgPrice > 0 {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    HStack {
                        Text("Your average price per rod:")
                            .font(DesignSystem.Typography.formLabel)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Text(formatPrice(avgPrice))
                            .font(DesignSystem.Typography.formLabel)
                            .fontWeight(DesignSystem.FontWeight.semibold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }

                    // Show latest price if different from average
                    if let latestPrice = latestPricePerRod, latestPrice != avgPrice {
                        HStack {
                            Text("Your latest price per rod:")
                                .font(DesignSystem.Typography.formLabel)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            Text(formatPrice(latestPrice))
                                .font(DesignSystem.Typography.formLabel)
                                .fontWeight(DesignSystem.FontWeight.semibold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                        }
                    }
                }
            }
        }
    }

    private func formatPrice(_ price: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: price as NSDecimalNumber) ?? "$\(price)"
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


    // MARK: - Description Section

    private var glassItemDetailsSection: some View {
        ExpandableSection(
            title: "Description",
            systemImage: "info.circle",
            isExpanded: expandedSections.contains("glass-item"),
            onToggle: { toggleSection("glass-item") },
            accessibilityId: "section_description"
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Bundled catalog flags (shown as tag-style chips)
                BundledFlagsChipsView(
                    itemStableId: currentItem.glassItem.stable_id,
                    repository: catalogFlagBundledRepository
                )

                if canShowManufacturerDescription,
                   let notes = currentItem.glassItem.mfr_notes, !notes.isEmpty {
                    expandableNotesCard(title: nil, content: notes, accessibilityId: "expand_description")
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
                        .tint(DesignSystem.Colors.accentDanger)
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
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Photos")
                    .font(DesignSystem.Typography.subsectionTitle)
                    .fontWeight(DesignSystem.FontWeight.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                Button {
                    showingImagePicker = true
                } label: {
                    Label("Add Photo", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("photos_add_button")
            }

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
        .padding(DesignSystem.Padding.standard)
        .background(DesignSystem.Colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.extraLarge))
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

    private func expandableNotesCard(title: String?, content: String, accessibilityId: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            if let title = title {
                Text(title)
                    .font(DesignSystem.Typography.formLabel)
                    .fontWeight(DesignSystem.FontWeight.semibold)
            }

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

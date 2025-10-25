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
    let userImageRepository: UserImageRepository

    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false

    // State for managing UI interactions
    @State private var selectedInventoryType: InventoryTypeSelection?
    @State private var showingShoppingListOptions = false
    @State private var showingUserNotesEditor = false
    @State private var showingUserTagsEditor = false
    @State private var showingAddInventory = false
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
    @State private var loadedImages: [UUID: UIImage] = [:]
    @State private var manufacturerImage: UIImage?
    @State private var showingImagePicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isLoadingImages = false

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
        userNotesRepository: UserNotesRepository = RepositoryFactory.createUserNotesRepository(),
        userTagsRepository: UserTagsRepository = RepositoryFactory.createUserTagsRepository(),
        shoppingListRepository: ShoppingListRepository = RepositoryFactory.createShoppingListRepository(),
        userImageRepository: UserImageRepository = RepositoryFactory.createUserImageRepository()
    ) {
        self.item = item
        self.inventoryTrackingService = inventoryTrackingService
        self.catalogService = catalogService
        self.userNotesRepository = userNotesRepository
        self.userTagsRepository = userTagsRepository
        self.shoppingListRepository = shoppingListRepository
        self.userImageRepository = userImageRepository
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

                    // Glass Item Details Section
                    glassItemDetailsSection
                        .id("glass-item-section")

                    // Inventory Breakdown Section
                    inventoryBreakdownSection

                    // Shopping List Section
                    shoppingListSection

                    // Location Distribution Section
                    if !currentItem.locations.isEmpty {
                        locationDistributionSection
                    }

                    // Custom Images Section
                    customImagesSection

                    // Actions Section
                    actionsSection

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
        scrollableContent
            .navigationTitle(currentItem.glassItem.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if !isEditing {
                    Menu {
                        Button("Add Inventory", systemImage: "plus.circle.fill") {
                            showingAddInventory = true
                        }
                        Button("Add to Shopping List", systemImage: "cart.badge.plus") {
                            showingShoppingListOptions = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingShoppingListOptions, onDismiss: {
            // Reload shopping list after adding
            loadShoppingList()
        }) {
            ShoppingListOptionsView(item: item, shoppingListRepository: shoppingListRepository)
        }
        .sheet(item: $selectedInventoryType) { selection in
            LocationDetailView(
                item: currentItem,
                inventoryType: selection.type
            )
            .onAppear {
                print("🔍 Sheet: Showing LocationDetailView for type: \(selection.type)")
            }
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
                    inventoryTrackingService: inventoryTrackingService,
                    catalogService: catalogService
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
            loadInitialData()
            loadUserNotes()
            loadUserTags()
            loadShoppingList()
            loadUserImages()
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
        manufacturerImage = ImageHelpers.loadProductImage(
            for: currentItem.glassItem.sku,
            manufacturer: currentItem.glassItem.manufacturer,
            stableId: currentItem.glassItem.stable_id
        )
    }

    private func handleImageSelection(_ items: [PhotosPickerItem]) {
        Task {
            for item in items {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    continue
                }

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
                    for: currentItem.glassItem.sku,
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
                        for: currentItem.glassItem.sku,
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
                        for: currentItem.glassItem.sku,
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
                if let notes = currentItem.glassItem.mfr_notes, !notes.isEmpty {
                    expandableNotesCard(title: "Manufacturer Notes", content: notes)
                }

                // User notes section
                userNotesSection
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
                                .foregroundColor(.blue)
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
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .id("user-notes") // Anchor for scrolling
            } else {
                // Add note button
                Button(action: {
                    showingUserNotesEditor = true
                }) {
                    HStack {
                        Image(systemName: "note.text.badge.plus")
                        Text("Add a note for \(currentItem.glassItem.name)")
                        Spacer()
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
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
                        showingAddInventory = true
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
                                print("🔍 Type row tapped: \(type)")
                                selectedInventoryType = InventoryTypeSelection(type: type)
                                print("🔍 Set selectedInventoryType to: \(selectedInventoryType?.type ?? "nil")")
                            }
                        )
                    }
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
                    showingAddInventory = true
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

            Text(content)
                .font(.body)
                .lineLimit(isManufacturerNotesExpanded ? nil : 4)

            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isManufacturerNotesExpanded.toggle()
                }
            }) {
                Text(isManufacturerNotesExpanded ? "Show Less" : "Show More")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
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

/// Expandable section with animation
struct ExpandableSection<Content: View>: View {
    let title: String
    let systemImage: String
    let isExpanded: Bool
    let onToggle: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    Image(systemName: systemImage)
                        .foregroundColor(.blue)
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            if isExpanded {
                content
                    .transition(.opacity.combined(with: .slide))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
}

/// Inventory type row with tap handling for detail view
struct InventoryDetailTypeRow: View {
    let type: String
    let quantity: Double
    let inventoryRecords: [InventoryModel]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.capitalized)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    // Show subtypes if present
                    if !subtypesSummary.isEmpty {
                        Text(subtypesSummary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Show dimensions summary if present
                    if !dimensionsSummary.isEmpty {
                        Text(dimensionsSummary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("\(inventoryRecords.count) record\(inventoryRecords.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatQuantity(quantity))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    Text("units")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color.secondary.opacity(0.6))
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    /// Get a summary of subtypes present in inventory records
    private var subtypesSummary: String {
        let subtypes = Set(inventoryRecords.compactMap { $0.subtype }).sorted()
        if subtypes.isEmpty {
            return ""
        } else if subtypes.count == 1 {
            return subtypes[0].capitalized
        } else if subtypes.count == 2 {
            return subtypes.map { $0.capitalized }.joined(separator: ", ")
        } else {
            return "\(subtypes.count) subtypes"
        }
    }

    /// Get a summary of dimensions present in inventory records
    private var dimensionsSummary: String {
        let recordsWithDimensions = inventoryRecords.filter { $0.dimensions != nil && !($0.dimensions?.isEmpty ?? true) }

        if recordsWithDimensions.isEmpty {
            return ""
        }

        // If there's just one record with dimensions, show them
        if recordsWithDimensions.count == 1, let dims = recordsWithDimensions.first?.dimensions {
            return formatDimensions(dims)
        }

        // Otherwise, just indicate there are multiple dimension sets
        return "\(recordsWithDimensions.count) with dimensions"
    }

    /// Format dimensions for display
    private func formatDimensions(_ dimensions: [String: Double]) -> String {
        let formatted = GlassItemTypeSystem.formatDimensions(dimensions, for: type)
        if formatted.count > 40 {
            return String(formatted.prefix(40)) + "..."
        }
        return formatted
    }

    private func formatQuantity(_ quantity: Double) -> String {
        if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", quantity)
        } else {
            return String(format: "%.1f", quantity)
        }
    }
}

/// Shopping list options view with item card, quantity, and store autocomplete
struct ShoppingListOptionsView: View {
    let item: CompleteInventoryItemModel
    let shoppingListRepository: ShoppingListRepository
    @Environment(\.dismiss) private var dismiss

    @State private var quantity: String = ""
    @State private var store: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccessToast = false
    @State private var isSaving = false

    init(item: CompleteInventoryItemModel, shoppingListRepository: ShoppingListRepository) {
        self.item = item
        self.shoppingListRepository = shoppingListRepository
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Glass Item Card
                    GlassItemCard(item: item.glassItem, variant: .compact)

                    // Form Section
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        // Quantity Field
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Quantity")
                                .font(DesignSystem.Typography.label)
                                .fontWeight(DesignSystem.FontWeight.medium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)

                            TextField("Enter quantity", text: $quantity)
                                .textFieldStyle(.roundedBorder)
                                #if canImport(UIKit)
                                .keyboardType(.decimalPad)
                                #endif
                        }

                        // Store Field
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Store")
                                .font(DesignSystem.Typography.label)
                                .fontWeight(DesignSystem.FontWeight.medium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)

                            StoreAutoCompleteField(
                                store: $store,
                                shoppingListRepository: shoppingListRepository
                            )
                        }
                    }

                    // Save Button
                    Button(action: saveToShoppingList) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Add to Shopping List")
                                .fontWeight(DesignSystem.FontWeight.semibold)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isSaving || quantity.isEmpty)

                    Spacer()
                }
                .padding(DesignSystem.Padding.standard)
            }
            .navigationTitle("Add to Shopping List")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .successToast(message: "Item added to shopping list", isShowing: $showingSuccessToast)
        }
    }

    // MARK: - Actions

    private func saveToShoppingList() {
        // Validate quantity
        guard let quantityValue = Double(quantity), quantityValue > 0 else {
            errorMessage = "Please enter a valid quantity greater than 0"
            showingError = true
            return
        }

        isSaving = true

        Task {
            do {
                // Use addQuantity which handles creating or updating
                let storeValue = store.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalStore = storeValue.isEmpty ? nil : storeValue

                _ = try await shoppingListRepository.addQuantity(
                    quantityValue,
                    toItem: item.glassItem.stable_id,
                    store: finalStore
                )

                await MainActor.run {
                    isSaving = false

                    // Post notification to refresh shopping list
                    NotificationCenter.default.post(name: .shoppingListItemAdded, object: nil)

                    // Show success toast and dismiss immediately
                    showingSuccessToast = true
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to add item to shopping list: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
}

/// View showing all inventory records for an item
/// Allows toggling between grouping by location or by type
struct LocationDetailView: View {
    let item: CompleteInventoryItemModel
    let inventoryType: String

    @Environment(\.dismiss) private var dismiss
    @State private var groupByLocation = true  // true = group by location, false = group by type
    @State private var showingAddInventory = false
    @State private var editingRecord: InventoryModel?

    private let inventoryRepository = RepositoryFactory.createInventoryRepository()

    var body: some View {
        NavigationStack {
            Group {
                if item.inventory.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "cube.box")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No inventory found")
                            .font(.headline)
                        Text("Showing \(item.glassItem.name)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    List {
                        // Show total summary
                        Section {
                            HStack {
                                Text("Total Inventory")
                                    .font(.headline)
                                Spacer()
                                Text(formatQuantity(totalQuantity))
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                            }
                        }

                        if groupByLocation {
                            groupedByLocationView
                        } else {
                            groupedByTypeView
                        }
                    }
                }
            }
            .navigationTitle(item.glassItem.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: {
                            showingAddInventory = true
                        }) {
                            Label("Add Inventory", systemImage: "plus.circle")
                        }

                        Button(action: {
                            withAnimation {
                                groupByLocation.toggle()
                            }
                        }) {
                            Label(groupByLocation ? "Group by Type" : "Group by Location",
                                  systemImage: groupByLocation ? "list.bullet" : "location")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                print("🔍 LocationDetailView onAppear - item: \(item.glassItem.name)")
                print("🔍 Total inventory records: \(item.inventory.count)")
            }
            .sheet(item: $editingRecord) { record in
                InventoryEditView(
                    record: record,
                    inventoryRepository: inventoryRepository
                )
            }
            .sheet(isPresented: $showingAddInventory) {
                // Present add inventory view (simplified quick-add form)
                QuickAddInventoryView(
                    itemStableId: item.glassItem.stable_id,
                    itemName: item.glassItem.name,
                    inventoryRepository: inventoryRepository
                )
            }
        }
    }

    @ViewBuilder
    private var groupedByLocationView: some View {
        ForEach(Array(item.inventoryByLocation.keys.sorted()), id: \.self) { locationKey in
            let records = item.inventory.filter { ($0.location ?? "No location") == locationKey }
            let locationQuantity = records.reduce(0.0) { $0 + $1.quantity }

            Section(header: Text(locationKey)) {
                ForEach(records, id: \.id) { record in
                    InventoryRecordRow(
                        record: record,
                        onDelete: {
                            deleteRecord(record)
                        },
                        showType: true,  // Show type when grouped by location
                        onTap: {
                            editingRecord = record
                        }
                    )
                }

                // Summary for this location
                HStack {
                    Text("Subtotal")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(formatQuantity(locationQuantity))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var groupedByTypeView: some View {
        ForEach(Array(item.inventoryByType.keys.sorted()), id: \.self) { type in
            let records = item.inventory.filter { $0.type == type }
            let typeQuantity = records.reduce(0.0) { $0 + $1.quantity }

            Section(header: Text(type.capitalized)) {
                ForEach(records, id: \.id) { record in
                    InventoryRecordRow(
                        record: record,
                        onDelete: {
                            deleteRecord(record)
                        },
                        showLocation: true,  // Show location when grouped by type
                        onTap: {
                            editingRecord = record
                        }
                    )
                }

                // Summary for this type
                HStack {
                    Text("Subtotal")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(formatQuantity(typeQuantity))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var totalQuantity: Double {
        item.inventory.reduce(0.0) { $0 + $1.quantity }
    }

    private func deleteRecord(_ record: InventoryModel) {
        Task {
            do {
                try await inventoryRepository.deleteInventory(id: record.id)
                print("✅ Deleted inventory record: \(record.id)")
                // Parent view will refresh on sheet dismiss via onDisappear callback
            } catch {
                print("Error deleting inventory record: \(error)")
            }
        }
    }

    private func formatQuantity(_ quantity: Double) -> String {
        if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", quantity)
        } else {
            return String(format: "%.1f", quantity)
        }
    }
}

/// Row showing a single inventory record with edit/delete options
struct InventoryRecordRow: View {
    let record: InventoryModel
    let onDelete: () -> Void
    var showType: Bool = false  // Show type when grouped by location
    var showLocation: Bool = false  // Show location when grouped by type
    var onTap: (() -> Void)? = nil  // Optional tap handler for editing

    var body: some View {
        let content = HStack {
            VStack(alignment: .leading, spacing: 4) {
                // Show type if requested (when grouped by location)
                if showType {
                    Text(record.type.capitalized)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                // Show subtype if present
                if let subtype = record.subtype {
                    Text(subtype.capitalized)
                        .font(showType ? .caption : .subheadline)
                        .fontWeight(showType ? .regular : .medium)
                        .foregroundColor(showType ? .secondary : .primary)
                }

                // Show dimensions if present
                if let dimensions = record.dimensions, !dimensions.isEmpty {
                    Text(GlassItemTypeSystem.formatDimensions(dimensions, for: record.type))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Show location if requested (when grouped by type)
                if showLocation, let location = record.location {
                    Text("📍 \(location)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(formatQuantity(record.quantity))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
        }

        if let onTap = onTap {
            Button(action: onTap) {
                content
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        } else {
            content
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                }
        }
    }

    private func formatQuantity(_ quantity: Double) -> String {
        if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", quantity)
        } else {
            return String(format: "%.1f", quantity)
        }
    }
}

/// Quick edit form for updating an inventory record
struct InventoryEditView: View {
    let record: InventoryModel
    let inventoryRepository: InventoryRepository

    @Environment(\.dismiss) private var dismiss
    @State private var quantity: String
    @State private var location: String
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""

    init(record: InventoryModel, inventoryRepository: InventoryRepository) {
        self.record = record
        self.inventoryRepository = inventoryRepository
        self._quantity = State(initialValue: String(format: "%.1f", record.quantity))
        self._location = State(initialValue: record.location ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    LabeledContent("Type", value: record.type.capitalized)
                    if let subtype = record.subtype {
                        LabeledContent("Subtype", value: subtype.capitalized)
                    }
                    if let dimensions = record.dimensions, !dimensions.isEmpty {
                        LabeledContent("Dimensions", value: GlassItemTypeSystem.formatDimensions(dimensions, for: record.type))
                    }
                }

                Section("Edit") {
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.decimalPad)
                    TextField("Location (optional)", text: $location)
                }
            }
            .navigationTitle("Edit Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(isSaving)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func saveChanges() {
        guard let quantityValue = Double(quantity), quantityValue > 0 else {
            errorMessage = "Please enter a valid quantity"
            showingError = true
            return
        }

        isSaving = true

        Task {
            do {
                let updatedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalLocation = updatedLocation.isEmpty ? nil : updatedLocation

                // Create updated inventory model preserving all fields except quantity and location
                let updatedRecord = InventoryModel(
                    id: record.id,
                    item_stable_id: record.item_stable_id,
                    type: record.type,
                    subtype: record.subtype,
                    subsubtype: record.subsubtype,
                    dimensions: record.dimensions,
                    quantity: quantityValue,
                    location: finalLocation,
                    date_added: record.date_added,
                    date_modified: Date()
                )

                try await inventoryRepository.updateInventory(updatedRecord)

                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
}

/// Quick add form for adding new inventory
struct QuickAddInventoryView: View {
    let itemStableId: String
    let itemName: String
    let inventoryRepository: InventoryRepository

    @Environment(\.dismiss) private var dismiss
    @State private var type = "rod"
    @State private var quantity = ""
    @State private var location = ""
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""

    private let types = ["rod", "tube", "sheet", "frit", "powder", "stringer", "twistie", "murrini", "cane"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    Text(itemName)
                        .foregroundColor(.secondary)
                }

                Section("New Inventory") {
                    Picker("Type", selection: $type) {
                        ForEach(types, id: \.self) { type in
                            Text(type.capitalized).tag(type)
                        }
                    }

                    TextField("Quantity", text: $quantity)
                        .keyboardType(.decimalPad)

                    TextField("Location (optional)", text: $location)
                }
            }
            .navigationTitle("Add Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addInventory()
                    }
                    .disabled(isSaving)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func addInventory() {
        guard let quantityValue = Double(quantity), quantityValue > 0 else {
            errorMessage = "Please enter a valid quantity"
            showingError = true
            return
        }

        isSaving = true

        Task {
            do {
                let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalLocation = trimmedLocation.isEmpty ? nil : trimmedLocation

                // Create new inventory model
                let newInventory = InventoryModel(
                    item_stable_id: itemStableId,
                    type: type,
                    quantity: quantityValue,
                    location: finalLocation
                )

                _ = try await inventoryRepository.createInventory(newInventory)

                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to add inventory: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Inventory Detail - With Data") {
    NavigationStack {
        let sampleGlassItem = GlassItemModel(
            stable_id: "bullseye-0001-0",
            natural_key: "bullseye-0001-0",
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

        InventoryDetailView(
            item: sampleCompleteItem,
            userNotesRepository: MockUserNotesRepository(),
            userTagsRepository: MockUserTagsRepository()
        )
    }
}

#Preview("Inventory Detail - Empty") {
    NavigationStack {
        let sampleGlassItem = GlassItemModel(
            stable_id: "spectrum-clear-0",
            natural_key: "spectrum-clear-0",
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

        InventoryDetailView(
            item: sampleCompleteItem,
            userNotesRepository: MockUserNotesRepository(),
            userTagsRepository: MockUserTagsRepository()
        )
    }
}

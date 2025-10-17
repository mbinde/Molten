//
//  InventoryDetailView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//  Updated for GlassItem Architecture on 10/14/25.
//  Merged comprehensive view with safe URL handling on 10/16/25.
//

import SwiftUI

/// Comprehensive inventory detail view showing complete item information
/// including inventory breakdown by type, location distribution, and shopping list integration
struct InventoryDetailView: View {
    let item: CompleteInventoryItemModel
    let inventoryTrackingService: InventoryTrackingService?
    let userNotesRepository: UserNotesRepository

    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false

    // State for managing UI interactions
    @State private var selectedInventoryType: String?
    @State private var showingLocationDetail = false
    @State private var showingShoppingListOptions = false
    @State private var showingUserNotesEditor = false
    @State private var showingAddInventory = false
    @State private var expandedSections: Set<String> = ["glass-item", "inventory"]
    @State private var isManufacturerNotesExpanded: Bool

    // User notes state
    @State private var userNotes: UserNotesModel?
    @State private var isLoadingNotes = false
    @State private var isUserNotesExpanded = false

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
        userNotesRepository: UserNotesRepository = RepositoryFactory.createUserNotesRepository()
    ) {
        self.item = item
        self.inventoryTrackingService = inventoryTrackingService
        self.userNotesRepository = userNotesRepository
        // Initialize from user settings
        self._isManufacturerNotesExpanded = State(initialValue: UserSettings.shared.expandManufacturerDescriptionsByDefault)
        self._isUserNotesExpanded = State(initialValue: UserSettings.shared.expandUserNotesByDefault)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    // Header with glass item image and basic info
                    headerSection
                        .id("header")

                    // Glass Item Details Section
                    glassItemDetailsSection
                        .id("glass-item-section")

                    // Inventory Breakdown Section
                    inventoryBreakdownSection

                    // Location Distribution Section
                    if !item.locations.isEmpty {
                        locationDistributionSection
                    }

                    // Tags Section
                    if !item.tags.isEmpty {
                        tagsSection
                    }

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
        .navigationTitle(item.glassItem.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(isEditing ? "Cancel" : "Done") {
                    if isEditing {
                        isEditing = false
                    } else {
                        dismiss()
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                if !isEditing {
                    Menu {
                        Button("Add Inventory", systemImage: "plus.circle.fill") {
                            showingAddInventory = true
                        }
                        Button("Add to Shopping List", systemImage: "cart.badge.plus") {
                            showingShoppingListOptions = true
                        }
                        Button("Share", systemImage: "square.and.arrow.up") {
                            // TODO: Share item details
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingShoppingListOptions) {
            ShoppingListOptionsView(item: item)
        }
        .sheet(isPresented: $showingLocationDetail) {
            if let selectedType = selectedInventoryType {
                LocationDetailView(
                    item: item,
                    inventoryType: selectedType
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
        .sheet(isPresented: $showingAddInventory) {
            AddInventoryItemView(
                prefilledNaturalKey: item.glassItem.natural_key,
                inventoryTrackingService: inventoryTrackingService
            )
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .onAppear {
            loadInitialData()
            loadUserNotes()
        }
    }

    // MARK: - Data Loading

    private func loadInitialData() {
        if let firstInventory = item.inventory.first {
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
                userNotes = try await userNotesRepository.fetchNotes(forItem: item.glassItem.natural_key)
            } catch {
                // No notes is fine, just leave userNotes as nil
                print("No user notes found or error loading: \(error)")
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        GlassItemCard(item: item.glassItem, variant: .large)
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
                if let notes = item.glassItem.mfr_notes, !notes.isEmpty {
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
                        Text("Add a note")
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
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
            if item.inventory.isEmpty {
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
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                LazyVStack(spacing: 8) {
                    // Group by type using inventoryByType computed property
                    ForEach(Array(item.inventoryByType.keys.sorted()), id: \.self) { type in
                        let quantity = item.inventoryByType[type] ?? 0
                        let typeInventory = item.inventory.filter { $0.type == type }

                        InventoryDetailTypeRow(
                            type: type,
                            quantity: quantity,
                            recordCount: typeInventory.count,
                            onTap: {
                                selectedInventoryType = type
                                showingLocationDetail = true
                            }
                        )
                    }
                }
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
                ForEach(item.locations, id: \.id) { location in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(location.location)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Qty: \(formatQuantity(location.quantity))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // Progress bar showing relative quantity
                        let maxQuantity = item.locations.map { $0.quantity }.max() ?? 1
                        let percentage = location.quantity / maxQuantity

                        HStack(spacing: 8) {
                            ProgressView(value: percentage)
                                .frame(width: 60)
                            Text("\(Int(percentage * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: - Tags Section

    private var tagsSection: some View {
        ExpandableSection(
            title: "Tags",
            systemImage: "tag",
            isExpanded: expandedSections.contains("tags"),
            onToggle: { toggleSection("tags") }
        ) {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 80), spacing: 8)
            ], spacing: 8) {
                ForEach(item.tags.sorted(), id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
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

            // Secondary actions
            HStack(spacing: 12) {
                Button("Share", systemImage: "square.and.arrow.up") {
                    // TODO: Share item
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top)
    }

    // MARK: - Helper Methods

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
        .background(Color(.systemGray6))
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
        .background(Color(.systemGray6))
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
    let recordCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.capitalized)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text("\(recordCount) record\(recordCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func formatQuantity(_ quantity: Double) -> String {
        if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", quantity)
        } else {
            return String(format: "%.1f", quantity)
        }
    }
}

/// Placeholder views for modal presentations
struct ShoppingListOptionsView: View {
    let item: CompleteInventoryItemModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Shopping List Options")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Add \(item.glassItem.name) to your shopping list")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                // TODO: Implement shopping list functionality

                Button("Add to Shopping List") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .navigationTitle("Shopping List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct LocationDetailView: View {
    let item: CompleteInventoryItemModel
    let inventoryType: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                Text("Location Detail")
                Text("Showing \(inventoryType) locations for \(item.glassItem.name)")

                // TODO: Implement location detail functionality
            }
            .padding()
            .navigationTitle("\(inventoryType.capitalized) Locations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Inventory Detail - With Data") {
    NavigationStack {
        let sampleGlassItem = GlassItemModel(
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
            InventoryModel(item_natural_key: "bullseye-0001-0", type: "rod", quantity: 12.0),
            InventoryModel(item_natural_key: "bullseye-0001-0", type: "sheet", quantity: 3.0),
            InventoryModel(item_natural_key: "bullseye-0001-0", type: "frit", quantity: 8.5)
        ]

        let sampleLocations = [
            LocationModel(inventory_id: UUID(), location: "Studio Shelf A", quantity: 8.0),
            LocationModel(inventory_id: UUID(), location: "Storage Room", quantity: 7.5)
        ]

        let sampleCompleteItem = CompleteInventoryItemModel(
            glassItem: sampleGlassItem,
            inventory: sampleInventory,
            tags: ["red", "opal", "bullseye", "warm"],
            locations: sampleLocations
        )

        InventoryDetailView(
            item: sampleCompleteItem,
            userNotesRepository: MockUserNotesRepository()
        )
    }
}

#Preview("Inventory Detail - Empty") {
    NavigationStack {
        let sampleGlassItem = GlassItemModel(
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
            locations: []
        )

        InventoryDetailView(
            item: sampleCompleteItem,
            userNotesRepository: MockUserNotesRepository()
        )
    }
}

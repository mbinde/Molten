//
//  DeepLinkedItemView.swift
//  Molten
//
//  View for displaying a glass item accessed via deep link (QR code scan)
//

import SwiftUI

/// Quick actions available when scanning QR codes
enum QRQuickAction: String, CaseIterable, Codable {
    case removeFromInventory = "Remove from Inventory"
    case addToInventory = "Add to Inventory"
    case changeLocation = "Change Location"
    case viewDetails = "View Details"

    var icon: String {
        switch self {
        case .removeFromInventory: return "minus.circle.fill"
        case .addToInventory: return "plus.circle.fill"
        case .changeLocation: return "location.fill"
        case .viewDetails: return "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .removeFromInventory: return .red
        case .addToInventory: return .green
        case .changeLocation: return .blue
        case .viewDetails: return .gray
        }
    }
}

/// View that loads and displays a glass item from a deep link stable_id
struct DeepLinkedItemView: View {
    let stableId: String
    @Environment(\.dismiss) private var dismiss

    @State private var item: CompleteInventoryItemModel?
    @State private var isLoading = true
    @State private var errorMessage: String?

    // Quick action state
    @State private var selectedAction: QRQuickAction = .removeFromInventory
    @State private var showingActionConfirmation = false
    @State private var showingActionMenu = false
    @State private var actionInProgress = false
    @State private var actionSuccessMessage: String?

    // CRITICAL: Cache service instances in @State to prevent recreation on every body evaluation
    @State private var catalogService: CatalogService?
    @State private var inventoryService: InventoryTrackingService?

    // UserDefaults key for persisting selected action
    private let selectedActionKey = "qrScanQuickAction"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Quick action toolbar (only show when item is loaded)
                if !isLoading && item != nil {
                    quickActionToolbar
                        .padding()
                        .background(Color(.systemGroupedBackground))
                }

                // Main content
                Group {
                    if isLoading {
                        ProgressView("Loading item...")
                    } else if let error = errorMessage {
                        errorView(error)
                    } else if let item = item, let inventoryService = inventoryService {
                        // Show success message overlay if action succeeded
                        ZStack {
                            InventoryDetailView(
                                item: item,
                                inventoryTrackingService: inventoryService,
                                catalogService: catalogService
                            )

                            if let successMessage = actionSuccessMessage {
                                VStack {
                                    Spacer()
                                    Text(successMessage)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.green)
                                        .cornerRadius(10)
                                        .padding()
                                    Spacer().frame(height: 100)
                                }
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                    } else {
                        errorView("Item not found")
                    }
                }
            }
            .navigationTitle("Scanned Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .task {
                // Load persisted action preference
                if let savedAction = UserDefaults.standard.string(forKey: selectedActionKey),
                   let action = QRQuickAction(rawValue: savedAction) {
                    selectedAction = action
                }

                // Initialize services first (guaranteed to run on MainActor)
                print("🔗 DeepLinkedItemView: .task started for stable_id: \(stableId)")
                if catalogService == nil {
                    print("🔗 DeepLinkedItemView: Creating CatalogService...")
                    catalogService = RepositoryFactory.createCatalogService()
                    print("✅ DeepLinkedItemView: CatalogService created")
                }
                if inventoryService == nil {
                    print("🔗 DeepLinkedItemView: Creating InventoryTrackingService...")
                    inventoryService = RepositoryFactory.createInventoryTrackingService()
                    print("✅ DeepLinkedItemView: InventoryTrackingService created")
                }

                // Then load the item
                await loadItem()
            }
            .confirmationDialog("Confirm Action", isPresented: $showingActionConfirmation) {
                Button(selectedAction.rawValue, role: selectedAction == .removeFromInventory ? .destructive : nil) {
                    Task {
                        await performQuickAction()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                if let item = item {
                    Text("Are you sure you want to \(selectedAction.rawValue.lowercased()) for \(item.glassItem.name)?")
                }
            }
        }
    }

    // MARK: - Quick Action Toolbar

    private var quickActionToolbar: some View {
        HStack(spacing: 12) {
            // Change Action button
            Button {
                showingActionMenu = true
            } label: {
                Label("Change Action", systemImage: "chevron.down.circle.fill")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .confirmationDialog("Select Quick Action", isPresented: $showingActionMenu) {
                ForEach(QRQuickAction.allCases, id: \.self) { action in
                    Button {
                        selectedAction = action
                        // Save preference
                        UserDefaults.standard.set(action.rawValue, forKey: selectedActionKey)
                    } label: {
                        Label(action.rawValue, systemImage: action.icon)
                    }
                }
            }

            // Selected action button
            Button {
                if selectedAction == .viewDetails {
                    // View details doesn't need confirmation
                } else {
                    showingActionConfirmation = true
                }
            } label: {
                Label(selectedAction.rawValue, systemImage: selectedAction.icon)
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .tint(selectedAction.color)
            .disabled(actionInProgress || selectedAction == .viewDetails)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("Stable ID: \(stableId)")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("Close") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    @MainActor
    private func loadItem() async {
        print("🔗 DeepLinkedItemView: loadItem() called for \(stableId)")

        guard let catalogService = catalogService else {
            print("❌ DeepLinkedItemView: catalogService is nil!")
            errorMessage = "Service not initialized"
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // Look up the glass item by stable_id directly
            print("🔗 DeepLinkedItemView: Looking up item...")
            if let foundItem = try await catalogService.getGlassItemByNaturalKey(stableId) {
                print("✅ DeepLinkedItemView: Found item: \(foundItem.glassItem.name)")
                item = foundItem
            } else {
                print("❌ DeepLinkedItemView: Item not found")
                errorMessage = "Item with ID '\(stableId)' not found in catalog"
            }
        } catch {
            print("❌ DeepLinkedItemView: Error: \(error)")
            errorMessage = "Error loading item: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Quick Actions

    @MainActor
    private func performQuickAction() async {
        guard let item = item,
              let inventoryService = inventoryService else {
            return
        }

        actionInProgress = true
        defer { actionInProgress = false }

        do {
            switch selectedAction {
            case .removeFromInventory:
                try await removeOneFromInventory(item: item, service: inventoryService)
                showSuccessMessage("Removed 1 from inventory")

            case .addToInventory:
                try await addOneToInventory(item: item, service: inventoryService)
                showSuccessMessage("Added 1 to inventory")

            case .changeLocation:
                // TODO: Implement change location
                showSuccessMessage("Change location - Coming soon!")

            case .viewDetails:
                // Already showing details
                break
            }

            // Reload item to reflect changes
            await loadItem()
        } catch {
            print("❌ DeepLinkedItemView: Quick action failed: \(error)")
            errorMessage = "Action failed: \(error.localizedDescription)"
        }
    }

    private func removeOneFromInventory(item: CompleteInventoryItemModel, service: InventoryTrackingService) async throws {
        // Find the first inventory record with quantity > 0
        guard let inventory = item.inventory.first(where: { $0.quantity > 0 }) else {
            throw NSError(domain: "DeepLinkedItemView", code: 1, userInfo: [NSLocalizedDescriptionKey: "No inventory to remove"])
        }

        // Decrement by 1
        let newQuantity = max(0, inventory.quantity - 1)
        let updatedInventory = InventoryModel(
            id: inventory.id,
            item_stable_id: inventory.item_stable_id,
            type: inventory.type,
            subtype: inventory.subtype,
            subsubtype: inventory.subsubtype,
            dimensions: inventory.dimensions,
            quantity: newQuantity,
            date_added: inventory.date_added,
            date_modified: Date()
        )

        _ = try await service.inventoryRepository.updateInventory(updatedInventory)
    }

    private func addOneToInventory(item: CompleteInventoryItemModel, service: InventoryTrackingService) async throws {
        // Find the first inventory record or create a new one
        if let inventory = item.inventory.first {
            // Increment existing
            let newQuantity = inventory.quantity + 1
            let updatedInventory = InventoryModel(
                id: inventory.id,
                item_stable_id: inventory.item_stable_id,
                type: inventory.type,
                subtype: inventory.subtype,
                subsubtype: inventory.subsubtype,
                dimensions: inventory.dimensions,
                quantity: newQuantity,
                date_added: inventory.date_added,
                date_modified: Date()
            )

            _ = try await service.inventoryRepository.updateInventory(updatedInventory)
        } else {
            // Create new inventory record with quantity 1
            let newInventory = InventoryModel(
                id: UUID(),
                item_stable_id: item.glassItem.stable_id,
                type: "rod",  // Default type
                subtype: nil,
                subsubtype: nil,
                dimensions: nil,
                quantity: 1,
                date_added: Date(),
                date_modified: Date()
            )

            _ = try await service.inventoryRepository.createInventory(newInventory)
        }
    }

    private func showSuccessMessage(_ message: String) {
        withAnimation {
            actionSuccessMessage = message
        }

        // Hide after 2 seconds
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation {
                actionSuccessMessage = nil
            }
        }
    }
}

#Preview {
    DeepLinkedItemView(stableId: "2wjEBu")
}

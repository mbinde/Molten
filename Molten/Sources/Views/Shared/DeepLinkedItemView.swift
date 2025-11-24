//
//  DeepLinkedItemView.swift
//  Molten
//
//  View for displaying a glass item accessed via deep link (QR code scan)
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

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
    @State private var actionSuccessMessage = ""
    @State private var showActionSuccessToast = false

    // Services from AppDependencies (NOT @State - services are stable)
    private let deps: AppDependencies
    private let catalogService: CatalogService
    private let inventoryService: InventoryTrackingService

    // UserDefaults key for persisting selected action
    private let selectedActionKey = "qrScanQuickAction"

    init(stableId: String, deps: AppDependencies = AppDependencies()) {
        self.stableId = stableId
        self.deps = deps
        self.catalogService = deps.catalogService
        self.inventoryService = deps.inventoryTrackingService
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Quick action toolbar (only show when item is loaded)
                if !isLoading && item != nil {
                    quickActionToolbar
                        .padding()
                        #if os(macOS)
                        .background(Color(NSColor.controlBackgroundColor))
                        #else
                        .background(Color(.systemGray6))
                        #endif
                }

                // Main content
                Group {
                    if isLoading {
                        LoadingStateView(message: "Loading item...")
                    } else if let error = errorMessage {
                        errorView(error)
                    } else if let item = item {
                        InventoryDetailView(
                            item: item,
                            deps: deps
                        )
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
                    .accessibilityIdentifier("deep_linked_item_close")
                }
            }
            .task {
                // Load persisted action preference
                if let savedAction = UserDefaults.standard.string(forKey: selectedActionKey),
                   let action = QRQuickAction(rawValue: savedAction) {
                    selectedAction = action
                }

                // Services already initialized in init() - just load the item
                print("🔗 DeepLinkedItemView: .task started for stable_id: \(stableId)")
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
            .toast(
                message: actionSuccessMessage,
                style: .success,
                placement: .bottom,
                isShowing: $showActionSuccessToast
            )
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
                .font(.largeTitle)
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
        guard let item = item else {
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

        _ = try await service.updateInventory(updatedInventory)
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

            _ = try await service.updateInventory(updatedInventory)
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

            _ = try await service.createInventory(newInventory)
        }
    }

    private func showSuccessMessage(_ message: String) {
        actionSuccessMessage = message
        withAnimation {
            showActionSuccessToast = true
        }
    }
}

#Preview {
    DeepLinkedItemView(stableId: "2wjEBu")
}

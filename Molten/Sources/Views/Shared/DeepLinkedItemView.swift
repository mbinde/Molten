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
    case removeFromInventory = "Remove"
    case addToInventory = "Add"

    var icon: String {
        switch self {
        case .removeFromInventory: return "minus"
        case .addToInventory: return "plus"
        }
    }
}

/// View that loads and displays a glass item from a deep link stable_id
struct DeepLinkedItemView: View {
    let stableId: String
    let showQuickActions: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var item: CompleteInventoryItemModel?
    @State private var isLoading = true
    @State private var errorMessage: String?

    // Quick action state
    @State private var actionInProgress = false
    @State private var toastMessage = ""
    @State private var toastStyle: ToastStyle = .success
    @State private var showToast = false

    // Services from AppDependencies (NOT @State - services are stable)
    private let deps: AppDependencies
    private let catalogService: CatalogService
    private let inventoryService: InventoryTrackingService

    init(stableId: String, showQuickActions: Bool = true, deps: AppDependencies = AppDependencies()) {
        self.stableId = stableId
        self.showQuickActions = showQuickActions
        self.deps = deps
        self.catalogService = deps.catalogService
        self.inventoryService = deps.inventoryTrackingService
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Quick action toolbar (only show when item is loaded and quick actions enabled)
                if showQuickActions && !isLoading && item != nil {
                    quickActionToolbar
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
            .navigationTitle(showQuickActions ? "Scanned Item" : "Item Details")
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
                print("🔗 DeepLinkedItemView: .task started for stable_id: \(stableId)")
                await loadItem()
            }
            .toast(
                message: toastMessage,
                style: toastStyle,
                placement: .bottom,
                isShowing: $showToast
            )
        }
    }

    // MARK: - Quick Action Toolbar

    /// Current inventory quantity for display
    private var currentQuantity: Int {
        guard let item = item else { return 0 }
        return Int(item.inventory.reduce(0) { $0 + $1.quantity })
    }

    private var quickActionToolbar: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            // Remove button
            Button {
                Task { await performAction(.removeFromInventory) }
            } label: {
                Label("Remove", systemImage: "minus")
                    .font(.headline)
                    .frame(minWidth: 80)
            }
            .buttonStyle(.bordered)
            .tint(DesignSystem.Colors.accentDanger)
            .disabled(actionInProgress || currentQuantity == 0)

            // Quantity display
            VStack(spacing: 2) {
                Text("\(currentQuantity)")
                    .font(DesignSystem.Typography.prominentNumber)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Text("in stock")
                    .font(DesignSystem.Typography.listItemCaption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .frame(minWidth: 60)

            // Add button
            Button {
                Task { await performAction(.addToInventory) }
            } label: {
                Label("Add", systemImage: "plus")
                    .font(.headline)
                    .frame(minWidth: 80)
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignSystem.Colors.accentSuccess)
            .disabled(actionInProgress)
        }
        .padding()
        .background(DesignSystem.Colors.backgroundSecondary)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(DesignSystem.Colors.accentWarning)

            Text(message)
                .font(DesignSystem.Typography.sectionHeader)
                .multilineTextAlignment(.center)

            Text("Stable ID: \(stableId)")
                .font(DesignSystem.Typography.listItemCaption)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Button("Close") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignSystem.Colors.tintPrimary)
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
    private func performAction(_ action: QRQuickAction) async {
        guard let item = item else { return }

        actionInProgress = true
        defer { actionInProgress = false }

        do {
            switch action {
            case .removeFromInventory:
                try await removeOneFromInventory(item: item)
                showToast(message: "Removed 1 from inventory", style: .success)

            case .addToInventory:
                try await addOneToInventory(item: item)
                showToast(message: "Added 1 to inventory", style: .success)
            }

            // Reload item to reflect changes
            await loadItem()
        } catch {
            print("❌ DeepLinkedItemView: Action failed: \(error)")
            showToast(message: error.localizedDescription, style: .error)
        }
    }

    private func removeOneFromInventory(item: CompleteInventoryItemModel) async throws {
        // Find the first inventory record with stock
        guard let inventory = item.inventory.first(where: { $0.hasStock }) else {
            throw NSError(domain: "DeepLinkedItemView", code: 1, userInfo: [NSLocalizedDescriptionKey: "No inventory to remove"])
        }

        // Decrement by 1
        let newQuantity: Double
        let newContainerCount: Double?
        if inventory.quantity > 0 {
            newQuantity = max(0, inventory.quantity - 1)
            newContainerCount = inventory.containerCount
        } else {
            // Jar-only tracking - decrement containers
            newQuantity = 0
            newContainerCount = max(0, (inventory.containerCount ?? 0) - 1)
        }

        let updatedInventory = InventoryModel(
            id: inventory.id,
            item_stable_id: inventory.item_stable_id,
            type: inventory.type,
            subtype: inventory.subtype,
            subsubtype: inventory.subsubtype,
            dimensions: inventory.dimensions,
            quantity: newQuantity,
            containerCount: newContainerCount,
            date_added: inventory.date_added,
            date_modified: Date()
        )

        _ = try await inventoryService.updateInventory(updatedInventory)
    }

    private func addOneToInventory(item: CompleteInventoryItemModel) async throws {
        if let inventory = item.inventory.first {
            // Increment existing
            let updatedInventory = InventoryModel(
                id: inventory.id,
                item_stable_id: inventory.item_stable_id,
                type: inventory.type,
                subtype: inventory.subtype,
                subsubtype: inventory.subsubtype,
                dimensions: inventory.dimensions,
                quantity: inventory.quantity + 1,
                date_added: inventory.date_added,
                date_modified: Date()
            )
            _ = try await inventoryService.updateInventory(updatedInventory)
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
            _ = try await inventoryService.createInventory(newInventory)
        }
    }

    private func showToast(message: String, style: ToastStyle) {
        toastMessage = message
        toastStyle = style
        withAnimation {
            showToast = true
        }
    }
}

#Preview {
    DeepLinkedItemView(stableId: "2wjEBu")
}

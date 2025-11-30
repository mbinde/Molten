//
//  DeepLinkedItemView.swift
//  Molten
//
//  View for displaying a glass item accessed via deep link (QR code scan)
//  Supports two modes: inventory management and item details
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

/// View that loads and displays a glass item from a deep link stable_id
/// Uses user settings to determine whether to show inventory management or item details first
struct DeepLinkedItemView: View {
    let stableId: String
    let showQuickActions: Bool
    let inventoryType: String?       // Type from QR code (e.g., "rod", "frit")
    let inventorySubtype: String?    // Subtype from QR code (e.g., "coarse", "fine")
    let inventorySubsubtype: String? // Subsubtype from QR code (rarely used)
    @Environment(\.dismiss) private var dismiss

    @State private var item: CompleteInventoryItemModel?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingInventoryView: Bool

    // Services from AppDependencies (NOT @State - services are stable)
    private let deps: AppDependencies
    private let catalogService: CatalogService

    init(
        stableId: String,
        showQuickActions: Bool = true,
        inventoryType: String? = nil,
        inventorySubtype: String? = nil,
        inventorySubsubtype: String? = nil,
        deps: AppDependencies = .shared
    ) {
        self.stableId = stableId
        self.showQuickActions = showQuickActions
        self.inventoryType = inventoryType
        self.inventorySubtype = inventorySubtype
        self.inventorySubsubtype = inventorySubsubtype
        self.deps = deps
        self.catalogService = deps.catalogService

        // Determine initial view based on settings
        let settings = UserSettings.shared
        let shouldShowInventory: Bool
        switch settings.qrScanBehavior {
        case .inventoryFirst:
            shouldShowInventory = true
        case .detailsFirst:
            shouldShowInventory = false
        case .rememberLast:
            shouldShowInventory = settings.qrScanLastShowedInventory
        }
        // Only use inventory view if quick actions are enabled
        self._showingInventoryView = State(initialValue: showQuickActions && shouldShowInventory)
    }

    var body: some View {
        let _ = print("🔗 DeepLinkedItemView: body evaluated, isLoading=\(isLoading), item=\(item != nil), showingInventory=\(showingInventoryView)")
        Group {
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if let item = item {
                if showingInventoryView {
                    QRScanInventoryView(
                        item: item,
                        inventoryType: inventoryType,
                        inventorySubtype: inventorySubtype,
                        inventorySubsubtype: inventorySubsubtype,
                        onViewDetails: {
                            showingInventoryView = false
                            UserSettings.shared.qrScanLastShowedInventory = false
                        },
                        deps: deps
                    )
                } else {
                    detailsView(item: item)
                }
            } else {
                errorView("Item not found")
            }
        }
        .task {
            print("🔗 DeepLinkedItemView: .task started for stable_id: \(stableId)")
            await loadItem()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        NavigationStack {
            LoadingStateView(message: "Loading item...")
                .navigationTitle("Loading...")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
        }
    }

    // MARK: - Details View

    private func detailsView(item: CompleteInventoryItemModel) -> some View {
        NavigationStack {
            // Main content - pass callback if quick actions enabled
            InventoryDetailView(
                item: item,
                deps: deps,
                onManageInventory: showQuickActions ? {
                    showingInventoryView = true
                    UserSettings.shared.qrScanLastShowedInventory = true
                } : nil
            )
            .navigationTitle("Item Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .accessibilityIdentifier("deep_linked_item_close")
                }
            }
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.xl) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(DesignSystem.Colors.accentWarning)

                Text(message)
                    .font(DesignSystem.Typography.sectionTitle)
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
            .navigationTitle("Error")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Data Loading

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
}

#Preview {
    DeepLinkedItemView(stableId: "2wjEBu")
}

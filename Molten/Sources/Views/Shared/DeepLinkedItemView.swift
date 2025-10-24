//
//  DeepLinkedItemView.swift
//  Molten
//
//  View for displaying a glass item accessed via deep link (QR code scan)
//

import SwiftUI

/// View that loads and displays a glass item from a deep link stable_id
struct DeepLinkedItemView: View {
    let stableId: String
    @Environment(\.dismiss) private var dismiss

    @State private var item: CompleteInventoryItemModel?
    @State private var isLoading = true
    @State private var errorMessage: String?

    // CRITICAL: Cache service instances in @State to prevent recreation on every body evaluation
    @State private var catalogService: CatalogService?
    @State private var inventoryService: InventoryTrackingService?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading item...")
                } else if let error = errorMessage {
                    errorView(error)
                } else if let item = item, let inventoryService = inventoryService {
                    InventoryDetailView(
                        item: item,
                        inventoryTrackingService: inventoryService,
                        catalogService: catalogService
                    )
                } else {
                    errorView("Item not found")
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
}

#Preview {
    DeepLinkedItemView(stableId: "2wjEBu")
}

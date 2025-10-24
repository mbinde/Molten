//
//  DeepLinkedItemView.swift
//  Molten
//
//  View for displaying a glass item accessed via deep link (QR code scan)
//

import SwiftUI

/// View that loads and displays a glass item from a deep link natural key
struct DeepLinkedItemView: View {
    let naturalKey: String
    @Environment(\.dismiss) private var dismiss

    @State private var item: CompleteInventoryItemModel?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let catalogService = RepositoryFactory.createCatalogService()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading item...")
                } else if let error = errorMessage {
                    errorView(error)
                } else if let item = item {
                    InventoryDetailView(
                        item: item,
                        inventoryTrackingService: RepositoryFactory.createInventoryTrackingService()
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

            Text("Natural Key: \(naturalKey)")
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
        isLoading = true
        errorMessage = nil

        do {
            // Search for the glass item by natural key
            let request = GlassItemSearchRequest(
                searchText: naturalKey,
                tags: [],
                manufacturers: [],
                coeValues: [],
                hasInventory: nil,
                sortBy: .name
            )

            let result = try await catalogService.searchGlassItems(request: request)

            // Find exact match by natural key
            if let foundItem = result.items.first(where: { $0.glassItem.natural_key == naturalKey }) {
                item = foundItem
            } else {
                errorMessage = "Item with code '\(naturalKey)' not found in catalog"
            }
        } catch {
            errorMessage = "Error loading item: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

#Preview {
    DeepLinkedItemView(naturalKey: "bullseye-clear-001")
}

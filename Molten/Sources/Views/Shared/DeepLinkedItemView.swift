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
        isLoading = true
        errorMessage = nil

        do {
            // Look up the glass item by stable_id directly
            if let foundItem = try await catalogService.getGlassItemByNaturalKey(stableId) {
                item = foundItem
            } else {
                errorMessage = "Item with ID '\(stableId)' not found in catalog"
            }
        } catch {
            errorMessage = "Error loading item: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

#Preview {
    DeepLinkedItemView(stableId: "2wjEBu")
}

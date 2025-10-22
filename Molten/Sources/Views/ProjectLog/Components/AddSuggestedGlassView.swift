//
//  AddSuggestedGlassView.swift
//  Molten
//
//  View for adding suggested glass to a project plan
//

import SwiftUI

struct AddSuggestedGlassView: View {
    @Environment(\.dismiss) private var dismiss

    let plan: ProjectModel
    let repository: ProjectRepository

    @State private var selectedGlassItem: GlassItemModel?
    @State private var searchText = ""
    @State private var quantity = ""
    @State private var unit = "rods"
    @State private var notes = ""
    @State private var glassItems: [GlassItemModel] = []
    @State private var isLoading = false

    private let catalogService: CatalogService

    init(plan: ProjectModel, repository: ProjectRepository) {
        self.plan = plan
        self.repository = repository
        self.catalogService = RepositoryFactory.createCatalogService()
    }

    var body: some View {
        Form {
            // Glass Item Selection
            GlassItemSearchSelector(
                selectedGlassItem: $selectedGlassItem,
                searchText: $searchText,
                prefilledNaturalKey: nil,
                glassItems: glassItems,
                onSelect: { item in
                    selectedGlassItem = item
                    searchText = ""
                },
                onClear: {
                    selectedGlassItem = nil
                    searchText = ""
                }
            )

            // Quantity and Unit
            Section("Quantity") {
                HStack {
                    TextField("Quantity", text: $quantity)
                        #if canImport(UIKit)
                        .keyboardType(.decimalPad)
                        #endif
                        .textFieldStyle(.roundedBorder)

                    Picker("Unit", selection: $unit) {
                        Text("Rods").tag("rods")
                        Text("Grams").tag("grams")
                        Text("Oz").tag("oz")
                        Text("Pounds").tag("lbs")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                }
            }

            // Optional Notes
            Section("Notes (Optional)") {
                TextField("e.g., for the base layer", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
        .navigationTitle("Add Suggested Glass")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    Task {
                        await saveGlassItem()
                    }
                }
                .disabled(selectedGlassItem == nil || quantity.isEmpty)
            }
        }
        .task {
            await loadGlassItems()
        }
    }

    private func loadGlassItems() async {
        print("⏱️ [SEARCH] loadGlassItems() started, cache isLoaded=\(CatalogSearchCache.shared.isLoaded)")
        isLoading = true

        // CRITICAL: Trust the cache is loaded during FirstRunDataLoadingView
        // The cache is ALWAYS loaded during startup (see FirstRunDataLoadingView line 189)
        // If it's not loaded yet, we wait for it to finish loading (don't reload!)
        if CatalogSearchCache.shared.isLoaded {
            // Cache ready - instant access!
            glassItems = CatalogSearchCache.shared.items
            print("✅ [SEARCH] Using pre-loaded cache with \(glassItems.count) items")
        } else {
            // Cache still loading from FirstRunDataLoadingView, wait for it
            print("⏳ [SEARCH] Cache not ready, waiting for FirstRunDataLoadingView to finish...")
            await CatalogSearchCache.shared.loadIfNeeded(catalogService: catalogService)
            glassItems = CatalogSearchCache.shared.items
            print("✅ [SEARCH] Cache now ready with \(glassItems.count) items")
        }

        isLoading = false
    }

    private func saveGlassItem() async {
        guard let glassItem = selectedGlassItem,
              let quantityValue = Decimal(string: quantity) else {
            return
        }

        // Create new ProjectGlassItem
        let newItem = ProjectGlassItem(
            naturalKey: glassItem.natural_key,
            quantity: quantityValue,
            unit: unit,
            notes: notes.isEmpty ? nil : notes
        )

        // Create updated plan with new glass item
        var updatedGlassItems = plan.glassItems
        updatedGlassItems.append(newItem)

        let updatedPlan = ProjectModel(
            id: plan.id,
            title: plan.title,
            type: plan.type,
            dateCreated: plan.dateCreated,
            dateModified: Date(), // Update modification date
            isArchived: plan.isArchived,
            tags: plan.tags,
            coe: plan.coe,
            summary: plan.summary,
            steps: plan.steps,
            estimatedTime: plan.estimatedTime,
            difficultyLevel: plan.difficultyLevel,
            proposedPriceRange: plan.proposedPriceRange,
            images: plan.images,
            heroImageId: plan.heroImageId,
            glassItems: updatedGlassItems,
            referenceUrls: plan.referenceUrls,
            timesUsed: plan.timesUsed,
            lastUsedDate: plan.lastUsedDate
        )

        do {
            try await repository.updateProject(updatedPlan)
            await MainActor.run {
                dismiss()
            }
        } catch {
            // TODO: Show error alert
            print("Error saving glass item: \(error)")
        }
    }
}

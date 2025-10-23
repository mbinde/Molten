//
//  AddGlassToStepView.swift
//  Molten
//
//  View for adding glass items to a project plan step
//  Uses GlassItemSearchSelector for consistent search UX with image cards
//  Quick select from glasses already in plan + full catalog search + freeform entries
//

import SwiftUI

struct AddGlassToStepView: View {
    @Environment(\.dismiss) private var dismiss

    let plan: ProjectModel
    let onSave: (ProjectGlassItem) -> Void

    // Search and selection
    @State private var searchText = ""
    @State private var selectedGlassItem: GlassItemModel?
    @State private var glassItems: [GlassItemModel] = []
    @State private var isLoading = false

    // Common fields
    @State private var quantity = ""
    @State private var unit = "rods"
    @State private var notes = ""

    private let catalogService: CatalogService

    init(plan: ProjectModel, onSave: @escaping (ProjectGlassItem) -> Void) {
        self.plan = plan
        self.onSave = onSave
        self.catalogService = RepositoryFactory.createCatalogService()
    }

    /// Get all unique glass items used in any step of this plan
    private var existingGlassInPlan: [ProjectGlassItem] {
        let allGlass = plan.steps.flatMap { $0.glassItemsNeeded ?? [] }

        // Group by naturalKey or freeformDescription to get unique items
        var seen = Set<String>()
        var unique: [ProjectGlassItem] = []

        for glass in allGlass {
            let key = glass.naturalKey ?? glass.freeformDescription ?? ""
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(glass)
            }
        }

        return unique
    }

    /// Filter existing plan glasses by search text
    private var filteredPlanGlasses: [ProjectGlassItem] {
        guard !searchText.isEmpty else { return existingGlassInPlan }

        return existingGlassInPlan.filter { glass in
            let searchLower = searchText.lowercased()

            // Search in natural key
            if let naturalKey = glass.naturalKey, naturalKey.lowercased().contains(searchLower) {
                return true
            }

            // Search in freeform description
            if let freeformDescription = glass.freeformDescription, freeformDescription.lowercased().contains(searchLower) {
                return true
            }

            // Search in notes
            if let notes = glass.notes, notes.lowercased().contains(searchLower) {
                return true
            }

            return false
        }
    }

    var body: some View {
        Form {
            // Quick Select from Plan Glasses
            if !existingGlassInPlan.isEmpty {
                Section {
                    Text("Glasses already in this plan")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(nil)

                    ForEach(filteredPlanGlasses.prefix(5)) { glass in
                        Button(action: {
                            selectExistingGlass(glass)
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(glass.displayName)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    if glass.quantity > 0 {
                                        Text(verbatim: "\(glass.quantity) \(glass.unit)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                if selectedGlassItem?.natural_key == glass.naturalKey {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Quick Select from Plan")
                }
            }

            // Reusable Glass Search Component (shows cards with images!)
            GlassItemSearchSelector(
                selectedGlassItem: $selectedGlassItem,
                searchText: $searchText,
                prefilledNaturalKey: nil,
                glassItems: glassItems,
                onSelect: { item in
                    selectCatalogGlass(item)
                },
                onClear: {
                    selectedGlassItem = nil
                    searchText = ""
                }
            )

            // Freeform glass option
            if selectedGlassItem == nil && !searchText.isEmpty {
                Section {
                    Text("Or add as custom glass: \"\(searchText)\"")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } footer: {
                    Text("If you can't find the glass in the catalog, we'll add it as a custom entry.")
                        .font(.caption)
                }
            }

            // Quantity and Unit
            Section("Quantity (Optional)") {
                HStack {
                    TextField("Quantity (optional)", text: $quantity)
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

            // Notes Field (dual purpose)
            Section {
                TextField(notesPlaceholder, text: $notes, axis: .vertical)
                    .lineLimit(2...4)
            } header: {
                Text(notesHeader)
            } footer: {
                Text(notesFooter)
                    .font(.caption)
            }
        }
        .navigationTitle("Add Glass to Step")
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
                    saveGlassItem()
                }
                .disabled(!canSave)
            }
        }
        .task {
            await loadGlassItems()
        }
    }

    // MARK: - Computed Properties

    private var notesHeader: String {
        "Notes (Optional)"
    }

    private var notesPlaceholder: String {
        "e.g., for the base layer"
    }

    private var notesFooter: String {
        "Add optional context about how this glass will be used"
    }

    private var canSave: Bool {
        // If quantity is provided, it must be valid
        if !quantity.isEmpty {
            guard Decimal(string: quantity) != nil else {
                return false
            }
        }

        // Either have a catalog item selected, OR have search text (for free-form)
        return selectedGlassItem != nil || !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Helper Functions

    private func selectExistingGlass(_ glass: ProjectGlassItem) {
        // If it's a catalog item, try to find it in the catalog
        if glass.isCatalogItem, let naturalKey = glass.naturalKey {
            if let catalogItem = glassItems.first(where: { $0.natural_key == naturalKey }) {
                selectCatalogGlass(catalogItem)
                quantity = "\(glass.quantity)"
                unit = glass.unit
                notes = glass.notes ?? ""
                return
            }
        }

        // If not a catalog item, pre-fill from existing free-form glass
        selectedGlassItem = nil
        quantity = "\(glass.quantity)"
        unit = glass.unit
        notes = glass.notes ?? ""
        searchText = glass.freeformDescription ?? ""
    }

    private func selectCatalogGlass(_ item: GlassItemModel) {
        selectedGlassItem = item
        searchText = item.name
        // Don't pre-fill quantity - let user enter it fresh
    }

    private func saveGlassItem() {
        // Use quantity from field, or 0 if empty
        let quantityValue = quantity.isEmpty ? Decimal(0) : (Decimal(string: quantity) ?? Decimal(0))

        let newItem: ProjectGlassItem

        if let catalogItem = selectedGlassItem {
            // Catalog item with optional notes
            newItem = ProjectGlassItem(
                stableId: catalogItem.natural_key,
                quantity: quantityValue,
                unit: unit,
                notes: notes.isEmpty ? nil : notes
            )
        } else {
            // Free-form item using search text as description, notes optional
            let trimmedSearch = searchText.trimmingCharacters(in: .whitespaces)
            guard !trimmedSearch.isEmpty else { return }

            newItem = ProjectGlassItem(
                freeformDescription: trimmedSearch,
                quantity: quantityValue,
                unit: unit,
                notes: notes.isEmpty ? nil : notes
            )
        }

        onSave(newItem)
        dismiss()
    }

    private func loadGlassItems() async {
        isLoading = true

        if CatalogSearchCache.shared.isLoaded {
            glassItems = CatalogSearchCache.shared.items
        } else {
            await CatalogSearchCache.shared.loadIfNeeded(catalogService: catalogService)
            glassItems = CatalogSearchCache.shared.items
        }

        isLoading = false
    }
}

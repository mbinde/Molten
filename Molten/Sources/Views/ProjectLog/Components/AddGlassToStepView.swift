//
//  AddGlassToStepView.swift
//  Molten
//
//  View for adding glass items to a project plan step
//  Features unified search with intelligent grouping: plan glasses first, then catalog
//

import SwiftUI

struct AddGlassToStepView: View {
    @Environment(\.dismiss) private var dismiss

    let plan: ProjectPlanModel
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

    init(plan: ProjectPlanModel, onSave: @escaping (ProjectGlassItem) -> Void) {
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

    /// Filter catalog glasses by search text
    private var filteredCatalogGlasses: [GlassItemModel] {
        guard !searchText.isEmpty else { return glassItems }

        return glassItems.filter { item in
            let searchLower = searchText.lowercased()
            return item.name.lowercased().contains(searchLower) ||
                   item.natural_key.lowercased().contains(searchLower) ||
                   item.manufacturer.lowercased().contains(searchLower)
        }
    }

    var body: some View {
        Form {
            // Unified Search Section
            Section {
                TextField("Search glass or enter custom description", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
            }

            // Search Results - Grouped Display
            if !searchText.isEmpty || !existingGlassInPlan.isEmpty || !glassItems.isEmpty {
                Section {
                    // Group 1: Glasses already in this plan
                    if !filteredPlanGlasses.isEmpty {
                        Text("In This Plan")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .textCase(nil)

                        ForEach(filteredPlanGlasses) { glass in
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

                        // Visual separator
                        if !filteredCatalogGlasses.isEmpty {
                            Divider()
                                .padding(.vertical, 4)
                        }
                    }

                    // Group 2: Catalog glasses
                    if !filteredCatalogGlasses.isEmpty {
                        if !filteredPlanGlasses.isEmpty {
                            Text("Catalog")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .textCase(nil)
                        }

                        ForEach(filteredCatalogGlasses.prefix(20)) { item in
                            Button(action: {
                                selectCatalogGlass(item)
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Text(item.natural_key)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if selectedGlassItem?.natural_key == item.natural_key {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }

                        if filteredCatalogGlasses.count > 20 {
                            Text("\(filteredCatalogGlasses.count - 20) more items...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // No results message
                    if filteredPlanGlasses.isEmpty && filteredCatalogGlasses.isEmpty && !searchText.isEmpty {
                        Text("No matching glass found. Enter quantity below to add as custom glass.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Selected Item Display
            if let selected = selectedGlassItem {
                Section("Selected Glass") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selected.name)
                            .font(.headline)
                        Text(selected.natural_key)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button("Clear Selection") {
                        selectedGlassItem = nil
                        searchText = ""
                    }
                    .foregroundColor(.red)
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
                naturalKey: catalogItem.natural_key,
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

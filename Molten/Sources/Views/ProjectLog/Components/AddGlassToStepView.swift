//
//  AddGlassToStepView.swift
//  Molten
//
//  View for adding glass items to a project plan step
//  Supports three modes: quick-add from existing glass in plan, search catalog, or free-form text
//

import SwiftUI

struct AddGlassToStepView: View {
    @Environment(\.dismiss) private var dismiss

    let plan: ProjectPlanModel
    let onSave: (ProjectGlassItem) -> Void

    // Input mode selection
    @State private var inputMode: InputMode = .quickAdd

    // Quick add from existing glass
    @State private var selectedExistingGlass: ProjectGlassItem?

    // Search catalog
    @State private var selectedGlassItem: GlassItemModel?
    @State private var searchText = ""
    @State private var glassItems: [GlassItemModel] = []
    @State private var isLoading = false

    // Free-form text
    @State private var freeformDescription = ""

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

    enum InputMode: String, CaseIterable {
        case quickAdd = "From This Plan"
        case catalog = "Search Catalog"
        case freeform = "Free-Form Text"
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

    var body: some View {
        Form {
            // Input Mode Picker
            Section {
                Picker("Input Method", selection: $inputMode) {
                    ForEach(InputMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Mode-specific input
            switch inputMode {
            case .quickAdd:
                quickAddSection
            case .catalog:
                catalogSearchSection
            case .freeform:
                freeformSection
            }

            // Quantity and Unit (common to all modes)
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
            if inputMode == .catalog {
                await loadGlassItems()
            }
        }
    }

    // MARK: - Input Mode Sections

    @ViewBuilder
    private var quickAddSection: some View {
        Section("Select Glass from This Plan") {
            if existingGlassInPlan.isEmpty {
                Text("No glass items added to other steps yet")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                ForEach(existingGlassInPlan) { glass in
                    Button(action: {
                        selectExistingGlass(glass)
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(glass.displayName)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text("\(glass.quantity) \(glass.unit)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedExistingGlass?.id == glass.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var catalogSearchSection: some View {
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
    }

    @ViewBuilder
    private var freeformSection: some View {
        Section("Glass Description") {
            TextField("e.g., any dark transparent", text: $freeformDescription)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif

            Text("Use free-form text for general descriptions like \"any dark transparent\" or \"clear base glass\"")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Helper Functions

    private func selectExistingGlass(_ glass: ProjectGlassItem) {
        selectedExistingGlass = glass
        // Pre-fill quantity and unit from the selected glass
        quantity = "\(glass.quantity)"
        unit = glass.unit
    }

    private var canSave: Bool {
        guard !quantity.isEmpty, Decimal(string: quantity) != nil else {
            return false
        }

        switch inputMode {
        case .quickAdd:
            return selectedExistingGlass != nil
        case .catalog:
            return selectedGlassItem != nil
        case .freeform:
            return !freeformDescription.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func saveGlassItem() {
        guard let quantityValue = Decimal(string: quantity) else { return }

        let newItem: ProjectGlassItem

        switch inputMode {
        case .quickAdd:
            guard let existing = selectedExistingGlass else { return }
            if existing.isCatalogItem, let naturalKey = existing.naturalKey {
                newItem = ProjectGlassItem(
                    naturalKey: naturalKey,
                    quantity: quantityValue,
                    unit: unit,
                    notes: notes.isEmpty ? nil : notes
                )
            } else if let freeform = existing.freeformDescription {
                newItem = ProjectGlassItem(
                    freeformDescription: freeform,
                    quantity: quantityValue,
                    unit: unit,
                    notes: notes.isEmpty ? nil : notes
                )
            } else {
                return
            }

        case .catalog:
            guard let glassItem = selectedGlassItem else { return }
            newItem = ProjectGlassItem(
                naturalKey: glassItem.natural_key,
                quantity: quantityValue,
                unit: unit,
                notes: notes.isEmpty ? nil : notes
            )

        case .freeform:
            let trimmed = freeformDescription.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            newItem = ProjectGlassItem(
                freeformDescription: trimmed,
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

//
//  AddRecipeView.swift
//  Molten
//
//  View for creating a new recipe
//

import SwiftUI

struct AddRecipeView: View {
    @Environment(\.dismiss) private var dismiss

    private let recipeService: RecipeService
    private let catalogService: CatalogService
    private let onSave: (RecipeModel) -> Void

    // Form state
    @State private var title = ""
    @State private var descriptionText = ""
    @State private var measurementType: MeasurementType = .byWeight
    @State private var ingredients: [RecipeIngredientModel] = []

    // UI state
    @State private var showingAddIngredient = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var availableGlassItems: [CompleteInventoryItemModel] = []
    @State private var isLoadingGlassItems = false

    init(
        recipeService: RecipeService = RepositoryFactory.createRecipeService(),
        catalogService: CatalogService = RepositoryFactory.createCatalogService(),
        onSave: @escaping (RecipeModel) -> Void = { _ in }
    ) {
        self.recipeService = recipeService
        self.catalogService = catalogService
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                // Basic info
                Section("Recipe Details") {
                    TextField("Title", text: $title)
                        .autocorrectionDisabled()

                    Picker("Measurement Type", selection: $measurementType) {
                        ForEach(MeasurementType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }

                    TextField("Description (optional)", text: $descriptionText, axis: .vertical)
                        .lineLimit(3...6)
                }

                // Ingredients
                Section {
                    ForEach(ingredients) { ingredient in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(ingredient.stableId)
                                    .font(.body)
                                Text("Glass Item ID")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("\(ingredient.amount, specifier: "%.2f")")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete(perform: deleteIngredients)

                    Button {
                        showingAddIngredient = true
                    } label: {
                        Label("Add Ingredient", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Ingredients")
                } footer: {
                    if ingredients.isEmpty {
                        Text("Add frit or glass items to this recipe")
                    }
                }

                // Validation feedback
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveRecipe()
                        }
                    }
                    .disabled(!isValid || isSaving)
                }
            }
            .sheet(isPresented: $showingAddIngredient) {
                AddIngredientView(
                    availableItems: availableGlassItems,
                    measurementType: measurementType,
                    onAdd: { ingredient in
                        ingredients.append(ingredient)
                        showingAddIngredient = false
                    }
                )
            }
            .task {
                await loadGlassItems()
            }
        }
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func deleteIngredients(at offsets: IndexSet) {
        ingredients.remove(atOffsets: offsets)
    }

    private func loadGlassItems() async {
        isLoadingGlassItems = true
        do {
            availableGlassItems = try await catalogService.getAllGlassItems()
        } catch {
            errorMessage = "Failed to load glass items: \(error.localizedDescription)"
        }
        isLoadingGlassItems = false
    }

    private func saveRecipe() async {
        errorMessage = nil
        isSaving = true

        do {
            let recipe = RecipeModel(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                descriptionText: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
                measurementType: measurementType,
                ingredients: ingredients
            )

            let saved = try await recipeService.createRecipe(recipe)
            onSave(saved)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}

// MARK: - Add Ingredient View

struct AddIngredientView: View {
    @Environment(\.dismiss) private var dismiss

    let availableItems: [CompleteInventoryItemModel]
    let measurementType: MeasurementType
    let onAdd: (RecipeIngredientModel) -> Void

    @State private var searchText = ""
    @State private var selectedItem: CompleteInventoryItemModel?
    @State private var amount: Double = 1.0

    var filteredItems: [CompleteInventoryItemModel] {
        if searchText.isEmpty {
            return availableItems
        } else {
            return availableItems.filter { item in
                item.glassItem.name.localizedCaseInsensitiveContains(searchText) ||
                item.glassItem.stable_id.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search glass items", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(DesignSystem.Padding.standard)
                .background(DesignSystem.Colors.backgroundSecondary)

                Divider()

                // Item list
                List(filteredItems, id: \.glassItem.stable_id) { item in
                    Button {
                        selectedItem = item
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.glassItem.name)
                                    .foregroundStyle(.primary)
                                Text(item.glassItem.stable_id)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if selectedItem?.glassItem.stable_id == item.glassItem.stable_id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
                .listStyle(.plain)

                // Amount input
                if selectedItem != nil {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Divider()

                        HStack {
                            Text("Amount:")
                                .fontWeight(.medium)

                            TextField("Amount", value: $amount, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)

                            Text(measurementType == .byWeight ? "grams" : "parts")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)

                        Button {
                            if let item = selectedItem {
                                let ingredient = RecipeIngredientModel(
                                    stableId: item.glassItem.stable_id,
                                    amount: amount
                                )
                                onAdd(ingredient)
                            }
                        } label: {
                            Text("Add Ingredient")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.horizontal)
                        .padding(.bottom)
                        .disabled(amount <= 0)
                    }
                    .background(DesignSystem.Colors.backgroundSecondary)
                }
            }
            .navigationTitle("Add Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview("Add Recipe") {
    RepositoryFactory.configureForTesting()
    return AddRecipeView()
}

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
    @State private var recordMeasurements = false
    @State private var ingredients: [RecipeIngredientModel] = []

    // UI state
    @State private var ingredientSearchText = ""
    @State private var showingIngredientResults = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var availableGlassItems: [CompleteInventoryItemModel] = []
    @State private var isLoadingGlassItems = false

    init(
        recipeService: RecipeService,
        catalogService: CatalogService,
        onSave: @escaping (RecipeModel) -> Void = { _ in }
    ) {
        self.recipeService = recipeService
        self.catalogService = catalogService
        self.onSave = onSave
    }

    /// Convenience init using AppDependencies
    init(deps: AppDependencies = AppDependencies(), onSave: @escaping (RecipeModel) -> Void = { _ in }) {
        self.recipeService = deps.recipeService
        self.catalogService = deps.catalogService
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                // Basic info
                Section("Recipe Details") {
                    TextField("Title", text: $title)
                        .autocorrectionDisabled()

                    TextField("Description (optional)", text: $descriptionText, axis: .vertical)
                        .lineLimit(3...6)
                }

                // Measurement toggle
                Section {
                    Toggle("Record ingredient measurements", isOn: $recordMeasurements)
                } footer: {
                    if recordMeasurements {
                        Text("Track precise amounts for each ingredient")
                    } else {
                        Text("Just list ingredients without measurements")
                    }
                }

                // Ingredients
                ingredientsSection

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
            .task {
                await loadGlassItems()
            }
        }
    }

    private var ingredientsSection: some View {
        Section {
            // Existing ingredients
            ForEach(ingredients) { ingredient in
                HStack(spacing: DesignSystem.Spacing.sm) {
                    // Thumbnail
                    if let item = availableGlassItems.first(where: { $0.glassItem.stable_id == ingredient.stableId }) {
                        AsyncImage(url: URL(string: item.glassItem.image_url ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        Text(item.glassItem.name)
                            .font(.body)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        Text(ingredient.stableId)
                            .font(.body)
                    }

                    Spacer()

                    if recordMeasurements {
                        Text("\(ingredient.amount, specifier: "%.2f")")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete(perform: deleteIngredients)

            // Inline search field
            HStack {
                TextField("Search glass items to add...", text: $ingredientSearchText)
                    .autocorrectionDisabled()

                if !ingredientSearchText.isEmpty {
                    Button {
                        ingredientSearchText = ""
                        showingIngredientResults = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
            .onChange(of: ingredientSearchText) { _, newValue in
                showingIngredientResults = !newValue.isEmpty
            }

            // Show filtered results when searching
            if showingIngredientResults && !ingredientSearchText.isEmpty {
                ForEach(filteredGlassItems.prefix(5)) { item in
                    Button {
                        addIngredient(item)
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            // Thumbnail
                            AsyncImage(url: URL(string: item.glassItem.image_url ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                            Text(item.glassItem.name)
                                .font(.body)
                                .foregroundColor(.primary)

                            Spacer()

                            if ingredients.contains(where: { $0.stableId == item.glassItem.stable_id }) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                if filteredGlassItems.count > 5 {
                    Text("\(filteredGlassItems.count - 5) more...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Ingredients")
        } footer: {
            if ingredients.isEmpty {
                Text("Add frit or glass items to this recipe")
            }
        }
    }

    private var filteredGlassItems: [CompleteInventoryItemModel] {
        if ingredientSearchText.isEmpty {
            return []
        }
        return availableGlassItems.filter { item in
            item.glassItem.name.localizedCaseInsensitiveContains(ingredientSearchText) ||
            item.glassItem.stable_id.localizedCaseInsensitiveContains(ingredientSearchText)
        }
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func deleteIngredients(at offsets: IndexSet) {
        ingredients.remove(atOffsets: offsets)
    }

    private func addIngredient(_ item: CompleteInventoryItemModel) {
        // Check if already added
        guard !ingredients.contains(where: { $0.stableId == item.glassItem.stable_id }) else {
            ingredientSearchText = ""
            showingIngredientResults = false
            return
        }

        let ingredient = RecipeIngredientModel(
            stableId: item.glassItem.stable_id,
            amount: recordMeasurements ? 1.0 : 0.0
        )
        ingredients.append(ingredient)
        ingredientSearchText = ""
        showingIngredientResults = false
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
                measurementType: recordMeasurements ? .byRatio : .byRatio,
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

#Preview("Add Recipe") {
    RepositoryFactory.configureForTesting()
    return AddRecipeView()
}

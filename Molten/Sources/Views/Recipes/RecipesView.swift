//
//  RecipesView.swift
//  Molten
//
//  Main view for managing frit recipes
//

import SwiftUI

struct RecipesView: View {
    private let deps: AppDependencies
    private let recipeService: RecipeService
    private let recipeRepository: RecipeRepository

    @State private var recipes: [RecipeModel] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var showingAddRecipe = false

    init(deps: AppDependencies = AppDependencies()) {
        self.deps = deps
        self.recipeService = deps.recipeService
        self.recipeRepository = deps.recipeRepository
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar at top
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search recipes", text: $searchText)
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

                // Content
                if isLoading {
                    LoadingStateView(message: "Loading recipes...")
                } else if let error = errorMessage {
                    errorView(error)
                } else if filteredRecipes.isEmpty {
                    if recipes.isEmpty {
                        emptyStateView
                    } else {
                        searchEmptyStateView
                    }
                } else {
                    recipeList
                }
            }
            .navigationTitle("Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddRecipe = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddRecipe) {
                AddRecipeView(
                    deps: deps,
                    onSave: { newRecipe in
                        recipes.append(newRecipe)
                    }
                )
            }
            .task {
                await loadRecipes()
            }
        }
    }

    private var filteredRecipes: [RecipeModel] {
        if searchText.isEmpty {
            return recipes
        } else {
            return recipes.filter { recipe in
                recipe.title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private var recipeList: some View {
        List {
            ForEach(filteredRecipes) { recipe in
                NavigationLink {
                    RecipeDetailView(recipe: recipe, deps: deps)
                } label: {
                    RecipeRow(recipe: recipe)
                }
            }
            .onDelete { indexSet in
                Task {
                    for index in indexSet {
                        await deleteRecipe(filteredRecipes[index])
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var emptyStateView: some View {
        CustomEmptyStateView(
            icon: "book.closed",
            title: "No Recipes Yet",
            description: "Create recipes to blend frit colors and track your favorite combinations",
            actionButton: .init(
                title: "Create Your First Recipe",
                action: { showingAddRecipe = true },
                style: .prominent
            )
        )
    }

    private var searchEmptyStateView: some View {
        CustomEmptyStateView.searchResults(
            searchTerm: searchText.isEmpty ? nil : searchText,
            filters: [],
            onClearFilters: {
                searchText = ""
            }
        )
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            Text("Error Loading Recipes")
                .font(.title3)
                .fontWeight(.semibold)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task {
                    await loadRecipes()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private func loadRecipes() async {
        isLoading = true
        errorMessage = nil

        do {
            recipes = try await recipeService.getAllRecipes()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Custom Deletion Pattern
    //
    // ⚠️ IMPORTANT: This view does NOT use CachedDataDeletion protocol
    // (see Molten/Sources/Utilities/DeletionHelpers.swift)
    //
    // WHY: Swift 6 strict concurrency issue with protocol conformance
    //      (conformance crosses into main actor-isolated code)
    //
    // PATTERN: This implementation follows the SAME three-step pattern as CachedDataDeletion:
    //   1. Delete from database (performDeletion)
    //   2. Immediate cache removal (removeFromCache)
    //   3. Deferred reload (reloadData) - 0.3s delay prevents animation crashes
    //
    // ⚠️ MAINTENANCE: If you update DeletionHelpers.swift, apply equivalent changes here:
    //   - Timing (currently 0.3s / 300_000_000 nanoseconds)
    //   - Error handling pattern
    //   - Cache update sequence
    //
    private func deleteRecipe(_ item: RecipeModel) async {
        do {
            // Step 1: Delete from database
            try await recipeRepository.deleteRecipe(id: item.id)

            // Step 2: Immediately update the view model to remove the deleted item
            await MainActor.run {
                recipes.removeAll { $0.id == item.id }
            }

            // Step 3: Defer full reload to allow .onDelete animation to complete
            // (Same timing as DeletionHelpers.deleteItem: 0.3 seconds)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)  // 0.3 seconds
                await loadRecipes()
            }
        } catch {
            print("❌ Failed to delete recipe: \(error)")
        }
    }
}

// MARK: - Recipe Row

struct RecipeRow: View {
    let recipe: RecipeModel

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(recipe.title)
                .font(DesignSystem.Typography.rowTitle)

            HStack(spacing: DesignSystem.Spacing.sm) {
                Label(recipe.measurementType.displayName, systemImage: measurementIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !recipe.ingredients.isEmpty {
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text("\(recipe.ingredients.count) ingredients")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !recipe.descriptionText.isEmpty {
                Text(recipe.descriptionText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, DesignSystem.Padding.rowVertical)
    }

    private var measurementIcon: String {
        switch recipe.measurementType {
        case .byWeight:
            return "scalemass"
        case .byRatio:
            return "percent"
        }
    }
}

// MARK: - Recipe Detail View

struct RecipeDetailView: View {
    let recipe: RecipeModel
    let recipeService: RecipeService

    private let catalogService: CatalogService

    @State private var availableGlassItems: [CompleteInventoryItemModel] = []
    @State private var isLoadingGlassItems = false

    init(recipe: RecipeModel, deps: AppDependencies = AppDependencies()) {
        self.recipe = recipe
        self.recipeService = deps.recipeService
        self.catalogService = deps.catalogService
    }

    var body: some View {
        List {
            Section("Details") {
                LabeledContent("Title", value: recipe.title)

                if !recipe.descriptionText.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(recipe.descriptionText)
                    }
                }
            }

            if !recipe.ingredients.isEmpty {
                Section("Ingredients") {
                    ForEach(recipe.ingredients) { ingredient in
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

                            if ingredient.amount > 0 {
                                Text("\(ingredient.amount, specifier: "%.2f")")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section("Metadata") {
                LabeledContent("Created", value: recipe.dateCreated, format: .dateTime)
                LabeledContent("Modified", value: recipe.dateModified, format: .dateTime)
            }
        }
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadGlassItems()
        }
    }

    private func loadGlassItems() async {
        isLoadingGlassItems = true
        do {
            availableGlassItems = try await catalogService.getAllGlassItems()
        } catch {
            // Silently fail - just won't show thumbnails
        }
        isLoadingGlassItems = false
    }
}

#Preview("Empty State") {
    let deps = AppDependencies(persistenceController: .createTestController())
    return RecipesView(deps: deps)
}

#Preview("With Recipes") {
    let deps = AppDependencies(persistenceController: .createTestController())

    // Create some test recipes
    Task {
        let service = deps.recipeService
        _ = try? await service.createRecipe(RecipeModel(
            title: "Clear Frit Mix",
            descriptionText: "A basic clear frit blend",
            measurementType: .byWeight,
            ingredients: [
                RecipeIngredientModel(stableId: "bullseye-clear-001", amount: 100.0)
            ]
        ))
        _ = try? await service.createRecipe(RecipeModel(
            title: "Blue Tint",
            descriptionText: "Subtle blue color",
            measurementType: .byRatio,
            ingredients: [
                RecipeIngredientModel(stableId: "bullseye-clear-001", amount: 10.0),
                RecipeIngredientModel(stableId: "bullseye-blue-001", amount: 1.0)
            ]
        ))
    }

    return RecipesView(deps: deps)
}

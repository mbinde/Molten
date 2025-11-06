//
//  RecipesView.swift
//  Molten
//
//  Main view for managing frit recipes
//

import SwiftUI

struct RecipesView: View {
    private let recipeService: RecipeService

    @State private var recipes: [RecipeModel] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var showingAddRecipe = false

    init(recipeService: RecipeService = RepositoryFactory.createRecipeService()) {
        self.recipeService = recipeService
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
                    ProgressView("Loading recipes...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    recipeService: recipeService,
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
                    RecipeDetailView(recipe: recipe, recipeService: recipeService)
                } label: {
                    RecipeRow(recipe: recipe)
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

    var body: some View {
        List {
            Section("Details") {
                LabeledContent("Title", value: recipe.title)
                LabeledContent("Measurement Type", value: recipe.measurementType.displayName)

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
                        HStack {
                            Text(ingredient.stableId)
                            Spacer()
                            Text("\(ingredient.amount, specifier: "%.2f")")
                                .foregroundStyle(.secondary)
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
    }
}

#Preview("Empty State") {
    RepositoryFactory.configureForTesting()
    return RecipesView()
}

#Preview("With Recipes") {
    RepositoryFactory.configureForTesting()

    // Create some test recipes
    Task {
        let service = RepositoryFactory.createRecipeService()
        try? await service.createRecipe(RecipeModel(
            title: "Clear Frit Mix",
            descriptionText: "A basic clear frit blend",
            measurementType: .byWeight,
            ingredients: [
                RecipeIngredientModel(stableId: "bullseye-clear-001", amount: 100.0)
            ]
        ))
        try? await service.createRecipe(RecipeModel(
            title: "Blue Tint",
            descriptionText: "Subtle blue color",
            measurementType: .byRatio,
            ingredients: [
                RecipeIngredientModel(stableId: "bullseye-clear-001", amount: 10.0),
                RecipeIngredientModel(stableId: "bullseye-blue-001", amount: 1.0)
            ]
        ))
    }

    return RecipesView()
}

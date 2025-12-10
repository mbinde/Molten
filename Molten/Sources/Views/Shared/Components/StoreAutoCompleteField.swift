//
//  StoreAutoCompleteField.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//  Auto-complete input field for shopping list store names
//

import SwiftUI

/// Auto-complete input field for store names using repository pattern
struct StoreAutoCompleteField: View {
    @Binding var store: String
    let shoppingListRepository: ShoppingListRepository
    let locationService: UnifiedLocationService

    @State private var showingSuggestions = false
    @State private var storeSuggestions: [StoreSuggestion] = []
    @FocusState private var isTextFieldFocused: Bool

    init(store: Binding<String>,
         shoppingListRepository: ShoppingListRepository,
         locationService: UnifiedLocationService) {
        self._store = store
        self.shoppingListRepository = shoppingListRepository
        self.locationService = locationService
    }

    /// Convenience init using AppDependencies
    init(store: Binding<String>, deps: AppDependencies = .shared) {
        self._store = store
        self.shoppingListRepository = deps.shoppingListRepository
        self.locationService = deps.unifiedLocationService
    }

    /// Represents a store suggestion with metadata about its source
    private struct StoreSuggestion: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let isStoreEntity: Bool // true if from Store entities, false if from shopping list

        func hash(into hasher: inout Hasher) {
            hasher.combine(name)
            hasher.combine(isStoreEntity)
        }

        static func == (lhs: StoreSuggestion, rhs: StoreSuggestion) -> Bool {
            lhs.name == rhs.name && lhs.isStoreEntity == rhs.isStoreEntity
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            TextField("Optional", text: $store)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .focused($isTextFieldFocused)
                .onSubmit {
                    showingSuggestions = false
                }
                .onChange(of: store) { _, newValue in
                    updateSuggestions(for: newValue)
                }
                .onChange(of: isTextFieldFocused) { _, isFocused in
                    if isFocused {
                        Task {
                            await loadInitialSuggestions()
                        }
                    } else {
                        // Delay hiding to allow tapping suggestions
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            showingSuggestions = false
                        }
                    }
                }

            // Auto-complete suggestions below the text field
            if showingSuggestions && !storeSuggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(storeSuggestions.prefix(5)) { suggestion in
                        Button(action: {
                            store = suggestion.name
                            showingSuggestions = false
                            isTextFieldFocused = false
                        }) {
                            HStack {
                                // Show storefront icon for Store entities
                                if suggestion.isStoreEntity {
                                    Image(systemName: "storefront")
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                        .font(.caption)
                                }

                                Text(suggestion.name)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)

                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(Color(UIColor.systemBackground))
                        .accessibilityIdentifier("store_autocomplete_\(suggestion.name.replacingOccurrences(of: " ", with: "_").lowercased())")

                        if suggestion != storeSuggestions.prefix(5).last {
                            Divider()
                        }
                    }
                }
                .background(Color(UIColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
        }
    }

    private func updateSuggestions(for searchText: String) {
        Task {
            storeSuggestions = await getStoreSuggestions(matching: searchText)
            await MainActor.run {
                showingSuggestions = !storeSuggestions.isEmpty && isTextFieldFocused
            }
        }
    }

    private func loadInitialSuggestions() async {
        let suggestions = await getDistinctStores()
        await MainActor.run {
            storeSuggestions = suggestions
            showingSuggestions = !suggestions.isEmpty && isTextFieldFocused
        }
    }

    // MARK: - Store Service Methods (Repository Pattern)

    private func getDistinctStores() async -> [StoreSuggestion] {
        do {
            // Get store names from multiple sources:
            // 1. Previous shopping list stores entered by user
            // 2. Retail locations (stores)
            // 3. All locations (including inventory storage locations like "Studio")
            let shoppingListStores = try await shoppingListRepository.getDistinctStores()
            let allLocations = try await locationService.getAllLocations()

            // Create suggestions from all locations (with icon for retail ones)
            let locationSuggestions = allLocations.map { location in
                StoreSuggestion(name: location.name, isStoreEntity: location.hasRetail)
            }

            // Create suggestions from shopping list stores (without icon)
            let shoppingListSuggestions = shoppingListStores.map { storeName in
                StoreSuggestion(name: storeName, isStoreEntity: false)
            }

            // Combine and deduplicate (prefer location entities over shopping list entries)
            var uniqueStores: [String: StoreSuggestion] = [:]
            for suggestion in shoppingListSuggestions {
                uniqueStores[suggestion.name] = suggestion
            }
            for suggestion in locationSuggestions {
                uniqueStores[suggestion.name] = suggestion // Overwrites if duplicate
            }

            // Sort alphabetically by name
            return uniqueStores.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        } catch {
            print("❌ Failed to fetch store suggestions: \(error)")
            return []
        }
    }

    private func getStoreSuggestions(matching searchText: String) async -> [StoreSuggestion] {
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Get all stores from both sources
        let allStoreSuggestions = await getDistinctStores()

        guard !trimmedSearchText.isEmpty else {
            return allStoreSuggestions
        }

        // Filter stores that contain search text (case-insensitive)
        // Prioritize stores that START with the search text, then ones that contain it
        let lowercaseSearch = trimmedSearchText.lowercased()
        let startsWithMatches = allStoreSuggestions.filter {
            $0.name.lowercased().hasPrefix(lowercaseSearch)
        }
        let containsMatches = allStoreSuggestions.filter {
            !$0.name.lowercased().hasPrefix(lowercaseSearch) &&
            $0.name.lowercased().contains(lowercaseSearch)
        }
        return startsWithMatches + containsMatches
    }
}

#Preview {
    @Previewable @State var store = ""
    let deps = AppDependencies(persistenceController: .createTestController())

    VStack {
        StoreAutoCompleteField(
            store: $store,
            deps: deps
        )
        Spacer()
    }
    .padding()
}

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
    init(store: Binding<String>, deps: AppDependencies = AppDependencies()) {
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
        VStack(spacing: 0) {
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
                        loadInitialSuggestions()
                        showingSuggestions = true
                    } else {
                        // Delay hiding to allow tapping suggestions
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showingSuggestions = false
                        }
                    }
                }

            // Auto-complete suggestions dropdown
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
                                        .foregroundColor(.secondary)
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
                        .background(Color(white: 1.0))

                        if suggestion != storeSuggestions.prefix(5).last {
                            Divider()
                        }
                    }
                }
                .background(Color(white: 1.0))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                .zIndex(1)
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

    private func loadInitialSuggestions() {
        Task {
            storeSuggestions = await getDistinctStores()
        }
    }

    // MARK: - Store Service Methods (Repository Pattern)

    private func getDistinctStores() async -> [StoreSuggestion] {
        do {
            // Get store names from both sources
            let shoppingListStores = try await shoppingListRepository.getDistinctStores()
            let locationEntities = try await locationService.getRetailLocations()

            // Create suggestions from retail locations (with icon)
            let locationSuggestions = locationEntities.map { location in
                StoreSuggestion(name: location.name, isStoreEntity: true)
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
        do {
            let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

            // Get all stores from both sources
            let allStoreSuggestions = await getDistinctStores()

            guard !trimmedSearchText.isEmpty else {
                return allStoreSuggestions
            }

            // Filter stores that start with search text (case-insensitive)
            let lowercaseSearch = trimmedSearchText.lowercased()
            let suggestions = allStoreSuggestions.filter {
                $0.name.lowercased().hasPrefix(lowercaseSearch)
            }
            return suggestions

        } catch {
            print("❌ Failed to get store suggestions: \(error)")
            return []
        }
    }
}

#Preview {
    @Previewable @State var store = ""
    let deps = AppDependencies(forTesting: true)

    VStack {
        StoreAutoCompleteField(
            store: $store,
            deps: deps
        )
        Spacer()
    }
    .padding()
}

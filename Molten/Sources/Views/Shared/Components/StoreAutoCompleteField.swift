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

    @State private var showingSuggestions = false
    @State private var storeSuggestions: [String] = []
    @FocusState private var isTextFieldFocused: Bool

    init(store: Binding<String>, shoppingListRepository: ShoppingListRepository? = nil) {
        self._store = store
        self.shoppingListRepository = shoppingListRepository ?? RepositoryFactory.createShoppingListRepository()
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
                    ForEach(storeSuggestions.prefix(5), id: \.self) { suggestion in
                        Button(action: {
                            store = suggestion
                            showingSuggestions = false
                            isTextFieldFocused = false
                        }) {
                            HStack {
                                Image(systemName: "storefront")
                                    .foregroundColor(.secondary)
                                    .font(.caption)

                                Text(suggestion)
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

    private func getDistinctStores() async -> [String] {
        do {
            // Get all distinct store names from the shopping list repository
            let storeNames = try await shoppingListRepository.getDistinctStores()
            return storeNames

        } catch {
            print("❌ Failed to fetch store suggestions: \(error)")
            return []
        }
    }

    private func getStoreSuggestions(matching searchText: String) async -> [String] {
        do {
            let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedSearchText.isEmpty else {
                return try await shoppingListRepository.getDistinctStores()
            }

            // Filter stores that start with search text (case-insensitive)
            let allStores = try await shoppingListRepository.getDistinctStores()
            let lowercaseSearch = trimmedSearchText.lowercased()
            let suggestions = allStores.filter { $0.lowercased().hasPrefix(lowercaseSearch) }
            return suggestions

        } catch {
            print("❌ Failed to get store suggestions: \(error)")
            return []
        }
    }
}

#Preview {
    @State var store = ""

    VStack {
        StoreAutoCompleteField(store: $store)
        Spacer()
    }
    .padding()
}

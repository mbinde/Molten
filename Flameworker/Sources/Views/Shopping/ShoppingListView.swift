//
//  ShoppingListView.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//

import SwiftUI

struct ShoppingListView: View {
    private let shoppingListService: ShoppingListService

    @State private var shoppingItems: [ItemShoppingModel] = []
    @State private var isLoading = false

    init(shoppingListService: ShoppingListService) {
        self.shoppingListService = shoppingListService
    }

    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if shoppingItems.isEmpty {
                    emptyStateView
                } else {
                    shoppingListContent
                }
            }
            .navigationTitle("Shopping List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // TODO: Add functionality to add items
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                await loadShoppingList()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "cart")
                .font(.system(size: 80))
                .foregroundColor(.secondary)

            Text("Shopping List Empty")
                .font(.title2)
                .fontWeight(.bold)

            Text("Add items you need to purchase")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var shoppingListContent: some View {
        List {
            ForEach(shoppingItems) { item in
                ShoppingListRowView(item: item)
            }
            .onDelete(perform: deleteItems)
        }
    }

    private func loadShoppingList() async {
        isLoading = true
        defer { isLoading = false }

        do {
            shoppingItems = try await shoppingListService.getAllShoppingItems()
        } catch {
            print("Error loading shopping list: \(error)")
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let item = shoppingItems[index]
                do {
                    try await shoppingListService.removeShoppingItem(
                        naturalKey: item.item_natural_key,
                        store: item.store
                    )
                } catch {
                    print("Error deleting item: \(error)")
                }
            }
            await loadShoppingList()
        }
    }
}

struct ShoppingListRowView: View {
    let item: ItemShoppingModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.item_natural_key)
                    .font(.headline)

                if let store = item.store {
                    Text(store)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text("\(item.quantity, specifier: "%.1f")")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    RepositoryFactory.configureForTesting()
    let shoppingListService = RepositoryFactory.createShoppingListService()
    return ShoppingListView(shoppingListService: shoppingListService)
}

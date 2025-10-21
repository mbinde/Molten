//
//  TestDataGeneratorView.swift
//  Flameworker
//
//  Created by Assistant on 10/19/25.
//  Test data generator for development and testing
//

import SwiftUI

struct TestDataGeneratorView: View {
    @StateObject private var errorState = ErrorAlertState()
    @State private var isGenerating = false
    @State private var lastGeneratedMessage = ""
    @State private var showingSuccess = false

    private let inventoryTrackingService: InventoryTrackingService
    private let shoppingListService: ShoppingListService
    private let catalogService: CatalogService

    init(
        inventoryTrackingService: InventoryTrackingService? = nil,
        shoppingListService: ShoppingListService? = nil,
        catalogService: CatalogService? = nil
    ) {
        self.inventoryTrackingService = inventoryTrackingService ?? RepositoryFactory.createInventoryTrackingService()
        self.shoppingListService = shoppingListService ?? RepositoryFactory.createShoppingListService()
        self.catalogService = catalogService ?? RepositoryFactory.createCatalogService()
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Generate test data for development and testing")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Each button press adds more data to your database")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                Button {
                    generate25InventoryItems()
                } label: {
                    Label("Add 25 Random Inventory Items", systemImage: "cube.box")
                }
                .disabled(isGenerating)
            } header: {
                Text("Inventory Test Data")
            } footer: {
                Text("Adds 25 random inventory records with varying quantities and types")
            }

            Section {
                Button {
                    generate10ShoppingItems()
                } label: {
                    Label("Add 10 Random Shopping Items", systemImage: "cart")
                }
                .disabled(isGenerating)
            } header: {
                Text("Shopping List Test Data")
            } footer: {
                Text("Adds 10 random items to your shopping list with various stores")
            }

            if !lastGeneratedMessage.isEmpty {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(lastGeneratedMessage)
                            .font(.subheadline)
                    }
                }
            }

            if isGenerating {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Generating data...")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Test Data Generator")
        .errorAlert(errorState)
    }

    // MARK: - Data Generation

    private func generate25InventoryItems() {
        guard !isGenerating else { return }

        isGenerating = true
        lastGeneratedMessage = ""

        Task {
            let startTime = Date()
            print("🔧 [TestData] Starting inventory generation at \(startTime)")

            do {
                // Get all available glass items from catalog
                let catalogStartTime = Date()
                let glassItems = try await catalogService.getAllGlassItems()
                let catalogDuration = Date().timeIntervalSince(catalogStartTime)
                print("🔧 [TestData] Loaded \(glassItems.count) catalog items in \(String(format: "%.2f", catalogDuration))s")

                guard !glassItems.isEmpty else {
                    throw TestDataError.noCatalogItems
                }

                // Generate 25 random inventory items
                var createdCount = 0
                let types = ["rod", "tube", "frit", "sheet", "stringer"]
                let locations = ["Studio", "Storage Room", "Shelf A", "Drawer B", "Cabinet 1", ""]

                for i in 0..<25 {
                    let itemStartTime = Date()

                    // Pick a random glass item
                    guard let randomItem = glassItems.randomElement() else { continue }

                    // Random quantity between 1 and 50 (whole numbers only)
                    let quantity = Double(Int.random(in: 1...50))

                    // Random type
                    guard let type = types.randomElement() else { continue }

                    // Random location (sometimes empty)
                    let location = locations.randomElement() ?? ""

                    // Create location distribution
                    let locationDistribution: [(location: String, quantity: Double)] = location.isEmpty ? [] : [(location, quantity)]

                    // Add inventory
                    _ = try await inventoryTrackingService.addInventory(
                        quantity: quantity,
                        type: type,
                        toItem: randomItem.glassItem.natural_key,
                        distributedTo: locationDistribution
                    )

                    createdCount += 1
                    let itemDuration = Date().timeIntervalSince(itemStartTime)
                    print("🔧 [TestData] Item \(i+1)/25: Created inventory for '\(randomItem.glassItem.name)' in \(String(format: "%.3f", itemDuration))s")
                }

                let totalDuration = Date().timeIntervalSince(startTime)
                print("🔧 [TestData] ✅ Completed: Created \(createdCount) items in \(String(format: "%.2f", totalDuration))s (avg: \(String(format: "%.3f", totalDuration / Double(createdCount)))s per item)")

                await MainActor.run {
                    isGenerating = false
                    lastGeneratedMessage = "✅ Added \(createdCount) inventory items in \(String(format: "%.1f", totalDuration))s"
                    showingSuccess = true

                    // Post notification to refresh InventoryView
                    NotificationCenter.default.post(name: .inventoryItemAdded, object: nil)
                }

            } catch {
                let totalDuration = Date().timeIntervalSince(startTime)
                print("🔧 [TestData] ❌ Failed after \(String(format: "%.2f", totalDuration))s: \(error)")

                await MainActor.run {
                    isGenerating = false
                    errorState.show(error: error, context: "Failed to generate inventory test data")
                }
            }
        }
    }

    private func generate10ShoppingItems() {
        guard !isGenerating else { return }

        isGenerating = true
        lastGeneratedMessage = ""

        Task {
            do {
                // Get all available glass items from catalog
                let glassItems = try await catalogService.getAllGlassItems()
                guard !glassItems.isEmpty else {
                    throw TestDataError.noCatalogItems
                }

                // Generate 10 random shopping list items
                var createdCount = 0
                let stores = ["Frantz", "Hot Glass Color", "Mountain Glass"]
                let types = ["rod", "tube", "frit", "sheet"]

                for _ in 0..<10 {
                    // Pick a random glass item
                    guard let randomItem = glassItems.randomElement() else { continue }

                    // Random needed quantity between 1 and 20 (whole numbers only)
                    let neededQuantity = Double(Int.random(in: 1...20))

                    // Random store
                    let store = stores.randomElement() ?? "Online"

                    // Random type
                    let type = types.randomElement() ?? "rod"

                    // Create shopping list item
                    let newItem = ItemShoppingModel(
                        item_natural_key: randomItem.glassItem.natural_key,
                        quantity: neededQuantity,
                        store: store,
                        type: type,
                        subtype: nil,
                        subsubtype: nil
                    )

                    _ = try await shoppingListService.shoppingListRepository.createItem(newItem)

                    createdCount += 1
                }

                await MainActor.run {
                    isGenerating = false
                    lastGeneratedMessage = "✅ Added \(createdCount) shopping list items"
                    showingSuccess = true

                    // Post notification to refresh ShoppingListView
                    NotificationCenter.default.post(name: .shoppingListItemAdded, object: nil)
                }

            } catch {
                await MainActor.run {
                    isGenerating = false
                    errorState.show(error: error, context: "Failed to generate shopping list test data")
                }
            }
        }
    }
}

// MARK: - Errors

enum TestDataError: LocalizedError {
    case noCatalogItems

    var errorDescription: String? {
        switch self {
        case .noCatalogItems:
            return "No catalog items found. Please load catalog data first from Data Management."
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TestDataGeneratorView()
    }
}

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
    @State private var inventoryItemCount = 19
    @State private var shoppingItemCount = 10

    private let inventoryTrackingService: InventoryTrackingService
    private let shoppingListService: ShoppingListService
    private let catalogService: CatalogService

    init(
        inventoryTrackingService: InventoryTrackingService,
        shoppingListService: ShoppingListService,
        catalogService: CatalogService
    ) {
        self.inventoryTrackingService = inventoryTrackingService
        self.shoppingListService = shoppingListService
        self.catalogService = catalogService
    }

    /// Convenience init using AppDependencies
    init(deps: AppDependencies = .shared) {
        self.inventoryTrackingService = deps.inventoryTrackingService
        self.shoppingListService = deps.shoppingListService
        self.catalogService = deps.catalogService
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Generate test data for development and testing")
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text("Each button press adds more data to your database")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                HStack {
                    Text("Items to add:")
                    TextField("", value: $inventoryItemCount, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    Stepper("", value: $inventoryItemCount, in: 1...1000)
                        .labelsHidden()
                }
                Button {
                    generateInventoryItems(count: inventoryItemCount)
                } label: {
                    Label("Add \(inventoryItemCount) Random Inventory Items", systemImage: "c/ube.box")
                }
                .disabled(isGenerating)
                .accessibilityIdentifier("test_data_generate_inventory")
            } header: {
                Text("Inventory Test Data")
            } footer: {
                Text("Adds random inventory records with varying quantities and types")
            }

            Section {
                HStack {
                    Text("Items to add:")
                    TextField("", value: $shoppingItemCount, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    Stepper("", value: $shoppingItemCount, in: 1...1000)
                        .labelsHidden()
                }
                Button {
                    generateShoppingItems(count: shoppingItemCount)
                } label: {
                    Label("Add \(shoppingItemCount) Random Shopping Items", systemImage: "cart")
                }
                .disabled(isGenerating)
                .accessibilityIdentifier("test_data_generate_shopping")
            } header: {
                Text("Shopping List Test Data")
            } footer: {
                Text("Adds random items to your shopping list with various stores")
            }

            Section {
                Button {
                    runStorageLocationMigration()
                } label: {
                    Label("Run StorageLocation Migration", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(isGenerating)
                .accessibilityIdentifier("test_data_run_migration")

                Button {
                    testLocationDefinitionMigration()
                } label: {
                    Label("Test Location Definition Migration", systemImage: "testtube.2")
                }
                .disabled(isGenerating)
                .accessibilityIdentifier("test_data_location_def_migration")
            } header: {
                Text("Data Migration")
            } footer: {
                Text("StorageLocation migration converts Inventory.location strings to StorageLocation records. Location Definition migration creates autocomplete entries for locations.")
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

    private func generateInventoryItems(count: Int) {
        guard !isGenerating else { return }

        isGenerating = true
        lastGeneratedMessage = ""

        Task {
            let startTime = Date()
            print("🔧 [TestData] Starting inventory generation at \(startTime)")

            do {
                // Get all available glass items from catalog
                let catalogStartTime = Date()
                let allItems = try await catalogService.getAllGlassItems()

                // Filter to only glass items (exclude coatings and tools)
                let glassItems = allItems.filter { $0.catalogItem.itemType == .glass }

                let catalogDuration = Date().timeIntervalSince(catalogStartTime)
                print("🔧 [TestData] Loaded \(glassItems.count) glass items (\(allItems.count) total catalog items) in \(String(format: "%.2f", catalogDuration))s")

                guard !glassItems.isEmpty else {
                    throw TestDataError.noCatalogItems
                }

                // Generate random inventory items
                var createdCount = 0
                let types = ["rod", "tube", "frit", "sheet", "stringer"]
                let locations = ["Studio", "Storage Room", "Shelf A", "Drawer B", "Cabinet 1", ""]

                // Date range: last 30 days
                let now = Date()
                let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now)!

                for i in 0..<count {
                    let itemStartTime = Date()

                    // Pick a random glass item
                    guard let randomItem = glassItems.randomElement() else { continue }

                    // Random quantity between 1 and 50 (whole numbers only)
                    let quantity = Double(Int.random(in: 1...50))

                    // Random type
                    guard let type = types.randomElement() else { continue }

                    // Random location (sometimes nil for unlocated inventory)
                    let location = locations.randomElement()
                    let finalLocation = location == "" ? nil : location

                    // Random date within the last 30 days
                    let randomTimeInterval = TimeInterval.random(in: 0...now.timeIntervalSince(thirtyDaysAgo))
                    let randomDate = thirtyDaysAgo.addingTimeInterval(randomTimeInterval)

                    print("🔧 [TestData] Generating item with randomDate: \(randomDate)")

                    // Add inventory with optional location and random date
                    _ = try await inventoryTrackingService.addInventory(
                        quantity: quantity,
                        type: type,
                        toItem: randomItem.glassItem.stable_id,
                        atLocation: finalLocation,
                        dateAdded: randomDate
                    )

                    createdCount += 1
                    let itemDuration = Date().timeIntervalSince(itemStartTime)
                    print("🔧 [TestData] Item \(i+1)/\(count): Created inventory for '\(randomItem.glassItem.name)' in \(String(format: "%.3f", itemDuration))s")
                }

                let totalDuration = Date().timeIntervalSince(startTime)
                print("🔧 [TestData] ✅ Completed: Created \(createdCount) items in \(String(format: "%.2f", totalDuration))s (avg: \(String(format: "%.3f", totalDuration / Double(createdCount)))s per item)")

                // Reload the cache so data is ready when user navigates to Inventory
                await CatalogDataCache.shared.reload(catalogService: catalogService)

                await MainActor.run {
                    isGenerating = false
                    lastGeneratedMessage = "✅ Added \(createdCount) inventory items in \(String(format: "%.1f", totalDuration))s"
                    showingSuccess = true

                    // Post notification to refresh InventoryView (if it's currently visible)
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

    private func runStorageLocationMigration() {
        guard !isGenerating else { return }

        isGenerating = true
        lastGeneratedMessage = ""

        Task {
            let startTime = Date()
            print("🔧 [TestData] Starting StorageLocation migration...")

            // Force run the migration (resets the "completed" flag first)
            await AppDependencies.shared.storageLocationMigrationService.forceRunMigration()

            let duration = Date().timeIntervalSince(startTime)
            print("🔧 [TestData] ✅ Migration completed in \(String(format: "%.2f", duration))s")

            // Reload the cache so data is ready
            await CatalogDataCache.shared.reload(catalogService: catalogService)

            await MainActor.run {
                isGenerating = false
                lastGeneratedMessage = "✅ StorageLocation migration completed in \(String(format: "%.1f", duration))s"

                // Post notification to refresh InventoryView
                NotificationCenter.default.post(name: .inventoryItemAdded, object: nil)
            }
        }
    }

    /// Test the LocationDefinitionMigration by:
    /// 1. Creating inventory with locations directly (bypassing service layer)
    /// 2. Clearing the migration flag
    /// 3. Running the migration
    /// 4. Verifying definitions were created
    private func testLocationDefinitionMigration() {
        guard !isGenerating else { return }

        isGenerating = true
        lastGeneratedMessage = ""

        Task {
            let startTime = Date()
            print("🔧 [TestData] Starting LocationDefinitionMigration test...")

            do {
                let deps = AppDependencies.shared
                let inventoryRepo = deps.inventoryRepository
                let locationDefRepo = deps.storageLocationDefinitionRepository

                // Get a test item
                let testItems = try await catalogService.getGlassItemsLightweight()
                guard let testItem = testItems.first else {
                    throw TestDataError.noCatalogItems
                }

                // Step 1: Create inventory with unique test locations DIRECTLY via repository
                // (bypassing InventoryTrackingService which would create definitions)
                let testLocations = ["MigrationTest-A", "MigrationTest-B", "MigrationTest-C"]
                var createdInventory: [InventoryModel] = []

                for location in testLocations {
                    let inventory = InventoryModel(
                        item_stable_id: testItem.stable_id,
                        type: "rod",
                        quantity: 1,
                        location: location
                    )
                    let created = try await inventoryRepo.createInventory(inventory)
                    createdInventory.append(created)
                    print("🔧 [TestData] Created inventory with location: \(location)")
                }

                // Step 2: Verify definitions DON'T exist yet
                let beforeDefs = try await locationDefRepo.fetchAll()
                let beforeNames = Set(beforeDefs.map { $0.name })
                let missingBefore = testLocations.filter { !beforeNames.contains($0) }
                print("🔧 [TestData] Definitions missing before migration: \(missingBefore)")

                // Step 3: Clear migration flag and run migration
                print("🔧 [TestData] Running LocationDefinitionMigration.forceRun()...")
                await deps.locationDefinitionMigration.forceRun()

                // Step 4: Verify definitions now exist
                let afterDefs = try await locationDefRepo.fetchAll()
                let afterNames = Set(afterDefs.map { $0.name })
                let createdDefs = testLocations.filter { afterNames.contains($0) }
                let stillMissing = testLocations.filter { !afterNames.contains($0) }

                // Step 5: Clean up test inventory
                for inventory in createdInventory {
                    try await inventoryRepo.deleteInventory(id: inventory.id)
                }
                print("🔧 [TestData] Cleaned up test inventory")

                // Step 6: Clean up test definitions
                for defName in testLocations {
                    if let def = afterDefs.first(where: { $0.name == defName }) {
                        try await locationDefRepo.softDelete(id: def.id)
                    }
                }
                print("🔧 [TestData] Cleaned up test definitions")

                let duration = Date().timeIntervalSince(startTime)

                let resultMessage: String
                if stillMissing.isEmpty {
                    resultMessage = "✅ Migration test PASSED: Created \(createdDefs.count) definitions in \(String(format: "%.1f", duration))s"
                    print("🔧 [TestData] \(resultMessage)")
                } else {
                    resultMessage = "❌ Migration test FAILED: Missing definitions for: \(stillMissing.joined(separator: ", "))"
                    print("🔧 [TestData] \(resultMessage)")
                }

                await MainActor.run {
                    isGenerating = false
                    lastGeneratedMessage = resultMessage
                }

            } catch {
                let duration = Date().timeIntervalSince(startTime)
                print("🔧 [TestData] ❌ Migration test failed after \(String(format: "%.2f", duration))s: \(error)")

                await MainActor.run {
                    isGenerating = false
                    errorState.show(error: error, context: "Failed to test location definition migration")
                }
            }
        }
    }

    private func generateShoppingItems(count: Int) {
        guard !isGenerating else { return }

        isGenerating = true
        lastGeneratedMessage = ""

        Task {
            do {
                // Get all available glass items from catalog
                let allItems = try await catalogService.getAllGlassItems()

                // Filter to only glass items (exclude coatings and tools)
                let glassItems = allItems.filter { $0.catalogItem.itemType == .glass }

                guard !glassItems.isEmpty else {
                    throw TestDataError.noCatalogItems
                }

                // Generate random shopping list items
                var createdCount = 0
                let stores = ["Frantz", "Hot Glass Color", "Mountain Glass"]
                let types = ["rod", "tube", "frit", "sheet"]

                for _ in 0..<count {
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
                        item_stable_id: randomItem.glassItem.stable_id,
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

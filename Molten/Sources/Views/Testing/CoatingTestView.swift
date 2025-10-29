//
//  CoatingTestView.swift
//  Molten
//
//  Created by Assistant on 10/29/25.
//  Test view for experimenting with coating data display
//

import SwiftUI
import CoreData

/// Simple test view to load and display coating products
struct CoatingTestView: View {
    @State private var coatings: [CoatingItemModel] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var loadedCount = 0

    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    VStack {
                        ProgressView()
                        Text("Loading coatings...")
                            .foregroundColor(.secondary)
                    }
                } else if let error = errorMessage {
                    VStack {
                        Text("Error")
                            .font(.headline)
                        Text(error)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()

                        Button("Retry") {
                            loadCoatings()
                        }
                        .buttonStyle(.bordered)
                    }
                } else if coatings.isEmpty {
                    VStack {
                        Text("No coatings loaded")
                            .foregroundColor(.secondary)

                        Button("Load Coatings") {
                            loadCoatings()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        Section {
                            Text("\(coatings.count) coatings loaded from database")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        ForEach(groupedCoatings.keys.sorted(), id: \.self) { manufacturer in
                            Section(header: Text(manufacturerName(manufacturer))) {
                                ForEach(groupedCoatings[manufacturer] ?? []) { coating in
                                    CoatingRowView(coating: coating)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Coating Test")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Load From JSON") {
                        loadCoatingsFromJSON()
                    }
                }
            }
        }
        .onAppear {
            loadCoatings()
        }
    }

    // Group coatings by manufacturer
    private var groupedCoatings: [String: [CoatingItemModel]] {
        Dictionary(grouping: coatings) { $0.manufacturer }
    }

    private func manufacturerName(_ code: String) -> String {
        switch code {
        case "JET": return "Jet Age Studio"
        case "THMP": return "Thompson Enamel"
        default: return code
        }
    }

    // Load coatings from Core Data
    private func loadCoatings() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                // Get persistent container from view context
                guard let container = viewContext.persistentStoreCoordinator?.persistentStores.first?.url.flatMap({ url in
                    // Access the container through the coordinator
                    viewContext.persistentStoreCoordinator?.value(forKey: "container") as? NSPersistentContainer
                }) else {
                    throw NSError(domain: "CoatingTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not access persistent container"])
                }

                // Create repository
                let repository = CoreDataCoatingItemRepository(persistentContainer: container)

                // Fetch all coatings
                let loadedCoatings = try await repository.fetchItems(matching: nil)

                await MainActor.run {
                    self.coatings = loadedCoatings
                    self.loadedCount = loadedCoatings.count
                    self.isLoading = false
                }

            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load coatings: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    // Load coatings from JSON and import to Core Data
    private func loadCoatingsFromJSON() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                // Load JSON data
                let jsonLoader = JSONDataLoader()
                let jsonData = try jsonLoader.findCatalogJSONData(catalogType: "coating")
                let catalogItems = try jsonLoader.decodeCatalogItems(from: jsonData, catalogType: "coating")

                print("Loaded \(catalogItems.count) coating items from JSON")

                // Get persistent container
                guard let container = viewContext.persistentStoreCoordinator?.persistentStores.first?.url.flatMap({ url in
                    viewContext.persistentStoreCoordinator?.value(forKey: "container") as? NSPersistentContainer
                }) else {
                    throw NSError(domain: "CoatingTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not access persistent container"])
                }

                // Create repository
                let repository = CoreDataCoatingItemRepository(persistentContainer: container)

                // Convert CatalogItemData to CoatingItemModel
                let coatingModels = catalogItems.compactMap { item -> CoatingItemModel? in
                    guard let stableId = item.stable_id, !stableId.isEmpty else {
                        print("Warning: Skipping item with missing stable_id: \(item.name)")
                        return nil
                    }

                    return CoatingItemModel(
                        stable_id: stableId,
                        name: item.name,
                        sku: item.code,
                        manufacturer: item.manufacturer ?? "Unknown",
                        mfr_notes: item.manufacturer_description,
                        url: item.manufacturer_url,
                        mfr_status: "available",
                        image_url: item.image_url,
                        image_path: item.image_path
                    )
                }

                print("Converted \(coatingModels.count) items to CoatingItemModel")

                // Import to Core Data
                _ = try await repository.createItems(coatingModels)

                print("Imported \(coatingModels.count) coatings to Core Data")

                // Reload from Core Data
                let loadedCoatings = try await repository.fetchItems(matching: nil)

                await MainActor.run {
                    self.coatings = loadedCoatings
                    self.loadedCount = loadedCoatings.count
                    self.isLoading = false
                }

            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load from JSON: \(error.localizedDescription)"
                    self.isLoading = false
                }
                print("Error loading coatings: \(error)")
            }
        }
    }
}

/// Row view for a single coating
struct CoatingRowView: View {
    let coating: CoatingItemModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(coating.name)
                .font(.headline)

            if let sku = coating.sku, !sku.isEmpty {
                Text("SKU: \(sku)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let notes = coating.mfr_notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    CoatingTestView()
}

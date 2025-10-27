//
//  CoreDataStoreRepository.swift
//  Flameworker
//
//  Created for Store Feature on 10/26/25.
//

@preconcurrency import CoreData
import Foundation
import CoreLocation
import OSLog

/// Core Data implementation of StoreRepository
/// Provides persistent storage for store information using Core Data
class CoreDataStoreRepository: @unchecked Sendable, StoreRepository {

    // MARK: - Dependencies

    private let persistentContainer: NSPersistentContainer
    private let backgroundContext: NSManagedObjectContext
    private let log = Logger(subsystem: "com.flameworker.app", category: "store-repository")

    // MARK: - Initialization

    /// Initialize CoreDataStoreRepository with a Core Data persistent container
    /// - Parameter persistentContainer: The NSPersistentContainer to use for store operations
    /// - Note: In production, pass PersistenceController.shared.container
    nonisolated init(storePersistentContainer persistentContainer: NSPersistentContainer) {
        self.persistentContainer = persistentContainer
        self.backgroundContext = persistentContainer.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
    }

    // MARK: - Basic CRUD Operations

    func fetchAllStores() async throws -> [StoreModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[StoreModel], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Store")
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let stores = coreDataItems.compactMap { self.convertToStoreModel($0) }

                    continuation.resume(returning: stores)

                } catch {
                    self.log.error("Failed to fetch all stores: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchStore(byId stable_id: String) async throws -> StoreModel? {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<StoreModel?, Error>) in
            backgroundContext.perform {
                do {
                    let result = try self.fetchStoreSync(byId: stable_id)
                    continuation.resume(returning: result)
                } catch {
                    self.log.error("Failed to fetch store: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @preconcurrency func fetchStores(matching predicate: NSPredicate?) async throws -> [StoreModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[StoreModel], Error>) in
            nonisolated(unsafe) let predicateCopy = predicate
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Store")
                    fetchRequest.predicate = predicateCopy
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let stores = coreDataItems.compactMap { self.convertToStoreModel($0) }

                    continuation.resume(returning: stores)

                } catch {
                    self.log.error("Failed to fetch stores with predicate: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func createStore(_ store: StoreModel) async throws -> StoreModel {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<StoreModel, Error>) in
            backgroundContext.perform {
                do {
                    // Validate store
                    guard store.isValid else {
                        throw CoreDataStoreRepositoryError.invalidData(store.validationErrors.joined(separator: ", "))
                    }

                    // Check if store already exists
                    if try self.fetchStoreSync(byId: store.stable_id) != nil {
                        throw CoreDataStoreRepositoryError.storeAlreadyExists(store.stable_id)
                    }

                    // Create new Core Data entity
                    guard let entity = NSEntityDescription.entity(forEntityName: "Store", in: self.backgroundContext) else {
                        throw CoreDataStoreRepositoryError.entityNotFound("Store")
                    }
                    let coreDataItem = NSManagedObject(entity: entity, insertInto: self.backgroundContext)

                    // Set properties
                    self.updateCoreDataItem(coreDataItem, with: store)

                    // Save context
                    try self.backgroundContext.save()

                    self.log.info("Created store: \(store.name)")
                    continuation.resume(returning: store)

                } catch {
                    self.log.error("Failed to create store: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func createStores(_ stores: [StoreModel]) async throws -> [StoreModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[StoreModel], Error>) in
            backgroundContext.perform {
                do {
                    var createdStores: [StoreModel] = []

                    for store in stores {
                        // Validate store
                        guard store.isValid else {
                            throw CoreDataStoreRepositoryError.invalidData(store.validationErrors.joined(separator: ", "))
                        }

                        // Skip if store already exists
                        if try self.fetchStoreSync(byId: store.stable_id) != nil {
                            self.log.warning("Store already exists, skipping: \(store.stable_id)")
                            continue
                        }

                        // Create new Core Data entity
                        guard let entity = NSEntityDescription.entity(forEntityName: "Store", in: self.backgroundContext) else {
                            throw CoreDataStoreRepositoryError.entityNotFound("Store")
                        }
                        let coreDataItem = NSManagedObject(entity: entity, insertInto: self.backgroundContext)

                        // Set properties
                        self.updateCoreDataItem(coreDataItem, with: store)
                        createdStores.append(store)
                    }

                    // Save context once for all stores
                    if !createdStores.isEmpty {
                        try self.backgroundContext.save()
                        self.log.info("Created \(createdStores.count) stores")
                    }

                    continuation.resume(returning: createdStores)

                } catch {
                    self.log.error("Failed to create stores: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func updateStore(_ store: StoreModel) async throws -> StoreModel {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<StoreModel, Error>) in
            backgroundContext.perform {
                do {
                    // Validate store
                    guard store.isValid else {
                        throw CoreDataStoreRepositoryError.invalidData(store.validationErrors.joined(separator: ", "))
                    }

                    // Find existing item
                    guard let coreDataItem = try self.fetchCoreDataItemSync(byId: store.stable_id) else {
                        self.log.warning("Attempted to update non-existent store: \(store.stable_id)")
                        throw CoreDataStoreRepositoryError.storeNotFound(store.stable_id)
                    }

                    // Update properties
                    self.updateCoreDataItem(coreDataItem, with: store)

                    // Save context
                    try self.backgroundContext.save()

                    self.log.info("Updated store: \(store.name)")
                    continuation.resume(returning: store)

                } catch {
                    self.log.error("Failed to update store: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteStore(_ store: StoreModel) async throws {
        try await deleteStore(byId: store.stable_id)
    }

    func deleteStore(byId stable_id: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    // Find existing item
                    guard let coreDataItem = try self.fetchCoreDataItemSync(byId: stable_id) else {
                        self.log.warning("Attempted to delete non-existent store: \(stable_id)")
                        // Not throwing error - idempotent delete
                        continuation.resume()
                        return
                    }

                    // Delete item
                    self.backgroundContext.delete(coreDataItem)

                    // Save context
                    try self.backgroundContext.save()

                    self.log.info("Deleted store: \(stable_id)")
                    continuation.resume()

                } catch {
                    self.log.error("Failed to delete store: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteAllStores() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Store")
                    let allStores = try self.backgroundContext.fetch(fetchRequest)

                    for store in allStores {
                        self.backgroundContext.delete(store)
                    }

                    if !allStores.isEmpty {
                        try self.backgroundContext.save()
                    }

                    self.log.info("Deleted all \(allStores.count) stores")
                    continuation.resume()

                } catch {
                    self.log.error("Failed to delete all stores: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Query Operations

    func searchStores(matching searchText: String) async throws -> [StoreModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[StoreModel], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Store")
                    fetchRequest.predicate = NSPredicate(
                        format: "name CONTAINS[cd] %@ OR address_line1 CONTAINS[cd] %@ OR city CONTAINS[cd] %@ OR notes CONTAINS[cd] %@",
                        searchText, searchText, searchText, searchText
                    )
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let stores = coreDataItems.compactMap { self.convertToStoreModel($0) }

                    self.log.debug("Found \(stores.count) stores matching search text")
                    continuation.resume(returning: stores)

                } catch {
                    self.log.error("Failed to search stores: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchStores(inCity city: String) async throws -> [StoreModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[StoreModel], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Store")
                    fetchRequest.predicate = NSPredicate(format: "city ==[cd] %@", city)
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let stores = coreDataItems.compactMap { self.convertToStoreModel($0) }

                    continuation.resume(returning: stores)

                } catch {
                    self.log.error("Failed to fetch stores in city: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchStores(inState state: String) async throws -> [StoreModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[StoreModel], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Store")
                    fetchRequest.predicate = NSPredicate(format: "state ==[cd] %@", state)
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let stores = coreDataItems.compactMap { self.convertToStoreModel($0) }

                    continuation.resume(returning: stores)

                } catch {
                    self.log.error("Failed to fetch stores in state: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchStores(near coordinate: CLLocationCoordinate2D, radiusMeters: Double) async throws -> [StoreModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[StoreModel], Error>) in
            backgroundContext.perform {
                do {
                    // Fetch all stores with valid locations
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Store")
                    fetchRequest.predicate = NSPredicate(format: "latitude != 0.0 AND longitude != 0.0")

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let allStores = coreDataItems.compactMap { self.convertToStoreModel($0) }

                    // Filter by distance in memory (Core Data doesn't have built-in distance queries)
                    let nearbyStores = allStores.filter { store in
                        guard let distance = store.distance(from: coordinate) else { return false }
                        return distance <= radiusMeters
                    }

                    // Sort by distance
                    let sortedStores = nearbyStores.sorted { store1, store2 in
                        let dist1 = store1.distance(from: coordinate) ?? Double.greatestFiniteMagnitude
                        let dist2 = store2.distance(from: coordinate) ?? Double.greatestFiniteMagnitude
                        return dist1 < dist2
                    }

                    continuation.resume(returning: sortedStores)

                } catch {
                    self.log.error("Failed to fetch nearby stores: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchVerifiedStores() async throws -> [StoreModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[StoreModel], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Store")
                    fetchRequest.predicate = NSPredicate(format: "is_verified == YES")
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let stores = coreDataItems.compactMap { self.convertToStoreModel($0) }

                    continuation.resume(returning: stores)

                } catch {
                    self.log.error("Failed to fetch verified stores: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchStoresWithLocation() async throws -> [StoreModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[StoreModel], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Store")
                    fetchRequest.predicate = NSPredicate(format: "latitude != 0.0 AND longitude != 0.0")
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let stores = coreDataItems.compactMap { self.convertToStoreModel($0) }

                    continuation.resume(returning: stores)

                } catch {
                    self.log.error("Failed to fetch stores with location: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Discovery Operations

    func getDistinctCities() async throws -> [String] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Store")
                    let stores = try self.backgroundContext.fetch(fetchRequest)

                    let cities = Set(stores.compactMap { $0.value(forKey: "city") as? String })
                    continuation.resume(returning: Array(cities).sorted())

                } catch {
                    self.log.error("Failed to get distinct cities: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getDistinctStates() async throws -> [String] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Store")
                    let stores = try self.backgroundContext.fetch(fetchRequest)

                    let states = Set(stores.compactMap { $0.value(forKey: "state") as? String })
                    continuation.resume(returning: Array(states).sorted())

                } catch {
                    self.log.error("Failed to get distinct states: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getCities(withPrefix prefix: String) async throws -> [String] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Store")
                    fetchRequest.predicate = NSPredicate(format: "city BEGINSWITH[cd] %@", prefix)

                    let stores = try self.backgroundContext.fetch(fetchRequest)
                    let cities = Set(stores.compactMap { $0.value(forKey: "city") as? String })

                    continuation.resume(returning: Array(cities).sorted())

                } catch {
                    self.log.error("Failed to get cities with prefix: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getStates(withPrefix prefix: String) async throws -> [String] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Store")
                    fetchRequest.predicate = NSPredicate(format: "state BEGINSWITH[cd] %@", prefix)

                    let stores = try self.backgroundContext.fetch(fetchRequest)
                    let states = Set(stores.compactMap { $0.value(forKey: "state") as? String })

                    continuation.resume(returning: Array(states).sorted())

                } catch {
                    self.log.error("Failed to get states with prefix: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getStoreCountByState() async throws -> [String: Int] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String: Int], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Store")
                    let stores = try self.backgroundContext.fetch(fetchRequest)

                    let stateGroups = Dictionary(grouping: stores) { store in
                        (store.value(forKey: "state") as? String) ?? "Unknown"
                    }
                    let stateCounts = stateGroups.mapValues { $0.count }

                    continuation.resume(returning: stateCounts)

                } catch {
                    self.log.error("Failed to get store count by state: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getStoreCountByCity() async throws -> [String: Int] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String: Int], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Store")
                    let stores = try self.backgroundContext.fetch(fetchRequest)

                    let cityGroups = Dictionary(grouping: stores) { store in
                        (store.value(forKey: "city") as? String) ?? "Unknown"
                    }
                    let cityCounts = cityGroups.mapValues { $0.count }

                    continuation.resume(returning: cityCounts)

                } catch {
                    self.log.error("Failed to get store count by city: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Bulk Operations

    func loadStoresFromJSON(_ data: Data) async throws -> Int {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int, Error>) in
            backgroundContext.perform {
                do {
                    let decoder = JSONDecoder()
                    let wrappedData = try decoder.decode(WrappedStoresData.self, from: data)

                    // Get list of stable_ids from JSON
                    let jsonStableIds = Set(wrappedData.stores.map { $0.stable_id })

                    // Delete stores that aren't in the JSON (cleanup old data)
                    let allStoresFetch = NSFetchRequest<NSManagedObject>(entityName: "Store")
                    let existingStores = try self.backgroundContext.fetch(allStoresFetch)

                    var deletedCount = 0
                    for existingStore in existingStores {
                        if let stableId = existingStore.value(forKey: "stable_id") as? String {
                            if !jsonStableIds.contains(stableId) {
                                // Store not in JSON - delete it
                                self.log.debug("Deleting store not in JSON: \(stableId)")
                                self.backgroundContext.delete(existingStore)
                                deletedCount += 1
                            }
                        }
                    }

                    if deletedCount > 0 {
                        self.log.info("Deleted \(deletedCount) stores not in JSON")
                    }

                    var loadedCount = 0

                    for storeData in wrappedData.stores {
                        let store = storeData.toModel()

                        // Check if store already exists
                        if let existingItem = try self.fetchCoreDataItemSync(byId: store.stable_id) {
                            // UPDATE existing store (web data takes precedence)
                            self.log.debug("Updating existing store from JSON: \(store.stable_id)")
                            self.updateCoreDataItem(existingItem, with: store)
                            loadedCount += 1
                        } else {
                            // CREATE new Core Data entity
                            guard let entity = NSEntityDescription.entity(forEntityName: "Store", in: self.backgroundContext) else {
                                throw CoreDataStoreRepositoryError.entityNotFound("Store")
                            }
                            let coreDataItem = NSManagedObject(entity: entity, insertInto: self.backgroundContext)

                            // Set properties
                            self.log.debug("Adding new store from JSON: \(store.stable_id)")
                            self.updateCoreDataItem(coreDataItem, with: store)
                            loadedCount += 1
                        }
                    }

                    // Save context once for all stores
                    if loadedCount > 0 {
                        try self.backgroundContext.save()
                        self.log.info("Loaded \(loadedCount) stores from JSON")
                    }

                    continuation.resume(returning: loadedCount)

                } catch {
                    self.log.error("Failed to load stores from JSON: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func loadStoresFromJSONFile(at fileURL: URL) async throws -> Int {
        let data = try Data(contentsOf: fileURL)
        return try await loadStoresFromJSON(data)
    }

    func exportStoresToJSON() async throws -> Data {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Store")
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let stores = coreDataItems.compactMap { self.convertToStoreModel($0) }
                    let storeDataArray = stores.map { $0.toData() }

                    let metadata = StoreMetadata(
                        version: "1.0",
                        generated: ISO8601DateFormatter().string(from: Date()),
                        storeCount: storeDataArray.count
                    )

                    let wrapper = WrappedStoresData(metadata: metadata, stores: storeDataArray)

                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    let data = try encoder.encode(wrapper)

                    continuation.resume(returning: data)

                } catch {
                    self.log.error("Failed to export stores to JSON: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func storeExists(withId stable_id: String) async throws -> Bool {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            backgroundContext.perform {
                do {
                    let exists = try self.fetchStoreSync(byId: stable_id) != nil
                    continuation.resume(returning: exists)
                } catch {
                    self.log.error("Failed to check if store exists: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Statistics Operations

    func getStoreCount() async throws -> Int {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int, Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Store")
                    let count = try self.backgroundContext.count(for: fetchRequest)

                    continuation.resume(returning: count)

                } catch {
                    self.log.error("Failed to get store count: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getVerifiedStoreCount() async throws -> Int {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int, Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Store")
                    fetchRequest.predicate = NSPredicate(format: "is_verified == YES")
                    let count = try self.backgroundContext.count(for: fetchRequest)

                    continuation.resume(returning: count)

                } catch {
                    self.log.error("Failed to get verified store count: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getStoresWithLocationCount() async throws -> Int {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int, Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Store")
                    fetchRequest.predicate = NSPredicate(format: "latitude != 0.0 AND longitude != 0.0")
                    let count = try self.backgroundContext.count(for: fetchRequest)

                    continuation.resume(returning: count)

                } catch {
                    self.log.error("Failed to get stores with location count: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Helper Methods

    private nonisolated func fetchStoreSync(byId stable_id: String) throws -> StoreModel? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Store")
        fetchRequest.predicate = NSPredicate(format: "stable_id == %@", stable_id)
        fetchRequest.fetchLimit = 1

        let results = try backgroundContext.fetch(fetchRequest)
        return results.first.flatMap { convertToStoreModel($0) }
    }

    private nonisolated func fetchCoreDataItemSync(byId stable_id: String) throws -> NSManagedObject? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Store")
        fetchRequest.predicate = NSPredicate(format: "stable_id == %@", stable_id)
        fetchRequest.fetchLimit = 1

        let results = try backgroundContext.fetch(fetchRequest)
        return results.first
    }

    private nonisolated func updateCoreDataItem(_ coreDataItem: NSManagedObject, with store: StoreModel) {
        coreDataItem.setValue(store.stable_id, forKey: "stable_id")
        coreDataItem.setValue(store.name, forKey: "name")
        coreDataItem.setValue(store.addressLine1, forKey: "address_line1")
        coreDataItem.setValue(store.addressLine2, forKey: "address_line2")
        coreDataItem.setValue(store.city, forKey: "city")
        coreDataItem.setValue(store.state, forKey: "state")
        coreDataItem.setValue(store.zip, forKey: "zip")
        coreDataItem.setValue(store.latitude, forKey: "latitude")
        coreDataItem.setValue(store.longitude, forKey: "longitude")
        coreDataItem.setValue(store.websiteUrl, forKey: "website_url")
        coreDataItem.setValue(store.phone, forKey: "phone")
        coreDataItem.setValue(store.hoursJson, forKey: "hours_json")
        coreDataItem.setValue(store.heroImagePath, forKey: "hero_image_path")
        coreDataItem.setValue(store.notes, forKey: "notes")
        coreDataItem.setValue(store.isVerified, forKey: "is_verified")
    }

    private nonisolated func convertToStoreModel(_ coreDataItem: NSManagedObject) -> StoreModel? {
        guard let stable_id = coreDataItem.value(forKey: "stable_id") as? String,
              let name = coreDataItem.value(forKey: "name") as? String else {
            log.error("Failed to convert Core Data item to StoreModel - missing required properties")
            return nil
        }

        return StoreModel(
            stable_id: stable_id,
            name: name,
            addressLine1: coreDataItem.value(forKey: "address_line1") as? String,
            addressLine2: coreDataItem.value(forKey: "address_line2") as? String,
            city: coreDataItem.value(forKey: "city") as? String,
            state: coreDataItem.value(forKey: "state") as? String,
            zip: coreDataItem.value(forKey: "zip") as? String,
            latitude: (coreDataItem.value(forKey: "latitude") as? Double) ?? 0.0,
            longitude: (coreDataItem.value(forKey: "longitude") as? Double) ?? 0.0,
            websiteUrl: coreDataItem.value(forKey: "website_url") as? String,
            phone: coreDataItem.value(forKey: "phone") as? String,
            hoursJson: coreDataItem.value(forKey: "hours_json") as? String,
            heroImagePath: coreDataItem.value(forKey: "hero_image_path") as? String,
            notes: coreDataItem.value(forKey: "notes") as? String,
            isVerified: (coreDataItem.value(forKey: "is_verified") as? Bool) ?? false
        )
    }
}

// MARK: - Core Data Repository Errors

enum CoreDataStoreRepositoryError: Error, LocalizedError {
    case entityNotFound(String)
    case storeNotFound(String)
    case storeAlreadyExists(String)
    case invalidData(String)

    var errorDescription: String? {
        switch self {
        case .entityNotFound(let entityName):
            return "Core Data entity not found: \(entityName)"
        case .storeNotFound(let stableId):
            return "Store not found: \(stableId)"
        case .storeAlreadyExists(let stableId):
            return "Store already exists: \(stableId)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        }
    }
}

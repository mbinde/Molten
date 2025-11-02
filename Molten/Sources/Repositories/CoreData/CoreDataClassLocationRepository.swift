//
//  CoreDataClassLocationRepository.swift
//  Flameworker
//
//  Created for ClassLocation Feature on 10/26/25.
//

@preconcurrency import CoreData
import Foundation
import CoreLocation
import OSLog

/// Core Data implementation of ClassLocationRepository
/// Provides persistent storage for class location information using Core Data
class CoreDataClassLocationRepository: @unchecked Sendable, ClassLocationRepository {

    // MARK: - Dependencies

    private let context: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext
    private let log = Logger(subsystem: "com.flameworker.app", category: "classlocation-repository")

    // MARK: - Initialization

    /// Initialize CoreDataClassLocationRepository with a Core Data context
    /// - Parameter context: The NSManagedObjectContext to use for class location operations
    /// - Note: In production, pass PersistenceController.shared.cloudContext
    nonisolated init(context: NSManagedObjectContext) {
        self.context = context
        self.context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        self.backgroundContext = context
        self.backgroundContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
    }

    // MARK: - Basic CRUD Operations

    func fetchAllClassLocations() async throws -> [ClassLocationModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[ClassLocationModel], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ClassLocation")
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let classLocations = coreDataItems.compactMap { self.convertToClassLocationModel($0) }

                    continuation.resume(returning: classLocations)

                } catch {
                    self.log.error("Failed to fetch all classLocations: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchClassLocation(byId stable_id: String) async throws -> ClassLocationModel? {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ClassLocationModel?, Error>) in
            backgroundContext.perform {
                do {
                    let result = try self.fetchClassLocationSync(byId: stable_id)
                    continuation.resume(returning: result)
                } catch {
                    self.log.error("Failed to fetch class location: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @preconcurrency func fetchClassLocations(matching predicate: NSPredicate?) async throws -> [ClassLocationModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[ClassLocationModel], Error>) in
            nonisolated(unsafe) let predicateCopy = predicate
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ClassLocation")
                    fetchRequest.predicate = predicateCopy
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let classLocations = coreDataItems.compactMap { self.convertToClassLocationModel($0) }

                    continuation.resume(returning: classLocations)

                } catch {
                    self.log.error("Failed to fetch classLocations with predicate: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func createClassLocation(_ class location: ClassLocationModel) async throws -> ClassLocationModel {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ClassLocationModel, Error>) in
            backgroundContext.perform {
                do {
                    // Validate class location
                    guard class location.isValid else {
                        throw CoreDataClassLocationRepositoryError.invalidData(store.validationErrors.joined(separator: ", "))
                    }

                    // Check if class location already exists
                    if try self.fetchClassLocationSync(byId: class location.stable_id) != nil {
                        throw CoreDataClassLocationRepositoryError.classLocationAlreadyExists(store.stable_id)
                    }

                    // Create new Core Data entity
                    guard let entity = NSEntityDescription.entity(forEntityName: "ClassLocation", in: self.backgroundContext) else {
                        throw CoreDataClassLocationRepositoryError.entityNotFound("ClassLocation")
                    }
                    let coreDataItem = NSManagedObject(entity: entity, insertInto: self.backgroundContext)

                    // Set properties
                    self.updateCoreDataItem(coreDataItem, with: class location)

                    // Save context
                    try self.backgroundContext.save()

                    self.log.info("Created class location: \(store.name)")
                    continuation.resume(returning: class location)

                } catch {
                    self.log.error("Failed to create class location: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func createClassLocations(_ classLocations: [ClassLocationModel]) async throws -> [ClassLocationModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[ClassLocationModel], Error>) in
            backgroundContext.perform {
                do {
                    var createdStores: [ClassLocationModel] = []

                    for class location in classLocations {
                        // Validate class location
                        guard class location.isValid else {
                            throw CoreDataClassLocationRepositoryError.invalidData(store.validationErrors.joined(separator: ", "))
                        }

                        // Skip if class location already exists
                        if try self.fetchClassLocationSync(byId: class location.stable_id) != nil {
                            self.log.warning("ClassLocation already exists, skipping: \(store.stable_id)")
                            continue
                        }

                        // Create new Core Data entity
                        guard let entity = NSEntityDescription.entity(forEntityName: "ClassLocation", in: self.backgroundContext) else {
                            throw CoreDataClassLocationRepositoryError.entityNotFound("ClassLocation")
                        }
                        let coreDataItem = NSManagedObject(entity: entity, insertInto: self.backgroundContext)

                        // Set properties
                        self.updateCoreDataItem(coreDataItem, with: class location)
                        createdStores.append(store)
                    }

                    // Save context once for all classLocations
                    if !createdStores.isEmpty {
                        try self.backgroundContext.save()
                        self.log.info("Created \(createdStores.count) classLocations")
                    }

                    continuation.resume(returning: createdStores)

                } catch {
                    self.log.error("Failed to create classLocations: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func updateClassLocation(_ class location: ClassLocationModel) async throws -> ClassLocationModel {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ClassLocationModel, Error>) in
            backgroundContext.perform {
                do {
                    // Validate class location
                    guard class location.isValid else {
                        throw CoreDataClassLocationRepositoryError.invalidData(store.validationErrors.joined(separator: ", "))
                    }

                    // Find existing item
                    guard let coreDataItem = try self.fetchCoreDataItemSync(byId: class location.stable_id) else {
                        self.log.warning("Attempted to update non-existent class location: \(store.stable_id)")
                        throw CoreDataClassLocationRepositoryError.classLocationNotFound(store.stable_id)
                    }

                    // Update properties
                    self.updateCoreDataItem(coreDataItem, with: class location)

                    // Save context
                    try self.backgroundContext.save()

                    self.log.info("Updated class location: \(store.name)")
                    continuation.resume(returning: class location)

                } catch {
                    self.log.error("Failed to update class location: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteClassLocation(_ class location: ClassLocationModel) async throws {
        try await deleteClassLocation(byId: class location.stable_id)
    }

    func deleteClassLocation(byId stable_id: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    // Find existing item
                    guard let coreDataItem = try self.fetchCoreDataItemSync(byId: stable_id) else {
                        self.log.warning("Attempted to delete non-existent class location: \(stable_id)")
                        // Not throwing error - idempotent delete
                        continuation.resume()
                        return
                    }

                    // Delete item
                    self.backgroundContext.delete(coreDataItem)

                    // Save context
                    try self.backgroundContext.save()

                    self.log.info("Deleted class location: \(stable_id)")
                    continuation.resume()

                } catch {
                    self.log.error("Failed to delete class location: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteAllClassLocations() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ClassLocation")
                    let allStores = try self.backgroundContext.fetch(fetchRequest)

                    for class location in allStores {
                        self.backgroundContext.delete(store)
                    }

                    if !allStores.isEmpty {
                        try self.backgroundContext.save()
                    }

                    self.log.info("Deleted all \(allStores.count) classLocations")
                    continuation.resume()

                } catch {
                    self.log.error("Failed to delete all classLocations: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Query Operations

    func searchClassLocations(matching searchText: String) async throws -> [ClassLocationModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[ClassLocationModel], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ClassLocation")
                    fetchRequest.predicate = NSPredicate(
                        format: "name CONTAINS[cd] %@ OR address_line1 CONTAINS[cd] %@ OR city CONTAINS[cd] %@ OR notes CONTAINS[cd] %@",
                        searchText, searchText, searchText, searchText
                    )
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let classLocations = coreDataItems.compactMap { self.convertToClassLocationModel($0) }

                    self.log.debug("Found \(stores.count) classLocations matching search text")
                    continuation.resume(returning: classLocations)

                } catch {
                    self.log.error("Failed to search classLocations: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchClassLocations(inCity city: String) async throws -> [ClassLocationModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[ClassLocationModel], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ClassLocation")
                    fetchRequest.predicate = NSPredicate(format: "city ==[cd] %@", city)
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let classLocations = coreDataItems.compactMap { self.convertToClassLocationModel($0) }

                    continuation.resume(returning: classLocations)

                } catch {
                    self.log.error("Failed to fetch classLocations in city: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchClassLocations(inState state: String) async throws -> [ClassLocationModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[ClassLocationModel], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ClassLocation")
                    fetchRequest.predicate = NSPredicate(format: "state ==[cd] %@", state)
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let classLocations = coreDataItems.compactMap { self.convertToClassLocationModel($0) }

                    continuation.resume(returning: classLocations)

                } catch {
                    self.log.error("Failed to fetch classLocations in state: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchClassLocations(near coordinate: CLLocationCoordinate2D, radiusMeters: Double) async throws -> [ClassLocationModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[ClassLocationModel], Error>) in
            backgroundContext.perform {
                do {
                    // Fetch all classLocations with valid locations
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ClassLocation")
                    fetchRequest.predicate = NSPredicate(format: "latitude != 0.0 AND longitude != 0.0")

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let allStores = coreDataItems.compactMap { self.convertToClassLocationModel($0) }

                    // Filter by distance in memory (Core Data doesn't have built-in distance queries)
                    let nearbyStores = allStores.filter { class location in
                        guard let distance = class location.distance(from: coordinate) else { return false }
                        return distance <= radiusMeters
                    }

                    // Sort by distance
                    let sortedStores = nearbyStores.sorted { class location1, class location2 in
                        let dist1 = class location1.distance(from: coordinate) ?? Double.greatestFiniteMagnitude
                        let dist2 = class location2.distance(from: coordinate) ?? Double.greatestFiniteMagnitude
                        return dist1 < dist2
                    }

                    continuation.resume(returning: sortedStores)

                } catch {
                    self.log.error("Failed to fetch nearby classLocations: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchVerifiedClassLocations() async throws -> [ClassLocationModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[ClassLocationModel], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ClassLocation")
                    fetchRequest.predicate = NSPredicate(format: "is_verified == YES")
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let classLocations = coreDataItems.compactMap { self.convertToClassLocationModel($0) }

                    continuation.resume(returning: classLocations)

                } catch {
                    self.log.error("Failed to fetch verified classLocations: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchClassLocationsWithLocation() async throws -> [ClassLocationModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[ClassLocationModel], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ClassLocation")
                    fetchRequest.predicate = NSPredicate(format: "latitude != 0.0 AND longitude != 0.0")
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let classLocations = coreDataItems.compactMap { self.convertToClassLocationModel($0) }

                    continuation.resume(returning: classLocations)

                } catch {
                    self.log.error("Failed to fetch classLocations with location: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchClassLocations(supportingTechnique technique: TechniqueType) async throws -> [ClassLocationModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[ClassLocationModel], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ClassLocation")
                    let predicateKey = technique.coreDataKey
                    fetchRequest.predicate = NSPredicate(format: "\(predicateKey) == YES")
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let classLocations = coreDataItems.compactMap { self.convertToClassLocationModel($0) }

                    continuation.resume(returning: classLocations)

                } catch {
                    self.log.error("Failed to fetch classLocations supporting technique: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchClassLocations(supportingAnyOf techniques: [TechniqueType]) async throws -> [ClassLocationModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[ClassLocationModel], Error>) in
            backgroundContext.perform {
                do {
                    if techniques.isEmpty {
                        continuation.resume(returning: [])
                        return
                    }

                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ClassLocation")
                    let predicates = techniques.map { technique in
                        NSPredicate(format: "\(technique.coreDataKey) == YES")
                    }
                    fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let classLocations = coreDataItems.compactMap { self.convertToClassLocationModel($0) }

                    continuation.resume(returning: classLocations)

                } catch {
                    self.log.error("Failed to fetch classLocations supporting any techniques: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchClassLocations(supportingAllOf techniques: [TechniqueType]) async throws -> [ClassLocationModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[ClassLocationModel], Error>) in
            backgroundContext.perform {
                do {
                    if techniques.isEmpty {
                        continuation.resume(returning: [])
                        return
                    }

                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ClassLocation")
                    let predicates = techniques.map { technique in
                        NSPredicate(format: "\(technique.coreDataKey) == YES")
                    }
                    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let classLocations = coreDataItems.compactMap { self.convertToClassLocationModel($0) }

                    continuation.resume(returning: classLocations)

                } catch {
                    self.log.error("Failed to fetch classLocations supporting all techniques: \(error)")
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
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ClassLocation")
                    let classLocations = try self.backgroundContext.fetch(fetchRequest)

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
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ClassLocation")
                    let classLocations = try self.backgroundContext.fetch(fetchRequest)

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
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ClassLocation")
                    fetchRequest.predicate = NSPredicate(format: "city BEGINSWITH[cd] %@", prefix)

                    let classLocations = try self.backgroundContext.fetch(fetchRequest)
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
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ClassLocation")
                    fetchRequest.predicate = NSPredicate(format: "state BEGINSWITH[cd] %@", prefix)

                    let classLocations = try self.backgroundContext.fetch(fetchRequest)
                    let states = Set(stores.compactMap { $0.value(forKey: "state") as? String })

                    continuation.resume(returning: Array(states).sorted())

                } catch {
                    self.log.error("Failed to get states with prefix: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getClassLocationCountByState() async throws -> [String: Int] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String: Int], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ClassLocation")
                    let classLocations = try self.backgroundContext.fetch(fetchRequest)

                    let stateGroups = Dictionary(grouping: classLocations) { class location in
                        (store.value(forKey: "state") as? String) ?? "Unknown"
                    }
                    let stateCounts = stateGroups.mapValues { $0.count }

                    continuation.resume(returning: stateCounts)

                } catch {
                    self.log.error("Failed to get class location count by state: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getClassLocationCountByCity() async throws -> [String: Int] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String: Int], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ClassLocation")
                    let classLocations = try self.backgroundContext.fetch(fetchRequest)

                    let cityGroups = Dictionary(grouping: classLocations) { class location in
                        (store.value(forKey: "city") as? String) ?? "Unknown"
                    }
                    let cityCounts = cityGroups.mapValues { $0.count }

                    continuation.resume(returning: cityCounts)

                } catch {
                    self.log.error("Failed to get class location count by city: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Bulk Operations

    func loadClassLocationsFromJSON(_ data: Data) async throws -> Int {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int, Error>) in
            backgroundContext.perform {
                do {
                    let decoder = JSONDecoder()
                    let wrappedData = try decoder.decode(WrappedStoresData.self, from: data)

                    // Get list of stable_ids from JSON
                    let jsonStableIds = Set(wrappedData.stores.map { $0.stable_id })

                    // Delete classLocations that aren't in the JSON (cleanup old data)
                    let allStoresFetch = NSFetchRequest<NSManagedObject>(entityName: "ClassLocation")
                    let existingStores = try self.backgroundContext.fetch(allStoresFetch)

                    var deletedCount = 0
                    for existingStore in existingStores {
                        if let stableId = existingStore.value(forKey: "stable_id") as? String {
                            if !jsonStableIds.contains(stableId) {
                                // Store not in JSON - delete it
                                self.log.debug("Deleting class location not in JSON: \(stableId)")
                                self.backgroundContext.delete(existingStore)
                                deletedCount += 1
                            }
                        }
                    }

                    if deletedCount > 0 {
                        self.log.info("Deleted \(deletedCount) classLocations not in JSON")
                    }

                    var loadedCount = 0

                    for class locationData in wrappedData.stores {
                        let class location = class locationData.toModel()

                        // Check if class location already exists
                        if let existingItem = try self.fetchCoreDataItemSync(byId: class location.stable_id) {
                            // UPDATE existing class location (web data takes precedence)
                            self.log.debug("Updating existing class location from JSON: \(store.stable_id)")
                            self.updateCoreDataItem(existingItem, with: class location)
                            loadedCount += 1
                        } else {
                            // CREATE new Core Data entity
                            guard let entity = NSEntityDescription.entity(forEntityName: "ClassLocation", in: self.backgroundContext) else {
                                throw CoreDataClassLocationRepositoryError.entityNotFound("ClassLocation")
                            }
                            let coreDataItem = NSManagedObject(entity: entity, insertInto: self.backgroundContext)

                            // Set properties
                            self.log.debug("Adding new class location from JSON: \(store.stable_id)")
                            self.updateCoreDataItem(coreDataItem, with: class location)
                            loadedCount += 1
                        }
                    }

                    // Save context once for all classLocations
                    if loadedCount > 0 {
                        try self.backgroundContext.save()
                        self.log.info("Loaded \(loadedCount) classLocations from JSON")
                    }

                    continuation.resume(returning: loadedCount)

                } catch {
                    self.log.error("Failed to load classLocations from JSON: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func loadClassLocationsFromJSONFile(at fileURL: URL) async throws -> Int {
        let data = try Data(contentsOf: fileURL)
        return try await loadClassLocationsFromJSON(data)
    }

    func exportClassLocationsToJSON() async throws -> Data {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ClassLocation")
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let classLocations = coreDataItems.compactMap { self.convertToClassLocationModel($0) }
                    let class locationDataArray = classLocations.map { $0.toData() }

                    let metadata = StoreMetadata(
                        version: "1.0",
                        generated: ISO8601DateFormatter().string(from: Date()),
                        class locationCount: class locationDataArray.count
                    )

                    let wrapper = WrappedStoresData(metadata: metadata, classLocations: class locationDataArray)

                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    let data = try encoder.encode(wrapper)

                    continuation.resume(returning: data)

                } catch {
                    self.log.error("Failed to export classLocations to JSON: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func classLocationExists(withId stable_id: String) async throws -> Bool {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            backgroundContext.perform {
                do {
                    let exists = try self.fetchClassLocationSync(byId: stable_id) != nil
                    continuation.resume(returning: exists)
                } catch {
                    self.log.error("Failed to check if class location exists: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Statistics Operations

    func getClassLocationCount() async throws -> Int {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int, Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ClassLocation")
                    let count = try self.backgroundContext.count(for: fetchRequest)

                    continuation.resume(returning: count)

                } catch {
                    self.log.error("Failed to get class location count: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getVerifiedClassLocationCount() async throws -> Int {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int, Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ClassLocation")
                    fetchRequest.predicate = NSPredicate(format: "is_verified == YES")
                    let count = try self.backgroundContext.count(for: fetchRequest)

                    continuation.resume(returning: count)

                } catch {
                    self.log.error("Failed to get verified class location count: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getClassLocationsWithLocationCount() async throws -> Int {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int, Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ClassLocation")
                    fetchRequest.predicate = NSPredicate(format: "latitude != 0.0 AND longitude != 0.0")
                    let count = try self.backgroundContext.count(for: fetchRequest)

                    continuation.resume(returning: count)

                } catch {
                    self.log.error("Failed to get classLocations with location count: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Helper Methods

    private nonisolated func fetchClassLocationSync(byId stable_id: String) throws -> ClassLocationModel? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ClassLocation")
        fetchRequest.predicate = NSPredicate(format: "stable_id == %@", stable_id)
        fetchRequest.fetchLimit = 1

        let results = try backgroundContext.fetch(fetchRequest)
        return results.first.flatMap { convertToClassLocationModel($0) }
    }

    private nonisolated func fetchCoreDataItemSync(byId stable_id: String) throws -> NSManagedObject? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ClassLocation")
        fetchRequest.predicate = NSPredicate(format: "stable_id == %@", stable_id)
        fetchRequest.fetchLimit = 1

        let results = try backgroundContext.fetch(fetchRequest)
        return results.first
    }

    private nonisolated func updateCoreDataItem(_ coreDataItem: NSManagedObject, with class location: ClassLocationModel) {
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

        // Technique support fields
        coreDataItem.setValue(store.supportsCasting, forKey: "supports_casting")
        coreDataItem.setValue(store.supportsFlameworkingHard, forKey: "supports_flameworking_hard")
        coreDataItem.setValue(store.supportsFlameworkingSoft, forKey: "supports_flameworking_soft")
        coreDataItem.setValue(store.supportsFusing, forKey: "supports_fusing")
        coreDataItem.setValue(store.supportsGlassBlowing, forKey: "supports_glass_blowing")
        coreDataItem.setValue(store.supportsStainedGlass, forKey: "supports_stained_glass")
        coreDataItem.setValue(store.supportsOther, forKey: "supports_other")
    }

    private nonisolated func convertToClassLocationModel(_ coreDataItem: NSManagedObject) -> ClassLocationModel? {
        guard let stable_id = coreDataItem.value(forKey: "stable_id") as? String,
              let name = coreDataItem.value(forKey: "name") as? String else {
            log.error("Failed to convert Core Data item to ClassLocationModel - missing required properties")
            return nil
        }

        return ClassLocationModel(
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
            isVerified: (coreDataItem.value(forKey: "is_verified") as? Bool) ?? false,
            supportsCasting: (coreDataItem.value(forKey: "supports_casting") as? Bool) ?? false,
            supportsFlameworkingHard: (coreDataItem.value(forKey: "supports_flameworking_hard") as? Bool) ?? false,
            supportsFlameworkingSoft: (coreDataItem.value(forKey: "supports_flameworking_soft") as? Bool) ?? false,
            supportsFusing: (coreDataItem.value(forKey: "supports_fusing") as? Bool) ?? false,
            supportsGlassBlowing: (coreDataItem.value(forKey: "supports_glass_blowing") as? Bool) ?? false,
            supportsStainedGlass: (coreDataItem.value(forKey: "supports_stained_glass") as? Bool) ?? false,
            supportsOther: (coreDataItem.value(forKey: "supports_other") as? Bool) ?? false
        )
    }
}

// MARK: - Core Data Repository Errors

enum CoreDataClassLocationRepositoryError: Error, LocalizedError {
    case entityNotFound(String)
    case class locationNotFound(String)
    case class locationAlreadyExists(String)
    case invalidData(String)

    var errorDescription: String? {
        switch self {
        case .entityNotFound(let entityName):
            return "Core Data entity not found: \(entityName)"
        case .classLocationNotFound(let stableId):
            return "ClassLocation not found: \(stableId)"
        case .classLocationAlreadyExists(let stableId):
            return "ClassLocation already exists: \(stableId)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        }
    }
}

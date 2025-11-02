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
/// Provides persistent storage for classLocation information using Core Data
class CoreDataClassLocationRepository: @unchecked Sendable, ClassLocationRepository {

    // MARK: - Dependencies

    private let context: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext
    private let log = Logger(subsystem: "com.flameworker.app", category: "classlocation-repository")

    // MARK: - Initialization

    /// Initialize CoreDataClassLocationRepository with a Core Data context
    /// - Parameter context: The NSManagedObjectContext to use for classLocation operations
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
                    self.log.error("Failed to fetch classLocation: \(error)")
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

    func createClassLocation(_ classLocation: ClassLocationModel) async throws -> ClassLocationModel {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ClassLocationModel, Error>) in
            backgroundContext.perform {
                do {
                    // Validate classLocation
                    guard classLocation.isValid else {
                        throw CoreDataClassLocationRepositoryError.invalidData(classLocation.validationErrors.joined(separator: ", "))
                    }

                    // Check if classLocation already exists
                    if try self.fetchClassLocationSync(byId: classLocation.stable_id) != nil {
                        throw CoreDataClassLocationRepositoryError.classLocationAlreadyExists(classLocation.stable_id)
                    }

                    // Create new Core Data entity
                    guard let entity = NSEntityDescription.entity(forEntityName: "ClassLocation", in: self.backgroundContext) else {
                        throw CoreDataClassLocationRepositoryError.entityNotFound("ClassLocation")
                    }
                    let coreDataItem = NSManagedObject(entity: entity, insertInto: self.backgroundContext)

                    // Set properties
                    self.updateCoreDataItem(coreDataItem, with: classLocation)

                    // Save context
                    try self.backgroundContext.save()

                    self.log.info("Created classLocation: \(classLocation.name)")
                    continuation.resume(returning: classLocation)

                } catch {
                    self.log.error("Failed to create classLocation: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func createClassLocations(_ classLocations: [ClassLocationModel]) async throws -> [ClassLocationModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[ClassLocationModel], Error>) in
            backgroundContext.perform {
                do {
                    var createdClassLocations: [ClassLocationModel] = []

                    for classLocation in classLocations {
                        // Validate classLocation
                        guard classLocation.isValid else {
                            throw CoreDataClassLocationRepositoryError.invalidData(classLocation.validationErrors.joined(separator: ", "))
                        }

                        // Skip if classLocation already exists
                        if try self.fetchClassLocationSync(byId: classLocation.stable_id) != nil {
                            self.log.warning("ClassLocation already exists, skipping: \(classLocation.stable_id)")
                            continue
                        }

                        // Create new Core Data entity
                        guard let entity = NSEntityDescription.entity(forEntityName: "ClassLocation", in: self.backgroundContext) else {
                            throw CoreDataClassLocationRepositoryError.entityNotFound("ClassLocation")
                        }
                        let coreDataItem = NSManagedObject(entity: entity, insertInto: self.backgroundContext)

                        // Set properties
                        self.updateCoreDataItem(coreDataItem, with: classLocation)
                        createdClassLocations.append(classLocation)
                    }

                    // Save context once for all classLocations
                    if !createdClassLocations.isEmpty {
                        try self.backgroundContext.save()
                        self.log.info("Created \(createdClassLocations.count) classLocations")
                    }

                    continuation.resume(returning: createdClassLocations)

                } catch {
                    self.log.error("Failed to create classLocations: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func updateClassLocation(_ classLocation: ClassLocationModel) async throws -> ClassLocationModel {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ClassLocationModel, Error>) in
            backgroundContext.perform {
                do {
                    // Validate classLocation
                    guard classLocation.isValid else {
                        throw CoreDataClassLocationRepositoryError.invalidData(classLocation.validationErrors.joined(separator: ", "))
                    }

                    // Find existing item
                    guard let coreDataItem = try self.fetchCoreDataItemSync(byId: classLocation.stable_id) else {
                        self.log.warning("Attempted to update non-existent classLocation: \(classLocation.stable_id)")
                        throw CoreDataClassLocationRepositoryError.classLocationNotFound(classLocation.stable_id)
                    }

                    // Update properties
                    self.updateCoreDataItem(coreDataItem, with: classLocation)

                    // Save context
                    try self.backgroundContext.save()

                    self.log.info("Updated classLocation: \(classLocation.name)")
                    continuation.resume(returning: classLocation)

                } catch {
                    self.log.error("Failed to update classLocation: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteClassLocation(_ classLocation: ClassLocationModel) async throws {
        try await deleteClassLocation(byId: classLocation.stable_id)
    }

    func deleteClassLocation(byId stable_id: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    // Find existing item
                    guard let coreDataItem = try self.fetchCoreDataItemSync(byId: stable_id) else {
                        self.log.warning("Attempted to delete non-existent classLocation: \(stable_id)")
                        // Not throwing error - idempotent delete
                        continuation.resume()
                        return
                    }

                    // Delete item
                    self.backgroundContext.delete(coreDataItem)

                    // Save context
                    try self.backgroundContext.save()

                    self.log.info("Deleted classLocation: \(stable_id)")
                    continuation.resume()

                } catch {
                    self.log.error("Failed to delete classLocation: \(error)")
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
                    let allClassLocations = try self.backgroundContext.fetch(fetchRequest)

                    for classLocation in allClassLocations {
                        self.backgroundContext.delete(classLocation)
                    }

                    if !allClassLocations.isEmpty {
                        try self.backgroundContext.save()
                    }

                    self.log.info("Deleted all \(allClassLocations.count) classLocations")
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

                    self.log.debug("Found \(classLocations.count) classLocations matching search text")
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
                    let allClassLocations = coreDataItems.compactMap { self.convertToClassLocationModel($0) }

                    // Filter by distance in memory (Core Data doesn't have built-in distance queries)
                    let nearbyClassLocations = allClassLocations.filter { classLocation in
                        guard let distance = classLocation.distance(from: coordinate) else { return false }
                        return distance <= radiusMeters
                    }

                    // Sort by distance
                    let sortedClassLocations = nearbyClassLocations.sorted { classLocation1, classLocation2 in
                        let dist1 = classLocation1.distance(from: coordinate) ?? Double.greatestFiniteMagnitude
                        let dist2 = classLocation2.distance(from: coordinate) ?? Double.greatestFiniteMagnitude
                        return dist1 < dist2
                    }

                    continuation.resume(returning: sortedClassLocations)

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

                    let cities = Set(classLocations.compactMap { $0.value(forKey: "city") as? String })
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

                    let states = Set(classLocations.compactMap { $0.value(forKey: "state") as? String })
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
                    let cities = Set(classLocations.compactMap { $0.value(forKey: "city") as? String })

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
                    let states = Set(classLocations.compactMap { $0.value(forKey: "state") as? String })

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

                    let stateGroups = Dictionary(grouping: classLocations) { classLocation in
                        (classLocation.value(forKey: "state") as? String) ?? "Unknown"
                    }
                    let stateCounts = stateGroups.mapValues { $0.count }

                    continuation.resume(returning: stateCounts)

                } catch {
                    self.log.error("Failed to get classLocation count by state: \(error)")
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

                    let cityGroups = Dictionary(grouping: classLocations) { classLocation in
                        (classLocation.value(forKey: "city") as? String) ?? "Unknown"
                    }
                    let cityCounts = cityGroups.mapValues { $0.count }

                    continuation.resume(returning: cityCounts)

                } catch {
                    self.log.error("Failed to get classLocation count by city: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Bulk Operations

    func loadClassLocationsFromJSON(_ data: Data) async throws -> Int {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int, Error>) in
            backgroundContext.perform {
                // TODO: Implement ClassLocationData JSON structure
                // Currently using mock data instead of JSON deserialization
                continuation.resume(returning: 0)
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
                // TODO: Implement ClassLocationData JSON structure
                // Currently returning empty JSON
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                do {
                    let emptyArray: [String] = []
                    let data = try encoder.encode(["classLocations": emptyArray])
                    continuation.resume(returning: data)
                } catch {
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
                    self.log.error("Failed to check if classLocation exists: \(error)")
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
                    self.log.error("Failed to get classLocation count: \(error)")
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
                    self.log.error("Failed to get verified classLocation count: \(error)")
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

    private nonisolated func updateCoreDataItem(_ coreDataItem: NSManagedObject, with classLocation: ClassLocationModel) {
        coreDataItem.setValue(classLocation.stable_id, forKey: "stable_id")
        coreDataItem.setValue(classLocation.name, forKey: "name")
        coreDataItem.setValue(classLocation.addressLine1, forKey: "address_line1")
        coreDataItem.setValue(classLocation.addressLine2, forKey: "address_line2")
        coreDataItem.setValue(classLocation.city, forKey: "city")
        coreDataItem.setValue(classLocation.state, forKey: "state")
        coreDataItem.setValue(classLocation.zip, forKey: "zip")
        coreDataItem.setValue(classLocation.latitude, forKey: "latitude")
        coreDataItem.setValue(classLocation.longitude, forKey: "longitude")
        coreDataItem.setValue(classLocation.websiteUrl, forKey: "website_url")
        coreDataItem.setValue(classLocation.phone, forKey: "phone")
        coreDataItem.setValue(classLocation.hoursJson, forKey: "hours_json")
        coreDataItem.setValue(classLocation.heroImagePath, forKey: "hero_image_path")
        coreDataItem.setValue(classLocation.notes, forKey: "notes")
        coreDataItem.setValue(classLocation.isVerified, forKey: "is_verified")

        // Technique support fields
        coreDataItem.setValue(classLocation.supportsCasting, forKey: "supports_casting")
        coreDataItem.setValue(classLocation.supportsFlameworkingHard, forKey: "supports_flameworking_hard")
        coreDataItem.setValue(classLocation.supportsFlameworkingSoft, forKey: "supports_flameworking_soft")
        coreDataItem.setValue(classLocation.supportsFusing, forKey: "supports_fusing")
        coreDataItem.setValue(classLocation.supportsGlassBlowing, forKey: "supports_glass_blowing")
        coreDataItem.setValue(classLocation.supportsStainedGlass, forKey: "supports_stained_glass")
        coreDataItem.setValue(classLocation.supportsOther, forKey: "supports_other")
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
    case classLocationNotFound(String)
    case classLocationAlreadyExists(String)
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

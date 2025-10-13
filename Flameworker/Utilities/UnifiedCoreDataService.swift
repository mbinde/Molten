//
//  UnifiedCoreDataService.swift
//  Flameworker
//
//  Created by Assistant on 9/30/25.
//

import Foundation
import CoreData
import OSLog
import SwiftUI

// MARK: - Base CoreData Service

class BaseCoreDataService<T: NSManagedObject> {
    let entityName: String
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Flameworker", category: "CoreData")
    
    init(entityName: String) {
        self.entityName = entityName
    }
    
    // MARK: - CRUD Operations
    
    /// Create a new entity
    func create(in context: NSManagedObjectContext) -> T {
        let entity = T(context: context)
        log.debug("Created new \(self.entityName)")
        return entity
    }
    
    /// Fetch all entities with optional predicate and sort descriptors
    func fetch(
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor] = [],
        limit: Int? = nil,
        in context: NSManagedObjectContext
    ) throws -> [T] {
        let request = NSFetchRequest<T>(entityName: entityName)
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        
        if let limit = limit {
            request.fetchLimit = limit
        }
        
        do {
            let results = try context.fetch(request)
            log.debug("Fetched \(results.count) \(self.entityName) entities")
            return results
        } catch {
            log.error("Failed to fetch \(self.entityName): \(error)")
            throw ErrorHandler.shared.createDataError(
                "Failed to load \(self.entityName) data",
                technicalDetails: error.localizedDescription
            )
        }
    }
    
    /// Save context with error handling
    func save(context: NSManagedObjectContext, description: String) throws {
        guard context.hasChanges else {
            log.debug("No changes to save for \(description)")
            return
        }
        
        do {
            try context.save()
            log.info("Successfully saved \(description)")
        } catch let nsError as NSError {
            log.error("Failed to save \(description): \(nsError)")
            ErrorHandler.shared.handleCoreDataError(nsError, context: "Saving \(description)")
            throw nsError
        }
    }
    
    /// Delete entity with error handling
    func delete(_ entity: T, from context: NSManagedObjectContext, description: String? = nil) throws {
        let desc = description ?? "Delete \(self.entityName)"
        context.delete(entity)
        try save(context: context, description: desc)
        log.info("Deleted \(desc)")
    }
    
    /// Delete all entities matching predicate
    func deleteAll(
        matching predicate: NSPredicate? = nil,
        in context: NSManagedObjectContext
    ) throws -> Int {
        let entities = try fetch(predicate: predicate, in: context)
        let count = entities.count
        
        if count == 0 {
            log.debug("No \(self.entityName) entities found to delete")
            return 0
        }
        
        // Delete entities directly without using safe enumeration
        // This prevents potential issues with the Set conversion
        for entity in entities {
            context.delete(entity)
        }
        
        // Verify pending deletions before save
        let deletedObjectsCount = context.deletedObjects.count
        log.debug("Deleting \(count) \(self.entityName) entities, \(deletedObjectsCount) objects marked for deletion")
        
        try save(context: context, description: "Delete \(count) \(self.entityName) entities")
        
        // Verify deletion was successful
        let remainingCount = try fetch(predicate: predicate, in: context).count
        if remainingCount > 0 {
            log.error("Delete operation failed: \(remainingCount) entities still exist after deletion")
            throw NSError(domain: "CoreDataService", code: 1001, userInfo: [
                NSLocalizedDescriptionKey: "Delete operation failed: \(remainingCount) entities still exist"
            ])
        }
        
        return count
    }
    
    /// Count entities matching predicate
    func count(predicate: NSPredicate? = nil, in context: NSManagedObjectContext) throws -> Int {
        let request = NSFetchRequest<T>(entityName: entityName)
        request.predicate = predicate
        return try context.count(for: request)
    }
}

// MARK: - Fetch Request Builder

struct FetchRequestBuilder<T: NSManagedObject> {
    private var predicate: NSPredicate?
    private var sortDescriptors: [NSSortDescriptor] = []
    private var limit: Int?
    
    private let entityName: String
    
    init(entityName: String) {
        self.entityName = entityName
    }
    
    func `where`(_ predicate: NSPredicate) -> FetchRequestBuilder<T> {
        var builder = self
        builder.predicate = predicate
        return builder
    }
    
    func and(_ predicate: NSPredicate) -> FetchRequestBuilder<T> {
        var builder = self
        if let existingPredicate = builder.predicate {
            builder.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [existingPredicate, predicate])
        } else {
            builder.predicate = predicate
        }
        return builder
    }
    
    func or(_ predicate: NSPredicate) -> FetchRequestBuilder<T> {
        var builder = self
        if let existingPredicate = builder.predicate {
            builder.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [existingPredicate, predicate])
        } else {
            builder.predicate = predicate
        }
        return builder
    }
    
    func whereIn(keyPath: String, values: [Any]) -> FetchRequestBuilder<T> {
        var builder = self
        
        // Handle empty values case - should return no results
        if values.isEmpty {
            // Use a predicate that will never match
            builder.predicate = NSPredicate(value: false)
        } else {
            // Create IN predicate
            let inPredicate = NSPredicate(format: "%K IN %@", keyPath, values)
            builder.predicate = inPredicate
        }
        
        return builder
    }
    
    func sorted(by keyPath: KeyPath<T, String?>, ascending: Bool = true) -> FetchRequestBuilder<T> {
        var builder = self
        let sortDescriptor = NSSortDescriptor(keyPath: keyPath, ascending: ascending)
        builder.sortDescriptors.append(sortDescriptor)
        return builder
    }
    
    func limit(_ count: Int) -> FetchRequestBuilder<T> {
        var builder = self
        builder.limit = count
        return builder
    }
    
    func execute(in context: NSManagedObjectContext) throws -> [T] {
        let request = NSFetchRequest<T>(entityName: entityName)
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        
        if let limit = limit {
            request.fetchLimit = limit
        }
        
        return try context.fetch(request)
    }
    
    func map<U>(in context: NSManagedObjectContext, transform: @escaping (T) -> U) throws -> [U] {
        let entities = try execute(in: context)
        return entities.map(transform)
    }
    
    func distinct(keyPath: String, in context: NSManagedObjectContext) throws -> [String] {
        let entities = try execute(in: context)
        
        // Extract values from the specified key path
        let values = entities.compactMap { entity in
            return entity.value(forKey: keyPath) as? String
        }
        
        // Return unique values using Set and convert back to Array
        return Array(Set(values)).sorted()
    }
}

// MARK: - Specialized Services

// NOTE: UnifiedPurchaseRecordService removed during repository pattern migration
// Use PurchaseRecordService with repository pattern instead

// MARK: - CoreData Extensions for Safe Property Access

extension NSManagedObject {
    /// Safely set string value
    func setString(_ value: String?, forKey key: String) {
        setValue(value?.isEmpty == true ? nil : value, forKey: key)
    }
    
    /// Safely get string value
    func getString(forKey key: String) -> String? {
        return value(forKey: key) as? String
    }
    
    /// Safely set double value
    func setDouble(_ value: Double, forKey key: String) {
        setValue(value, forKey: key)
    }
    
    /// Safely get double value
    func getDouble(forKey key: String) -> Double {
        return value(forKey: key) as? Double ?? 0.0
    }
    
    /// Safely set date value
    func setDate(_ value: Date?, forKey key: String) {
        setValue(value, forKey: key)
    }
    
    /// Safely get date value
    func getDate(forKey key: String) -> Date? {
        return value(forKey: key) as? Date
    }
}

// MARK: - ErrorHandler CoreData Extension

extension ErrorHandler {
    /// Handle Core Data specific errors with detailed analysis
    func handleCoreDataError(_ error: NSError, context: String = "", object: NSManagedObject? = nil) {
        logError(error, context: "CoreData - \(context)")
        
        if let validationErrors = error.userInfo[NSDetailedErrorsKey] as? [NSError] {
            for validationError in validationErrors {
                logError(validationError, context: "CoreData Validation")
            }
        }
    }
}

// MARK: - Preview Support

struct ServiceExampleView: View {
    @State private var records: [PurchaseRecord] = []
    @State private var errorMessage: String = ""
    @State private var showingError = false
    
    var body: some View {
        VStack {
            Text("Purchase Records: \(records.count)")
            
            Button("Load Recent Records") {
                loadRecentRecords()
            }
            
            if showingError {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { showingError = false }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func loadRecentRecords() {
        // NOTE: Updated to use direct Core Data during repository migration
        // TODO: Replace with new PurchaseRecordService once repository pattern is complete
        do {
            let context = PersistenceController.shared.container.viewContext
            let fetchRequest: NSFetchRequest<PurchaseRecord> = PurchaseRecord.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \PurchaseRecord.date_added, ascending: false)]
            fetchRequest.fetchLimit = 10
            
            records = try context.fetch(fetchRequest)
        } catch {
            errorMessage = "Failed to load records: \(error.localizedDescription)"
            showingError = true
        }
    }
}

#if DEBUG
struct ServiceExampleView_Previews: PreviewProvider {
    static var previews: some View {
        ServiceExampleView()
    }
}
#endif

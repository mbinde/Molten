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
        
        // Use safe enumeration to prevent collection mutation errors during deletion
        // Filter out any nil values that might exist in the collection
        CoreDataHelpers.safelyEnumerate(Set(entities.compactMap { $0 })) { entity in
            context.delete(entity)
        }
        try save(context: context, description: "Delete \(count) \(self.entityName) entities")
        
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
}

// MARK: - Specialized Services

final class UnifiedPurchaseRecordService: BaseCoreDataService<PurchaseRecord> {
    static let shared = UnifiedPurchaseRecordService()
    
    private init() {
        super.init(entityName: "PurchaseRecord")
    }
    
    // MARK: - Specialized Methods
    
    func createPurchaseRecord(
        supplier: String,
        totalAmount: Double,
        date: Date = Date(),
        notes: String? = nil,
        in context: NSManagedObjectContext
    ) throws -> PurchaseRecord {
        let record = create(in: context)
        
        // Set properties safely
        record.setValue(supplier, forKey: "supplier")
        record.setValue(totalAmount, forKey: "price")
        record.setValue(date, forKey: "date_added")
        record.setValue(notes, forKey: "notes")
        
        // Set timestamps if supported
        setTimestamp(on: record, key: "createdAt")
        
        try save(context: context, description: "new PurchaseRecord for \(supplier)")
        return record
    }
    
    func fetchBySupplier(_ supplier: String, in context: NSManagedObjectContext) throws -> [PurchaseRecord] {
        let predicate = NSPredicate(format: "supplier CONTAINS[cd] %@", supplier)
        let sortDescriptors = [NSSortDescriptor(keyPath: \PurchaseRecord.date_added, ascending: false)]
        
        return try fetch(predicate: predicate, sortDescriptors: sortDescriptors, in: context)
    }
    
    func fetchByDateRange(from startDate: Date, to endDate: Date, in context: NSManagedObjectContext) throws -> [PurchaseRecord] {
        let predicate = NSPredicate(format: "date_added >= %@ AND date_added <= %@", startDate as NSDate, endDate as NSDate)
        let sortDescriptors = [NSSortDescriptor(keyPath: \PurchaseRecord.date_added, ascending: false)]
        
        return try fetch(predicate: predicate, sortDescriptors: sortDescriptors, in: context)
    }
    
    func calculateTotalSpending(from startDate: Date, to endDate: Date, in context: NSManagedObjectContext) throws -> Double {
        let records = try fetchByDateRange(from: startDate, to: endDate, in: context)
        return records.reduce(0.0) { total, record in
            total + (record.value(forKey: "price") as? Double ?? 0.0)
        }
    }
    
    // MARK: - Private Helpers
    
    private func setTimestamp(on record: PurchaseRecord, key: String) {
        // Check if the attribute exists before trying to set it
        if record.entity.attributesByName[key] != nil {
            record.setValue(Date(), forKey: key)
        }
    }
}

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
        do {
            let context = PersistenceController.shared.container.viewContext
            let sortDescriptors = [NSSortDescriptor(keyPath: \PurchaseRecord.date_added, ascending: false)]
            
            records = try UnifiedPurchaseRecordService.shared.fetch(
                sortDescriptors: sortDescriptors,
                limit: 10,
                in: context
            )
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

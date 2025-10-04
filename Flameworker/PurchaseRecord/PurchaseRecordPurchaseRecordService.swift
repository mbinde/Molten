//
//  PurchaseRecordService.swift
//  Flameworker
//
//  Created by Assistant on 9/30/25.
//

import Foundation
import CoreData

class PurchaseRecordService {
    static let shared = PurchaseRecordService()
    
    private init() {}
    
    // MARK: - Create Operations
    
    /// Creates a new PurchaseRecord with the provided data
    func createPurchaseRecord(
        supplier: String,
        totalAmount: Double,
        date: Date = Date(),
        notes: String? = nil,
        in context: NSManagedObjectContext
    ) throws -> PurchaseRecord {
        
        let newRecord = PurchaseRecord(context: context)
        newRecord.supplier = supplier
        newRecord.price = totalAmount
        newRecord.date_added = date
        newRecord.notes = notes
        
        // Set creation timestamp if the entity supports it
        if let _ = newRecord.entity.attributesByName["createdAt"] {
            newRecord.setValue(Date(), forKey: "createdAt")
        }
        
        try CoreDataHelpers.safeSave(context: context, description: "new PurchaseRecord for supplier: \(supplier)")
        
        return newRecord
    }
    
    // MARK: - Read Operations
    
    /// Fetches all purchase records sorted by date (newest first)
    func fetchAllPurchaseRecords(from context: NSManagedObjectContext) throws -> [PurchaseRecord] {
        let fetchRequest: NSFetchRequest<PurchaseRecord> = PurchaseRecord.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \PurchaseRecord.date_added, ascending: false)]
        
        return try context.fetch(fetchRequest)
    }
    
    /// Fetches purchase records for a specific supplier
    func fetchPurchaseRecords(forSupplier supplier: String, in context: NSManagedObjectContext) throws -> [PurchaseRecord] {
        let fetchRequest: NSFetchRequest<PurchaseRecord> = PurchaseRecord.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "supplier CONTAINS[cd] %@", supplier)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \PurchaseRecord.date_added, ascending: false)]
        
        return try context.fetch(fetchRequest)
    }
    
    /// Fetches purchase records within a date range
    func fetchPurchaseRecords(from startDate: Date, to endDate: Date, in context: NSManagedObjectContext) throws -> [PurchaseRecord] {
        let fetchRequest: NSFetchRequest<PurchaseRecord> = PurchaseRecord.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date_added >= %@ AND date_added <= %@", startDate as NSDate, endDate as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \PurchaseRecord.date_added, ascending: false)]
        
        return try context.fetch(fetchRequest)
    }
    
    // MARK: - Update Operations
    
    /// Updates an existing PurchaseRecord
    func updatePurchaseRecord(
        _ record: PurchaseRecord,
        supplier: String? = nil,
        totalAmount: Double? = nil,
        date: Date? = nil,
        notes: String? = nil,
        in context: NSManagedObjectContext
    ) throws {
        
        // Update only the properties that are provided (not nil)
        if let supplier = supplier { record.supplier = supplier }
        if let totalAmount = totalAmount { record.price = totalAmount }
        if let date = date { record.date_added = date }
        if let notes = notes { record.notes = notes }
        
        // Update modification timestamp if the entity supports it
        if let _ = record.entity.attributesByName["modifiedAt"] {
            record.setValue(Date(), forKey: "modifiedAt")
        }
        
        try CoreDataHelpers.safeSave(context: context, description: "updated PurchaseRecord for supplier: \(record.supplier ?? "unknown")")
    }
    
    // MARK: - Delete Operations
    
    /// Deletes a PurchaseRecord
    func deletePurchaseRecord(_ record: PurchaseRecord, from context: NSManagedObjectContext) throws {
        context.delete(record)
        try CoreDataHelpers.safeSave(context: context, description: "deleted PurchaseRecord for supplier: \(record.supplier ?? "unknown")")
        print("🗑️ Deleted PurchaseRecord for supplier: \(record.supplier ?? "unknown")")
    }
    
    // MARK: - Analytics Operations
    
    /// Calculates total spending for a specific period
    func calculateTotalSpending(from startDate: Date, to endDate: Date, in context: NSManagedObjectContext) throws -> Double {
        let fetchRequest: NSFetchRequest<PurchaseRecord> = PurchaseRecord.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date_added >= %@ AND date_added <= %@", startDate as NSDate, endDate as NSDate)
        
        let records = try context.fetch(fetchRequest)
        return records.reduce(0.0) { $0 + $1.price }
    }
    
    /// Gets spending by supplier for a specific period
    func getSpendingBySupplier(from startDate: Date, to endDate: Date, in context: NSManagedObjectContext) throws -> [String: Double] {
        let fetchRequest: NSFetchRequest<PurchaseRecord> = PurchaseRecord.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date_added >= %@ AND date_added <= %@", startDate as NSDate, endDate as NSDate)
        
        let records = try context.fetch(fetchRequest)
        var supplierTotals: [String: Double] = [:]
        
        for record in records {
            let supplier = record.supplier ?? "Unknown"
            supplierTotals[supplier, default: 0] += record.price
        }
        
        return supplierTotals
    }
    
    /// Gets top suppliers by total spending
    func getTopSuppliers(limit: Int = 5, in context: NSManagedObjectContext) throws -> [(supplier: String, totalSpent: Double)] {
        let fetchRequest: NSFetchRequest<PurchaseRecord> = PurchaseRecord.fetchRequest()
        let records = try context.fetch(fetchRequest)
        
        var supplierTotals: [String: Double] = [:]
        for record in records {
            let supplier = record.supplier ?? "Unknown"
            supplierTotals[supplier, default: 0] += record.price
        }
        
        return supplierTotals.sorted { $0.value > $1.value }
                           .prefix(limit)
                           .map { (supplier: $0.key, totalSpent: $0.value) }
    }
}

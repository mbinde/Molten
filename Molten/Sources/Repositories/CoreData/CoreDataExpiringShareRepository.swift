//
//  CoreDataExpiringShareRepository.swift
//  Molten
//
//  Core Data repository for expiring share aliases
//

@preconcurrency import CoreData
import Foundation

/// Repository for managing expiring share records in Core Data
class CoreDataExpiringShareRepository: @unchecked Sendable {

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
        self.context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
    }

    // MARK: - CRUD Operations

    /// Fetch all expiring shares for the user
    func fetchAllExpiringShares() async throws -> [ExpiringShare] {
        return try await CoreDataHelper.performAsync(on: context) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ExpiringShareRecord")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "expires_at", ascending: true)]

            let records = try context.fetch(fetchRequest)
            let shares = records.compactMap { Self.convertToExpiringShare($0) }

            return shares
        }
    }

    /// Fetch a specific expiring share by share code
    func fetchExpiringShare(byCode shareCode: String) async throws -> ExpiringShare? {
        return try await CoreDataHelper.performAsync(on: context) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ExpiringShareRecord")
            fetchRequest.predicate = NSPredicate(format: "share_code == %@", shareCode)
            fetchRequest.fetchLimit = 1

            let records = try context.fetch(fetchRequest)
            let share = records.first.flatMap { Self.convertToExpiringShare($0) }

            return share
        }
    }

    /// Save a new expiring share
    func saveExpiringShare(_ share: ExpiringShare) async throws {
        try await CoreDataHelper.performAsyncVoid(on: context) { context in
            guard let entity = NSEntityDescription.entity(forEntityName: "ExpiringShareRecord", in: context) else {
                throw NSError(domain: "CoreData", code: -1, userInfo: [NSLocalizedDescriptionKey: "Entity ExpiringShareRecord not found"])
            }

            let record = NSManagedObject(entity: entity, insertInto: context)
            record.setValue(share.id, forKey: "id")
            record.setValue(share.shareCode, forKey: "share_code")
            record.setValue(share.mainShareCode, forKey: "main_share_code")
            record.setValue(share.displayName, forKey: "display_name")
            record.setValue(share.shareNotes, forKey: "share_notes")
            record.setValue(share.expiresAt, forKey: "expires_at")
            record.setValue(share.createdAt, forKey: "created_at")

            try context.save()
        }
    }

    /// Delete an expiring share by share code
    func deleteExpiringShare(byCode shareCode: String) async throws {
        try await CoreDataHelper.performAsyncVoid(on: context) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ExpiringShareRecord")
            fetchRequest.predicate = NSPredicate(format: "share_code == %@", shareCode)

            let records = try context.fetch(fetchRequest)
            for record in records {
                context.delete(record)
            }

            if !records.isEmpty {
                try context.save()
            }
        }
    }

    /// Delete all expiring shares associated with a main share code
    func deleteExpiringShares(forMainShareCode mainShareCode: String) async throws {
        try await CoreDataHelper.performAsyncVoid(on: context) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ExpiringShareRecord")
            fetchRequest.predicate = NSPredicate(format: "main_share_code == %@", mainShareCode)

            let records = try context.fetch(fetchRequest)
            for record in records {
                context.delete(record)
            }

            if !records.isEmpty {
                try context.save()
            }
        }
    }

    /// Delete all expired shares
    func deleteExpiredShares() async throws {
        try await CoreDataHelper.performAsyncVoid(on: context) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ExpiringShareRecord")
            fetchRequest.predicate = NSPredicate(format: "expires_at < %@", Date() as NSDate)

            let records = try context.fetch(fetchRequest)
            for record in records {
                context.delete(record)
            }

            if !records.isEmpty {
                try context.save()
            }
        }
    }

    // MARK: - Conversion Helpers

    private nonisolated static func convertToExpiringShare(_ record: NSManagedObject) -> ExpiringShare? {
        guard let id = record.value(forKey: "id") as? UUID,
              let shareCode = record.value(forKey: "share_code") as? String,
              let mainShareCode = record.value(forKey: "main_share_code") as? String,
              let displayName = record.value(forKey: "display_name") as? String,
              let expiresAt = record.value(forKey: "expires_at") as? Date,
              let createdAt = record.value(forKey: "created_at") as? Date else {
            return nil
        }

        let shareNotes = record.value(forKey: "share_notes") as? String

        // ExpiringShare is Sendable, but compiler incorrectly infers MainActor isolation
        // Using assumeIsolated to bypass false positive
        return MainActor.assumeIsolated {
            ExpiringShare(
                id: id,
                shareCode: shareCode,
                mainShareCode: mainShareCode,
                displayName: displayName,
                shareNotes: shareNotes,
                expiresAt: expiresAt,
                createdAt: createdAt
            )
        }
    }
}

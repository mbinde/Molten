//
//  CoreDataShareRecordRepository.swift
//  Molten
//
//  Repository for managing friend share records in Core Data (Cloud store)
//

import Foundation
import CoreData

/// Repository for managing ShareRecord entities (synced via CloudKit)
@MainActor
class CoreDataShareRecordRepository {

    // MARK: - Properties

    private let context: NSManagedObjectContext

    // MARK: - Initialization

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - CRUD Operations

    /// Save or update a share record
    /// - Parameter shareCode: Share code
    /// - Parameter ownerName: Owner's display name
    /// - Parameter ownerNickname: Optional nickname
    /// - Parameter ownerShareNotes: Owner's public share notes (from server)
    /// - Parameter iconSymbol: SF Symbol name for icon
    /// - Parameter iconBackgroundHex: Background color hex
    /// - Parameter iconForegroundHex: Foreground color hex
    func saveShareRecord(
        shareCode: String,
        ownerName: String,
        ownerNickname: String? = nil,
        ownerShareNotes: String? = nil,
        iconSymbol: String? = nil,
        iconBackgroundHex: String? = nil,
        iconForegroundHex: String? = nil
    ) throws {
        // Check if record already exists
        let fetchRequest: NSFetchRequest<ShareRecord> = ShareRecord.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "share_code == %@", shareCode)
        fetchRequest.fetchLimit = 1

        let existing = try context.fetch(fetchRequest).first
        let isNewRecord = existing == nil

        let record = existing ?? ShareRecord(context: context)

        // Set/update attributes
        record.setValue(shareCode, forKey: "share_code")
        record.setValue(ownerName, forKey: "owner_name")
        record.setValue(ownerNickname, forKey: "owner_nickname")
        record.setValue(ownerShareNotes, forKey: "user_share_notes")
        record.setValue(Date(), forKey: "last_fetched")
        record.setValue("active", forKey: "status")

        // Set icon values only for new records (don't overwrite existing customizations)
        if isNewRecord {
            record.setValue(iconSymbol, forKey: "icon_symbol")
            record.setValue(iconBackgroundHex, forKey: "icon_background_hex")
            record.setValue(iconForegroundHex, forKey: "icon_foreground_hex")
            record.setValue(Date(), forKey: "date_added")
        }

        try CoreDataErrorHandler.save(context: context)
    }

    /// Get all active share records
    /// - Returns: Array of active ShareRecord entities
    func getActiveShareRecords() throws -> [ShareRecord] {
        let fetchRequest: NSFetchRequest<ShareRecord> = ShareRecord.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "status == %@", "active")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date_added", ascending: true)]

        return try context.fetch(fetchRequest)
    }

    /// Get a specific share record by code
    /// - Parameter shareCode: Share code
    /// - Returns: ShareRecord if found
    func getShareRecord(shareCode: String) throws -> ShareRecord? {
        let fetchRequest: NSFetchRequest<ShareRecord> = ShareRecord.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "share_code == %@", shareCode)
        fetchRequest.fetchLimit = 1

        return try context.fetch(fetchRequest).first
    }

    /// Mark a share record as inactive (soft delete)
    /// - Parameter shareCode: Share code to deactivate
    func deactivateShareRecord(shareCode: String) throws {
        guard let record = try getShareRecord(shareCode: shareCode) else {
            return // Already doesn't exist
        }

        record.setValue("inactive", forKey: "status")
        try CoreDataErrorHandler.save(context: context)
    }

    /// Reactivate a share record
    /// - Parameter shareCode: Share code to reactivate
    func reactivateShareRecord(shareCode: String) throws {
        guard let record = try getShareRecord(shareCode: shareCode) else {
            throw NSError(domain: "ShareRecordRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Share record not found"])
        }

        record.setValue("active", forKey: "status")
        record.setValue(Date(), forKey: "last_fetched")
        try CoreDataErrorHandler.save(context: context)
    }

    /// Update last fetched timestamp
    /// - Parameter shareCode: Share code
    func updateLastFetched(shareCode: String) throws {
        guard let record = try getShareRecord(shareCode: shareCode) else {
            return
        }

        record.setValue(Date(), forKey: "last_fetched")
        try CoreDataErrorHandler.save(context: context)
    }

    /// Permanently delete a share record
    /// Note: Usually you should use deactivateShareRecord instead
    /// - Parameter shareCode: Share code to delete
    func deleteShareRecord(shareCode: String) throws {
        guard let record = try getShareRecord(shareCode: shareCode) else {
            return
        }

        context.delete(record)
        try CoreDataErrorHandler.save(context: context)
    }

    // MARK: - User Customization

    /// Update user's personal nickname for a share owner
    /// - Parameters:
    ///   - shareCode: Share code
    ///   - nickname: Personal nickname (can be nil to clear)
    func updateOwnerNickname(shareCode: String, nickname: String?) throws {
        guard let record = try getShareRecord(shareCode: shareCode) else {
            return
        }

        record.setValue(nickname, forKey: "owner_nickname")
        try CoreDataErrorHandler.save(context: context)
    }

    /// Update user's personal notes about a share
    /// - Parameters:
    ///   - shareCode: Share code
    ///   - notes: Personal notes (can be nil to clear)
    func updateUserShareNotes(shareCode: String, notes: String?) throws {
        guard let record = try getShareRecord(shareCode: shareCode) else {
            return
        }

        record.setValue(notes, forKey: "user_share_notes")
        try CoreDataErrorHandler.save(context: context)
    }

    /// Update custom icon for a share
    /// - Parameters:
    ///   - shareCode: Share code
    ///   - symbol: SF Symbol name
    ///   - backgroundHex: Background color hex
    ///   - foregroundHex: Foreground color hex
    func updateIcon(
        shareCode: String,
        symbol: String?,
        backgroundHex: String?,
        foregroundHex: String?
    ) throws {
        guard let record = try getShareRecord(shareCode: shareCode) else {
            return
        }

        record.setValue(symbol, forKey: "icon_symbol")
        record.setValue(backgroundHex, forKey: "icon_background_hex")
        record.setValue(foregroundHex, forKey: "icon_foreground_hex")
        try CoreDataErrorHandler.save(context: context)
    }
}

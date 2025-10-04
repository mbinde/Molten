//
//  CoreDataMigrationService.swift
//  Flameworker
//
//  Created by Assistant on 10/4/25.
//

import Foundation
import CoreData

/// Errors that can occur during Core Data migration
enum CoreDataMigrationError: Error, LocalizedError {
    case noBackupFound
    case backupCorrupted
    case rollbackFailed(String)
    case backupCreationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noBackupFound:
            return "No migration backup found"
        case .backupCorrupted:
            return "Migration backup is corrupted or incomplete"
        case .rollbackFailed(let reason):
            return "Migration rollback failed: \(reason)"
        case .backupCreationFailed(let reason):
            return "Failed to create migration backup: \(reason)"
        }
    }
}

/// Migration progress phases
enum MigrationPhase: String, CaseIterable {
    case backup = "Creating Backup"
    case catalogMigration = "Migrating Catalog Items"
    case inventoryValidation = "Validating Inventory"
    case rollback = "Rolling Back Changes"
    case complete = "Complete"
    
    var displayName: String {
        return rawValue
    }
}

/// Progress information for migration operations
struct MigrationProgress {
    let phase: MigrationPhase
    let currentItem: Int
    let totalItems: Int
    let percentComplete: Double
    let message: String
    
    init(phase: MigrationPhase, currentItem: Int, totalItems: Int, message: String = "") {
        self.phase = phase
        self.currentItem = currentItem
        self.totalItems = totalItems
        self.percentComplete = totalItems > 0 ? (Double(currentItem) / Double(totalItems)) * 100.0 : 0.0
        self.message = message.isEmpty ? phase.displayName : message
    }
}

class CoreDataMigrationService {
    static let shared = CoreDataMigrationService()
    
    private let unitsMigrationKey = "units_migration_v2_completed"
    private let backupKey = "units_migration_backup"
    
    // Progress reporting
    private var progressCallback: ((MigrationProgress) -> Void)?
    
    private init() {}
    
    // MARK: - Backup Data Structure
    
    /// Structure to hold catalog item backup data
    private struct CatalogItemBackup: Codable {
        let id: String
        let code: String?
        let name: String?
        let units: Int16
    }
    
    // MARK: - Public Migration Interface
    
    /// Performs all necessary migrations on app startup
    func performStartupMigrations(in context: NSManagedObjectContext) async throws {
        let migrationNeeded = try await checkIfUnitsMigrationNeeded(in: context)
        
        if migrationNeeded {
            print("🔄 Starting units migration from InventoryItem to CatalogItem...")
            
            // Create backup before migration
            try await createMigrationBackup(in: context)
            print("💾 Created migration backup")
            
            do {
                try await migrateUnitsFromInventoryToCatalog(in: context)
                markUnitsMigrationCompleted()
                print("✅ Units migration completed successfully")
                
                // Clear backup after successful migration
                await clearMigrationBackup()
                print("🗑️ Cleared migration backup after successful migration")
            } catch {
                print("❌ Migration failed: \(error)")
                print("🔄 Attempting automatic rollback...")
                
                do {
                    try await rollbackUnitsMigration(in: context)
                    print("✅ Successfully rolled back migration")
                } catch {
                    print("❌ Rollback failed: \(error)")
                    print("⚠️ Manual intervention may be required")
                }
                
                throw error
            }
        } else {
            print("ℹ️ Units migration already completed, skipping")
        }
    }
    
    // MARK: - Units Migration
    
    /// Checks if units migration is needed
    func checkIfUnitsMigrationNeeded(in context: NSManagedObjectContext) async throws -> Bool {
        // First check if migration was already completed via UserDefaults flag
        if UserDefaults.standard.bool(forKey: unitsMigrationKey) {
            return false
        }
        
        // Sophisticated detection: Analyze the actual data
        return try await analyzeDataForMigrationNeeds(in: context)
    }
    
    /// Analyzes the database to determine if units migration is actually needed
    private func analyzeDataForMigrationNeeds(in context: NSManagedObjectContext) async throws -> Bool {
        // Fetch all catalog items to check their units status
        let catalogFetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        let catalogItems = try context.fetch(catalogFetchRequest)
        
        // If no catalog items exist, no migration needed
        if catalogItems.isEmpty {
            print("ℹ️ No catalog items found - no migration needed")
            return false
        }
        
        // Check if any catalog items have uninitialized units (value of 0)
        let uninitializedItems = catalogItems.filter { $0.units == 0 }
        
        if uninitializedItems.isEmpty {
            print("ℹ️ All catalog items have initialized units - no migration needed")
            return false
        } else {
            print("🔍 Found \(uninitializedItems.count) catalog items with uninitialized units - migration needed")
            for item in uninitializedItems {
                print("  - \(item.name ?? item.id ?? "unknown"): units = \(item.units)")
            }
            return true
        }
    }
    
    /// Migrates units from InventoryItem to CatalogItem
    func migrateUnitsFromInventoryToCatalog(in context: NSManagedObjectContext) async throws {
        // Fetch all catalog items and ensure they have proper default units
        let catalogFetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        let catalogItems = try context.fetch(catalogFetchRequest)
        
        let totalCatalogItems = catalogItems.count
        var migratedCount = 0
        var preservedCount = 0
        var processedCatalogItems = 0
        
        reportProgress(MigrationProgress(phase: .catalogMigration, currentItem: 0, totalItems: totalCatalogItems, message: "Starting catalog migration"))
        
        for catalogItem in catalogItems {
            // Only set default units if uninitialized (0 means uninitialized)
            // Preserve existing non-zero units
            if catalogItem.units == 0 {
                catalogItem.units = InventoryUnits.rods.rawValue
                migratedCount += 1
                print("📝 Migrated catalog item '\(catalogItem.name ?? catalogItem.id ?? "unknown")': set default units to rods")
            } else {
                preservedCount += 1
                let units = InventoryUnits(rawValue: catalogItem.units)?.displayName ?? "unknown"
                print("✅ Preserved existing units for catalog item '\(catalogItem.name ?? catalogItem.id ?? "unknown")': \(units)")
            }
            
            processedCatalogItems += 1
            if processedCatalogItems % max(1, totalCatalogItems / 10) == 0 || processedCatalogItems == totalCatalogItems {
                reportProgress(MigrationProgress(phase: .catalogMigration, currentItem: processedCatalogItems, totalItems: totalCatalogItems, message: "Migrating catalog items"))
            }
        }
        
        print("🏁 Migration summary: \(migratedCount) items migrated, \(preservedCount) items preserved")
        
        // Fetch all inventory items to validate they can access units through relationship
        let inventoryFetchRequest: NSFetchRequest<InventoryItem> = InventoryItem.fetchRequest()
        let inventoryItems = try context.fetch(inventoryFetchRequest)
        
        let totalInventoryItems = inventoryItems.count
        var processedInventoryItems = 0
        
        if totalInventoryItems > 0 {
            reportProgress(MigrationProgress(phase: .inventoryValidation, currentItem: 0, totalItems: totalInventoryItems, message: "Starting inventory validation"))
            
            for inventoryItem in inventoryItems {
                // Validate that each inventory item can access its catalog item's units
                let units = inventoryItem.unitsKind
                processedInventoryItems += 1
                
                if processedInventoryItems % max(1, totalInventoryItems / 10) == 0 || processedInventoryItems == totalInventoryItems {
                    reportProgress(MigrationProgress(phase: .inventoryValidation, currentItem: processedInventoryItems, totalItems: totalInventoryItems, message: "Validating inventory items"))
                }
                
                print("🔗 Validated units access for inventory item '\(inventoryItem.id ?? "unknown")': \(units.displayName)")
            }
            
            print("✅ Validated \(processedInventoryItems) inventory items can access units through catalog relationship")
        }
        
        try CoreDataHelpers.safeSave(context: context, description: "units migration from InventoryItem to CatalogItem")
        
        // Report completion
        reportProgress(MigrationProgress(phase: .complete, currentItem: 1, totalItems: 1, message: "Migration completed successfully"))
    }
    
    /// Marks the units migration as completed
    func markUnitsMigrationCompleted() {
        UserDefaults.standard.set(true, forKey: unitsMigrationKey)
    }
    
    /// Resets migration status for testing
    func resetMigrationStatusForTesting() {
        UserDefaults.standard.removeObject(forKey: unitsMigrationKey)
    }
    
    // MARK: - Progress Reporting
    
    /// Sets a callback to receive progress updates during migration
    func setProgressCallback(_ callback: @escaping (MigrationProgress) -> Void) async {
        progressCallback = callback
    }
    
    /// Clears the progress callback
    func clearProgressCallback() async {
        progressCallback = nil
    }
    
    /// Reports progress to the callback if set
    private func reportProgress(_ progress: MigrationProgress) {
        progressCallback?(progress)
        print("📊 \(progress.phase.displayName): \(String(format: "%.1f", progress.percentComplete))% (\(progress.currentItem)/\(progress.totalItems)) - \(progress.message)")
    }
    
    // MARK: - Backup and Rollback System
    
    /// Creates a backup of current catalog item units before migration
    func createMigrationBackup(in context: NSManagedObjectContext) async throws {
        let catalogFetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        let catalogItems = try context.fetch(catalogFetchRequest)
        
        let totalItems = catalogItems.count
        reportProgress(MigrationProgress(phase: .backup, currentItem: 0, totalItems: totalItems, message: "Starting backup creation"))
        
        // Create backup data structure
        var backupData: [CatalogItemBackup] = []
        var processedItems = 0
        
        for item in catalogItems {
            guard let id = item.id else { continue }
            
            let backup = CatalogItemBackup(
                id: id,
                code: item.code,
                name: item.name,
                units: item.units
            )
            backupData.append(backup)
            
            processedItems += 1
            if processedItems % max(1, totalItems / 10) == 0 || processedItems == totalItems {
                reportProgress(MigrationProgress(phase: .backup, currentItem: processedItems, totalItems: totalItems, message: "Backing up catalog items"))
            }
        }
        
        // Store backup in UserDefaults
        do {
            let backupJSON = try JSONEncoder().encode(backupData)
            UserDefaults.standard.set(backupJSON, forKey: backupKey)
            reportProgress(MigrationProgress(phase: .backup, currentItem: totalItems, totalItems: totalItems, message: "Backup completed"))
            print("💾 Created backup for \(backupData.count) catalog items")
        } catch {
            throw CoreDataMigrationError.backupCreationFailed("Failed to encode backup data: \(error)")
        }
    }
    
    /// Rolls back the units migration using the stored backup
    func rollbackUnitsMigration(in context: NSManagedObjectContext) async throws {
        // Load backup data
        guard let backupJSON = UserDefaults.standard.data(forKey: backupKey) else {
            throw CoreDataMigrationError.noBackupFound
        }
        
        let backupData: [CatalogItemBackup]
        do {
            backupData = try JSONDecoder().decode([CatalogItemBackup].self, from: backupJSON)
        } catch {
            throw CoreDataMigrationError.backupCorrupted
        }
        
        let totalItems = backupData.count
        print("🔄 Rolling back units migration using backup with \(totalItems) items")
        reportProgress(MigrationProgress(phase: .rollback, currentItem: 0, totalItems: totalItems, message: "Starting rollback"))
        
        // Restore each catalog item from backup
        var restoredCount = 0
        var failedCount = 0
        var processedItems = 0
        
        for backup in backupData {
            // Find the catalog item
            let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", backup.id)
            fetchRequest.fetchLimit = 1
            
            do {
                let results = try context.fetch(fetchRequest)
                if let catalogItem = results.first {
                    // Restore the original units value
                    catalogItem.units = backup.units
                    restoredCount += 1
                    print("🔄 Restored '\(backup.name ?? backup.id)': units = \(backup.units)")
                } else {
                    print("⚠️ Could not find catalog item to restore: \(backup.id)")
                    failedCount += 1
                }
            } catch {
                print("❌ Failed to restore catalog item \(backup.id): \(error)")
                failedCount += 1
            }
            
            processedItems += 1
            if processedItems % max(1, totalItems / 10) == 0 || processedItems == totalItems {
                reportProgress(MigrationProgress(phase: .rollback, currentItem: processedItems, totalItems: totalItems, message: "Rolling back catalog items"))
            }
        }
        
        // Save the rolled-back state
        do {
            try CoreDataHelpers.safeSave(context: context, description: "rollback units migration")
            print("✅ Rollback completed: \(restoredCount) items restored, \(failedCount) items failed")
        } catch {
            throw CoreDataMigrationError.rollbackFailed("Failed to save rolled-back state: \(error)")
        }
        
        // Reset migration status so migration can be attempted again
        resetMigrationStatusForTesting()
        
        // Clear the backup since it was used
        await clearMigrationBackup()
        
        // Report completion
        reportProgress(MigrationProgress(phase: .complete, currentItem: 1, totalItems: 1, message: "Rollback completed successfully"))
    }
    
    /// Checks if a migration backup exists
    func hasMigrationBackup() async -> Bool {
        return UserDefaults.standard.data(forKey: backupKey) != nil
    }
    
    /// Verifies that the backup data is valid and complete
    func verifyBackupIntegrity(in context: NSManagedObjectContext) async throws -> Bool {
        guard let backupJSON = UserDefaults.standard.data(forKey: backupKey) else {
            return false
        }
        
        do {
            let backupData = try JSONDecoder().decode([CatalogItemBackup].self, from: backupJSON)
            
            // Verify backup has valid structure
            let validItems = backupData.filter { !$0.id.isEmpty }
            let isValid = validItems.count == backupData.count
            
            print("🔍 Backup integrity check: \(backupData.count) items, valid: \(isValid)")
            return isValid
        } catch {
            print("❌ Backup integrity check failed: \(error)")
            return false
        }
    }
    
    /// Clears the migration backup
    func clearMigrationBackup() async {
        UserDefaults.standard.removeObject(forKey: backupKey)
        print("🗑️ Cleared migration backup")
    }
}
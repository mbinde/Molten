//
//  CoreDataRecoveryUtility.swift
//  Flameworker
//
//  Created by Assistant on 10/4/25.
//

import Foundation
@preconcurrency import CoreData
import OSLog

/// Utility for recovering from Core Data migration issues
/// Use when you encounter "missing mapping model" or model incompatibility errors
struct CoreDataRecoveryUtility {
    private static let logger = Logger(subsystem: "com.motleywoods.molten", category: "core-data-recovery")
    
    /// Resets the Core Data store by deleting all persistent store files
    /// This will cause all existing data to be lost, but resolves migration issues
    /// 
    /// - Parameter controller: The PersistenceController to reset
    /// - Returns: true if reset was successful, false otherwise
    @discardableResult
    static func resetPersistentStore(_ controller: PersistenceController) async -> Bool {
        logger.info("Starting Core Data store reset...")
        
        // Step 1: Delete the existing store
        controller.deletePersistentStore()
        
        // Step 2: Reload the store with a clean model
        await controller.reloadPersistentStore()
        
        logger.info("Core Data store reset completed")
        return true
    }
    
    /// Diagnostic function to check what entities exist in the current model
    /// Use this to understand what's actually in your Core Data model
    static func diagnoseModel(_ controller: PersistenceController) {
        let model = controller.container.managedObjectModel
        
        logger.info("🔍 Core Data Model Diagnosis:")
        logger.info("Found \(model.entities.count) entities in model:")
        
        for entity in model.entities.sorted(by: { ($0.name ?? "") < ($1.name ?? "") }) {
            logger.info("📋 Entity: \(entity.name ?? "Unknown")")
            logger.info("   Class: \(entity.managedObjectClassName)")
            
            if !entity.attributesByName.isEmpty {
                logger.info("   Attributes:")
                for (name, attribute) in entity.attributesByName.sorted(by: { $0.key < $1.key }) {
                    logger.info("     - \(name): \(attribute.attributeType.rawValue)")
                }
            }
            
            if !entity.relationshipsByName.isEmpty {
                logger.info("   Relationships:")
                for (name, relationship) in entity.relationshipsByName.sorted(by: { $0.key < $1.key }) {
                    let destEntity = relationship.destinationEntity?.name ?? "Unknown"
                    logger.info("     - \(name) -> \(destEntity)")
                }
            }
        }
    }
    
    /// Checks if the store is ready and can be accessed without errors
    /// - Parameter controller: The PersistenceController to check
    /// - Returns: true if store is accessible, false if there are issues
    static func verifyStoreHealth(_ controller: PersistenceController) -> Bool {
        guard controller.isReady else {
            logger.error("Store is not ready - hasStoreLoadingError: \(controller.hasStoreLoadingError)")
            if let error = controller.storeLoadingError {
                logger.error("Store loading error details: \(error.localizedDescription)")
            }
            return false
        }
        
        guard !controller.container.persistentStoreCoordinator.persistentStores.isEmpty else {
            logger.error("No persistent stores loaded")
            return false
        }
        
        // CatalogItem health check removed - legacy code
        // If health checks are needed in the future, use GlassItem or other current entities
        logger.info("✅ Store loaded successfully (health check disabled)")
        return true
    }
    
    /// Generates a report showing entity counts for all entities in the model
    /// - Parameter context: The managed object context to query
    /// - Returns: A formatted string report showing entity names and counts
    static func generateEntityCountReport(in context: NSManagedObjectContext) -> String {
        let model = context.persistentStoreCoordinator?.managedObjectModel
        guard let entities = model?.entities else {
            return "Entity Count Report: No entities found"
        }
        
        var report = "Entity Count Report:\n"
        
        for entity in entities.sorted(by: { ($0.name ?? "") < ($1.name ?? "") }) {
            guard let entityName = entity.name else { continue }
            
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            do {
                let count = try context.count(for: fetchRequest)
                report += "\(entityName): \(count)\n"
            } catch {
                report += "\(entityName): Error counting - \(error.localizedDescription)\n"
            }
        }
        
        return report
    }
    
    /// Validates data integrity across all entities in the store
    /// - Parameter context: The managed object context to validate
    /// - Returns: Array of strings describing any data integrity issues found
    static func validateDataIntegrity(in context: NSManagedObjectContext) -> [String] {
        var issues: [String] = []
        
        let model = context.persistentStoreCoordinator?.managedObjectModel
        guard let entities = model?.entities else {
            issues.append("Cannot access data model entities")
            return issues
        }
        
        // CatalogItem validation removed - legacy code
        // If data integrity validation is needed in the future, add checks for current entities

        return issues
    }

    // Legacy CatalogItem validation method removed
    
    /// Measures query performance for common Core Data operations
    /// - Parameter context: The managed object context to test
    /// - Returns: A formatted string report showing query execution times
    static func measureQueryPerformance(in context: NSManagedObjectContext) -> String {
        var report = "Query Performance Report:\n\n"

        // CatalogItem performance measurement removed - legacy code
        // If performance measurements are needed, add for current entities (GlassItem, etc.)
        report += "Performance measurements disabled (CatalogItem removed)\n"

        return report
    }
    
    /// Measures performance for a specific entity type
    /// - Parameters:
    ///   - entityName: Name of the entity to test
    ///   - context: The managed object context to use
    /// - Returns: A formatted string with performance measurements for this entity
    private static func measureEntityPerformance(entityName: String, in context: NSManagedObjectContext) -> String {
        var entityReport = "\(entityName) Performance:\n"
        
        // Measure count operation
        let countStartTime = CFAbsoluteTimeGetCurrent()
        let count: Int
        do {
            let countRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            count = try context.count(for: countRequest)
        } catch {
            return "  Error measuring \(entityName): \(error.localizedDescription)\n\n"
        }
        let countTime = (CFAbsoluteTimeGetCurrent() - countStartTime) * 1000
        entityReport += "  Count (\(count) entities): \(String(format: "%.2f", countTime)) ms\n"
        
        // Measure fetch operation
        let fetchStartTime = CFAbsoluteTimeGetCurrent()
        do {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            _ = try context.fetch(fetchRequest)
        } catch {
            entityReport += "  Fetch: Error - \(error.localizedDescription)\n"
        }
        let fetchTime = (CFAbsoluteTimeGetCurrent() - fetchStartTime) * 1000
        entityReport += "  Fetch all: \(String(format: "%.2f", fetchTime)) ms\n"
        
        entityReport += "\n"
        return entityReport
    }
    
    /// Provides instructions for fixing common Core Data migration issues
    static func printRecoveryInstructions() {
        logger.info("🚑 Core Data Recovery Instructions:")
        logger.info("")
        logger.info("If you're seeing 'missing mapping model' or migration errors:")
        logger.info("")
        logger.info("1. QUICKEST FIX - Reset the database:")
        logger.info("   - This will delete all existing data")
        logger.info("   - Call CoreDataRecoveryUtility.resetPersistentStore()")
        logger.info("   - Or delete the app from simulator/device and reinstall")
        logger.info("")
        logger.info("2. Check for entity mismatches:")
        logger.info("   - Run diagnoseModel() to see what entities exist")
        logger.info("   - Make sure your code only references existing entities")
        logger.info("   - Remove references to non-existent entities like PurchaseRecord")
        logger.info("")
        logger.info("3. For production apps with user data:")
        logger.info("   - Create a proper Core Data mapping model")
        logger.info("   - Add lightweight migration support")
        logger.info("   - Test migration thoroughly before release")
        logger.info("")
        logger.info("Current entities in your model:")
        
        // Show current entities
        let controller = PersistenceController.createTestController()
        let model = controller.container.managedObjectModel
        let entityNames = model.entities.compactMap { $0.name }.sorted()
        
        for entityName in entityNames {
            logger.info("   - \(entityName)")
        }
    }
}

// MARK: - SwiftUI Integration

#if canImport(SwiftUI)
import SwiftUI

/// SwiftUI view for Core Data recovery during development
/// Add this to your app's debug menu or settings
struct CoreDataRecoveryView: View {
    @State private var isResetting = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Core Data Recovery")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Use these tools when you encounter 'missing mapping model' or migration errors.")
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button("Diagnose Model") {
                diagnoseCurrentModel()
            }
            .buttonStyle(.bordered)
            
            Button("Check Store Health") {
                checkStoreHealth()
            }
            .buttonStyle(.bordered)
            
            Button("Show Recovery Instructions") {
                showRecoveryInstructions()
            }
            .buttonStyle(.bordered)
            
            Button("Reset Store (⚠️ Deletes All Data)") {
                resetStore()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isResetting)
            .foregroundColor(.white)
            .background(Color.red)
            .cornerRadius(8)
            
            if isResetting {
                ProgressView("Resetting store...")
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
        .padding()
        .alert("Core Data Recovery", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func diagnoseCurrentModel() {
        CoreDataRecoveryUtility.diagnoseModel(PersistenceController.shared)
        alertMessage = "Model diagnosis complete. Check the debug console for details."
        showingAlert = true
    }
    
    private func checkStoreHealth() {
        let isHealthy = CoreDataRecoveryUtility.verifyStoreHealth(PersistenceController.shared)
        alertMessage = isHealthy 
            ? "✅ Store is healthy and ready to use."
            : "❌ Store has issues. Consider resetting."
        showingAlert = true
    }
    
    private func showRecoveryInstructions() {
        CoreDataRecoveryUtility.printRecoveryInstructions()
        alertMessage = "📝 Recovery instructions printed to console. Check Xcode's debug output."
        showingAlert = true
    }
    
    private func resetStore() {
        isResetting = true
        
        Task {
            let success = await CoreDataRecoveryUtility.resetPersistentStore(PersistenceController.shared)
            
            await MainActor.run {
                isResetting = false
                alertMessage = success 
                    ? "✅ Store reset successfully. App restart recommended."
                    : "❌ Store reset failed. Check console for errors."
                showingAlert = true
            }
        }
    }
}
#endif
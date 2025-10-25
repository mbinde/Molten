//
//  GlassItemDataLoadingExample.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//

import Foundation
import OSLog

/// Example demonstrating how to use the new GlassItemDataLoadingService
/// This shows various scenarios: initial loading, migration, validation, and error handling
class GlassItemDataLoadingExample {
    
    private let log = Logger.dataLoading
    
    // MARK: - Setup Example
    
    /// Example of how to set up the data loading service with all dependencies
    func setupGlassItemDataLoadingService() async throws -> GlassItemDataLoadingService {
        // 1. Create mock repositories for testing/demo
        // In a real app, these would be Core Data implementations
        let glassItemRepository = MockGlassItemRepository()
        let inventoryRepository = MockInventoryRepository()
        let locationRepository = MockLocationRepository()
        let itemTagsRepository = MockItemTagsRepository()
        let itemMinimumRepository = MockItemMinimumRepository()
        
        // 2. Create supporting services
        let inventoryTrackingService = InventoryTrackingService(
            glassItemRepository: glassItemRepository,
            inventoryRepository: inventoryRepository,
            itemTagsRepository: itemTagsRepository
        )
        
        let shoppingListRepository = MockShoppingListRepository()
        let userTagsRepository = MockUserTagsRepository()
        let shoppingListService = ShoppingListService(
            itemMinimumRepository: itemMinimumRepository,
            shoppingListRepository: shoppingListRepository,
            inventoryRepository: inventoryRepository,
            glassItemRepository: glassItemRepository,
            itemTagsRepository: itemTagsRepository,
            userTagsRepository: userTagsRepository
        )

        // 3. Create enhanced catalog service
        let catalogService = CatalogService(
            glassItemRepository: glassItemRepository,
            inventoryTrackingService: inventoryTrackingService,
            shoppingListService: shoppingListService,
            itemTagsRepository: itemTagsRepository,
            userTagsRepository: userTagsRepository
        )
        
        // 4. Create the data loading service
        return GlassItemDataLoadingService(catalogService: catalogService)
    }
    
    // MARK: - Basic Loading Examples
    
    /// Example: Basic data loading from glassitems.json
    func basicLoadingExample() async throws {
        log.info("🚀 Basic Loading Example")
        
        let loadingService = try await setupGlassItemDataLoadingService()
        
        // Load with default options
        let result = try await loadingService.loadGlassItemsFromJSON()
        
        log.info("Loading completed:")
        log.info("Items created: \(result.itemsCreated, privacy: .public)")
        log.info("Items failed: \(result.itemsFailed, privacy: .public)")
        log.info("Items skipped: \(result.itemsSkipped, privacy: .public)")
        log.info("Success rate: \(String(format: "%.1f", result.successRate), privacy: .public)%")
        
        // Display some of the created items
        for (index, item) in result.successfulItems.prefix(3).enumerated() {
            log.info("Item \(index + 1, privacy: .public): \(item.glassItem.name, privacy: .public) (\(item.glassItem.stable_id, privacy: .public))")
            log.info("Tags: \(item.tags.joined(separator: ", "), privacy: .public)")
            log.info("Total Inventory: \(item.totalQuantity, privacy: .public)")
        }
    }
    
    /// Example: Loading only if the system is empty
    func safeLoadingExample() async throws {
        log.info("🔒 Safe Loading Example")
        
        let loadingService = try await setupGlassItemDataLoadingService()
        
        // This will only load if no data exists
        if let result = try await loadingService.loadGlassItemsFromJSONIfEmpty() {
            log.info("Data loaded because system was empty")
            log.info("Items created: \(result.itemsCreated, privacy: .public)")
        } else {
            log.info("Data loading skipped because system already contains data")
        }
    }
    
    // MARK: - Advanced Loading Examples
    
    /// Example: Loading with custom options for initial setup
    func initialSetupExample() async throws {
        log.info("🎯 Initial Setup Example")
        
        let loadingService = try await setupGlassItemDataLoadingService()
        
        // Configure options for initial setup
        let setupOptions = GlassItemDataLoadingService.LoadingOptions(
            skipExistingItems: false, // Don't skip for fresh setup
            createInitialInventory: true, // Create starter inventory
            defaultInventoryType: "rod",
            defaultInventoryQuantity: 5.0, // Give each item 5 units to start
            enableTagExtraction: true, // Extract all available tags
            enableSynonymTags: true, // Include synonym-based tags
            validateNaturalKeys: true, // Validate for consistency
            batchSize: 25 // Moderate batch size for stability
        )
        
        let result = try await loadingService.loadGlassItemsFromJSON(options: setupOptions)
        
        log.info("Initial setup completed:")
        log.info("Items with inventory: \(result.successfulItems.filter { $0.totalQuantity > 0 }.count, privacy: .public)")
        let avgTags = result.successfulItems.isEmpty ? 0 : result.successfulItems.map { $0.tags.count }.reduce(0, +) / result.successfulItems.count
        log.info("Average tags per item: \(avgTags, privacy: .public)")
    }
    
    /// Example: Loading with testing/development options
    func developmentLoadingExample() async throws {
        log.info("🛠️ Development Loading Example")
        
        let loadingService = try await setupGlassItemDataLoadingService()
        
        // Use testing options for development
        let result = try await loadingService.loadGlassItemsFromJSON(
            options: .testing
        )
        
        log.info("Development data loaded:")
        log.info("Items created: \(result.itemsCreated, privacy: .public)")
        log.info("Total processed: \(result.totalProcessed, privacy: .public)")
        
        // Show detailed information for debugging
        if result.failedItems.isNotEmpty {
            log.warning("Failed items for debugging:")
            for (index, failed) in result.failedItems.prefix(3).enumerated() {
                log.warning("Failed item \(index + 1, privacy: .public): \(failed.originalData.name, privacy: .public)")
            }
        }
    }
    
    // MARK: - Migration Examples
    
    /// Example: Migrating from legacy system to GlassItem system
    /// Note: This example requires MockCatalogRepository which may not be available
    func migrationExample() async throws {
        log.info("🔄 Migration Example")
        
        let loadingService = try await setupGlassItemDataLoadingService()
        
        // For this example, we'll just use the direct migration method
        let result = try await loadingService.migrateFromLegacySystem()
        
        log.info("Migration completed!")
        log.info("Items created: \(result.itemsCreated, privacy: .public)")
        log.info("Success rate: \(String(format: "%.1f", result.successRate), privacy: .public)%")
        
        if result.successRate > 95.0 {
            log.info("✅ Migration successful - new system is ready")
        } else {
            log.warning("Migration completed with issues - check results")
        }
    }
    
    // MARK: - Validation Examples
    
    /// Example: Validating JSON data before loading
    func validationExample() async throws {
        log.info("🔍 Validation Example")
        
        let loadingService = try await setupGlassItemDataLoadingService()
        
        // Validate the JSON data first
        let validationResult = try await loadingService.validateJSONData()
        
        log.info("JSON validation results:")
        log.info("Total items found: \(validationResult.totalItemsFound, privacy: .public)")
        log.info("Items with errors: \(validationResult.itemsWithErrors, privacy: .public)")
        log.info("Items with warnings: \(validationResult.itemsWithWarnings, privacy: .public)")
        
        // Show specific validation issues
        let problematicItems = validationResult.validationDetails.filter { !$0.isValid }
        if problematicItems.isNotEmpty {
            log.warning("Items with validation errors:")
            for (index, item) in problematicItems.prefix(5).enumerated() {
                log.warning("Problem item \(index + 1, privacy: .public): \(item.itemName, privacy: .public) (\(item.itemCode, privacy: .public))")
                for error in item.errors {
                    log.warning("Error: \(error, privacy: .public)")
                }
                for warning in item.warnings {
                    log.warning("Warning: \(warning, privacy: .public)")
                }
            }
        } else {
            log.info("✅ All items passed validation")
        }
        
        // Decide whether to proceed with loading based on validation
        let errorPercentage = Double(validationResult.itemsWithErrors) / Double(validationResult.totalItemsFound) * 100.0
        if errorPercentage < 5.0 { // Less than 5% errors
            log.info("Validation passed, proceeding with data loading...")
            _ = try await loadingService.loadGlassItemsFromJSON()
        } else {
            log.warning("Too many validation errors, skipping data load")
            log.warning("Error percentage: \(String(format: "%.1f", errorPercentage), privacy: .public)%")
        }
    }
    
    // MARK: - Error Handling Examples
    
    /// Example: Comprehensive error handling during data loading
    func errorHandlingExample() async throws {
        log.info("⚠️ Error Handling Example")
        
        let loadingService = try await setupGlassItemDataLoadingService()
        
        do {
            let result = try await loadingService.loadGlassItemsFromJSON(
                options: .testing
            )
            
            // Check for partial failures
            if result.itemsFailed > 0 {
                log.warning("Partial failure - items failed to load")
                log.warning("Failed items count: \(result.itemsFailed, privacy: .public)")
                
                // Analyze failure patterns
                let failureReasons = result.failedItems.grouped(by: \.failureReason)
                for (reason, items) in failureReasons {
                    log.warning("Failure reason '\(reason, privacy: .public)': \(items.count, privacy: .public) items")
                }
                
                // Decide on retry strategy
                if result.successRate > 80.0 {
                    log.info("Success rate acceptable, continuing")
                    log.info("Success rate: \(String(format: "%.1f", result.successRate), privacy: .public)%")
                } else {
                    log.error("Success rate too low, investigation needed")
                    log.error("Success rate: \(String(format: "%.1f", result.successRate), privacy: .public)%")
                }
            } else {
                log.info("✅ All items loaded successfully")
            }
            
        } catch let error as CatalogServiceError {
            log.error("Catalog service error: \(error.localizedDescription)")
            
            switch error {
            case .newSystemNotAvailable:
                log.error("  -> New system not properly configured")
            case .naturalKeyAlreadyExists(let key):
                log.error("Duplicate key detected: \(key, privacy: .public)")
            case .validationFailed(let errors):
                log.error("Validation errors: \(errors.joined(separator: ", "), privacy: .public)")
            default:
                log.error("  -> Other catalog error")
            }
            
        } catch let error as DataLoadingServiceError {
            log.error("Data loading error: \(error.localizedDescription)")
            
            switch error {
            case .noDataAvailable:
                log.error("No data available in system")
            case .searchFailed(let reason):
                log.error("Search failed: \(reason, privacy: .public)")
            case .systemUnavailable:
                log.error("System is unavailable")
            }
            
        } catch {
            log.error("Unexpected error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Performance Examples
    
    /// Example: Performance monitoring and optimization
    func performanceExample() async throws {
        log.info("⚡ Performance Example")
        
        let loadingService = try await setupGlassItemDataLoadingService()
        
        // Configure for optimal performance
        let performanceOptions = GlassItemDataLoadingService.LoadingOptions(
            skipExistingItems: true, // Skip existing for speed
            createInitialInventory: false, // Don't create inventory for speed
            defaultInventoryType: "rod",
            defaultInventoryQuantity: 0.0,
            enableTagExtraction: true,
            enableSynonymTags: false, // Disable for speed
            validateNaturalKeys: false, // Disable validation for speed
            batchSize: 100 // Larger batches for throughput
        )
        
        let startTime = Date()
        let result = try await loadingService.loadGlassItemsFromJSON(options: performanceOptions)
        let endTime = Date()
        
        let duration = endTime.timeIntervalSince(startTime)
        let itemsPerSecond = Double(result.totalProcessed) / duration
        
        log.info("Performance metrics:")
        log.info("Total time: \(String(format: "%.2f", duration), privacy: .public) seconds")
        log.info("Items per second: \(String(format: "%.1f", itemsPerSecond), privacy: .public)")
        log.info("Success rate: \(String(format: "%.1f", result.successRate), privacy: .public)%")
        log.info("Batch errors: \(result.batchErrors.count, privacy: .public)")
        
        if duration > 10.0 {
            log.warning("Loading took longer than expected - consider optimizing batch size or reducing operations")
        } else {
            log.info("✅ Loading performance is acceptable")
        }
    }
    
    // MARK: - Complete Workflow Example
    
    /// Example: Complete workflow from validation to loading with error recovery
    func completeWorkflowExample() async throws {
        log.info("🌟 Complete Workflow Example")
        
        let loadingService = try await setupGlassItemDataLoadingService()
        
        // Step 1: Validate the data
        log.info("Step 1: Validating JSON data...")
        let validationResult = try await loadingService.validateJSONData()
        
        guard validationResult.itemsWithErrors == 0 else {
            log.error("Validation failed - aborting")
            log.error("Errors found: \(validationResult.itemsWithErrors, privacy: .public)")
            return
        }
        
        log.info("Validation passed")
        log.info("Items ready to load: \(validationResult.totalItemsFound, privacy: .public)")
        
        // Step 2: Check if system is empty and decide on approach
        log.info("Step 2: Checking system state...")
        if let safeResult = try await loadingService.loadGlassItemsFromJSONIfEmpty(options: .default) {
            log.info("Loaded into empty system")
            log.info("Items created: \(safeResult.itemsCreated, privacy: .public)")
            return
        }
        
        log.info("System not empty, proceeding with merge approach...")
        
        // Step 3: Load with merge strategy
        log.info("Step 3: Loading with merge strategy...")
        let mergeOptions = GlassItemDataLoadingService.LoadingOptions(
            skipExistingItems: true, // Skip existing items
            createInitialInventory: false, // Don't overwrite existing inventory
            defaultInventoryType: "rod",
            defaultInventoryQuantity: 0.0,
            enableTagExtraction: true,
            enableSynonymTags: true,
            validateNaturalKeys: true,
            batchSize: 50
        )
        
        let result = try await loadingService.loadGlassItemsFromJSON(options: mergeOptions)
        
        // Step 4: Analyze results and provide recommendations
        log.info("Step 4: Analyzing results...")
        log.info("Final results:")
        log.info("Items created: \(result.itemsCreated, privacy: .public)")
        log.info("Items skipped: \(result.itemsSkipped, privacy: .public)")
        log.info("Items failed: \(result.itemsFailed, privacy: .public)")
        
        if result.successRate > 95.0 {
            log.info("🌟 Excellent! Loading completed with high success rate")
        } else if result.successRate > 80.0 {
            log.info("✅ Good! Loading completed with acceptable success rate")
        } else {
            log.warning("⚠️ Loading completed but with low success rate - review failed items")
        }
        
        log.info("🎉 Complete workflow finished successfully!")
    }
}

// MARK: - Usage Instructions

/*
 
## How to Use the GlassItemDataLoadingService

### 1. Basic Setup
```swift
let example = GlassItemDataLoadingExample()
let loadingService = try await example.setupGlassItemDataLoadingService()
```

### 2. Simple Loading
```swift
try await example.basicLoadingExample()
```

### 3. Safe Loading (only if empty)
```swift
try await example.safeLoadingExample()
```

### 4. Migration from Legacy System
```swift
try await example.migrationExample()
```

### 5. Data Validation Before Loading
```swift
try await example.validationExample()
```

### 6. Complete Production Workflow
```swift
try await example.completeWorkflowExample()
```

## Loading Options Guide

### `.default` - Safe for production
- Skips existing items
- No initial inventory creation
- Full tag extraction
- Moderate batch size (50)

### `.migration` - For migrating from legacy
- Overwrites existing items
- Creates initial inventory (1.0 units)
- Full tag extraction
- Smaller batch size (25) for stability

### `.testing` - For development/testing
- Overwrites existing items
- Creates test inventory (10.0 units)
- Simplified tag extraction
- Small batch size (10) for debugging

### Custom Options
Create your own LoadingOptions instance to fine-tune the behavior for your specific needs.

*/

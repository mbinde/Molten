# iPhone 17 Core Data Entity Resolution Fix

## Problem
The app crashes on iPhone 17 (but not iPhone 17 Pro or Pro Max) with this error:
```
CoreData: error: +[CatalogItem entity] Failed to find a unique match for an NSEntityDescription to a managed object subclass
*** Terminating app due to uncaught exception 'NSInvalidArgumentException', reason: 'executeFetchRequest:error: A fetch request must have an entity.'
```

## Root Cause
This is a timing/initialization issue where Core Data can't properly resolve the `CatalogItem` entity on specific iPhone 17 models. This typically happens when:
1. NSFetchRequest is created without explicitly setting the entity
2. NSManagedObject subclasses are instantiated before entity resolution is complete
3. There are subtle differences in Core Data initialization timing on different device models

## Solution
We've implemented several fixes:

### 1. Explicit Entity Resolution
All fetch requests now explicitly resolve the entity using `NSEntityDescription.entity(forEntityName:in:)`:

```swift
// OLD (unsafe):
let fetchRequest = NSFetchRequest<CatalogItem>(entityName: "CatalogItem")

// NEW (safe):
guard let entity = NSEntityDescription.entity(forEntityName: "CatalogItem", in: context) else {
    // Handle error
    return
}
let fetchRequest = NSFetchRequest<CatalogItem>()
fetchRequest.entity = entity
```

### 2. Safe Helper Methods
Use the new helper methods in `CoreDataEntityHelpers.swift`:

```swift
// For fetch requests:
guard let fetchRequest = CoreDataEntityHelpers.safeCatalogItemFetchRequest(in: context) else {
    // Handle entity resolution failure
    return
}

// For creating new items:
guard let newItem = CoreDataEntityHelpers.safeCatalogItemCreation(in: context) else {
    // Handle entity creation failure
    return
}
```

### 3. Enhanced PersistenceController
The `PersistenceController` now includes:
- Explicit model loading and validation
- Entity registration verification
- Device-specific workarounds
- Better error logging and recovery

### 4. Startup Validation
The app now validates entity registration during startup:

```swift
// In your app's startup code:
.task {
    await PersistenceController.handleStartupRecovery()
    
    // Validate entities are properly registered
    if !PersistenceController.shared.validateEntityRegistration() {
        // Handle entity resolution issues
    }
}
```

## Migration Guide

### Update Existing Code

1. **Replace unsafe fetch requests:**
   ```swift
   // Find all instances of:
   NSFetchRequest<CatalogItem>(entityName: "CatalogItem")
   
   // Replace with:
   CoreDataEntityHelpers.safeCatalogItemFetchRequest(in: context)
   ```

2. **Replace unsafe entity creation:**
   ```swift
   // Find all instances of:
   CatalogItem(context: context)
   
   // Replace with:
   CoreDataEntityHelpers.safeCatalogItemCreation(in: context)
   ```

3. **Add error handling:**
   ```swift
   guard let fetchRequest = CoreDataEntityHelpers.safeCatalogItemFetchRequest(in: context) else {
       logger.error("Failed to create CatalogItem fetch request - entity resolution failed")
       return []
   }
   ```

### Testing on iPhone 17
To test the fix:
1. Build and run on iPhone 17
2. Check console logs for entity validation messages:
   - ✅ indicates successful entity resolution
   - ❌ indicates entity resolution failures
3. Test all Core Data operations (create, read, update, delete)
4. Verify preview data creation works correctly

### Additional Debugging
If issues persist, use these diagnostic tools:

```swift
// Check entity registration status
let isValid = PersistenceController.shared.validateEntityRegistration()

// Force entity cache rebuild
PersistenceController.shared.rebuildEntityCaches()

// Get detailed model info
let modelInfo = CoreDataVersionInfo.shared.troubleshootingInfo
print(modelInfo)
```

## Prevention
To prevent similar issues in the future:
1. Always use the safe helper methods for Core Data operations
2. Never create fetch requests without explicit entity resolution
3. Test on multiple device models, especially new releases
4. Monitor Core Data logs during app initialization

## Files Modified
- `Persistence.swift` - Enhanced with entity resolution and validation
- `CoreDataEntityHelpers.swift` - New file with safe helper methods
- `iPhone17-CoreData-Fix_DELETED.md` - This documentation

## Rollout Strategy
1. Test thoroughly on iPhone 17 devices
2. Monitor crash reports for Core Data-related issues
3. Update all Core Data usage throughout the app
4. Consider adding telemetry for entity resolution success/failure rates
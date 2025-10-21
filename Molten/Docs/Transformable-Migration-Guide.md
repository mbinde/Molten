# Transformable Attributes Migration Guide

## Overview

This guide walks you through removing Transformable attributes from ProjectLog, ProjectPlan, and ProjectStep entities and replacing them with proper Core Data relationships.

## Migration Strategy: Phased Approach

We'll migrate in order of complexity (easiest first):

1. **Phase 1**: Tags (ProjectLog, ProjectPlan)
2. **Phase 2**: Techniques (ProjectLog)
3. **Phase 3**: Reference URLs (ProjectPlan)
4. **Phase 4**: Glass Items (ProjectLog, ProjectPlan, ProjectStep)

## Phase 1: Migrate Tags

### Step 1.1: Create New Core Data Entities

Open `Molten.xcdatamodeld` in Xcode and create a **new model version**:
1. Editor → Add Model Version
2. Name it "Molten 6"
3. Base it on "Molten 5"

Then create these new entities in the new version:

#### Entity: ProjectTag
```
Entity Name: ProjectTag
Code Generation: Class Definition

Attributes:
- tag (String, required)
- dateAdded (Date, optional)

Relationships:
- log (To One, ProjectLog, inverse: tags, Delete Rule: Nullify)
- plan (To One, ProjectPlan, inverse: tags, Delete Rule: Nullify)
```

### Step 1.2: Update ProjectLog Entity

In ProjectLog entity:
1. **DELETE** attribute: `tags` (Transformable)
2. **ADD** relationship:
   ```
   Name: tags
   Destination: ProjectTag
   Type: To Many
   Inverse: log
   Delete Rule: Cascade
   ```

### Step 1.3: Update ProjectPlan Entity

In ProjectPlan entity:
1. **DELETE** attribute: `tags` (Transformable)
2. **ADD** relationship:
   ```
   Name: tags
   Destination: ProjectTag
   Type: To Many
   Inverse: plan
   Delete Rule: Cascade
   ```

### Step 1.4: Set Current Model Version

1. Select `.xccurrentversion` file
2. Change current version to "Molten 6"

### Step 1.5: Update Model Files

The domain models need to change from `[String]` to relationships.

**File: `Molten/Sources/Models/Domain/ProjectModels.swift`**

Find `ProjectLogModel` struct and change:
```swift
// OLD
let tags: [String]

// NEW
// Tags are now accessed via repository, not stored in model
// Remove tags property entirely, or keep it computed from ProjectTag entities
```

Find `ProjectPlanModel` struct and change:
```swift
// OLD
let tags: [String]

// NEW
// Tags are now accessed via repository, not stored in model
// Remove tags property entirely
```

### Step 1.6: Create Migration Helper

Create new file: `Molten/Sources/Repositories/CoreData/Migrations/TagsMigrationHelper.swift`

```swift
//
//  TagsMigrationHelper.swift
//  Molten
//
//  Helper for migrating tags from Transformable to relationships
//

import Foundation
import CoreData

struct TagsMigrationHelper {

    /// Migrate tags for a single ProjectLog
    static func migrateTags(for log: ProjectLog, in context: NSManagedObjectContext) throws {
        // Get old tags data (this will be nil after migration, but exists during migration)
        guard let oldTagsData = log.value(forKey: "tags") as? Data else { return }

        // Decode old tags array
        let decoder = JSONDecoder()
        guard let oldTags = try? decoder.decode([String].self, from: oldTagsData) else { return }

        // Create new ProjectTag entities
        for tagString in oldTags {
            let projectTag = NSEntityDescription.insertNewObject(forEntityName: "ProjectTag", into: context) as! ProjectTag
            projectTag.tag = tagString
            projectTag.dateAdded = Date()
            projectTag.log = log
        }
    }

    /// Migrate tags for a single ProjectPlan
    static func migrateTags(for plan: ProjectPlan, in context: NSManagedObjectContext) throws {
        // Get old tags data
        guard let oldTagsData = plan.value(forKey: "tags") as? Data else { return }

        // Decode old tags array
        let decoder = JSONDecoder()
        guard let oldTags = try? decoder.decode([String].self, from: oldTagsData) else { return }

        // Create new ProjectTag entities
        for tagString in oldTags {
            let projectTag = NSEntityDescription.insertNewObject(forEntityName: "ProjectTag", into: context) as! ProjectTag
            projectTag.tag = tagString
            projectTag.dateAdded = Date()
            projectTag.plan = plan
        }
    }

    /// Migrate all tags in the store
    static func migrateAllTags(in context: NSManagedObjectContext) throws {
        // Migrate ProjectLog tags
        let logFetch = NSFetchRequest<ProjectLog>(entityName: "ProjectLog")
        let logs = try context.fetch(logFetch)
        for log in logs {
            try? migrateTags(for: log, in: context)
        }

        // Migrate ProjectPlan tags
        let planFetch = NSFetchRequest<ProjectPlan>(entityName: "ProjectPlan")
        let plans = try context.fetch(planFetch)
        for plan in plans {
            try? migrateTags(for: plan, in: context)
        }

        try context.save()
    }
}
```

### Step 1.7: Run Migration

Add migration call in `Persistence.swift` after store loads:

```swift
// In PersistenceController.init(), after container.loadPersistentStores:

// Run one-time migration for tags (only if upgrading from Molten 5 to Molten 6)
if UserDefaults.standard.bool(forKey: "migratedToMolten6_Tags") == false {
    do {
        try TagsMigrationHelper.migrateAllTags(in: container.viewContext)
        UserDefaults.standard.set(true, forKey: "migratedToMolten6_Tags")
        print("✅ Successfully migrated tags to Molten 6")
    } catch {
        print("⚠️ Failed to migrate tags: \(error)")
    }
}
```

---

## Phase 2: Migrate Techniques (ProjectLog)

### Step 2.1: Create ProjectTechnique Entity

In Xcode Core Data editor:

#### Entity: ProjectTechnique
```
Entity Name: ProjectTechnique
Code Generation: Class Definition

Attributes:
- technique (String, required)
- dateAdded (Date, optional)

Relationships:
- log (To One, ProjectLog, inverse: techniques, Delete Rule: Nullify)
```

### Step 2.2: Update ProjectLog Entity

In ProjectLog entity:
1. **DELETE** attribute: `techniques_used` (Transformable)
2. **ADD** relationship:
   ```
   Name: techniques
   Destination: ProjectTechnique
   Type: To Many
   Inverse: log
   Delete Rule: Cascade
   ```

### Step 2.3: Create Migration Helper

Add to `TagsMigrationHelper.swift` (or create separate file):

```swift
extension TagsMigrationHelper {

    /// Migrate techniques for a single ProjectLog
    static func migrateTechniques(for log: ProjectLog, in context: NSManagedObjectContext) throws {
        guard let oldTechniquesData = log.value(forKey: "techniques_used") as? Data else { return }

        let decoder = JSONDecoder()
        guard let oldTechniques = try? decoder.decode([String].self, from: oldTechniquesData) else { return }

        for techniqueString in oldTechniques {
            let projectTechnique = NSEntityDescription.insertNewObject(forEntityName: "ProjectTechnique", into: context) as! ProjectTechnique
            projectTechnique.technique = techniqueString
            projectTechnique.dateAdded = Date()
            projectTechnique.log = log
        }
    }

    /// Migrate all techniques in the store
    static func migrateAllTechniques(in context: NSManagedObjectContext) throws {
        let logFetch = NSFetchRequest<ProjectLog>(entityName: "ProjectLog")
        let logs = try context.fetch(logFetch)
        for log in logs {
            try? migrateTechniques(for: log, in: context)
        }

        try context.save()
    }
}
```

### Step 2.4: Run Migration

Add to `Persistence.swift`:

```swift
if UserDefaults.standard.bool(forKey: "migratedToMolten6_Techniques") == false {
    do {
        try TagsMigrationHelper.migrateAllTechniques(in: container.viewContext)
        UserDefaults.standard.set(true, forKey: "migratedToMolten6_Techniques")
        print("✅ Successfully migrated techniques to Molten 6")
    } catch {
        print("⚠️ Failed to migrate techniques: \(error)")
    }
}
```

---

## Phase 3: Migrate Reference URLs (ProjectPlan)

### Step 3.1: Create ProjectReferenceUrl Entity

#### Entity: ProjectReferenceUrl
```
Entity Name: ProjectReferenceUrl
Code Generation: Class Definition

Attributes:
- url (String, required)
- title (String, optional)
- urlDescription (String, optional) [Note: Can't use "description" as it conflicts]
- dateAdded (Date, optional)
- orderIndex (Integer 32, default 0)

Relationships:
- plan (To One, ProjectPlan, inverse: referenceUrls, Delete Rule: Nullify)
```

### Step 3.2: Update ProjectPlan Entity

In ProjectPlan entity:
1. **DELETE** attribute: `reference_urls_data` (Transformable)
2. **ADD** relationship:
   ```
   Name: referenceUrls
   Destination: ProjectReferenceUrl
   Type: To Many
   Inverse: plan
   Delete Rule: Cascade
   ```

### Step 3.3: Update Domain Model

**File: `Molten/Sources/Models/Domain/ProjectModels.swift`**

The `ProjectReferenceUrl` struct already exists in the codebase. Keep it as-is for the domain model, but we'll use the Core Data entity for storage.

### Step 3.4: Create Migration Helper

```swift
extension TagsMigrationHelper {

    /// Migrate reference URLs for a single ProjectPlan
    static func migrateReferenceUrls(for plan: ProjectPlan, in context: NSManagedObjectContext) throws {
        guard let oldUrlsData = plan.value(forKey: "reference_urls_data") as? Data else { return }

        let decoder = JSONDecoder()
        guard let oldUrls = try? decoder.decode([ProjectReferenceUrl].self, from: oldUrlsData) else { return }

        for (index, urlModel) in oldUrls.enumerated() {
            let projectUrl = NSEntityDescription.insertNewObject(forEntityName: "ProjectReferenceUrl", into: context) as! ProjectReferenceUrl
            projectUrl.url = urlModel.url
            projectUrl.title = urlModel.title
            projectUrl.urlDescription = urlModel.description
            projectUrl.dateAdded = Date()
            projectUrl.orderIndex = Int32(index)
            projectUrl.plan = plan
        }
    }

    /// Migrate all reference URLs in the store
    static func migrateAllReferenceUrls(in context: NSManagedObjectContext) throws {
        let planFetch = NSFetchRequest<ProjectPlan>(entityName: "ProjectPlan")
        let plans = try context.fetch(planFetch)
        for plan in plans {
            try? migrateReferenceUrls(for: plan, in: context)
        }

        try context.save()
    }
}
```

### Step 3.5: Run Migration

```swift
if UserDefaults.standard.bool(forKey: "migratedToMolten6_ReferenceUrls") == false {
    do {
        try TagsMigrationHelper.migrateAllReferenceUrls(in: container.viewContext)
        UserDefaults.standard.set(true, forKey: "migratedToMolten6_ReferenceUrls")
        print("✅ Successfully migrated reference URLs to Molten 6")
    } catch {
        print("⚠️ Failed to migrate reference URLs: \(error)")
    }
}
```

---

## Phase 4: Migrate Glass Items (COMPLEX)

This is the most complex migration. Each entity (ProjectLog, ProjectPlan, ProjectStep) stores arrays of glass item data.

### Step 4.1: Create Through Entities

We need three separate "through" entities for many-to-many relationships:

#### Entity: ProjectLogGlassItem
```
Entity Name: ProjectLogGlassItem
Code Generation: Class Definition

Attributes:
- itemNaturalKey (String, required)
- quantity (Double, default 0.0)
- notes (String, optional)
- orderIndex (Integer 32, default 0)

Relationships:
- log (To One, ProjectLog, inverse: glassItems, Delete Rule: Nullify)
```

#### Entity: ProjectPlanGlassItem
```
Entity Name: ProjectPlanGlassItem
Code Generation: Class Definition

Attributes:
- itemNaturalKey (String, required)
- quantity (Double, default 0.0)
- notes (String, optional)
- orderIndex (Integer 32, default 0)

Relationships:
- plan (To One, ProjectPlan, inverse: glassItems, Delete Rule: Nullify)
```

#### Entity: ProjectStepGlassItem
```
Entity Name: ProjectStepGlassItem
Code Generation: Class Definition

Attributes:
- itemNaturalKey (String, required)
- quantity (Double, default 0.0)
- notes (String, optional)
- orderIndex (Integer 32, default 0)

Relationships:
- step (To One, ProjectStep, inverse: glassItems, Delete Rule: Nullify)
```

### Step 4.2: Update ProjectLog Entity

1. **DELETE** attribute: `glass_items_data` (Transformable)
2. **ADD** relationship:
   ```
   Name: glassItems
   Destination: ProjectLogGlassItem
   Type: To Many
   Inverse: log
   Delete Rule: Cascade
   ```

### Step 4.3: Update ProjectPlan Entity

1. **DELETE** attribute: `glass_items_data` (Transformable)
2. **ADD** relationship:
   ```
   Name: glassItems
   Destination: ProjectPlanGlassItem
   Type: To Many
   Inverse: plan
   Delete Rule: Cascade
   ```

### Step 4.4: Update ProjectStep Entity

1. **DELETE** attribute: `glass_items_needed_data` (Transformable)
2. **ADD** relationship:
   ```
   Name: glassItems
   Destination: ProjectStepGlassItem
   Type: To Many
   Inverse: step
   Delete Rule: Cascade
   ```

### Step 4.5: Update Domain Models

**File: `Molten/Sources/Models/Domain/ProjectModels.swift`**

The `ProjectGlassItem` struct already exists. We'll keep using it in the domain model layer.

### Step 4.6: Create Migration Helper

```swift
extension TagsMigrationHelper {

    /// Migrate glass items for ProjectLog
    static func migrateLogGlassItems(for log: ProjectLog, in context: NSManagedObjectContext) throws {
        guard let oldItemsData = log.value(forKey: "glass_items_data") as? Data else { return }

        let decoder = JSONDecoder()
        guard let oldItems = try? decoder.decode([ProjectGlassItem].self, from: oldItemsData) else { return }

        for (index, item) in oldItems.enumerated() {
            let glassItem = NSEntityDescription.insertNewObject(forEntityName: "ProjectLogGlassItem", into: context) as! ProjectLogGlassItem
            glassItem.itemNaturalKey = item.itemNaturalKey
            glassItem.quantity = item.quantity
            glassItem.notes = item.notes
            glassItem.orderIndex = Int32(index)
            glassItem.log = log
        }
    }

    /// Migrate glass items for ProjectPlan
    static func migratePlanGlassItems(for plan: ProjectPlan, in context: NSManagedObjectContext) throws {
        guard let oldItemsData = plan.value(forKey: "glass_items_data") as? Data else { return }

        let decoder = JSONDecoder()
        guard let oldItems = try? decoder.decode([ProjectGlassItem].self, from: oldItemsData) else { return }

        for (index, item) in oldItems.enumerated() {
            let glassItem = NSEntityDescription.insertNewObject(forEntityName: "ProjectPlanGlassItem", into: context) as! ProjectPlanGlassItem
            glassItem.itemNaturalKey = item.itemNaturalKey
            glassItem.quantity = item.quantity
            glassItem.notes = item.notes
            glassItem.orderIndex = Int32(index)
            glassItem.plan = plan
        }
    }

    /// Migrate glass items for ProjectStep
    static func migrateStepGlassItems(for step: ProjectStep, in context: NSManagedObjectContext) throws {
        guard let oldItemsData = step.value(forKey: "glass_items_needed_data") as? Data else { return }

        let decoder = JSONDecoder()
        guard let oldItems = try? decoder.decode([ProjectGlassItem].self, from: oldItemsData) else { return }

        for (index, item) in oldItems.enumerated() {
            let glassItem = NSEntityDescription.insertNewObject(forEntityName: "ProjectStepGlassItem", into: context) as! ProjectStepGlassItem
            glassItem.itemNaturalKey = item.itemNaturalKey
            glassItem.quantity = item.quantity
            glassItem.notes = item.notes
            glassItem.orderIndex = Int32(index)
            glassItem.step = step
        }
    }

    /// Migrate all glass items in the store
    static func migrateAllGlassItems(in context: NSManagedObjectContext) throws {
        // Migrate ProjectLog glass items
        let logFetch = NSFetchRequest<ProjectLog>(entityName: "ProjectLog")
        let logs = try context.fetch(logFetch)
        for log in logs {
            try? migrateLogGlassItems(for: log, in: context)
        }

        // Migrate ProjectPlan glass items
        let planFetch = NSFetchRequest<ProjectPlan>(entityName: "ProjectPlan")
        let plans = try context.fetch(planFetch)
        for plan in plans {
            try? migratePlanGlassItems(for: plan, in: context)
        }

        // Migrate ProjectStep glass items
        let stepFetch = NSFetchRequest<ProjectStep>(entityName: "ProjectStep")
        let steps = try context.fetch(stepFetch)
        for step in steps {
            try? migrateStepGlassItems(for: step, in: context)
        }

        try context.save()
    }
}
```

### Step 4.7: Run Migration

```swift
if UserDefaults.standard.bool(forKey: "migratedToMolten6_GlassItems") == false {
    do {
        try TagsMigrationHelper.migrateAllGlassItems(in: container.viewContext)
        UserDefaults.standard.set(true, forKey: "migratedToMolten6_GlassItems")
        print("✅ Successfully migrated glass items to Molten 6")
    } catch {
        print("⚠️ Failed to migrate glass items: \(error)")
    }
}
```

---

## Testing Strategy

### Before Migration
1. Export a backup of your Core Data store
2. Create test projects/logs with all types of data (tags, techniques, URLs, glass items)
3. Note down the data for verification after migration

### After Migration
1. Verify all tags are accessible in UI
2. Verify all techniques are preserved
3. Verify all reference URLs work
4. Verify all glass item lists are complete
5. Test adding new items through the UI
6. Test editing and deleting

### Rollback Plan
If migration fails:
1. Delete the app
2. Restore from backup
3. Change `.xccurrentversion` back to "Molten 5"
4. Rebuild and reinstall

---

## Timeline Estimate

- **Phase 1 (Tags)**: 2-3 hours
- **Phase 2 (Techniques)**: 1-2 hours
- **Phase 3 (Reference URLs)**: 2-3 hours
- **Phase 4 (Glass Items)**: 4-6 hours
- **Testing**: 2-3 hours

**Total**: 11-17 hours

---

## Benefits After Migration

✅ CloudKit can sync individual changes (not entire blobs)
✅ No more merge conflicts when editing projects on multiple devices
✅ Better performance (no serialization overhead)
✅ Can query projects by tag, technique, or glass item
✅ Proper referential integrity
✅ Future-proof data model

---

## Next Steps

1. Start with Phase 1 (Tags) - it's the simplest
2. Test thoroughly before proceeding
3. Move to Phase 2 only after Phase 1 is stable
4. Consider doing Phase 4 last (most complex)
5. Update repositories to work with new relationships
6. Update UI code to read from relationships instead of arrays

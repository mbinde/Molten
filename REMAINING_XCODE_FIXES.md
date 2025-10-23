# Remaining Xcode Fixes Needed - Entity Class Renaming

## Current Build Error

The build is failing because Core Data's auto-generated code references entity classes that don't exist:

```
error: cannot find type 'ProjectGlassItemEntity' in scope
error: cannot find type 'ProjectReferenceUrlEntity' in scope
```

## What You Need To Do In Xcode

Open `Molten.xcdatamodeld` in Xcode and rename the entity classes:

### Step 1: Rename ProjectGlassItem Entity Class

1. Open `Molten.xcdatamodeld` in Xcode
2. Select the **current version** (Molten 8.xcdatamodel)
3. Select the **ProjectGlassItem** entity in the left sidebar
4. In the **Data Model Inspector** (right panel), find the "Class" field
5. Change from `ProjectGlassItem` to `ProjectGlassItemEntity`

**Why**: This prevents conflict with the domain model struct `ProjectGlassItem` in your Swift code.

### Step 2: Rename ProjectReferenceUrl Entity Class

1. Still in Molten 8.xcdatamodel
2. Select the **ProjectReferenceUrl** entity
3. In the **Data Model Inspector**, change "Class" field
4. Change from `ProjectReferenceUrl` to `ProjectReferenceUrlEntity`

**Why**: Same reason - prevents conflict with domain model struct.

### Step 3: Verify Relationship Destinations

Quick verification after renaming:
- Project entity → `glassItems` relationship → should point to `ProjectGlassItemEntity`
- Project entity → `referenceUrls` relationship → should point to `ProjectReferenceUrlEntity`

The relationship destinations should automatically update when you rename the entity classes.

### Step 4: After Making Changes in Xcode

1. **Save the model** (Cmd+S)
2. **Clean Build Folder**: Product → Clean Build Folder (Cmd+Shift+K)
3. **Delete Derived Data** (optional but recommended):
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/Molten-*
   ```
4. **Rebuild** the project

## What I've Already Fixed in Code

- ✅ Updated `CoreDataProjectRepository.swift` to use:
  - `ProjectGlassItemEntity` instead of `ProjectPlanGlassItem`
  - `ProjectReferenceUrlEntity` instead of `ProjectPlanReferenceUrl`

- ✅ Implemented generalized UserTags system with:
  - `owner_type` and `owner_id` attributes (instead of broken tags relationships)
  - Migration logic to convert old `item_natural_key` data
  - Support for tagging Projects and Logbooks (not just glass items)

- ✅ Updated MockUserTagsRepository to match new protocol

- ✅ Deleted corrupted entity "I" from Core Data model

## Once You Complete These Steps

The build should succeed! The only remaining error is the entity class name mismatch, which can only be fixed in Xcode's Data Model Editor.

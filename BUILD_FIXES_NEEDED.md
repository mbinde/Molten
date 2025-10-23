# Build Fixes Needed

## Problem
Core Data's automatic code generation is creating conflicts with domain model structs.

## Errors
1. **Type conflicts**: ProjectGlassItem and ProjectReferenceUrl exist as both Swift structs (domain models) and Core Data entities
2. **Missing Project class**: Core Data is trying to extend a `Project` class that doesn't exist
3. **Mysterious 'I' type**: Bug in Core Data code generation for tags relationships

## Root Cause
The Core Data model has "Codegen" set to "Class Definition" or "Category/Extension" for entities that should be manual/none.

## Solution

### In Xcode:

1. **Open Molten.xcdatamodeld**

2. **For ProjectGlassItem entity:**
   - Select the entity in the left sidebar
   - Open Data Model Inspector (right sidebar)
   - Set "Codegen" to **"Manual/None"**
   - Reason: ProjectGlassItem is a value type struct in ProjectModels.swift, not a Core Data managed object

3. **For ProjectReferenceUrl entity:**
   - Select the entity
   - Set "Codegen" to **"Manual/None"**
   - Reason: ProjectReferenceUrl is a value type struct in ProjectModels.swift, not a Core Data managed object

4. **For Project entity:**
   - Select the entity
   - Verify "Class" is set to "Project" (not "ProjectPlan")
   - Set "Codegen" to **"Class Definition"** (this should auto-generate the Project class)

5. **For Logbook entity:**
   - Select the entity
   - Check if there's a tags relationship
   - If the relationship points to an entity called "I", that's the bug
   - It should point to "ItemTags" or similar

6. **Clean Build Folder:**
   - In Xcode: Product menu → Clean Build Folder (Cmd+Shift+K)
   - Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData/Molten-*`

7. **Rebuild:**
   - Build the project again

## Architecture Note

Your app uses a clean architecture pattern:
- **Domain Models** (ProjectModels.swift): Swift structs - lightweight, Codable, Sendable
- **Core Data Entities**: NSManagedObject subclasses - heavy, persistence layer

The repositories handle conversion between these two layers. Domain models should NOT be Core Data objects.

## Files Affected
- `/Molten/Molten.xcdatamodeld` (needs Codegen changes)
- Auto-generated files in DerivedData (will be regenerated correctly)

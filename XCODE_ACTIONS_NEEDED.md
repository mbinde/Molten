# Xcode Actions Needed - UserTags Migration

## Summary
I've designed and implemented the generalized UserTags system following the UserImage pattern (owner_type + owner_id). Before I can continue updating the repository implementations, you need to make changes to the Core Data model in Xcode.

## What's Been Done

✅ **Updated UserTagsRepository Protocol**
- Added `TagOwnerType` enum: `.glassItem`, `.project`, `.logbook`
- Updated `UserTagModel` to include `ownerType` and `ownerId`
- Added new generic methods (e.g., `fetchTags(ownerType:ownerId:)`)
- Kept legacy methods for backward compatibility (e.g., `fetchTags(forItem:)`)

✅ **Created Migration Plan**
- See `USER_TAGS_MIGRATION_PLAN.md` for complete details

## What You Need to Do in Xcode

### Step 1: Create New Core Data Model Version

1. Open **Molten.xcodeproj** in Xcode
2. Select **Molten.xcdatamodeld** in the file navigator
3. Go to menu: **Editor → Add Model Version...**
4. Name it: **Molten 2** (or whatever the next version number should be)
5. Based on: Current version
6. Click **Finish**

### Step 2: Update UserTags Entity

1. In the xcdatamodeld editor, select the **new model version** you just created
2. Select the **UserTags** entity in the left sidebar
3. In the **Attributes** section (right panel), **add two new attributes**:

   **Attribute 1:**
   - Name: `owner_type`
   - Type: `String`
   - Optional: **NO** (uncheck)
   - Indexed: **YES** (check)

   **Attribute 2:**
   - Name: `owner_id`
   - Type: `String`
   - Optional: **NO** (uncheck)
   - Indexed: **YES** (check)

4. **Keep the existing `item_natural_key` attribute** (we'll use it for migration)
5. **Keep the existing `tag` attribute** (unchanged)

### Step 3: Add Migration Default Values

Since we're adding required (non-optional) attributes to an existing entity, we need to set default values for migration:

1. Select the `owner_type` attribute
2. In the Data Model Inspector (right panel), find **Default Value**
3. Set it to: `glassItem`

4. Select the `owner_id` attribute
5. Set its **Default Value** to: `(empty string)`

### Step 4: Fix Project and Logbook Tags Relationships

**For Project entity:**
1. Select the **Project** entity in the left sidebar
2. Find the **Relationships** section
3. Look for the `tags` relationship
4. **DELETE** the `tags` relationship (it currently points to a broken "I" entity)
5. Projects will now use UserTags via the repository with `ownerType: .project`

**For Logbook entity:**
1. Select the **Logbook** entity
2. Find the **Relationships** section
3. Look for the `tags` relationship
4. **DELETE** the `tags` relationship (it also points to the broken "I" entity)
5. Logbooks will now use UserTags via the repository with `ownerType: .logbook`

### Step 5: Set Current Model Version

1. Select **Molten.xcdatamodeld** (the parent folder) in the file navigator
2. In the **File Inspector** (right panel), find **Model Version**
3. Set **Current** to: **Molten 2** (the new version you created)

### Step 6: Clean Build

1. In Xcode menu: **Product → Clean Build Folder** (Cmd+Shift+K)
2. Delete DerivedData:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/Molten-*
   ```

## What I'll Do Next (After You're Done)

Once you've completed the above steps:

1. ✅ Update `CoreDataUserTagsRepository` to:
   - Use `owner_type` and `owner_id` in all predicates
   - Implement the new generic methods
   - Add migration logic to copy `item_natural_key → owner_id` for existing records
   - Keep legacy methods working as wrappers

2. ✅ Update `MockUserTagsRepository` to:
   - Use `(ownerType, ownerId)` as keys instead of `itemNaturalKey`
   - Implement new generic methods
   - Keep legacy methods working

3. ✅ Build and test to verify:
   - Migration preserves existing glass item tags
   - New generic API works for all owner types
   - Legacy API still works for backward compatibility

## Why This Fixes the Build Errors

The mysterious "I" type error you saw:
```swift
@NSManaged public func addToTags(_ value: I)  // Error: cannot find type 'I'
```

This was happening because:
1. Project and Logbook entities had `tags` relationships
2. These relationships pointed to a corrupted/missing entity (showing as "I")
3. Core Data's code generator tried to create methods referencing this "I" type

**Solution**: Instead of using Core Data relationships, we're using the UserTags repository pattern:
- No relationships = no code generation errors
- Flexible owner_type/owner_id pattern = works with any entity
- Same proven pattern as UserImage = consistent architecture

## Questions?

If you run into any issues or have questions about these steps, let me know!

## When You're Ready

After you've completed all the above steps in Xcode, just let me know and I'll:
1. Update the repository implementations
2. Add migration logic
3. Build and verify everything works
4. Run tests to ensure no regressions

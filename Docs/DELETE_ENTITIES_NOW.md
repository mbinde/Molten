# Delete Core Data Entities - Ready Now!

## ✅ What's Done

All prep work is complete. You can now safely delete the entities in Xcode.

## 🚀 Steps to Delete Entities

### 1. Open Xcode and the Core Data Model
```
Open Molten.xcodeproj in Xcode
Navigate to: Molten/Molten.xcdatamodeld/Molten 21.xcdatamodel
```

### 2. Delete These 5 Entities (One at a Time)

**IMPORTANT**: Delete in this order (children before parents):

1. **GlassItem** - Select entity → Press Delete → Confirm
2. **CoatingItem** - Select entity → Press Delete → Confirm
3. **ToolItem** - Select entity → Press Delete → Confirm
4. **ItemTags** - Select entity → Press Delete → Confirm
5. **Item** (parent entity) - Select entity → Press Delete → Confirm

### 3. Remove from "Local" Configuration

After deleting all 5 entities, check the "Local" configuration:
- Click on "Molten.xcdatamodeld" (root)
- In Editor menu → select "Configuration" → "Local"
- Verify these entities are NOT listed

### 4. Save the Model

- Cmd+S to save
- Xcode will regenerate DerivedData

### 5. Clean Build

In Terminal:
```bash
cd /Users/binde/projects/arch

# Remove stub file (no longer needed)
git rm Molten/Sources/Repositories/CoreData/StubCatalogEntities.swift

# Clean DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData/Molten-*

# Build
xcodebuild -project Molten.xcodeproj -scheme Molten -sdk iphoneos build
```

### 6. Verify Success

The build should succeed with NO references to:
- GlassItem (Core Data entity)
- CoatingItem (Core Data entity)
- ToolItem (Core Data entity)
- ItemTags (Core Data entity)
- Item (Core Data entity)

### 7. Commit

```bash
git add "Molten/Molten.xcdatamodeld/Molten 21.xcdatamodel/contents"
git add Molten.xcodeproj/project.pbxproj
git commit -m "feat: delete unused Core Data catalog entities

Removed entities from Core Data model:
- GlassItem
- CoatingItem
- ToolItem
- ItemTags
- Item (parent)

These entities were only used in tests. Production and tests now both
use SQLite repositories exclusively.

Also removed StubCatalogEntities.swift (no longer needed).

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

## If You Get Errors:

### "Cannot delete - entity is referenced"
This shouldn't happen since there are no relationships. But if it does:
- Note which entity is complaining
- Check if there's a relationship pointing to it
- Delete the relationship first

### "Build failed after deletion"
```bash
# Aggressive clean
rm -rf ~/Library/Developer/Xcode/DerivedData/Molten-*
Product → Clean Build Folder in Xcode (⇧⌘K)

# Rebuild
xcodebuild -project Molten.xcodeproj -scheme Molten -sdk iphoneos clean build
```

### "Xcode crashes when deleting"
This is why we created the stub file. But if it still happens:
```bash
# Revert
git checkout HEAD -- "Molten/Molten.xcdatamodeld/Molten 21.xcdatamodel/contents"

# Ask Claude for help
```

## Success Criteria:

✅ All 5 entities deleted from model
✅ Build succeeds
✅ No Core Data auto-generated files for these entities in DerivedData
✅ Tests still pass (they use SQLite repositories now)
✅ App runs and catalog view works

---

**You're ready! The stub classes prevent crashes during deletion.**

# Next Step: Delete Core Data Catalog Entities

## ✅ What's Done

1. ✅ Created SQLite test infrastructure (`TestCatalogDatabaseManager`)
2. ✅ Updated AppDependencies to use SQLite for tests
3. ✅ Deleted Core Data catalog repositories (5 files)
4. ✅ Build succeeds
5. ✅ Tests now use production SQLite code

## 🚀 Final Step: Delete Core Data Entities (Requires Xcode)

You need to delete these entities from the Core Data model:

### Entities to Delete:
1. **GlassItem** - Only used in deleted repositories
2. **ItemTags** - Only used in deleted repositories
3. **CoatingItem** - Only used in deleted repositories
4. **ToolItem** - Only used in deleted repositories
5. **Item** (parent entity) - Only used as parent of above entities

### Steps in Xcode:

1. **Open the Core Data model**:
   ```
   Molten.xcodeproj → Molten/Molten.xcdatamodeld → Molten 21.xcdatamodel
   ```

2. **Create new model version** (for safe migration):
   - Editor → Add Model Version
   - Name it "Molten 22"
   - Based on: Molten 21
   - Click "Finish"

3. **Set Molten 22 as current version**:
   - Click on `Molten.xcdatamodeld` (the parent)
   - In File Inspector (right panel), set "Current" to "Molten 22"

4. **In Molten 22, delete these entities**:
   - Select "GlassItem" entity → Delete
   - Select "ItemTags" entity → Delete
   - Select "CoatingItem" entity → Delete
   - Select "ToolItem" entity → Delete
   - Select "Item" entity → Delete (parent entity)

5. **Verify .xccurrentversion**:
   ```bash
   cat Molten/Molten.xcdatamodeld/.xccurrentversion
   ```
   Should show: `<string>Molten 22.xcdatamodel</string>`

6. **Clean and rebuild**:
   ```bash
   # Clean DerivedData
   rm -rf ~/Library/Developer/Xcode/DerivedData/Molten-*

   # Rebuild
   xcodebuild -project Molten.xcodeproj -scheme Molten -sdk iphoneos build
   ```

7. **Run tests**:
   ```bash
   xcodebuild test -project Molten.xcodeproj -scheme Molten -testPlan UnitTestsOnly -destination 'platform=iOS Simulator,name=iPhone 15'
   ```

8. **Commit the changes**:
   ```bash
   git add Molten/Molten.xcdatamodeld/.xccurrentversion
   git add "Molten/Molten.xcdatamodeld/Molten 22.xcdatamodel"
   git commit -m "feat: delete unused Core Data catalog entities

   Removed entities that were only used in tests:
   - GlassItem
   - ItemTags
   - CoatingItem
   - ToolItem
   - Item (parent)

   Created new model version (Molten 22) for safe migration.
   Production and tests both use SQLite repositories now.

   🤖 Generated with [Claude Code](https://claude.com/claude-code)

   Co-Authored-By: Claude <noreply@anthropic.com>"
   ```

## Expected Results:

- ✅ Build succeeds
- ✅ Tests pass (using SQLite repositories)
- ✅ Catalog view works in app
- ✅ Core Data model only has user data entities (Inventory, Projects, etc)

## Rollback If Needed:

```bash
# Revert to Molten 21
git checkout HEAD~1 -- Molten/Molten.xcdatamodeld/.xccurrentversion
git checkout HEAD~1 -- "Molten/Molten.xcdatamodeld/Molten 22.xcdatamodel"
```

## Success Criteria:

1. Core Data model no longer has catalog entities
2. Build succeeds without errors
3. Tests pass (validate production SQLite code)
4. App runs and catalog view loads data
5. `grep -r "GlassItem\|ItemTags\|CoatingItem\|ToolItem" Molten/Sources/Repositories` returns NO results (except in SQLite repos)

---

**Note**: This is the final step! After this, the anti-pattern is eliminated and tests validate actual production code.

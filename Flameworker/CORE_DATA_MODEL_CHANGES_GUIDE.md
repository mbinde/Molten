//
//  CORE_DATA_MODEL_CHANGES_GUIDE.md
//  Flameworker
//
//  Created by Assistant on 10/4/25.
//

# Core Data Model Changes Guide 🛡️

This guide will help you safely modify your Core Data model without corrupting your database.

## 🚨 What NOT to Do (What Caused Our Problem)

**NEVER do this:**
1. ❌ Write code that creates entities before adding them to the model file
2. ❌ Modify existing entity attributes without creating a new model version
3. ❌ Delete entities from the model that have existing data
4. ❌ Change attribute types (String → Int) without migration planning

**This is what caused our database corruption:**
```swift
// DON'T DO THIS - PurchaseRecord didn't exist in the model!
let newRecord = PurchaseRecord(context: context)
newRecord.supplier = "Test"  // ← This corrupted the database
```

## ✅ The Correct Workflow

### Step 1: Plan Your Changes
Before touching any code, write down:
- What entities you need to add/modify
- What attributes each entity needs
- Data types for each attribute
- Relationships between entities

### Step 2: Modify the Core Data Model File

#### For New Entities:
1. **Open `Flameworker.xcdatamodel`** in Xcode
2. **Click the "+" button** in the bottom toolbar
3. **Select "Add Entity"**
4. **Name your entity** (e.g., "PurchaseRecord")
5. **Add attributes** by clicking "+" in the Attributes section:
   ```
   supplier: String
   price: Double
   date_added: Date
   notes: String (Optional) ← Check "Optional" box
   type: Int16
   units: Int16
   ```

#### For Existing Entity Changes (Advanced):
**If your app is already released or has important data:**

1. **Select your `Flameworker.xcdatamodeld` file**
2. **Editor Menu → Add Model Version...**
3. **Name it** (e.g., "Flameworker 2")
4. **Make your changes** in the NEW version
5. **Select the `.xcdatamodeld` group** (not individual model)
6. **Set "Current Model Version"** to your new version in the inspector

### Step 3: Configure Code Generation

For each entity, set the **Codegen** option in the inspector:
- **"Class Definition"** (Recommended): Xcode auto-generates everything
- **"Category/Extension"**: You write the class, Xcode generates properties
- **"Manual/None"**: You write everything manually

### Step 4: Clean and Build
1. **Product → Clean Build Folder** (⌘⇧K)
2. **Build your project** (⌘B)
3. **Fix any compilation errors**

### Step 5: Write Your Code
NOW you can safely write code using your entities:
```swift
let newRecord = PurchaseRecord(context: context)
newRecord.supplier = "Test Supplier"
newRecord.price = 100.0
newRecord.date_added = Date()
```

### Step 6: Test Thoroughly
1. **Delete the app** from simulator/device
2. **Install and test** with fresh database
3. **Verify data saves and loads correctly**
4. **Test with existing data** if applicable

## 🔧 Model Versioning Examples

### Example 1: Adding a New Entity (Simple)
```
Current: Flameworker.xcdatamodel
├── CatalogItem entity (existing)

Add PurchaseRecord entity:
1. Open Flameworker.xcdatamodel
2. Add PurchaseRecord entity
3. No version needed (just adding, not changing)
4. Build and test
```

### Example 2: Modifying Existing Entity (Advanced)
```
Current: Flameworker.xcdatamodel
├── CatalogItem entity
    ├── name: String
    ├── code: String
    
Want to add: price: Double to CatalogItem

Steps:
1. Editor → Add Model Version → "Flameworker 2"
2. In Flameworker 2.xcdatamodel:
   - Add price: Double to CatalogItem
3. Set Current Model Version to "Flameworker 2"
4. Add migration options to PersistenceController
5. Test migration thoroughly
```

## 🛡️ Migration Configuration

### Lightweight Migration (Automatic)
For simple changes (adding entities, adding optional attributes):

Add this to your `PersistenceController` init:
```swift
if let description = container.persistentStoreDescriptions.first {
    // Enable automatic migration for simple changes
    description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
    description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
}
```

### Manual Migration (Complex Changes)
For complex changes (changing data types, splitting entities):
1. Create a **mapping model** (.xcmappingmodel file)
2. Write **migration policies** if needed
3. Test extensively with real data

## 📋 Pre-Change Checklist

Before making ANY Core Data model changes:

- [ ] I have planned what entities/attributes I need
- [ ] I have backed up important data (if any)
- [ ] I understand if this needs a new model version
- [ ] I have decided on the migration strategy
- [ ] I will test in simulator first
- [ ] I will not write entity code until model is updated

## 🚨 Emergency Recovery

If you corrupt your database again:
1. **Don't panic** - we have recovery code in PersistenceController
2. **Check the console** for specific error messages
3. **Use the aggressive reset** (already implemented in your init)
4. **Re-load JSON data** after reset

## 💡 Pro Tips

### For Development:
- **Delete simulator app** before testing model changes
- **Use in-memory stores** for unit tests
- **Keep model changes small** and incremental

### For Production:
- **Always test migration** with real user data first
- **Have rollback plan** for complex changes
- **Consider data export/import** for major restructuring

### Common Attribute Types:
```swift
String      // Text data
Int16       // Small numbers (-32,768 to 32,767)
Int32       // Medium numbers 
Int64       // Large numbers
Double      // Decimal numbers
Float       // Smaller decimal numbers
Bool        // True/false
Date        // Timestamps
Data        // Binary data (images, etc.)
UUID        // Unique identifiers
```

## 🔄 Example: Adding PurchaseRecord Safely

Here's exactly how to add the PurchaseRecord entity that caused our issue:

### Step 1: Open Model File
```
1. In Xcode, click on Flameworker.xcdatamodeld
2. You'll see the visual editor with your CatalogItem entity
```

### Step 2: Add Entity
```
1. Click "+" at bottom of editor
2. Choose "Add Entity"
3. Name: "PurchaseRecord"
4. Set Codegen: "Class Definition" (in inspector)
```

### Step 3: Add Attributes
```
Click "+" in Attributes section, add:

supplier
├── Type: String
├── Optional: NO
└── Default: (empty)

price  
├── Type: Double
├── Optional: NO
└── Default: 0

date_added
├── Type: Date
├── Optional: NO
└── Default: (empty)

notes
├── Type: String
├── Optional: YES ← Important!
└── Default: (empty)

type
├── Type: Integer 16
├── Optional: NO
└── Default: 0

units
├── Type: Integer 16
├── Optional: NO
└── Default: 0
```

### Step 4: Build and Test
```
1. ⌘⇧K (Clean)
2. ⌘B (Build)
3. Delete simulator app
4. Run and test
```

### Step 5: Write Code
```swift
// NOW this will work safely:
let purchase = PurchaseRecord(context: context)
purchase.supplier = "Test Supplier"
purchase.price = 100.0
purchase.date_added = Date()
purchase.notes = "Test notes"  // Optional field
purchase.type = 1
purchase.units = 5

try context.save()
```

## 📞 When in Doubt

If you're unsure about a model change:
1. **Start simple** - add entities without relationships first
2. **Test incrementally** - one change at a time
3. **Use version control** - commit before model changes
4. **Ask for help** - better to check than corrupt data

Remember: **Model First, Code Second** - Always update the .xcdatamodel file before writing entity code!
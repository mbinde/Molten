# Recipe Feature - Core Data Model Setup Guide

This guide describes the Core Data entities you need to create in Xcode for the Recipe feature.

## ⚠️ CRITICAL: Store Assignment

**All Recipe entities MUST be in the CLOUD STORE** (not Local Store)

Recipes are user-created data that should sync via CloudKit.

## Required Entities

### 1. Recipe (Abstract Entity)

**Purpose**: Base class for all recipe types

**Configuration**:
- ✅ **Abstract Entity**: YES
- ✅ **Codegen**: Class Definition (automatic)
- ✅ **Store**: Cloud Store

**Attributes**:
| Name | Type | Optional | Default | Notes |
|------|------|----------|---------|-------|
| `id` | UUID | NO | - | Primary key |
| `title` | String | NO | - | Recipe name |
| `descriptionText` | String | YES | "" | Recipe description |
| `dateCreated` | Date | NO | - | Creation timestamp |
| `dateModified` | Date | NO | - | Last modification timestamp |

**Relationships**: None

---

### 2. FritRecipe (Concrete Entity)

**Purpose**: Frit mixing recipes

**Configuration**:
- ✅ **Abstract Entity**: NO
- ✅ **Parent Entity**: Recipe
- ✅ **Codegen**: Class Definition (automatic)
- ✅ **Store**: Cloud Store

**Attributes**:
| Name | Type | Optional | Default | Notes |
|------|------|----------|---------|-------|
| `measurementType` | String | NO | "weight" | "weight" or "ratio" |

**Relationships**:
| Name | Destination | Inverse | Type | Delete Rule |
|------|-------------|---------|------|-------------|
| `ingredients` | FritIngredient | `recipe` | To-Many | Cascade |

**Notes**:
- Inherits `id`, `title`, `descriptionText`, `dateCreated`, `dateModified` from Recipe
- Delete Rule "Cascade" ensures ingredients are deleted when recipe is deleted

---

### 3. FritIngredient (Concrete Entity)

**Purpose**: Individual ingredients in a frit recipe

**Configuration**:
- ✅ **Abstract Entity**: NO
- ✅ **Codegen**: Class Definition (automatic)
- ✅ **Store**: Cloud Store

**Attributes**:
| Name | Type | Optional | Default | Notes |
|------|------|----------|---------|-------|
| `id` | UUID | NO | - | Primary key |
| `stableId` | String | NO | - | References GlassItem (cross-store) |
| `amount` | Double | NO | 0.0 | Quantity (interpretation depends on recipe's measurementType) |

**Relationships**:
| Name | Destination | Inverse | Type | Delete Rule |
|------|-------------|---------|------|-------------|
| `recipe` | FritRecipe | `ingredients` | To-One | Nullify |

**Notes**:
- `stableId` is a **string-based cross-store reference** to GlassItem entity (in Local Store)
- Do NOT create a Core Data relationship to GlassItem (different stores)
- Delete Rule "Nullify" for safety (though recipe should cascade delete ingredients)

---

## Integration with Existing Systems

### Tags (UserTags)

Recipes use the existing `UserTags` system:
- Owner Type: `recipe` (already added to `TagOwnerType` enum)
- Owner ID: `recipe.id.uuidString`
- No Core Data relationship needed - handled by UserTagsRepository

### Images (UserImages)

Recipes use the existing `UserImages` system:
- Owner Type: `recipe` (already added to `ImageOwnerType` enum)
- Owner ID: `recipe.id.uuidString`
- No Core Data relationship needed - handled by UserImageRepository

---

## Step-by-Step Instructions

### 1. Open Core Data Model in Xcode

1. Open `Molten.xcodeproj` in Xcode
2. Navigate to `Molten.xcdatamodeld`
3. Select the current model version (likely `Molten 15` or similar)

### 2. Create Recipe Entity (Abstract)

1. Click **"Add Entity"** button
2. Name it **"Recipe"**
3. In **Data Model Inspector** (right panel):
   - Check ✅ **"Abstract Entity"**
   - Set **Codegen** to **"Class Definition"**
4. Add attributes (click + in Attributes section):
   - `id`: UUID, not optional
   - `title`: String, not optional
   - `descriptionText`: String, optional
   - `dateCreated`: Date, not optional
   - `dateModified`: Date, not optional

### 3. Create FritRecipe Entity

1. Click **"Add Entity"** button
2. Name it **"FritRecipe"**
3. In **Data Model Inspector**:
   - **Parent Entity**: Select "Recipe"
   - **Codegen**: "Class Definition"
4. Add attribute:
   - `measurementType`: String, not optional, default value: "weight"

### 4. Create FritIngredient Entity

1. Click **"Add Entity"** button
2. Name it **"FritIngredient"**
3. In **Data Model Inspector**:
   - **Codegen**: "Class Definition"
4. Add attributes:
   - `id`: UUID, not optional
   - `stableId`: String, not optional
   - `amount`: Double, not optional, default value: 0.0

### 5. Create Relationships

**FritRecipe → FritIngredient**:
1. Select **FritRecipe** entity
2. Add relationship (click + in Relationships section):
   - Name: `ingredients`
   - Destination: `FritIngredient`
   - Type: **To-Many**
   - Delete Rule: **Cascade**

**FritIngredient → FritRecipe**:
1. Select **FritIngredient** entity
2. Add relationship:
   - Name: `recipe`
   - Destination: `FritRecipe`
   - Inverse: `ingredients` (should auto-populate)
   - Type: **To-One**
   - Delete Rule: **Nullify**

### 6. Verify Configuration

**Recipe Entity**:
- [x] Abstract Entity is checked
- [x] Has 5 attributes: id, title, descriptionText, dateCreated, dateModified
- [x] Has 0 relationships

**FritRecipe Entity**:
- [x] Parent Entity is "Recipe"
- [x] Has 1 attribute: measurementType
- [x] Has 1 relationship: ingredients → FritIngredient (To-Many, Cascade)

**FritIngredient Entity**:
- [x] Has 3 attributes: id, stableId, amount
- [x] Has 1 relationship: recipe → FritRecipe (To-One, Nullify)

### 7. Assign to Cloud Store Configuration

**CRITICAL**: Ensure all 3 entities are assigned to the **Cloud Store** in your persistent store configuration.

In `Persistence.swift`, the `cloudStoreDescription` should include these entities.

### 8. Save and Build

1. **Save** the Core Data model (⌘S)
2. **Build** the project to generate Core Data classes
3. Xcode will automatically generate:
   - `Recipe+CoreDataClass.swift`
   - `Recipe+CoreDataProperties.swift`
   - `FritRecipe+CoreDataClass.swift`
   - `FritRecipe+CoreDataProperties.swift`
   - `FritIngredient+CoreDataClass.swift`
   - `FritIngredient+CoreDataProperties.swift`

**DO NOT create these files manually!** They will be generated in `DerivedSources`.

---

## Migration Notes

This adds new entities to the Core Data model, so you'll need to create a new model version:

1. Select `Molten.xcdatamodeld` in Xcode
2. Menu: **Editor → Add Model Version**
3. Name it appropriately (e.g., "Molten 16")
4. Based on: Select current version
5. Add the new entities to this version
6. Set as current version: Select `.xccurrentversion` file, update `_XCCurrentVersionName`

OR simply add to the current version if you're still in development mode with no production data.

---

## Next Steps

After creating the Core Data model:
1. ✅ Return to this chat
2. ✅ I'll implement `CoreDataRecipeRepository`
3. ✅ Update `RepositoryFactory`
4. ✅ Create `RecipeService`
5. ✅ Build the UI

---

## Common Issues

### "Multiple commands produce" error
- **Cause**: Manual Core Data class files conflict with automatic generation
- **Fix**: Delete any manually created `Recipe+CoreDataClass.swift` files, use Codegen only

### "Cannot find type 'Recipe' in scope"
- **Cause**: Build hasn't generated Core Data classes yet
- **Fix**: Clean build folder (⇧⌘K), then build (⌘B)

### Recipes not syncing to CloudKit
- **Cause**: Entities assigned to Local Store instead of Cloud Store
- **Fix**: Check persistent store configuration in `Persistence.swift`

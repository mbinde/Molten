# Core Data Import Cleanup Analysis

**Date:** October 12, 2025  
**Purpose:** Document remaining Core Data dependencies after Repository Pattern Migration  
**Goal:** Identify files that should remove `import CoreData` and convert to repository pattern

## 🎯 **Classification Criteria**

### ✅ **Should KEEP Core Data imports:**
- Core Data repository implementations (`CoreData*Repository.swift`)
- Core Data infrastructure (`Persistence.swift`, `CoreDataHelpers.swift`)
- Migration and diagnostic utilities
- Legacy files marked for deletion (`*_DELETED.swift`)

### ❌ **Should REMOVE Core Data imports:**
- All Views (should use services/view models)
- All Service layer files (should use repositories)
- All Business models (`*Model.swift`)
- All Repository protocols (abstract interfaces)
- All Mock implementations
- Utility files not specifically for Core Data

## 📊 **Scan Results**

### **Files with Core Data Dependencies Found:**

#### **Views (Should be migrated to repository pattern):**
- `InventoryView.swift` (732 lines)
- `AddInventoryItemView.swift` (558 lines)  
- `InventoryItemRowView.swift` (146 lines)

#### **Services/Utilities (Need analysis):**
- `ServiceValidation.swift` (81 lines)
- `CatalogCodeLookup.swift` (122 lines)
- `InventoryUnits.swift` (111 lines)
- `FormComponents.swift` (496 lines)
- `ViewUtilities.swift` (398 lines)

#### **Test Files (May need cleanup):**
- `FetchRequestBuilderTests.swift` (162 lines) - Likely testing deleted code
- `CoreDataRecoveryUtilityTests.swift` (213 lines) - May be legitimate

## 🔍 **Detailed Analysis**

### **1. Views - HIGH PRIORITY for Migration**

#### ❌ **InventoryView.swift** (732 lines)
- **Status**: Legacy backup view (comment: "old Core Data-based InventoryView kept as backup")
- **Action**: Should be renamed to `InventoryViewLegacy_DELETED.swift` or deleted
- **Note**: Repository-based version should exist in `InventoryViewRepository.swift`

#### ❌ **AddInventoryItemView.swift** (558 lines)  
- **Status**: ✅ **MIGRATED** - Updated to use repository pattern with InventoryService and CatalogService
- **Action**: **COMPLETE** - All Core Data dependencies removed, async/await patterns implemented
- **Priority**: ✅ **DONE** - No longer uses Core Data directly

#### ❌ **InventoryItemRowView.swift** (146 lines)
- **Status**: Likely displays Core Data entities directly  
- **Action**: **NEEDS MIGRATION** - Convert to display `InventoryItemModel` instead
- **Priority**: HIGH - Used in inventory listings

### **2. Utilities - MEDIUM PRIORITY**

#### ❌ **ServiceValidation.swift** (81 lines)
- **Status**: Generic validation utility importing Core Data
- **Action**: Remove `import CoreData` - should be pure business logic
- **Priority**: MEDIUM - Easy fix, no Core Data usage expected

#### ❌ **InventoryUnits.swift** (111 lines)  
- **Status**: Enum using `Int16` (Core Data type) and importing Core Data
- **Action**: Remove `import CoreData`, change to `Int` if no Core Data needed
- **Priority**: MEDIUM - Business logic should be persistence-agnostic

#### ❌ **CatalogCodeLookup.swift** (122 lines)
- **Action**: **NEEDS ANALYSIS** - Determine if Core Data usage is legitimate
- **Priority**: MEDIUM

#### ❌ **ViewUtilities.swift** (398 lines)
- **Action**: **NEEDS ANALYSIS** - May contain Core Data view helpers that need migration
- **Priority**: MEDIUM  

#### ❌ **FormComponents.swift** (496 lines)
- **Action**: **NEEDS ANALYSIS** - Form components shouldn't need Core Data
- **Priority**: MEDIUM

### **3. Test Files - LOW PRIORITY**

#### ❌ **FetchRequestBuilderTests.swift** (162 lines)
- **Status**: Tests disabled during repository migration, tests deleted FetchRequestBuilder
- **Action**: Should be deleted or marked `_DELETED.swift`
- **Priority**: LOW - Tests deprecated functionality

#### ✅ **CoreDataRecoveryUtilityTests.swift** (213 lines)  
- **Status**: Legitimately tests Core Data recovery functionality
- **Action**: Keep Core Data import
- **Priority**: KEEP AS-IS

## 📋 **Action Plan**

### **Phase 1: High Priority (Active User-Facing Views)**
1. ✅ **AddInventoryItemView.swift** - **MIGRATED** to repository pattern with InventoryService and CatalogService
2. **InventoryItemRowView.swift** - Update to use models instead of entities  
3. **InventoryView.swift** - Delete or rename as legacy backup

### **Phase 2: Medium Priority (Utilities)**  
1. **ServiceValidation.swift** - Remove unnecessary `import CoreData`
2. **InventoryUnits.swift** - Remove Core Data dependency, use standard types
3. **Analyze remaining utilities** for legitimate vs unnecessary Core Data usage

### **Phase 3: Low Priority (Cleanup)**
1. **Delete deprecated test files** that test removed functionality
2. **Final scan** to ensure no Core Data imports in business logic files

## 🎯 **Success Criteria**
- [ ] All View files use repository pattern (no `@Environment(\.managedObjectContext)`)
- [ ] All Service files use repository interfaces (no direct Core Data)
- [ ] All Model files are pure business logic (no Core Data imports)
- [ ] Only Core Data repositories and infrastructure files import Core Data

## 🚀 **Quick Reference: Repository Pattern Migration**

### **View Migration Pattern:**
```swift
// ❌ OLD: Core Data dependency
@Environment(\.managedObjectContext) private var viewContext
let item = InventoryItem(context: viewContext)

// ✅ NEW: Repository pattern  
private let inventoryService: InventoryService
let item = InventoryItemModel(catalogCode: "...", quantity: 1)
_ = try await inventoryService.addItem(item)
```

### **Files That Should NOT Import Core Data:**
- `*View.swift` - All SwiftUI views
- `*Service.swift` - All service layer files  
- `*Model.swift` - All business model files
- `*Repository.swift` - Repository protocol definitions
- `Mock*Repository.swift` - Mock implementations
- Most utility files

### **Files That SHOULD Import Core Data:**
- `CoreData*Repository.swift` - Core Data implementations
- `Persistence.swift` - Core Data stack setup
- `CoreDataHelpers.swift` - Core Data utilities
- Core Data migration/diagnostic files

# 🔧 Remaining Core Data Migration Tasks

## **🎯 High Priority - Core Views**

### **1. InventoryView.swift** - **Major Migration Required**
- **Current**: Uses `@FetchRequest(entity: InventoryItem.entity())` directly
- **Target**: Use `InventoryViewModel` with repository pattern
- **Impact**: Main inventory interface, heavily used
- **Effort**: Medium - Replace @FetchRequest with InventoryViewModel we already created

### **2. ConsolidatedInventoryDetailView.swift** - **Medium Migration Required**  
- **Current**: Uses `NSFetchRequest<InventoryItem>` for data refresh
- **Target**: Use InventoryService through dependency injection
- **Impact**: Detail view functionality, moderate usage
- **Effort**: Small - Replace fetch requests with service calls

### **3. FormComponents.swift** - **Medium Migration Required**
- **Current**: `CatalogItemSearchField` uses `@FetchRequest(entity: CatalogItem.entity())`
- **Target**: Use CatalogService for search functionality  
- **Impact**: Form components used across app
- **Effort**: Medium - Refactor search to use CatalogService

## **🧹 Low Priority - Cleanup**

### **4. UnifiedCoreDataService.swift** - **Cleanup Required**
- **Current**: `ServiceExampleView` still references old `PurchaseRecord` entity
- **Target**: Remove example view or update to use new services
- **Impact**: Example/preview code only
- **Effort**: Minimal - Delete or update example

## **✅ Migration Benefits:**

**After completing these migrations:**
- **100% repository pattern coverage** across UI layer
- **Zero direct Core Data dependencies** in views  
- **Complete testability** of all UI components
- **Consistent architecture** throughout the app

## **🎯 Recommended Order:**

1. **InventoryView** → Use existing InventoryViewModel (biggest impact)
2. **FormComponents** → Migrate search to CatalogService  
3. **ConsolidatedInventoryDetailView** → Use InventoryService
4. **ServiceExampleView** → Remove or update (cleanup)

## **📊 Current Migration Status:**

- ✅ **Repository Layer**: 100% complete
- ✅ **Service Layer**: 100% complete  
- ✅ **Advanced Features**: 100% complete
- 🔄 **View Layer**: ~70% complete (InventoryViewModel done, views need migration)
- 📋 **Final Cleanup**: ~0% complete

**Completing these migrations will achieve 100% repository pattern adoption!** 🎉
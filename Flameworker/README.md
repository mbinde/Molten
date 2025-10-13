# Flameworker

A Swift inventory management application built with SwiftUI, following strict TDD (Test-Driven Development) practices and clean architecture principles.

## 🏗️ Project Structure Reorganization Proposal

To improve maintainability and scalability, the project should be reorganized into the following directory structure:

### Proposed Directory Structure

```
Flameworker/
├── Sources/
│   ├── App/                        # Application entry point & configuration
│   │   ├── MainTabView.swift       # Main navigation controller
│   │   └── AppDelegate.swift       # App lifecycle management
│   │
│   ├── Models/                     # Business logic & domain models
│   │   ├── Domain/
│   │   │   ├── CatalogItemModel.swift
│   │   │   ├── InventoryItemModel.swift
│   │   │   ├── PurchaseRecordModel.swift
│   │   │   └── WeightUnit.swift
│   │   └── Helpers/
│   │       ├── CatalogItemHelpers.swift
│   │       └── BusinessRules/
│   │
│   ├── Services/                   # Service layer orchestration
│   │   ├── Core/
│   │   │   ├── CatalogService.swift
│   │   │   ├── InventoryService.swift
│   │   │   └── PurchaseRecordService.swift
│   │   ├── Coordination/
│   │   │   ├── EntityCoordinator.swift
│   │   │   └── ReportingService.swift
│   │   └── DataLoading/
│   │       ├── DataLoadingService.swift
│   │       └── JSONDataLoader.swift
│   │
│   ├── Repositories/               # Data persistence layer
│   │   ├── Protocols/
│   │   │   ├── CatalogItemRepository.swift
│   │   │   ├── InventoryItemRepository.swift
│   │   │   └── PurchaseRecordRepository.swift
│   │   ├── CoreData/
│   │   │   ├── CoreDataCatalogRepository.swift
│   │   │   ├── CoreDataInventoryRepository.swift
│   │   │   ├── Persistence.swift
│   │   │   ├── CoreDataHelpers.swift
│   │   │   ├── CoreDataMigrationService.swift
│   │   │   └── CoreDataRecoveryUtility.swift
│   │   └── Mock/
│   │       ├── MockCatalogRepository.swift
│   │       ├── MockInventoryRepository.swift
│   │       └── MockPurchaseRepository.swift
│   │
│   ├── Views/                      # SwiftUI views & UI components
│   │   ├── Catalog/
│   │   │   ├── CatalogView.swift
│   │   │   ├── CatalogItemDetailView.swift
│   │   │   └── Components/
│   │   │       ├── CatalogItemRowView.swift
│   │   │       └── CatalogFilterView.swift
│   │   ├── Inventory/
│   │   │   ├── InventoryView.swift
│   │   │   ├── AddInventoryItemView.swift
│   │   │   └── Components/
│   │   ├── Purchases/
│   │   │   ├── PurchasesView.swift
│   │   │   └── Components/
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift
│   │   │   ├── DataManagementView.swift
│   │   │   ├── COEFilterView.swift
│   │   │   └── ManufacturerFilterView.swift
│   │   ├── ProjectLog/
│   │   │   └── ProjectLogView.swift
│   │   └── Shared/
│   │       ├── Components/
│   │       ├── ViewModifiers/
│   │       └── ViewUtilities/
│   │
│   ├── Utilities/                  # Cross-cutting concerns & helpers
│   │   ├── Search/
│   │   │   ├── SearchUtilities.swift
│   │   │   └── FilterUtilities.swift
│   │   ├── Validation/
│   │   │   └── ValidationUtilities.swift
│   │   ├── Image/
│   │   │   └── ImageHelpers.swift
│   │   ├── Network/
│   │   │   └── NetworkSimulationUtilities.swift
│   │   ├── Error/
│   │   │   └── SimpleErrorHandling.swift
│   │   └── Extensions/
│   │       └── Foundation+Extensions.swift
│   │
│   └── Resources/                  # Static resources & configuration
│       ├── Manufacturers/
│       │   └── GlassManufacturers.swift
│       ├── Data/
│       │   └── SampleData/
│       └── Localization/
│           └── Localizable.strings
│
├── Tests/                          # Test suite organization
│   ├── UnitTests/
│   │   ├── Models/
│   │   │   ├── CatalogItemModelTests.swift
│   │   │   └── BusinessRulesTests.swift
│   │   ├── Services/
│   │   │   ├── CatalogServiceTests.swift
│   │   │   └── DataLoadingServiceTests.swift
│   │   ├── Repositories/
│   │   │   ├── CatalogRepositoryTests.swift
│   │   │   └── InventoryRepositoryTests.swift
│   │   └── Utilities/
│   │       ├── SearchUtilitiesTests.swift
│   │       ├── FilterUtilitiesTests.swift
│   │       └── ValidationTests.swift
│   ├── IntegrationTests/
│   │   ├── IntegrationTests.swift
│   │   ├── CoreDataIntegrationTests.swift
│   │   └── ServiceIntegrationTests.swift
│   ├── PerformanceTests/
│   │   └── AdvancedTestingTests.swift
│   └── ErrorHandlingTests/
│       └── ErrorHandlingTests.swift
│
├── Tools/                          # Development & build tools
│   ├── Scripts/
│   │   ├── csv_to_json_converter.py
│   │   └── image_downloader.py
│   └── Documentation/
│       ├── TEST-COVERAGE.md
│       └── RELEASE_STRATEGY_UPDATED.md
│
└── Package.swift                   # Swift Package Manager configuration
```

## 🎯 Architecture Principles

### **3-Layer Clean Architecture**

**Layer 1: Models (Domain/Business Logic)**
- Business rules applied during construction
- Data validation and normalization  
- Change detection logic
- Domain-specific behavior

**Layer 2: Services (Application/Orchestration)**
- Coordinate repository operations
- Handle async/await patterns
- Cross-entity coordination
- Application-level business flows

**Layer 3: Repositories (Infrastructure/Persistence)**
- Data storage/retrieval
- Technology-specific implementations
- Context and transaction management
- NO business logic

### **🎯 THE GOLDEN RULE:**
**"Business logic lives in the Model layer. Services orchestrate. Repositories persist."**

## 📁 Directory Organization Benefits

### **1. Models Directory**
- **Domain/**: Core business entities with embedded logic
- **Helpers/**: Supporting utilities for business rules
- Clear separation of domain logic from infrastructure

### **2. Services Directory**  
- **Core/**: Primary business services (Catalog, Inventory, Purchase)
- **Coordination/**: Cross-entity coordination services
- **DataLoading/**: Specialized data import services

### **3. Repositories Directory**
- **Protocols/**: Repository interfaces for dependency injection
- **CoreData/**: Core Data specific implementations
- **Mock/**: Test doubles for unit testing

### **4. Views Directory**
- **Feature-based folders**: Catalog/, Inventory/, Settings/
- **Components/**: Reusable UI components within features
- **Shared/**: Cross-feature UI utilities

### **5. Utilities Directory**
- **Single-purpose folders**: Search/, Validation/, Image/
- Clear separation of cross-cutting concerns
- Easy to find and reuse

## 🔄 Migration Benefits

### **Improved Maintainability**
- **Clear file location**: Developers know exactly where to find code
- **Reduced coupling**: Clean separation between layers
- **Easier testing**: Mock repositories enable fast unit tests

### **Better Scalability**  
- **Feature-based organization**: Easy to add new domains
- **Modular structure**: Components can be extracted to packages
- **Clear dependencies**: Services depend on repositories, not vice versa

### **Enhanced Developer Experience**
- **Faster navigation**: Logical grouping reduces search time
- **Clearer responsibilities**: Each directory has a single purpose
- **Better code reviews**: Changes are localized to appropriate areas

## 🚀 Implementation Strategy

### **Phase 1: Directory Structure (Non-breaking)**
1. Create new directory structure
2. Move files to appropriate locations
3. Update imports and references

### **Phase 2: Interface Extraction**
1. Extract repository protocols
2. Create mock implementations
3. Update service dependencies

### **Phase 3: View Component Organization**
1. Split large views into components
2. Create shared UI utilities
3. Organize by feature areas

## 🧪 Testing Strategy

The reorganized structure supports comprehensive testing:

- **Unit Tests**: Test models and utilities in isolation
- **Service Tests**: Use mock repositories for fast testing
- **Integration Tests**: Test repository implementations
- **UI Tests**: Test complete user workflows

---

## 🚀 Current Implementation Status

The project currently uses a **flat file structure** but follows clean architecture principles. Files are organized by type rather than by feature or layer, which can make navigation challenging as the project grows.

### **Current File Organization (To Be Reorganized):**

**Views & UI:** CatalogView.swift, SettingsView.swift, MainTabView.swift, ProjectLogView.swift

**Services:** DataLoadingService.swift, ReportingService.swift, EntityCoordinator.swift

**Core Data:** Persistence.swift, CoreDataHelpers.swift, CoreDataMigrationService.swift, CoreDataRecoveryUtility.swift

**Utilities:** SearchUtilities.swift, CatalogItemHelpers.swift, WeightUnit.swift, ImageHelpers.swift, SimpleErrorHandling.swift, NetworkSimulationUtilities.swift

**Tests:** Comprehensive test suite with 95%+ coverage across multiple test files

## 🚨 Core Data Guidelines

**❌ NEVER CREATE MANUAL CORE DATA FILES**
- Uses Xcode's automatic Core Data code generation
- Manual entity files cause "Multiple commands produce" build conflicts
- Repository implementations reference auto-generated classes directly

## 🔒 Swift 6 Concurrency & Testing

- **Async/await** throughout repository operations
- **Swift Testing** with `#expect()` assertions  
- **Clean concurrency boundaries** via repository pattern
- **Thread-safe** service and utility implementations

## 📋 Development Workflow

**TDD (Test-Driven Development):**
1. **RED:** Write failing test first
2. **GREEN:** Implement simplest solution
3. **REFACTOR:** Improve without changing behavior

**Architecture Verification:**
- Business logic in models ✅
- Services orchestrate operations ✅  
- Repositories handle persistence ✅
- No cross-layer logic duplication ✅

---

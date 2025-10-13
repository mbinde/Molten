# Molten

A Swift inventory management application built with SwiftUI, following strict TDD (Test-Driven Development) practices and clean architecture principles.

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

## 📁 Directory Structure Guidelines

This section documents the organizational scheme for maintaining clean, scalable file structure as the project grows.

### **🏗️ High-Level Directory Decisions**

#### **`Models/`** - Domain Logic & Business Rules
**What Goes Here:** Business models, domain enums, validation logic, business rule implementations
**Decision Criteria:** 
- Contains business logic or domain rules
- Used across multiple features
- Defines "what the business does" rather than "how the UI works"

**Subdirectories:**
- **`Domain/`**: Core business entities (`WeightUnit.swift`, `InventoryItemType.swift`, `CatalogSortOption.swift`)
- **`Helpers/`**: Business logic utilities that support domain models (`CatalogItemHelpers.swift`)

#### **`Services/`** - Orchestration & Coordination
**What Goes Here:** Service layer classes that orchestrate repository operations
**Decision Criteria:**
- Coordinates between repositories and/or external systems  
- Contains async/await orchestration logic
- NO business rule implementation (delegates to models)

**Subdirectories:**
- **`Core/`**: Primary business services (`CatalogService.swift`, `InventoryService.swift`)
- **`Coordination/`**: Cross-entity coordination (`EntityCoordinator.swift`, `ReportingService.swift`)
- **`DataLoading/`**: Specialized data import services (`DataLoadingService.swift`)

#### **`Repositories/`** - Data Persistence
**What Goes Here:** Data storage/retrieval implementations
**Decision Criteria:**
- Handles database, API, or file system operations
- Converts between models and persistence formats
- NO business logic (just storage/retrieval)

#### **`Views/`** - SwiftUI Interface Layer
**What Goes Here:** SwiftUI views, view models, UI components
**Decision Criteria:**
- Renders user interface or handles user interaction
- Feature-specific UI logic
- View state management

#### **`Utilities/`** - Cross-Cutting Concerns
**What Goes Here:** Generic utilities used across multiple features
**Decision Criteria:**
- No business logic specific to one feature
- Pure utility functions (formatting, validation, extensions)
- Could be extracted to separate package

#### **`App/`** - Application Infrastructure
**What Goes Here:** App-level configuration, navigation, entry points, dependency injection
**Decision Criteria:**
- App-wide concerns (navigation structure, lifecycle)
- Not feature-specific
- Core app infrastructure
- Dependency injection and factory patterns

**Subdirectories:**
- **`Configuration/`**: App-wide settings and feature flags (`DebugConfig.swift`)
- **`Navigation/`**: App navigation structure (`DefaultTab.swift`)
- **`Factories/`**: Dependency injection factories (`CatalogViewFactory.swift`)

### **📂 Feature-Based View Organization**

Each feature area under `Views/` follows consistent subdirectory patterns:

#### **Standard Feature Structure:**
```
Views/
├── [FeatureName]/              # e.g., Catalog/, Inventory/, Settings/
│   ├── [MainView].swift        # Primary view for feature
│   ├── [DetailView].swift      # Detail/drill-down views
│   ├── Components/             # Reusable SwiftUI components
│   ├── ViewModels/             # MVVM view models (if used)
│   ├── Helpers/                # Feature-specific non-UI utilities
│   └── Debug/                  # Development/debug views
```

#### **Subdirectory Decision Rules:**

**`Components/`** - Reusable SwiftUI Views
- **What:** SwiftUI view structs that render UI
- **Examples:** `InventoryItemRowView.swift`, `CatalogTagFilterView.swift`, `CatalogToolbarContent.swift`
- **Test:** Could this view be used in multiple places within this feature?

**`ViewModels/`** - MVVM State Management
- **What:** ObservableObject classes managing view state
- **Examples:** `InventoryViewModel.swift`
- **Test:** Does this manage complex state for a view?

**`Helpers/`** - Feature-Specific Non-UI Logic
- **What:** Non-SwiftUI utilities supporting views in this feature
- **Examples:** `CatalogViewHelpers.swift`, `InventorySearchSuggestions.swift`
- **Test:** Is this logic specific to views in this feature (not domain logic)?

**`Debug/`** - Development Tools
- **What:** Debug/development views for this feature
- **Examples:** `CatalogBundleDebugView.swift`
- **Test:** Is this only used during development/debugging?

#### **Quick Decision Tree:**
```
New file for [FeatureName]? Ask:

1. "Is this a SwiftUI view struct?"
   → YES: Does it get reused within this feature?
     → YES: `Views/[Feature]/Components/`
     → NO: `Views/[Feature]/` (main directory)

2. "Is this an ObservableObject managing view state?"
   → YES: `Views/[Feature]/ViewModels/`

3. "Is this non-UI logic supporting this feature's views?"
   → YES: `Views/[Feature]/Helpers/`

4. "Is this only used during development/debugging?"
   → YES: `Views/[Feature]/Debug/`

5. "Could this be used by other features?"
   → YES: `Views/Shared/Components/`

6. "Is this domain logic or business rules?"
   → YES: `Models/Domain/` or `Models/Helpers/`

7. "Is this a cross-cutting utility (search, validation, formatting)?"
   → YES: `Utilities/[Category]/`

8. "Does this orchestrate repository operations?"
   → YES: `Services/Core/` or `Services/Coordination/`

9. "Does this handle data persistence?"
   → YES: `Repositories/CoreData/` or `Repositories/Mock/`

10. "Is this app-wide configuration or navigation?"
    → YES: `App/` (main directory)

11. "Is this dependency injection or factory pattern?"
    → YES: `App/Factories/`

12. "Is this app-wide configuration settings?"
    → YES: `App/Configuration/`

If none apply: Start with the main feature directory and refactor later.
```

#### **Shared vs Feature-Specific Decision:**

**Use `Views/Shared/Components/`** when:
- Component could be used across multiple features
- Generic form fields, common UI patterns
- Examples: `LocationAutoCompleteField.swift`, `QuantityInputField.swift`

**Use `Views/[Feature]/Components/`** when:
- Component is specific to one feature domain
- Contains feature-specific business logic
- Examples: `CatalogItemRowView.swift`, `PurchaseRowView.swift`

### **🔄 File Lifecycle Guidelines**

#### **When to Split Files:**
- File exceeds 600-700 lines
- Multiple unrelated responsibilities in one file
- Reusable components can be extracted

#### **When to Create New Subdirectories:**
- 3+ files of the same type accumulate
- Clear logical grouping emerges
- Different concerns need separation

#### **Migration Path:**
1. **Start simple**: Place files in main feature directory
2. **Identify patterns**: Watch for groupings of similar files  
3. **Extract when clear**: Create subdirectories when patterns emerge
4. **Maintain consistency**: Follow established patterns for similar features

This structure scales from simple features (few files in main directory) to complex features (multiple subdirectories) while maintaining consistent organization principles.

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

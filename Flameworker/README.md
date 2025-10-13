# 🏗️ ARCHITECTURAL PATTERNS - CORE PRINCIPLES

## 📋 Repository Pattern with Clean Architecture

We follow a strict **3-layer architecture** that separates business logic from persistence concerns:

### **Layer 1: Model Layer (Business Logic)**
```swift
// ✅ CORRECT: Business rules applied during model construction
let item = CatalogItemModel(
    name: "Red Glass Rod",
    rawCode: "RGR-001",           // Raw input
    manufacturer: "Bullseye"
)
// Result: item.code = "BULLSEYE-RGR-001" (business rule applied)
```

**Responsibilities:**
- Apply business rules during construction (`constructFullCode()`, tag formatting)
- Handle data validation and normalization
- Provide change detection logic (`hasChanges()`)
- Maintain data integrity constraints

### **Layer 2: Service Layer (Orchestration)**
```swift
// ✅ CORRECT: Service orchestrates, doesn't re-process
class CatalogService {
    func createItem(_ item: CatalogItemModel) async throws -> CatalogItemModel {
        // Item already has processed code from constructor - just pass it through
        return try await repository.createItem(item)
    }
}
```

**Responsibilities:**
- Orchestrate repository operations
- Handle async/await patterns
- Coordinate between multiple repositories if needed
- Delegate business logic to models, NOT re-implement it

### **Layer 3: Repository Layer (Persistence)**
```swift
// ✅ CORRECT: Repository handles persistence, not business logic
class CoreDataCatalogRepository: CatalogItemRepository {
    func createItem(_ item: CatalogItemModel) async throws -> CatalogItemModel {
        // Convert model to Core Data entity and save
        let coreDataItem = // ... Core Data creation logic
        coreDataItem.code = item.code  // Use already-processed code
        // ... persistence logic
    }
}
```

**Responsibilities:**
- Handle persistence technology (Core Data, databases, APIs)
- Convert between models and persistence objects
- Manage contexts, connections, and transactions
- NO business logic - just data storage/retrieval

### **❌ ANTI-PATTERNS TO AVOID:**

```swift
// ❌ WRONG: Service re-processing data (business logic in wrong layer)
func createItem(_ item: CatalogItemModel) async throws -> CatalogItemModel {
    let processedItem = CatalogItemModel(
        name: item.name,
        rawCode: item.code,  // This re-processes already processed data!
        manufacturer: item.manufacturer
    )
    return try await repository.createItem(processedItem)
}

// ❌ WRONG: Repository implementing business logic
class CoreDataCatalogRepository {
    func createItem(_ item: CatalogItemModel) async throws -> CatalogItemModel {
        let fullCode = "\(item.manufacturer.uppercased())-\(item.code)"  // Business logic in wrong layer!
        coreDataItem.code = fullCode
    }
}

// ❌ WRONG: Models that are just data containers (anemic domain model)
struct CatalogItemModel {
    let name: String
    let code: String  // Just a dumb container, no business logic
}
```

### **🎯 THE GOLDEN RULE:**

**"Business logic lives in the Model layer. Services orchestrate. Repositories persist."**

- **Model constructors** apply business rules once, correctly
- **Services** trust that models are already properly formed
- **Repositories** trust that models contain valid, business-rule-compliant data
- **No layer re-implements logic from another layer**

### **✅ VERIFICATION PATTERN:**

When you see build errors or logic duplication, ask:
1. **Where should this business logic live?** (Usually: Model constructor)
2. **Is this layer doing its job or someone else's job?** 
3. **Am I re-processing data that's already been processed?**

This pattern ensures:
- **Single Responsibility**: Each layer has one clear job
- **No Duplication**: Business logic exists in exactly one place  
- **Easy Testing**: Mock repositories, test business logic in isolation
- **Clean Code**: Clear separation of concerns, easy to understand and maintain

---

# Flameworker

A Swift inventory management application built with SwiftUI, following strict TDD (Test-Driven Development) practices and maintainable code principles.


### Project Structure

```
Flameworker/
├── FlameworkerTests/               # Unit tests directory (95-98% coverage)
│   ├── CoreDataHelpersTests.swift  # Core Data utility tests
│   ├── InventoryDataValidatorTests.swift # Data validation tests
│   ├── ViewUtilitiesTests.swift    # UI utility tests
│   ├── SearchUtilitiesTests.swift  # Search engine tests
│   ├── FilterUtilitiesTests.swift  # Filter logic tests
│   ├── AdvancedTestingTests.swift  # Performance & edge cases
│   ├── IntegrationTests.swift      # Component integration
│   └── DataLoadingServiceTests.swift # Data loading tests
├── FlameworkerUITests/             # UI tests directory
│   └── FlameworkerUITests.swift    # UI automation tests
├── Core Services/
│   ├── DataLoadingService.swift    # JSON data loading with retry logic
│   ├── CoreDataHelpers.swift       # Core Data utilities with safety patterns
│   ├── UnifiedCoreDataService.swift # Core Data management with batch operations
│   └── SearchUtilities.swift       # High-performance search engine ⭐
├── View Utilities/
│   ├── ViewUtilities.swift         # Common view patterns with async support
│   ├── UIStateManagers.swift       # Loading/Selection/Filter state management
│   └── InventoryViewComponents.swift # Inventory UI components
├── Views/
│   ├── CatalogView.swift          # Main catalog interface
│   └── ColorListView.swift       # Color management UI
└── Utilities/
    ├── GlassManufacturers.swift   # Manufacturer mapping utilities
    ├── ValidationUtilities.swift  # Input validation with error handling
    └── ImageHelpers.swift         # Image loading with caching
```
---

---

## 🚨 CRITICAL: Core Data Automatic Code Generation Policy

### **❌ NEVER CREATE MANUAL CORE DATA FILES**

This project uses **Xcode's automatic Core Data code generation**. Manual entity files will cause build conflicts.

Whenever you, Claude, are editing code, the entities and their properties have always already been created and the code generation has been done.

**✅ CORRECT PROCESS:**
1. **Repository code references auto-generated classes** directly

**❌ NEVER CREATE:**
- `Entity+CoreDataClass.swift` files
- `Entity+CoreDataProperties.swift` files
- Manual NSManagedObject subclasses

**⚠️ BUILD ERRORS:** Manual files cause "Multiple commands produce" compilation failures.

### **For Core Data Repository Implementations Only:**

1. **Model Management** - Only project owner modifies `.xcdatamodeld` files
2. **Entity Extensions** - Create `Entity+Extensions.swift` for computed properties (if needed)
3. **Test Isolation** - Use isolated contexts for Core Data infrastructure tests
4. **Repository Pattern** - Most code should use repositories, not Core Data directly

### **✅ Repository Pattern Benefits:**
- **Business logic tests** use mock repositories (no Core Data needed)
- **Integration tests** use mock data structures (no persistence complexity)
- **View layer** uses services and models (no Core Data dependencies)

**Key Principle:** Only Core Data repository implementations and infrastructure should import Core Data.

---

## 🔒 Swift 6 Concurrency Guidelines

### **Simple Rules:**

1. **Keep enums simple** - No complex annotations, let Swift handle isolation naturally
2. **Use `async/await` for repository operations** - Clean async boundaries in service layer  
3. **Test with `#expect()`** - Works naturally with Swift 6 concurrency
4. **Avoid over-annotating** - Don't add `@MainActor` or `nonisolated` unless required

### **Repository Pattern Async Example:**

```swift
class CatalogService {
    private let repository: CatalogItemRepository
    
    func createItem(_ item: CatalogItemModel) async throws -> CatalogItemModel {
        // Clean async boundary - repository pattern handles isolation
        return try await repository.createItem(item)
    }
}
```

**✅ Key Principle:** Repository pattern architecture naturally prevents most Swift 6 concurrency issues through clean separation of concerns.

#### **🔧 Development Guidelines:**

**When implementing any functionality:**
- ✅ Use simple, flat data structures
- ✅ Add comprehensive nil checking and guards
- ✅ Test each feature incrementally 
- ✅ Use Foundation's optimized string comparison methods

---

#### When to Add to Existing vs Create New Files

**✅ ADD to Existing Files When:**
- Feature extends existing functionality
- Test fits existing file's purpose (see descriptions above)  
- File is under 600 lines
- Functionality overlaps with existing tests

**⚠️ CREATE New File When:**
- New major feature area (e.g., Reporting system → `ReportingTests.swift`)
- File exceeds 700 lines (split into logical sub-components)
- Completely new business domain (e.g., User Management, Analytics)
- Distinct technology integration (e.g., CloudKit, Core ML)

#### File Size Guidelines
- **Minimum viable:** 100+ lines (don't create tiny files)
- **Optimal range:** 300-600 lines (easy to navigate)
- **Maximum recommended:** 700 lines (split if larger)  
- **Emergency maximum:** 800 lines (immediate split required)

#### Naming Conventions
- **Business Logic:** `[ComponentName]BusinessLogicTests.swift`
- **UI/Interactions:** `[ComponentName]UITests.swift` or `[ComponentName]InteractionTests.swift`
- **Integration:** `[ComponentName]IntegrationTests.swift`
- **System-wide:** `[FunctionalArea]Tests.swift`

#### Organization Principles
- **One responsibility per file** - Clear, single purpose
- **Logical grouping** - Related functionality together
- **Business logic vs UI separation** - Keep concerns separate
- **No duplicate test scenarios** - Each test exists in exactly one place

### 3. Test Categories

- **Unit Tests**: Test individual methods/classes in isolation
- **Integration Tests**: Test component interactions
- **Edge Cases**: Test boundary conditions, empty inputs, error states

**Remember:** The goal is maintainable, well-tested code. Write the simplest code that passes the tests, then refactor for clarity. Every feature should have corresponding tests before implementation.

######### Prompt #########

You're my strict TDD pair programmer. We are writing in Swift and following Swift best practices for maintainable code. We're following red/green/refactor at every step. Here's the workflow I want you to follow for every request:

🟥 RED:

Write a failing test for the next smallest unit of behavior.

Do not write any implementation code yet.

Explain what the test is verifying and why.

Label this step: # RED

🟩 GREEN:

Implement the simplest code to make the test pass.

Avoid overengineering or anticipating future needs.

Confirm that all tests pass (existing + new).

Label this step: # GREEN

✅ Commit message (only after test passes):
"feat: implement [feature/behavior] to pass test"

🛠 REFACTOR:

During REFACTOR, do NOT change anything besides any necessary updates to the README. Instead, help me plan to refactor my existing code to improve readability, structure, or performance.

When I am ready, proceed again to RED.

IMPORTANT:

No skipping steps.

Implement the simplest code possible.

Avoid introducing warnings whenever possible.

No test-first = no code.

Only commit on clean GREEN.

Each loop should be tight and focused, no solving 3 things at once.

If I give you a feature idea, you figure out the next RED test to write.

Avoid overengineering or anticipating future needs.

Don't duplicate code or data structures -- look for existing implementations first. 

When adding new tests, first consider whether they fit best in an existing testing file before creating a new one. Tests should be grouped logically so they're easy to find, reason about, and can share code appropriately.

We follow a strict **3-layer architecture** that separates business logic from persistence concerns:

### **🎯 THE GOLDEN RULE:**

**"Business logic lives in the Model layer. Services orchestrate. Repositories persist."**

- **Model constructors** apply business rules once, correctly
- **Services** trust that models are already properly formed
- **Repositories** trust that models contain valid, business-rule-compliant data
- **No layer re-implements logic from another layer**

### **✅ VERIFICATION PATTERN:**

When you see build errors or logic duplication, ask:
1. **Where should this business logic live?** (Usually: Model constructor)
2. **Is this layer doing its job or someone else's job?** 
3. **Am I re-processing data that's already been processed?**

This pattern ensures:
- **Single Responsibility**: Each layer has one clear job
- **No Duplication**: Business logic exists in exactly one place  
- **Easy Testing**: Mock repositories, test business logic in isolation
- **Clean Code**: Clear separation of concerns, easy to understand and maintain

######### End Prompt #########

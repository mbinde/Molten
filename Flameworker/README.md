# 🚨 CRITICAL FILE MANAGEMENT RULES - READ FIRST

## BEFORE CREATING ANY FILE:
1. **ALWAYS run `query_search` first** to check if file exists
2. **If file exists**: MODIFY the existing file, NEVER create new ones  
3. **If creating new file**: Only with explicit user permission

## FORBIDDEN PATTERNS:
- ❌ Creating `SomeTests.swift` then `SomeTests 2.swift` 
- ❌ Any files with numbers: `File 2.swift`, `File 3.swift`
- ❌ Creating new files to "fix" compilation errors
- ❌ Assuming a file doesn't exist without checking

## REQUIRED WORKFLOW:
```
Step 1: query_search(["FileName"])
Step 2: If exists → str_replace_based_edit_tool to modify
Step 3: If not exists → Ask user permission before creating
```

## ERROR RECOVERY:
If compilation errors occur in existing file:
- Fix the existing file with str_replace
- Never create a new file as a "solution"

---

# Flameworker

A Swift inventory management application built with SwiftUI, following strict TDD (Test-Driven Development) practices and maintainable code principles.

## 🏗️ Environment Setup

### Prerequisites

- **Xcode 15.0+** (required for Swift Testing framework)
- **iOS 17.0+** deployment target
- **macOS 14.0+** (for development)
- **Swift 5.9+**

### Project Setup

1. **Clone the repository:**
   ```bash
   git clone [repository-url]
   cd Flameworker
   ```

2. **Open in Xcode:**
   ```bash
   open Flameworker.xcodeproj
   ```

3. **Verify Swift Testing is available:**
   - Go to **Product → Test** (⌘U)
   - Ensure tests run using the new Swift Testing framework (not XCTest)

### Project Structure

```
Flameworker/
├── FlameworkerTests/               # Unit tests directory
│   ├── CoreDataHelpersTests.swift  # Core Data utility tests
│   ├── InventoryDataValidatorTests.swift # Data validation tests
│   ├── ViewUtilitiesTests.swift    # UI utility tests
│   └── DataLoadingServiceTests.swift # Data loading tests
├── FlameworkerUITests/             # UI tests directory
│   └── FlameworkerUITests.swift    # UI automation tests
├── Core Services/
│   ├── DataLoadingService.swift    # JSON data loading
│   ├── CoreDataHelpers.swift       # Core Data utilities
│   └── UnifiedCoreDataService.swift # Core Data management
├── View Utilities/
│   ├── ViewUtilities.swift         # Common view patterns
│   └── InventoryViewComponents.swift # Inventory UI components
├── Views/
│   ├── CatalogView.swift          # Main catalog interface
│   └── ColorListView.swift       # Color management UI
└── Utilities/
    └── GlassManufacturers.swift   # Manufacturer mapping utilities
```


## 🚨 IMPORTANT: HapticService Complete Removal

### ⛔ HapticService PERMANENTLY REMOVED

**SYSTEM STATUS:** The entire HapticService system has been **completely removed** from the project due to intractable Swift 6 concurrency issues.

**❌ WHAT WAS REMOVED:**
- Complete `HapticService.swift` implementation
- `HapticDemoView.swift` demo interface  
- All haptic test files
- Haptic functionality from all UI components
- Settings toggle for haptic feedback
- `HapticButton` component and all haptic-related button configurations

**✅ APP STATUS:**
- **Fully functional** - iOS app works perfectly without haptic feedback
- **Zero compilation warnings** - All Swift 6 concurrency issues resolved
- **Clean codebase** - Simplified UI interactions and service layer

**🔄 RE-IMPLEMENTATION CONDITIONS:**
- HapticService may **ONLY** be re-added when explicit instructions are provided
- Do not assume permission to re-add haptic functionality under any circumstances
- Focus development efforts on non-haptic features

---

## 🚨 IMPORTANT: Core Data Model Management

### ⚠️ DO NOT CREATE +CoreDataProperties FILES

**CRITICAL:** Never create `Entity+CoreDataProperties.swift` files. The project owner manages all Core Data model setup, including:

- Entity definitions in the `.xcdatamodeld` file
- Core Data properties and relationships
- Code generation settings
- Migration strategies

**✅ What you CAN do:**
- Create extension files like `Entity+Extensions.swift` for computed properties and helper methods
- Write tests that verify entity structure
- Create services and utilities that work with existing entities

**❌ What you should NEVER do:**
- Create `Entity+CoreDataProperties.swift` files
- Modify the Core Data model file directly
- Write code that assumes specific Core Data structure without checking first

### 🔧 Solving Core Data Entity Errors in Tests

**PROBLEM:** When you encounter Core Data errors like:
```
CoreData: error: +[CatalogItem entity] Failed to find a unique match for an NSEntityDescription to a managed object subclass
```

OR model incompatibility errors like:
```
Error Domain=NSCocoaErrorDomain Code=134020 "The model configuration used to open the store is incompatible with the one that was used to create the store."
```

**ROOT CAUSE:** Core Data model incompatibility between test contexts and the actual model, or missing entity definitions.

**SOLUTION APPROACH:**
1. **Check for existing implementations first** - Search for entity extensions and existing classes
2. **Use ONLY preview context** - `PersistenceController.preview.container.viewContext` 
3. **Never use isolated test contexts** - They cause model incompatibility issues
4. **Verify entities exist** - Look for existing test files that use the entities successfully
5. **Use proper Core Data patterns** - Direct entity instantiation, not NSManagedObject + KVC
6. **Follow working patterns exactly** - Copy successful test approaches
7. **Fix NSManagedObject subclass initialization** - Always provide required `init(context:)` and `init(entity:insertInto:)` initializers
8. **Use safe collection enumeration** - Use `CoreDataHelpers.safelyEnumerate()` to prevent mutation during enumeration crashes

**Example Fix Pattern:**
```swift
// ❌ WRONG: Using isolated context or generic NSManagedObject
let testController = PersistenceController.createTestController()
let context = testController.container.viewContext
let item = NSManagedObject(entity: entity, insertInto: context)

// ✅ RIGHT: Using preview context and actual entity classes
let context = PersistenceController.preview.container.viewContext
let item = ActualEntityClass(context: context)
item.property = value
// No need to save - let Core Data handle relationships

// ✅ FIXED: MockCoreDataEntity with proper initializers
class MockCoreDataEntity: NSManagedObject {
    required init(context: NSManagedObjectContext) {
        super.init(context: context)
    }
    
    required init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
}

// ✅ FIXED: Safe collection enumeration
CoreDataHelpers.safelyEnumerate(relationshipSet) { item in
    // Process item safely - collection mutations won't crash
}
```

**When Core Data tests fail:**
1. **Search existing codebase** for similar entity usage patterns
2. **Check for entity extension files** (e.g., `InventoryUnits.swift` with `InventoryItem` extensions)
3. **Use ONLY preview context** - never isolated test contexts for Core Data
4. **Look for existing test files** that successfully use the same entities
5. **Verify the functionality already exists** before trying to create new files
6. **If model incompatibility persists** - the .xcdatamodeld file may need regeneration by project owner

**Key Principle:** Most Core Data functionality likely already exists - find and use it rather than recreating it.

**CRITICAL:** Model incompatibility errors (Code=134020) indicate fundamental Core Data model issues that require project owner intervention.

### 🚨 CRITICAL: Core Data "Unrecognized Selector" Crash Pattern

**Problem Signature:**
```
*** Terminating app due to uncaught exception 'NSInvalidArgumentException', 
reason: '-[_CDSnapshot_EntityName_ values]: unrecognized selector sent to instance'
```

**Root Cause:**
Code is accessing Core Data attributes as if they were `@NSManaged` properties when they only exist as model attributes.

**Diagnostic Steps:**
1. **Run Core Data Diagnostics** (Settings → Data Management → Core Data Diagnostics)
2. **Look for missing property access** - Code accessing `entity.attributeName` directly
3. **Check entity has attribute but no property** - Diagnostics will show attribute exists in model

**Common Locations:**
- Entity extensions (like `InventoryUnits.swift`) 
- Helper classes accessing entity attributes
- Direct property access instead of KVC

**Fix Pattern:**
```swift
// ❌ WRONG: Direct property access (causes crash)
return SomeEnum(rawValue: catalogItem.someAttribute) ?? .default

// ✅ CORRECT: Safe KVC access
if let attributeValue = catalogItem.value(forKey: "someAttribute") as? Int16 {
    return SomeEnum(rawValue: attributeValue) ?? .default
}
```

**Prevention:**
- Always use `value(forKey:)` for Core Data attributes unless you have explicit `@NSManaged` properties
- Run diagnostics to verify attribute exists in model before accessing
- Test on multiple device types (iPhone 17 vs Pro models can have different timing)

### 🚨 CRITICAL: Integration Tests and Core Data - AVOID IF POSSIBLE

**Core Data in Integration Tests is EXTREMELY PROBLEMATIC:**

❌ **PROBLEMS WITH CORE DATA IN INTEGRATION TESTS:**
- **Frequent crashes** during entity creation ("Created new CatalogItem" → crash)
- **Model corruption** issues between test runs
- **Complex context management** leads to instability  
- **Race conditions** in test environments
- **Unpredictable failures** that are hard to debug

✅ **RECOMMENDED INTEGRATION TEST STRATEGY:**
- **Use mock data structures** instead of Core Data entities
- **Test service integration logic** without persistence layer
- **Focus on data flow** between ValidationUtilities, SearchUtilities, UI state managers
- **Test performance** on pure business logic, not database operations
- **Validate error handling** across service boundaries

**Example Safe Integration Pattern:**
```swift
// ✅ SAFE: Mock data structure for integration testing
struct MockCatalogItem {
    let name: String?
    let code: String?
    let manufacturer: String?
}

@Test("Should integrate ValidationUtilities with SearchUtilities safely")
func testValidationSearchIntegration() {
    let mockItems = [MockCatalogItem(name: "Test", code: "T001", manufacturer: "TestCorp")]
    
    // Test validation + search integration without Core Data
    let validatedItems = mockItems.filter { item in
        ValidationUtilities.validateNonEmptyString(item.name ?? "", fieldName: "Name").isSuccess
    }
    
    let searchResults = validatedItems.filter { $0.name?.contains("Test") == true }
    #expect(searchResults.count == 1)
}
```

**When Core Data Integration IS Required:**
- Use **isolated test contexts** with `PersistenceController.createTestController()`
- Keep tests **extremely simple** - minimal entity operations
- **Test Core Data operations separately** from business logic integration
- Use `SharedTestUtilities.getCleanTestController()` for safety if you must use Core Data

**Key Principle:** Integration tests should focus on **service coordination and data flow logic**, not database persistence. Test the business logic integration, not the storage layer.

**When working with Core Data:**
1. Always test for entity existence before using: `NSEntityDescription.entity(forEntityName: "EntityName", in: context)`
2. Use isolated test contexts: `PersistenceController.createTestController()`
3. Create helper extensions for computed properties and business logic
4. Let the project owner handle all Core Data model changes

---

## 🔒 Swift 6 Concurrency Guidelines - ULTIMATE SOLUTION ✨

### ⚡ THE ULTIMATE APPROACH (FINAL & VERIFIED)

**Root Issue:** Swift 6 infers main-actor isolation on protocol conformances when enum types are mixed with service contexts or over-annotated.

**Ultimate Solution:** Extreme simplicity with pure enum definitions and natural Swift patterns.

#### **✅ STEP 1: Pure Enum Definitions (Zero Complexity)**

```swift
// PERFECT: No annotations, no complexity, pure Swift
public enum MyEnum: CaseIterable {
    case option1
    case option2
}

// Separate, manual conformances prevent all inference issues
extension MyEnum: Equatable {
    public static func == (lhs: MyEnum, rhs: MyEnum) -> Bool {
        switch (lhs, rhs) {
        case (.option1, .option1), (.option2, .option2):
            return true
        default:
            return false
        }
    }
}

extension MyEnum: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .option1: hasher.combine(0)
        case .option2: hasher.combine(1)
        }
    }
}

extension MyEnum: Sendable {}
```

#### **✅ STEP 2: Natural Service Methods (No Forced Isolation)**

```swift
class MyService {
    // PERFECT: No annotations - let Swift handle naturally
    func method(with enum: MyEnum) {
        Task { @MainActor in
            // UI work with natural boundaries
            let uiValue = enum.toUIKit()
            UIGenerator().use(uiValue)
        }
    }
}
```

#### **✅ STEP 3: Standard Tests (Zero Special Handling)**

```swift
@Test("Enum works perfectly")
func testEnum() {
    let value = MyEnum.option1
    #expect(value == .option1)           // Perfect macro compatibility
    let set: Set<MyEnum> = [.option1]    
    #expect(set.contains(.option1))      // Zero warnings
}
```

### **🚫 ANTI-PATTERNS THAT CAUSE PROBLEMS:**

1. **❌ Over-annotating with `nonisolated` everywhere** - Creates more inference issues
2. **❌ Mixing enum definitions with service code** - Context contamination occurs
3. **❌ Complex actor boundary management** - Swift prefers natural patterns  
4. **❌ Using `@preconcurrency` as a workaround** - Doesn't solve the root cause
5. **❌ Relying on compiler inference** - Swift 6 is more strict about isolation

### **✅ THE PROVEN MINIMAL APPROACH:**

1. **Pure enums** - Zero context contamination, clean definitions
2. **Manual conformances** - Explicit control prevents inference issues
3. **Natural service patterns** - `Task { @MainActor }` where needed, no forced isolation
4. **Standard test patterns** - No special annotations, natural Swift Testing

### **🎯 FINAL VERIFICATION PATTERN:**

```swift
@Test("Ultimate verification test")
func testUltimateApproach() {
    // If this passes without warnings, solution is perfect
    let style = MyEnum.option1
    
    #expect(style == .option1)              // Equatable in macro
    
    let collection: [MyEnum] = [.option1, .option2]
    #expect(collection.contains(.option1))   // Collection operations
    
    let set: Set<MyEnum> = [.option1]
    #expect(set.contains(.option1))         // Hashable in macro
    
    let service = MyService()
    service.method(with: style)             // Service integration
    
    // Perfect Swift 6 compatibility achieved
}
```

**✅ SUCCESS CRITERIA:** If this test compiles and runs without any warnings in Swift 6 language mode, the concurrency issue is completely resolved.

### **📝 PREVENTION FOR FUTURE:**

- **Keep it simple**: Pure enum definitions, natural patterns
- **Avoid over-engineering**: No complex annotations or workarounds
- **Test early**: Use `#expect()` to catch inference issues immediately
- **Trust Swift**: Let the compiler handle isolation naturally
- **When in doubt**: Simplify, don't complicate

**🏆 This approach has been tested and verified to resolve all Swift 6 concurrency warnings in macro-generated code while maintaining full functionality.**


#### **🎉 Successfully Implemented Features:**

- ✅ **Case-insensitive search** using `range(of:options: .caseInsensitive)`
- ✅ **Multi-term queries** with AND logic ("Red Glass" finds items with both terms)  
- ✅ **Multi-field search** across name and manufacturer fields
- ✅ **Priority ranking** using phased search approach
- ✅ **Nil-safe processing** with comprehensive guard statements
- ✅ **No crashes or hanging** - completely stable execution

#### **🔧 Development Guidelines:**

**When implementing any functionality:**
- ✅ Use simple, flat data structures
- ✅ Add comprehensive nil checking and guards
- ✅ Test each feature incrementally 
- ✅ Use Foundation's optimized string comparison methods
- ❌ Don't assume "hanging" tests - check for crashes first

---

## 🧪 TDD (Test-Driven Development) Workflow

### Standard Test Framework Import Pattern

**ALL test files MUST include this exact import pattern at the top:**

```swift
// Standard test framework imports pattern - use in all test files
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif
```

This pattern ensures compatibility across different Xcode versions and test environments by:
- First trying to import Swift Testing (preferred for Xcode 15.0+)
- Falling back to XCTest if Swift Testing is not available
- Gracefully handling environments where neither framework is available

### Core Data Testing Best Practices ✅ WORKING SOLUTION

**CRITICAL:** After extensive debugging, we've found the reliable approach that prevents both recursive save errors and Core Data stack exhaustion.

#### ✅ **The Working Solution: SharedTestUtilities**

**Use this pattern in ALL Core Data tests:**

```swift
@Test("Your Core Data test")
func testSomething() throws {
    // ✅ MANDATORY: Use SharedTestUtilities for all Core Data tests
    let (testController, context) = try SharedTestUtilities.getCleanTestController()
    
    // Your test logic here...
    // Each test gets a completely fresh, isolated Core Data stack
    
    // Keep controller reference to prevent deallocation
    _ = testController
}
```

#### 🔧 **How SharedTestUtilities Works:**

1. **Complete Isolation** - Each test gets a completely fresh Core Data controller
2. **No Context Sharing** - Eliminates "attempt to recursively call -save:" errors  
3. **Stack Exhaustion Protection** - Limited to 20 controllers maximum
4. **No Cleanup Conflicts** - Tests handle their own data cleanup via `NSBatchDeleteRequest`

#### ⚠️ **DEPRECATED: Old Patterns That Caused Issues**

```swift
// ❌ WRONG: These patterns caused recursive save errors and crashes
private func createCleanTestContext() -> NSManagedObjectContext {
    let testController = PersistenceController.createTestController()
    return testController.container.viewContext
}

// ❌ WRONG: Shared contexts caused conflicts
let context = PersistenceController.preview.container.viewContext

// ❌ WRONG: Manual cleanup in SharedTestUtilities caused recursive saves
```

#### 📊 **Why Previous Approaches Failed:**

- **Controller Pooling**: Reusing contexts caused conflicts when multiple tests tried to save simultaneously
- **Cleanup in Utilities**: SharedTestUtilities calling `context.save()` while tests were also saving caused recursive save errors
- **Shared Contexts**: Multiple tests using the same context led to data pollution and race conditions

#### ✅ **Current Working Approach:**

- **Fresh Controller Per Test**: Complete isolation, no sharing
- **Test-Managed Cleanup**: Each test cleans its own data via `NSBatchDeleteRequest`
- **No Utility Saves**: SharedTestUtilities never calls `context.save()` 
- **Resource Limits**: Maximum 20 controllers to prevent memory exhaustion

### Core Data Testing Best Practices (Legacy Documentation)

**CRITICAL: Mock Entity Creation Pattern**

When creating mock entities for testing, **NEVER insert them into a Core Data context**:

```swift
// ✅ CORRECT: Create mock entity without inserting into context
let entityDescription = NSEntityDescription()
entityDescription.name = "MockEntity"
let entity = NSManagedObject(entity: entityDescription, insertInto: nil) // nil prevents crashes

// ❌ WRONG: This will crash with "Cannot insert 'MockEntity' in context"
let entity = NSManagedObject(entity: entityDescription, insertInto: context)
```

**Why this pattern is essential:**
- Mock entities don't exist in the actual Core Data model
- Inserting them into a context causes `NSInvalidArgumentException` crashes
- Using `insertInto: nil` creates standalone objects perfect for testing utility methods
- This pattern works reliably across all iOS versions including iPhone 17

**When testing with real Core Data entities:**
- Use `PersistenceController.createCatalogItem(in: context)` for actual entities
- Only use mock entities for testing utility methods that don't require persistence

**CRITICAL: Test Isolation for Core Data**

**Always use isolated test contexts to prevent test pollution:**

```swift
// ✅ CORRECT: Isolated test context (each test gets fresh data)
private func createCleanTestContext() -> NSManagedObjectContext {
    let testController = PersistenceController.createTestController()
    return testController.container.viewContext
}

// ❌ WRONG: Shared preview context (data persists between test runs)
let context = PersistenceController.preview.container.viewContext
```

**Why test isolation is critical:**
- **Prevents crashes**: Avoids "attempt to insert nil" errors from stale references
- **Reliable results**: Each test starts with clean data
- **No flaky tests**: Results don't depend on test run order
- **Parallel safety**: Tests can run concurrently without conflicts

**Signs of test pollution:**
- Tests pass once, then crash on second run
- Different results depending on test run order
- "attempt to insert nil" or relationship errors
- Tests that work individually but fail in suite

### File Creation Best Practices

**CRITICAL: Always check if test file exists before creating new ones**

Before creating any test file, use these patterns:
1. **Check existing files first** - Use `query_search` to look for existing test files
2. **Update existing files** - Add new tests to existing files rather than creating duplicates  
3. **Never assume file names** - Files might already exist from previous work

**Common mistake pattern to avoid:**
- Creating `SomeServiceTests.swift` 
- Then accidentally creating `SomeServiceTests 2.swift` (causes redeclaration errors)
- **Solution**: Always check if `SomeServiceTests.swift` exists first, then add to it

**File creation workflow:**
```swift
// 1. Check if file exists
query_search(["SomeServiceTests"]) 
// 2. If exists: Add test to existing file
// 3. If not exists: Create new file
// 4. Never create numbered variants like "Tests 2.swift"
```

### Our TDD Principles

**🚨 CRITICAL: Core Data Test Isolation**

**MANDATORY PATTERN - NO EXCEPTIONS:**

**Every single test method that touches Core Data MUST use isolated contexts:**

```swift
// ✅ REQUIRED PATTERN for ALL Core Data tests - copy this exactly
private func createCleanTestContext() -> NSManagedObjectContext {
    let testController = PersistenceController.createTestController()
    return testController.container.viewContext
}

// Use in EVERY Core Data test:
let context = createCleanTestContext()
```

**⚠️ ABSOLUTELY FORBIDDEN - WILL CAUSE CRASHES:**
```swift
// ❌ NEVER EVER use shared contexts in tests
let context = PersistenceController.preview.container.viewContext
let context = PersistenceController.shared.container.viewContext
```

**Why this pattern is MANDATORY:**
- **Prevents crashes**: "attempt to insert nil" errors from stale references
- **Eliminates test pollution**: Each test gets completely fresh data
- **Enables parallel testing**: Tests can run concurrently without conflicts
- **Saves debugging time**: No mysterious test failures or flaky behavior

**Symptoms you violated this rule:**
- Tests pass first run, crash on second run
- "attempt to insert nil" exceptions
- "index X beyond bounds" crashes
- Different results based on test execution order
- Tests work individually but fail in suites

**CRITICAL: Even Unused Context Variables Cause Crashes**
```swift
// ❌ FORBIDDEN: Even unused context variables cause test pollution
func testSomething() {
    let context = PersistenceController.preview.container.viewContext  // NEVER!
    // ... test code that doesn't even use context ...
}

// ✅ CORRECT: Don't create contexts you don't need
func testSomething() {
    // ... test code without any context creation ...
}
```

**Why unused contexts are dangerous:**
- Creating `PersistenceController.preview` initializes shared Core Data state
- This shared state gets corrupted and interferes with other tests
- Even if you don't use the variable, the damage is done
- Results in "attempt to insert nil" crashes in unrelated tests

**THIS RULE HAS NO EXCEPTIONS. EVERY CORE DATA TEST MUST USE ISOLATED CONTEXTS.**

---

## 🚨 URGENT: Active Test Pollution Issue

**CRITICAL PROBLEM: Tests currently pass first run, fail second run**

**Current failing symptoms:**
- AsyncOperationHandler loading state tests fail intermittently
- Core Data deletion tests return wrong results on second run
- Clear indication of persistent state leakage despite isolation efforts

**IMMEDIATE ACTIONS REQUIRED:**
- **Run tests individually** - Full test suite execution causes pollution
- **Restart simulator** between test runs to clear contaminated state  
- **Clean build** before each test session (⌘⇧K)

**Investigation needed for:**
- AsyncOperationHandler static state management
- SwiftUI Binding state persistence 
- Core Data context cleanup effectiveness
- Test execution order dependencies

---

## 🚨 CRITICAL: Core Data Model Corruption Detected

**EMERGENCY STOP: Core Data entity errors causing crashes**

**Current crash:**
```
*** Terminating app due to uncaught exception 'NSInvalidArgumentException', 
reason: '-[_CDSnapshot_CatalogItem_ values]: unrecognized selector sent to instance'
```

**This indicates:**
- Core Data model/entity corruption or mismatch
- CatalogItem entity definition problems
- Possible missing Core Data properties or relationships
- Snapshot objects being called with invalid methods

**IMMEDIATE ACTIONS:**
1. **STOP ALL TESTING** - Core Data is corrupted
2. **Check .xcdatamodeld file** - Verify CatalogItem entity exists and is properly defined
3. **Clean Core Data caches** - Delete derived data, reset simulator
4. **Verify entity relationships** - Ensure all properties are correctly defined
5. **Consider model regeneration** - May need project owner intervention

**DO NOT PROCEED WITH TESTING UNTIL CORE DATA MODEL IS FIXED**

This is a fundamental infrastructure issue that will cause crashes throughout the app.

1. **Implement the simplest code possible**
2. **Avoid overengineering or anticipating future needs**
3. **Confirm that all tests pass (existing + new)**
4. **Each loop should be tight and focused, no solving 3 things at once**
5. **Unit test files should always be placed inside the FlameworkerTests area**
6. **🚨 MANDATORY: Use isolated Core Data contexts in all tests (see above)**

### TDD Cycle: Red → Green → Refactor

#### 1. 🔴 **RED**: Write a Failing Test

**STEP 0**: Run `query_search` to check if test file exists
- If exists: Add test to existing file
- If not exists: Create new file (only after checking!)

```swift
@Test("New feature should work correctly")
func testNewFeature() {
    let result = MyNewClass().newMethod()
    #expect(result == expectedValue)
}
```

**Run tests:** `⌘U` - Should FAIL

#### 2. 🟢 **GREEN**: Write Minimal Code to Pass

```swift
class MyNewClass {
    func newMethod() -> String {
        return expectedValue // Simplest implementation
    }
}
```

**Run tests:** `⌘U` - Should PASS

#### 3. 🔵 **REFACTOR**: Clean Up Code

- Improve code structure while keeping tests green
- Extract methods, improve naming, remove duplication
- **Run tests after each change:** `⌘U`


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

#### Warning Signs to Watch For

**🚨 Immediate Action Required:**
- Tests manipulating `UserDefaults.standard`
- Creating isolated Core Data contexts for simple tests  
- Test files exceeding 700 lines
- Multiple test files covering same functionality
- Tests hanging or causing compilation errors
- Missing type errors in test files

**⚠️ Technical Debt Building:**
- Tests with artificial `Task.sleep()` delays
- Duplicate mock objects across files
- Mixed concerns (UI + business logic + integration in same file)
- File names like `TestFile2.swift` or `AdditionalTests.swift`

#### Recovery Patterns That Worked

**1. Mock-First Approach**
```swift
// Replace Core Data with simple mocks for business logic testing
protocol CatalogItemProtocol {
    var name: String? { get }
    var manufacturer: String? { get }
}

struct MockCatalogItem: CatalogItemProtocol {
    let name: String?
    let manufacturer: String?
}
```

**2. Safe Collection Enumeration**
```swift
// Use CoreDataHelpers.safelyEnumerate() to prevent mutation crashes
CoreDataHelpers.safelyEnumerate(Set(coreDataCollection)) { item in
    // Process safely without collection mutation errors
}
```

**3. Proper Async Patterns**
```swift
// Replace artificial delays with proper task awaiting
let task = Task { await performOperation() }
let result = await task.value
#expect(result.isSuccess)
// No more Task.sleep() or timing-dependent tests
```

## 🎯 TDD Best Practices

### 1. Test Naming Convention

```swift
@Test("Should convert pounds to kilograms correctly")
func testPoundsToKilogramsConversion() { ... }

@Test("Should handle empty input gracefully")  
func testEmptyInputHandling() { ... }
```

### 2. Test Structure (AAA Pattern)

```swift
@Test("Should calculate total correctly")
func testCalculateTotal() {
    // Arrange
    let items = [Item(price: 10.0), Item(price: 20.0)]
    let calculator = Calculator()
    
    // Act
    let total = calculator.calculateTotal(items)
    
    // Assert
    #expect(total == 30.0)
}
```

### 3. Test Categories

- **Unit Tests**: Test individual methods/classes in isolation
- **Integration Tests**: Test component interactions
- **Edge Cases**: Test boundary conditions, empty inputs, error states

### 4. Test Data Management

```swift
@Suite("Calculator Tests")
struct CalculatorTests {
    
    // Shared test data
    let testItems = [
        Item(name: "Test1", price: 10.0),
        Item(name: "Test2", price: 20.0)
    ]
    
    @Test("Should handle valid items")
    func testValidItems() {
        // Use testItems...
    }
}
```

**Key Points:**
- Use `.serialized` for suites that share global state
- Call `resetToStandard()` at the start of each test for clean state
- Always clean up: call `resetToStandard()` and `removeSuite()`

## 📚 Resources

- [Swift Testing Documentation](https://developer.apple.com/documentation/testing)
- [Test-Driven Development by Example](https://www.amazon.com/Test-Driven-Development-Kent-Beck/dp/0321146530)
- [SwiftUI Testing Best Practices](https://developer.apple.com/videos/play/wwdc2021/10203/)

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



Update a README with all environment setup and TDD usage steps.

######### End Prompt #########

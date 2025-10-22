# Core Data Prevention Guide for FlameworkerTests

## 🚨 **FlameworkerTests is MOCK-ONLY!**

This test target has a strict **NO Core Data** policy. Any attempt to use Core Data will result in immediate test failure with a clear error message.

## 🛡️ **How Prevention Works**

### 1. **Automatic Detection System**
- `CoreDataPreventionSystem.swift` automatically detects Core Data class usage
- Triggers `fatalError` with detailed instructions when Core Data is detected
- Runs automatically when using `TestConfiguration` or `MockOnlyTestSuite`

### 2. **Protocol-Based Prevention**
```swift
struct YourTestSuite: MockOnlyTestSuite {
    init() {
        ensureMockOnlyEnvironment() // Prevents Core Data!
    }
}
```

### 3. **Configuration-Based Prevention**
```swift
let repos = TestConfiguration.setupMockOnlyTestEnvironment()
// This call includes automatic Core Data prevention
```

## ❌ **Forbidden in FlameworkerTests**

```swift
// DON'T DO THESE:
import CoreData
PersistenceController(inMemory: true)
NSManagedObjectContext()
CoreDataCatalogRepository(context: context)
context.save()
viewContext.perform { }
```

## ✅ **Required Patterns**

```swift
// DO THESE INSTEAD:
import Foundation
@testable import Molten

@Suite("Your Test Name")
struct YourTest: MockOnlyTestSuite {
    init() {
        ensureMockOnlyEnvironment() // Required!
    }
    
    @Test("Your test")
    func testSomething() async throws {
        // Always start with this:
        let repos = TestConfiguration.setupMockOnlyTestEnvironment()
        
        // Use mock repositories:
        _ = try await repos.glassItem.createItem(testItem)
        let items = try await repos.glassItem.fetchItems(matching: nil)
        
        // Use SearchUtilities for search:
        let results = SearchUtilities.filter(items, with: "search term")
        
        #expect(results.count >= 0, "Test your logic")
    }
}
```

## 🔧 **Available Tools**

### TestConfiguration
- `TestConfiguration.setupMockOnlyTestEnvironment()` - Creates all mock repos + prevention
- `TestConfiguration.createIsolatedMockRepositories()` - Just mock repos
- `TestConfiguration.verifyNoCoreDdataLeakage()` - Validates isolation

### TestDataSetup
- `TestDataSetup.createStandardTestGlassItems()` - Consistent test data
- `TestDataSetup.setupCompleteTestEnvironment()` - Full environment

### SearchUtilities
- `SearchUtilities.filter(items, with: "term")` - Replace repository search
- `SearchUtilities.parseSearchTerms()` - Parse search queries

## 🔍 **Violation Detection**

When Core Data usage is detected, you'll see:

```
🚨 CORE DATA VIOLATION DETECTED! 🚨

Class detected: NSManagedObjectContext

FlameworkerTests is a MOCK-ONLY test target!

❌ FORBIDDEN in FlameworkerTests:
• import CoreData
• PersistenceController
• NSManagedObjectContext
• Any Core Data repositories
• .save() operations on contexts

✅ REQUIRED in FlameworkerTests:
• Use TestConfiguration.setupMockOnlyTestEnvironment()
• Use TestDataSetup for consistent test data  
• Use Mock* repository implementations only
• Use SearchUtilities.filter() for search operations

💡 SOLUTION:
1. Remove 'import CoreData' from your test file
2. Replace Core Data repositories with Mock* repositories
3. Use TestConfiguration patterns for setup
4. See CORE_DATA_CLEANUP_SUMMARY.md for examples

📁 For Core Data integration tests, create a separate test target.
```

## 🚀 **Quick Start**

1. **Copy NewTestTemplate.swift** and rename it
2. **Follow the template structure exactly**
3. **Run the verification script:**
   ```bash
   chmod +x check_core_data_violations.sh
   ./check_core_data_violations.sh
   ```

## 📁 **For Core Data Testing**

If you need to test Core Data integration:
1. Create a separate test target (e.g., "FlameworkerIntegrationTests")
2. Put Core Data tests there
3. Keep FlameworkerTests pure mock-only

## 🎯 **Benefits**

- ⚡ **Fast Tests** - No database overhead
- 🔒 **Reliable Tests** - No state pollution between tests  
- 🎯 **Focused Tests** - Pure business logic testing
- 🛡️ **Automatic Prevention** - Impossible to accidentally use Core Data
- 📝 **Clear Errors** - Immediate feedback with solution steps

## 📚 **Examples**

See these files for correct patterns:
- `NewTestTemplate.swift` - Template to copy
- `RepositoryIdentityTest.swift` - Updated example
- `SearchUtilitiesConfigurationTests.swift` - Existing good example
- `ViewUtilitiesTests.swift` - Existing good example

---

## 🐛 **Troubleshooting: "Breakpoints" That Aren't Breakpoints**

### Swift Concurrency Data Race Detection

**Symptom:** Tests "hang" or "break" at a specific line in MockInventoryRepository with error:
```
Thread X: EXC_BREAKPOINT (code=1, subcode=0x1801bbe80)
```

**This is NOT a breakpoint!** It's Swift 6's concurrency runtime detecting a potential data race.

### Root Cause

Mock repositories use `nonisolated(unsafe)` for storage:
```swift
nonisolated(unsafe) private var inventories: [UUID: InventoryModel] = [:]
```

When Xcode's debugger is attached, it enables strict Swift 6 concurrency checking. Accessing `self.inventories.values` directly can trigger false positives even when protected by `DispatchQueue`.

### The Fix

**Always snapshot collections AND avoid extension methods that trigger the checker:**

```swift
// ❌ DON'T DO THIS:
self.queue.async {
    let groupedByItem = self.inventories.values.grouped(by: \.item_natural_key)
}

// ❌ STILL TRIGGERS THE CHECKER:
self.queue.async {
    let values = Array(self.inventories.values)  // Snapshot first
    let groupedByItem = values.grouped(by: \.item_natural_key)  // Extension method triggers checker!
}

// ✅ DO THIS INSTEAD:
self.queue.async {
    let values = Array(self.inventories.values)  // Snapshot first!
    // Inline Dictionary(grouping:) instead of using extension method
    let groupedByItem = Dictionary(grouping: values, by: { $0.item_natural_key })
}
```

**Key insight:** Swift's concurrency checker is suspicious of extension methods on Collection that iterate. Use `Dictionary(grouping:by:)` directly instead of custom `.grouped()` extensions.

### Why This Happens

- **Command-line tests work fine** - Less strict concurrency checking
- **Xcode UI tests fail** - Debugger enables stricter checks
- **Cmd+Y doesn't help** - It's not a user breakpoint
- **Deleting derived data doesn't help** - It's a runtime check

### Solution Applied

All mock repositories now snapshot `values` before any operations that iterate over collections. See `MockInventoryRepository.swift` for the pattern.

### Key Insight

`EXC_BREAKPOINT` doesn't always mean a breakpoint was set - it can also indicate:
- `fatalError()` calls
- `preconditionFailure()` calls
- Swift runtime concurrency violations
- Force unwrapping nil values

If you see "EXC_BREAKPOINT" and can't find a breakpoint, look for concurrency issues!

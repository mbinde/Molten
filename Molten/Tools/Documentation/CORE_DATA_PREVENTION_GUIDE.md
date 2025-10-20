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

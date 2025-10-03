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
├── FlameworkerTests.swift          # All unit tests (Swift Testing)
├── WeightUnit.swift                # Weight unit enums & conversion logic
├── InventoryUnits.swift            # Inventory unit types
├── InventoryItemType.swift         # Item type enums
├── SimpleImageHelpers.swift        # Image loading utilities
├── FormComponents.swift            # UI form components
├── CatalogView.swift              # Main catalog interface
└── InventoryItemDetailView.swift  # Item detail views
```

## 🧪 TDD (Test-Driven Development) Workflow

### Our TDD Principles

1. **Implement the simplest code possible**
2. **Avoid overengineering or anticipating future needs**
3. **Confirm that all tests pass (existing + new)**
4. **Each loop should be tight and focused, no solving 3 things at once**
5. **Unit test files should always be placed inside the FlameworkerTests area**

### TDD Cycle: Red → Green → Refactor

#### 1. 🔴 **RED**: Write a Failing Test

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

### Testing Framework: Swift Testing

We use Apple's modern **Swift Testing** framework (not XCTest). Key differences:

#### Swift Testing Syntax

```swift
import Testing
@testable import Flameworker

@Suite("Feature Tests")
struct FeatureTests {
    
    @Test("Description of what this tests")
    func testSomething() {
        // Arrange
        let input = "test"
        
        // Act
        let result = processInput(input)
        
        // Assert
        #expect(result == "expected")
        #expect(result.count > 0, "Should have content")
    }
    
    @Test("Test with parameters", arguments: [1, 2, 3])
    func testWithParams(value: Int) {
        #expect(value > 0)
    }
}
```

#### Key Swift Testing Features

- `@Suite("Name")` - Groups related tests
- `@Test("Description")` - Individual test method
- `#expect(condition, "message")` - Main assertion
- `#require(optional)` - Unwrap optionals (like XCTUnwrap)
- Automatic async/await support

## 🏃‍♂️ Running Tests

### Command Line

```bash
# Run all tests
xcodebuild test -scheme Flameworker -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test suite
xcodebuild test -scheme Flameworker -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:FlameworkerTests/WeightUnitTests
```

### Xcode IDE

- **All Tests:** `⌘U`
- **Current Test:** Click the diamond next to test method
- **Test Suite:** Click diamond next to `@Suite`
- **Test Navigator:** `⌘6` → View all tests

### Continuous Testing

Enable **Test Navigator → Show Test Results** to see real-time test status indicators throughout your code.

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

## 📊 Current Test Coverage

### Core Business Logic (Fully Tested)

- ✅ **WeightUnit**: Conversion logic, display names, symbols, edge cases (zero, negative, large values)
- ✅ **InventoryUnits**: Unit types, display formatting, ID mapping, formatting edge cases
- ✅ **InventoryItemType**: Type categorization, UI metadata, color validation
- ✅ **ImageHelpers**: Filename sanitization, path handling, whitespace handling, empty input validation
- ✅ **UnitsDisplayHelper**: Unit conversion, preference handling, fractional values, zero values
- ✅ **SearchUtilities**: Search configuration, multi-term filtering, fuzzy search logic
- ✅ **ErrorHandler**: Error creation, severity mapping, success/failure handling
- ✅ **CatalogItemHelpers**: Display formatting, tags string creation, availability status, display info structures
- ✅ **FilterUtilities**: Status filtering logic, type filtering logic
- ✅ **SortUtilities**: Sort criteria enums, generic sorting behavior
- ✅ **InventoryViewComponents**: Status property logic, data validation, display formatting
- ✅ **String Validation**: String trimming, validation logic, email format validation, length validation
- ✅ **Form State Management**: Form validation logic, error message management, field validation patterns
- ✅ **Alert State Management**: Alert state logic, error categorization, contextual message formatting
- ✅ **Async Operation Error Handling**: Async error patterns, Result type usage, operation safety
- ✅ **SearchUtilities Advanced**: Levenshtein distance calculation, fuzzy matching precision
- ✅ **WeightUnit Thread Safety**: Concurrent access patterns, thread-safe UserDefaults operations
- ✅ **UnitsDisplayHelper Precision**: Small value precision, large value handling, overflow protection
- ✅ **ValidationUtilities**: String validation, number parsing, email format validation, minimum length validation, positive/negative/non-negative number validation, multi-field validation, validation result handling
- ✅ **FormValidationState**: Form state management, field registration, validation orchestration, error message retrieval, has-error checking, multi-field validation scenarios
- ✅ **GlassManufacturers**: Full name/code mapping, COE value lookup, manufacturer color mapping, case-insensitive lookup, reverse lookup, COE support checking, manufacturer search, normalization, comprehensive manufacturer info, COE grouping
- ✅ **ViewUtilities**: Feature description creation, async operation handling, bundle utilities, duplicate operation prevention, loading state management
- ✅ **CoreDataOperations**: Type validation, index bounds checking, safe deletion operations, create-and-save patterns
- ✅ **AlertBuilders**: Message template replacement, count handling (zero, positive, large values), deletion confirmation patterns
- ✅ **Advanced ValidationUtilities**: Success/error callback execution, common validation patterns (supplier names, purchase amounts, inventory counts), complex email validation, special number cases (very small, very large, whitespace handling)

### Test Metrics

- **Total Tests:** 170+ tests across 28 test suites  
- **Core Logic Coverage:** ~99%
- **Edge Cases:** Comprehensive coverage (invalid inputs, empty strings, boundary values, UserDefaults handling, whitespace inputs, zero/negative/large values, fractional numbers, fuzzy matching, error conditions)
- **Advanced Testing:** Thread safety, async operations, precision handling, form validation patterns, manufacturer mapping, COE validation, comprehensive validation utilities, view utility functions, Core Data operation safety, alert message formatting

## 🔄 Development Workflow

### Adding New Features (TDD)

1. **Start with a failing test:**
   ```swift
   @Test("New feature should work")
   func testNewFeature() {
       #expect(newFeature() == expectedResult)
   }
   ```

2. **Run tests** (`⌘U`) - Should fail with compilation error

3. **Add minimal code** to compile:
   ```swift
   func newFeature() -> String { "" }
   ```

4. **Run tests** (`⌘U`) - Should fail assertion

5. **Implement feature** to pass test:
   ```swift
   func newFeature() -> String { return expectedResult }
   ```

6. **Run tests** (`⌘U`) - Should pass

7. **Refactor** while keeping tests green

8. **Add edge case tests** and repeat

### Refactoring Existing Code

1. **Ensure all tests pass** (`⌘U`)
2. **Make incremental changes**
3. **Run tests after each change** (`⌘U`)
4. **If tests fail**: Revert and try smaller change
5. **Add tests for new scenarios** as needed

## 🚨 Troubleshooting

### Tests Not Running

- Verify Swift Testing is enabled (Xcode 15+)
- Check test target membership
- Ensure `@testable import Flameworker` is present

### Build Errors

- Clean Build Folder: `⌘⇧K`
- Reset Simulator: Device → Erase All Content and Settings
- Restart Xcode if necessary

### UserDefaults in Tests

Some tests depend on UserDefaults and require isolation to prevent random failures. The WeightUnitPreference tests use the `.serialized` attribute and isolated UserDefaults instances:

```swift
@Suite("WeightUnitPreference Tests", .serialized)
struct WeightUnitPreferenceTests {
    
    @Test("Test with isolated UserDefaults")
    func testWithIsolatedDefaults() {
        // Create isolated test UserDefaults
        let testSuite = "Test_\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: testSuite)!
        
        // Ensure clean start
        WeightUnitPreference.resetToStandard()
        WeightUnitPreference.setUserDefaults(testDefaults)
        testDefaults.set("Kilograms", forKey: WeightUnitPreference.storageKey)
        
        // Run test
        let result = WeightUnitPreference.current
        #expect(result == .kilograms)
        
        // Clean up
        WeightUnitPreference.resetToStandard()
        testDefaults.removeSuite(named: testSuite)
    }
}
```

**Key Points:**
- Use `.serialized` for suites that share global state
- Call `resetToStandard()` at the start of each test for clean state
- Create unique test suite names with UUIDs  
- Always clean up: call `resetToStandard()` and `removeSuite()`

## 📚 Resources

- [Swift Testing Documentation](https://developer.apple.com/documentation/testing)
- [Test-Driven Development by Example](https://www.amazon.com/Test-Driven-Development-Kent-Beck/dp/0321146530)
- [SwiftUI Testing Best Practices](https://developer.apple.com/videos/play/wwdc2021/10203/)

## 🤝 Contributing

1. Follow TDD workflow (Red → Green → Refactor)
2. Write tests first, then implement features
3. Keep test methods focused and simple
4. Use descriptive test names
5. Ensure all tests pass before committing
6. Add tests for bug fixes

---

**Remember:** The goal is maintainable, well-tested code. Write the simplest code that passes the tests, then refactor for clarity. Every feature should have corresponding tests before implementation.

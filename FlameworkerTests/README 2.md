# Flameworker

An inventory management app for iOS/macOS built with SwiftUI and Swift Testing.

## Environment Setup

### Requirements
- Xcode 15.0 or later
- iOS 17.0+ / macOS 14.0+ target
- Swift 5.9+

### Project Structure
```
Flameworker/
├── Models/
│   ├── WeightUnit.swift          # Weight unit conversion & preferences
│   ├── InventoryUnits.swift      # Inventory unit types
│   ├── InventoryItemType.swift   # Item categories (inventory/buy/sell)
│   └── SimpleImageHelpers.swift  # Product image management
└── FlameworkerTests/
    └── FlameworkerTests.swift    # Comprehensive unit tests
```

### Key Components
- **WeightUnit**: Handles pounds ↔ kilograms conversion with user preferences
- **InventoryUnits**: Various unit types (shorts, rods, ounces, pounds, grams, kg)
- **InventoryItemType**: Item categories with colors and system images
- **ImageHelpers**: Product image loading and filename sanitization
- **UnitsDisplayHelper**: Smart unit conversion based on user preferences

## Test-Driven Development (TDD) Usage

### Running Tests
1. Open project in Xcode
2. Use `⌘+U` to run all tests
3. Use `⌘+Control+U` to run tests without building dependencies
4. Individual tests can be run by clicking the diamond icon next to each test

### TDD Workflow
1. **Red**: Write a failing test first
2. **Green**: Write minimal code to make the test pass
3. **Refactor**: Improve code while keeping tests green

### Test Structure
Tests use Swift Testing framework with `@Test` and `@Suite` attributes:

```swift
@Suite("Feature Tests")
struct FeatureTests {
    
    @Test("Specific behavior description")
    func testSpecificBehavior() {
        // Arrange
        let input = "test"
        
        // Act
        let result = functionUnderTest(input)
        
        // Assert
        #expect(result == expectedOutput)
    }
}
```

### Current Test Coverage
- ✅ **WeightUnit**: Conversion, display names, symbols, system images
- ✅ **InventoryUnits**: Display names, initialization, ID values
- ✅ **InventoryItemType**: Display names, system images, colors, initialization
- ✅ **ImageHelpers**: Filename sanitization, image loading, existence checks
- ✅ **UnitsDisplayHelper**: Unit conversion, preference handling
- ✅ **WeightUnitPreference**: UserDefaults integration, fallback behavior

### Adding New Features
1. Create failing test in `FlameworkerTests.swift`
2. Implement minimal code to pass the test
3. Refactor and add edge case tests
4. Ensure all existing tests still pass

### Best Practices
- Keep tests focused and isolated
- Use descriptive test names
- Test edge cases (empty strings, nil values, invalid inputs)
- Clean up UserDefaults in tests to avoid side effects
- Use `#expect` for assertions and `#require` for unwrapping

## Features

### Weight Unit Conversion
- Supports pounds and kilograms
- User preference storage via UserDefaults
- Automatic conversion in UI display

### Inventory Units
- Multiple unit types: shorts, rods, ounces, pounds, grams, kilograms
- Smart display with proper abbreviations
- Two-stage conversion: small units → large units → preferred system

### Item Categories
- Three types: Inventory (blue), Buy (orange), Sell (green)
- System SF Symbols integration
- Consistent color theming

### Image Management
- Product image loading from bundle
- Filename sanitization for special characters
- Manufacturer-prefixed image support
- Multiple image format support (jpg, png, etc.)

## Development Notes
- All model types implement `Identifiable` for SwiftUI compatibility
- Robust fallback handling for invalid enum raw values
- UserDefaults integration with proper default values
- Comprehensive error handling for image operations
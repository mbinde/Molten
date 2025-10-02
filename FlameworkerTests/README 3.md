# Flameworker

A Swift application for managing inventory with weight unit conversions and product image support.

## Environment Setup

### Requirements
- iOS 17.0+ / macOS 14.0+
- Xcode 15.0+
- Swift 6.0+

### Project Structure
```
Flameworker/
├── WeightUnit.swift          # Weight unit types and conversion logic
├── InventoryUnits.swift      # Inventory unit enumeration
├── InventoryItemType.swift   # Item type classification
├── SimpleImageHelpers.swift  # Product image loading utilities
└── FlameworkerTests/
    └── FlameworkerTests.swift # Comprehensive test suite
```

## Test-Driven Development (TDD) Usage

### Running Tests
1. Open project in Xcode
2. Press `Cmd+U` to run all tests
3. Use Test Navigator (`Cmd+6`) to run specific test suites

### Test Organization
Tests are organized into focused suites:

- **WeightUnit Tests**: Unit conversion, display names, symbols
- **InventoryUnits Tests**: Raw value initialization, display names, ID values
- **InventoryItemType Tests**: Type classification, colors, system images  
- **ImageHelpers Tests**: Filename sanitization, image loading
- **UnitsDisplayHelper Tests**: Unit conversion with user preferences
- **WeightUnitPreference Tests**: UserDefaults integration with proper test isolation

### Test Isolation Strategy
Tests that depend on UserDefaults use isolated test suites to prevent interference:

```swift
// Each test gets its own UserDefaults instance
let testSuiteName = "TestSuite_\(UUID().uuidString)"
let testUserDefaults = UserDefaults(suiteName: testSuiteName)!

// Configure for testing
WeightUnitPreference.setUserDefaults(testUserDefaults)

// Run test logic...

// Clean up
WeightUnitPreference.resetToStandard()
testUserDefaults.removeSuite(named: testSuiteName)
```

### TDD Workflow
1. **Red**: Write a failing test that describes the desired behavior
2. **Green**: Write the simplest code possible to make the test pass
3. **Refactor**: Improve code while keeping tests green

### Key Testing Principles
- **Simple Implementation**: Always implement the simplest solution first
- **No Overengineering**: Avoid anticipating future needs
- **Focused Tests**: Each test suite covers one responsibility
- **Test Isolation**: Tests don't interfere with each other
- **Clean Setup/Teardown**: Proper resource management in tests

## Core Features

### Weight Unit System
- Support for pounds and kilograms
- User preference storage via UserDefaults
- Automatic conversion between units
- Two-stage conversion: small→large→preferred (e.g., ounces→pounds→kg)

### Inventory Management
- Multiple unit types: shorts, rods, ounces, pounds, grams, kilograms
- Item type classification: inventory, buy, sell
- Display formatting with user preferences

### Product Images
- Automatic image loading with manufacturer prefixes
- Fallback support for legacy naming
- Multiple image format support (jpg, jpeg, png)
- Filename sanitization for cross-platform compatibility

### User Preferences
- Weight unit preference (pounds/kilograms) stored in UserDefaults
- Testable architecture with dependency injection for UserDefaults
- Fallback to sensible defaults when no preference set
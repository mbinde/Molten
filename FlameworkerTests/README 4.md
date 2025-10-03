# Flameworker

A Swift inventory management application.

## Development Environment Setup

### Prerequisites
- Xcode 15.0 or later
- Swift 6.0 or later
- macOS 14.0 or later

### Running Tests

This project uses Swift Testing framework with Test Driven Development (TDD) practices.

#### Running All Tests
```bash
# From Xcode
⌘ + U

# From command line (if available)
swift test
```

#### Running Specific Test Suites
In Xcode:
1. Open the Test Navigator (⌘ + 6)
2. Find the specific test suite (e.g., "WeightUnit Tests")
3. Click the play button next to the suite name

#### Running Individual Tests
In Xcode:
1. Open the test file (`FlameworkerTests.swift`)
2. Find the specific test function
3. Click the diamond icon next to the test function

### Test-Driven Development Workflow

1. **Red**: Write a failing test that describes the desired behavior
2. **Green**: Write the minimal code needed to make the test pass
3. **Refactor**: Improve the code while keeping tests passing

### Test Structure

- All tests are located in `FlameworkerTests.swift`
- Tests are organized into `@Suite` groups by functionality
- Tests use the new Swift Testing framework with `@Test` and `#expect`

### Common Issues

#### Weight Unit Tests Randomly Failing
The weight unit preference tests require serialization to prevent concurrent access to shared UserDefaults state. Tests are marked with `.serialized` to run sequentially.

#### Core Data Testing
Core Data tests create isolated in-memory stores to avoid interference between test runs.

### Code Style

- Follow Swift API Design Guidelines
- Use dependency injection for testability
- Prefer simple, maintainable solutions over complex abstractions
- Write comprehensive unit tests for all business logic

## Architecture

### Key Components

- **WeightUnit**: Enum for weight measurement units with conversion capabilities
- **InventoryUnits**: Enum for inventory quantity units
- **WeightUnitPreference**: Manages user weight unit preferences
- **UnitsDisplayHelper**: Handles unit conversions and display formatting
- **ImageHelpers**: Utilities for product image management

### Testing Strategy

- Unit tests for all enum types and utilities
- Isolated testing using dependency injection
- Edge case testing for conversions and validations
- Core Data safety testing with fallback behaviors
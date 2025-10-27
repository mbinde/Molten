# Unit Test Implementation Plan

## Overview
This document tracks the implementation of additional unit tests for the Molten project, following TDD principles and Swift 6 strict concurrency guidelines.

## 🎯 Goals
- Add 18-25 new test files covering untested code
- Achieve ~205-282 additional test methods
- Follow TDD: RED → GREEN → REFACTOR
- Comply with Swift 6 strict concurrency
- Maintain test isolation and independence

---

## 📋 Swift 6 Concurrency Rules for Tests

### ✅ Required Patterns

**Test Suite Declaration:**
```swift
import Testing
@testable import Molten

@Suite("Service Name Tests")
@MainActor  // ✅ When accessing MainActor-isolated code (ObservableObjects, etc.)
struct ServiceNameTests {

    init() async {
        // Setup - configure repository factory for testing
        RepositoryFactory.configureForTesting()
    }

    @Test("Test description")
    func testMethod() async throws {
        // Use #expect() assertions
        #expect(value == expectedValue)
    }
}
```

**Key Rules:**
1. ✅ Use `@Suite` with descriptive name
2. ✅ Add `@MainActor` to suite when accessing MainActor-isolated properties
3. ✅ Use `@Test` with descriptive name for each test
4. ✅ Use `#expect()` assertions (NOT XCTest assertions)
5. ✅ Use `async throws` for async operations
6. ✅ Call `RepositoryFactory.configureForTesting()` in `init()`
7. ✅ Tests should be independent - no shared state
8. ❌ NEVER use `nonisolated struct` - it's invalid syntax

### Test Organization by Type

**Services (Actor-based):**
- Services are `actor` types in this codebase
- Tests calling actor methods must use `await`
- Example: `PurchaseRecordService` is an actor

**Utilities (Synchronous):**
- Pure utility functions
- No `@MainActor` needed unless accessing ObservableObjects
- Example: Array extensions, String extensions

**Models (Structs):**
- Sendable structs
- No special concurrency annotations needed
- Example: WeightUnit, CatalogItemModel

---

## 🚀 Phase 1: Critical Services (Priority 1)

### Phase 1.1: PurchaseRecordServiceTests.swift ✅
**Status**: Pending
**Location**: `Tests/MoltenTests/Services/`
**File Type**: New file - **PAUSE for Xcode target addition**
**Service Type**: `actor` (requires `await` in tests)
**Estimated Tests**: 15-20

**Test Categories:**
1. Basic CRUD Operations
   - ✅ Create purchase record
   - ✅ Get record by ID (found)
   - ✅ Get record by ID (not found)
   - ✅ Update purchase record
   - ✅ Delete purchase record
   - ✅ Get all records

2. Date Range Queries
   - ✅ Get records within date range
   - ✅ Get records with no matches in range
   - ✅ Get records with start date only
   - ✅ Get records with end date only

3. Search & Filter
   - ✅ Search records by text
   - ✅ Search with no matches
   - ✅ Filter by supplier
   - ✅ Filter by supplier (no matches)

4. Analytics
   - ✅ Calculate total spending for date range
   - ✅ Get distinct suppliers
   - ✅ Get spending by supplier
   - ✅ Get spending by supplier (empty data)

5. Glass Item Operations
   - ✅ Get purchase history for glass item
   - ✅ Get total purchased quantity
   - ✅ Get total purchased (no records)

6. Edge Cases
   - ✅ Handle nil optional fields
   - ✅ Handle empty supplier list
   - ✅ Handle zero spending calculations

**Swift 6 Considerations:**
- Service is `actor` - all calls need `await`
- Repository operations are async - use `await`
- No @MainActor needed (service doesn't access UI)

---

### Phase 1.2: LabelPrintingServiceTests.swift ⭐
**Status**: Pending
**Location**: `Tests/MoltenTests/Services/`
**File Type**: New file - **PAUSE for Xcode target addition**
**Service Type**: `class` with `@preconcurrency`
**Estimated Tests**: 35-45

**Test Categories:**
1. QR Code Generation (10 tests)
   - ✅ Generate QR with valid stable_id
   - ✅ QR contains correct deep link format
   - ✅ QR code size is correct
   - ✅ Logo overlay is applied
   - ✅ Handle missing logo asset gracefully
   - ✅ Generate QR for various stable_id formats
   - ✅ QR code error correction level is High
   - ✅ QR code scaling
   - ✅ Empty stable_id handling
   - ✅ Special characters in stable_id

2. Label Builder Configuration (15 tests)
   - ✅ Default configuration
   - ✅ Preset: Information Dense
   - ✅ Preset: QR Focused
   - ✅ Preset: Dual QR
   - ✅ Preset: Location Labels
   - ✅ QR position: left
   - ✅ QR position: right
   - ✅ QR position: both
   - ✅ QR position: none
   - ✅ Text alignment: left
   - ✅ Text alignment: center
   - ✅ Text alignment: right
   - ✅ Text field selection
   - ✅ Text field ordering
   - ✅ Convert to legacy template

3. Layout Validation (8 tests)
   - ✅ Validate layout for Avery 5160
   - ✅ Validate layout for Avery 5163
   - ✅ Validate layout for Avery 5167
   - ✅ Validate layout for Mr-Label MR184
   - ✅ Detect text overflow
   - ✅ Detect narrow text area
   - ✅ Detect too many fields
   - ✅ Font scale impact on validation

4. Preset Management (6 tests)
   - ✅ Save preset
   - ✅ Load presets
   - ✅ Delete preset
   - ✅ Export preset to JSON
   - ✅ Import preset from JSON
   - ✅ Get all presets (built-in + user)

5. Label Sheet Generation (6-10 tests)
   - ✅ Generate single-page PDF
   - ✅ Generate multi-page PDF
   - ✅ Partial sheet printing (startRow, startColumn)
   - ✅ Font scaling
   - ✅ Offset adjustments
   - ✅ Empty label data
   - ✅ Manufacturer de-duplication

**Swift 6 Considerations:**
- Service is `@preconcurrency class`
- `generateLabelSheet()` is async - use `await`
- Tests need `@MainActor` because UIImage/UIGraphics are MainActor-isolated
- LabelPresetsManager is `@MainActor` class - all access needs `@MainActor` context

---

### Phase 1.3: EntityCoordinatorTests.swift 🔄
**Status**: Pending
**Location**: `Tests/MoltenTests/Services/`
**File Type**: New file - **PAUSE for Xcode target addition**
**Service Type**: `class` (synchronous methods with async service calls)
**Estimated Tests**: 12-15

**Test Categories:**
1. Catalog + Inventory Coordination
   - ✅ Get inventory for valid glass item
   - ✅ Get inventory for non-existent item (error)
   - ✅ Get inventory with zero quantity
   - ✅ Get inventory with multiple locations

2. Purchase + Inventory Correlation
   - ✅ Correlate purchases with inventory
   - ✅ Calculate average price per unit
   - ✅ Handle no purchase records
   - ✅ Handle no inventory records
   - ✅ Calculate total spent

3. Search with Inventory Context
   - ✅ Search glass items with inventory context
   - ✅ Search with multiple matches
   - ✅ Search with no matches
   - ✅ Filter items with inventory only

4. Error Handling
   - ✅ Missing catalog service
   - ✅ Missing inventory service
   - ✅ Missing purchase service
   - ✅ Catalog item not found

**Swift 6 Considerations:**
- EntityCoordinator is a regular `class`
- All methods call async service methods - use `await`
- No @MainActor needed

---

### Phase 1.4: ReportingServiceTests.swift 📊
**Status**: Pending
**Location**: `Tests/MoltenTests/Services/`
**File Type**: New file - **PAUSE for Xcode target addition**
**Service Type**: `class` (synchronous with async service calls)
**Estimated Tests**: 18-25

**Test Categories:**
1. Comprehensive Reports
   - ✅ Generate comprehensive report with data
   - ✅ Generate report with empty data
   - ✅ Date range filtering
   - ✅ Calculate totals (items, records, quantity)

2. Inventory Reports
   - ✅ Generate inventory report
   - ✅ Inventory by type statistics
   - ✅ Low stock items
   - ✅ Total quantity calculations

3. Manufacturer Reports
   - ✅ Generate manufacturer report
   - ✅ Manufacturer distribution
   - ✅ Manufacturer statistics (counts, quantities, COEs)
   - ✅ Sort by item count

4. Tag Reports
   - ✅ Generate tag report
   - ✅ Tag statistics
   - ✅ Top tags calculation
   - ✅ Average tags per item

5. Shopping List Reports
   - ✅ Generate shopping list report (when service available)
   - ✅ Handle missing shopping list service
   - ✅ Combine shopping lists from multiple stores
   - ✅ Calculate low stock items

6. Statistics Calculations
   - ✅ Inventory type statistics
   - ✅ COE distribution
   - ✅ Tag analysis (unique tags, assignments, averages)

**Swift 6 Considerations:**
- ReportingService is a regular `class`
- All methods call async services - use `await`
- No @MainActor needed

---

## 🛠️ Phase 2: Essential Utilities (Priority 2)

### Phase 2.1: ArrayExtensionsTests.swift 📦
**Status**: Pending
**Location**: `Tests/MoltenTests/Utilities/`
**File Type**: New file - **PAUSE for Xcode target addition**
**Utility Type**: Pure functions (synchronous, no concurrency)
**Estimated Tests**: 25-30

**Test Categories:**
1. Array.chunked(into:) - 6 tests
2. Array.subscript(safe:) - 4 tests
3. Array.removing(_:) - 3 tests
4. Array.removing(where:) - 3 tests
5. Collection.isNotEmpty - 2 tests
6. Sequence.grouped(by keyPath:) - 3 tests
7. Sequence.grouped(by transform:) - 2 tests
8. Sequence.count(where:) - 3 tests
9. Array.removingDuplicates() - 3 tests
10. Array.removingDuplicates(by:) - 2 tests
11. Array.removingDuplicatesUnordered() - 2 tests

**Swift 6 Considerations:**
- Pure utility extensions - no async
- No @MainActor needed
- All synchronous tests

---

### Phase 2.2: StringExtensionsTests.swift 📝
**Status**: Pending
**Location**: `Tests/MoltenTests/Utilities/`
**File Type**: New file - **PAUSE for Xcode target addition**
**Utility Type**: Pure functions (synchronous)
**Estimated Tests**: 6-8

**Test Categories:**
1. String.truncatedSKU() - 6 tests
   - Short SKU (no truncation)
   - Long SKU (with ellipsis)
   - Exactly max length
   - Empty string
   - Custom max length
   - Very long SKU

**Swift 6 Considerations:**
- Pure utility extension - no async
- No @MainActor needed

---

### Phase 2.3: CatalogFormattersTests.swift 📅
**Status**: Pending
**Location**: `Tests/MoltenTests/Utilities/`
**File Type**: New file - **PAUSE for Xcode target addition**
**Utility Type**: DateFormatter (synchronous)
**Estimated Tests**: 4-6

**Test Categories:**
1. itemFormatter - 2 tests
   - Format date with short date style
   - Format date with medium time style

2. yearFormatter - 2 tests
   - Format date to year only
   - Verify "yyyy" format

**Swift 6 Considerations:**
- DateFormatter is synchronous
- No @MainActor needed

---

## 📝 Implementation Process

### For Each Test File:

1. **Create test file** with proper structure
   - Import Testing framework
   - Import @testable Molten
   - Add @Suite attribute with descriptive name
   - Add @MainActor if needed (check concurrency requirements)

2. **Add init() for setup**
   - Call `RepositoryFactory.configureForTesting()`
   - Set up any test data

3. **Write tests following TDD**
   - 🔴 RED: Write failing test first
   - 🟢 GREEN: Verify test passes (or fix implementation if needed)
   - 🔵 REFACTOR: Improve test clarity

4. **Verify Swift 6 compliance**
   - No `nonisolated struct`
   - Proper use of `await` for async calls
   - Proper use of `@MainActor` where needed

5. **Run tests**
   - Single test: `xcodebuild test -project Molten.xcodeproj -scheme Molten -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:MoltenTests/TestClassName/testMethodName`
   - Full suite: `xcodebuild test -project Molten.xcodeproj -scheme Molten -testPlan UnitTestsOnly -destination 'platform=iOS Simulator,name=iPhone 15'`

---

## ✅ Completion Criteria

For each test file:
- [ ] File created in correct location
- [ ] Added to Xcode project target
- [ ] All planned tests implemented
- [ ] All tests pass
- [ ] Swift 6 concurrency compliance verified
- [ ] Code follows CLAUDE.md guidelines
- [ ] TDD process followed (RED → GREEN → REFACTOR)

---

## 📊 Progress Tracking

### Phase 1: Critical Services
- [ ] Phase 1.1: PurchaseRecordServiceTests.swift (0/20 tests)
- [ ] Phase 1.2: LabelPrintingServiceTests.swift (0/45 tests)
- [ ] Phase 1.3: EntityCoordinatorTests.swift (0/15 tests)
- [ ] Phase 1.4: ReportingServiceTests.swift (0/25 tests)

**Phase 1 Total**: 0/105 tests

### Phase 2: Essential Utilities
- [ ] Phase 2.1: ArrayExtensionsTests.swift (0/30 tests)
- [ ] Phase 2.2: StringExtensionsTests.swift (0/8 tests)
- [ ] Phase 2.3: CatalogFormattersTests.swift (0/6 tests)

**Phase 2 Total**: 0/44 tests

---

## 🎓 Key Learnings

Document any issues or patterns discovered during implementation:
- [To be filled in during implementation]

---

**Last Updated**: 2025-10-26
**Status**: Phase 1.1 - Ready to begin

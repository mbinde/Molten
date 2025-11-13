# AppDependencies Safety Mechanisms

This document explains the safety mechanisms in place to prevent accidental use of `configureForTesting()` in production code.

## The Problem

`AppDependencies.configureForTesting()` switches the **entire app** to mock mode. If called in production code, it causes:
- All repositories use in-memory mocks instead of Core Data
- No data persists to disk
- Users cannot save their inventory, projects, or other data
- App appears to work but nothing is saved

This has happened multiple times:
1. October 2024: `DataLoadingService.shared` initialization
2. November 2024: Same file, same issue after code changes

## Safety Mechanisms

### 1. Runtime Safety Check (Primary Defense)

**Location:** `AppDependencies.swift` lines 736-798

**How it works:**
```swift
nonisolated static func configureForTesting() {
    // CRITICAL SAFETY CHECK
    guard isRunningInTestBundle() else {
        #if DEBUG
        fatalError("🚨 configureForTesting() called outside test context!")
        #else
        configureForProduction()  // Fallback to production mode
        return
        #endif
    }
    // ... configure mocks
}
```

**Detection method:**
- Checks for XCTest framework: `NSClassFromString("XCTestCase") != nil`
- Checks bundle identifiers for "Tests" suffix
- Verifies against known test bundle names

**Behavior:**
- **DEBUG builds**: Crashes immediately with detailed error message
- **RELEASE builds**: Logs warning and falls back to production mode
- **Test context**: Works normally

### 2. Pre-commit Hook (Secondary Defense)

**Location:** `.git/hooks/pre-commit`

**How it works:**
- Scans all staged Swift files (excluding test files)
- Searches for patterns: `.configureForTesting()` or `AppDependencies.configureForTesting()`
- Blocks commit if found in production code
- Skips `AppDependencies.swift` (where the function is defined)

**Example output when triggered:**
```
🚨 ERROR: Found configureForTesting() in production code!
   File: Molten/Sources/Services/DataLoading/DataLoadingService.swift

   This will put the ENTIRE app in mock mode.
   Replace with: AppDependencies.configureForProduction()

   To bypass this check (NOT recommended):
   git commit --no-verify
```

**To bypass** (only when intentional):
```bash
git commit --no-verify
```

### 3. Documentation and Comments

All calls to `AppDependencies.configureForTesting()` should have comments:
```swift
// ONLY for tests - DO NOT use in production code
AppDependencies.configureForTesting()
```

## Best Practices

### ✅ CORRECT: Production Code

```swift
// In singletons, services, view models
class MyService {
    static let shared = MyService()

    private init() {
        AppDependencies.configureForProduction()  // ✅ Correct
        self.repo = AppDependencies.createMyRepository()
    }
}
```

### ✅ CORRECT: Test Code

```swift
// In test files (MoltenTests, RepositoryTests, etc.)
@Test func testSomething() {
    AppDependencies.configureForTesting()  // ✅ Correct in tests
    // ...
}
```

### ❌ WRONG: Production Code

```swift
class MyService {
    static let shared = MyService()

    private init() {
        AppDependencies.configureForTesting()  // ❌ WRONG - will crash in DEBUG
        self.repo = AppDependencies.createMyRepository()
    }
}
```

## Troubleshooting

### Error: "configureForTesting() called outside of test context!"

**In production code:**
- Replace with: `AppDependencies.configureForProduction()`
- This is always a bug

**In test code:**
- Ensure test file is in correct test target (MoltenTests, RepositoryTests, etc.)
- Check bundle identifier contains "Tests"
- Verify XCTest is properly linked

### Pre-commit hook blocking legitimate test code

The hook should never block test files because it excludes:
- Files in `/Tests/` directories
- Files ending in `Test.swift`

If it's blocking a test file incorrectly:
1. Check the file is in the correct directory
2. Ensure filename matches test conventions
3. Override with `git commit --no-verify` (rare)

## Configuration Modes Reference

| Mode | Use Case | Configure With |
|------|----------|----------------|
| **Production** | Real app, Core Data | `configureForProduction()` |
| **Testing (Mocks)** | Unit tests, fast | `configureForTesting()` |
| **Testing (Core Data)** | Integration tests | `configureForTestingWithCoreData()` |
| **Development** | Mixed/hybrid | `configureForDevelopment()` |

## Related Files

- `AppDependencies.swift` - Factory with safety checks
- `.git/hooks/pre-commit` - Git pre-commit hook
- `CLAUDE.md` - General project architecture guide

## History

- **2024-11-08**: Added runtime safety check and pre-commit hook
- **2024-10-XX**: First occurrence of bug in DataLoadingService
- **2024-11-08**: Second occurrence, same location

---

**Last Updated:** 2024-11-08
**Author:** Claude Code

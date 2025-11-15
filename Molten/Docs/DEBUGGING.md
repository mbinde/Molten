# DEBUGGING.md

Debug guide for working with the Molten test suite.

---

## Test Success Criteria

**CRITICAL**: Tests are NOT complete until BOTH test suites pass at 100%.

### Required Test Suites

1. **Unit Tests** (`UnitTestsOnly` test plan)
   - Location: `Molten/Tests/MoltenTests/`
   - Uses: Mock repositories only
   - Purpose: Fast tests for business logic, services, view models
   - Command: `xcodebuild test -project Molten.xcodeproj -scheme Molten -testPlan UnitTestsOnly -destination 'platform=iOS Simulator,name=iPhone 15'`

2. **Repository Tests** (`RepositoryTests` test plan)
   - Location: `Molten/Tests/RepositoryTests/`
   - Uses: In-memory Core Data, SQLite integration
   - Purpose: Persistence layer integration tests
   - Command: `xcodebuild test -project Molten.xcodeproj -scheme Molten -testPlan RepositoryTests -destination 'platform=iOS Simulator,name=iPhone 15'`

### Success Checklist

- [ ] Repository tests: 100% pass (502/502 as of 2025-11-14)
- [ ] Unit tests: 100% pass (all suites must complete)
- [ ] No crashes during test execution
- [ ] No "TEST FAILED" markers in output
- [ ] All test suites complete (not just partial runs)

---

## Detecting Test Crashes

### Common Crash Patterns

When running tests in the background or checking test output, **ALWAYS** look for these indicators:

#### 1. Exception Markers
- `NSInvalidArgumentException`
- `NSRangeException`
- `NSInternalInconsistencyException`

#### 2. Signal Crashes
- `EXC_BAD_ACCESS`
- `EXC_BREAKPOINT`
- `EXC_BAD_INSTRUCTION`
- `SIGSEGV`
- `SIGABRT`
- `objc_msgSend` (usually indicates messaging a deallocated object)

#### 3. Xcode Test Failures
- `** TEST FAILED **`
- `*** Terminating app due to uncaught exception`
- `*** First throw call stack:`

#### 4. Partial Test Runs
- If you see "35 tests passed" but expect 500+, the suite likely crashed
- Check for "Test Suite 'All tests' started" but no matching "passed" or "failed"

### Proactive Crash Checking

Before reporting test success, ALWAYS:

1. **Check background process outputs**:
   ```bash
   BashOutput tool with filter: "(EXC_|NSInvalidArgumentException|objc_msgSend|SIGSEGV|TEST FAILED|Terminating app)"
   ```

2. **Verify test completion**:
   ```bash
   grep "Test run with" /tmp/test_output.log
   ```
   Should show total test count, not just partial completion

3. **Check for crashes after last test**:
   ```bash
   tail -50 /tmp/test_output.log | grep -E "(crash|exception|signal)"
   ```

---

## Common Crash Scenarios

### 1. Core Data Relationship Issues

**Symptom**: `keypath <attribute> not found in entity <Entity>`

**Cause**:
- Code references non-existent Core Data attribute
- Using wrong keypath (e.g., `plan_id` instead of `plan.id`)
- Attempting to access relationship as attribute

**Fix**:
- Verify Core Data schema: `grep "entity name=" Molten/Molten.xcdatamodeld/Molten\ 16.xcdatamodel/contents`
- Check predicates and sort descriptors for correct keypaths
- Use relationships, not attribute names (e.g., `plan.id` not `plan_id`)

### 2. Service Creation in View Lifecycle

**Symptom**: `_dispatch_assert_queue_fail`, multiple Core Data context crashes

**Cause**: Creating services in `.onAppear`/`.task` instead of `init()`

**Fix**: See CLAUDE.md "Service Creation Anti-Pattern" section

### 3. Test Environment Mixing

**Symptom**: Tests expect mocks but get Core Data (or vice versa)

**Cause**: `AppDependencies` not properly detecting test environment

**Fix**:
- Verify `AppDependencies.shared` in tests
- Check test target membership
- Ensure `forTesting: true` when explicitly creating dependencies

### 4. SQLite Parameter Binding

**Symptom**: Queries return wrong results or all results

**Cause**: Using `nil` instead of `SQLITE_TRANSIENT` for parameter destructor

**Fix**:
```swift
let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
```

---

## Debugging Workflow

### When Tests Fail

1. **Identify the crash**:
   - Read full stack trace
   - Note which test suite was running
   - Identify exact test method if possible

2. **Reproduce locally**:
   - Run single test: `-only-testing:MoltenTests/SuiteClass/testMethod`
   - Add breakpoints on "All Exceptions" in Xcode
   - Check console for error messages

3. **Investigate the code**:
   - Read the repository/service implementation
   - Verify Core Data schema matches code expectations
   - Check for KVC usage with wrong keys
   - Look for relationship vs attribute confusion

4. **Fix and verify**:
   - Apply fix
   - Run affected test suite
   - Run BOTH full test suites to ensure no regressions
   - Check background outputs for crashes

### Test Output Files

Background test runs often write to `/tmp/`:
- `/tmp/unit_test_output.txt`
- `/tmp/repo_test_output.txt`
- `/tmp/final_test_run.log`

Always check these for crash information:
```bash
grep -E "(EXC_|crash|exception|TEST FAILED)" /tmp/*.log
```

---

## Performance Issues

### Tests Taking Too Long

- Repository tests should complete in ~30-60 seconds
- Unit tests should complete in ~10-30 seconds
- If tests hang, check for:
  - Infinite loops in business logic
  - Deadlocks in async/await code
  - Network calls in tests (should be mocked)

### Memory Pressure

- Use instruments to check for leaks
- Verify Core Data contexts are properly released
- Check for retain cycles in closures

---

## Prevention

### Before Committing

1. Run both test suites locally
2. Check for crash indicators in output
3. Verify 100% pass rate on both suites
4. Clean build folder if switching between branches

### During Development

1. Use TDD - write tests first
2. Run tests frequently during implementation
3. Check test output proactively
4. Don't batch multiple features before testing

---

## Quick Reference Commands

```bash
# Run all unit tests
xcodebuild test -project Molten.xcodeproj -scheme Molten -testPlan UnitTestsOnly -destination 'platform=iOS Simulator,name=iPhone 15'

# Run all repository tests
xcodebuild test -project Molten.xcodeproj -scheme Molten -testPlan RepositoryTests -destination 'platform=iOS Simulator,name=iPhone 15'

# Run single test
xcodebuild test -project Molten.xcodeproj -scheme Molten -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:MoltenTests/TestClass/testMethod

# Check for crashes in background output
grep -E "(EXC_|crash|exception|FAILED)" /tmp/test_output.txt

# View Core Data schema
grep -A 20 "entity name=\"EntityName\"" Molten/Molten.xcdatamodeld/Molten\ 16.xcdatamodel/contents

# Kill hung test processes
killall xcodebuild
pkill -9 -f "platform=iOS Simulator"
```

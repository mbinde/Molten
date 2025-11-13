# Unmerged Branches - Current Status

Generated: 2025-11-08

## Summary

**Branches with unmerged work:**
1. ✅ **`tests`** - 30+ commits with test improvements (HIGH PRIORITY)
2. ✅ **`inventory`** - 3 commits with KeyPairManager and ShareCodeGenerator features
3. ❌ **`feature/kilns`** - Fully merged, no unique commits
4. ❌ **`misc`** - Fully merged, no unique commits

## Detailed Analysis

### 1. `tests` Branch ⚠️ HIGH PRIORITY

**Status**: Never merged to main
**Diverged**: At commit `01c654be` (fix: resolve Swift Testing configuration)
**Unique Commits**: 30+

**What's in it:**
- ValidationUtilities test fixes
- 20 test suite fixes
- Swift 6 concurrency fixes (@MainActor annotations)
- DecimalFormattingTests fixes
- Capability tests cleanup
- ServiceValidationTests fixes

**Sample Commits:**
```
85e32220 fix: resolve remaining 3 ValidationUtilities test failures
3e70a161 fix: resolve 20 test failures across 5 test suites
7c84f718 fix: add recoverySuggestion property to AppError
70955168 fix: disable UnifiedLocationModelTests (Swift 6 concurrency)
cf3723e2 fix: remove CapabilityTests.swift references
```

**Recommended Action**: Merge ASAP - contains valuable test improvements

**Merge Command:**
```bash
git checkout main
git pull origin main
git merge origin/tests --no-ff --no-commit
# Resolve conflicts carefully (especially project.pbxproj)
# Run full test suite
# Expect test count to INCREASE from 2140
git commit -m "merge: Integrate test improvements from tests branch"
```

### 2. `inventory` Branch

**Status**: Never merged to main
**Unique Commits**: 3

**What's in it:**
- KeyPairManager with iOS Keychain storage (TDD)
- ShareCodeGenerator for inventory sharing (TDD)
- Test file corrections

**Commits:**
```
8780dbfc feat: implement KeyPairManager with iOS Keychain storage (TDD)
133f61f8 fix: correct ShareCodeGeneratorTests target membership
e2d9999a feat: implement ShareCodeGenerator for inventory sharing (TDD)
```

**Recommended Action**: Review and merge if features are wanted

**Merge Command:**
```bash
git checkout main
git merge origin/inventory --no-ff --no-commit
# Review: Are KeyPairManager and ShareCodeGenerator features we want?
# If yes, complete merge
# If no, close branch without merging
```

### 3. `feature/kilns` Branch ✅

**Status**: Fully merged
**Unique Commits**: 0
**Action**: Can be deleted

```bash
git branch -d feature/kilns
git push origin --delete feature/kilns
```

### 4. `misc` Branch ✅

**Status**: Fully merged
**Unique Commits**: 0
**Action**: Can be deleted

```bash
git branch -d misc
git push origin --delete misc
```

### 5. `refactoring` Branch ⚠️

**Status**: Merged but branch still exists
**Unique Commits**: 0 (all in main)
**Action**: Can be deleted

```bash
git branch -d refactoring
git push origin --delete refactoring
```

## Recommended Merge Order

1. **First**: Merge `tests` branch (highest value, lowest risk)
2. **Second**: Review and decide on `inventory` branch
3. **Third**: Clean up fully-merged branches

## Verification After Each Merge

After merging each branch, run:

```bash
# 1. Build succeeds
xcodebuild build -project Molten.xcodeproj -scheme Molten \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# 2. All tests pass (count should increase after tests branch)
xcodebuild test -project Molten.xcodeproj -scheme Molten \
  -destination 'platform=iOS Simulator,name=iPhone 17' | \
  grep "Test run with"

# 3. Commit only if both succeed
git commit -m "merge: [branch-name]"
git push origin main
```

## Next Session To-Do

- [ ] Merge `tests` branch (follow BRANCH_MERGE_STRATEGY.md)
- [ ] Review `inventory` branch commits and decide if features are needed
- [ ] Clean up fully-merged branches (feature/kilns, misc, refactoring)
- [ ] Adopt short-lived branch workflow going forward

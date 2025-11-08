# Branch Merge Strategy - Preventing Data Loss

## The Problem

We lost work when merging branches because:

1. **Conflict resolution chose wrong version** - Used `git checkout --theirs` which took old branch version
2. **Branches never merged** - `tests` branch has 30+ commits that never made it to main
3. **No verification after merge** - Didn't check that all changes were preserved

## Branches Currently Needing Attention

### Priority 1: `tests` Branch (30+ commits, never merged)
Contains test improvements and fixes from October-November 2024.

**Status**: Diverged from main at `01c654be`, has valuable test work

### Priority 2: Other Active Branches
- `feature/kilns` - Check if has unmerged work
- `inventory` - Check if has unmerged work
- `misc` - Check if has unmerged work

## Safe Merge Process (Follow This Every Time)

### Phase 1: Pre-Merge Verification

```bash
# 1. Ensure main is up to date
git checkout main
git pull origin main

# 2. Check what's different
git log main..origin/BRANCH --oneline

# 3. Count unique commits
git log --oneline origin/BRANCH ^main | wc -l

# 4. Review actual file changes (CRITICAL)
git diff main...origin/BRANCH --stat
```

**🚨 RED FLAG**: If `project.pbxproj` shows changes, extra care needed!

### Phase 2: Safe Merge with Conflict Handling

```bash
# 1. Create backup branch
git checkout -b backup-before-merge-BRANCHNAME

# 2. Return to main and start merge
git checkout main
git merge origin/BRANCH --no-ff --no-commit

# 3. Check for conflicts
git status
```

### Phase 3: Resolving Conflicts (MOST IMPORTANT)

**For `project.pbxproj` conflicts:**

❌ **NEVER DO THIS**:
```bash
git checkout --theirs Molten.xcodeproj/project.pbxproj  # LOSES MAIN'S CHANGES
git checkout --ours Molten.xcodeproj/project.pbxproj    # LOSES BRANCH'S CHANGES
```

✅ **CORRECT APPROACH**:

**Option A: Manual Merge (Safest)**
```bash
# 1. Look at both versions
git show HEAD:Molten.xcodeproj/project.pbxproj > /tmp/main_version.pbxproj
git show origin/BRANCH:Molten.xcodeproj/project.pbxproj > /tmp/branch_version.pbxproj

# 2. Identify what's different
diff /tmp/main_version.pbxproj /tmp/branch_version.pbxproj

# 3. Manually merge - take BOTH sets of changes
# - Keep all package dependencies from main
# - Add all new test files from branch
# - Use a text editor or merge tool
```

**Option B: Accept and Re-add (When Branch is Much Newer)**
```bash
# 1. Take branch version
git checkout origin/BRANCH -- Molten.xcodeproj/project.pbxproj

# 2. Identify what main had that branch doesn't
git log main ^origin/BRANCH --oneline -- Molten.xcodeproj/project.pbxproj

# 3. Re-apply those changes manually
# Example: If main added RevenueCat packages, re-add them after merge
```

**For Code Files (`.swift` files):**
```bash
# Open in your editor's 3-way merge tool
# VSCode: Shows "Current Change | Incoming Change | Both Changes"
# Choose "Both Changes" when both are valid additions
```

### Phase 4: Post-Merge Verification (CRITICAL)

```bash
# 1. Build succeeds
xcodebuild build -project Molten.xcodeproj -scheme Molten \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# 2. All tests pass
xcodebuild test -project Molten.xcodeproj -scheme Molten \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# 3. Verify specific features that were added
# - Check that test files from branch are present
# - Check that RevenueCat still works (if in main)
# - Run specific tests that were added

# 4. Review the merge commit
git diff HEAD~1 HEAD --stat  # See all changed files
git log -1 -p                # See full diff
```

### Phase 5: Commit and Push

```bash
# Only if all checks pass
git commit -m "merge: Integrate BRANCH into main

Verified:
- Build succeeds
- All 2140 tests pass
- RevenueCat integration preserved
- New test files from branch included"

git push origin main
```

## Specific Recovery Tasks

### Task 1: Merge `tests` Branch

```bash
# Follow complete process above
git checkout main
git merge origin/tests --no-ff --no-commit

# Expect conflicts in:
# - project.pbxproj (test file references)
# - Possibly some test files

# After resolving:
# - Verify all new test files are in MoltenTests target
# - Run full test suite
# - Should have MORE than 2140 tests after merge
```

### Task 2: Check Other Branches

```bash
for branch in feature/kilns inventory misc; do
  echo "=== Checking $branch ==="
  commits=$(git log --oneline origin/$branch ^main | wc -l)
  echo "Unique commits: $commits"
  git log --oneline origin/$branch ^main | head -5
  echo ""
done
```

## Prevention: New Workflow

### Daily/Per-Feature Workflow

1. **Work on focused feature branches** (not long-lived branches)
2. **Merge to main frequently** (every 1-3 days max)
3. **Delete branch after successful merge**

### Branch Naming Convention

```
feature/short-description  # For new features (merge within 3 days)
fix/bug-description        # For bug fixes (merge within 1 day)
test/test-name            # For test additions (merge same day)
```

### Pre-Merge Checklist

- [ ] All tests pass on branch
- [ ] No conflicts with current main
- [ ] Branch is < 3 days old
- [ ] Changes are focused (not mixing features with tests with refactoring)

## Red Flags to Watch For

1. **Branch is more than 1 week old** → High risk of conflicts
2. **More than 50 commits** → Hard to review merge
3. **Changes to `project.pbxproj`** → Very likely to conflict
4. **Multiple people working on same files** → Coordination needed

## Tools to Help

### Git Aliases (Add to `~/.gitconfig`)

```ini
[alias]
    # Safe merge with backup
    safe-merge = "!f() { \
        git checkout -b backup-before-merge-$1 && \
        git checkout main && \
        git merge origin/$1 --no-ff --no-commit; \
    }; f"

    # Show what's unique in branch
    branch-diff = "!f() { \
        git log --oneline origin/$1 ^main; \
    }; f"

    # Verify merge result
    verify-merge = "!f() { \
        xcodebuild build -project Molten.xcodeproj -scheme Molten -destination 'platform=iOS Simulator,name=iPhone 17' && \
        xcodebuild test -project Molten.xcodeproj -scheme Molten -destination 'platform=iOS Simulator,name=iPhone 17'; \
    }; f"
```

### Usage

```bash
# Instead of direct merge:
git safe-merge tests

# Review changes:
git branch-diff tests

# After merge, verify:
git verify-merge
```

## Emergency: Recovering from Bad Merge

If you merged and lost work:

```bash
# 1. Find the commit before merge
git reflog | grep "before-merge"

# 2. Reset to before merge (CAREFUL)
git reset --hard <commit-hash>

# 3. Re-attempt merge with correct process
# Follow "Safe Merge Process" above
```

## Summary: Key Principles

1. ✅ **Always use `--no-commit`** to review before finalizing
2. ✅ **Never use `--theirs` or `--ours` for project.pbxproj**
3. ✅ **Always verify build + tests after merge**
4. ✅ **Merge branches frequently** (don't let them get stale)
5. ✅ **Keep branches focused** (one feature/fix per branch)
6. ❌ **Never force push to main**
7. ❌ **Never delete unmerged branches**

## Next Steps (Immediate)

1. [ ] Merge `tests` branch using safe process
2. [ ] Check `feature/kilns`, `inventory`, `misc` for unmerged work
3. [ ] Set up git aliases for safe merging
4. [ ] Adopt short-lived branch workflow going forward

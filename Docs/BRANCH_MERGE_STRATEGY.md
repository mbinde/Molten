# Branch Merge Strategy - MANDATORY PROCESS

## CRITICAL RULES

1. ❌ **NEVER** use `git checkout --theirs` or `git checkout --ours` for `project.pbxproj`
2. ✅ **ALWAYS** use `--no-commit` flag when merging
3. ✅ **ALWAYS** verify build + tests before committing merge
4. ✅ **ALWAYS** manually merge `project.pbxproj` conflicts

---

## STEP-BY-STEP MERGE PROCESS

### Step 1: Pre-Merge Check
```bash
git checkout main
git pull origin main
git log --oneline origin/BRANCH ^main    # See what's being merged
git diff main...origin/BRANCH --stat     # See file changes
```

### Step 2: Start Merge
```bash
git merge origin/BRANCH --no-ff --no-commit
```

### Step 3: Handle Conflicts

#### If `project.pbxproj` has conflicts:

**DO THIS:**
```bash
# 1. Save both versions
git show HEAD:Molten.xcodeproj/project.pbxproj > /tmp/main.pbxproj
git show origin/BRANCH:Molten.xcodeproj/project.pbxproj > /tmp/branch.pbxproj

# 2. See what's different
diff /tmp/main.pbxproj /tmp/branch.pbxproj

# 3. Manually combine BOTH versions:
#    - Keep ALL package dependencies from main
#    - Add ALL new files from branch
#    - Use text editor to merge sections
```

**NOT THIS:**
```bash
git checkout --theirs Molten.xcodeproj/project.pbxproj  # ❌ LOSES MAIN'S CHANGES
git checkout --ours Molten.xcodeproj/project.pbxproj    # ❌ LOSES BRANCH'S CHANGES
```

#### For `.swift` file conflicts:
```bash
# Open in editor's merge tool
# Choose "Accept Both Changes" when both are valid additions
# Manually resolve when changes overlap
```

### Step 4: Verify Merge (MANDATORY)
```bash
# Build must succeed
xcodebuild build -project Molten.xcodeproj -scheme Molten \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# Tests must pass
xcodebuild test -project Molten.xcodeproj -scheme Molten \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

### Step 5: Commit Only If Verification Passes
```bash
git commit -m "merge: BRANCH into main

Verified:
- Build succeeds
- Tests pass (count: X)
- [List key features preserved]"

git push origin main
```

---

## CONFLICT RESOLUTION CHECKLIST

When you see conflicts in `project.pbxproj`:

- [ ] I saved both versions to /tmp
- [ ] I compared them with diff
- [ ] I manually merged BOTH sets of changes
- [ ] I did NOT use `--theirs` or `--ours`
- [ ] Build succeeds after merge
- [ ] Tests pass after merge

---

## EMERGENCY: Undo Bad Merge

If you already committed a bad merge:

```bash
# Find commit before merge
git reflog

# Reset to before merge
git reset --hard <commit-before-merge>

# Start over with correct process
```

---

## Quick Reference Card

**Starting merge:**
```bash
git merge origin/BRANCH --no-ff --no-commit
```

**Handling project.pbxproj conflict:**
```bash
# Save both → Compare → Manually merge BOTH
git show HEAD:Molten.xcodeproj/project.pbxproj > /tmp/main.pbxproj
git show origin/BRANCH:Molten.xcodeproj/project.pbxproj > /tmp/branch.pbxproj
diff /tmp/main.pbxproj /tmp/branch.pbxproj
# Edit Molten.xcodeproj/project.pbxproj to include BOTH sets of changes
git add Molten.xcodeproj/project.pbxproj
```

**Verification (MANDATORY before commit):**
```bash
xcodebuild build -project Molten.xcodeproj -scheme Molten -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild test -project Molten.xcodeproj -scheme Molten -destination 'platform=iOS Simulator,name=iPhone 17'
```

**Only commit if both succeed:**
```bash
git commit -m "merge: BRANCH into main"
git push origin main
```

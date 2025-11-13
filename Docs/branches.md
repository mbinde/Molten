# Git Branch Workflow for Claude Code

**Instructions for Claude Code when starting work on a new feature.**

## ⚠️ CRITICAL RULE: ALWAYS PUSH AFTER EVERY COMMIT

**Every time you commit, immediately push to remote.** The user works across multiple machines and needs instant access to all changes. Never leave commits unpushed.

## Getting a Fresh Copy of the Repository

If you need to clone the repository to a new local directory:

```bash
git clone git@github.com:mbinde/Molten.git subs

# Navigate into the cloned repository
cd subs

# Verify you're on the main branch
git branch --show-current

# Check status
git status
```

After cloning, you'll have a clean working tree on the `main` branch, ready to create feature branches.

---

## Before Starting ANY Work

1. **Check current branch status:**
   ```bash
   git status
   git branch --show-current
   ```

2. **If there are uncommitted changes on a feature branch:**
   - Ask the user: "There are uncommitted changes on branch `feature/xyz`. Should I continue working on this feature, or switch to something else?"
   - If continuing: proceed with the existing branch
   - If switching: commit the changes first, then switch branches

3. **If on `main` branch with no uncommitted changes:**
   - Good! You're ready to start a new feature branch

4. **If on `main` branch WITH uncommitted changes:**
   - These changes should be committed to a feature branch FIRST before starting new work

## Starting a New Feature

**The user will tell you the feature name.** Use this workflow:

```bash
# 1. Ensure you're on main and up to date
git checkout main
git pull

# 2. Create and switch to new feature branch
# Format: feature/descriptive-name-with-hyphens
git checkout -b feature/your-feature-name

# 3. Confirm the switch
git branch --show-current
```

**Branch naming conventions:**
- Use `feature/` prefix for new features
- Use `fix/` prefix for bug fixes
- Use `refactor/` prefix for code refactoring
- Use kebab-case: `feature/store-maps-split-view`
- Be descriptive: `feature/inventory-csv-export` not `feature/csv`

## Working on the Feature

1. **Make changes as requested by the user**

2. **Commit frequently** (after completing logical chunks of work):
   ```bash
   git add .
   git commit -m "feat: descriptive commit message"
   ```

3. **⚠️ ALWAYS PUSH IMMEDIATELY AFTER COMMITTING** (so other computers can access it):
   ```bash
   # First push on new branch:
   git push -u origin feature/your-feature-name

   # All subsequent pushes:
   git push
   ```

   **Why push after every commit?**
   - User may want to access work from different machines
   - Prevents lost work if session ends unexpectedly
   - Makes it easy to switch between computers mid-feature
   - Ensures remote repository is always up-to-date

4. **Follow TDD principles:**
   - Write tests first
   - Commit after RED phase (failing tests)
   - Commit after GREEN phase (passing tests)
   - Commit after REFACTOR phase

## Commit Message Conventions

Use conventional commit format:

- `feat: add split view layout to stores` - New feature
- `fix: resolve crash when loading stores` - Bug fix
- `refactor: extract LocationManager to separate file` - Code refactoring
- `test: add unit tests for StoreListViewModel` - Adding tests
- `docs: update README with API documentation` - Documentation only

## Adding Test Files to Xcode

**CRITICAL: When you create test files, you MUST add them to the test target AND commit the project file.**

### Automated Workflow (Default)

```bash
# 1. Create the test file (already done via Write tool)

# 2. Add to Xcode test target automatically
ruby add-test-to-xcode.rb Tests/MoltenTests/Your/TestFile.swift

# 3. IMMEDIATELY commit BOTH files together
git add Tests/MoltenTests/Your/TestFile.swift
git add Molten.xcodeproj/project.pbxproj
git commit -m "test: add Your tests"
git push
```

### Why This Matters

- The `project.pbxproj` file stores which files belong to which targets
- Once committed, **anyone** checking out your branch gets the file in the correct target automatically
- Without committing `project.pbxproj`, users would have to manually re-add the file every time
- This is especially important with multiple workspaces and branches

### Manual Fallback

If the script fails (missing `xcodeproj` gem):

```bash
# Ask user to manually add the file
# Then commit the project file they modified:
git add Tests/MoltenTests/Your/TestFile.swift
git add Molten.xcodeproj/project.pbxproj
git commit -m "test: add Your tests"
git push
```

### For Different Test Targets

```bash
# MoltenTests (unit tests - default)
ruby add-test-to-xcode.rb Tests/MoltenTests/YourTest.swift

# RepositoryTests (Core Data integration tests)
ruby add-test-to-xcode.rb Tests/RepositoryTests/YourTest.swift
```

## When Feature is Complete

**Ask the user: "This feature is complete and ready to merge. Should I merge it to main now, or leave it on the feature branch?"**

If user says merge:

```bash
# 1. Commit any final changes
git add .
git commit -m "feat: complete feature description"
git push

# 2. Switch to main and update
git checkout main
git pull

# 3. Merge the feature branch
git merge feature/your-feature-name

# 4. Check for conflicts
# If conflicts exist, you'll see:
# CONFLICT (content): Merge conflict in SomeFile.swift
# Ask user how to resolve, or handle automatically if obvious

# 5. Push merged changes
git push

# 6. Ask user: "Feature merged successfully. Should I delete the feature branch?"
# If yes:
git branch -d feature/your-feature-name
git push origin --delete feature/your-feature-name
```

## If Switching Between Features

**When user says: "Stop working on this feature, let's work on something else"**

```bash
# 1. Commit current work
git add .
git commit -m "wip: describe current state"
git push

# 2. Switch to main
git checkout main
git pull

# 3. Create new feature branch (see "Starting a New Feature" above)
git checkout -b feature/new-feature-name
```

## Important Reminders

- ✅ **DO** work on one feature per branch
- ✅ **DO** commit frequently with descriptive messages
- ✅ **DO** push immediately after EVERY commit (not just periodically)
- ✅ **DO** ask before merging to main
- ⚠️ **CRITICAL:** Always push after committing - the user needs access from other machines
- ❌ **DON'T** work on multiple unrelated features in one branch
- ❌ **DON'T** commit directly to `main` unless explicitly instructed
- ❌ **DON'T** merge without asking the user first
- ❌ **DON'T** delete branches without asking the user first
- ❌ **DON'T** leave commits unpushed - always push immediately

## Quick Reference

```bash
# Check where you are
git status
git branch --show-current

# Start new feature
git checkout main && git pull
git checkout -b feature/name

# Save work (ALWAYS push immediately after commit!)
git add .
git commit -m "feat: description"
git push  # ⚠️ NEVER SKIP THIS STEP

# Finish feature (with user approval)
git checkout main && git pull
git merge feature/name
git push
```

## What to Tell the User

When starting work, tell the user:

> "I'm creating a new feature branch called `feature/xyz` and will work there. All changes will be isolated from `main` until we're ready to merge."

When feature is complete, tell the user:

> "The feature is complete on branch `feature/xyz`. I can merge it to `main` when you're ready, or we can leave it on the branch for now."

## Troubleshooting

**"You are in 'detached HEAD' state"**
```bash
# Create a branch from current state
git checkout -b feature/recovery-branch
```

**"Your branch is behind 'origin/main'"**
```bash
git pull
```

**"Merge conflict"**
- Ask user for guidance
- Show which files have conflicts
- Offer to show the conflicting sections

**"Can't switch branches, uncommitted changes"**
```bash
# Commit them first
git add .
git commit -m "wip: saving before branch switch"
```

---

**Remember: When in doubt, ask the user. It's better to ask than to make assumptions about merging or deleting branches.**

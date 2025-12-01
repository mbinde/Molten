# Git Merge Workflow: Combining Branch Changes with Main

> **⚠️ IMPORTANT: NEVER follow this workflow automatically. Only execute these steps when the user explicitly tells you to merge or "follow GIT_MERGE_WORKFLOW". Always run full tests and get user approval before merging.**

## Scenario
- `origin/main` has important changes
- Local branch (e.g., `arch`) has important changes
- Goal: ALL changes from BOTH branches deployed to `origin/main`

## The Correct Workflow

### Step 0: Update local main to match origin/main FIRST
```bash
git checkout main
git pull origin main
```
**CRITICAL**: Must fetch latest from origin before merging. Otherwise you're merging stale local main.

### Step 1: Bring main's changes INTO your working branch
```bash
git checkout arch
git merge main
```
**Resolve conflicts carefully**: Go line-by-line, make wise choices, ask about edge cases

### Step 2: Test everything on the merged branch
```bash
# Run all tests to verify the merge didn't break anything
xcodebuild test ...
```

### Step 3: Merge your branch INTO main
```bash
git checkout main
git merge arch
```
**This should be fast-forward** (no conflicts) because we already resolved everything in Step 1

### Step 4: Push to origin
```bash
git push origin main
```

### Step 5: Switch back to your working branch
```bash
git checkout arch
```

## What You Should Tell Me
"Update local main from origin, merge main into arch, resolve conflicts carefully, then merge arch into main and push to origin"

OR simply: "Follow GIT_MERGE_WORKFLOW.md"

## What I Should NEVER Do
- Use `--ours` or `--theirs` without asking
- Skip examining what changed in conflicting files
- Use rebase when you said merge
- Assume which changes to keep without checking

## If Step 4 Fails (remote has new commits)
DO NOT rebase. Instead:
1. Ask you what to do
2. OR: `git pull origin main` (regular merge, not rebase)
3. Then push again

## IMPORTANT: Do NOT Delete Branches
After completing the workflow, **DO NOT delete the working branch**. The user keeps their working branches for ongoing development. Step 5 switches back to the working branch - that's the final step. Never run `git branch -d` unless explicitly asked.

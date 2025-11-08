# Branch Shutdown Checklist

This document provides a step-by-step checklist for properly completing and closing a development branch to ensure no work is lost and all changes are safely committed to the repository.

## ⚠️ WHY THIS MATTERS

Incomplete shutdowns can result in:
- **Lost work**: Uncommitted changes never make it to the repository
- **Broken builds**: Uncommitted changes make local builds succeed but remote builds fail
- **Lost context**: Future sessions can't see what was in progress
- **Merge conflicts**: Stale branches diverge from main and become hard to merge

## 📋 BRANCH SHUTDOWN CHECKLIST

### Phase 1: Verify Working Tree Status

**Goal**: Ensure all changes are tracked and no work is lost.

- [ ] **Check git status**: Run `git status` to see what's changed
  ```bash
  git status
  ```

- [ ] **Review untracked files**: Identify any new files not yet added to git
  - Look for files listed under "Untracked files:"
  - Decide if each should be committed or ignored

- [ ] **Review modified files**: Check what existing files have changes
  - Look for files listed under "Changes not staged for commit:"
  - Review changes with `git diff <file>` if needed

- [ ] **Review staged files**: Check what's ready to commit
  - Look for files listed under "Changes to be committed:"

**Red Flags**:
- ❌ Untracked `.swift` files → Likely forgot to commit new code
- ❌ Modified test files → Tests may not be in repository
- ❌ Modified `.xcodeproj/project.pbxproj` → Project structure changes not saved

### Phase 2: Commit All Changes

**Goal**: Save all work to git history.

- [ ] **Add untracked files**: Add new files that should be committed
  ```bash
  git add <file1> <file2> ...
  # OR add everything:
  git add .
  ```

- [ ] **Commit changes**: Create commit(s) with descriptive messages
  ```bash
  git commit -m "descriptive message explaining what changed"
  ```

- [ ] **Verify clean status**: Confirm working tree is clean
  ```bash
  git status
  # Should show: "nothing to commit, working tree clean"
  ```

**Best Practices**:
- ✅ Group related changes into single commits
- ✅ Use clear, descriptive commit messages
- ✅ Commit messages should explain "why" not just "what"
- ✅ Test files and source files can be in same commit if related

### Phase 3: Push to Remote Repository

**Goal**: Backup all work to GitHub so it's not lost.

- [ ] **Push branch to remote**: Upload all commits
  ```bash
  git push
  # OR if first push:
  git push -u origin <branch-name>
  ```

- [ ] **Verify push succeeded**: Check for success message
  - Should see: "To github.com:user/repo.git"
  - Should see: "branch-name -> branch-name"

- [ ] **Check GitHub web UI**: Confirm branch exists on GitHub
  - Visit https://github.com/user/repo/branches
  - Your branch should be listed with latest commit

**Red Flags**:
- ❌ "Everything up-to-date" but you just made commits → Push failed, try again
- ❌ "Repository not found" → Check remote URL with `git remote -v`
- ❌ "Permission denied" → Check GitHub authentication

### Phase 4: Verify Build and Tests

**Goal**: Ensure the branch is in a good state for future work or merging.

- [ ] **Build succeeds**: Verify project compiles
  ```bash
  xcodebuild -project Molten.xcodeproj -scheme Molten -configuration Debug build
  ```

- [ ] **Unit tests pass**: Run fast unit tests
  ```bash
  xcodebuild test -project Molten.xcodeproj -scheme Molten \
    -testPlan UnitTestsOnly \
    -destination 'platform=iOS Simulator,name=iPhone 17'
  ```

- [ ] **Document known issues**: If tests fail, document why
  - Add comment to PR or create issue
  - Note which tests are failing and why
  - Mark tests as `.disabled()` with explanation if needed

**When to Skip**:
- 🟡 If stopping mid-feature: OK to have failing tests, but document
- 🟡 If fixing bugs: OK to have known issues, but list them
- 🔴 If merging to main: MUST have all tests passing

### Phase 5: Document Current State

**Goal**: Leave breadcrumbs for next session.

- [ ] **Update PR description**: If PR exists, update with current status
  - What's complete
  - What's in-progress
  - What's remaining
  - Any blockers or issues

- [ ] **Create PR if needed**: If branch is ready for review
  ```bash
  gh pr create --title "Title" --body "Description"
  ```

- [ ] **Add TODO.md**: If work is incomplete, document what's next
  - Create `Docs/TODO-<branch-name>.md` with next steps
  - List any decisions that need to be made
  - Note any assumptions or context

- [ ] **Update CLAUDE.md**: If new patterns or rules were established
  - Add to architecture guidelines
  - Document new conventions
  - Update testing requirements

**Example TODO.md**:
```markdown
# TODO: Refactoring Branch

## Completed
- ✅ Moved domain models to Models/Domain/
- ✅ Fixed project file references
- ✅ All 1,512 tests passing

## In Progress
- 🔄 Fixing RepositoryTests (found pre-existing bugs)

## Next Steps
1. Fix CoreDataUserTagsRepository bug (remove item_stable_id)
2. Run full RepositoryTests suite
3. Merge to main if all tests pass

## Blockers
- None

## Notes
- TransformableMigrationHelper tests disabled (require old model)
- UserTags entity never had item_stable_id attribute
```

### Phase 6: Final Verification

**Goal**: Triple-check nothing was forgotten.

- [ ] **Review commit log**: Check all commits are pushed
  ```bash
  git log --oneline -10
  ```

- [ ] **Compare local vs remote**: Verify branches are in sync
  ```bash
  git fetch
  git log HEAD..origin/<branch-name>  # Should be empty
  git log origin/<branch-name>..HEAD  # Should be empty
  ```

- [ ] **Check file count**: Verify all files are committed
  ```bash
  git ls-files | wc -l  # Count tracked files
  find . -name "*.swift" -not -path "./build/*" | wc -l  # Count Swift files
  # Numbers should be close (difference = build artifacts, etc.)
  ```

- [ ] **Verify on different machine**: If possible, clone and build
  ```bash
  # On different machine or directory:
  git clone <repo-url> test-clone
  cd test-clone
  git checkout <branch-name>
  xcodebuild build
  ```

**The Gold Standard**:
- ✅ Fresh clone + checkout + build = succeeds → Branch is safe
- ❌ Fresh clone + checkout + build = fails → Something missing

### Phase 7: Communication & Handoff

**Goal**: Ensure team/future-you knows what happened.

- [ ] **Update issue tracker**: Close or update related issues
  - Link commits to issues
  - Update issue status
  - Add "Ready for Review" label if applicable

- [ ] **Tag reviewers**: If PR exists, request reviews
  ```bash
  gh pr edit --add-reviewer username
  ```

- [ ] **Write handoff notes**: Document for future session
  - What was accomplished
  - What's remaining
  - How to test
  - Any gotchas or quirks

**For Claude Code Sessions**:
- 📝 Leave detailed PR description (Claude can't see previous sessions)
- 📝 Update CLAUDE.md with new patterns learned
- 📝 Add inline comments for complex decisions made

## 🚨 EMERGENCY SHUTDOWN

If you need to stop immediately (power outage, urgent interruption):

**Minimum Actions** (in order of importance):

1. **Commit everything**:
   ```bash
   git add -A
   git commit -m "WIP: emergency save"
   ```

2. **Push immediately**:
   ```bash
   git push
   ```

3. **Note what you were doing**:
   ```bash
   echo "Working on: <task>" >> EMERGENCY-NOTES.txt
   git add EMERGENCY-NOTES.txt
   git commit -m "Emergency notes"
   git push
   ```

Even a "WIP" commit is better than losing work!

## 📊 VERIFICATION COMMANDS SUMMARY

Quick reference for verification commands:

```bash
# Status checks
git status                          # Working tree status
git log --oneline -10               # Recent commits
git diff HEAD..origin/<branch>      # Local vs remote diff

# Remote checks
git fetch                           # Update remote info
git branch -vv                      # Show tracking branches
git remote -v                       # Show remote URLs

# Build verification
xcodebuild build                    # Test build
xcodebuild test -testPlan UnitTestsOnly  # Test unit tests

# File counts
git ls-files | wc -l                # Tracked files
git status --short | wc -l          # Modified files
```

## 🎯 COMMON MISTAKES TO AVOID

1. **"I pushed, right?"**
   - ❌ Assuming `git commit` pushes to remote (it doesn't)
   - ✅ Always explicitly `git push` after committing

2. **"Working tree clean = pushed"**
   - ❌ Clean working tree just means no uncommitted changes
   - ✅ Check `git log HEAD..origin/branch` to see unpushed commits

3. **"Tests passed locally = safe"**
   - ❌ Local tests might use uncommitted files
   - ✅ Verify clean clone + checkout + build works

4. **"I'll commit it later"**
   - ❌ Uncommitted changes are only on your machine
   - ✅ Commit immediately, refine commit message later if needed

5. **"Just the Swift files matter"**
   - ❌ Forgetting .xcodeproj, test files, docs, configs
   - ✅ Review ALL modified files with `git status`

## 📚 DETAILED EXPLANATIONS

### Why Check Both Local and Remote?

Git is a **distributed** version control system. You have:
- **Local repository**: On your machine (commits, branches, history)
- **Remote repository**: On GitHub (backup, collaboration)

Changes flow: `Working Directory → Staging → Local Repo → Remote Repo`

Commands:
- `git add`: Working Directory → Staging
- `git commit`: Staging → Local Repo
- `git push`: Local Repo → Remote Repo

**You can commit without pushing!** That's why we verify both.

### Why Verify Clean Clone?

Your local environment might have:
- Uncommitted files in `.gitignore`
- Build artifacts that accidentally work
- Environment-specific configs

A clean clone simulates:
- New team member checking out code
- CI/CD system running tests
- You on a different machine

If clean clone fails → something's missing from repository.

### Why Document State?

Scenarios where documentation saves you:

1. **Context switching**: Interrupted for urgent bug fix, forget what you were doing
2. **Long gaps**: Come back to branch weeks later, don't remember decisions
3. **Team collaboration**: Someone else needs to continue your work
4. **AI assistance**: Claude Code can't see previous conversations, needs written context

Documentation is **insurance** against memory loss and context loss.

## ✅ FINAL CHECKLIST SUMMARY

Use this quick checklist for every branch shutdown:

```
[ ] git status shows clean working tree
[ ] git log shows all commits made
[ ] git push succeeded with confirmation
[ ] GitHub shows branch with latest commit
[ ] Build succeeds (xcodebuild build)
[ ] Tests pass or failures documented
[ ] PR exists and is updated (if needed)
[ ] TODO/notes documented (if incomplete)
[ ] Verified: git log HEAD..origin/<branch> is empty
```

**Time estimate**: 5-10 minutes for complete shutdown.

**Worth it?** Absolutely. Prevents hours of lost work and debugging.

---

## 📖 FOR CLAUDE CODE: SESSION SHUTDOWN PROTOCOL

When user says "pause development", "stop for now", or similar:

1. **Immediate**: Run `git status` and report any uncommitted changes
2. **Commit**: Offer to commit all changes with appropriate messages
3. **Push**: Always push after committing
4. **Verify**: Run verification commands and report status
5. **Document**: Create/update TODO.md with current state
6. **Report**: Provide clear summary of what's been saved and what's next

**Never assume**:
- ❌ Don't assume user will manually push
- ❌ Don't assume uncommitted files are intentional
- ❌ Don't assume tests will pass later

**Always verify**:
- ✅ Working tree is clean OR changes are documented
- ✅ All commits are pushed to remote
- ✅ Branch state is documented for next session

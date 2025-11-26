# Release Workflow

How to prepare and track App Store releases for Molten.

---

## Quick Reference

```bash
# See what changed since last release
git log --oneline v1.0.0..HEAD

# Tag a release
git tag -a v1.1.0 -m "App Store release 1.1.0"
git push origin v1.1.0
```

---

## Full Release Workflow

### 1. Prepare Release Notes

```bash
# See all commits since the last release tag
git log --oneline v1.0.0..HEAD

# Or with more detail
git log v1.0.0..HEAD --pretty=format:"- %s"
```

### 2. Update CHANGELOG.md

Move items from `[Unreleased]` to a new version section:

```markdown
## [1.1.0] - 2025-11-26

### Added
- Feature X
- Feature Y

### Fixed
- Bug Z
```

Write user-friendly descriptions, not commit messages. Group related changes.

### 3. Commit the Changelog

```bash
git add CHANGELOG.md
git commit -m "docs: prepare release notes for v1.1.0"
```

### 4. Tag the Release

**Tag BEFORE submitting to App Store** (so the tag matches exactly what was submitted):

```bash
git tag -a v1.1.0 -m "App Store release 1.1.0"
git push origin v1.1.0
```

### 5. Submit to App Store

- Archive in Xcode
- Upload to App Store Connect
- Add release notes from CHANGELOG.md to App Store Connect

### 6. After Approval (Optional)

If you want to track the approval date:
```bash
# Add a lightweight tag for the approval
git tag v1.1.0-approved
git push origin v1.1.0-approved
```

---

## Tag Naming Convention

| Tag | Meaning |
|-----|---------|
| `v1.0.0` | App Store submission for version 1.0.0 |
| `v1.0.1` | App Store submission for version 1.0.1 (bug fix) |
| `v1.1.0` | App Store submission for version 1.1.0 (new features) |
| `v2.0.0` | App Store submission for version 2.0.0 (breaking changes) |

---

## Version Numbering (Semantic Versioning)

- **MAJOR** (2.0.0): Breaking changes, major redesigns
- **MINOR** (1.1.0): New features, backward compatible
- **PATCH** (1.0.1): Bug fixes, backward compatible

The build number (CURRENT_PROJECT_VERSION in Xcode) increments with each build and is separate from the marketing version.

---

## Useful Commands

```bash
# List all release tags
git tag -l "v*"

# Show what's in a specific release
git show v1.0.0

# Compare two releases
git log v1.0.0..v1.1.0 --oneline

# See commits not yet in any release
git log $(git describe --tags --abbrev=0)..HEAD --oneline

# Delete a tag (if you made a mistake)
git tag -d v1.0.0
git push origin :refs/tags/v1.0.0
```

---

## Writing Good Release Notes

**For CHANGELOG.md** (developer-focused):
- Be specific about what changed
- Reference issue numbers if applicable
- Group by type (Added, Fixed, Changed)

**For App Store** (user-focused):
- Focus on benefits, not implementation
- Use plain language
- Keep it brief (users skim)
- Highlight the most exciting changes first

Example transformation:
- CHANGELOG: "Centralized image loading with automatic gradient fallback for items without product photos"
- App Store: "Items without photos now show beautiful color gradients based on the glass color"

---

## TestFlight Builds

For TestFlight-only builds that won't go to the App Store:
- No need to tag unless it's a significant milestone
- Keep notes in `[Unreleased]` section of CHANGELOG.md
- When ready for App Store, consolidate into a release version

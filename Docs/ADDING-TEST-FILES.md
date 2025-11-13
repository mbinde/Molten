# Guide: Adding Test Files to Xcode Project

## Critical Rules (learned the hard way)

### 1. File Location on Disk

**ALWAYS create test files in the correct physical location FIRST:**

```
Molten/Tests/MoltenTests/        # Unit tests (mocks only)
Molten/Tests/RepositoryTests/    # Core Data integration tests
Molten/Tests/PerformanceTests/   # Performance tests
Molten/Tests/MoltenUITests/      # UI automation tests
```

**NEVER create test files in:**
- Project root `Tests/` directory
- Any location outside `Molten/Tests/`
- Nested duplicates like `Molten/Tests/Molten/Tests/`

### 2. Using the Script to Add Files

After creating the file on disk, use the script to add it to the Xcode project:

```bash
# The script auto-detects the target from the path
ruby add-file-to-project.rb Molten/Tests/MoltenTests/Views/MyTests.swift

# Or explicitly specify target (if auto-detection fails)
ruby add-file-to-project.rb Molten/Tests/MoltenTests/Views/MyTests.swift MoltenTests
```

**The script handles:**
- Creating proper group hierarchy in Xcode (matching file path)
- Adding file reference with correct path settings
- Adding file to appropriate test target
- **NOT adding file to Molten target (app)**

### 3. Xcode Project Structure Rules

#### Groups vs Physical Files

Xcode has TWO separate hierarchies:

1. **Physical file system**: Where files actually live on disk
2. **Xcode groups**: Virtual folders shown in Xcode's project navigator

**Critical: These must match for paths to resolve correctly.**

#### Group Path Settings

Groups should use **relative paths** with `source_tree = '<group>'`:

**CORRECT:**
```ruby
Tests group:
  path: 'Molten/Tests'        # Relative to project root
  source_tree: '<group>'

MoltenTests group (child of Tests):
  path: 'MoltenTests'          # Relative to parent (just the name)
  source_tree: '<group>'
```

**WRONG:**
```ruby
MoltenTests group:
  path: 'Molten/Tests/MoltenTests'  # ❌ Absolute path causes nested resolution
  source_tree: '<group>'
```

#### File Reference Settings

Individual files should use **just the filename** with `source_tree = '<group>'`:

**CORRECT:**
```ruby
File reference:
  path: 'MyTests.swift'        # Just filename
  source_tree: '<group>'
  Parent: Services group
```

**WRONG:**
```ruby
File reference:
  path: 'Molten/Tests/MoltenTests/Services/MyTests.swift'  # ❌ Full path
  source_tree: '<group>'
```

#### How Path Resolution Works

Given this group hierarchy:
```
Main Group (project root)
└── Tests (path: 'Molten/Tests')
    └── MoltenTests (path: 'MoltenTests')
        └── Services (path: 'Services')
            └── MyTests.swift (path: 'MyTests.swift')
```

The final resolved path is:
```
<project_root> + Molten/Tests + MoltenTests + Services + MyTests.swift
= /Users/you/project/Molten/Tests/MoltenTests/Services/MyTests.swift
```

### 4. Test Files Must NOT Be in Molten Group

**The Tests group MUST be at the root level, not nested under Molten:**

**CORRECT structure:**
```
Main Group
├── Molten (contains app source files)
│   ├── Sources/
│   └── Resources/
├── Tests (NOT under Molten!)
│   ├── MoltenTests/
│   ├── PerformanceTests/
│   └── RepositoryTests/
└── Products
```

**WRONG structure (causes tests to compile in Molten target):**
```
Main Group
├── Molten
│   ├── Sources/
│   ├── Tests/          # ❌ Tests under Molten group
│   │   ├── MoltenTests/
│   │   └── ...
└── Products
```

**Why this matters:**
- Everything under the Molten group gets compiled into the Molten app target
- App target doesn't have Testing framework → "Unknown attribute 'Suite'" errors
- Test files should ONLY compile in their respective test targets

### 5. Never "Fix" by Wrapping Entire File in Conditionals

**NEVER do this:**
```swift
#if canImport(Testing)
import Testing

@Suite("My Tests")
struct MyTests {
  // all test code
}
#endif
```

**Why:** This just hides the problem. The real issue is project configuration.

**Conditional imports are fine (and correct):**
```swift
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

// Test code here (NOT inside #if)
@Suite("My Tests")
struct MyTests { ... }
```

### 6. Common Symptoms and Fixes

#### "Unknown attribute 'Suite'" or "Unknown attribute 'Test'"

**Symptom:** Test files show these errors in Xcode

**Root causes:**
1. File is being compiled in Molten target (not just test target)
2. File path doesn't resolve correctly
3. Tests group is under Molten group

**Fix:**
```bash
# 1. Check which targets the file is in
ruby -e "
require 'xcodeproj'
project = Xcodeproj::Project.open('Molten.xcodeproj')
file = project.files.find { |f| f.path.to_s.include?('YourTest') }
project.targets.each do |t|
  in_target = t.source_build_phase.files.any? { |f| f.file_ref == file }
  puts \"#{t.name}: #{in_target}\" if in_target
end
"

# 2. If it's in Molten target, remove it:
# Use Xcode: Select file → File Inspector → Target Membership → Uncheck Molten

# 3. Check if Tests group is under Molten:
# Xcode project navigator: Tests group should be at same level as Molten, not nested under it

# 4. Clean build:
rm -rf ~/Library/Developer/Xcode/DerivedData/Molten-*
```

#### File path resolves to wrong location

**Symptom:**
```
Real path: /Users/you/project/Molten/Tests/Molten/Tests/MoltenTests/...
                                      ^^^^^^^^^^^^^^^^  # Duplicated!
```

**Root cause:** Group has absolute path instead of relative path

**Fix:**
```ruby
require 'xcodeproj'
project = Xcodeproj::Project.open('Molten.xcodeproj')

# Find the problematic group
tests_group = project.main_group.groups.find { |g| g.display_name == 'Tests' }

# Fix the path to be relative
tests_group.path = 'Molten/Tests'  # Relative to project root
tests_group.source_tree = '<group>'

project.save
```

#### "File is part of module 'Molten'; ignoring import"

**Symptom:** During build, warning that test file is being compiled as part of Molten

**Root cause:** Tests group is nested under Molten group

**Fix:**
```ruby
require 'xcodeproj'
project = Xcodeproj::Project.open('Molten.xcodeproj')

molten_group = project.main_group.groups.find { |g| g.display_name == 'Molten' }
tests_group = molten_group.groups.find { |g| g.display_name == 'Tests' }

# Move Tests from Molten to root
molten_group.children.delete(tests_group)
project.main_group.children << tests_group

project.save
```

### 7. Verification Checklist

After adding a test file, verify:

```bash
# 1. File exists in correct physical location
ls -la Molten/Tests/MoltenTests/Your/Path/YourTests.swift

# 2. File is in correct test target (not Molten)
ruby -e "
require 'xcodeproj'
project = Xcodeproj::Project.open('Molten.xcodeproj')
file = project.files.find { |f| f.path.to_s.include?('YourTests') }
puts \"File: #{file.path}\"
puts \"Real path: #{file.real_path}\"
puts \"Exists: #{File.exist?(file.real_path)}\"
project.targets.each do |t|
  in_target = t.source_build_phase.files.any? { |f| f.file_ref == file }
  puts \"In #{t.name}: #{in_target}\" if in_target
end
"

# Expected output:
# File: YourTests.swift
# Real path: /Users/you/project/Molten/Tests/MoltenTests/.../YourTests.swift
# Exists: true
# In MoltenTests: true  (or PerformanceTests, etc.)
# Should NOT show "In Molten: true"

# 3. Clean and rebuild
rm -rf ~/Library/Developer/Xcode/DerivedData/Molten-*
xcodebuild -project Molten.xcodeproj -scheme Molten -destination 'platform=iOS Simulator,name=iPhone 15' build
```

### 8. Quick Reference: File Creation Workflow

```bash
# 1. Create file in correct location
touch Molten/Tests/MoltenTests/Views/Shared/MyNewTests.swift

# 2. Write your test code (use existing test files as template)

# 3. Add to Xcode project with script
ruby add-file-to-project.rb Molten/Tests/MoltenTests/Views/Shared/MyNewTests.swift

# 4. Verify it worked
ruby -e "
require 'xcodeproj'
project = Xcodeproj::Project.open('Molten.xcodeproj')
file = project.files.find { |f| f.path.to_s.include?('MyNewTests') }
puts \"✅ In MoltenTests: #{project.targets.find { |t| t.name == 'MoltenTests' }.source_build_phase.files.any? { |f| f.file_ref == file }}\"
puts \"❌ In Molten: #{project.targets.find { |t| t.name == 'Molten' }.source_build_phase.files.any? { |f| f.file_ref == file }}\"
"

# 5. Commit BOTH the test file AND the project file
git add Molten/Tests/MoltenTests/Views/Shared/MyNewTests.swift
git add Molten.xcodeproj/project.pbxproj
git commit -m "test: add MyNewTests"
```

## Summary of Mistakes Made

1. ❌ Created test files in project root `Tests/` instead of `Molten/Tests/`
2. ❌ Used `add-test-to-xcode.rb` which created files at wrong hierarchy level
3. ❌ Set group paths to absolute paths instead of relative paths
4. ❌ Set file paths to full paths instead of just filenames
5. ❌ Left Tests group nested under Molten group
6. ❌ Tried to fix by wrapping entire file in `#if canImport(Testing)`

## What Actually Works

1. ✅ Create files in `Molten/Tests/[TargetName]/` on disk
2. ✅ Use `add-file-to-project.rb` script to add to Xcode
3. ✅ Groups use relative paths: `path = 'MoltenTests'`, `source_tree = '<group>'`
4. ✅ Files use just filename: `path = 'MyTests.swift'`, `source_tree = '<group>'`
5. ✅ Tests group at root level, not nested under Molten
6. ✅ Fix configuration issues, don't paper over them

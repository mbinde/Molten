================================================================================
DEAD CODE ANALYSIS - COMPREHENSIVE REPORT
Molten iOS App Codebase
November 2, 2025
================================================================================

START HERE: Quick Reference for Dead Code in Your Codebase

Three reports have been generated analyzing your codebase for unused code:

1. DEAD_CODE_INDEX.md ..................... START HERE (Quick reference guide)
2. DEAD_CODE_SUMMARY.md ................... Executive summary with priorities
3. DEAD_CODE_ANALYSIS.txt ................. Detailed analysis with line numbers

================================================================================
KEY FINDINGS AT A GLANCE
================================================================================

TOTAL DEAD CODE FOUND: 37 items totaling 2,600+ lines

BREAKDOWN BY RISK:
  - VERY HIGH confidence: 15 items (backup files, clearly unused)
  - HIGH confidence:       12 items (never called, deprecated)
  - MEDIUM confidence:     10 items (minimal usage)

BREAKDOWN BY CATEGORY:
  - Root directory backups:     975 lines (DELETE IMMEDIATELY - not in project)
  - Unused utilities:        1,200+ lines (never used)
  - Placeholder functions:      150+ lines (always return empty/nil)
  - Deprecated/legacy code:     100+ lines (marked @available deprecated)
  - Unused extensions:           50+ lines (barely or never used)

================================================================================
MOST CRITICAL ITEMS TO REMOVE (RIGHT NOW)
================================================================================

These 7 backup files in the root directory should be deleted immediately:
- CatalogFormatters 2.swift (22 lines)
- CatalogItemDetailView 2.swift (116 lines)
- CatalogView 2.swift (144 lines)
- CatalogItemRowView 2.swift (103 lines)
- MockItemMinimumRepository 2.swift (251 lines)
- CatalogBundleDebugView 2.swift (93 lines)
- GlassItemCardTests_ToAdd.swift (246 lines)

TOTAL: 975 lines - ZERO RISK (not in your Xcode project)

================================================================================
LARGEST UNUSED FILES
================================================================================

1. NetworkSimulationUtilities.swift ........ 684 lines (exploratory code)
2. JSON5Parser.swift ....................... 228 lines (never used)
3. AdvancedTestingUtilities.swift .......... 213 lines (not integrated)
4. MockItemMinimumRepository 2.swift ....... 251 lines (backup file)
5. CatalogView 2.swift ..................... 144 lines (backup file)

Total: 1,520 lines that can be safely deleted

================================================================================
QUICK START: WHAT TO DO NEXT
================================================================================

STEP 1: Read the Summary
  - Open: DEAD_CODE_SUMMARY.md
  - Time: 5 minutes
  - Action: Understand priorities and risks

STEP 2: Review Priority 1 Items
  - Open: DEAD_CODE_INDEX.md "Quick Facts" section
  - Time: 3 minutes
  - Action: Verify you want to delete these files

STEP 3: Delete Backup Files
  - Files: 7 files in /Users/binde/deadcode/ root directory
  - Risk: ZERO (not in Xcode project)
  - Time: 1 minute

STEP 4: Delete Unused Utilities (if desired)
  - Files: JSON5Parser.swift, NetworkSimulationUtilities.swift, etc.
  - Risk: LOW (0 production references)
  - Location: Molten/Sources/Utilities/
  - Time: 2 minutes

STEP 5: Clean Up Functions (if desired)
  - Remove placeholder functions from CatalogItemHelpers.swift
  - Remove deprecated stubs from ServiceValidation.swift
  - Remove legacy methods from CatalogCodeLookup.swift
  - Risk: LOW (deprecated or always return empty)
  - Time: 5-10 minutes

STEP 6: Test
  - Build the app
  - Run tests
  - Verify no regressions
  - Time: 10-15 minutes

TOTAL TIME: 25-45 minutes for Priority 1 & 2 cleanup

================================================================================
DETAILED ANALYSIS BY SECTION
================================================================================

For complete details on each finding, see DEAD_CODE_ANALYSIS.txt which includes:

SECTION 1: Root Directory Backup Files (Items 1-7)
  - 7 backup/duplicate files
  - 975 lines total
  - Confidence: VERY HIGH

SECTION 2: Unused Utility Functions (Items 8-16)
  - 9 unused utility files/methods
  - 1,200+ lines total
  - Confidence: HIGH
  - Includes: JSON5Parser, NetworkSimulationUtilities, etc.

SECTION 3: Unused Helper Functions (Items 17-32)
  - 16 placeholder/deprecated functions
  - 150+ lines total
  - Confidence: HIGH
  - In: CatalogItemHelpers, ServiceValidation, CatalogCodeLookup

SECTION 4: Unused View Components (Items 33-35)
  - 3 partially/unused views
  - 320+ lines
  - Confidence: MEDIUM

SECTION 5: Unused Array Extensions (Items 36-37)
  - 2 unused extension methods
  - 50+ lines
  - Confidence: MEDIUM

SECTION 6: Deprecated/Legacy Code Summary

================================================================================
FILES TO MODIFY OR DELETE
================================================================================

DELETE ENTIRELY (5 files):
  /Users/binde/deadcode/Molten/Sources/Utilities/JSON5Parser.swift
  /Users/binde/deadcode/Molten/Sources/Utilities/NetworkSimulationUtilities.swift
  /Users/binde/deadcode/Molten/Sources/Utilities/StringValidationUtilities.swift
  /Users/binde/deadcode/Molten/Sources/Utilities/AdvancedTestingUtilities.swift
  (Plus 7 root directory files)

EDIT TO REMOVE FUNCTIONS FROM (4 files):
  /Users/binde/deadcode/Molten/Sources/Models/Helpers/CatalogItemHelpers.swift
    - Remove: synonymsForItem(), coeForItem(), synonymsArrayForItem(),
              getCOEDisplayValue(), isFutureRelease(), AvailabilityStatus.futureRelease

  /Users/binde/deadcode/Molten/Sources/Models/Helpers/ServiceValidation.swift
    - Remove: validateCatalogItem(), validateInventoryItem()

  /Users/binde/deadcode/Molten/Sources/Models/Helpers/CatalogCodeLookup.swift
    - Remove: searchByExactCode(), searchByExactId(), searchByBaseCode(),
              searchByCodeSuffix(), searchByCodeContains(), preferredCatalogCode()

  /Users/binde/deadcode/Molten/Sources/Utilities/InventorySearchSuggestions.swift
    - Remove: suggestedCatalogItems()

================================================================================
VERIFICATION COMMANDS
================================================================================

Before deleting, verify there are no hidden references:

# Check JSON5Parser has no references
grep -r "JSON5Parser" Molten/Sources/
# Expected: 0 results

# Check NetworkSimulationUtilities has no references
grep -r "NetworkSimulationUtilities" Molten/Sources/
# Expected: 0 results

# Check StringValidationUtilities has no references
grep -r "StringValidationUtilities" Molten/Sources/
# Expected: 0 results

# Check AdvancedTestingUtilities has no references
grep -r "AdvancedTestingUtilities" Molten/Sources/
# Expected: 0 results

# Verify placeholder functions aren't used
grep -r "synonymsForItem\|coeForItem" Molten/Sources/
# Expected: Only in CatalogItemHelpers.swift definition

================================================================================
RECOMMENDATIONS FOR FUTURE CODE QUALITY
================================================================================

This analysis revealed some architectural patterns that could be improved:

1. CONSOLIDATE VALIDATION UTILITIES
   - Multiple validation files with similar purposes
   - ValidationUtilities.swift, StringValidationUtilities.swift
   - Recommendation: Merge into single validation module

2. STANDARDIZE ERROR HANDLING
   - Multiple error handling patterns in codebase
   - SimpleErrorHandling.swift vs other patterns
   - Recommendation: Choose one pattern, use consistently

3. AVOID EXPLORATORY CODE IN PRODUCTION
   - NetworkSimulationUtilities (exploratory network patterns)
   - AdvancedTestingUtilities (exploratory test utilities)
   - Recommendation: Use branches for exploratory work, clean before merge

4. CLEAN UP ON REGULAR BASIS
   - Dead code accumulates over time
   - Recommend: Monthly review of unused code
   - Consider: CI/CD tool to detect dead code automatically

================================================================================
RISK ASSESSMENT
================================================================================

PRIORITY 1: Delete Immediately (2,165 lines)
  Risk: ZERO
  Reason: Backup files not in project, unused utilities with 0 references

PRIORITY 2: Clean Up Functions (100 lines)
  Risk: VERY LOW
  Reason: Deprecated, placeholder, or legacy functions

PRIORITY 3: Evaluate & Potentially Remove (150 lines)
  Risk: LOW
  Reason: Minimal usage, may still be used post-launch

PRIORITY 4: Refactor (varies)
  Risk: MEDIUM
  Reason: Requires careful consolidation to avoid breaking changes

OVERALL: LOW RISK for Priorities 1-2, MEDIUM for Priority 3-4

================================================================================
NEXT STEPS
================================================================================

1. [ ] Read DEAD_CODE_SUMMARY.md (5 min)
2. [ ] Review DEAD_CODE_INDEX.md (3 min)
3. [ ] Delete 7 root directory backup files (1 min)
4. [ ] Delete 5 unused utility files (2 min)
5. [ ] Remove placeholder/deprecated functions (10 min)
6. [ ] Build and test app (15 min)
7. [ ] Commit changes with message:
       "refactor: remove 2,600+ lines of dead code
        
        - Removed 7 backup files from root directory
        - Removed 5 unused utility files (JSON5Parser, NetworkSimulationUtilities, etc.)
        - Removed placeholder functions from helpers
        - Removed deprecated/legacy methods
        
        This cleans up exploratory code that was never integrated into production."

8. [ ] Consider Priority 3-4 items in future sprints

================================================================================
QUESTIONS?
================================================================================

Each dead code item in the detailed analysis includes:
  - Line number(s)
  - Type (function, class, extension, etc.)
  - Confidence level (VERY HIGH, HIGH, MEDIUM)
  - Why it's considered dead code
  - What would break if removed (usually nothing)

See DEAD_CODE_ANALYSIS.txt for complete details on any item.

================================================================================
SUMMARY STATISTICS
================================================================================

Files Analyzed:       200+ Swift files
Time to Cleanup:      30-60 minutes (Priority 1-2)
Lines to Remove:      2,600+
Confidence Level:     70% HIGH/VERY HIGH, 30% MEDIUM
Risk Level:           LOW for Priority 1-2, MEDIUM for Priority 3-4
Build Impact:         None (exploratory code not in build)
Test Impact:          Minimal (mostly test utilities)
User Impact:          None (dead code not compiled)

Expected Benefits:
  - Improved code clarity
  - Reduced maintenance burden
  - Cleaner project structure
  - Better developer experience

================================================================================
END OF README

For detailed analysis, see:
- DEAD_CODE_INDEX.md (quick reference)
- DEAD_CODE_SUMMARY.md (executive summary)
- DEAD_CODE_ANALYSIS.txt (detailed line-by-line analysis)

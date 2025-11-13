# Dead Code Analysis - Index & Quick Reference

## Documents Generated

This analysis includes two comprehensive reports:

1. **DEAD_CODE_ANALYSIS.txt** - Complete detailed analysis with line numbers, confidence levels, and full reasoning for each item
2. **DEAD_CODE_SUMMARY.md** - Executive summary with priorities and cleanup recommendations
3. **DEAD_CODE_INDEX.md** - This file - quick reference guide

## Quick Facts

- **Total dead code items**: 37
- **Total lines of dead code**: 2,600+
- **Most dangerous files**: 7 backup files in root directory (975 lines)
- **Largest unused file**: NetworkSimulationUtilities.swift (684 lines)
- **Confidence**: 70% HIGH/VERY HIGH, 30% MEDIUM

## Dead Code Categories

### Category 1: Root Directory Backups (DELETE IMMEDIATELY)
```
/Users/binde/deadcode/CatalogFormatters 2.swift
/Users/binde/deadcode/CatalogItemDetailView 2.swift
/Users/binde/deadcode/CatalogView 2.swift
/Users/binde/deadcode/CatalogItemRowView 2.swift
/Users/binde/deadcode/MockItemMinimumRepository 2.swift
/Users/binde/deadcode/CatalogBundleDebugView 2.swift
/Users/binde/deadcode/GlassItemCardTests_ToAdd.swift
```
**Total**: 975 lines | **Risk**: ZERO (not in project)

### Category 2: Unused Utilities in Molten/Sources/Utilities/

| File | Lines | Issue |
|------|-------|-------|
| JSON5Parser.swift | 228 | No production references |
| NetworkSimulationUtilities.swift | 684 | Exploratory code never used |
| StringValidationUtilities.swift | 65 | Never adopted |
| AdvancedTestingUtilities.swift | 213 | Never integrated |
| String+Extensions.swift | 7 | truncatedSKU() barely used |

### Category 3: Placeholder Functions in Models/Helpers/
- CatalogItemHelpers.swift: 6 functions that return empty/nil
- ServiceValidation.swift: 3 deprecated functions
- CatalogCodeLookup.swift: 6 legacy search methods
- InventorySearchSuggestions.swift: 1 deprecated stub

### Category 4: Unused Extensions
- Array+Extensions.swift: `chunked()`, `isNotEmpty`
- String+Extensions.swift: `truncatedSKU()`

## How to Use These Reports

### For Quick Cleanup
1. Read DEAD_CODE_SUMMARY.md
2. Focus on Priority 1 items (2,165 lines, safe to delete)
3. Delete files listed under "Files to Delete Entirely"

### For Detailed Review
1. Read specific sections in DEAD_CODE_ANALYSIS.txt
2. Each item has line number, type, confidence, and reasoning
3. Use grep to verify no usage before deletion

### For Code Inspection
```bash
# Find all dead code references
grep -r "JSON5Parser" Molten/Sources/  # Should return 0
grep -r "NetworkSimulationUtilities" Molten/Sources/  # Should return 0

# Verify confidence
grep -n "synonymsForItem\|coeForItem" Molten/Sources/Models/Helpers/CatalogItemHelpers.swift
```

## By the Numbers

```
Priority 1 (Delete immediately):        2,165 lines
  - Backup files:                         975 lines
  - Unused utilities:                   1,190 lines

Priority 2 (Clean up):                    ~100 lines
  - Placeholder functions:                ~80 lines
  - Deprecated stubs:                     ~20 lines

Priority 3 (Evaluate):                    ~150 lines
  - LocationFilterPreferences:             37 lines
  - AlphaDisclaimerView:                  122 lines

Priority 4 (Refactor):                   VARIES
  - Validation utilities consolidation
  - Error handling pattern merge
  - Search utility consolidation

TOTAL IDENTIFIED:                      2,600+ lines
```

## Confidence Levels

| Level | Count | Files |
|-------|-------|-------|
| VERY HIGH | 15 | Backup files, clearly unused |
| HIGH | 12 | Never called, deprecated |
| MEDIUM | 10 | Minimal usage, could be removed |
| **TOTAL** | **37** | - |

## Risk Assessment

### Safe to Delete (0 Risk)
- All backup files in root (not in project)
- JSON5Parser.swift (0 usages)
- NetworkSimulationUtilities.swift (0 usages)
- StringValidationUtilities.swift (0 usages)
- AdvancedTestingUtilities.swift (0 usages)

### Safe to Remove Functions (Low Risk)
- All placeholder functions (always return empty/nil/false)
- All deprecated functions (marked @available(*, deprecated))
- All legacy helper methods (only call other methods)

### Medium Risk (Verify First)
- truncatedSKU() - used 2 times, could be inlined
- chunked() - only in tests
- isNotEmpty - simple wrapper

## Cleanup Checklist

- [ ] Read DEAD_CODE_SUMMARY.md
- [ ] Review DEAD_CODE_ANALYSIS.txt for Priority 1 items
- [ ] Delete 7 backup files from root directory
- [ ] Remove JSON5Parser.swift from Molten/Sources/Utilities/
- [ ] Remove NetworkSimulationUtilities.swift from Molten/Sources/Utilities/
- [ ] Remove StringValidationUtilities.swift from Molten/Sources/Utilities/
- [ ] Remove AdvancedTestingUtilities.swift from Molten/Sources/Utilities/
- [ ] Remove placeholder methods from CatalogItemHelpers.swift
- [ ] Remove deprecated methods from ServiceValidation.swift
- [ ] Remove legacy methods from CatalogCodeLookup.swift
- [ ] Remove deprecated stub from InventorySearchSuggestions.swift
- [ ] Build and test app
- [ ] Review Priority 3-4 items for future refactoring

## Related Issues

This analysis revealed several code quality patterns:
1. **Multiple validation files** - Consolidate ValidationUtilities.swift, StringValidationUtilities.swift
2. **Multiple error handling patterns** - SimpleErrorHandling vs other error patterns
3. **Possibly duplicate search utilities** - SearchTextParser vs SearchUtilities overlap
4. **Exploratory code left in codebase** - NetworkSimulationUtilities, AdvancedTestingUtilities

Consider creating follow-up issues for architectural cleanup.

---

**Analysis Date**: November 2, 2025
**Confidence**: 70% HIGH/VERY HIGH confidence
**Estimated Safe Cleanup Time**: 2-3 hours
**Risk Level**: LOW (for Priority 1 items)

See detailed analysis in DEAD_CODE_ANALYSIS.txt

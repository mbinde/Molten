#!/bin/bash
#
# plan-di-migration.sh
# Generates a migration plan for all files using RepositoryFactory
#
# Usage: ./Scripts/plan-di-migration.sh [directory]
#

SEARCH_DIR="${1:-Molten/Sources/Views}"

echo "=============================================="
echo "DI Migration Planner"
echo "=============================================="
echo "Scanning: $SEARCH_DIR"
echo ""

# Find all Swift files with RepositoryFactory usage
FILES=$(grep -rl "RepositoryFactory\.create" "$SEARCH_DIR" --include="*.swift" | sort)

if [[ -z "$FILES" ]]; then
    echo "✅ No files found with RepositoryFactory usage!"
    exit 0
fi

FILE_COUNT=$(echo "$FILES" | wc -l | tr -d ' ')
TOTAL_USAGES=$(grep -r "RepositoryFactory\.create" "$SEARCH_DIR" --include="*.swift" | wc -l | tr -d ' ')

echo "📊 Found $FILE_COUNT files with $TOTAL_USAGES total usages"
echo ""
echo "=============================================="
echo "Migration Plan by Batch"
echo "=============================================="
echo ""

# Categorize files by directory
echo "📁 Batch 1: Main Navigation Views"
echo "$FILES" | grep -E "(MainTabView|CatalogView|InventoryView|ShoppingListView|PurchasesView|ProjectLogView|SettingsView)\.swift" | while read -r file; do
    count=$(grep -c "RepositoryFactory\.create" "$file")
    echo "  - $(basename "$file") ($count usages)"
done
echo ""

echo "📁 Batch 2: Catalog Feature Views"
echo "$FILES" | grep "Views/Catalog" | grep -v "MainTabView\|CatalogView" | while read -r file; do
    count=$(grep -c "RepositoryFactory\.create" "$file")
    echo "  - $(basename "$file") ($count usages)"
done
echo ""

echo "📁 Batch 3: Inventory Feature Views"
echo "$FILES" | grep "Views/Inventory" | while read -r file; do
    count=$(grep -c "RepositoryFactory\.create" "$file")
    echo "  - $(basename "$file") ($count usages)"
done
echo ""

echo "📁 Batch 4: Shopping Feature Views"
echo "$FILES" | grep "Views/Shopping" | while read -r file; do
    count=$(grep -c "RepositoryFactory\.create" "$file")
    echo "  - $(basename "$file") ($count usages)"
done
echo ""

echo "📁 Batch 5: Project/Logbook Views"
echo "$FILES" | grep "Views/ProjectLog" | while read -r file; do
    count=$(grep -c "RepositoryFactory\.create" "$file")
    echo "  - $(basename "$file") ($count usages)"
done
echo ""

echo "📁 Batch 6: Other Views"
echo "$FILES" | grep -vE "(Catalog|Inventory|Shopping|ProjectLog|Purchases|Settings)" | while read -r file; do
    count=$(grep -c "RepositoryFactory\.create" "$file")
    echo "  - $(basename "$file") ($count usages)"
done
echo ""

echo "=============================================="
echo "Most Used Services"
echo "=============================================="
grep -roh "RepositoryFactory\.create\w*" "$SEARCH_DIR" --include="*.swift" | sort | uniq -c | sort -rn | head -10
echo ""

echo "=============================================="
echo "Suggested Migration Order"
echo "=============================================="
echo ""
echo "1. Run dry-run on a file to see changes:"
echo "   ./Scripts/migrate-to-di.sh --dry-run Molten/Sources/Views/Catalog/CatalogView.swift"
echo ""
echo "2. Apply migration to a file:"
echo "   ./Scripts/migrate-to-di.sh Molten/Sources/Views/Catalog/CatalogView.swift"
echo ""
echo "3. Review and fix:"
echo "   - Add @Environment(\.appDependencies) if needed"
echo "   - Update parent views to pass services"
echo "   - Update Previews"
echo ""
echo "4. Build and test:"
echo "   xcodebuild build"
echo ""
echo "5. Commit batch:"
echo "   git add ."
echo "   git commit -m 'refactor(di): migrate [BatchName] views'"
echo ""

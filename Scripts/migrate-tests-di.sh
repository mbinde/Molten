#!/bin/bash
#
# migrate-tests-di.sh
# Automated migration of test files from RepositoryFactory to AppDependencies
#
# Usage: ./Scripts/migrate-tests-di.sh

set -e

echo "=============================================="
echo "Test DI Migration - Automated"
echo "=============================================="
echo ""

# Find all test files using RepositoryFactory
TEST_FILES=$(grep -rl "RepositoryFactory" Molten/Tests --include="*.swift" | sort)

if [[ -z "$TEST_FILES" ]]; then
    echo "✅ No test files found with RepositoryFactory usage!"
    exit 0
fi

FILE_COUNT=$(echo "$TEST_FILES" | wc -l | tr -d ' ')
echo "📊 Found $FILE_COUNT test files to migrate"
echo ""

# Process each file
for file in $TEST_FILES; do
    echo "Processing: $(basename "$file")"

    # Pattern 1: Replace RepositoryFactory.configureForTesting() with deps creation
    # This is tricky because we need to handle different patterns

    # Pattern 2: Replace RepositoryFactory.create* calls
    perl -i -pe 's/RepositoryFactory\.createCatalogService\(\)/deps.catalogService/g' "$file"
    perl -i -pe 's/RepositoryFactory\.createInventoryTrackingService\(\)/deps.inventoryTrackingService/g' "$file"
    perl -i -pe 's/RepositoryFactory\.createShoppingListService\(\)/deps.shoppingListService/g' "$file"
    perl -i -pe 's/RepositoryFactory\.createPurchaseRecordService\(\)/deps.purchaseRecordService/g' "$file"
    perl -i -pe 's/RepositoryFactory\.createProjectService\(\)/deps.projectService/g' "$file"
    perl -i -pe 's/RepositoryFactory\.createKilnScheduleService\(\)/deps.kilnScheduleService/g' "$file"
    perl -i -pe 's/RepositoryFactory\.createRecipeService\(\)/deps.recipeService/g' "$file"
    perl -i -pe 's/RepositoryFactory\.createUnifiedLocationService\(\)/deps.unifiedLocationService/g' "$file"
    perl -i -pe 's/RepositoryFactory\.createEntitlementService\(\)/deps.entitlementService/g' "$file"
    perl -i -pe 's/RepositoryFactory\.createGlassItemRepository\(\)/deps.glassItemRepository/g' "$file"
    perl -i -pe 's/RepositoryFactory\.createInventoryRepository\(\)/deps.inventoryRepository/g' "$file"
    perl -i -pe 's/RepositoryFactory\.createLocationRepository\(\)/deps.locationRepository/g' "$file"
    perl -i -pe 's/RepositoryFactory\.createUserImageRepository\(\)/deps.userImageRepository/g' "$file"
    perl -i -pe 's/RepositoryFactory\.createProjectRepository\(\)/deps.projectRepository/g' "$file"
    perl -i -pe 's/RepositoryFactory\.createLogbookRepository\(\)/deps.logbookRepository/g' "$file"
    perl -i -pe 's/RepositoryFactory\.createPurchaseRecordRepository\(\)/deps.purchaseRecordRepository/g' "$file"
    perl -i -pe 's/RepositoryFactory\.createItemTagsRepository\(\)/deps.itemTagsRepository/g' "$file"
    perl -i -pe 's/RepositoryFactory\.createUserTagsRepository\(\)/deps.userTagsRepository/g' "$file"
    perl -i -pe 's/RepositoryFactory\.createShoppingListRepository\(\)/deps.shoppingListRepository/g' "$file"
    perl -i -pe 's/RepositoryFactory\.createUserNotesRepository\(\)/deps.userNotesRepository/g' "$file"
    perl -i -pe 's/RepositoryFactory\.createBackgroundUpdateService\(\)/deps.backgroundUpdateService/g' "$file"
    perl -i -pe 's/RepositoryFactory\.createSubscriptionService\(\)/deps.subscriptionService/g' "$file"

    # Pattern 3: Replace RepositoryFactory.configureForTesting() with deps creation
    # Need to add "let deps = AppDependencies(forTesting: true)" before first usage
    if grep -q "RepositoryFactory\.configureForTesting" "$file"; then
        # This is complex - we'll need to add the deps line and remove configureForTesting
        # For now, just remove the line and add a comment
        perl -i -pe 's/.*RepositoryFactory\.configureForTesting\(\).*$/        let deps = AppDependencies(forTesting: true)/g' "$file"
    fi

    # If file now has deps.* but no "let deps", add it at the start of each test function
    if grep -q "deps\." "$file" && ! grep -q "let deps = AppDependencies" "$file"; then
        echo "  ⚠️  File has deps.* references but no deps variable - manual fix needed"
    fi
done

echo ""
echo "=============================================="
echo "Migration Complete"
echo "=============================================="
echo ""
echo "⚠️  IMPORTANT: This is an automated migration that may need manual fixes:"
echo "  1. Some test functions may need 'let deps = AppDependencies(forTesting: true)' added"
echo "  2. Some configureForTesting() calls may not have been replaced correctly"
echo "  3. Build the project to find any remaining issues"
echo ""
echo "Next steps:"
echo "  1. Build tests: xcodebuild test -project Molten.xcodeproj -scheme Molten"
echo "  2. Fix any compilation errors"
echo "  3. Commit changes: git add Molten/Tests && git commit -m 'test(di): migrate tests to AppDependencies'"

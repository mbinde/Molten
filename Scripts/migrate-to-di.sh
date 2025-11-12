#!/bin/bash
#
# migrate-to-di.sh
# Automated migration from RepositoryFactory to AppDependencies
#
# Usage: ./Scripts/migrate-to-di.sh [--dry-run] <file>
#

set -e

DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    shift
fi

FILE="$1"

if [[ -z "$FILE" || ! -f "$FILE" ]]; then
    echo "Usage: $0 [--dry-run] <swift-file>"
    exit 1
fi

echo "==================================================================="
echo "DI Migration Tool - Converting RepositoryFactory to AppDependencies"
echo "==================================================================="
echo "File: $FILE"
echo "Mode: $([ "$DRY_RUN" = true ] && echo "DRY RUN (no changes)" || echo "APPLY CHANGES")"
echo ""

# Mapping of RepositoryFactory methods to AppDependencies properties
declare -A SERVICE_MAP=(
    ["createCatalogService"]="catalogService"
    ["createInventoryTrackingService"]="inventoryTrackingService"
    ["createShoppingListService"]="shoppingListService"
    ["createPurchaseRecordService"]="purchaseRecordService"
    ["createProjectService"]="projectService"
    ["createKilnScheduleService"]="kilnScheduleService"
    ["createRecipeService"]="recipeService"
    ["createUnifiedLocationService"]="unifiedLocationService"
    ["createEntitlementService"]="entitlementService"
    ["createGlassItemRepository"]="glassItemRepository"
    ["createInventoryRepository"]="inventoryRepository"
    ["createLocationRepository"]="locationRepository"
    ["createUserImageRepository"]="userImageRepository"
    ["createProjectRepository"]="projectRepository"
    ["createLogbookRepository"]="logbookRepository"
    ["createPurchaseRecordRepository"]="purchaseRecordRepository"
)

# Count RepositoryFactory usages
USAGE_COUNT=$(grep -c "RepositoryFactory\." "$FILE" || true)
echo "Found $USAGE_COUNT RepositoryFactory usage(s)"
echo ""

if [[ $USAGE_COUNT -eq 0 ]]; then
    echo "✅ No RepositoryFactory usages found - file already migrated or doesn't use it"
    exit 0
fi

# Show what we found
echo "📋 RepositoryFactory usages:"
grep -n "RepositoryFactory\." "$FILE" | head -20
echo ""

# Backup original file
BACKUP="${FILE}.backup.$(date +%s)"
if [[ "$DRY_RUN" = false ]]; then
    cp "$FILE" "$BACKUP"
    echo "💾 Backup created: $BACKUP"
    echo ""
fi

# Pattern 1: Default parameter with RepositoryFactory
# Example: init(service: MyService = RepositoryFactory.createMyService())
# Transform: Remove the default value
echo "🔍 Pattern 1: Default parameters with RepositoryFactory..."
DEFAULT_PARAMS=$(grep -n "= RepositoryFactory\.create" "$FILE" | wc -l)
if [[ $DEFAULT_PARAMS -gt 0 ]]; then
    echo "   Found $DEFAULT_PARAMS default parameter(s) to remove"

    if [[ "$DRY_RUN" = false ]]; then
        # Remove default parameters - this is a simplified version
        # Manual review required for complex cases
        perl -i -pe 's/(\w+:\s+\w+)\s*=\s*RepositoryFactory\.\w+\(\)/$1/g' "$FILE"
    fi
else
    echo "   None found"
fi

# Pattern 2: Direct RepositoryFactory calls in view body
# Example: let service = RepositoryFactory.createMyService()
# Transform: dependencies.myService
echo ""
echo "🔍 Pattern 2: Direct RepositoryFactory calls..."
DIRECT_CALLS=$(grep -n "RepositoryFactory\.create\w*(" "$FILE" | grep -v "init(" | wc -l)
if [[ $DIRECT_CALLS -gt 0 ]]; then
    echo "   Found $DIRECT_CALLS direct call(s)"
    echo "   ⚠️  These need manual review - replacing with dependencies.service"
    echo ""
    echo "   Suggested replacements:"

    for factory_method in "${!SERVICE_MAP[@]}"; do
        if grep -q "RepositoryFactory\.$factory_method" "$FILE"; then
            property="${SERVICE_MAP[$factory_method]}"
            echo "   - RepositoryFactory.$factory_method() → dependencies.$property"

            if [[ "$DRY_RUN" = false ]]; then
                # Replace direct calls (simple cases only)
                perl -i -pe "s/RepositoryFactory\.$factory_method\(\)/dependencies.$property/g" "$FILE"
            fi
        fi
    done
else
    echo "   None found"
fi

# Pattern 3: Check if @Environment(\.appDependencies) is needed
echo ""
echo "🔍 Pattern 3: Checking for @Environment(\.appDependencies)..."
if grep -q "@Environment(\\\\.appDependencies)" "$FILE"; then
    echo "   ✅ Already has @Environment(\.appDependencies)"
elif grep -q "dependencies\." "$FILE"; then
    echo "   ⚠️  Uses 'dependencies' but missing @Environment declaration"
    echo "   Add: @Environment(\\.appDependencies) private var dependencies"
else
    echo "   Not needed (no dependencies references)"
fi

# Pattern 4: Preview updates
echo ""
echo "🔍 Pattern 4: Checking Preview..."
if grep -q "#Preview" "$FILE"; then
    if grep -q "RepositoryFactory" "$FILE" && grep -q "#Preview" "$FILE"; then
        echo "   ⚠️  Preview may need updating to use AppDependencies(forTesting: true)"
        echo "   Current preview block:"
        sed -n '/#Preview/,/^}/p' "$FILE" | head -10
    else
        echo "   ✅ Preview looks clean or already migrated"
    fi
else
    echo "   No Preview found"
fi

# Summary
echo ""
echo "==================================================================="
echo "Migration Summary"
echo "==================================================================="

REMAINING=$(grep -c "RepositoryFactory\." "$FILE" || true)
if [[ "$DRY_RUN" = false ]]; then
    echo "✅ Changes applied to: $FILE"
    echo "📊 Remaining RepositoryFactory usages: $REMAINING"

    if [[ $REMAINING -gt 0 ]]; then
        echo ""
        echo "⚠️  Manual review needed for remaining usages:"
        grep -n "RepositoryFactory\." "$FILE"
    else
        echo "🎉 All RepositoryFactory usages removed!"
    fi

    echo ""
    echo "Next steps:"
    echo "1. Review changes: git diff $FILE"
    echo "2. Add @Environment(\.appDependencies) if needed"
    echo "3. Update parent view call sites to pass services"
    echo "4. Build and test: xcodebuild build"
    echo "5. If errors, restore backup: mv $BACKUP $FILE"
else
    echo "DRY RUN - No changes made"
    echo ""
    echo "To apply changes, run without --dry-run:"
    echo "  ./Scripts/migrate-to-di.sh $FILE"
fi

echo "==================================================================="

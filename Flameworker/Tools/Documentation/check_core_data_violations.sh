#!/bin/bash

# check_core_data_violations.sh
# Script to verify FlameworkerTests contains no Core Data usage
# Run this before committing new test files

echo "🔍 Checking FlameworkerTests for Core Data violations..."
echo ""

# Check for Core Data imports
echo "Checking for 'import CoreData'..."
if grep -r "import CoreData" FlameworkerTests/; then
    echo "❌ VIOLATION: Found 'import CoreData' in FlameworkerTests!"
    echo "   Remove Core Data imports from FlameworkerTests"
    echo ""
    exit 1
else
    echo "✅ No 'import CoreData' found"
fi

# Check for PersistenceController usage
echo "Checking for PersistenceController usage..."
if grep -r "PersistenceController" FlameworkerTests/; then
    echo "❌ VIOLATION: Found PersistenceController usage in FlameworkerTests!"
    echo "   Use TestConfiguration.setupMockOnlyTestEnvironment() instead"
    echo ""
    exit 1
else
    echo "✅ No PersistenceController usage found"
fi

# Check for NSManagedObjectContext
echo "Checking for NSManagedObjectContext usage..."
if grep -r "NSManagedObjectContext" FlameworkerTests/; then
    echo "❌ VIOLATION: Found NSManagedObjectContext usage in FlameworkerTests!"
    echo "   Use mock repositories instead of Core Data contexts"
    echo ""
    exit 1
else
    echo "✅ No NSManagedObjectContext usage found"
fi

# Check for .save() operations (common Core Data pattern)
echo "Checking for Core Data .save() operations..."
if grep -r "\.save()" FlameworkerTests/; then
    echo "❌ VIOLATION: Found .save() operations in FlameworkerTests!"
    echo "   Mock repositories don't require .save() operations"
    echo ""
    exit 1
else
    echo "✅ No .save() operations found"
fi

# Check for viewContext usage
echo "Checking for viewContext usage..."
if grep -r "viewContext\|backgroundContext" FlameworkerTests/; then
    echo "❌ VIOLATION: Found Core Data context usage in FlameworkerTests!"
    echo "   Use mock repositories instead of Core Data contexts"
    echo ""
    exit 1
else
    echo "✅ No Core Data context usage found"
fi

# Check that new files use the proper patterns
echo "Checking for proper MockOnlyTestSuite usage..."
test_files=$(find FlameworkerTests/ -name "*Tests.swift" ! -name "NewTestTemplate.swift")
missing_mock_only=()

for file in $test_files; do
    if ! grep -q "MockOnlyTestSuite\|ensureMockOnlyEnvironment\|TestConfiguration\.setup" "$file"; then
        missing_mock_only+=("$file")
    fi
done

if [ ${#missing_mock_only[@]} -ne 0 ]; then
    echo "⚠️  WARNING: These test files don't use MockOnlyTestSuite pattern:"
    for file in "${missing_mock_only[@]}"; do
        echo "   - $file"
    done
    echo "   Consider updating them to use the MockOnlyTestSuite protocol"
    echo "   See NewTestTemplate.swift for the correct pattern"
    echo ""
fi

# Success
echo ""
echo "🎉 SUCCESS: FlameworkerTests appears to be Core Data free!"
echo ""
echo "📋 SUMMARY:"
echo "✅ No Core Data imports"
echo "✅ No PersistenceController usage"
echo "✅ No NSManagedObjectContext usage"
echo "✅ No .save() operations"
echo "✅ No Core Data context usage"
echo ""
echo "To run this check automatically:"
echo "chmod +x check_core_data_violations.sh"
echo "./check_core_data_violations.sh"
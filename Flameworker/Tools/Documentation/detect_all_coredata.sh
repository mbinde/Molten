#!/bin/bash

echo "🔍 Comprehensive Core Data Detection in FlameworkerTests..."
echo ""

# Search for any Core Data related imports
echo "=== SEARCHING FOR CORE DATA IMPORTS ==="
find FlameworkerTests/ -name "*.swift" -exec grep -l "import CoreData\|import Core Data" {} \;

echo ""
echo "=== SEARCHING FOR CORE DATA CLASSES ==="
find FlameworkerTests/ -name "*.swift" -exec grep -l "NSManagedObject\|NSPersistentContainer\|PersistenceController" {} \;

echo ""
echo "=== SEARCHING FOR CORE DATA OPERATIONS ==="
find FlameworkerTests/ -name "*.swift" -exec grep -l "\.save()\|viewContext\|backgroundContext" {} \;

echo ""
echo "=== LISTING ALL TEST FILES ==="
find FlameworkerTests/ -name "*.swift" | sort

echo ""
echo "=== CHECKING FOR REPOSITORY FACTORY USAGE ==="
find FlameworkerTests/ -name "*.swift" -exec grep -l "RepositoryFactory\." {} \;

echo ""
echo "✅ Detection complete!"
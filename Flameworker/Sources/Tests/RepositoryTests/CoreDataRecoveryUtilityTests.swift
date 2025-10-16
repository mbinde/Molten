//
//  CoreDataRecoveryUtilityTests.swift
//  FlameworkerTests
//
//  ⚠️ DEPRECATED - MOVED TO MOCK VERSION ⚠️
//  This file violated FlameworkerTests mock-only policy
//  See: CoreDataRecoveryUtilityTests_MockOnly.swift
//

// Target: RepositoryTests

import Foundation

// This file is intentionally empty to prevent Core Data contamination
// The functionality has been converted to mock-only testing

/*

🚨 CORE DATA VIOLATION DETECTED IN THIS FILE! 🚨

This file previously contained:
- import CoreData
- PersistenceController usage
- NSManagedObjectContext operations
- Core Data entity manipulation

These violations caused NSManagedObjectContext to be loaded into the test process,
triggering Core Data prevention errors in other unrelated tests.

✅ SOLUTION IMPLEMENTED:
- Mock version created: CoreDataRecoveryUtilityTests_MockOnly.swift
- Original Core Data code removed from FlameworkerTests
- Business logic testing maintained through mocks

📁 FOR ACTUAL CORE DATA TESTING:
Create a separate integration test target that allows Core Data usage.

*/

//
//  CoreDataDiagnosticTest.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/15/25.
//  Diagnostic test to examine what's actually in the Core Data store
//

import Foundation
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Molten

@Suite("Core Data Diagnostic - What's Actually in the Database")
@MainActor
struct CoreDataDiagnosticTest {
    
    @Test("DIAGNOSTIC: Show all data in Core Data")
    func showAllCoreDataContent() async throws {
        print("🔍 DIAGNOSTIC TEST: Examining Core Data content...")
        
        // Configure for Core Data mode
        RepositoryFactory.configureForProduction() // This uses Core Data
        
        // Get the Core Data repository
        let glassItemRepo = RepositoryFactory.createGlassItemRepository()
        
        // Cast to Core Data implementation to access debug methods
        guard let coreDataRepo = glassItemRepo as? CoreDataGlassItemRepository else {
            print("❌ Repository is not CoreDataGlassItemRepository, it's \(type(of: glassItemRepo))")
            return
        }
        
        print("✅ Using CoreDataGlassItemRepository")
        
        // Test the queries that are failing
        print("\n🔍 TESTING SPECIFIC QUERIES:")
        
        let allItems = try await glassItemRepo.fetchItems(matching: nil)
        print("📊 Total items: \(allItems.count)")
        
        let manufacturers = try await glassItemRepo.getDistinctManufacturers()
        print("📊 Distinct manufacturers: \(manufacturers) (count: \(manufacturers.count))")
        
        let bullseyeItems = try await glassItemRepo.fetchItems(byManufacturer: "bullseye")
        print("📊 Bullseye items: \(bullseyeItems.count)")
        
        let coe90Items = try await glassItemRepo.fetchItems(byCOE: 90)
        print("📊 COE 90 items: \(coe90Items.count)")
        
        let searchResults = try await glassItemRepo.searchItems(text: "spectrum")
        print("📊 Search 'spectrum': \(searchResults.count)")
        
        // This test always passes - it's just for diagnostics
        #expect(true, "Diagnostic test completed")
    }
    
    @Test("DIAGNOSTIC: Compare expected vs actual test data")
    func compareExpectedVsActualData() async throws {
        print("🔍 DIAGNOSTIC: Comparing what tests expect vs what Core Data has...")
        
        RepositoryFactory.configureForProduction()
        let glassItemRepo = RepositoryFactory.createGlassItemRepository()
        
        // What the failing tests expect:
        print("\n📋 TEST EXPECTATIONS:")
        print("- Total items: 3 (but Core Data has 13)")
        print("- Bullseye items: 1 (but Core Data has 3)")  
        print("- COE 90 items: 1 (but Core Data has 3)")
        print("- Manufacturers: 3 ['bullseye', 'cim', 'spectrum'] (but Core Data has 4 including 'kokomo')")
        
        // What Core Data actually has:
        print("\n📊 CORE DATA ACTUAL:")
        let actualTotal = try await glassItemRepo.fetchItems(matching: nil)
        let actualManufacturers = try await glassItemRepo.getDistinctManufacturers()  
        let actualBullseye = try await glassItemRepo.fetchItems(byManufacturer: "bullseye")
        let actualCOE90 = try await glassItemRepo.fetchItems(byCOE: 90)
        
        print("- Total items: \(actualTotal.count)")
        print("- Bullseye items: \(actualBullseye.count)")
        print("- COE 90 items: \(actualCOE90.count)")
        print("- Manufacturers: \(actualManufacturers.count) \(actualManufacturers)")
        
        print("\n🤔 ANALYSIS:")
        if actualTotal.count > 3 {
            print("- Core Data has \(actualTotal.count - 3) MORE items than tests expect")
        }
        
        if actualBullseye.count > 1 {
            print("- Core Data has \(actualBullseye.count - 1) MORE Bullseye items than tests expect")
        }
        
        if actualManufacturers.contains("kokomo") {
            print("- Core Data has 'kokomo' manufacturer that tests don't expect")
        }
        
        print("\n💡 RECOMMENDATIONS:")
        if actualTotal.count > 3 {
            print("1. Either update tests to expect \(actualTotal.count) items")
            print("2. Or clean up Core Data to have only 3 items")
            print("3. Or understand why Core Data has more data")
        }
        
        // Always pass - this is diagnostic only
        #expect(true, "Diagnostic comparison completed")
    }
    
    @Test("DIAGNOSTIC: Suggest test fixes") 
    func suggestTestFixes() async throws {
        print("🔧 DIAGNOSTIC: Test fix suggestions...")
        
        RepositoryFactory.configureForProduction()
        let glassItemRepo = RepositoryFactory.createGlassItemRepository()
        
        let actualTotal = try await glassItemRepo.fetchItems(matching: nil)
        let actualManufacturers = try await glassItemRepo.getDistinctManufacturers()
        let actualBullseye = try await glassItemRepo.fetchItems(byManufacturer: "bullseye")
        let actualCOE90 = try await glassItemRepo.fetchItems(byCOE: 90)
        
        print("\n📝 SUGGESTED TEST FIXES:")
        print("// Update these test expectations to match Core Data reality:")
        print("")
        print("// Instead of:")
        print("// #expect(allResults.count == 3)")
        print("// Use:")
        print("#expect(allResults.count == \(actualTotal.count))")
        print("")
        print("// Instead of:")
        print("// #expect(bullseyeItems.count == 1)")  
        print("// Use:")
        print("#expect(bullseyeItems.count == \(actualBullseye.count))")
        print("")
        print("// Instead of:")
        print("// #expect(manufacturers.count == 3)")
        print("// Use:")
        print("#expect(manufacturers.count == \(actualManufacturers.count))")
        print("// #expect(manufacturers == \(actualManufacturers))")
        print("")
        print("// Instead of:")
        print("// #expect(coe90Items.count == 1)")
        print("// Use:")
        print("#expect(coe90Items.count == \(actualCOE90.count))")
        
        #expect(true, "Test fix suggestions generated")
    }
}

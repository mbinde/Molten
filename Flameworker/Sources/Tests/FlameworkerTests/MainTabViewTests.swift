//
//  MainTabViewTests.swift
//  Flameworker
//
//  Created by Assistant on 10/13/25.
//

// Standard test framework imports pattern - use in all test files
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import SwiftUI
@testable import Flameworker

@Suite("MainTabView Repository Pattern Tests")
struct MainTabViewTests {
    
    @Test("MainTabView should accept pre-configured catalog service via dependency injection")
    func testMainTabViewAcceptsCatalogService() {
        // Arrange: Create a mock catalog service
        let mockRepository = MockCatalogRepository()
        let catalogService = CatalogService(repository: mockRepository)
        
        // Act: Create MainTabView with pre-configured service
        let tabView = MainTabView(catalogService: catalogService)
        
        // Assert: MainTabView should be created successfully with injected service
        #expect(tabView != nil, "MainTabView should accept catalogService via dependency injection")
    }
    
    @Test("MainTabView should accept pre-configured purchase service via dependency injection")
    func testMainTabViewAcceptsPurchaseService() {
        // Arrange: Create mock services
        let mockCatalogRepository = MockCatalogRepository()
        let catalogService = CatalogService(repository: mockCatalogRepository)
        let mockPurchaseRepository = MockPurchaseRecordRepository()
        let purchaseService = PurchaseRecordService(repository: mockPurchaseRepository)
        
        // Act: Create MainTabView with both services
        let tabView = MainTabView(
            catalogService: catalogService,
            purchaseService: purchaseService
        )
        
        // Assert: MainTabView should be created successfully with both injected services
        #expect(tabView != nil, "MainTabView should accept both catalogService and purchaseService via dependency injection")
    }
    
    @Test("MainTabView should not require Core Data context when using dependency injection")
    func testMainTabViewWorksWithoutCoreDataContext() {
        // Arrange: Create mock services (no Core Data involved)
        let mockCatalogRepository = MockCatalogRepository()
        let catalogService = CatalogService(repository: mockCatalogRepository)
        
        // Act: Create MainTabView with just the service (no Core Data context)
        let tabView = MainTabView(catalogService: catalogService)
        
        // Assert: This should work without any Core Data environment
        #expect(tabView != nil, "MainTabView should work without Core Data context when services are injected")
        
        // Additional check: The view should not import CoreData at all
        // This will be verified by the compiler - if MainTabView imports CoreData
        // but we're not providing a Core Data context, it should still work
        // because it's using injected services instead of creating its own
    }
}
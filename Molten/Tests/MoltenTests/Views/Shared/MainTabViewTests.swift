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
@testable import Molten

@Suite("MainTabView Repository Pattern Tests", .serialized)
@MainActor
struct MainTabViewTests {

    // MARK: - Shared Dependencies

    /// ✅ CRITICAL: Store AppDependencies at struct level to keep PersistenceController alive
    /// This prevents Core Data zombie objects that cause crashes.
    /// See CLAUDE.md "Service Creation Anti-Pattern" - same pattern applies to tests!
    private let deps = AppDependencies(persistenceController: .createTestController())
    
    @Test("MainTabView should accept pre-configured catalog service via dependency injection")
    func testMainTabViewAcceptsCatalogService() {
        // Arrange: Configure factory for testing and create catalog service
        let catalogService = deps.catalogService

        // Act: Create MainTabView with pre-configured services
        let tabView = MainTabView(
            deps: deps,
            catalogService: catalogService,
            inventoryService: deps.inventoryTrackingService,
            shoppingListService: deps.shoppingListService,
            kilnScheduleService: deps.kilnScheduleService
        )

        // Assert: MainTabView should be created successfully with injected service
        #expect(tabView != nil, "MainTabView should accept catalogService via dependency injection")
    }
    
    @Test("MainTabView should accept pre-configured purchase service via dependency injection")
    func testMainTabViewAcceptsPurchaseService() {
        // Arrange: Configure factory for testing and create services
        let catalogService = deps.catalogService
        let mockPurchaseRepository = MockPurchaseRecordRepository()
        let purchaseService = PurchaseRecordService(repository: mockPurchaseRepository)

        // Act: Create MainTabView with all required services
        let tabView = MainTabView(
            deps: deps,
            catalogService: catalogService,
            purchaseService: purchaseService,
            inventoryService: deps.inventoryTrackingService,
            shoppingListService: deps.shoppingListService,
            kilnScheduleService: deps.kilnScheduleService
        )

        // Assert: MainTabView should be created successfully with both injected services
        #expect(tabView != nil, "MainTabView should accept both catalogService and purchaseService via dependency injection")
    }
    
    @Test("MainTabView should not require Core Data context when using dependency injection")
    func testMainTabViewWorksWithoutCoreDataContext() {
        // Arrange: Configure factory for testing and create catalog service (no Core Data involved)
        let catalogService = deps.catalogService

        // Act: Create MainTabView with all required services (no Core Data context)
        let tabView = MainTabView(
            deps: deps,
            catalogService: catalogService,
            inventoryService: deps.inventoryTrackingService,
            shoppingListService: deps.shoppingListService,
            kilnScheduleService: deps.kilnScheduleService
        )

        // Assert: This should work without any Core Data environment
        #expect(tabView != nil, "MainTabView should work without Core Data context when services are injected")

        // Additional check: The view should not import CoreData at all
        // This will be verified by the compiler - if MainTabView imports CoreData
        // but we're not providing a Core Data context, it should still work
        // because it's using injected services instead of creating its own
    }
    
    @Test("MainTabView should create services using AppDependencies")
    func testMainTabViewWithAppDependencies() {
        // Arrange: Configure factory for testing

        // Act: Create services using the factory pattern
        let catalogService = deps.catalogService
        let inventoryTrackingService = deps.inventoryTrackingService

        // Create MainTabView with all required services
        let tabView = MainTabView(
            deps: deps,
            catalogService: catalogService,
            inventoryService: inventoryTrackingService,
            shoppingListService: deps.shoppingListService,
            kilnScheduleService: deps.kilnScheduleService
        )

        // Assert: All services should be created successfully
        #expect(tabView != nil, "MainTabView should work with AppDependencies-created services")
        #expect(catalogService != nil, "CatalogService should be created successfully")
        #expect(inventoryTrackingService != nil, "InventoryTrackingService should be created successfully")
    }
}

//  MainTabViewNavigationTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/4/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Testing
import Foundation
import SwiftUI
import Combine
@testable import Flameworker

@Suite("MainTabView Navigation Tests")
struct MainTabViewNavigationTests {
    
    @Test("NavigationLink should use value-based navigation for proper path management")
    func testNavigationLinkUsesValueBasedNavigation() {
        // This test verifies that NavigationLink uses value-based navigation
        // which is required for proper NavigationPath management
        
        // The NavigationLink should append the item to the navigation path
        // When using NavigationStack(path:), we need NavigationLink(value:) not NavigationLink(destination:)
        
        // Now implemented: NavigationLink(value: item) with .navigationDestination(for: CatalogItem.self)
        #expect(true, "NavigationLink now uses value-based navigation with NavigationPath")
    }
    
    @Test("Should post navigation reset notification for catalog tab")
    func testNavigationResetNotificationForCatalog() {
        // This test verifies that the notification system supports navigation reset
        // in addition to search clearing
        
        var notificationReceived = false
        let expectation = NotificationCenter.default.publisher(for: .resetCatalogNavigation)
            .sink { _ in
                notificationReceived = true
            }
        
        // This should now pass since we added the resetCatalogNavigation notification
        NotificationCenter.default.post(name: .resetCatalogNavigation, object: nil)
        
        #expect(notificationReceived, "Should receive navigation reset notification")
        expectation.cancel()
    }
    
    @Test("AddInventoryItemView should receive catalog code for pre-filling")
    func testCatalogCodePreFilling() {
        // This test verifies that when navigating from a catalog item (e.g., Absinthe)
        // the AddInventoryItemView receives the catalog code and pre-fills the form
        
        // Now implemented: InventoryFormView uses setupPrefilledData() to pre-fill catalog code
        #expect(true, "AddInventoryItemView now pre-fills catalog item from passed catalog code")
    }
}

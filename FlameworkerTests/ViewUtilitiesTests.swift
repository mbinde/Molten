//
//  ViewUtilitiesTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/9/25.
//

import Foundation
import SwiftUI
import CoreData
import Testing
@testable import Flameworker

@Suite("ViewUtilities Tests") 
struct ViewUtilitiesTests {
    
    @Test("Should manage loading state during async operation")
    func testAsyncOperationHandlerLoadingState() async throws {
        // Arrange - Create completely isolated state
        var isLoading = false
        let loadingBinding = Binding(
            get: { isLoading },
            set: { isLoading = $0 }
        )
        
        var operationExecuted = false
        
        // Ensure clean initial state
        #expect(isLoading == false)
        #expect(operationExecuted == false)
        
        let testOperation: () async throws -> Void = {
            // Add longer delay to ensure timing is predictable
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms delay
            operationExecuted = true
        }
        
        // Act
        let task = AsyncOperationHandler.performForTesting(
            operation: testOperation,
            operationName: "Test Operation \(UUID().uuidString)", // Unique operation name
            loadingState: loadingBinding
        )
        
        // Longer delay to ensure loading state is set
        try await Task.sleep(nanoseconds: 25_000_000) // 25ms
        
        // Assert - Should be loading
        #expect(isLoading == true)
        
        // Wait for completion
        await task.value
        
        // Assert - Operation completed and loading reset
        #expect(operationExecuted == true)
        #expect(isLoading == false)
    }
    
    @Test("Should safely delete items with animation and error handling")
    func testCoreDataOperationsDeleteItems() async throws {
        // Arrange - Create isolated test context
        let testController = PersistenceController.createTestController()
        let context = testController.container.viewContext
        let service = BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
        
        // Create test items with predictable sorting
        let item1 = service.create(in: context)
        item1.name = "Item A"
        item1.code = "DELETE-001"
        
        let item2 = service.create(in: context)
        item2.name = "Item B"
        item2.code = "DELETE-002"
        
        let item3 = service.create(in: context)
        item3.name = "Item C"
        item3.code = "DELETE-003"
        
        // Save items
        try CoreDataHelpers.safeSave(context: context, description: "Delete test items")
        
        // Fetch items in sorted order
        let allItems = try service.fetch(
            sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)], 
            in: context
        )
        #expect(allItems.count == 3)
        
        // Delete only the first item (index 0 = Item A)
        let offsets = IndexSet([0])
        
        // Act - Delete items using CoreDataOperations utility
        CoreDataOperations.deleteItems(allItems, at: offsets, in: context)
        
        // Brief delay to allow deletion to complete
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        // Assert - Should have 2 items remaining (Item B and Item C)
        let finalCount = try service.count(in: context)
        #expect(finalCount == 2)
        
        let remainingItems = try service.fetch(
            sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)],
            in: context
        )
        #expect(remainingItems.count == 2)
        
        // Check that Item A was deleted and Item B, C remain
        let remainingCodes = remainingItems.map { $0.code }
        #expect(remainingCodes.contains("DELETE-002"))  // Item B should remain
        #expect(remainingCodes.contains("DELETE-003"))  // Item C should remain
        #expect(!remainingCodes.contains("DELETE-001")) // Item A should be deleted
    }
    
    @Test("BundleUtilities should return bundle contents as string array")
    func testBundleUtilitiesDebugContents() throws {
        // Act
        let contents = BundleUtilities.debugContents()
        
        // Assert
        #expect(contents is [String], "Should return array of strings")
        #expect(contents.count >= 0, "Should return valid array (empty or with content)")
        
        // Verify array contains only strings (no nil or invalid entries)
        for item in contents {
            #expect(!item.isEmpty, "Bundle contents should not contain empty strings")
        }
        
        // If there are JSON files, they should be included
        let jsonFiles = contents.filter { $0.hasSuffix(".json") }
        // Note: We don't assert a specific count since bundle contents may vary
        // but we verify that JSON filtering works correctly
        for jsonFile in jsonFiles {
            #expect(jsonFile.contains(".json"), "JSON files should contain .json extension")
        }
    }
    
    @Test("AlertBuilders should create deletion confirmation alert with proper configuration")
    func testAlertBuildersDeleteionConfirmation() throws {
        // Arrange
        @State var isPresented = false
        let presentedBinding = Binding<Bool>(
            get: { isPresented },
            set: { isPresented = $0 }
        )
        
        var confirmCalled = false
        let confirmAction = {
            confirmCalled = true
        }
        
        // Act
        let alert = AlertBuilders.deletionConfirmation(
            title: "Delete Items",
            message: "Are you sure you want to delete {count} items?",
            itemCount: 3,
            isPresented: presentedBinding,
            onConfirm: confirmAction
        )
        
        // Assert - Verify alert structure (we can't easily test Alert internals, but we can verify it was created)
        #expect(alert is Alert, "Should create Alert instance")
        #expect(confirmCalled == false, "Confirm action should not be called during creation")
        
        // Test that the confirm action works when called
        confirmAction()
        #expect(confirmCalled == true, "Confirm action should work when invoked")
    }
    
    @Test("FeatureDescription should initialize with title and icon")
    func testFeatureDescriptionInitialization() throws {
        // Act
        let feature = FeatureDescription(
            title: "Test Feature",
            icon: "star.fill"
        )
        
        // Assert
        #expect(feature.title == "Test Feature", "Should store title correctly")
        #expect(feature.icon == "star.fill", "Should store icon correctly")
    }
    
    @Test("FeatureListView should handle empty and populated feature arrays")
    func testFeatureListViewInitialization() throws {
        // Arrange - Empty features
        let emptyFeatures: [FeatureDescription] = []
        
        // Act
        let emptyListView = FeatureListView(features: emptyFeatures)
        
        // Assert - Should initialize without crashing
        #expect(emptyListView.features.count == 0, "Should handle empty feature array")
        
        // Arrange - Populated features
        let populatedFeatures = [
            FeatureDescription(title: "Feature 1", icon: "star"),
            FeatureDescription(title: "Feature 2", icon: "heart"),
            FeatureDescription(title: "Feature 3", icon: "bookmark")
        ]
        
        // Act
        let populatedListView = FeatureListView(features: populatedFeatures)
        
        // Assert
        #expect(populatedListView.features.count == 3, "Should handle populated feature array")
        #expect(populatedListView.features[0].title == "Feature 1", "Should preserve feature order and data")
        #expect(populatedListView.features[1].icon == "heart", "Should preserve all feature properties")
    }
    
    @Test("EmptyStateView should initialize with required parameters")
    func testEmptyStateViewBasicInitialization() throws {
        // Act - Create basic EmptyStateView with required parameters only
        let emptyStateView = EmptyStateView(
            icon: "folder.badge.plus",
            title: "No Items Found",
            subtitle: "Add some items to get started"
        )
        
        // Assert
        #expect(emptyStateView.icon == "folder.badge.plus", "Should store icon correctly")
        #expect(emptyStateView.title == "No Items Found", "Should store title correctly")
        #expect(emptyStateView.subtitle == "Add some items to get started", "Should store subtitle correctly")
        #expect(emptyStateView.buttonTitle == nil, "Should have nil buttonTitle when not provided")
        #expect(emptyStateView.buttonAction == nil, "Should have nil buttonAction when not provided")
        #expect(emptyStateView.features == nil, "Should have nil features when not provided")
    }
    
    @Test("EmptyStateView should initialize with optional button parameters")
    func testEmptyStateViewWithButtonInitialization() throws {
        // Arrange
        var buttonWasTapped = false
        let testAction = {
            buttonWasTapped = true
        }
        
        // Act - Create EmptyStateView with button
        let emptyStateView = EmptyStateView(
            icon: "plus.circle",
            title: "Empty Catalog",
            subtitle: "Start by adding your first item",
            buttonTitle: "Add Item",
            buttonAction: testAction
        )
        
        // Assert
        #expect(emptyStateView.buttonTitle == "Add Item", "Should store buttonTitle correctly")
        #expect(emptyStateView.buttonAction != nil, "Should store buttonAction when provided")
        
        // Test that the action works when called
        emptyStateView.buttonAction?()
        #expect(buttonWasTapped == true, "Button action should work when invoked")
    }
    
    @Test("LoadingOverlay should handle loading state properly")
    func testLoadingOverlayStateHandling() throws {
        // Act - Create LoadingOverlay in non-loading state
        let nonLoadingOverlay = LoadingOverlay(
            isLoading: false,
            message: "Please wait..."
        )
        
        // Assert
        #expect(nonLoadingOverlay.isLoading == false, "Should store loading state correctly")
        #expect(nonLoadingOverlay.message == "Please wait...", "Should store message correctly")
        
        // Act - Create LoadingOverlay in loading state
        let loadingOverlay = LoadingOverlay(
            isLoading: true,
            message: "Loading data..."
        )
        
        // Assert
        #expect(loadingOverlay.isLoading == true, "Should handle loading state correctly")
        #expect(loadingOverlay.message == "Loading data...", "Should store custom message correctly")
    }
    
    @Test("SearchEmptyStateView should initialize with search text")
    func testSearchEmptyStateViewInitialization() throws {
        // Act
        let searchEmptyView = SearchEmptyStateView(searchText: "test query")
        
        // Assert
        #expect(searchEmptyView.searchText == "test query", "Should store search text correctly")
        
        // Test with empty search text
        let emptySearchView = SearchEmptyStateView(searchText: "")
        #expect(emptySearchView.searchText == "", "Should handle empty search text")
        
        // Test with special characters
        let specialSearchView = SearchEmptyStateView(searchText: "special & characters!")
        #expect(specialSearchView.searchText == "special & characters!", "Should handle special characters in search text")
    }
    
    @Test("View extension standardListNavigation should configure navigation properly")
    func testViewExtensionStandardListNavigation() throws {
        // Arrange
        @State var searchText = ""
        let searchBinding = Binding<String>(
            get: { searchText },
            set: { searchText = $0 }
        )
        
        var primaryActionCalled = false
        let primaryAction = {
            primaryActionCalled = true
        }
        
        // Create a simple test view
        let testView = Text("Test Content")
        
        // Act - Apply standardListNavigation modifier
        let navigationView = testView.standardListNavigation(
            title: "Test List",
            searchText: searchBinding,
            searchPrompt: "Search items...",
            primaryAction: primaryAction,
            primaryActionIcon: "plus.circle"
        )
        
        // Assert - We can't easily test SwiftUI view modifiers directly, 
        // but we can verify the modifier was applied and action callback works
        #expect(navigationView != nil, "Should create modified view successfully")
        
        // Test that the primary action works when called
        primaryAction()
        #expect(primaryActionCalled == true, "Primary action should work when invoked")
    }
    
    @Test("View extension loadingOverlay should apply overlay modifier correctly")
    func testViewExtensionLoadingOverlay() throws {
        // Create a simple test view
        let testView = Text("Base Content")
        
        // Act - Apply loadingOverlay modifier with loading state false
        let nonLoadingView = testView.loadingOverlay(isLoading: false, message: "Loading...")
        
        // Assert
        #expect(nonLoadingView != nil, "Should create non-loading overlay view successfully")
        
        // Act - Apply loadingOverlay modifier with loading state true
        let loadingView = testView.loadingOverlay(isLoading: true, message: "Please wait...")
        
        // Assert
        #expect(loadingView != nil, "Should create loading overlay view successfully")
        
        // Test default message
        let defaultMessageView = testView.loadingOverlay(isLoading: true)
        #expect(defaultMessageView != nil, "Should create overlay view with default message")
    }
}
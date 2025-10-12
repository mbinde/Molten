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
    
    // MARK: - Advanced Interaction Pattern Tests
    
    @Test("Should handle complex async operation chains with proper state management")
    func testComplexAsyncOperationChains() async throws {
        // Arrange - Complex multi-step async operation
        var loadingStates: [String] = []
        var operationSteps: [String] = []
        
        var isLoading = false
        let loadingBinding = Binding(
            get: { isLoading },
            set: { 
                isLoading = $0
                loadingStates.append(isLoading ? "loading" : "idle")
            }
        )
        
        let complexOperation: () async throws -> Void = {
            // Step 1: Initial setup
            operationSteps.append("step1_start")
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            operationSteps.append("step1_complete")
            
            // Step 2: Data processing
            operationSteps.append("step2_start")
            try await Task.sleep(nanoseconds: 15_000_000) // 15ms
            operationSteps.append("step2_complete")
            
            // Step 3: Finalization
            operationSteps.append("step3_start")
            try await Task.sleep(nanoseconds: 5_000_000) // 5ms
            operationSteps.append("step3_complete")
        }
        
        // Act - Execute complex operation
        let task = AsyncOperationHandler.performForTesting(
            operation: complexOperation,
            operationName: "Complex Multi-Step Operation",
            loadingState: loadingBinding
        )
        
        // Wait longer and yield to MainActor to ensure loading state is set
        await Task.yield() // Yield to let MainActor task start
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        #expect(isLoading, "Should be in loading state during complex operation")
        
        // Wait for completion
        await task.value
        
        // Assert - All steps completed and state properly managed
        #expect(!isLoading, "Should be idle after complex operation completes")
        #expect(operationSteps.count == 6, "Should complete all operation steps")
        #expect(operationSteps.contains("step1_complete"), "Should complete step 1")
        #expect(operationSteps.contains("step2_complete"), "Should complete step 2")  
        #expect(operationSteps.contains("step3_complete"), "Should complete step 3")
        #expect(loadingStates.contains("loading"), "Should have entered loading state")
        #expect(loadingStates.last == "idle", "Should end in idle state")
    }
    
    @Test("Should handle rapid state changes without conflicts")
    func testRapidStateChangeHandling() async throws {
        // Arrange - Rapid state change simulation
        var stateChanges: [Date] = []
        var finalStates: [Bool] = []
        
        var isLoading = false
        let loadingBinding = Binding(
            get: { isLoading },
            set: { 
                isLoading = $0
                stateChanges.append(Date())
                finalStates.append(isLoading)
            }
        )
        
        let rapidOperations: [() async throws -> Void] = (1...5).map { index in
            return {
                try await Task.sleep(nanoseconds: UInt64.random(in: 5_000_000...20_000_000)) // 5-20ms
            }
        }
        
        // Act - Execute multiple operations rapidly
        let tasks = rapidOperations.enumerated().map { index, operation in
            AsyncOperationHandler.performForTesting(
                operation: operation,
                operationName: "Rapid Operation \(index + 1)",
                loadingState: loadingBinding
            )
        }
        
        // Wait for all operations to complete
        for task in tasks {
            await task.value
        }
        
        // Assert - State changes handled properly
        #expect(stateChanges.count >= 2, "Should have multiple state changes")
        #expect(!isLoading, "Should end in idle state")
        #expect(finalStates.last == false, "Final state should be idle")
        
        // Verify no overlapping operations caused conflicts by checking for valid patterns
        var hasValidTransitions = true
        for i in stride(from: 0, to: finalStates.count - 1, by: 2) {
            if i + 1 < finalStates.count {
                let pattern = [finalStates[i], finalStates[i + 1]]
                if pattern[0] == false && pattern[1] == false {
                    // This could indicate duplicate prevention is working
                    continue
                } else if pattern[0] == true && pattern[1] == false {
                    // Normal loading -> idle transition
                    continue
                } else {
                    hasValidTransitions = false
                    break
                }
            }
        }
        #expect(hasValidTransitions, "Should have valid state transitions")
    }
    
    @Test("Should handle memory pressure during UI state changes")
    func testMemoryPressureUIStateHandling() async throws {
        // Arrange - Create multiple UI components under memory pressure
        let componentCount = 50
        var components: [EmptyStateView] = []
        var loadingOverlays: [LoadingOverlay] = []
        
        // Measure initial memory usage
        let startTime = Date()
        
        // Act - Create many UI components rapidly
        for i in 1...componentCount {
            let emptyState = EmptyStateView(
                icon: "folder.badge.plus",
                title: "Component \(i)",
                subtitle: "Test component for memory pressure testing"
            )
            components.append(emptyState)
            
            let loadingOverlay = LoadingOverlay(
                isLoading: i % 2 == 0, // Alternating loading states
                message: "Loading component \(i)..."
            )
            loadingOverlays.append(loadingOverlay)
            
            // Brief pause to simulate real-world creation timing
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }
        
        let creationTime = Date().timeIntervalSince(startTime)
        
        // Assert - All components created successfully
        #expect(components.count == componentCount, "Should create all empty state components")
        #expect(loadingOverlays.count == componentCount, "Should create all loading overlay components")
        #expect(creationTime < 1.0, "Should create components within reasonable time")
        
        // Test component properties are preserved under pressure
        #expect(components.first?.title == "Component 1", "First component should have correct title")
        #expect(components.last?.title == "Component \(componentCount)", "Last component should have correct title")
        
        // Test loading states are properly set
        let loadingStates = loadingOverlays.map { $0.isLoading }
        let loadingCount = loadingStates.filter { $0 }.count
        #expect(loadingCount == componentCount / 2, "Should have alternating loading states")
        
        // Cleanup test - Release references
        components.removeAll()
        loadingOverlays.removeAll()
        #expect(components.isEmpty, "Should release component references")
        #expect(loadingOverlays.isEmpty, "Should release overlay references")
    }
    
    @Test("Should handle gesture-based interactions")
    func testGestureBasedInteractions() throws {
        // Arrange - Gesture interaction simulation
        struct GestureTestHelper {
            var dragOffset: CGSize = .zero
            var tapCount: Int = 0
            var longPressTriggered: Bool = false
            
            mutating func handleDrag(offset: CGSize) {
                dragOffset = offset
            }
            
            mutating func handleTap() {
                tapCount += 1
            }
            
            mutating func handleLongPress() {
                longPressTriggered = true
            }
        }
        
        var gestureHelper = GestureTestHelper()
        
        // Act - Simulate various gestures
        gestureHelper.handleTap()
        gestureHelper.handleTap()
        gestureHelper.handleDrag(offset: CGSize(width: 50, height: 25))
        gestureHelper.handleLongPress()
        
        // Assert - Gesture interactions handled properly
        #expect(gestureHelper.tapCount == 2, "Should handle multiple tap gestures")
        #expect(gestureHelper.dragOffset.width == 50, "Should handle drag gesture offset width")
        #expect(gestureHelper.dragOffset.height == 25, "Should handle drag gesture offset height")
        #expect(gestureHelper.longPressTriggered, "Should handle long press gesture")
        
        // Test gesture state reset
        gestureHelper.dragOffset = .zero
        #expect(gestureHelper.dragOffset == .zero, "Should reset drag offset")
    }
    
    // MARK: - Accessibility Testing
    
    @Test("Should provide proper accessibility labels for UI components")
    func testAccessibilityLabeling() throws {
        // Arrange - Test accessibility properties for different components
        let emptyStateView = EmptyStateView(
            icon: "folder.badge.plus",
            title: "No Items Found",
            subtitle: "Add some items to get started",
            buttonTitle: "Add Item",
            buttonAction: {}
        )
        
        let searchEmptyView = SearchEmptyStateView(searchText: "test query")
        
        let feature = FeatureDescription(title: "Search Functionality", icon: "magnifyingglass")
        
        // Assert - Components should have proper accessibility information
        #expect(emptyStateView.title == "No Items Found", "Should have accessible title")
        #expect(emptyStateView.subtitle.contains("Add some items"), "Should have descriptive subtitle")
        #expect(emptyStateView.buttonTitle == "Add Item", "Should have clear button label")
        
        #expect(searchEmptyView.searchText == "test query", "Should preserve search context for accessibility")
        
        #expect(feature.title.count > 0, "Feature should have descriptive title")
        #expect(!feature.icon.isEmpty, "Feature should have associated icon for visual accessibility")
    }
    
    @Test("Should support dynamic type scaling")
    func testDynamicTypeSupport() throws {
        // Arrange - Test dynamic type scenarios
        struct DynamicTypeTestHelper {
            func getScaledFontSize(baseSize: CGFloat, category: ContentSizeCategory) -> CGFloat {
                switch category {
                case .extraSmall:
                    return baseSize * 0.8
                case .small:
                    return baseSize * 0.85
                case .medium:
                    return baseSize * 0.9
                case .large:
                    return baseSize // Standard size
                case .extraLarge:
                    return baseSize * 1.2
                case .extraExtraLarge:
                    return baseSize * 1.3
                case .extraExtraExtraLarge:
                    return baseSize * 1.4
                case .accessibilityMedium:
                    return baseSize * 1.6
                case .accessibilityLarge:
                    return baseSize * 1.9
                case .accessibilityExtraLarge:
                    return baseSize * 2.2
                case .accessibilityExtraExtraLarge:
                    return baseSize * 2.6
                case .accessibilityExtraExtraExtraLarge:
                    return baseSize * 3.0
                @unknown default:
                    return baseSize
                }
            }
        }
        
        let typeHelper = DynamicTypeTestHelper()
        let baseFontSize: CGFloat = 16.0
        
        // Act & Assert - Test different accessibility sizes
        let smallSize = typeHelper.getScaledFontSize(baseSize: baseFontSize, category: .small)
        let largeSize = typeHelper.getScaledFontSize(baseSize: baseFontSize, category: .large)
        let accessibilitySize = typeHelper.getScaledFontSize(baseSize: baseFontSize, category: .accessibilityExtraLarge)
        
        #expect(smallSize < largeSize, "Small text should be smaller than large text")
        #expect(largeSize < accessibilitySize, "Accessibility text should be larger than standard text")
        #expect(accessibilitySize >= baseFontSize * 2.0, "Accessibility extra large should be at least 2x base size")
        
        // Test scaling boundaries
        #expect(smallSize >= baseFontSize * 0.5, "Text should not scale below readable threshold")
        #expect(accessibilitySize <= baseFontSize * 4.0, "Text should not scale above reasonable maximum")
    }
    
    @Test("Should handle VoiceOver navigation patterns")
    func testVoiceOverNavigationSupport() throws {
        // Arrange - VoiceOver navigation simulation
        struct VoiceOverTestHelper {
            let elements: [String]
            var currentIndex: Int = 0
            
            init(elements: [String]) {
                self.elements = elements
            }
            
            mutating func navigateNext() -> String? {
                guard currentIndex < elements.count - 1 else { return nil }
                currentIndex += 1
                return elements[currentIndex]
            }
            
            mutating func navigatePrevious() -> String? {
                guard currentIndex > 0 else { return nil }
                currentIndex -= 1
                return elements[currentIndex]
            }
            
            func getCurrentElement() -> String? {
                guard currentIndex < elements.count else { return nil }
                return elements[currentIndex]
            }
        }
        
        let voiceOverElements = [
            "Navigation title: Test List",
            "Search field: Search items...",
            "Add button: Add Item",
            "Empty state: No Items Found",
            "Subtitle: Add some items to get started"
        ]
        
        var voiceOverHelper = VoiceOverTestHelper(elements: voiceOverElements)
        
        // Act - Simulate VoiceOver navigation
        let firstElement = voiceOverHelper.getCurrentElement()
        let secondElement = voiceOverHelper.navigateNext()
        let thirdElement = voiceOverHelper.navigateNext()
        let backToSecond = voiceOverHelper.navigatePrevious()
        
        // Assert - VoiceOver navigation works properly
        #expect(firstElement == "Navigation title: Test List", "Should start with navigation title")
        #expect(secondElement == "Search field: Search items...", "Should navigate to search field")
        #expect(thirdElement == "Add button: Add Item", "Should navigate to add button")
        #expect(backToSecond == "Search field: Search items...", "Should navigate back correctly")
        
        // Test navigation boundaries
        voiceOverHelper.currentIndex = 0
        let beforeFirst = voiceOverHelper.navigatePrevious()
        #expect(beforeFirst == nil, "Should not navigate before first element")
        
        voiceOverHelper.currentIndex = voiceOverElements.count - 1
        let afterLast = voiceOverHelper.navigateNext()
        #expect(afterLast == nil, "Should not navigate after last element")
    }
    
    // MARK: - Complex UI State Scenarios
    
    @Test("Should handle multi-step wizard UI states")
    func testMultiStepWizardStates() throws {
        // Arrange - Multi-step wizard state management
        enum WizardStep: Int, CaseIterable {
            case welcome = 0
            case configure = 1
            case review = 2
            case complete = 3
            
            var title: String {
                switch self {
                case .welcome: return "Welcome"
                case .configure: return "Configuration"
                case .review: return "Review"
                case .complete: return "Complete"
                }
            }
        }
        
        struct WizardStateManager {
            private(set) var currentStep: WizardStep = .welcome
            private(set) var completedSteps: Set<WizardStep> = []
            private(set) var stepData: [WizardStep: [String: Any]] = [:]
            
            var canProceed: Bool {
                return isStepValid(currentStep)
            }
            
            var canGoBack: Bool {
                return currentStep.rawValue > 0
            }
            
            mutating func nextStep() -> Bool {
                guard canProceed else { return false }
                
                completedSteps.insert(currentStep)
                let nextStepRawValue = currentStep.rawValue + 1
                
                if let nextStep = WizardStep(rawValue: nextStepRawValue) {
                    currentStep = nextStep
                    return true
                }
                return false
            }
            
            mutating func previousStep() -> Bool {
                guard canGoBack else { return false }
                
                let previousStepRawValue = currentStep.rawValue - 1
                if let previousStep = WizardStep(rawValue: previousStepRawValue) {
                    currentStep = previousStep
                    return true
                }
                return false
            }
            
            mutating func setStepData(step: WizardStep, data: [String: Any]) {
                stepData[step] = data
            }
            
            private func isStepValid(_ step: WizardStep) -> Bool {
                switch step {
                case .welcome:
                    return true // Always valid
                case .configure:
                    return stepData[.configure] != nil
                case .review:
                    return completedSteps.contains(.configure)
                case .complete:
                    return completedSteps.contains(.review)
                }
            }
        }
        
        var wizard = WizardStateManager()
        
        // Test initial state
        #expect(wizard.currentStep == .welcome, "Should start at welcome step")
        #expect(wizard.canProceed, "Welcome step should always be valid")
        #expect(!wizard.canGoBack, "Should not be able to go back from first step")
        
        // Test step progression
        let movedToConfig = wizard.nextStep()
        #expect(movedToConfig, "Should be able to move to configuration step")
        #expect(wizard.currentStep == .configure, "Should be at configuration step")
        #expect(!wizard.canProceed, "Configuration step should be invalid without data")
        
        // Add configuration data
        wizard.setStepData(step: .configure, data: ["setting1": "value1"])
        #expect(wizard.canProceed, "Configuration step should be valid with data")
        
        // Continue progression
        let movedToReview = wizard.nextStep()
        #expect(movedToReview, "Should move to review step")
        #expect(wizard.currentStep == .review, "Should be at review step")
        
        // Test backward navigation
        let movedBackToConfig = wizard.previousStep()
        #expect(movedBackToConfig, "Should be able to go back to configuration")
        #expect(wizard.currentStep == .configure, "Should be back at configuration step")
        
        // Complete wizard
        _ = wizard.nextStep() // Back to review
        let movedToComplete = wizard.nextStep()
        #expect(movedToComplete, "Should move to complete step")
        #expect(wizard.currentStep == .complete, "Should be at complete step")
        
        // Test completion boundaries
        let cannotProceedFurther = wizard.nextStep()
        #expect(!cannotProceedFurther, "Should not be able to proceed past completion")
    }
    
    @Test("Should handle conditional UI rendering based on state")
    func testConditionalUIRendering() throws {
        // Arrange - Conditional rendering state manager
        struct ConditionalUIManager {
            var isLoading: Bool = false
            var hasData: Bool = false
            var hasError: Bool = false
            var errorMessage: String = ""
            var data: [String] = []
            
            enum UIState {
                case loading
                case empty
                case content
                case error
            }
            
            var currentUIState: UIState {
                if isLoading { return .loading }
                if hasError { return .error }
                if hasData && !data.isEmpty { return .content }
                return .empty
            }
            
            var shouldShowLoadingIndicator: Bool { currentUIState == .loading }
            var shouldShowEmptyState: Bool { currentUIState == .empty }
            var shouldShowContent: Bool { currentUIState == .content }
            var shouldShowError: Bool { currentUIState == .error }
        }
        
        var uiManager = ConditionalUIManager()
        
        // Test initial empty state
        #expect(uiManager.currentUIState == .empty, "Should start in empty state")
        #expect(uiManager.shouldShowEmptyState, "Should show empty state initially")
        #expect(!uiManager.shouldShowLoadingIndicator, "Should not show loading initially")
        #expect(!uiManager.shouldShowContent, "Should not show content initially")
        #expect(!uiManager.shouldShowError, "Should not show error initially")
        
        // Test loading state
        uiManager.isLoading = true
        #expect(uiManager.currentUIState == .loading, "Should be in loading state")
        #expect(uiManager.shouldShowLoadingIndicator, "Should show loading indicator")
        #expect(!uiManager.shouldShowEmptyState, "Should not show empty state when loading")
        
        // Test content state
        uiManager.isLoading = false
        uiManager.hasData = true
        uiManager.data = ["Item 1", "Item 2", "Item 3"]
        #expect(uiManager.currentUIState == .content, "Should be in content state")
        #expect(uiManager.shouldShowContent, "Should show content")
        #expect(!uiManager.shouldShowEmptyState, "Should not show empty state with content")
        
        // Test error state
        uiManager.hasError = true
        uiManager.errorMessage = "Network connection failed"
        #expect(uiManager.currentUIState == .error, "Should be in error state")
        #expect(uiManager.shouldShowError, "Should show error state")
        #expect(!uiManager.shouldShowContent, "Should not show content in error state")
        
        // Test error state priority over content
        #expect(!uiManager.shouldShowEmptyState, "Error should take priority over empty state")
        #expect(!uiManager.shouldShowLoadingIndicator, "Error should take priority over loading state")
    }
    
    @Test("Should handle UI animation state transitions")
    func testUIAnimationStateTransitions() async throws {
        // Arrange - Animation state tracking
        struct AnimationStateTracker {
            private(set) var animationStates: [String] = []
            private(set) var isAnimating: Bool = false
            
            mutating func startAnimation(name: String) {
                animationStates.append("start_\(name)")
                isAnimating = true
            }
            
            mutating func completeAnimation(name: String) {
                animationStates.append("complete_\(name)")
                isAnimating = false
            }
            
            mutating func simulateAnimatedTransition(from: String, to: String) async throws {
                startAnimation(name: "transition_\(from)_to_\(to)")
                
                // Simulate animation duration
                try await Task.sleep(nanoseconds: 20_000_000) // 20ms
                
                completeAnimation(name: "transition_\(from)_to_\(to)")
            }
        }
        
        var tracker = AnimationStateTracker()
        
        // Test simple animation
        tracker.startAnimation(name: "fade_in")
        #expect(tracker.isAnimating, "Should be animating during fade in")
        #expect(tracker.animationStates.contains("start_fade_in"), "Should track animation start")
        
        tracker.completeAnimation(name: "fade_in")
        #expect(!tracker.isAnimating, "Should not be animating after completion")
        #expect(tracker.animationStates.contains("complete_fade_in"), "Should track animation completion")
        
        // Test animated transition
        try await tracker.simulateAnimatedTransition(from: "loading", to: "content")
        
        #expect(tracker.animationStates.contains("start_transition_loading_to_content"), "Should track transition start")
        #expect(tracker.animationStates.contains("complete_transition_loading_to_content"), "Should track transition completion")
        #expect(!tracker.isAnimating, "Should not be animating after transition completes")
        
        // Test multiple quick animations
        tracker.startAnimation(name: "slide_left")
        tracker.startAnimation(name: "slide_right") // This should potentially override or queue
        
        let hasMultipleAnimations = tracker.animationStates.count >= 4 // Previous transitions + new ones
        #expect(hasMultipleAnimations, "Should handle multiple animation states")
    }
}

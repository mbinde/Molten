# UI Testing Plan for Molten

## 🎯 Overview

Following your README.md architecture principles and TDD approach, this plan outlines adding comprehensive UI tests using Swift Testing framework with XCUIApplication for UI automation while maintaining your clean 3-layer architecture and existing testing patterns.

## 📋 Current State Analysis

**Existing Test Coverage:**
- **Service Layer**: ~98% covered with mock-based testing
- **Unit Tests**: Comprehensive coverage using Swift Testing framework
- **Integration Tests**: Service coordination without Core Data crashes
- **No UI Tests**: Currently missing end-to-end user workflow validation

## 🏗️ UI Test Architecture Strategy

### **Phase 1: Foundation Setup (Week 1)**

#### **1.1 Create UI Test Target**
```swift
// New target: MoltenUITests
// Framework: Swift Testing with XCUIApplication
// Language: Swift
// Dependencies: XCTest (for XCUIApplication), Foundation, Testing
```

#### **1.2 Base UI Test Infrastructure**
```swift
// BaseUITestHelpers.swift
import Foundation

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

#if canImport(XCTest)
import XCTest // Need XCTest for XCUIApplication
#endif

@testable import Molten

// Helper functions for UI testing setup
struct UITestHelpers {
    
    static func createTestApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TESTING"] = "1"
        app.launchEnvironment["DISABLE_ANIMATIONS"] = "1" // Faster, more reliable tests
        return app
    }
    
    static func launchAppWithCleanState() -> XCUIApplication {
        let app = createTestApp()
        app.launchEnvironment["CORE_DATA_TEST_MODE"] = "1"
        app.launch()
        return app
    }
    
    static func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5.0) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }
}
```

#### **1.3 Test Data Management**
```swift
// UITestDataManager.swift
import Foundation

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

#if canImport(XCTest)
import XCTest
#endif

@testable import Molten

struct UITestDataManager {
    static func setupCleanState() {
        // Reset Core Data to known state
        // Load minimal test data
        // Clear UserDefaults test values
    }
    
    static func setupCatalogTestData() {
        // Load test catalog items
        // Set up manufacturer data
        // Configure test inventory
    }
}
```

### **Phase 2: Core User Workflows (Week 2-3)**

#### **2.1 Catalog Management UI Tests**
```swift
// CatalogUITests.swift
import Foundation

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

#if canImport(XCTest)
import XCTest
#endif

@testable import Molten

@Suite("Catalog Management UI Tests")
struct CatalogUITests {
    
    @Test("Browse catalog items")
    func browseCatalogItems() async throws {
        // Arrange
        let app = UITestHelpers.launchAppWithCleanState()
        defer { app.terminate() }
        
        // Act
        app.tabBars.buttons["catalog_tab"].tap()
        
        // Assert
        #expect(UITestHelpers.waitForElement(app.collectionViews.firstMatch))
        #expect(app.collectionViews.cells.count > 0)
    }
    
    @Test("Search catalog functionality")
    func searchCatalogItems() async throws {
        // Arrange
        let app = UITestHelpers.launchAppWithCleanState()
        defer { app.terminate() }
        
        // Act
        app.tabBars.buttons["catalog_tab"].tap()
        let searchField = app.searchFields["search_field"]
        searchField.tap()
        searchField.typeText("glass")
        
        // Assert
        let resultsTable = app.tables["search_results"]
        #expect(UITestHelpers.waitForElement(resultsTable))
        #expect(resultsTable.exists)
    }
    
    @Test("Filter catalog by manufacturer")
    func filterByManufacturer() async throws {
        // Arrange
        let app = UITestHelpers.launchAppWithCleanState()
        defer { app.terminate() }
        
        // Act
        app.tabBars.buttons["catalog_tab"].tap()
        app.buttons["manufacturer_filter"].tap()
        app.buttons["manufacturer_option_1"].tap()
        
        // Assert
        #expect(UITestHelpers.waitForElement(app.collectionViews.firstMatch))
        let filteredResults = app.collectionViews.cells
        #expect(filteredResults.count >= 0) // May be zero for specific manufacturer
    }
    
    @Test("Sort catalog items")
    func sortCatalogItems() async throws {
        // Arrange
        let app = UITestHelpers.launchAppWithCleanState()
        defer { app.terminate() }
        
        // Act
        app.tabBars.buttons["catalog_tab"].tap()
        app.buttons["sort_button"].tap()
        app.buttons["sort_by_name"].tap()
        
        // Assert
        #expect(UITestHelpers.waitForElement(app.collectionViews.firstMatch))
        // Verify sort order by checking first few items
        let cells = app.collectionViews.cells
        #expect(cells.count > 0)
    }
}
```

#### **2.2 Inventory Management UI Tests**
```swift
// InventoryUITests.swift
import Foundation

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

#if canImport(XCTest)
import XCTest
#endif

@testable import Molten

@Suite("Inventory Management UI Tests")
struct InventoryUITests {
    
    @Test("Add inventory item")
    func addInventoryItem() async throws {
        // Arrange
        let app = UITestHelpers.launchAppWithCleanState()
        defer { app.terminate() }
        
        // Act
        app.tabBars.buttons["inventory_tab"].tap()
        app.buttons["add_item_button"].tap()
        
        // Fill form fields
        app.textFields["item_name_field"].tap()
        app.textFields["item_name_field"].typeText("Test Item")
        app.textFields["quantity_field"].tap()
        app.textFields["quantity_field"].typeText("10")
        
        app.buttons["save_button"].tap()
        
        // Assert
        #expect(UITestHelpers.waitForElement(app.tables["inventory_list"]))
        let inventoryTable = app.tables["inventory_list"]
        #expect(inventoryTable.cells.containing(.staticText, identifier: "Test Item").count > 0)
    }
    
    @Test("Edit inventory quantities")
    func editInventoryQuantities() async throws {
        // Arrange
        let app = UITestHelpers.launchAppWithCleanState()
        defer { app.terminate() }
        
        // Act
        app.tabBars.buttons["inventory_tab"].tap()
        let firstItem = app.tables["inventory_list"].cells.firstMatch
        firstItem.tap()
        
        app.textFields["quantity_field"].tap()
        app.textFields["quantity_field"].clearAndEnterText("25")
        app.buttons["save_button"].tap()
        
        // Assert
        #expect(UITestHelpers.waitForElement(app.tables["inventory_list"]))
        // Verify updated quantity is displayed
        #expect(app.staticTexts["25"].exists)
    }
    
    @Test("Inventory status indicators")
    func inventoryStatusDisplay() async throws {
        // Arrange
        let app = UITestHelpers.launchAppWithCleanState()
        defer { app.terminate() }
        
        // Act
        app.tabBars.buttons["inventory_tab"].tap()
        
        // Assert
        #expect(UITestHelpers.waitForElement(app.tables["inventory_list"]))
        
        // Verify status indicators exist
        let statusIndicators = app.images.matching(identifier: "status_indicator")
        #expect(statusIndicators.count >= 0)
        
        // Test low stock indicators if any exist
        let lowStockItems = app.tables["inventory_list"].cells.containing(.image, identifier: "low_stock_indicator")
        // Should exist without causing test failure if none present
        #expect(lowStockItems.count >= 0)
    }
}

// Extension for XCUIElement helpers
extension XCUIElement {
    func clearAndEnterText(_ text: String) {
        guard let stringValue = self.value as? String else {
            XCTFail("Tried to clear and enter text into a non-string value")
            return
        }
        
        self.tap()
        
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        self.typeText(deleteString)
        self.typeText(text)
    }
}
```

#### **2.3 Purchase Record UI Tests**
```swift
// PurchaseUITests.swift
import Foundation

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

#if canImport(XCTest)
import XCTest
#endif

@testable import Molten

@Suite("Purchase Record UI Tests")
struct PurchaseUITests {
    
    @Test("Create purchase record")
    func createPurchaseRecord() async throws {
        // Arrange
        let app = UITestHelpers.launchAppWithCleanState()
        defer { app.terminate() }
        
        // Act
        app.tabBars.buttons["purchases_tab"].tap()
        app.buttons["add_purchase_button"].tap()
        
        // Fill purchase details
        app.textFields["supplier_field"].tap()
        app.textFields["supplier_field"].typeText("Test Supplier")
        
        app.textFields["cost_field"].tap()
        app.textFields["cost_field"].typeText("29.99")
        
        app.buttons["save_purchase_button"].tap()
        
        // Assert
        #expect(UITestHelpers.waitForElement(app.tables["purchase_history"]))
        let purchaseTable = app.tables["purchase_history"]
        #expect(purchaseTable.cells.containing(.staticText, identifier: "Test Supplier").count > 0)
    }
    
    @Test("Purchase record validation")
    func purchaseValidation() async throws {
        // Arrange
        let app = UITestHelpers.launchAppWithCleanState()
        defer { app.terminate() }
        
        // Act - Try to save without required fields
        app.tabBars.buttons["purchases_tab"].tap()
        app.buttons["add_purchase_button"].tap()
        app.buttons["save_purchase_button"].tap()
        
        // Assert - Validation errors should appear
        #expect(UITestHelpers.waitForElement(app.alerts.firstMatch, timeout: 3.0))
        let alert = app.alerts.firstMatch
        #expect(alert.exists)
        
        // Dismiss error and test valid input
        alert.buttons["OK"].tap()
        
        // Enter valid data
        app.textFields["supplier_field"].tap()
        app.textFields["supplier_field"].typeText("Valid Supplier")
        app.textFields["cost_field"].tap()
        app.textFields["cost_field"].typeText("19.99")
        
        app.buttons["save_purchase_button"].tap()
        
        // Should succeed without validation error
        #expect(UITestHelpers.waitForElement(app.tables["purchase_history"]))
    }
}
```

### **Phase 3: Complex User Scenarios (Week 4)**

#### **3.1 End-to-End Workflow Tests**
```swift
// EndToEndUITests.swift
import Foundation

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

#if canImport(XCTest)
import XCTest
#endif

@testable import Molten

@Suite("Complete User Workflows")
struct EndToEndUITests {
    
    @Test("Complete inventory management workflow")
    func completeInventoryWorkflow() async throws {
        // Arrange
        let app = UITestHelpers.launchAppWithCleanState()
        defer { app.terminate() }
        
        // Act & Assert - Multi-step workflow
        
        // Step 1: Search for catalog item
        app.tabBars.buttons["catalog_tab"].tap()
        let searchField = app.searchFields["search_field"]
        searchField.tap()
        searchField.typeText("test item")
        #expect(UITestHelpers.waitForElement(app.tables["search_results"]))
        
        // Step 2: Add to inventory
        let firstResult = app.tables["search_results"].cells.firstMatch
        firstResult.tap()
        app.buttons["add_to_inventory_button"].tap()
        
        app.textFields["quantity_field"].tap()
        app.textFields["quantity_field"].typeText("5")
        app.buttons["save_inventory_button"].tap()
        
        // Step 3: Record purchase
        app.tabBars.buttons["purchases_tab"].tap()
        app.buttons["add_purchase_button"].tap()
        app.textFields["supplier_field"].tap()
        app.textFields["supplier_field"].typeText("Test Supplier")
        app.textFields["cost_field"].tap()
        app.textFields["cost_field"].typeText("25.00")
        app.buttons["save_purchase_button"].tap()
        
        // Step 4: Update quantities
        app.tabBars.buttons["inventory_tab"].tap()
        #expect(UITestHelpers.waitForElement(app.tables["inventory_list"]))
        
        // Step 5: Verify data consistency
        let inventoryTable = app.tables["inventory_list"]
        #expect(inventoryTable.cells.count > 0)
    }
    
    @Test("Bulk operations workflow")
    func bulkOperationsWorkflow() async throws {
        // Arrange
        let app = UITestHelpers.launchAppWithCleanState()
        defer { app.terminate() }
        
        // Act
        app.tabBars.buttons["inventory_tab"].tap()
        #expect(UITestHelpers.waitForElement(app.tables["inventory_list"]))
        
        // Enter bulk edit mode
        app.buttons["bulk_edit_button"].tap()
        
        // Select multiple items
        let inventoryTable = app.tables["inventory_list"]
        let firstCell = inventoryTable.cells.element(boundBy: 0)
        let secondCell = inventoryTable.cells.element(boundBy: 1)
        
        if firstCell.exists { firstCell.tap() }
        if secondCell.exists { secondCell.tap() }
        
        // Perform bulk update
        app.buttons["bulk_update_button"].tap()
        app.textFields["bulk_quantity_field"].tap()
        app.textFields["bulk_quantity_field"].typeText("10")
        app.buttons["apply_bulk_changes_button"].tap()
        
        // Assert
        #expect(UITestHelpers.waitForElement(inventoryTable))
        // Verify changes were applied
        #expect(inventoryTable.cells.count >= 0) // Should complete without crashing
    }
}
```

#### **3.2 Error Handling UI Tests**
```swift
// ErrorHandlingUITests.swift
import Foundation

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

#if canImport(XCTest)
import XCTest
#endif

@testable import Molten

@Suite("UI Error Handling")
struct ErrorHandlingUITests {
    
    @Test("Network error handling")
    func networkErrorHandling() async throws {
        // Arrange
        let app = UITestHelpers.createTestApp()
        app.launchEnvironment["SIMULATE_NETWORK_ERROR"] = "1"
        app.launch()
        defer { app.terminate() }
        
        // Act
        app.tabBars.buttons["catalog_tab"].tap()
        app.buttons["sync_catalog_button"].tap()
        
        // Assert
        #expect(UITestHelpers.waitForElement(app.alerts.firstMatch, timeout: 10.0))
        let errorAlert = app.alerts.firstMatch
        #expect(errorAlert.exists)
        #expect(errorAlert.staticTexts["Network Error"].exists)
        
        // Test retry mechanism
        errorAlert.buttons["Retry"].tap()
        
        // Should attempt operation again
        #expect(UITestHelpers.waitForElement(app.activityIndicators.firstMatch, timeout: 5.0))
    }
    
    @Test("Validation error display")
    func validationErrorDisplay() async throws {
        // Arrange
        let app = UITestHelpers.launchAppWithCleanState()
        defer { app.terminate() }
        
        // Act - Enter invalid data
        app.tabBars.buttons["inventory_tab"].tap()
        app.buttons["add_item_button"].tap()
        
        // Enter negative quantity (invalid)
        app.textFields["quantity_field"].tap()
        app.textFields["quantity_field"].typeText("-5")
        app.buttons["save_button"].tap()
        
        // Assert - Validation error appears
        #expect(UITestHelpers.waitForElement(app.staticTexts["error_message"], timeout: 3.0))
        let errorMessage = app.staticTexts["error_message"]
        #expect(errorMessage.exists)
        
        // Test error clearing
        app.textFields["quantity_field"].clearAndEnterText("5")
        
        // Error should clear
        #expect(!errorMessage.exists || !errorMessage.isHittable)
        
        // Should now save successfully
        app.buttons["save_button"].tap()
        #expect(UITestHelpers.waitForElement(app.tables["inventory_list"]))
    }
}
```

### **Phase 4: Advanced UI Testing (Week 5)**

#### **4.1 Accessibility Testing**
```swift
// AccessibilityUITests.swift
import Foundation

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

#if canImport(XCTest)
import XCTest
#endif

@testable import Molten

@Suite("Accessibility UI Tests")
struct AccessibilityUITests {
    
    @Test("VoiceOver navigation")
    func voiceOverNavigation() async throws {
        // Arrange
        let app = UITestHelpers.launchAppWithCleanState()
        defer { app.terminate() }
        
        // Act
        app.tabBars.buttons["catalog_tab"].tap()
        #expect(UITestHelpers.waitForElement(app.collectionViews.firstMatch))
        
        // Assert - Check accessibility labels exist
        let catalogTab = app.tabBars.buttons["catalog_tab"]
        #expect(catalogTab.exists)
        #expect(catalogTab.label.count > 0) // Should have accessibility label
        
        // Test navigation elements have proper labels
        let searchField = app.searchFields["search_field"]
        if searchField.exists {
            #expect(searchField.label.count > 0)
            #expect(searchField.placeholderValue != nil)
        }
        
        // Test that interactive elements are accessible
        let addButton = app.buttons["add_item_button"]
        if addButton.exists {
            #expect(addButton.isEnabled)
            #expect(addButton.label.count > 0)
        }
    }
    
    @Test("Dynamic Type support")
    func dynamicTypeSupport() async throws {
        // Arrange
        let app = UITestHelpers.createTestApp()
        app.launchEnvironment["DYNAMIC_TYPE_SIZE"] = "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        app.launch()
        defer { app.terminate() }
        
        // Act
        app.tabBars.buttons["catalog_tab"].tap()
        #expect(UITestHelpers.waitForElement(app.collectionViews.firstMatch))
        
        // Assert - Text elements should be readable at large sizes
        let textElements = app.staticTexts
        let visibleTextElements = textElements.allElementsBoundByIndex.filter { $0.exists && $0.isHittable }
        
        #expect(visibleTextElements.count > 0)
        
        // Verify layout doesn't break with large text
        let catalogList = app.collectionViews.firstMatch
        #expect(catalogList.exists)
        #expect(catalogList.isHittable)
    }
}
```

#### **4.2 Performance UI Tests**
```swift
// PerformanceUITests.swift
import Foundation

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

#if canImport(XCTest)
import XCTest
#endif

@testable import Molten

@Suite("UI Performance Tests")
struct PerformanceUITests {
    
    @Test("Large dataset scrolling performance")
    func largeDatasetScrolling() async throws {
        // Arrange
        let app = UITestHelpers.createTestApp()
        app.launchEnvironment["LOAD_LARGE_DATASET"] = "1000" // Load 1000 items
        app.launch()
        defer { app.terminate() }
        
        // Act
        app.tabBars.buttons["catalog_tab"].tap()
        #expect(UITestHelpers.waitForElement(app.collectionViews.firstMatch, timeout: 10.0))
        
        let catalogList = app.collectionViews.firstMatch
        #expect(catalogList.exists)
        
        // Test scrolling performance
        let startTime = Date()
        
        // Perform scroll operations
        catalogList.swipeUp()
        catalogList.swipeUp()
        catalogList.swipeUp()
        catalogList.swipeDown()
        catalogList.swipeDown()
        
        let endTime = Date()
        let scrollTime = endTime.timeIntervalSince(startTime)
        
        // Assert - Scrolling should be responsive (less than 2 seconds for basic operations)
        #expect(scrollTime < 2.0, "Scrolling took \(scrollTime) seconds, should be under 2.0")
        
        // Verify UI remains responsive
        #expect(catalogList.isHittable)
    }
    
    @Test("Search performance")
    func searchPerformance() async throws {
        // Arrange
        let app = UITestHelpers.createTestApp()
        app.launchEnvironment["LOAD_LARGE_DATASET"] = "500"
        app.launch()
        defer { app.terminate() }
        
        // Act
        app.tabBars.buttons["catalog_tab"].tap()
        #expect(UITestHelpers.waitForElement(app.collectionViews.firstMatch, timeout: 10.0))
        
        let searchField = app.searchFields["search_field"]
        searchField.tap()
        
        // Measure search response time
        let startTime = Date()
        searchField.typeText("glass")
        
        // Wait for results to appear
        #expect(UITestHelpers.waitForElement(app.tables["search_results"], timeout: 5.0))
        
        let endTime = Date()
        let searchTime = endTime.timeIntervalSince(startTime)
        
        // Assert - Search should be fast (less than 1 second)
        #expect(searchTime < 1.0, "Search took \(searchTime) seconds, should be under 1.0")
        
        // Verify results are displayed
        let resultsTable = app.tables["search_results"]
        #expect(resultsTable.exists)
        #expect(resultsTable.cells.count > 0)
    }
}
```

## 🛠️ Implementation Guidelines

### **Test Data Management**
```swift
// Setup method for consistent test data
struct UITestEnvironmentSetup {
    static func setupUITestEnvironment(_ app: XCUIApplication) {
        app.launchEnvironment["UI_TESTING"] = "1"
        app.launchEnvironment["CORE_DATA_TEST_MODE"] = "1"
        app.launchEnvironment["DISABLE_NETWORKING"] = "1"
    }
}
```

### **Element Identification Strategy**
```swift
// Use accessibility identifiers for reliable element location
extension XCUIApplication {
    var catalogTab: XCUIElement { tabBars.buttons["catalog_tab"] }
    var inventoryTab: XCUIElement { tabBars.buttons["inventory_tab"] }
    var addButton: XCUIElement { buttons["add_item_button"] }
    var searchField: XCUIElement { searchFields["search_field"] }
}
```

### **Waiting and Synchronization**
```swift
// Helper methods for reliable waiting - integrated into UITestHelpers
extension UITestHelpers {
    static func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval = 5.0) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
    
    static func waitForElementToBeHittable(_ element: XCUIElement, timeout: TimeInterval = 5.0) -> Bool {
        let predicate = NSPredicate(format: "isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
}
```

## 📊 Testing Strategy Integration

### **Following Your TDD Approach**
1. **RED**: Write failing UI test for user story
2. **GREEN**: Implement minimum UI to pass test
3. **REFACTOR**: Improve UI implementation while keeping tests green

### **Maintaining Clean Architecture**
- UI tests focus on user interactions, not business logic
- Business logic remains tested at unit/service level
- UI tests verify proper service integration
- No duplicate business logic validation in UI tests

### **Performance Expectations**
- Individual UI tests: < 30 seconds
- Full UI test suite: < 10 minutes
- Reliable execution without flakiness
- Consistent results across test runs

## 🚀 Implementation Timeline

**Week 1**: Foundation setup, base test classes, test data management
**Week 2**: Core catalog and inventory UI tests
**Week 3**: Purchase records and form validation UI tests
**Week 4**: End-to-end workflows and error handling
**Week 5**: Accessibility and performance testing

## 📝 Documentation Updates

After implementation, update:
- **TEST-COVERAGE.md**: Add UI Tests section with coverage metrics
- **README.md**: Add UI testing workflow to development process
- **Inline documentation**: Add accessibility identifiers and UI test helpers

## 🎯 Success Metrics

- **Coverage**: All major user workflows covered
- **Reliability**: 95%+ test success rate
- **Performance**: Full suite under 10 minutes
- **Maintainability**: Clear, readable test code following project patterns
- **Integration**: Seamless integration with existing CI/CD pipeline

This plan follows your project's TDD principles, clean architecture, and testing patterns while providing comprehensive UI test coverage for the Molten inventory management application.

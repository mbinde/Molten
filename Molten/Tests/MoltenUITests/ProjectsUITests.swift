//
//  ProjectPlansUITests.swift
//  MoltenUITests
//
//  UI tests for Project Plans feature to prevent navigation regressions
//

import XCTest

final class ProjectPlansUITests: BaseUITest {

    // MARK: - Navigation Tests

    /// Tests that creating a new plan from the empty state successfully navigates to the detail view
    /// This prevents regression of the bug where navigationDestination was only registered
    /// when the list view was shown (non-empty state)
    func testCreatePlanFromEmptyStateNavigates() throws {
        // Navigate to the Plans tab
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitToExist(timeout: 10), "Tab bar should load")

        // The tab might be "Plans" or "Projects" depending on screen size
        // Try both
        let plansTab = app.buttons["Plans"]
        let projectsTab = app.buttons["Projects"]

        if plansTab.exists {
            plansTab.tapWhenHittable()
        } else if projectsTab.exists {
            projectsTab.tapWhenHittable()
            // If we tapped Projects, we need to select Plans from the menu
            let plansMenuItem = app.buttons["Plans"].firstMatch
            if plansMenuItem.waitToExist(timeout: 2) {
                plansMenuItem.tapWhenHittable()
            }
        } else {
            XCTFail("Could not find Plans or Projects tab")
        }

        // Wait for the Plans navigation title
        waitForNavigationTitle("Plans")

        // Look for the "Create Your First Plan" button (empty state)
        // or the + button (if plans already exist)
        let createFirstPlanButton = app.buttons["Create Your First Plan"]
        let addButton = app.buttons["Add Plan"]

        if createFirstPlanButton.exists {
            // Tap the empty state button using helper
            createFirstPlanButton.tapWhenHittable()
        } else if addButton.exists {
            // Tap the toolbar + button using helper
            addButton.tapWhenHittable()
        } else {
            XCTFail("Could not find Create Plan button")
        }

        // Verify we navigated to the detail view (not a black screen with yellow triangle)
        // The detail view should have a "New Plan" title or editable fields
        let newPlanTitle = app.navigationBars.containing(NSPredicate(format: "identifier CONTAINS 'New Project' OR identifier CONTAINS 'Untitled'")).firstMatch
        let titleField = app.textFields["Enter plan title"]

        // Either the navigation bar or the title field should appear
        // Give it a moment to navigate using our helper
        let titleFieldExists = titleField.waitToExist(timeout: 3)
        let navBarExists = newPlanTitle.waitToExist(timeout: 1)

        XCTAssertTrue(titleFieldExists || navBarExists,
                     "Detail view should appear after tapping create plan button (title field or nav bar should exist)")

        // Additional verification: ensure we're not showing an error state
        // The yellow triangle error would typically show an alert or error message
        let errorAlert = app.alerts.firstMatch
        XCTAssertFalse(errorAlert.exists, "Should not show error alert when creating new project")
    }

    /// Tests that navigation destination is registered even when starting from empty state
    /// This is the specific regression we're guarding against
    func testNavigationDestinationRegisteredInEmptyState() throws {
        // Navigate to Plans tab
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitToExist(timeout: 10), "Tab bar should load")

        let plansTab = app.buttons["Plans"]
        let projectsTab = app.buttons["Projects"]

        if plansTab.exists {
            plansTab.tapWhenHittable()
        } else if projectsTab.exists {
            projectsTab.tapWhenHittable()
            let plansMenuItem = app.buttons["Plans"].firstMatch
            if plansMenuItem.waitToExist(timeout: 2) {
                plansMenuItem.tapWhenHittable()
            }
        }

        // Wait for Plans view using helper
        waitForNavigationTitle("Plans")

        // Tap create button
        let createButton = app.buttons["Create Your First Plan"]
        if createButton.exists {
            createButton.tapWhenHittable()

            // Verify that SOME content appears (not a blank/error screen)
            // A successful navigation should show input fields or content
            let hasContent = app.textFields.count > 0 ||
                           app.textViews.count > 0 ||
                           app.tables.count > 0

            XCTAssertTrue(hasContent, "Detail view should display content after navigation")
        } else {
            // If there are already plans, the test is less relevant
            // but we can still verify the + button works
            let addButton = app.buttons["Add Plan"]
            if addButton.exists {
                addButton.tapWhenHittable()

                let hasContent = app.textFields.count > 0 ||
                               app.textViews.count > 0 ||
                               app.tables.count > 0

                XCTAssertTrue(hasContent, "Detail view should display content after navigation")
            }
        }
    }
}

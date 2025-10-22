//
//  ScreenshotAutomation.swift
//  ScreenshotAutomation
//
//  Automated screenshot generation for marketing and documentation.
//  Captures all key screens with realistic data for website and App Store.
//
//  ENHANCED VERSION:
//  - Better composition and timing
//  - More strategic screenshots
//  - Improved error handling
//  - Waits for content to load
//

import XCTest

final class ScreenshotAutomation: XCTestCase {

    var app: XCUIApplication!
    var screenshotCounter = 0

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()

        // Launch arguments to configure app for screenshots
        app.launchArguments = [
            "-UITestMode", "true",
            "-DemoDataMode", "true",          // Load demo data (EF + DH + GA)
            "-ResetForScreenshots", "true",   // Clear Core Data and generate fresh demo data
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]

        // Reset screenshot counter for each test
        screenshotCounter = 0

        // Force device to portrait orientation
        XCUIDevice.shared.orientation = .portrait

        app.launch()

        // Wait for initial app load and skip onboarding if present
        sleep(3)

        // Try to dismiss any onboarding/welcome screens
        skipOnboardingIfPresent()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Screenshot Generation Tests

    /// Complete screenshot suite for marketing materials
    /// BEST FOR: Website, social media, blog posts
    func testGenerateMarketingScreenshots() throws {
        print("\n📸 MARKETING SCREENSHOTS - Starting...")
        print("═══════════════════════════════════════════════\n")

        // 1. HERO SHOT: Catalog with colorful glass items
        print("1️⃣ Capturing: Catalog Browse (Hero Shot)")
        waitForContentToLoad()
        takeScreenshot(named: "01-catalog-browse", delay: 0.5)

        // 2. DETAIL VIEW: Show product information richness
        print("2️⃣ Capturing: Glass Item Detail")
        if let detailCell = findVisibleCellWithImage() {
            detailCell.tap()
            waitForContentToLoad(seconds: 1.5)

            // Scroll down a bit to show more info
            app.swipeUp()
            sleep(1)

            takeScreenshot(named: "02-glass-detail", delay: 0.5)

            // Go back to catalog
            navigateBack()
        }

        // 3. SEARCH IN ACTION: Show search functionality
        print("3️⃣ Capturing: Search Functionality")
        if activateSearch() {
            app.textFields.firstMatch.typeText("blue")
            waitForContentToLoad(seconds: 1)
            takeScreenshot(named: "03-catalog-search", delay: 0.5)

            // Clear search
            clearSearch()
        }

        // 3b. SEARCH RESULTS: Show actual search results
        print("3️⃣b Capturing: Search Results")
        if activateSearch() {
            app.textFields.firstMatch.typeText("trans")
            waitForContentToLoad(seconds: 1.5)
            takeScreenshot(named: "03b-search-results", delay: 0.5)
            clearSearch()
        }

        // 4. FILTERS: Show powerful filtering
        print("4️⃣ Capturing: Filter Interface")
        if showFilters() {
            takeScreenshot(named: "04-catalog-filters", delay: 0.5)
            dismissFilters()
        }

        // 5. INVENTORY: Show inventory tracking
        print("5️⃣ Capturing: Inventory Management")
        if navigateToTab("Inventory") {
            waitForContentToLoad()
            takeScreenshot(named: "05-inventory-view", delay: 0.5)

            // 5b. INVENTORY DETAIL: Show detail view with locations and types
            print("5️⃣b Capturing: Inventory Detail View")
            if let inventoryCell = findVisibleCellWithImage() {
                inventoryCell.tap()
                waitForContentToLoad(seconds: 1.5)
                takeScreenshot(named: "05b-inventory-detail", delay: 0.5)
                navigateBack()
            }
        }

        // 6. SHOPPING LIST: Show planning capability
        print("6️⃣ Capturing: Shopping List")
        if navigateToTab("Shopping") {
            waitForContentToLoad()
            takeScreenshot(named: "06-shopping-list", delay: 0.5)
        }

        // 7. PURCHASES: Show purchase tracking
        print("7️⃣ Capturing: Purchase History")
        if navigateToTab("Purchases") {
            waitForContentToLoad()
            takeScreenshot(named: "07-purchases", delay: 0.5)

            // 7b. PURCHASE DETAIL: Show detailed purchase record
            print("7️⃣b Capturing: Purchase Record Detail")
            if let purchaseCell = findVisibleCellWithImage() {
                purchaseCell.tap()
                waitForContentToLoad(seconds: 1.5)
                takeScreenshot(named: "07b-purchase-detail", delay: 0.5)
                navigateBack()
            }
        }

        // 8. PROJECTS: Show project logging
        print("8️⃣ Capturing: Project Log")
        if navigateToProjects(selectingType: "Logs") {
            waitForContentToLoad()
            takeScreenshot(named: "08-project-log", delay: 0.5)
        }

        // 9. Go back to Catalog for additional shots
        print("9️⃣ Capturing: Additional Catalog Views")
        if navigateToTab("Catalog") {
            waitForContentToLoad()

            // 9a. ITEM WITH RICH DATA: Find an item with lots of info
            print("9️⃣a Capturing: Rich Item Detail")
            // Tap on first item (likely has the most data)
            let firstCell = app.tables.cells.element(boundBy: 0)
            if firstCell.exists {
                firstCell.tap()
                waitForContentToLoad(seconds: 1.5)
                takeScreenshot(named: "09a-rich-item-detail", delay: 0.5)
                navigateBack()
            }

            // 9b. CATALOG GRID ZOOMED OUT: Scroll to show variety
            print("9️⃣b Capturing: Catalog Overview")
            waitForContentToLoad()
            takeScreenshot(named: "09b-catalog-overview", delay: 0.5)
        }

        // 10. ADD INVENTORY FLOW: Navigate to add inventory
        print("🔟 Capturing: Add Inventory Flow")
        if navigateToTab("Inventory") {
            waitForContentToLoad()
            // Look for "+" or "Add" button
            if let addButton = findAddButton() {
                addButton.tap()
                waitForContentToLoad(seconds: 1.5)
                takeScreenshot(named: "10-add-inventory-form", delay: 0.5)
                // Dismiss by tapping Cancel or back
                dismissModal()
            }
        }

        // 11. SETTINGS/PREFERENCES
        print("1️⃣1️⃣ Capturing: Settings")
        if navigateToTab("Settings") {
            waitForContentToLoad()
            takeScreenshot(named: "11-settings", delay: 0.5)
        }

        print("\n✅ Marketing screenshots complete!")
        print("═══════════════════════════════════════════════\n")
    }

    /// Screenshots specifically for App Store submission
    /// BEST FOR: App Store listing (follows Apple's guidelines)
    /// Optimized for 6.5" display (iPhone 15 Pro Max) requirements
    func testGenerateAppStoreScreenshots() throws {
        print("\n🍎 APP STORE SCREENSHOTS - Starting...")
        print("═══════════════════════════════════════════════\n")

        // SCREEN 1: Hero/Feature Graphic
        // Show the main value prop - comprehensive glass catalog
        print("1️⃣ App Store: Hero - Glass Catalog")
        waitForContentToLoad()
        takeScreenshot(named: "AppStore-01-Hero-Catalog", delay: 0.5)

        // SCREEN 2: Product Detail
        // Highlight rich product information
        print("2️⃣ App Store: Product Information")
        if let detailCell = findVisibleCellWithImage() {
            detailCell.tap()
            waitForContentToLoad(seconds: 1.5)
            takeScreenshot(named: "AppStore-02-Product-Detail", delay: 0.5)
            navigateBack()
        }

        // SCREEN 3: Search & Discover
        // Show powerful search and filtering
        print("3️⃣ App Store: Search & Filter")
        if activateSearch() {
            app.textFields.firstMatch.typeText("blue")
            waitForContentToLoad()

            // Show some results, then clear and show filters
            clearSearch()
            if showFilters() {
                takeScreenshot(named: "AppStore-03-Search-Filter", delay: 0.5)
                dismissFilters()
            }
        }

        // SCREEN 4: Inventory Tracking
        // Emphasize practical inventory management
        print("4️⃣ App Store: Inventory Tracking")
        if navigateToTab("Inventory") {
            waitForContentToLoad()
            takeScreenshot(named: "AppStore-04-Inventory", delay: 0.5)
        }

        // SCREEN 5: Shopping & Planning
        // Show planning and purchase features
        print("5️⃣ App Store: Planning & Shopping")
        if navigateToTab("Shopping") {
            waitForContentToLoad()
            takeScreenshot(named: "AppStore-05-Shopping", delay: 0.5)
        }

        print("\n✅ App Store screenshots complete!")
        print("═══════════════════════════════════════════════\n")
    }

    /// Dark mode screenshots for showcasing appearance support
    /// RUN SEPARATELY: Configure simulator for dark mode first
    func testGenerateDarkModeScreenshots() throws {
        print("\n🌙 DARK MODE SCREENSHOTS - Starting...")
        print("═══════════════════════════════════════════════\n")
        print("⚠️  Make sure simulator is in Dark Mode!")
        print("   Settings > Display & Brightness > Dark\n")

        // Catalog in dark mode
        print("1️⃣ Dark Mode: Catalog")
        waitForContentToLoad()
        takeScreenshot(named: "Dark-01-Catalog", delay: 0.5)

        // Detail view in dark mode
        print("2️⃣ Dark Mode: Detail View")
        if let detailCell = findVisibleCellWithImage() {
            detailCell.tap()
            waitForContentToLoad(seconds: 1.5)
            takeScreenshot(named: "Dark-02-Detail", delay: 0.5)
            navigateBack()
        }

        // Inventory in dark mode
        print("3️⃣ Dark Mode: Inventory")
        if navigateToTab("Inventory") {
            waitForContentToLoad()
            takeScreenshot(named: "Dark-03-Inventory", delay: 0.5)
        }

        // Shopping list in dark mode
        print("4️⃣ Dark Mode: Shopping")
        if navigateToTab("Shopping") {
            waitForContentToLoad()
            takeScreenshot(named: "Dark-04-Shopping", delay: 0.5)
        }

        print("\n✅ Dark mode screenshots complete!")
        print("═══════════════════════════════════════════════\n")
    }

    // MARK: - Navigation Helpers

    /// Navigate to a specific tab
    @discardableResult
    private func navigateToTab(_ tabName: String) -> Bool {
        // Custom tab bar uses regular buttons, not TabView
        // Try both tabBars.buttons and regular buttons
        let tabButton = app.tabBars.buttons[tabName]
        let regularButton = app.buttons[tabName]

        if tabButton.exists {
            tabButton.tap()
            sleep(1)
            return true
        } else if waitForElement(regularButton, timeout: 3) {
            regularButton.tap()
            sleep(1)
            return true
        }

        print("   ⚠️  Tab '\(tabName)' not found")
        return false
    }

    /// Navigate to Projects tab and select a project type (Plans or Logs)
    /// The Projects tab in compact mode shows a menu instead of direct navigation
    @discardableResult
    private func navigateToProjects(selectingType projectType: String) -> Bool {
        // First, tap the Projects tab button
        let projectsButton = app.buttons["Projects"]
        if !projectsButton.exists {
            print("   ⚠️  Projects tab button not found")
            return false
        }

        projectsButton.tap()
        sleep(1)

        // Wait for the menu to appear (it's shown as a sheet)
        // Look for the project type button in the menu
        let projectTypeButton = app.buttons[projectType]
        if waitForElement(projectTypeButton, timeout: 3) {
            projectTypeButton.tap()
            sleep(1)
            return true
        }

        // If the menu didn't appear, maybe we're already on Projects
        // Try to find the project type directly
        if app.navigationBars[projectType].exists {
            // Already on the correct project type
            return true
        }

        print("   ⚠️  Projects menu or project type '\(projectType)' not found")
        return false
    }

    /// Navigate back using navigation bar
    @discardableResult
    private func navigateBack() -> Bool {
        let backButton = app.navigationBars.buttons.firstMatch
        if backButton.exists {
            backButton.tap()
            sleep(1)
            return true
        }
        return false
    }

    /// Activate search field
    @discardableResult
    private func activateSearch() -> Bool {
        // Try multiple approaches to find the search field

        // Approach 1: Standard search fields
        let searchField = app.searchFields.firstMatch
        if searchField.exists {
            searchField.tap()
            sleep(1)
            return true
        }

        // Approach 2: Text fields (the search bar uses TextField, not SearchField)
        let textFields = app.textFields
        if textFields.count > 0 {
            textFields.firstMatch.tap()
            sleep(1)
            return true
        }

        // Approach 3: Text field by placeholder
        let searchByPlaceholder = app.textFields["Search colors, codes, manufacturers..."]
        if searchByPlaceholder.exists {
            searchByPlaceholder.tap()
            sleep(1)
            return true
        }

        print("   ⚠️  Search field not found (tried searchFields, textFields, and placeholder)")
        return false
    }

    /// Clear search field
    private func clearSearch() {
        // IMPORTANT: Dismiss keyboard first so clear button is visible
        // Tap anywhere outside the search field to dismiss keyboard
        let textFields = app.textFields
        if textFields.count > 0 {
            // Tap the return key if available
            if app.keyboards.buttons["Return"].exists {
                app.keyboards.buttons["Return"].tap()
                usleep(500_000) // 0.5 seconds
            } else if app.keyboards.buttons["return"].exists {
                app.keyboards.buttons["return"].tap()
                usleep(500_000) // 0.5 seconds
            } else {
                // Swipe down to dismiss keyboard
                app.swipeDown()
                usleep(500_000) // 0.5 seconds
            }
        }

        // Now try to clear the search text

        // Approach 1: Standard "Clear text" button
        if app.buttons["Clear text"].exists {
            app.buttons["Clear text"].tap()
            sleep(1)
            return
        }

        // Approach 2: Find X button by icon
        let clearButtons = app.buttons.matching(identifier: "xmark.circle.fill")
        if clearButtons.count > 0 {
            clearButtons.firstMatch.tap()
            sleep(1)
            return
        }

        // Approach 3: Cancel button
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.exists {
            cancelButton.tap()
            sleep(1)
            return
        }

        // Approach 4: Tap the text field and delete all text
        if textFields.count > 0 {
            let textField = textFields.firstMatch
            textField.tap()
            usleep(500_000) // 0.5 seconds
            textField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 50))
            sleep(1)
            return
        }
    }

    /// Show filter interface
    @discardableResult
    private func showFilters() -> Bool {
        // The app uses a collapsible filter header instead of a single filter button
        // Try to find and tap the "Filters" button to expand the filter section

        // Try to find "Filters" text (the header button)
        let filtersButton = app.buttons["Filters"]
        if filtersButton.exists {
            filtersButton.tap()
            sleep(1)
            return true
        }

        // Try to find manufacturer filter button (shows as "Mfr")
        let mfrButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'Mfr'")).firstMatch
        if mfrButton.exists {
            mfrButton.tap()
            sleep(1)
            return true
        }

        // Try to find COE filter button
        let coeButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'COE'")).firstMatch
        if coeButton.exists {
            coeButton.tap()
            sleep(1)
            return true
        }

        // Try to find Tags filter button
        let tagsButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'Tags'")).firstMatch
        if tagsButton.exists {
            tagsButton.tap()
            sleep(1)
            return true
        }

        print("   ⚠️  Filter buttons not found (tried Filters, Mfr, COE, Tags)")
        return false
    }

    /// Dismiss filter interface
    private func dismissFilters() {
        // Try multiple ways to dismiss
        if app.buttons["Done"].exists {
            app.buttons["Done"].tap()
        } else if app.buttons["Close"].exists {
            app.buttons["Close"].tap()
        } else if app.buttons["Cancel"].exists {
            app.buttons["Cancel"].tap()
        } else {
            // Swipe down to dismiss sheet
            app.swipeDown()
        }
        sleep(1)
    }

    /// Skip onboarding/welcome screens if present
    private func skipOnboardingIfPresent() {
        // Look for common onboarding elements
        if app.buttons["Continue"].exists {
            app.buttons["Continue"].tap()
            sleep(1)
        }

        if app.buttons["Skip"].exists {
            app.buttons["Skip"].tap()
            sleep(1)
        }

        if app.buttons["Get Started"].exists {
            app.buttons["Get Started"].tap()
            sleep(1)
        }
    }

    /// Find a visible table cell that likely has an image
    /// Returns the first cell that appears to have content
    private func findVisibleCellWithImage() -> XCUIElement? {
        let cells = app.tables.cells

        // Try to find a cell that's not the first one (often more interesting)
        if cells.count > 3 {
            // Return 2nd or 3rd cell for variety
            return cells.element(boundBy: 2)
        } else if cells.count > 0 {
            return cells.firstMatch
        }

        return nil
    }

    /// Find the Add button (+ or "Add" text)
    private func findAddButton() -> XCUIElement? {
        // Try navigation bar first
        if app.navigationBars.buttons["+"].exists {
            return app.navigationBars.buttons["+"]
        }
        if app.navigationBars.buttons["Add"].exists {
            return app.navigationBars.buttons["Add"]
        }

        // Try toolbar
        if app.toolbars.buttons["+"].exists {
            return app.toolbars.buttons["+"]
        }
        if app.toolbars.buttons["Add"].exists {
            return app.toolbars.buttons["Add"]
        }

        return nil
    }

    /// Dismiss modal by tapping Cancel, Close, or swiping down
    private func dismissModal() {
        if app.buttons["Cancel"].exists {
            app.buttons["Cancel"].tap()
            sleep(1)
        } else if app.buttons["Close"].exists {
            app.buttons["Close"].tap()
            sleep(1)
        } else {
            // Try swiping down to dismiss
            app.swipeDown()
            sleep(1)
        }
    }

    // MARK: - Timing & Wait Helpers

    /// Wait for content to load (scroll indicators to disappear, etc.)
    private func waitForContentToLoad(seconds: TimeInterval = 1.5) {
        sleep(UInt32(seconds))

        // Additional wait if there's a loading indicator
        let loadingIndicator = app.activityIndicators.firstMatch
        if loadingIndicator.exists {
            _ = loadingIndicator.waitForExistence(timeout: 5)
        }
    }

    /// Wait for element to appear
    @discardableResult
    private func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }

    // MARK: - Screenshot Helpers

    /// Takes a screenshot with a descriptive name and optional delay
    private func takeScreenshot(named name: String, delay: TimeInterval = 0) {
        // Optional delay for polish (let animations settle)
        if delay > 0 {
            usleep(useconds_t(delay * 1_000_000))
        }

        screenshotCounter += 1
        let screenshot = XCUIScreen.main.screenshot()

        // WORKAROUND: Save directly to Screenshots directory
        // XCTest attachments aren't being saved to .xcresult in iOS 26/Xcode 17
        let screenshotsPath = "/Users/binde/Library/Mobile Documents/com~apple~CloudDocs/Molten/Screenshots"
        let fileName = "\(name).png"
        let fileURL = URL(fileURLWithPath: screenshotsPath).appendingPathComponent(fileName)

        do {
            try screenshot.pngRepresentation.write(to: fileURL)
            print("   📸 Screenshot saved: \(fileName)")
        } catch {
            print("   ❌ Failed to save \(fileName): \(error)")
        }

        // Also attach to test results (for Xcode viewing)
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

// MARK: - Screenshot Configuration Extension

extension XCUIApplication {
    /// Configure app launch for screenshot generation
    func configureForScreenshots() {
        launchArguments += [
            "-UITestMode", "true",
            "-MockData", "true",
            "-AnimationsDisabled", "false", // Keep animations for natural look
            "-ResetOnboarding", "true"
        ]
    }
}

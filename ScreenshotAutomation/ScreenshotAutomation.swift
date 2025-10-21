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
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]

        // Reset screenshot counter for each test
        screenshotCounter = 0

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
            app.searchFields.firstMatch.typeText("blue")
            waitForContentToLoad(seconds: 1)
            takeScreenshot(named: "03-catalog-search", delay: 0.5)

            // Clear search
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
        }

        // 8. PROJECTS: Show project logging
        print("8️⃣ Capturing: Project Log")
        if navigateToTab("Projects") {
            waitForContentToLoad()
            takeScreenshot(named: "08-project-log", delay: 0.5)
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
            app.searchFields.firstMatch.typeText("blue")
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
        let tab = app.tabBars.buttons[tabName]
        if waitForElement(tab, timeout: 3) {
            tab.tap()
            sleep(1)
            return true
        }
        print("   ⚠️  Tab '\(tabName)' not found")
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
        let searchField = app.searchFields.firstMatch
        if waitForElement(searchField, timeout: 3) {
            searchField.tap()
            sleep(1)
            return true
        }
        print("   ⚠️  Search field not found")
        return false
    }

    /// Clear search field
    private func clearSearch() {
        if app.buttons["Clear text"].exists {
            app.buttons["Clear text"].tap()
            sleep(1)
        } else {
            // Alternative: tap X button or cancel
            let cancelButton = app.buttons["Cancel"]
            if cancelButton.exists {
                cancelButton.tap()
                sleep(1)
            }
        }
    }

    /// Show filter interface
    @discardableResult
    private func showFilters() -> Bool {
        // Try multiple possible filter button identifiers
        let possibleIdentifiers = ["Filter", "filter", "Filters", "filterButton"]

        for identifier in possibleIdentifiers {
            let filterButton = app.navigationBars.buttons.matching(identifier: identifier).firstMatch
            if filterButton.exists {
                filterButton.tap()
                sleep(1)
                return true
            }
        }

        // Also try toolbar buttons
        let toolbarFilter = app.toolbars.buttons.matching(identifier: "Filter").firstMatch
        if toolbarFilter.exists {
            toolbarFilter.tap()
            sleep(1)
            return true
        }

        print("   ⚠️  Filter button not found")
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

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = String(format: "%02d-%@", screenshotCounter, name)
        attachment.lifetime = .keepAlways
        add(attachment)

        print("   📸 Screenshot saved: \(attachment.name)")
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

//
//  ScreenshotAutomation.swift
//  ScreenshotAutomation
//
//  Automated screenshot generation for marketing and App Store.
//  Captures key screens with realistic data for website and App Store submission.
//
//  UPDATED VERSION (November 2025):
//  - Based on actual working UI tests
//  - Covers only ENABLED features (per FeatureFlags.swift)
//  - 15 core screenshots + 5 App Store optimized
//  - Better composition and realistic data
//  - Leverages BaseUITest patterns
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
            "UI-Testing",               // Enable UI test mode
            "USE-TEST-DATA",            // Populate known test data (from BaseUITest)
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]

        // Reset screenshot counter for each test
        screenshotCounter = 0

        // Force device to portrait orientation
        XCUIDevice.shared.orientation = .portrait

        app.launch()

        // Wait for app to be ready (tab bar appears)
        let catalogButton = app.buttons["Catalog"]
        XCTAssertTrue(catalogButton.waitForExistence(timeout: 30),
                      "App should launch and show tab bar within 30 seconds")

        // Additional wait for content to load
        sleep(3)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Main Screenshot Test Suites

    /// Complete screenshot suite for website marketing
    /// Generates 19 screenshots covering all enabled features
    /// BEST FOR: Website, blog posts, social media
    func testGenerateWebsiteScreenshots() throws {
        print("\n📸 WEBSITE SCREENSHOTS - Starting...")
        print("═══════════════════════════════════════════════\n")

        // IMPORTANT: Clear product type filter at the start to show ALL products (not just Coatings)
        ensureOnCatalog()
        clearProductTypeFilter()

        // HERO SHOTS

        // 1. Catalog Browse - Colorful Overview
        print("1️⃣ Hero: Catalog Browse")
        ensureOnCatalog()
        waitForContentToLoad()
        // Scroll down a bit to show variety of items
        app.swipeUp()
        sleep(1)
        takeScreenshot(named: "hero-catalog-browse", subdirectory: "website", delay: 0.5)

        // 2. Glass Detail - Rich Information
        print("2️⃣ Hero: Glass Detail View")
        // Tap on a visually appealing item (3rd item often has good data)
        let cells = app.tables.cells
        if cells.count > 2 {
            cells.element(boundBy: 2).tap()
            waitForContentToLoad(seconds: 2)
            // Scroll to show more specifications
            app.swipeUp()
            sleep(1)
            takeScreenshot(named: "hero-glass-detail", subdirectory: "website", delay: 0.5)
            navigateBack()
        }

        // 2b. Glass Detail with Manufacturer Info (Double Helix)
        print("2️⃣b Glass Detail: Manufacturer Info (Double Helix)")
        ensureOnCatalog()
        // Search for a Double Helix item to ensure we get their beautiful glass
        if activateSearch() {
            app.searchFields.firstMatch.typeText("double helix")
            waitForContentToLoad(seconds: 2)
            // Tap on first Double Helix result
            if app.tables.cells.count > 0 {
                app.tables.cells.firstMatch.tap()
                waitForContentToLoad(seconds: 2)
                // Look for and tap Manufacturer tab if it exists
                if app.buttons["Manufacturer"].exists {
                    app.buttons["Manufacturer"].tap()
                    sleep(1)
                } else if app.buttons["About"].exists {
                    app.buttons["About"].tap()
                    sleep(1)
                } else if app.buttons["Info"].exists {
                    app.buttons["Info"].tap()
                    sleep(1)
                }
                // Take screenshot showing manufacturer info
                takeScreenshot(named: "feature-glass-detail-manufacturer", subdirectory: "website", delay: 0.5)
                navigateBack()
                waitForContentToLoad()
            }
            clearSearch()
        }

        // CORE FEATURES

        // 3. Search & Filter - Powerful Discovery
        print("3️⃣ Feature: Search & Filter")
        ensureOnCatalog()
        if activateSearch() {
            app.searchFields.firstMatch.typeText("black")
            waitForContentToLoad()
            takeScreenshot(named: "feature-search-active", subdirectory: "website", delay: 0.5)
            clearSearch()
        }

        // 4. Catalog Filters - Comprehensive Options
        print("4️⃣ Feature: Catalog Filters")
        ensureOnCatalog()
        // Clear any product type filters to show all products (not just Coatings)
        // Look for and clear any active filter chips
        if app.buttons.matching(identifier: "Coatings").firstMatch.exists {
            app.buttons.matching(identifier: "Coatings").firstMatch.tap()
            sleep(1)
        }
        // Also try tapping "All" or clearing filters
        if app.buttons["All"].exists {
            app.buttons["All"].tap()
            sleep(1)
        }
        // Scroll to top of catalog to ensure we see all content
        app.swipeDown()
        app.swipeDown()
        sleep(1)
        // Tap the Filters header to expand filter section
        if app.buttons["Filters"].exists {
            app.buttons["Filters"].tap()
            sleep(1)
            takeScreenshot(named: "feature-catalog-filters", subdirectory: "website", delay: 0.5)
        } else if showManufacturerFilter() {
            takeScreenshot(named: "feature-catalog-filters", subdirectory: "website", delay: 0.5)
            dismissSheet()
        }

        // 4b. Color/Tag Filter Results
        print("4️⃣b Feature: Color/Tag Filtering")
        ensureOnCatalog()
        // Look for a tag filter (like "Transparent", "Opaque", "Striker")
        // Try common glass tags
        let tagButtons = ["Transparent", "Opaque", "Striker", "Red", "Blue"]
        var foundTag = false
        for tag in tagButtons {
            if app.buttons[tag].exists {
                app.buttons[tag].tap()
                sleep(1)
                waitForContentToLoad()
                takeScreenshot(named: "feature-tag-filter-\(tag.lowercased())", subdirectory: "website", delay: 0.5)
                // Tap again to deselect
                app.buttons[tag].tap()
                usleep(500000)
                foundTag = true
                break
            }
        }
        if !foundTag {
            print("   ⚠️  No tag filter buttons found - skipping tag filter screenshot")
        }

        // 5. Inventory Management - Track Your Stock
        print("5️⃣ Feature: Inventory List")
        navigateToTab("Inventory")
        waitForContentToLoad()
        takeScreenshot(named: "feature-inventory-list", subdirectory: "website", delay: 0.5)

        // 6. Inventory Detail - Complete Tracking
        print("6️⃣ Feature: Inventory Detail")
        // Tap on first inventory item with data
        if cells.count > 0 {
            cells.firstMatch.tap()
            waitForContentToLoad(seconds: 2)
            // Scroll to show locations and types
            app.swipeUp()
            sleep(1)
            takeScreenshot(named: "feature-inventory-detail", subdirectory: "website", delay: 0.5)
            navigateBack()
        }

        // 6b. Inventory Types - Frit, Rods, Sheets
        print("6️⃣b Feature: Inventory Types (Frit, Rods, Sheets)")
        ensureOnInventory()
        waitForContentToLoad()
        // Look for a type filter or segment control to switch between types
        if app.buttons["Frit"].exists {
            app.buttons["Frit"].tap()
            sleep(1)
            takeScreenshot(named: "feature-inventory-types-frit", subdirectory: "website", delay: 0.5)
            // Switch to show rods
            if app.buttons["Rods"].exists {
                app.buttons["Rods"].tap()
                sleep(1)
            }
        } else if app.buttons["Type"].exists {
            // If there's a Type filter button, tap it to show options
            app.buttons["Type"].tap()
            sleep(1)
            takeScreenshot(named: "feature-inventory-types", subdirectory: "website", delay: 0.5)
        } else {
            // Just take a screenshot showing the current inventory with mixed types
            takeScreenshot(named: "feature-inventory-types", subdirectory: "website", delay: 0.5)
        }

        // 7. Add Inventory - Simple Data Entry
        print("7️⃣ Feature: Add Inventory Form")
        ensureOnInventory()
        if let addButton = findAddButton() {
            addButton.tap()
            waitForContentToLoad(seconds: 2)

            // Select a specific glass item: Acid Yellow Crayon (Gaffer)
            // Look for a picker or search field to select the item
            if app.buttons["Select Glass Item"].exists || app.textFields["Glass Item"].exists {
                let itemField = app.buttons["Select Glass Item"].exists ? app.buttons["Select Glass Item"] : app.textFields["Glass Item"]
                itemField.tap()
                sleep(1)
                // Search or select Acid Yellow
                if app.searchFields.firstMatch.exists {
                    app.searchFields.firstMatch.tap()
                    app.searchFields.firstMatch.typeText("acid yellow")
                    sleep(1)
                    // Tap first result
                    if app.tables.cells.count > 0 {
                        app.tables.cells.firstMatch.tap()
                        sleep(1)
                    }
                }
            }

            // Fill quantity as 15
            if app.textFields["Quantity"].exists {
                app.textFields["Quantity"].tap()
                app.textFields["Quantity"].typeText("15")
                usleep(500000)
            }

            // Select "rods" type if there's a type picker
            if app.buttons["Type"].exists || app.buttons["Rods"].exists {
                let typeButton = app.buttons["Rods"].exists ? app.buttons["Rods"] : app.buttons["Type"]
                typeButton.tap()
                usleep(500000)
            }

            // Enter location "Garage, Bin 5"
            if app.textFields["Location"].exists {
                app.textFields["Location"].tap()
                app.textFields["Location"].typeText("Garage, Bin 5")
                usleep(500000)
            }

            // Dismiss keyboard and wait for form to settle
            app.swipeDown()
            sleep(1)

            takeScreenshot(named: "feature-add-inventory", subdirectory: "website", delay: 0.5)
            dismissModal()
        }

        // 8. Shopping List - Smart Planning
        print("8️⃣ Feature: Shopping List")
        navigateToTab("Shopping")
        waitForContentToLoad()
        takeScreenshot(named: "feature-shopping-list", subdirectory: "website", delay: 0.5)

        // 9. Label Printing - Professional Organization
        print("9️⃣ Feature: Label Designer")
        navigateToTab("Inventory")
        waitForContentToLoad()
        // Look for "Print Labels" button (might be in toolbar or menu)
        if app.buttons["Print Labels"].exists {
            app.buttons["Print Labels"].tap()
            waitForContentToLoad(seconds: 2)
            takeScreenshot(named: "feature-label-designer", subdirectory: "website", delay: 0.5)
            dismissModal()
        } else {
            print("   ⚠️  Print Labels button not found - skipping screenshot")
        }

        // 10. Locations - Studio Organization
        print("🔟 Feature: Locations Map")
        navigateToTab("Locations")
        waitForContentToLoad()
        takeScreenshot(named: "feature-locations-map", subdirectory: "website", delay: 0.5)

        // 11. Location Detail
        print("1️⃣1️⃣ Feature: Location Detail")
        // Tap on first location
        if app.tables.cells.count > 0 {
            app.tables.cells.firstMatch.tap()
            waitForContentToLoad(seconds: 2)
            takeScreenshot(named: "feature-location-detail", subdirectory: "website", delay: 0.5)
            navigateBack()
        }

        // 12. Settings - Customization (Top)
        print("1️⃣2️⃣ Feature: Settings (Top)")
        navigateToSettings()
        waitForContentToLoad()
        takeScreenshot(named: "feature-settings-top", subdirectory: "website", delay: 0.5)

        // 12b. Settings - Customization (Bottom)
        print("1️⃣2️⃣b Feature: Settings (Bottom)")
        // Scroll down to show bottom settings
        app.swipeUp()
        usleep(500000)
        app.swipeUp()
        usleep(500000)
        takeScreenshot(named: "feature-settings-bottom", subdirectory: "website", delay: 0.5)

        // 13. Coatings Catalog - Beyond Glass
        print("1️⃣3️⃣ Feature: Coatings Catalog")
        ensureOnCatalog()
        // Look for product type filter or tab
        if app.buttons["Coatings"].exists {
            app.buttons["Coatings"].tap()
            waitForContentToLoad()
            takeScreenshot(named: "feature-coatings-catalog", subdirectory: "website", delay: 0.5)
        } else {
            print("   ⚠️  Coatings tab/filter not found - skipping screenshot")
        }

        // 14. Search Results - Accurate & Fast
        print("1️⃣4️⃣ Feature: Search Results")
        ensureOnCatalog()
        if activateSearch() {
            app.searchFields.firstMatch.typeText("striker")
            waitForContentToLoad(seconds: 1.5)
            takeScreenshot(named: "feature-search-results", subdirectory: "website", delay: 0.5)
            clearSearch()
        }

        // 15. Catalog Grid - Touch-Friendly
        print("1️⃣5️⃣ Feature: Catalog Grid Overview")
        ensureOnCatalog()
        sleep(1) // Give catalog time to load
        // Make sure we're on Glass catalog, not Coatings or other filter
        if app.buttons["Glass"].exists {
            app.buttons["Glass"].tap()
            sleep(1)
        } else if app.buttons["All Products"].exists {
            app.buttons["All Products"].tap()
            sleep(1)
        }
        // Wait for content to load before scrolling
        waitForContentToLoad(seconds: 2)
        // Scroll to top to show variety (scroll within the list, not the whole app)
        if app.tables.firstMatch.exists {
            app.tables.firstMatch.swipeDown()
            usleep(500000)
            app.tables.firstMatch.swipeDown()
            usleep(500000)
        }
        takeScreenshot(named: "feature-catalog-grid", subdirectory: "website", delay: 0.5)

        print("\n✅ Website screenshots complete! (19 total)")
        print("═══════════════════════════════════════════════\n")
    }

    /// Screenshots optimized for App Store submission
    /// Tells a story: Discover → Find → Track → Plan → Polish
    /// BEST FOR: App Store listing (6.7" display requirements)
    func testGenerateAppStoreScreenshots() throws {
        print("\n🍎 APP STORE SCREENSHOTS - Starting...")
        print("═══════════════════════════════════════════════\n")

        // SCREENSHOT 1: HERO - What is this app?
        // "Browse 2,500+ glass products from top manufacturers"
        print("1️⃣ App Store: Hero - Catalog Browse")
        ensureOnCatalog()
        waitForContentToLoad()
        scrollToTop()
        takeScreenshot(named: "AppStore-01-Discover", subdirectory: "appstore", delay: 0.5)

        // SCREENSHOT 2: DISCOVERY - How do I find what I need?
        // "Find exactly what you need with powerful search & filters"
        print("2️⃣ App Store: Search & Filter")
        if activateSearch() {
            app.searchFields.firstMatch.typeText("blue")
            waitForContentToLoad()
            takeScreenshot(named: "AppStore-02-Find", subdirectory: "appstore", delay: 0.5)
            clearSearch()
        }

        // SCREENSHOT 3: MANAGEMENT - How do I organize?
        // "Track your inventory across multiple locations & types"
        print("3️⃣ App Store: Inventory Tracking")
        navigateToTab("Inventory")
        waitForContentToLoad()
        takeScreenshot(named: "AppStore-03-Track", subdirectory: "appstore", delay: 0.5)

        // SCREENSHOT 4: PLANNING - What's the practical value?
        // "Never run out with smart shopping lists & low stock alerts"
        print("4️⃣ App Store: Shopping List")
        navigateToTab("Shopping")
        waitForContentToLoad()
        takeScreenshot(named: "AppStore-04-Plan", subdirectory: "appstore", delay: 0.5)

        // SCREENSHOT 5: POLISH - What makes this professional?
        // "Print professional QR code labels for studio organization"
        print("5️⃣ App Store: Professional Features")
        // Try to show label printing OR detailed inventory view
        navigateToTab("Inventory")
        waitForContentToLoad()
        if app.buttons["Print Labels"].exists {
            app.buttons["Print Labels"].tap()
            waitForContentToLoad(seconds: 2)
            takeScreenshot(named: "AppStore-05-Professional", subdirectory: "appstore", delay: 0.5)
            dismissModal()
        } else if app.tables.cells.count > 0 {
            // Fall back to inventory detail view
            app.tables.cells.firstMatch.tap()
            waitForContentToLoad(seconds: 2)
            app.swipeUp()
            sleep(1)
            takeScreenshot(named: "AppStore-05-Professional", subdirectory: "appstore", delay: 0.5)
            navigateBack()
        }

        print("\n✅ App Store screenshots complete! (5 total)")
        print("═══════════════════════════════════════════════\n")
    }

    /// Dark mode screenshots (run separately with simulator in dark mode)
    /// Limited set - just to show design quality
    /// RUN SEPARATELY: Configure simulator for dark mode first
    func testGenerateDarkModeScreenshots() throws {
        print("\n🌙 DARK MODE SCREENSHOTS - Starting...")
        print("═══════════════════════════════════════════════\n")
        print("⚠️  Make sure simulator is in Dark Mode!")
        print("   Settings > Display & Brightness > Dark\n")

        // Just 2 dark mode screenshots to show support

        // 1. Catalog in dark mode
        print("1️⃣ Dark Mode: Catalog")
        ensureOnCatalog()
        waitForContentToLoad()
        takeScreenshot(named: "Dark-01-Catalog", subdirectory: "dark", delay: 0.5)

        // 2. Inventory in dark mode
        print("2️⃣ Dark Mode: Inventory")
        navigateToTab("Inventory")
        waitForContentToLoad()
        takeScreenshot(named: "Dark-02-Inventory", subdirectory: "dark", delay: 0.5)

        print("\n✅ Dark mode screenshots complete! (2 total)")
        print("═══════════════════════════════════════════════\n")
    }

    // MARK: - Navigation Helpers (Based on BaseUITest patterns)

    /// Ensure we're on the Catalog tab
    private func ensureOnCatalog() {
        let catalogButton = app.buttons["Catalog"]
        if catalogButton.exists && catalogButton.isHittable {
            catalogButton.tap()
            sleep(1)
        }
    }

    /// Ensure we're on the Inventory tab
    private func ensureOnInventory() {
        let inventoryButton = app.buttons["Inventory"]
        if inventoryButton.exists && inventoryButton.isHittable {
            inventoryButton.tap()
            sleep(1)
        }
    }

    /// Navigate to a specific tab
    @discardableResult
    private func navigateToTab(_ tabName: String) -> Bool {
        let tabButton = app.buttons[tabName]
        if tabButton.waitForExistence(timeout: 3) && tabButton.isHittable {
            tabButton.tap()
            sleep(1)
            return true
        }
        print("   ⚠️  Tab '\(tabName)' not found")
        return false
    }

    /// Navigate to Settings (accessed via More menu or direct button)
    private func navigateToSettings() {
        // Try direct Settings button first
        if app.buttons["Settings"].exists && app.buttons["Settings"].isHittable {
            app.buttons["Settings"].tap()
            sleep(1)
            return
        }

        // Settings is in the More menu
        if app.buttons["More"].exists {
            app.buttons["More"].tap()
            sleep(1)
            if app.buttons["Settings"].waitForExistence(timeout: 2) {
                app.buttons["Settings"].tap()
                sleep(1)
            }
        }
    }

    /// Navigate back using navigation bar
    @discardableResult
    private func navigateBack() -> Bool {
        let backButton = app.navigationBars.buttons.firstMatch
        if backButton.exists && backButton.isHittable {
            backButton.tap()
            sleep(1)
            return true
        }
        return false
    }

    /// Activate search field
    @discardableResult
    private func activateSearch() -> Bool {
        // Try searchFields FIRST (this is what the working UI tests use)
        let searchField = app.searchFields.firstMatch
        if searchField.waitForExistence(timeout: 5) {
            // Wait a bit more for it to be hittable
            sleep(1)
            if searchField.isHittable {
                searchField.tap()
                sleep(1)
                return true
            } else {
                print("   ⚠️  Search field exists but not hittable")
            }
        }

        // Try text fields as fallback
        let textField = app.textFields.firstMatch
        if textField.waitForExistence(timeout: 3) && textField.isHittable {
            textField.tap()
            sleep(1)
            return true
        }

        print("   ⚠️  Search field not found")
        return false
    }

    /// Clear search field
    private func clearSearch() {
        // Dismiss keyboard first
        if app.keyboards.buttons["Return"].exists {
            app.keyboards.buttons["Return"].tap()
            usleep(500_000) // 0.5 seconds
        } else if app.keyboards.buttons["return"].exists {
            app.keyboards.buttons["return"].tap()
            usleep(500_000) // 0.5 seconds
        } else {
            app.swipeDown()
            usleep(500_000) // 0.5 seconds
        }

        // Try standard clear button
        if app.buttons["Clear text"].exists {
            app.buttons["Clear text"].tap()
            sleep(1)
            return
        }

        // Try X button
        let clearButtons = app.buttons.matching(identifier: "xmark.circle.fill")
        if clearButtons.count > 0 {
            clearButtons.firstMatch.tap()
            sleep(1)
            return
        }

        // Try Cancel
        if app.buttons["Cancel"].exists {
            app.buttons["Cancel"].tap()
            sleep(1)
        }
    }

    /// Show manufacturer filter
    @discardableResult
    private func showManufacturerFilter() -> Bool {
        // Look for "Mfr" or "Manufacturer" filter button
        let mfrButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'Mfr'")).firstMatch
        if mfrButton.exists {
            mfrButton.tap()
            sleep(1)
            return true
        }

        let manufacturerButton = app.buttons["Manufacturer"]
        if manufacturerButton.exists {
            manufacturerButton.tap()
            sleep(1)
            return true
        }

        return false
    }

    /// Dismiss modal/sheet
    private func dismissModal() {
        if app.buttons["Cancel"].exists {
            app.buttons["Cancel"].tap()
            sleep(1)
        } else if app.buttons["Close"].exists {
            app.buttons["Close"].tap()
            sleep(1)
        } else if app.buttons["Done"].exists {
            app.buttons["Done"].tap()
            sleep(1)
        } else {
            // Swipe down to dismiss
            app.swipeDown()
            sleep(1)
        }
    }

    /// Dismiss sheet
    private func dismissSheet() {
        if app.buttons["Done"].exists {
            app.buttons["Done"].tap()
        } else if app.buttons["Close"].exists {
            app.buttons["Close"].tap()
        } else {
            app.swipeDown()
        }
        sleep(1)
    }

    /// Clear product type filter to show all products (not just Coatings)
    private func clearProductTypeFilter() {
        print("   🔧 Clearing product type filter to show all products...")

        // Look for active "Coatings" filter chip and tap it to clear
        if app.buttons.matching(identifier: "Coatings").firstMatch.exists {
            print("   → Found Coatings filter, tapping to clear...")
            app.buttons.matching(identifier: "Coatings").firstMatch.tap()
            sleep(1)
        }

        // Also check for other product type buttons
        if app.buttons["All"].exists {
            print("   → Tapping 'All' button...")
            app.buttons["All"].tap()
            sleep(1)
        }

        // Scroll to top to refresh view
        app.swipeDown()
        app.swipeDown()
        sleep(1)

        print("   ✓ Product type filter cleared")
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

    /// Scroll to top of list
    private func scrollToTop() {
        // Swipe down multiple times to get to top
        // Status bar tap doesn't work reliably in UI tests
        for _ in 0..<3 {
            app.swipeDown()
            usleep(300_000) // 0.3 seconds between swipes
        }
        sleep(1)
    }

    // MARK: - Timing & Wait Helpers

    /// Wait for content to load
    private func waitForContentToLoad(seconds: TimeInterval = 2.0) {
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
    /// - Parameters:
    ///   - name: Filename (without .png extension)
    ///   - subdirectory: Subdirectory within Screenshots/ (e.g., "website", "appstore", "dark")
    ///   - delay: Optional delay before taking screenshot to let animations settle
    private func takeScreenshot(named name: String, subdirectory: String = "", delay: TimeInterval = 0) {
        // Optional delay for polish (let animations settle)
        if delay > 0 {
            usleep(useconds_t(delay * 1_000_000))
        }

        screenshotCounter += 1
        let screenshot = XCUIScreen.main.screenshot()

        // WORKAROUND: Save directly to Screenshots directory
        // XCTest attachments aren't being saved to .xcresult in iOS 26/Xcode 17
        let baseScreenshotsPath = "/Users/binde/Library/Mobile Documents/com~apple~CloudDocs/Molten/Screenshots"

        // Build full path with optional subdirectory
        var screenshotsPath = baseScreenshotsPath
        if !subdirectory.isEmpty {
            screenshotsPath = "\(baseScreenshotsPath)/\(subdirectory)"

            // Create subdirectory if it doesn't exist
            let subdirURL = URL(fileURLWithPath: screenshotsPath)
            try? FileManager.default.createDirectory(at: subdirURL, withIntermediateDirectories: true, attributes: nil)
        }

        let fileName = "\(name).png"
        let fileURL = URL(fileURLWithPath: screenshotsPath).appendingPathComponent(fileName)

        do {
            try screenshot.pngRepresentation.write(to: fileURL)
            let displayPath = subdirectory.isEmpty ? fileName : "\(subdirectory)/\(fileName)"
            print("   📸 Screenshot saved: \(displayPath)")
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

// MARK: - XCUIElement Extension for Safer Tapping

extension XCUIElement {
    /// Tap only if element is hittable
    func tapWhenHittable() {
        if self.exists && self.isHittable {
            self.tap()
        }
    }

    /// Wait for element to exist
    func waitToExist(timeout: TimeInterval = 5) -> Bool {
        return self.waitForExistence(timeout: timeout)
    }
}

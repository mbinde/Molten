//
//  GlassDetailScreenshots.swift
//  ScreenshotAutomation
//
//  Captures individual glass detail page screenshots for the website.
//  Each glass item gets its own high-quality screenshot.
//

import XCTest

final class GlassDetailScreenshots: XCTestCase {

    var app: XCUIApplication!
    var screenshotCounter = 0

    // MARK: - Glass items to screenshot

    /// List of glass items to capture, with search term and output filename
    private let glassItems: [(searchTerm: String, filename: String)] = [
        ("Blue Flambé", "blue-flambe"),
        ("Maleficent Flake Holographic", "maleficent-flake-holographic"),
        ("AUTUMN: Orange", "autumn-orange-bullseye"),
        ("Atlas 2", "atlas-2"),
        ("Green Petroleum Filigrana", "green-petroleum-filigrana"),
        ("Unicorn Tears", "unicorn-tears"),
        ("Transitional Rose Quartz", "transitional-rose-quartz"),
        ("Black Iridescent Opalescent", "black-iridescent-opalescent-oceanside"),
        ("Yellow (A)", "yellow-a"),
    ]

    // MARK: - Setup

    override func setUpWithError() throws {
        continueAfterFailure = true  // Continue to capture as many as possible

        app = XCUIApplication()

        app.launchArguments = [
            "UI-Testing",
            "USE-TEST-DATA",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]

        screenshotCounter = 0
        XCUIDevice.shared.orientation = .portrait

        app.launch()

        // Wait for app to be ready
        let catalogButton = app.buttons["Catalog"]
        XCTAssertTrue(catalogButton.waitForExistence(timeout: 30),
                      "App should launch and show tab bar within 30 seconds")

        sleep(3)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Test

    /// Capture screenshots of individual glass detail pages
    func testCaptureGlassDetailScreenshots() throws {
        print("\n📸 GLASS DETAIL SCREENSHOTS - Starting...")
        print("═══════════════════════════════════════════════\n")

        var successCount = 0
        var failedItems: [String] = []

        for (index, item) in glassItems.enumerated() {
            print("\(index + 1)/\(glassItems.count) Capturing: \(item.searchTerm)")

            // IMPORTANT: Fully reset to catalog by double-tapping tab
            // This clears any stuck search state from previous iteration
            resetToCatalog()

            // Search for the item
            if activateSearch() {
                let searchField = app.searchFields.firstMatch

                // Try to clear existing text by tapping the clear button (X) in search field
                let clearButton = app.buttons["Clear text"]
                if clearButton.exists && clearButton.isHittable {
                    clearButton.tap()
                    sleep(1)
                } else {
                    // Fallback: try other clear button identifiers
                    let clearButtonAlt = searchField.buttons.firstMatch
                    if clearButtonAlt.exists && clearButtonAlt.isHittable {
                        clearButtonAlt.tap()
                        sleep(1)
                    }
                }

                // Type search term
                searchField.tap()
                sleep(1)
                searchField.typeText(item.searchTerm)
                sleep(2)

                // Check if we got results
                let cells = app.cells
                print("   📊 Found \(cells.count) cells")
                if cells.count > 0 && cells.firstMatch.isHittable {
                    // Tap the first result
                    cells.firstMatch.tap()
                    sleep(2)

                    // Scroll down slightly to show more detail
                    app.swipeUp()
                    sleep(1)

                    // Take the screenshot
                    takeScreenshot(named: item.filename, subdirectory: "glass-details")
                    print("   ✅ Captured: \(item.filename).png")
                    successCount += 1

                    // Navigate back to search results
                    navigateBack()
                    sleep(1)
                } else {
                    print("   ⚠️ No results found for '\(item.searchTerm)'")
                    failedItems.append(item.searchTerm)
                }
            } else {
                print("   ⚠️ Could not activate search")
                failedItems.append(item.searchTerm)
            }
        }

        print("\n═══════════════════════════════════════════════")
        print("✅ Glass detail screenshots complete!")
        print("   Captured: \(successCount)/\(glassItems.count)")
        if !failedItems.isEmpty {
            print("   Failed: \(failedItems.joined(separator: ", "))")
        }
        print("═══════════════════════════════════════════════\n")
    }

    // MARK: - Helpers

    /// Fully reset to catalog by double-tapping the tab
    /// This clears any stuck search/keyboard state
    private func resetToCatalog() {
        let catalogButton = app.buttons["Catalog"]
        if catalogButton.exists && catalogButton.isHittable {
            catalogButton.tap()
            sleep(1)
            catalogButton.tap()
            sleep(1)
        }

        // Dismiss any keyboard that might be showing
        if app.keyboards.element.exists {
            app.swipeDown()
            sleep(1)
        }
    }

    private func ensureOnCatalog() {
        let catalogButton = app.buttons["Catalog"]
        if catalogButton.exists && catalogButton.isHittable {
            catalogButton.tap()
            sleep(1)
        }
    }

    private func activateSearch() -> Bool {
        // Try tapping search field directly
        let searchField = app.searchFields.firstMatch
        if searchField.waitForExistence(timeout: 3) && searchField.isHittable {
            searchField.tap()
            sleep(1)
            return true
        }

        // Try navigation bar search
        if app.navigationBars.searchFields.firstMatch.exists {
            app.navigationBars.searchFields.firstMatch.tap()
            sleep(1)
            return true
        }

        return false
    }

    private func navigateBack() {
        let backButton = app.navigationBars.buttons.firstMatch
        if backButton.exists && backButton.isHittable {
            backButton.tap()
            sleep(1)
        }
    }

    private func takeScreenshot(named name: String, subdirectory: String = "") {
        screenshotCounter += 1
        let screenshot = XCUIScreen.main.screenshot()

        let baseScreenshotsPath = "/Users/binde/Library/Mobile Documents/com~apple~CloudDocs/Molten/Screenshots"

        var screenshotsPath = baseScreenshotsPath
        if !subdirectory.isEmpty {
            screenshotsPath = "\(baseScreenshotsPath)/\(subdirectory)"

            let subdirURL = URL(fileURLWithPath: screenshotsPath)
            try? FileManager.default.createDirectory(at: subdirURL, withIntermediateDirectories: true)
        }

        let filename = "\(name).png"
        let filePath = "\(screenshotsPath)/\(filename)"
        let fileURL = URL(fileURLWithPath: filePath)

        do {
            try screenshot.pngRepresentation.write(to: fileURL)
            print("   📸 Screenshot saved: \(subdirectory)/\(filename)")
        } catch {
            print("   ❌ Failed to save screenshot: \(error.localizedDescription)")
        }
    }
}

# Screenshot Workflow

This directory contains the automated screenshot generation system for Molten's marketing materials and WordPress site.

## Quick Start

Run the complete workflow (generate screenshots → publish to WordPress):

```bash
cd "/Users/binde/Library/Mobile Documents/com~apple~CloudDocs/Molten/Screenshots"
./generate_and_publish.sh
```

## How It Works

### 1. Screenshot Generation (`ScreenshotAutomation/ScreenshotAutomation.swift`)

XCUITest automation that launches the app and captures key screens:
- **Marketing screenshots**: Complete feature showcase (catalog, inventory, purchases, projects, etc.)
- **App Store screenshots**: Optimized for App Store listing requirements
- **Dark mode screenshots**: Showcasing dark mode support

**IMPORTANT - iOS 26/Xcode 17 Workaround**:

XCTest attachments are NOT being saved to .xcresult bundles in iOS 26/Xcode 17. The tests now save screenshots directly to disk:

```swift
// WORKAROUND: Save directly to Screenshots directory
// XCTest attachments aren't being saved to .xcresult in iOS 26/Xcode 17
let screenshotsPath = "/Users/binde/Library/Mobile Documents/com~apple~CloudDocs/Molten/Screenshots"
let fileName = "\(name).png"
let fileURL = URL(fileURLWithPath: screenshotsPath).appendingPathComponent(fileName)

try screenshot.pngRepresentation.write(to: fileURL)
```

This bypasses the .xcresult bundle entirely and saves PNGs directly to the Screenshots directory.

### 2. Publishing (`publish_to_wordpress.py`)

Uploads screenshots to WordPress and updates page content:
- Uploads PNG files to WordPress media library
- Processes markdown files with `**SCREENSHOTS: name1, name2**` placeholders
- Creates image carousels for multiple screenshots
- Updates pages with cache-busting timestamps

## Troubleshooting

### Problem: No screenshots being generated

**Root Cause**: In iOS 26/Xcode 17, XCTest attachments with `.keepAlways` lifetime are not being saved to .xcresult bundles, even though the tests pass.

**Solution**: We now save screenshots directly to disk using `FileManager` instead of relying on XCTest attachments.

**Evidence**:
- Tests show `📸 Screenshot saved: filename.png` output
- But `xcrun xcresulttool` finds 0 attachments in the .xcresult bundle
- Direct file saving bypasses this issue entirely

### Problem: Build errors about `homeDirectoryForCurrentUser`

**Root Cause**: `FileManager.default.homeDirectoryForCurrentUser` is unavailable in iOS (it's macOS-only).

**Solution**: Use hardcoded absolute path:
```swift
let screenshotsPath = "/Users/binde/Library/Mobile Documents/com~apple~CloudDocs/Molten/Screenshots"
```

### Problem: Search field not found / Keyboard covering buttons

**Root Cause**:
1. App uses `TextField` (not `SearchField`) for search
2. Keyboard appears when typing, covering the clear button

**Solution**:
1. Changed from `app.searchFields` to `app.textFields`
2. Dismiss keyboard before tapping clear button:
```swift
if app.keyboards.buttons["Return"].exists {
    app.keyboards.buttons["Return"].tap()
    usleep(500_000) // Wait for keyboard to dismiss
}
```

### Problem: Tab navigation not working

**Root Cause**: App uses custom tab bar (regular `Button` views) instead of standard SwiftUI `TabView`.

**Solution**: Try both approaches:
```swift
let tabButton = app.tabBars.buttons[tabName]  // Standard TabView
let regularButton = app.buttons[tabName]       // Custom tab bar
```

### Problem: Screenshots captured in landscape instead of portrait

**Root Cause**: Simulator defaults to landscape orientation, but the app is designed for portrait mode.

**Solution**: Force portrait orientation in `setUpWithError()`:
```swift
override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()

    // ... launch arguments ...

    // Force device to portrait orientation
    XCUIDevice.shared.orientation = .portrait

    app.launch()
    // ...
}
```

**Verification**: Check screenshot dimensions with `sips -g pixelWidth -g pixelHeight <filename>`. Portrait screenshots should have height > width (e.g., 1320 x 2868).

## Historical Context

**Before iOS 26 / Xcode 17**:
- Screenshots were attached using `XCTAttachment`
- Extracted from .xcresult bundles using `xcrun xcresulttool`
- `extract_screenshots.py` parsed JSON and exported PNGs

**After iOS 26 / Xcode 17**:
- XCTest attachments not being saved to .xcresult bundles
- Tests now save directly to disk (workaround)
- `extract_screenshots.py` is deprecated but kept for reference

**Regression Prevention**: This README documents the issue and solution. The code includes comments explaining the workaround.

## WordPress Result

Screenshots are published to: https://moltenglass.app/screenshots/

**Note**: WordPress.com cache may take 5-10 minutes to update after publishing.

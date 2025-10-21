# Screenshot Automation

Automated screenshot generation for Molten app marketing materials, App Store submissions, and documentation.

## Overview

This test target automatically captures professional screenshots of the Molten app for:
- **Website marketing** (https://moltenglass.app)
- **App Store submissions**
- **Documentation and tutorials**
- **Social media promotion**

## Quick Start

### Method 1: Run the Automation Script (Recommended)

```bash
cd ScreenshotAutomation
./generate_screenshots.sh
```

This will:
1. Build the app for iOS Simulator
2. Run screenshot tests on iPhone 15 Pro
3. Extract screenshots to `Screenshots/` folder
4. Optimize images for web (if ImageMagick installed)

### Method 2: Run Tests in Xcode

1. Open `Molten.xcodeproj`
2. Select `ScreenshotAutomation` scheme
3. Select target device (iPhone 15 Pro recommended)
4. Run tests (⌘U)
5. View screenshots in test results (expand test attachments)

## Screenshot Test Suites

### `testGenerateMarketingScreenshots()`
Complete set of screenshots for website and marketing:
- Catalog browsing view
- Glass item detail view
- Search functionality
- Inventory management
- Shopping list
- Purchase tracking
- Project log
- Filter interface

**Output**: 8 numbered screenshots (`01-catalog-browse.png`, `02-glass-detail.png`, etc.)

### `testGenerateAppStoreScreenshots()`
Curated screenshots following Apple's App Store guidelines:
- Hero shot (main catalog)
- Feature highlights
- Key functionality demos

**Output**: 5 App Store-ready screenshots (`AppStore-01-Hero-Catalog.png`, etc.)

### `testGenerateDarkModeScreenshots()`
Dark mode variants for showcasing appearance support.

**Output**: 3 dark mode screenshots (`Dark-01-catalog.png`, etc.)

## Device Configurations

### Primary Device
- **iPhone 15 Pro** (6.1" display)
- Resolution: 1179 × 2556 @ 3x
- Best for App Store and marketing

### Additional Devices (Optional)
Modify `generate_screenshots.sh` to capture:
- **iPhone SE (3rd gen)** - Smaller screen showcase
- **iPad Pro (12.9")** - Tablet layout showcase

## Output

Screenshots are saved to:
```
Molten/Screenshots/
├── 01-catalog-browse.png
├── 02-glass-detail.png
├── 03-catalog-search.png
├── 04-inventory-view.png
├── 05-shopping-list.png
├── 06-purchases.png
├── 07-project-log.png
├── 08-catalog-filters.png
├── AppStore-01-Hero-Catalog.png
├── AppStore-02-Detail.png
├── AppStore-03-Inventory.png
├── AppStore-04-Shopping.png
└── AppStore-05-Projects.png
```

## Customization

### Adding New Screenshots

Edit `ScreenshotAutomation.swift` and add new navigation/capture steps:

```swift
// Example: Capture settings screen
if app.tabBars.buttons["Settings"].exists {
    app.tabBars.buttons["Settings"].tap()
    sleep(1)
    takeScreenshot(named: "09-settings")
}
```

### Changing Device Appearance

To capture dark mode screenshots:

1. **Via Simulator**:
   - `xcrun simctl ui "iPhone 15 Pro" appearance dark`

2. **Via Script**:
   - Uncomment dark mode device in `generate_screenshots.sh`

### Test Data Setup

The tests use whatever data is already in the simulator. For best results:

1. Run app manually first
2. Add sample glass items
3. Create inventory records
4. Add shopping list items
5. Then run screenshot automation

**OR** add launch arguments to use mock data (requires implementation):

```swift
app.launchArguments = ["-MockData", "true"]
```

## Image Optimization

### Automatic Optimization (via Script)

Install ImageMagick for automatic web optimization:

```bash
brew install imagemagick
```

The script will:
- Resize to max width 1200px
- Compress to 85% quality
- Maintain aspect ratio

### Manual Optimization

Use ImageOptim, TinyPNG, or similar tools to:
- Reduce file size for web
- Convert to WebP for modern browsers
- Generate responsive image sets

## App Store Submission Guidelines

Apple's screenshot requirements (as of 2024):

### Required Sizes
- **6.5" Display** (iPhone 15 Pro Max): 1284 × 2778
- **6.1" Display** (iPhone 15 Pro): 1179 × 2556  ✅ **We generate this**
- **5.5" Display** (iPhone 8 Plus): 1242 × 2208

### Best Practices
- ✅ Show actual app UI (no mockups)
- ✅ Use realistic data
- ✅ Highlight key features
- ✅ Include both light/dark mode
- ❌ No misleading features
- ❌ No device frames (Apple adds these)

## Troubleshooting

### "No screenshots generated"
- Ensure app builds successfully
- Check simulator is booted: `xcrun simctl list | grep Booted`
- Run tests in Xcode to see detailed errors

### "Element not found" errors
- UI test may be too fast - increase `sleep()` delays
- Check element identifiers match current app UI
- Use Xcode's Accessibility Inspector to find correct identifiers

### "Dark mode screenshots look the same"
- Verify simulator appearance: `xcrun simctl ui booted appearance dark`
- App must support dark mode in code

### "Screenshots are low resolution"
- Use @3x device (iPhone 15 Pro, not iPhone SE)
- Don't resize screenshots before optimization

## Tips for Great Screenshots

### Composition
1. **Show real data** - Use actual glass product names and images
2. **Fill the screen** - Avoid empty states when possible
3. **Highlight features** - Show filters applied, search in use, etc.
4. **Tell a story** - Sequence screenshots to show workflow

### Timing
- Let animations complete (increase `sleep` if needed)
- Capture "peak moment" (mid-animation can look blurry)
- Ensure all images/data have loaded

### Polish
- Use visually interesting glass colors (blues, purples, oranges)
- Show variety (different manufacturers, COEs, types)
- Ensure good contrast in dark mode

## Next Steps

After generating screenshots:

1. **Review** in `Screenshots/` folder
2. **Select** best shots for each use case
3. **Website**: Upload to https://moltenglass.app
4. **App Store**: Upload via App Store Connect
5. **Social Media**: Share on Instagram, Twitter, etc.

## Maintenance

Update screenshots when:
- Major UI redesigns
- New features added
- App Store guidelines change
- Seasonal marketing campaigns

Set a reminder to refresh screenshots every 3-6 months!

---

**Created**: October 2025
**Maintained by**: Molten Development Team
**Questions?**: info@moltenglass.app

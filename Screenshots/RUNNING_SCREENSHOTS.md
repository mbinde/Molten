# Running Screenshot Tests

## Quick Start

```bash
# 1. Open Xcode
open /Users/binde/projects/uitests/Molten.xcodeproj

# 2. Select iPhone 15 Pro Max simulator (6.7" display for App Store)
# 3. Select the Screenshots test plan
# 4. Run the test you want:
#    - testGenerateWebsiteScreenshots (15 screenshots)
#    - testGenerateAppStoreScreenshots (5 screenshots)
#    - testGenerateDarkModeScreenshots (2 screenshots - run separately in dark mode)
```

Screenshots will be saved to:
```
/Users/binde/Library/Mobile Documents/com~apple~CloudDocs/Molten/Screenshots/
  ├── website/     (15 screenshots for marketing)
  ├── appstore/    (5 screenshots for App Store submission)
  └── dark/        (2 screenshots showing dark mode)
```

## Test Methods

### 1. `testGenerateWebsiteScreenshots()`
**Purpose:** Complete screenshot suite for website marketing
**Output:** 15 screenshots
**Best For:** Website, blog posts, social media

**Screenshots generated (in `website/` directory):**
1. `hero-catalog-browse.png` - Colorful catalog overview
2. `hero-glass-detail.png` - Rich product detail view
3. `feature-search-active.png` - Active search with query
4. `feature-catalog-filters.png` - Filter interface
5. `feature-inventory-list.png` - Inventory tracking list
6. `feature-inventory-detail.png` - Complete inventory detail
7. `feature-add-inventory.png` - Add inventory form
8. `feature-shopping-list.png` - Shopping list view
9. `feature-label-designer.png` - Label printing interface
10. `feature-locations-map.png` - Locations/stores map
11. `feature-location-detail.png` - Store detail view
12. `feature-settings.png` - Settings/preferences
13. `feature-coatings-catalog.png` - Coatings products
14. `feature-search-results.png` - Search results
15. `feature-catalog-grid.png` - Catalog grid overview

### 2. `testGenerateAppStoreScreenshots()`
**Purpose:** Screenshots optimized for App Store submission
**Output:** 5 screenshots
**Best For:** App Store listing (tells a story)

**Screenshots generated (in `appstore/` directory):**
1. `AppStore-01-Discover.png` - "Browse 2,500+ glass products from top manufacturers"
2. `AppStore-02-Find.png` - "Find exactly what you need with powerful search & filters"
3. `AppStore-03-Track.png` - "Track your inventory across multiple locations & types"
4. `AppStore-04-Plan.png` - "Never run out with smart shopping lists & low stock alerts"
5. `AppStore-05-Professional.png` - "Print professional QR code labels for studio organization"

### 3. `testGenerateDarkModeScreenshots()`
**Purpose:** Show dark mode support
**Output:** 2 screenshots
**Best For:** Features page, design showcase

**IMPORTANT:** Set simulator to Dark Mode FIRST:
1. Open Settings app in simulator
2. Display & Brightness
3. Select Dark
4. Then run this test

**Screenshots generated (in `dark/` directory):**
1. `Dark-01-Catalog.png` - Catalog in dark mode
2. `Dark-02-Inventory.png` - Inventory in dark mode

## Simulator Requirements

### Device
**iPhone 15 Pro Max (6.7" display)**
- Resolution: 1290 x 2796 pixels (portrait)
- This is the largest iPhone display size required by App Store

### Orientation
- Portrait (forced by test code)
- Device will automatically rotate to portrait

### Appearance
- **Light Mode** (default) for Website and App Store screenshots
- **Dark Mode** only for `testGenerateDarkModeScreenshots()`

## Test Data

The tests use `USE-TEST-DATA` launch argument which:
- Populates realistic demo inventory
- Creates shopping list items
- Adds locations and stores
- Uses actual product catalog (Effetre, Double Helix, Gaffer, etc.)

**Data quality:** Should be production-ready, not "test 123" placeholder data.

## Running from Xcode

### Step-by-Step

1. **Open project:**
   ```bash
   open /Users/binde/projects/uitests/Molten.xcodeproj
   ```

2. **Select simulator:**
   - Product → Destination → iPhone 15 Pro Max

3. **Select test plan:**
   - Test Navigator (⌘6)
   - Click "Screenshots" test plan

4. **Run specific test:**
   - Click ▶️ next to the test method name
   - OR: Right-click test → Run "testGenerateWebsiteScreenshots()"

5. **Wait for completion:**
   - Website: ~5-8 minutes (15 screenshots with navigation)
   - App Store: ~3-5 minutes (5 screenshots)
   - Dark Mode: ~2 minutes (2 screenshots)

6. **Check output:**
   - Watch console for `📸 Screenshot saved: filename.png` messages
   - Check iCloud folder for PNG files

## Running from Command Line

### Website Screenshots
```bash
xcodebuild test \
  -project Molten.xcodeproj \
  -scheme Molten \
  -testPlan Screenshots \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro Max' \
  -only-testing:ScreenshotAutomation/ScreenshotAutomation/testGenerateWebsiteScreenshots
```

### App Store Screenshots
```bash
xcodebuild test \
  -project Molten.xcodeproj \
  -scheme Molten \
  -testPlan Screenshots \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro Max' \
  -only-testing:ScreenshotAutomation/ScreenshotAutomation/testGenerateAppStoreScreenshots
```

### Dark Mode Screenshots
**FIRST:** Set simulator to dark mode manually (can't automate this)

```bash
xcodebuild test \
  -project Molten.xcodeproj \
  -scheme Molten \
  -testPlan Screenshots \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro Max' \
  -only-testing:ScreenshotAutomation/ScreenshotAutomation/testGenerateDarkModeScreenshots
```

## Troubleshooting

### Problem: Screenshots are blank or all white
**Solution:** Increase `waitForContentToLoad()` delays in test code. Images might be loading slowly.

### Problem: Screenshots show wrong content
**Solution:** Check that test data is loading. Look for "USE-TEST-DATA" in console output.

### Problem: Test fails immediately
**Solution:** Check that app builds successfully first:
```bash
xcodebuild build -project Molten.xcodeproj -scheme Molten -destination 'platform=iOS Simulator,name=iPhone 15 Pro Max'
```

### Problem: Wrong orientation (landscape instead of portrait)
**Solution:** Test code forces portrait. If screenshots are landscape:
1. Check `XCUIDevice.shared.orientation = .portrait` in setUp
2. Verify device lock rotation is OFF in simulator

### Problem: Can't find screenshots after test runs
**Solution:** Check both locations:
1. iCloud: `/Users/binde/Library/Mobile Documents/com~apple~CloudDocs/Molten/Screenshots/`
2. Local (fallback): `/Users/binde/projects/uitests/Screenshots/`

If iCloud folder doesn't exist, the test will fail to save. Create it first:
```bash
mkdir -p "/Users/binde/Library/Mobile Documents/com~apple~CloudDocs/Molten/Screenshots"
```

### Problem: Screenshots have status bar (shows time/battery)
**Solution:** This is normal for UI tests. If you need clean screenshots:
1. Use Xcode's simulator bezel rendering
2. OR: Crop status bar in post-processing

### Problem: App shows onboarding/welcome screen
**Solution:** Test should skip this automatically with `UI-Testing` launch argument. If not:
- Check MoltenApp.swift for onboarding skip logic
- Add accessibility identifier to skip button
- Update test to tap skip button in setUp

## Post-Processing

### Verify Screenshot Quality

Check each screenshot for:
- ✅ Correct orientation (portrait, 1290 x 2796 px)
- ✅ Clear, focused content
- ✅ Realistic data (not "test 123")
- ✅ No UI glitches (missing images, loading spinners)
- ✅ Good composition (important elements visible)

### Verify with sips command
```bash
sips -g pixelWidth -g pixelHeight "/Users/binde/Library/Mobile Documents/com~apple~CloudDocs/Molten/Screenshots/hero-catalog-browse.png"
```

Expected output:
```
pixelWidth: 1290
pixelHeight: 2796
```

### Rename if Needed

If you want more descriptive names:
```bash
cd "/Users/binde/Library/Mobile Documents/com~apple~CloudDocs/Molten/Screenshots"
mv hero-catalog-browse.png 01-catalog-browse-hero.png
```

## Next Steps

After generating screenshots:

1. **Review all screenshots** - Check quality, composition, data
2. **Select best shots** - Not all screenshots may be perfect
3. **Update config.json** - Map screenshot files to website pages
4. **Generate marketing copy** - Captions for each screenshot
5. **Publish to website** - Run `generate_and_publish.sh`

## App Store Submission

For App Store, you need:
- 5-10 screenshots
- 6.7" display (iPhone 15 Pro Max)
- Portrait orientation
- PNG format

Our 5 App Store screenshots tell a complete story:
1. Discover (what is it)
2. Find (how do I search)
3. Track (organize inventory)
4. Plan (shopping lists)
5. Professional (label printing)

Upload these to App Store Connect in this order.

## Tips for Great Screenshots

1. **Timing matters** - Wait for all images to load before capturing
2. **Data quality** - Use realistic product data, not test data
3. **Composition** - Show enough to be interesting, not so much it's cluttered
4. **Consistency** - Keep similar cropping/framing across screenshots
5. **Story** - Each screenshot should have one clear message
6. **Polish** - Scroll to hide any UI glitches or awkward states

## Common Mistakes to Avoid

❌ **Don't:**
- Show loading spinners or blank states
- Use Lorem Ipsum or "test 123" data
- Include disabled features (Projects, Purchases, etc.)
- Capture during animations or transitions
- Show error messages or alerts

✅ **Do:**
- Wait for content to fully load
- Use realistic glass product data
- Show only enabled features
- Capture stable, final states
- Show clean, polished UI

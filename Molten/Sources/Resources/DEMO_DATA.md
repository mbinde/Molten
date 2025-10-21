# Demo Data System

## Overview

The demo data system **filters** the main glass catalog to show only specific manufacturers for screenshots, documentation, and demonstrations. This ensures consistent, high-quality visuals that **always stay up-to-date** with the latest catalog data.

## How It Works

**No separate file!** Demo mode filters `glassitems.json` on-the-fly when the `-DemoDataMode` launch argument is present.

### Manufacturers Included

The filter includes these manufacturers (configured in `JSONDataLoader.swift`):

1. **Effetre (EF)** - ~275 items
   - COE 104 Italian soft glass
   - Colorful, photogenic rods
   - Full product images available

2. **Double Helix (DH)** - ~80 items
   - COE 104 boro striking colors
   - Highly visual, dramatic color changes
   - Full product images available

3. **Glass Alchemy (GA)** - ~134 items
   - COE 33 boro colors
   - Metallic and specialty effects
   - Full product images available

**Total**: ~489 items (counts vary as catalog updates)

### Why These Manufacturers?

- **Visual Appeal**: All three have vibrant, photogenic products
- **Product Images**: Full permission to use product-specific images
- **Variety**: Mix of soft glass (104) and boro (33 & 104)
- **Always Current**: Uses latest catalog data automatically
- **Manageable Size**: ~489 items loads quickly for testing

## Usage

### In Screenshot Automation

Demo mode is **automatically enabled** in screenshot tests:

```swift
// ScreenshotAutomation.swift
app.launchArguments = [
    "-UITestMode", "true",
    "-DemoDataMode", "true",  // Loads demo-data.json
    "-AppleLanguages", "(en)",
    "-AppleLocale", "en_US"
]
```

### Manual Testing with Demo Data

To test the app with demo data in Xcode:

1. **Edit Scheme** → Run → Arguments
2. **Add Launch Argument**: `-DemoDataMode`
3. **Run the app** - it will load from `demo-data.json`

### In Production

Demo mode is **never enabled** in production builds. The launch argument is only present during:
- Screenshot automation (XCUITest)
- Manual testing (when explicitly added to scheme)

## Updating Demo Data

### Changing Manufacturers

Demo manufacturers are configured in `JSONDataLoader.swift` line ~87:

```swift
// In decodeCatalogItems() method
let demoManufacturers: Set<String> = ["EF", "DH", "GA"]
```

To change which manufacturers appear in demos:

1. **Edit** `JSONDataLoader.swift`
2. **Update the Set** with desired manufacturer codes
3. **Commit** - screenshots will automatically use new data!

### Adding Northstar When Available

When Northstar (NS) gives permission and is scraped:

```swift
// Replace GA with NS in JSONDataLoader.swift
let demoManufacturers: Set<String> = ["EF", "DH", "NS"]  // ← Change here
```

**That's it!** No need to regenerate files - the filter updates automatically.

## Technical Implementation

### Code Flow

1. **App launches** with `-DemoDataMode` argument (screenshot tests do this automatically)
2. **JSONDataLoader** loads full `glassitems.json` from bundle
3. **decodeCatalogItems()** checks for demo mode flag
4. If enabled, **filters** to only include items from demo manufacturers
5. Returns filtered array - rest of app works identically

### File Structure

```
Molten/Sources/Resources/
├── glassitems.json          # Full catalog (2,569 items) - ONLY file needed!
└── DEMO_DATA.md             # This file
```

**No separate demo file!** Filtering happens in-memory.

### Code Location

**JSONDataLoader.swift** line ~82-96:

```swift
// Check for demo data mode (used for screenshots and documentation)
let isDemoMode = ProcessInfo.processInfo.arguments.contains("-DemoDataMode")

if isDemoMode {
    // Filter to only include demo manufacturers (always uses latest data!)
    let demoManufacturers: Set<String> = ["EF", "DH", "GA"]
    let filteredItems = wrapped.glassitems.filter { item in
        if let manufacturer = item.manufacturer {
            return demoManufacturers.contains(manufacturer)
        }
        return false
    }

    debugLog("🎬 Demo Data Mode: Filtered to \(filteredItems.count) items")
    return filteredItems
}
```

## Benefits

✅ **Consistent Screenshots**: Same manufacturers across all marketing materials
✅ **Always Current**: Uses latest catalog data automatically (no stale data!)
✅ **Fast Testing**: ~489 items load quickly vs 2,500+ full catalog
✅ **High Quality**: Only manufacturers with image permissions
✅ **Zero Maintenance**: No separate file to update or regenerate
✅ **Simple Configuration**: Change one line of code to update manufacturers

## Future Enhancements

- [ ] Add sample inventory records for demo items
- [ ] Add sample shopping list entries
- [ ] Add sample purchase records
- [ ] Add sample project log entries
- [ ] Create "demo mode" that pre-populates all app features

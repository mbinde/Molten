# Demo Data System

## Overview

The demo data system provides a curated subset of the glass catalog specifically for screenshots, documentation, and demonstrations. This ensures consistent, high-quality visuals across all marketing materials.

## Demo Dataset

**File**: `demo-data.json` (489 items)

### Manufacturers Included

1. **Effetre (EF)** - 275 items
   - COE 104 Italian soft glass
   - Colorful, photogenic rods
   - Full product images available

2. **Double Helix (DH)** - 80 items
   - COE 104 boro striking colors
   - Highly visual, dramatic color changes
   - Full product images available

3. **Glass Alchemy (GA)** - 134 items
   - COE 33 boro colors
   - Metallic and specialty effects
   - Full product images available

### Why These Manufacturers?

- **Visual Appeal**: All three have vibrant, photogenic products
- **Product Images**: Full permission to use product-specific images
- **Variety**: Mix of soft glass (104) and boro (33 & 104)
- **Real Data**: Actual products with authentic descriptions
- **Manageable Size**: 489 items loads quickly for testing

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

To use different manufacturers for demos:

```bash
cd Molten/Sources/Resources

# Edit the Python script in the creation command to change manufacturers
cat glassitems.json | python3 -c "
import sys, json
from datetime import datetime

data = json.load(sys.stdin)
all_items = data['glassitems']

# Change these manufacturer codes
demo_manufacturers = ['EF', 'DH', 'GA']  # ← Edit this line
demo_items = [item for item in all_items if item.get('manufacturer') in demo_manufacturers]

# Sort and create demo data
demo_items.sort(key=lambda x: (x.get('manufacturer', ''), x.get('name', '')))

demo_data = {
    'version': '1.0-demo',
    'generated': datetime.now().isoformat(),
    'description': 'Demo dataset for screenshots and documentation',
    'manufacturers': {
        'EF': 'Effetre (Italian soft glass, COE 104)',
        'DH': 'Double Helix (Boro strikers, COE 104)',
        'GA': 'Glass Alchemy (Boro colors, COE 33)'
    },
    'item_count': len(demo_items),
    'glassitems': demo_items
}

with open('demo-data.json', 'w') as f:
    json.dump(demo_data, f, indent=2)

print(f'Updated demo-data.json with {len(demo_items)} items')
" && git add demo-data.json && git commit -m "Update demo data manufacturers"
```

### Adding Northstar When Available

When Northstar (NS) gives permission and is scraped:

```python
# Replace GA with NS
demo_manufacturers = ['EF', 'DH', 'NS']  # EF + DH + Northstar
```

## Technical Implementation

### Code Flow

1. **JSONDataLoader** checks for `-DemoDataMode` launch argument
2. If enabled, loads `demo-data.json` instead of `glassitems.json`
3. Falls back to full catalog if demo file not found
4. Rest of app works identically (same data structures)

### File Structure

```
Molten/Sources/Resources/
├── glassitems.json          # Full catalog (2,569 items)
├── demo-data.json           # Demo subset (489 items)
└── DEMO_DATA.md             # This file
```

### Data Format

Both files use identical JSON structure:

```json
{
  "version": "1.0-demo",
  "generated": "2025-10-21T12:27:00",
  "description": "Demo dataset for screenshots and documentation",
  "item_count": 489,
  "glassitems": [
    {
      "manufacturer": "EF",
      "code": "EF-001",
      "name": "Transparent Clear",
      ...
    }
  ]
}
```

## Benefits

✅ **Consistent Screenshots**: Same data across all marketing materials
✅ **Fast Testing**: 489 items load quickly vs 2,500+ full catalog
✅ **High Quality**: Only manufacturers with image permissions
✅ **Easy Updates**: Simple Python script to regenerate
✅ **Version Controlled**: Committed to Git, reproducible

## Future Enhancements

- [ ] Add sample inventory records for demo items
- [ ] Add sample shopping list entries
- [ ] Add sample purchase records
- [ ] Add sample project log entries
- [ ] Create "demo mode" that pre-populates all app features

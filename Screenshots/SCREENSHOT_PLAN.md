# Screenshot Plan for Molten

## Overview

Based on analysis of:
- Existing UI tests (12 test files with working automation)
- Feature flags (what's enabled for launch)
- User workflows from Testing-Workflow-Coverage.md

## What's Enabled for Launch (Per FeatureFlags.swift)

✅ **ENABLED:**
- Glass catalog (core feature)
- Coatings catalog (`ENABLE_COATINGS = true`)
- Inventory tracking (core feature)
- Shopping lists (`ENABLE_SHOPPING_LISTS = true`)
- Data import/export (`ENABLE_DATA_IMPORT/EXPORT = true`)
- Catalog updates (`ENABLE_CATALOG_UPDATES = true`)
- Locations/Stores (core feature)

❌ **DISABLED (skip screenshots):**
- Tools (`ENABLE_TOOLS = false`)
- Projects (`ENABLE_PROJECTS = false`)
- Kiln Schedules (`ENABLE_KILN_SCHEDULES = false`)
- Purchases (`ENABLE_PURCHASES = false`)
- Recipes (`ENABLE_RECIPES = false`)

## Screenshot Categories

### 1. HERO SHOTS (Website homepage, App Store featured)
**Purpose:** Grab attention, show app personality

1. **Catalog Browse - Colorful Overview**
   - Full screen of glass items with vibrant colors
   - Show variety of manufacturers (Effetre, Double Helix, Gaffer)
   - Portrait orientation, well-lit, professional
   - **Used for:** Homepage hero, App Store screenshot #1

2. **Glass Detail - Rich Information**
   - Beautiful product image
   - Complete specifications visible
   - Color swatches, dimensions, pricing
   - Professional presentation
   - **Used for:** Homepage feature section, App Store screenshot #2

### 2. CORE FEATURES (Website features page, App Store)
**Purpose:** Demonstrate key value propositions

3. **Search & Filter - Powerful Discovery**
   - Active search with results
   - Filter chips visible (COE, Manufacturer, Tags)
   - Shows ease of finding specific glass
   - **Used for:** Features page, App Store screenshot #3

4. **Inventory Management - Track Your Stock**
   - Inventory list with quantities and locations
   - Mix of rod/tube/frit types
   - Color-coded status (in stock, low, out)
   - **Used for:** Features page, App Store screenshot #4

5. **Inventory Detail - Complete Tracking**
   - Item with multiple storage locations
   - Different types (rod, tube, frit) with quantities
   - Notes, tags, images
   - **Used for:** Features page

6. **Shopping List - Smart Planning**
   - Items with minimum quantities
   - Low stock warnings
   - Organized by manufacturer or store
   - **Used for:** Features page, App Store screenshot #5

7. **Add Inventory - Simple Data Entry**
   - Clean form UI
   - Type selection (rod/tube/frit)
   - Location picker
   - Quantity input with units
   - **Used for:** Features page

### 3. POLISH & PROFESSIONALISM (Website, builds trust)
**Purpose:** Show attention to detail, modern design

8. **Label Printing - Professional Organization**
   - Label designer interface
   - QR code preview
   - Template selection
   - **Used for:** Features page, unique differentiator

9. **Locations - Studio Organization**
   - Map view of stores/suppliers
   - Store detail with contact info
   - **Used for:** Features page

10. **Settings - Customization**
    - Manufacturer preferences
    - COE filter settings
    - Terminology options (rod/cane, tube/tubing)
    - **Used for:** Features page

### 4. DATA RICHNESS (Website, shows comprehensiveness)
**Purpose:** Prove the catalog is complete and professional

11. **Catalog Filters - Comprehensive Options**
    - Manufacturer filter (show many options)
    - COE options (90, 96, 104)
    - Tag cloud (transparent, opaque, striker, etc.)
    - **Used for:** Features page

12. **Search Results - Accurate & Fast**
    - Search for "transparent blue"
    - Show relevant results
    - Highlighting/sorting visible
    - **Used for:** Features page

13. **Coatings Catalog - Beyond Glass**
    - Show coating products (silver, gold, luster)
    - Demonstrates breadth of catalog
    - **Used for:** Features page

### 5. MOBILE-OPTIMIZED (App Store, proves mobile-first)
**Purpose:** Show it's built for mobile, not desktop-shrunk

14. **Catalog Grid - Touch-Friendly**
    - Large touch targets
    - Scrollable grid
    - Visible product images
    - **Used for:** App Store

15. **Quick Add Inventory - Mobile Workflow**
    - Optimized for one-handed use
    - Large buttons
    - Minimal typing required
    - **Used for:** App Store

## Screenshot Specifications

### Technical Requirements

**Resolution (iPhone 15 Pro Max - 6.7" display):**
- 1290 x 2796 pixels (portrait)
- Or 2796 x 1290 pixels (landscape, if needed)

**Format:**
- PNG (lossless)
- sRGB color space
- No transparency

**Orientation:**
- **Primary:** Portrait (catalog, inventory, shopping)
- **Optional:** Landscape (label designer, charts)

### Photography Guidelines

1. **Lighting:** Use simulator in light mode (better contrast for web)
2. **Status Bar:** Hide if possible, or use clean time (9:41 AM)
3. **Data:** Use realistic demo data (not Lorem Ipsum)
4. **Focus:** One clear message per screenshot
5. **Composition:** Follow rule of thirds when possible

### Dark Mode Strategy

**Limited dark mode screenshots:**
- 1-2 screenshots showing dark mode support
- Not primary marketing materials
- Used in "Features" section to show design quality

## App Store Specific Requirements

Apple requires 3-10 screenshots for each device size. We'll provide 5 screenshots optimized for storytelling:

**Screenshot Order (tells a story):**
1. **Hero:** Colorful catalog browse (shows what app is)
2. **Discovery:** Search & filter (shows how to find)
3. **Management:** Inventory tracking (shows organization)
4. **Planning:** Shopping list (shows practical value)
5. **Professional:** Label printing or data richness (shows polish)

**Captions for Each Screenshot:**
1. "Browse 2,500+ glass products from top manufacturers"
2. "Find exactly what you need with powerful search & filters"
3. "Track your inventory across multiple locations & types"
4. "Never run out with smart shopping lists & low stock alerts"
5. "Print professional QR code labels for studio organization"

## Website Specific Strategy

**Homepage:**
- 1 hero shot (catalog browse)
- 2-3 feature callouts (detail, inventory, shopping)

**Features Page:**
- All 15 screenshots organized by category
- Before/after comparisons if applicable
- Animated GIFs for key interactions (optional)

**Getting Started Page:**
- Tutorial-style screenshots with annotations
- Step-by-step workflow screenshots

## Implementation Plan

### Phase 1: Update Screenshot Automation
- Rewrite `ScreenshotAutomation.swift` based on this plan
- Use existing UI test helpers (we have working tests!)
- Focus on enabled features only
- Generate 15 core screenshots

### Phase 2: Generate & Review
- Run tests with portrait orientation
- Review screenshots for quality
- Retake any with timing issues or bad composition

### Phase 3: Organize & Tag
- Rename with descriptive names
- Create website vs App Store sets
- Update `config.json` mappings

### Phase 4: Optional - Dark Mode & Landscape
- Generate dark mode variants (2-3 screenshots)
- Generate landscape variants for label designer
- Use sparingly, not for primary marketing

## Success Criteria

✅ **Good screenshot has:**
- Clear, focused message
- Realistic data (not test gibberish)
- Professional composition
- Correct orientation and resolution
- No UI glitches or timing issues

❌ **Bad screenshot has:**
- Cluttered or confusing layout
- Lorem ipsum or "test 123" data
- Awkward cropping
- Loading spinners or blank states
- Disabled features visible

## Next Steps

1. Update `ScreenshotAutomation.swift` with new test methods
2. Add helper methods for:
   - Waiting for images to load
   - Scrolling to interesting content
   - Selecting items with good visual appeal
3. Run tests and generate screenshots
4. Review and curate best shots
5. Update website content files with screenshot references

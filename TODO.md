# Flameworker TODO List

## Current Tasks

### Fix Location System
- **Issue**: Locations not working properly, autocomplete broken
- **Tasks**:
  - Investigate location storage and retrieval
  - Fix autocomplete functionality for location input
  - Ensure locations persist correctly in Core Data
  - Test location assignment and filtering

---

## Future Features

## Home/Landing Page Feature

### Overview
Create a personalized home screen that shows the user's most recent activity across all sections of the app, similar to Ravelry's approach. This would replace or supplement the current tab-based navigation with a more engaging entry point.

### Core Features

**Recent Activity Sections:**
1. Recently Added Inventory Items
2. Recent Shopping List Items
3. Recent Projects
4. Recent Logbook Entries

**Customization:**
- User can reorder sections in Settings
- User can show/hide sections based on preferences
- Sections automatically populate as user adds content

**Future Enhancement - "What's Hot":**
- Track most-viewed/interacted glass items
- Show trending items in the catalog
- Based on user's own interaction patterns

### First-Run Experience Options

**Critical Question:** What to show when user hasn't used the app yet?

**Option 1: Guided Onboarding Cards**
- Series of actionable cards with illustrations
- "Browse the Glass Catalog" → Catalog tab
- "Add Items to Inventory" → Add Inventory flow
- "Create Your First Project" → New project form
- "Start a Shopping List" → Shopping list view
- Cards can be dismissed as user completes actions

**Option 2: Welcome Wizard**
- Multi-step walkthrough on first launch
- "What brings you to Molten?" with use-case options:
  - "I'm a hobbyist tracking my glass"
  - "I'm a professional managing inventory"
  - "I want to plan projects"
- Based on selection, pre-populate home screen sections in priority order
- Show example/template content they can explore

**Option 3: Smart Empty States**
- Home screen shows all sections with rich empty states
- Each section includes:
  - Descriptive text explaining purpose
  - Call-to-action button to add first item
  - Preview/example of populated state
- Sections automatically populate as content is added

**Option 4: Hybrid Approach (Recommended)**
- First launch: Show alpha disclaimer (already implemented ✓)
- After disclaimer: Brief welcome screen with:
  - "Welcome to Molten!" header
  - 3-4 quick suggestion cards:
    - "Explore the Glass Catalog" (passive, easy first step)
    - "Add Your First Inventory Item"
    - "Browse Project Ideas"
  - "Skip Tour" button → empty home screen
- Home screen with empty states for each section
- Content appears in "Recently Added" as user interacts

**Key Onboarding Principles:**
1. **Don't overwhelm** - Avoid decision paralysis with too many options
2. **Highlight catalog first** - Pre-populated content shows immediate value
3. **Progressive disclosure** - Show features as they become relevant
4. **Allow skipping** - Power users don't want excessive handholding

### Implementation Considerations
- Need to track "recent" items with timestamps
- Consider caching strategy for performance
- Section order stored in UserDefaults or app settings
- Analytics to track which sections users engage with most

### Benefits
- Faster access to recently worked-on items
- More engaging first screen experience
- Reduces navigation clicks for common tasks
- Personalizes app based on user behavior
- Mirrors familiar UX pattern from Ravelry

---

## CSV/Spreadsheet Inventory Import

### Overview
Allow users to import inventory from CSV files or spreadsheets (Google Sheets, Excel). Manual data entry is tedious on mobile, but file import workflows are rare in iOS apps - this would be a significant UX advantage.

### Implementation Phases

**Phase 1 (MVP):**

1. **Document Picker Integration**
   - Use SwiftUI `fileImporter` for native iOS file selection
   - Support .csv files initially
   - Access files from iCloud Drive, Google Drive, etc.
   - Show "Import Inventory" in Settings or Inventory view

2. **CSV Parser**
   - Parse comma/tab-delimited data
   - Handle quoted fields and escaped characters
   - Validate data types and required fields

3. **Preview & Validation UI**
   - Show parsed data in grid/table before importing
   - Highlight potential issues (missing data, invalid formats)
   - Allow user to review before committing

4. **Clipboard Import (Quick Win)**
   - "Import from Clipboard" option
   - Parse copied spreadsheet data directly
   - Great for small datasets
   - Simpler workflow for testing

**Phase 2 (Enhanced):**

5. **Field Mapping UI**
   - Auto-detect common column headers:
     - "Manufacturer", "SKU", "Color", "Quantity", "Location", etc.
   - Manual mapping for non-standard columns
   - Save user's mapping preferences for future imports
   - Preview how fields will map to inventory records

6. **Template Download**
   - Provide downloadable CSV template
   - Pre-formatted with correct headers and example data
   - Reduces import errors and user confusion
   - Could be hosted on moltenglass.app or bundled in app

**Phase 3 (Advanced):**

7. **QR Code Web Tool**
   - Web tool at moltenglass.app/import
   - Upload CSV on desktop browser
   - Generate temporary QR code or deep link
   - Scan with iPhone → auto-imports data
   - Bridges desktop/mobile workflow gap

8. **Excel (.xlsx) Support**
   - Parse Excel files directly if CSV proves limiting
   - Handle multiple sheets (could separate by inventory type?)

### Critical Data Quality Challenges

**Challenge 1: Glass Item Identification**

Problem: Accurately matching imported data to catalog items
- User might write "Bullseye Clear" vs "BE Clear" vs "Clear 001"
- SKU formats vary: "1101" vs "BE-1101" vs "Bullseye 1101"
- Color names are inconsistent across users
- Manufacturer abbreviations differ

**Potential Solutions:**
- **Fuzzy Matching Algorithm**
  - Match on multiple fields (manufacturer + SKU + color)
  - Use string similarity (Levenshtein distance) for close matches
  - Confidence scoring: exact match > fuzzy match > no match

- **Import Matching UI**
  - Show side-by-side: imported row vs. suggested catalog match
  - Confidence indicator (green/yellow/red)
  - User confirms or corrects each uncertain match
  - Option to "create new catalog item" if no match found

- **Standardization Preprocessing**
  - Normalize manufacturer names before matching
  - Strip common prefixes/suffixes
  - Handle COE variations (96 vs COE96 vs 96COE)

- **Smart Suggestions**
  - Show top 3 possible matches with % confidence
  - Learn from user corrections
  - Build mapping table: user's format → catalog natural key

**Challenge 2: Duplicate Detection**

Problem: User might upload duplicate inventory entries
- Import same CSV twice accidentally
- Partial overlaps (some items already exist)
- Different data for same glass item (quantity conflicts)

**Potential Solutions:**
- **Pre-Import Duplicate Check**
  - Before importing, scan for items that already exist
  - Match on: manufacturer + SKU + location + type
  - Show summary: "Found 15 potential duplicates"

- **Duplicate Resolution UI**
  - Show existing vs. imported record side-by-side
  - Resolution options per conflict:
    - Skip (don't import duplicate)
    - Replace (overwrite existing with imported data)
    - Merge (add quantities together)
    - Keep Both (create separate inventory entries)
  - Batch actions: "Skip all duplicates" or "Merge all"

- **Smart Quantity Handling**
  - If same item exists, ask: "Add to existing quantity or replace?"
  - Track import history (when/what was imported)
  - Show warning if quantity seems suspiciously high after merge

- **Dry Run Mode**
  - "Preview Import" that doesn't commit
  - Shows what would happen without changing database
  - User reviews and approves before actual import

**Challenge 3: Data Validation**

Additional issues to handle:
- Invalid manufacturer codes
- Malformed SKUs
- Negative quantities
- Unknown locations
- Invalid inventory types (rod/tube/frit/etc.)
- Missing required fields

**Validation Strategy:**
- Row-by-row validation with clear error messages
- Allow partial imports (skip invalid rows, import valid ones)
- Export validation report (which rows failed and why)
- Suggest corrections where possible

### UX Flow (Recommended)

1. User taps "Import Inventory" → File picker
2. Select CSV → Parse and validate
3. **Field Mapping Screen** (if headers don't match exactly)
4. **Match Review Screen** (uncertain catalog matches)
5. **Duplicate Detection Screen** (if conflicts found)
6. **Final Preview** (summary of what will import)
7. Confirm → Import with progress indicator
8. **Import Report** (success/failures/warnings)

### Technical Considerations

- Use background thread for parsing large files
- Progress indicator for long imports
- Transaction/rollback if import fails partway
- Limit file size (e.g., max 10,000 rows?)
- CSV encoding detection (UTF-8, UTF-16, etc.)
- Handle BOM (Byte Order Mark) if present

### Success Metrics

- % of rows successfully imported
- Time from file selection to completion
- User satisfaction with matching accuracy
- Duplicate detection effectiveness

---

## Label Printing with QR Code Integration

### Overview
Generate printable labels for glass inventory with QR codes that link directly to items in Molten. Scan a label with your iPhone camera → instantly opens that exact glass item in the app!

**Killer Feature:** Physical labels bridge the gap between your studio and your digital inventory.

### Core Concept

**Label Types:**
1. **Rod/Tube Labels** - Stick-on tags that hang off the end of glass rods
2. **Storage Box Labels** - For organizing bins and containers
3. **Shelf Labels** - Quick identification in studio
4. **Inventory Tags** - For any physical storage

**QR Code Magic:**
1. User selects inventory items to label
2. App generates PDF with Avery label template
3. Each label includes QR code encoding deep link: `molten://glass/bullseye-clear-001`
4. Print PDF from computer on label sheets
5. Scan QR with iPhone Camera → iOS offers "Open in Molten?" → App opens directly to that item!

**URL Scheme Registration (Simple!):**
Just add to Info.plist:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>molten</string>
        </array>
        <key>CFBundleURLName</key>
        <string>com.MotleyWoods.Molten</string>
    </dict>
</array>
```

iOS Camera app automatically recognizes `molten://` URLs in QR codes!

### Label Layout Templates

**Template A: Information-Dense** (for protruding rod labels)
```
┌─────────────────────────┐
│  [QR]  Bullseye Clear   │
│        SKU: 1101        │
│        COE: 96          │
│        Qty: 12 rods     │
└─────────────────────────┘
```

**Template B: QR-Focused** (minimal text, larger QR)
```
┌─────────────┐
│    [QR]     │
│             │
│ BE Clear    │
│   1101      │
└─────────────┘
```

**Template C: Box/Shelf Labels** (location-based)
```
┌───────────────────────────────┐
│ Location: Shelf A3            │
│ [QR]  Bullseye Transparent    │
│       SKU: 1101, COE: 96      │
│       12 rods                 │
└───────────────────────────────┘
```

### Supported Avery Label Formats

**Proscriptive approach:** Support specific popular Avery labels to ensure consistency.

**Recommended Formats:**

1. **Avery 5160** (Address Labels)
   - 30 labels per sheet (3 columns × 10 rows)
   - 1" × 2⅝" per label
   - **Use case:** Standard rod labels

2. **Avery 5163** (Shipping Labels)
   - 10 labels per sheet (2 columns × 5 rows)
   - 2" × 4" per label
   - **Use case:** Box labels with more detailed info

3. **Avery 5167** (Return Address)
   - 80 labels per sheet (4 columns × 20 rows)
   - ½" × 1¾" per label
   - **Use case:** Tiny labels for individual small rods

4. **Avery 22806** (Round Labels) - Future enhancement
   - 1" diameter circles
   - **Use case:** Small containers

### Implementation Phases

**Phase 1 (MVP):**

1. **PDF Generation**
   - Use CoreGraphics/PDFKit to generate label sheets
   - Support Avery 5160 (most common format)
   - Single layout template (information-dense)
   - QR code generation with deep links

2. **Deep Link Handling**
   - Register URL scheme in Info.plist
   - Parse `molten://glass/{naturalKey}` URLs
   - Navigate to glass item detail view

3. **Export Options**
   - Save PDF to Files app
   - Share sheet (AirDrop, Email, Messages)
   - User prints from computer

4. **Basic Label Designer**
   - Select items from inventory
   - Preview label sheet
   - Customize which fields to include:
     - Manufacturer, SKU, Color, COE, Quantity, Location
   - Generate and export PDF

**Phase 2 (Enhanced):**

5. **Multiple Label Formats**
   - Add Avery 5163, 5167 support
   - User chooses format for their use case

6. **Template Customization**
   - Multiple layout templates per format
   - Font size options
   - QR code size adjustment

7. **Batch Printing Features**
   - Select items by filter (location, manufacturer, COE)
   - "Print all items in Location X"
   - Partial sheet support (start at position 11 if some labels already used)

8. **Label Management**
   - Track which items have been labeled
   - Store print date in inventory
   - "Reprint Label" quick action
   - "Needs Relabeling" flag

**Phase 3 (Advanced):**

9. **AirPrint Support** (bonus feature if feasible)
   - Direct printing from iOS to compatible label printers
   - Print preview
   - Printer settings

10. **Smart Features**
    - Shopping list labels (print labels for items you're about to buy)
    - Label history (track when labels were printed)
    - Automatic label regeneration when item data changes

### Technical Implementation

**QR Code Generation:**
```swift
import CoreImage.CIFilterBuiltins

func generateQRCode(for naturalKey: String) -> UIImage {
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()

    let deepLink = "molten://glass/\(naturalKey)"
    let data = Data(deepLink.utf8)
    filter.setValue(data, forKey: "inputMessage")
    filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction

    // Scale QR code to appropriate size for label
    guard let outputImage = filter.outputImage else { return UIImage() }
    let scaleX = 150 / outputImage.extent.width
    let scaleY = 150 / outputImage.extent.height
    let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

    guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else {
        return UIImage()
    }

    return UIImage(cgImage: cgImage)
}
```

**PDF Label Sheet Generation:**
```swift
import PDFKit

struct AveryFormat {
    let labelsPerSheet: Int
    let columns: Int
    let rows: Int
    let labelWidth: CGFloat  // in points (1/72 inch)
    let labelHeight: CGFloat
    let leftMargin: CGFloat
    let topMargin: CGFloat
    let horizontalGap: CGFloat
    let verticalGap: CGFloat
}

class LabelPrinter {
    static let avery5160 = AveryFormat(
        labelsPerSheet: 30,
        columns: 3,
        rows: 10,
        labelWidth: 189, // 2⅝" × 72
        labelHeight: 72,  // 1" × 72
        leftMargin: 14.85,
        topMargin: 36,
        horizontalGap: 13.5,
        verticalGap: 0
    )

    func generateLabelSheet(
        items: [GlassItemModel],
        format: AveryFormat,
        template: LabelTemplate
    ) -> PDFDocument {
        // Create PDF document (8.5" × 11" = 612pt × 792pt)
        let pdfMetaData = [
            kCGPDFContextCreator: "Molten Glass Inventory",
            kCGPDFContextTitle: "Glass Labels"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            // Calculate positions and draw labels
            // ...
        }

        return PDFDocument(data: data) ?? PDFDocument()
    }
}
```

**Deep Link Handler:**
```swift
// In MoltenApp.swift
.onOpenURL { url in
    handleDeepLink(url)
}

func handleDeepLink(_ url: URL) {
    guard url.scheme == "molten" else { return }

    // Parse URL: molten://glass/bullseye-clear-001
    let pathComponents = url.pathComponents

    if pathComponents.count >= 2 && pathComponents[0] == "/", pathComponents[1] == "glass" {
        let naturalKey = pathComponents[2]

        // Navigate to glass item
        // Use NavigationPath or similar to push to GlassItemCard detail view
        navigateToGlassItem(naturalKey: naturalKey)
    }
}
```

### UX Flow

**Label Printing Workflow:**

1. **Inventory View** → User selects items → Tap "Print Labels" button

2. **Label Setup Screen:**
   - Choose Avery format (5160, 5163, or 5167)
   - Select layout template (Information-Dense, QR-Focused, etc.)
   - Customize fields to include (checkboxes):
     - ☑ QR Code
     - ☑ Manufacturer
     - ☑ SKU
     - ☑ Color Name
     - ☑ COE
     - ☑ Quantity
     - ☑ Location
   - Preview single label

3. **Sheet Preview Screen:**
   - Show full label sheet layout
   - All selected items positioned on sheet
   - Multiple pages if needed
   - Option to exclude specific items
   - "Start at position X" for partial sheets

4. **Export Options:**
   - Primary: "Save PDF to Files"
   - Secondary: Share sheet (AirDrop, Email, etc.)
   - Optional: AirPrint (if implemented)

5. **Confirmation:**
   - "PDF saved successfully"
   - Option to mark items as "labeled"
   - Quick action: "Print more labels"

**Scanning QR Code Workflow:**

1. User opens Camera app on iPhone
2. Points at QR code on label
3. iOS recognizes `molten://` URL
4. Shows notification: "Open in Molten?"
5. Tap notification → Molten opens to exact glass item!

### Challenges & Solutions

**Challenge 1: Printer Compatibility**

*Challenge:* Not all printers support AirPrint, label printers often need specific apps.

*Solution:*
- Make PDF export the primary workflow (works with any printer)
- AirPrint is nice-to-have bonus feature
- Users print from computer where they have full printer control
- Perfectly acceptable UX - most people print labels from desktop anyway

**Challenge 2: Label Alignment**

*Challenge:* Printer margins vary, partial sheets are tricky.

*Solution:*
- Use exact Avery specifications for label positioning
- Include "test print" feature - print alignment guide on plain paper
- Allow margin adjustment if user's printer is slightly off
- "Start at position X" feature for partial sheets
- Clear instructions: "Make sure printer margins are set to 0"

**Challenge 3: QR Code Minimum Size**

*Challenge:* QR codes need minimum size to scan reliably, especially on small labels.

*Solution:*
- Calculate minimum QR size per label format (at least 0.5" × 0.5")
- For tiny labels (Avery 5167), use QR-focused template with less text
- Use high error correction level ("H") for better scanning
- Test with real labels to validate scanability
- If label too small for QR, show warning: "QR code may be difficult to scan on this format"

**Challenge 4: Deep Link URL Scheme**

*Challenge:* Need to ensure URL scheme doesn't conflict, works reliably.

*Solution:*
- Use unique scheme: `molten://` (unlikely conflict)
- Register in Info.plist (one-time setup)
- iOS automatically handles recognition in Camera app
- No internet needed - works completely offline
- Fallback: Label has printed text anyway if QR fails

**Challenge 5: No QR Code Offline Fallback Needed**

*Note:* Originally considered encoding data in QR for offline use, but this is unnecessary:
- The deep link works offline (local navigation in app)
- If user can't open Molten, QR code is useless anyway
- Label already has human-readable text (manufacturer, SKU, etc.)
- QR code's sole purpose: quick navigation to item in app
- Simpler is better - just use QR for deep link!

### Future Enhancements

- **Label Templates Gallery**: User-submitted custom templates
- **Color Coding**: Color-coded labels by COE or manufacturer
- **Barcode Support**: Alternative to QR codes for some use cases
- **Label History**: Track all printed labels and reprints
- **Integration with Shopping**: Print labels for items on shopping list
- **Thermal Printer Support**: Direct integration with Dymo/Brother/Rollo if feasible

### Success Metrics

- QR code scan → app navigation success rate: >95%
- Label alignment accuracy: >90% on first print
- PDF generation time: <5 seconds for 30 labels
- User satisfaction: Labels are useful and time-saving

### Why This Is a Killer Feature

- **Unique differentiator** - No other glass inventory app does this
- **Solves real pain point** - Organization in physical studio space
- **Bridges physical/digital** - Seamless connection between studio and app
- **Professional feel** - Makes inventory management feel legitimate
- **Sticky feature** - Once labeled, users are committed to Molten

---

## UI Components

### Create Reusable Components Library

Build a library of reusable UI components in `Views/Shared/Components/` to ensure consistency across the app.

**Components to create:**

1. **CardView.swift** - Standard card container
   - Replaces repeated card styling patterns
   - Uses `DesignSystem` for padding, background, and corner radius
   - Optional header, footer, and shadow support

2. **SectionHeader.swift** - Consistent section headers
   - Used across all list sections
   - Standard font (title2 + semibold) and spacing
   - Optional action button support

3. **EmptyStateView.swift** - Standard empty states
   - Icon, title, description, optional button
   - Consistent spacing and typography
   - Configurable icon and colors

4. **LoadingView.swift** - Standard loading indicators
   - Spinner with optional message
   - Consistent styling and positioning
   - Support for inline vs. full-screen loading

5. **ErrorView.swift** - Standard error displays
   - Error icon, message, optional retry button
   - Consistent error styling
   - Support for different error types

6. **TagView.swift** - Reusable tag/chip component
   - Selected vs. unselected states
   - Consistent padding and corner radius
   - Color variants (blue, green, gray, etc.)

7. **SearchBarView.swift** - Standard search bar
   - Magnifying glass icon, text field, clear button
   - Consistent background and styling
   - Optional filter button

8. **FormSection.swift** - Reusable form section container
   - Label, input field, helper text, error message
   - Consistent spacing and typography
   - Support for various input types

**Benefits:**
- Reduce code duplication across views
- Ensure UI consistency automatically
- Easier to update design system-wide
- Better developer experience

**Acceptance Criteria:**
- All components use `DesignSystem` constants
- Components are documented with usage examples
- Existing views can optionally migrate to use these components
- Components support both light and dark mode

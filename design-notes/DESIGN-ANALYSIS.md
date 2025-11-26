# Design Analysis: "Luminous Precision" → iOS Implementation

Analysis of Gemini's mockups, translated for iOS conventions.

---

## Design Concept Summary

**Theme**: "Luminous Precision" — Balance data precision with the warmth of molten glass.

**Goal**: Transform from "database utility" to "studio companion" while keeping clean lines.

---

## Color Palette: "Embers & Ash"

| Role | Name | Hex | iOS Usage |
|------|------|-----|-----------|
| **Primary** | Molten Orange | `#FF5722` | Tint color, active tabs, key actions, filled SF Symbols |
| **Secondary** | Warm Amber | `#FFC107` | Warnings, low-stock indicators, "heating up" states |
| **Tertiary** | Slate Teal | `#00796B` | Links, in-stock counts, secondary actions |
| **Background** | Off-White/Ash | `#F8F9FA` | List backgrounds, grouped table backgrounds |
| **Text Primary** | Charcoal | `#212121` | Body text, titles (softer than pure black) |
| **Text Secondary** | Gray | `#757575` | Subtitles, captions, metadata |

**Note**: Replace default iOS blue tint (`#007AFF`) with Molten Orange throughout.

---

## Typography

| Element | Font | Weight | Design |
|---------|------|--------|--------|
| Large Titles | SF Pro | Bold | `.largeTitle.bold()` |
| Section Headers | SF Pro | Semibold | `.headline` |
| Body | SF Pro | Regular | `.body` |
| **Inventory Counts** | SF Pro Rounded | Bold | `.system(.title2, design: .rounded).bold()` |
| Captions | SF Pro | Regular | `.caption` |

**Key Change**: Use SF Pro Rounded for prominent numbers (inventory counts, temperatures, quantities) to give them a softer, tactile feel.

---

## Mockup Screens Analysis

### Screen 1: Inventory List ("My Inventory")

**Mockup Shows:**
- Large title navigation
- Search bar
- Card-based list items (not edge-to-edge rows)
- Large color swatches (leading edge, ~60×80pt)
- Item info: SKU (bold) → Name → Type/variant
- Inventory count on trailing edge with SF Rounded Bold
- Low-stock items in Warm Amber
- Tab bar with icons

**iOS Translation:**
- ✅ Large title navigation — standard iOS
- ✅ Search bar — use `.searchable()` modifier
- ⚠️ Card-based list — mockup shows cards; iOS typically uses `List` with `.insetGrouped`. **Decision needed**: Cards in ScrollView+LazyVStack vs styled List rows
- ✅ Tab bar — standard iOS, use filled icons for active state

**Existing Code**: `InventoryView.swift`, `InventoryItemRowView.swift`

---

### Screen 2: Item Detail ("BE-0124-30")

**Mockup Shows:**
- Inline navigation title
- Hero header with glass color as full-width background
- Item name overlaid on color (white text)
- "Inventory Status" card with sheet count
- Specifications in 2-column grid of "Data Tiles"
- Each tile: icon, label, value

**iOS Translation:**
- ✅ Inline navigation — standard iOS for detail views
- ✅ Hero header — custom view, works well
- ⚠️ Data tiles grid — mockup shows custom cards; could also use `Form` with grouped sections. Cards are fine but more custom work.

**Existing Code**: `InventoryDetailView.swift`, `CatalogItemDetailView.swift`

---

### Screen 3: Kiln Schedule View

**Mockup Shows:**
- Large title "Fuse & Slump"
- "Edit" button (Molten Orange) in toolbar
- Heat curve chart (Swift Charts)
- Gradient fill under curve (cool→warm→hot)
- Segments list below chart
- Each segment as card with icon, title, rate, temperature, hold time

**iOS Translation:**
- ✅ Large title + toolbar button — standard iOS
- ✅ Swift Charts — native iOS 16+ framework
- ✅ Gradient fill — achievable with `AreaMark` and `LinearGradient`
- ✅ Segment cards — custom views

**Existing Code**: `KilnScheduleDetailView.swift`, `KilnScheduleGraphView.swift`

---

### Screen 4: Add to Inventory Form

**Mockup Shows:**
- Modal sheet with Cancel/title
- Item preview card at top
- Form fields: Quantity, Type picker, Location
- Notes field (multiline)
- "Save" button (Molten Orange, full-width)

**iOS Translation:**
- ✅ Modal sheet — standard iOS
- ✅ Form — use SwiftUI `Form`
- ⚠️ Full-width button — mockup shows Material-style button; iOS prefers toolbar buttons or `.bordered.prominent` in forms

**Existing Code**: `AddInventoryItemView.swift`

---

### Screen 5: Project Detail

**Mockup Shows:**
- Dark header with project image
- Progress bar (Molten Orange)
- Summary text
- Steps list with numbered steps
- "Add Logbook Entry" button (Molten Orange, pill shape)

**iOS Translation:**
- ✅ Image header — common iOS pattern
- ✅ Progress bar — use `ProgressView`
- ⚠️ Pill button — mockup shows floating pill; iOS would typically use toolbar button or button in list

**Existing Code**: `ProjectDetailView.swift`

---

### Screen 6: Projects List

**Mockup Shows:**
- Large title "Projects"
- Search bar
- Card-based project rows with image backgrounds
- Project name overlaid on image

**iOS Translation:**
- ✅ Large title + search — standard iOS
- ✅ Image cards — custom views in List or ScrollView

**Existing Code**: `ProjectsView.swift`, `ProjectRow.swift`

---

### Screen 7: Settings

**Mockup Shows:**
- Large title "Settings"
- Grouped sections (General, Catalog, Data, About)
- Standard form rows with disclosure indicators
- Toggle for Notifications

**iOS Translation:**
- ✅ Fully standard iOS `Form` with sections
- No major changes needed, just color updates

**Existing Code**: `SettingsView.swift`

---

### Screen 8: Locations View

**Mockup Shows:**
- Segmented control (Stores / Classes)
- Map at top
- Location cards below
- "Directions" button
- "Suggest a Change or Deletion" link

**iOS Translation:**
- ✅ Segmented control — standard iOS
- ✅ Map — MapKit
- ✅ List cards — custom views

**Existing Code**: `LocationsView.swift`, `LocationDetailView.swift`

---

### Screen 9: Recipes List & Add Recipe

**Mockup Shows:**
- Card-based recipe list with images
- Add Recipe form with type picker, glass colors list, proportions, photos

**iOS Translation:**
- ✅ Form-based input — standard iOS
- ✅ Image gallery — custom component

**Existing Code**: (Recipes feature — disabled, needs investigation)

---

### Screen 10: Shopping List (Shopping Mode)

**Mockup Shows:**
- Toggle "Shopping Mode" at top
- Checklist-style items with checkboxes
- "Checkout (1 Item)" button at bottom (Molten Orange)

**iOS Translation:**
- ✅ Toggle — standard iOS
- ⚠️ Bottom button — iOS typically avoids bottom buttons outside tab bars; could use toolbar or floating action

**Existing Code**: `ShoppingListView.swift`

---

### Screen 11: Share Inventory

**Mockup Shows:**
- Form for share options (Include filter, Expires picker)
- "Create Share Link" button
- Active shares list with "Revoke" action

**iOS Translation:**
- ✅ Form — standard iOS
- ✅ List of shares — standard iOS list with swipe actions

**Existing Code**: (Sharing feature)

---

### Screen 12: Rate Glass Dialog

**Mockup Shows:**
- Modal sheet
- Star rating (4 stars selected)
- Text field for descriptive words
- Word chips (Vibrant, Ruby)
- Cancel / Submit Rating buttons

**iOS Translation:**
- ✅ Sheet presentation — standard iOS
- ⚠️ Chip input — not native iOS; use tag-style input or simple TextField

**Existing Code**: `RatingView.swift`, rating components

---

## iOS Convention Conflicts to Address

### 1. Bottom Action Buttons
**Mockup**: Full-width buttons at screen bottom (Save, Checkout)
**iOS**: Prefer toolbar buttons or `.borderedProminent` buttons within forms
**Resolution**: Use toolbar for primary actions OR card-style footer that's clearly not the tab bar

### 2. Card-Based Lists
**Mockup**: Every list uses white cards with shadows
**iOS**: `List` with `.insetGrouped` is the standard
**Resolution**: Can use cards, but ensure they don't look like Android Material cards. Consider `.insetGrouped` List styling with custom row content instead.

### 3. Floating Action Buttons (FAB)
**Mockup**: Some screens hint at floating buttons
**iOS**: No FABs — use toolbar buttons, navigation bar buttons, or contextual menus
**Resolution**: Move all floating actions to toolbars

### 4. Segmented Controls vs Tabs
**Mockup**: Uses segmented control in Locations view
**iOS**: Correct for filtering within a view, but tab bar for top-level navigation
**Resolution**: Already correct in mockup

### 5. Tab Bar Icons
**Mockup**: Shows flame icon for Projects
**iOS**: Use SF Symbols, filled for active state
**Resolution**: Map to appropriate SF Symbols (flame.fill, archivebox.fill, cart.fill, gearshape.fill)

---

## Existing Shared Components to Update

These files in `Views/Shared/Components/` will need design system updates:

| Component | Purpose | Updates Needed |
|-----------|---------|----------------|
| `ColorSwatchView.swift` | Glass color display | Larger size option, rounded corners |
| `GlassItemCard.swift` | Item display | New card styling |
| `GlassItemRowView.swift` | List row | Card conversion or styling |
| `EmptyStateView.swift` | Empty states | Color updates |
| `BadgeLabel.swift` | Labels/tags | Color updates |
| `FilterChipsRow.swift` | Filter chips | Color updates |
| `FormComponents.swift` | Form fields | Styling updates |
| `SuccessToast.swift` | Toast messages | Color updates |
| `ExpandableText.swift` | Collapsible text | Styling updates |

---

## New Components to Create

| Component | Purpose |
|-----------|---------|
| `Theme.swift` | Centralized colors, fonts, spacing |
| `DataTile.swift` | Grid tile for specs (icon + label + value) |
| `HeroHeader.swift` | Color-filled header with overlay text |
| `GlassItemCardView.swift` | New card-based item display (or rename existing) |
| `InventoryBadge.swift` | Inventory count with rounded font |
| `LowStockIndicator.swift` | Amber low-stock badge |

---

## Implementation Priority

### Phase 1: Foundation
1. Create `Theme.swift` with colors, fonts, spacing constants
2. Update tint color throughout app
3. Update existing shared components with theme

### Phase 2: Core Screens (Enabled Features)
1. Inventory List — card styling, larger swatches
2. Item Detail — hero header, data tiles
3. Shopping List — styling updates
4. Catalog — same treatment as Inventory
5. Settings — color updates only
6. Locations — styling updates

### Phase 3: Disabled Features (When Re-enabled)
1. Projects
2. Kiln Schedules (heat curve gradient)
3. Purchases
4. Recipes

---

## Questions for User

1. **Card style**: Do you want true cards (shadow + corner radius) or styled insetGrouped List rows?
2. **Color swatch size**: How large should swatches be in lists? (Mockup shows ~60×80pt)
3. **Tab bar icons**: Confirm which tabs exist and preferred SF Symbols
4. **Accessibility**: Any specific Dynamic Type or VoiceOver requirements beyond standard?

---

*Created: 2025-11-24*

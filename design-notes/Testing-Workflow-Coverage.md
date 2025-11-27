## Workflow Coverage Tracking

---

### Workflow 17: Print Inventory Labels with QR Codes

**User Journey:**
> Select items from inventory, choose a label template, customize what information appears on labels, and print QR code labels for physical glass items.

**Implementation Location:** Inventory view, label designer/printer

**Features to Test:**
- Select items to print labels for
- Choose label template (multiple templates available)
- Customize label content (what information to include)
- Generate QR codes for selected items
- Preview labels before printing
- Print labels
- Label templates render correctly
- QR codes are scannable and accurate
- Selection UI:
  - Select by date range
  - Edit quantities for individual items
  - Bulk selection options
  - Clear selection
  - Select all/none

**Known Issues/Bugs:**
- 🔥 **CRITICAL BUG - APP CRASH:** Loading the label printing screen **crashes the whole app**! This wasn't caught in tests - major test coverage gap
- ⚠️ **UX IMPROVEMENT NEEDED:** Need better UI for selecting which items to print labels for (date ranges, editing individual quantities, etc.)
- 💡 **UI PATTERN REUSE:** Could steal UI ideas from shopping list implementation for item selection

**Test Coverage:**
- ❌ **MAJOR GAP:** Current tests did NOT catch the app crash when loading this screen
- TBD - Needs investigation for all other aspects

**Note:** Described as "our most awesome feature" - label printing with QR codes for inventory management.

### Workflow 1: View Inventory Item Detail with All Interactions

**User Journey:**
> Pull up inventory, click on an item to view it. While on that screen, expand/collapse manufacturer notes, add tags, click on the manufacturer link to visit their website. Should also be able to add it to inventory, shopping list, add custom images, and add custom notes.

**Implementation Details:**

**Main View:** `InventoryDetailView.swift` (Molten/Sources/Views/Inventory/)
- Comprehensive detail view with expandable sections
- Floating Action Button (FAB) with 5 actions: Add Inventory, Add to Shopping List, Add Image, Add Note, Manage Tags
- Uses `CompleteInventoryItemModel` as the data model
- Dependency-injected services for all operations

**Key Features:**
1. **Expand/Collapse Manufacturer Notes** (Lines 982-1008)
   - State: `isManufacturerNotesExpanded` (initialized from `UserSettings.shared.expandManufacturerDescriptionsByDefault`)
   - Shows first 4 lines by default, expandable to full text
   - Smooth animation with scroll-to-top on collapse

2. **Add/Manage Tags** (Lines 209, 244-252)
   - Opens `UserTagsEditor` sheet (Component at Views/Inventory/Components/UserTagsEditor.swift)
   - FAB action triggers `showingUserTagsEditor`
   - Editor supports adding/removing user tags with suggested tags
   - Repository: `UserTagsRepository`

3. **Manufacturer Website Link** (Lines 612-634)
   - Rendered in empty details message when no manufacturer notes
   - Uses SwiftUI `Link` component with safe URL validation
   - Tests exist for invalid/nil/empty URLs (InventoryItemDetailViewTests.swift:156-255)

4. **Add to Inventory** (Lines 197-199, 403-437, 253-265)
   - FAB action → checks entitlement limits → shows either add form or upgrade prompt
   - Opens `AddInventoryItemView` sheet with prefilled `stable_id`
   - Refreshes item data on sheet dismiss

5. **Add to Shopping List** (Lines 200-202, 215-224)
   - FAB action triggers `showingShoppingListOptions`
   - Opens `ShoppingListOptionsView` sheet (Lines 1177-1320)
   - Form with quantity picker and store autocomplete
   - Repository: `ShoppingListRepository`

6. **Add Custom Images** (Lines 203-205, 278-288, 439-483)
   - FAB action triggers PhotosPicker with 10-image limit
   - Uses `PhotosPickerItem` for selection
   - Auto-resizing handled by `UserImageRepository`
   - First image or no primary → becomes primary, others → alternates
   - Repository: `UserImageRepository`

7. **Add Custom Notes** (Lines 206-208, 235-243)
   - FAB action opens `UserNotesEditor` sheet
   - Shows existing notes with "Edit" button (Lines 637-689)
   - Expandable with 4-line preview, similar to manufacturer notes
   - Repository: `UserNotesRepository`

**Current Test Coverage:**

⚠️ **Missing Unit/Integration Tests:**
- [ ] FAB action triggering

❌ **UI Tests (Critical Gaps):**
- [ ] **No end-to-end test for this complete workflow**
- [ ] Navigate from inventory list → item detail
- [ ] Tap expand manufacturer notes, verify expanded
- [ ] Tap "Manage Tags", add a tag, verify it appears
- [ ] Tap manufacturer link, verify Safari/browser opens
- [ ] Tap "Add Inventory", fill form, verify item updated
- [ ] Tap "Add to Shopping List", fill form, verify added
- [ ] Tap "Add Image", select photo, verify image appears
- [ ] Tap "Add Note", enter text, verify note saved

**Recommended Tests to Add:**

**UI Tests (High Priority - MUST HAVE):**
1. `InventoryDetailUITests.swift`
   ```swift
   @Test("Complete item detail workflow")
   func testCompleteItemDetailWorkflow() async throws {
       // Given: Inventory with at least one item
       app.launch()
       app.tabBars.buttons["Inventory"].tap()

       // When: Tap first item
       app.collectionViews.cells.firstMatch.tap()

       // Then: Detail view appears
       #expect(app.navigationBars["Item Name"].exists)

       // Test expand manufacturer notes
       app.buttons["expand_manufacturer_notes"].tap()
       #expect(app.staticTexts["show_less_button"].exists)

       // Test add tag
       app.buttons["fab_manage_tags"].tap()
       app.textFields["tag_input"].tap()
       app.textFields["tag_input"].typeText("favorite")
       app.buttons["add_tag_button"].tap()
       app.buttons["Done"].tap()
       #expect(app.staticTexts["favorite"].exists)

       // Test add to shopping list
       app.buttons["fab_add_shopping_list"].tap()
       app.textFields["quantity"].typeText("5")
       app.buttons["Add to Shopping List"].tap()
       #expect(app.staticTexts["Item added to shopping list"].exists)

       // Test add note
       app.buttons["fab_add_note"].tap()
       app.textViews["note_text"].typeText("This is my note")
       app.buttons["Save"].tap()
       #expect(app.staticTexts["Your Notes"].exists)
   }
   ```

**Test Data Requirements:**
- Item with manufacturer notes (long enough to expand)
- Item with manufacturer URL
- Item without inventory (to test "add inventory" flow)
- Mock UserImageRepository with test images
- Mock ShoppingListRepository
- Mock UserNotesRepository with existing notes

**References:**
- Main view: `Molten/Sources/Views/Inventory/InventoryDetailView.swift`
- Existing tests: `Molten/Tests/MoltenTests/Views/Inventory/InventoryItemDetailViewTests.swift`
- Components: `UserTagsEditor.swift`, `UserNotesEditor.swift`
- CloudKit testing guide: `Molten/Docs/CloudKit-Testing-Guide.md` (for multi-device image sync)

---

### Workflow 2: Add Inventory Item with Notes (BUG - Notes Not Saved)

**User Journey:**
> Add a new inventory item to the system, filling in quantity, type, location, and notes. The notes should be saved with the item.

**BUG STATUS:** 🐛 **CRITICAL BUG** - Notes are collected but never saved!

**Implementation Details:**

**Main View:** `AddInventoryItemView.swift` (Molten/Sources/Views/Inventory/)
**ViewModel:** `AddInventoryItemViewModel.swift` (Molten/Sources/Views/Inventory/ViewModels/)

**Current Behavior:**
1. Form has a notes field (Line 258-264 in AddInventoryItemView.swift)
   ```swift
   private var notesField: some View {
       LabeledField("Notes (optional)") {
           TextField("Notes (optional)", text: $viewModel.notes, axis: .vertical)
               .lineLimit(3...6)
               .accessibilityIdentifier("inventory.add.notesField")
       }
   }
   ```

2. ViewModel has a `notes` field (Line 35 in AddInventoryItemViewModel.swift)
   ```swift
   var notes: String = ""
   ```

3. **BUT** the `save()` method (Lines 171-211) NEVER uses the notes:
   ```swift
   func save() async -> Bool {
       // ... validation ...

       do {
           _ = try await inventoryTrackingService.addInventory(
               quantity: quantityValue,
               type: selectedType,
               toItem: stableId,
               atLocation: finalLocation
               // ❌ notes is NEVER passed!
           )
           // ...
       }
   }
   ```

4. The `inventoryTrackingService.addInventory()` method doesn't even have a notes parameter:
   ```swift
   func addInventory(
       quantity: Double,
       type: String,
       toItem stableId: String,
       atLocation location: String? = nil  // ❌ No notes parameter
   ) async throws -> InventoryModel
   ```

**Root Cause:**
- The `InventoryModel` itself doesn't have a notes field (inventory records are for quantity/type/location)
- Notes are stored separately via `UserNotesRepository` (one note per glass item, not per inventory record)
- The UI collects notes during inventory addition but never calls `UserNotesRepository` to save them

**Expected Behavior:**
When adding inventory with notes, the system should:
1. Create the inventory record via `inventoryTrackingService.addInventory()`
2. Save the notes via `UserNotesRepository.createNotes()` or `updateNotes()`
3. Both operations should succeed, or both should fail (atomic transaction preferred)

**Fix Required:**

**Option 1: Add notes to ViewModel.save() (Recommended)**
```swift
// In AddInventoryItemViewModel.swift, line 171-211
func save() async -> Bool {
    // ... existing validation ...

    do {
        // 1. Create inventory record
        _ = try await inventoryTrackingService.addInventory(
            quantity: quantityValue,
            type: selectedType,
            toItem: stableId,
            atLocation: finalLocation
        )

        // 2. Save notes if provided
        if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let userNotesRepo = RepositoryFactory.createUserNotesRepository()

            // Check if notes already exist
            let existingNotes = try? await userNotesRepo.fetchNotes(forItem: stableId)

            if existingNotes != nil {
                // Update existing notes
                try await userNotesRepo.updateNotes(
                    notes,
                    forItem: stableId
                )
            } else {
                // Create new notes
                let notesModel = UserNotesModel(
                    item_stable_id: stableId,
                    notes: notes
                )
                _ = try await userNotesRepo.createNotes(notesModel)
            }
        }

        errorMessage = nil
        return true
    } catch {
        setError("Failed to save: \(error.localizedDescription)")
        return false
    }
}
```

**Option 2: Add UserNotesRepository to ViewModel Dependencies**
- Inject `UserNotesRepository` in `AddInventoryItemViewModel` init
- Pass it through from `AddInventoryItemView`
- Better for testing and follows existing dependency injection pattern

**Current Test Coverage:**

✅ **Unit Tests (Extensive but Missing Notes):**
- `AddInventoryItemViewTests.swift` (70+ tests)

❌ **UI Tests (Complete Gap):**
- [ ] **No UI test for add inventory workflow at all**
- [ ] Fill form with notes → Save → Verify notes appear in detail view
- [ ] Add inventory without notes → Verify no notes in detail view
- [ ] Add inventory with notes to item that already has notes → Verify notes updated

**Accessibility Identifiers:**
✅ **Already present:**
- `"inventory.add.notesField"` (Line 262)
- `"inventory.add.quantityField"` (Line 146)
- `"inventory.add.typePicker"` (Line 165)
- `"inventory.add.saveButton"` (Line 281)
- `"inventory.add.cancelButton"` (Line 273)

**Recommended Tests to Add:**

**Unit Tests (High Priority - Verify Bug Fix):**
1. `AddInventoryItemViewModel_NotesTests.swift`
   ```swift
   @Test("Notes are saved when adding inventory")
   func testNotesAreSavedWithInventory() async throws {
       // Arrange
       let viewModel = createViewModel()
       viewModel.selectGlassItem(testGlassItem)
       viewModel.quantity = "10"
       viewModel.selectedType = "rod"
       viewModel.notes = "This is a test note"

       // Act
       let success = await viewModel.save()

       // Assert
       #expect(success == true)

       // Verify notes were saved
       let savedNotes = try await userNotesRepo.fetchNotes(forItem: testGlassItem.stable_id)
       #expect(savedNotes?.notes == "This is a test note")
   }

   @Test("Empty notes are not saved")
   func testEmptyNotesNotSaved() async throws {
       // Arrange
       let viewModel = createViewModel()
       viewModel.selectGlassItem(testGlassItem)
       viewModel.quantity = "10"
       viewModel.notes = "   "  // Whitespace only

       // Act
       let success = await viewModel.save()

       // Assert
       #expect(success == true)

       // Verify no notes were created
       let savedNotes = try? await userNotesRepo.fetchNotes(forItem: testGlassItem.stable_id)
       #expect(savedNotes == nil)
   }

   @Test("Existing notes are updated not duplicated")
   func testExistingNotesUpdated() async throws {
       // Arrange - Create existing notes
       let existingNotes = UserNotesModel(
           item_stable_id: testGlassItem.stable_id,
           notes: "Old notes"
       )
       _ = try await userNotesRepo.createNotes(existingNotes)

       // Add inventory with new notes
       let viewModel = createViewModel()
       viewModel.selectGlassItem(testGlassItem)
       viewModel.quantity = "10"
       viewModel.notes = "New notes"

       // Act
       let success = await viewModel.save()

       // Assert
       #expect(success == true)

       // Verify notes were updated (not duplicated)
       let savedNotes = try await userNotesRepo.fetchNotes(forItem: testGlassItem.stable_id)
       #expect(savedNotes?.notes == "New notes")
   }
   ```

**Integration Tests (Medium Priority):**
2. `AddInventoryWithNotes_IntegrationTests.swift`
   - Test full flow: Create inventory + notes via services
   - Verify both inventory and notes are queryable
   - Test transaction rollback if either operation fails

**UI Tests (High Priority - After Bug Fix):**
3. `AddInventoryUITests.swift`
   ```swift
   @Test("Add inventory with notes workflow")
   func testAddInventoryWithNotes() async throws {
       // Given: App is running
       app.launch()
       app.tabBars.buttons["Inventory"].tap()

       // When: Tap add button
       app.buttons["inventory.addButton"].tap()

       // Search for item
       app.textFields["inventory.add.searchSelector"].tap()
       app.textFields["inventory.add.searchSelector"].typeText("Clear")
       app.collectionViews.cells.firstMatch.tap()

       // Fill form with notes
       app.textFields["inventory.add.quantityField"].tap()
       app.textFields["inventory.add.quantityField"].typeText("10")

       app.textFields["inventory.add.notesField"].tap()
       app.textFields["inventory.add.notesField"].typeText("Test note for UI test")

       // Save
       app.buttons["inventory.add.saveButton"].tap()

       // Then: Success message appears
       #expect(app.staticTexts.matching(identifier: "successToast").element.exists)

       // Navigate to item detail
       app.collectionViews.cells.firstMatch.tap()

       // Verify notes appear
       #expect(app.staticTexts["Your Notes"].exists)
       #expect(app.staticTexts["Test note for UI test"].exists)
   }
   ```

**Test Data Requirements:**
- Glass items with and without existing notes
- Mock `UserNotesRepository` with create/update/fetch methods
- Test scenarios: no notes, new notes, update existing notes, whitespace-only notes

**References:**
- View: `Molten/Sources/Views/Inventory/AddInventoryItemView.swift` (Lines 258-264)
- ViewModel: `Molten/Sources/Views/Inventory/ViewModels/AddInventoryItemViewModel.swift` (Lines 35, 171-211)
- Service: `Molten/Sources/Services/Core/InventoryTrackingService.swift` (Line 157)
- Tests: `Molten/Tests/MoltenTests/Views/Inventory/AddInventoryItemViewTests.swift` (NO notes tests)
- Related: `UserNotesRepository` in `Molten/Sources/Repositories/Protocols/`

---

### Workflow 3: Scroll and Filter Inventory by COE, Tags, or Manufacturer

**User Journey:**
> Scroll through the inventory list and filter it by COE rating, tags, or manufacturer to find specific items.

**Implementation Location:** `InventoryView.swift`, `InventoryViewModel.swift`

**Features to Test:**
- Scrolling through inventory list
- Filter by COE (e.g., 90, 96, 104)
- Filter by tags (catalog tags and user tags)
- Filter by manufacturer (Bullseye, CiM, Effetre, etc.)
- Multiple filters applied simultaneously
- Clear filters / reset to show all
- Filter counts showing number of items per filter option
- Filter persistence across app sessions

**Test Coverage:** TBD - Needs investigation

---

### Workflow 4: View Glass Item Details with All Information and Actions

**User Journey:**
> Click on an item to view its complete details including manufacturer description, images, inventory, and shopping lists. Use the three dots menu to manage tags, add notes, images, shopping list entries, or inventory.

**Implementation Location:** `CatalogItemDetailView.swift` or `InventoryDetailView.swift`

**Features to Test:**
- Display manufacturer description/notes
- Display product images (manufacturer and user-uploaded)
- Show current inventory for the item
- Show shopping list entries for the item
- Three dots menu actions:
  - Manage your personal tags
  - Add a note
  - Add an image
  - Add to shopping list
  - Add to inventory
- All information sections present and properly formatted
- Navigation to/from detail view

**Test Coverage:** TBD - Needs investigation

**Note:** This overlaps with Workflow 1 but focuses on viewing from catalog rather than inventory context.

---

### Workflow 5: Rate Items and Add Descriptive Words

**User Journey:**
> View star ratings for an item, click "Rate" to add your own rating and up to five descriptive words. See top words from all users displayed below tags, with a three-dot expansion to see all words when they exceed one line.

**Implementation Location:** TBD - Rating/review component

**Features to Test:**
- Display current star rating for item
- Click "Rate" button to open rating dialog
- Select 1-5 stars
- Add up to 5 descriptive words for the item
- Display top/most common words below tags
- Show three dots (...) when words exceed one line
- Click three dots to expand and see all words
- Word truncation and expansion animation
- Save rating and words
- Update display after rating is submitted

**Test Coverage:** TBD - Needs investigation

---

### Workflow 6: Navigate to Manufacturer's Product Page

**User Journey:**
> Click on the manufacturer's link for an item to open their product page in a browser, where you can read their description or purchase the item.

**Implementation Location:** Item detail views (manufacturer URL link)

**Features to Test:**
- Manufacturer link is displayed for items that have URLs
- Click link opens browser/Safari
- Correct URL is opened (manufacturer's page for specific product)
- Handle items without manufacturer URLs gracefully
- Link accessibility (VoiceOver support)
- Invalid/broken URL handling

**Test Coverage:** TBD - Needs investigation

**Note:** Workflow 1 already documented some tests for URL handling (invalid/nil/empty URLs), this covers the user interaction aspect.

---

### Workflow 7: Share Item Information

**User Journey:**
> Click the share icon on an item to share its information with a friend via message, email, or other sharing methods.

**Implementation Location:** Item detail views (share button/icon)

**Features to Test:**
- Share icon is visible on item detail view
- Click share icon opens system share sheet
- Share sheet contains item information (name, manufacturer, details, etc.)
- Supports multiple share destinations (Messages, Mail, AirDrop, etc.)
- Cancel share sheet dismisses properly
- Shared content is properly formatted
- Share functionality works for all item types

**Test Coverage:** TBD - Needs investigation

---

### Workflow 8: Sort Inventory (Similar to Catalog Sorting)

**User Journey:**
> Sort inventory items using the same sorting options as the catalog. The inventory view is identical to catalog view, but items include quantity, type, and location information.

**Implementation Location:** `InventoryView.swift`, sorting controls

**Features to Test:**
- Sort by name (A-Z)
- Sort by manufacturer
- Sort by total quantity
- Sort by date added
- Sort options are identical to catalog view
- Items display with quantity, type, and location fields
- Visual consistency between catalog and inventory views
- Sort preference persistence
- Inventory-specific data (quantity/type/location) displays correctly while sorted

**Test Coverage:** TBD - Needs investigation

**Note:** Catalog and Inventory are different views of the same items - Inventory adds quantity, type, and optional location fields.

---

### Workflow 9: Shopping List and Shopping Mode Checkout

**User Journey:**
> View shopping list (similar to inventory/catalog), note where to acquire items from, turn on "shopping mode" for a checklist experience, check items off as you shop, then check out to add all items to inventory.

**Implementation Location:** Shopping list view, shopping mode

**Features to Test:**
- Shopping list displays items similar to catalog/inventory
- Add store/location where you want to acquire item
- Toggle "shopping mode" on/off
- Shopping mode displays as checklist
- Check off items as you shop them
- Click checkout button to add all checked items to inventory
- Items are added to inventory with correct quantities
- Shopping list is cleared/updated after checkout

**Known Issues/Questions:**
- 🔥 **CRITICAL UX ISSUE:** The entire shopping checkout experience UI/UX is very confusing right now - needs complete overhaul
- ⚠️ **UNCLEAR:** Can you modify quantity in shopping mode? If so, how?
- 🐛 **BUG:** Instructions say "click checkout" but there's no button marked "checkout"

**Test Coverage:** TBD - Needs investigation

**Note:** Shopping list is a third view of items (alongside Catalog and Inventory), focused on acquisition planning.

---

### Workflow 10: Create and Manage Projects with Steps

**User Journey:**
> Search/filter projects like other views. Create a new project with title, type (idea, tutorial, etc.), optional technique type, optional summary, optional tags, optional images, and other fields. Add multiple steps to the project, each with title, description, optional glass items, and optional photos.

**Implementation Location:** Projects view, Add/Edit Project form

**Features to Test:**
- Search/filter projects (same pattern as catalog/inventory/shopping)
- Create new project with required fields:
  - Title (required)
  - Type (idea, tutorial, etc.)
- Optional project fields:
  - Technique type
  - Summary
  - Tags
  - Images
  - (other fields - TBD: review form for complete list)
- Add steps to project
- Each step has:
  - Title (required)
  - Description (required)
  - Optional: Glass items
  - Optional: Photos
- Add multiple steps (unlimited)
- Edit/delete steps
- Reorder steps
- Save project with all steps
- View project with all details and steps

**Test Coverage:** TBD - Needs investigation

**Known Issues/Questions:**
- 🔥 **CRITICAL UX ISSUE:** Project viewing is currently a mix between editing and viewing modes - this is awful and needs major improvement. Should have clear separation between view mode and edit mode.
- 💡 **FEATURE REQUEST:** Check if you have all glass items from project in your inventory (inventory checking)
- 💡 **FEATURE REQUEST:** Add all items from project to your shopping list (or multiples of the project)

**Note:** Projects are more complex entities with nested steps, unlike the simpler item-based views (Catalog/Inventory/Shopping).

---

### Workflow 11: Add Photos Throughout the App

**User Journey:**
> Add photos in various contexts (item images, project photos, step photos, etc.) with consistent UI/UX.

**Implementation Location:** Photo picker components used throughout app

**Features to Test:**
- Photo upload from camera
- Photo selection from library
- Photo picker UI consistency across all contexts:
  - Adding item images
  - Adding project images
  - Adding step photos
  - Adding notes photos
  - Other photo contexts
- Button labeling consistency
- Photo preview after selection
- Photo deletion
- Multiple photo selection where applicable

**Known Issues/Questions:**
- ⚠️ **UI CONSISTENCY:** Should say "Add a Photo" not "Select a Photo" everywhere photos can be added to the app

**Test Coverage:** TBD - Needs investigation

**Contexts Where Photos Are Used:**
- Item detail view (custom images)
- Projects (main images)
- Project steps (step photos)
- Other contexts TBD

---

### Workflow 12: Add Reference URLs to Projects/Tutorials

**User Journey:**
> Include reference URLs in projects (especially tutorials) to link to external resources, source materials, or related content.

**Implementation Location:** Project form, tutorial fields

**Features to Test:**
- Add reference URL field to projects
- Support multiple URLs
- URL validation (valid URL format)
- Display URLs in project view
- Click URL to open in browser
- Edit/delete URLs
- URL field is optional
- URLs display properly formatted

**Test Coverage:** TBD - Needs investigation

---

### Workflow 13: Share Projects (Print as PDF, Export as File)

**User Journey:**
> Save project ideas or tutorials, write your own, and share them with others. Projects can be printed as PDFs or exported in a special file format for easy sharing via AirDrop, forums, Facebook, etc.

**Implementation Location:** Project view, export/share functionality

**Features to Test:**
- Print project as PDF
- Export project to file format
- File format uses `.molten` extension
- Share exported file via:
  - AirDrop
  - Messages
  - Email
  - Social media (Facebook, etc.)
  - Forums
  - Other share destinations
- Import `.molten` files from others
- Imported projects display correctly
- PDF formatting is clean and readable
- PDF includes all project details and steps

**Known Issues/Questions:**
- ⚠️ **FILE FORMAT NAMING:** Currently says "moltenplan" - should NOT specify that in the UI/docs
- ⚠️ **FILE EXTENSION:** Need to ensure it's using `.molten` (not `.moltenplan` or other variations)

**Test Coverage:** TBD - Needs investigation

**Note:** This enables community sharing of tutorials and project ideas between Molten users.

---

### Workflow 14: Create Logbook Entries as Project Instances

**User Journey:**
> Create a logbook entry as an instance of a project. For example, create a project explaining how to make a vortex marble, then each time you make one, create a logbook entry tied to that project. View all logbook entries associated with a specific project.

**Implementation Location:** Logbook view, project-logbook linking

**Features to Test:**
- Create logbook entry from a project
- Link logbook entry to parent project
- Logbook entry inherits project details/steps as template
- View all logbook entries for a given project
- Logbook entry tracks:
  - Date/time of creation
  - Photos of actual work
  - Notes about this specific instance
  - Variations from the original project
  - Results/outcomes
- Navigate between project and its logbook instances
- Filter logbook by project
- Unlink logbook entry from project (if needed)

**Test Coverage:** TBD - Needs investigation

**Note:** This creates a project-template → logbook-instance relationship, allowing you to track multiple attempts at the same technique.

---

### Workflow 15: Standalone Logbook Entries with Completion Tracking

**User Journey:**
> Create standalone logbook entries (not tied to a project), track completion status (when completed, what happened to the piece - sold/broke/kept/etc.), and record sale price if sold. View saved logbook entries.

**Implementation Location:** Logbook view, logbook detail/edit form

**Features to Test:**
- Create logbook entry without linking to project
- Mark logbook entry as complete
- Record completion date
- Select outcome status:
  - Sold
  - Broke
  - Kept
  - Gave away
  - Other outcomes
- Record sale price (when outcome = sold)
- Sale price field is visible and functional
- Click on saved logbook entry to view it
- View all logbook details (photos, notes, glass used, outcomes, etc.)
- Edit logbook entry after creation
- Navigation between logbook list and detail view

**Known Issues/Bugs:**
- 🐛 **BUG:** Sale price/amount field seems to have disappeared from the screen - needs to be restored
- 🐛 **BUG:** Cannot click on a saved logbook entry to view it - clicking should open detail/view mode

**Test Coverage:** TBD - Needs investigation

**Note:** Logbooks can either be standalone entries or instances of projects (Workflow 14).

**Future Enhancement (Post-Launch):**
- 💡 Feature requested: Automatically deduct glass used from inventory when marking a logbook/project as complete - not planned for initial launch

---

### Workflow 16: QR Code Scanning for Inventory Management

**User Journey:**
> Scan a QR code on a glass item to quickly remove it from inventory (or potentially add it to inventory).

**Implementation Location:** QR code scanner, inventory actions

**Features to Test:**
- QR code scanner functionality
- Scan QR code to identify glass item
- Option to remove scanned item from inventory
- Option to add scanned item to inventory (?)
- Confirm action before removing/adding
- Update inventory counts after scan
- Handle invalid/unrecognized QR codes
- Handle items not in catalog
- Scanning multiple items in sequence
- Undo accidental removals

**Known Issues/Questions:**
- ⚠️ **FEATURE PLANNING:** Planned feature - still want to add this
- ⚠️ **UNCLEAR:** Should we allow adding to inventory via QR scan? Might not be smart/practical

**Test Coverage:** TBD - Needs investigation (feature not yet implemented)

**Note:** This would streamline inventory management by using QR codes on physical glass items.

---

### Workflow 18: Create and Manage Recipes (Frit Mixes, Custom Colors, Cane Twists)

**User Journey:**
> Record recipes for frit mixes, custom colors, or twisted cane combinations (like techniques from advanced flameworking books). List glass colors with optional proportions, and add photos of color arrangements, mixed frit, and/or final results.

**Implementation Location:** Recipes view/section

**Features to Test:**
- Create new recipe
- Add recipe name/title
- List glass colors/items used in recipe
- Specify proportions for each color (optional)
- Add multiple photos:
  - Color arrangement photos
  - Mixed frit photos
  - Final result photos
- Edit existing recipes
- Delete recipes
- Search/filter recipes
- View recipe details
- Share recipes with others
- Recipe categories/types:
  - Frit mixes
  - Custom colors
  - Cane twists
  - Other techniques

**Known Issues/Questions:**
- ⚠️ **FEATURE MISSING:** Photos likely don't exist for recipes today - need to add photo support
- 💡 **FEATURE REQUEST:** Should be able to add multiples of a recipe to your shopping list (e.g., "add 3x this recipe")
- 💡 **FEATURE REQUEST:** Check if you have all items from recipe in your inventory (inventory checking)

**Test Coverage:** TBD - Needs investigation

**Note:** Useful for documenting advanced techniques like those from Milon Townsend's advanced flameworking book - mixing colors, twisting canes, creating custom frit blends.

---

### Workflow 19: Create and Manage Kiln Schedules

**User Journey:**
> Create kiln schedules as standalone entries or attach them to projects. The app automatically estimates total duration and draws a heat curve visualization.

**Implementation Location:** Kiln schedules view, project linking

**Features to Test:**
- Create new kiln schedule
- Add schedule segments (ramp rates, hold times, temperatures)
- Save standalone kiln schedule
- Attach kiln schedule to a project
- View kiln schedules list
- Edit existing schedules
- Delete schedules
- **Automatic duration calculation:**
  - Calculate total time based on segments
  - Display estimated completion time
  - Update duration when segments change
- **Heat curve visualization:**
  - Draw graphical heat curve
  - Show temperature over time
  - Visual representation of ramps and holds
  - Curve updates when schedule changes
- Link/unlink schedule from project
- Search/filter kiln schedules

**Known Issues/Questions:**
- 💡 **FEATURE REQUEST:** Add default annealing information display (even if just at bottom of screen) - would be helpful reference
- 💡 **FEATURE REQUEST:** When printing projects as PDFs (Workflow 13), kiln schedules should be included at the bottom of the PDF

**Test Coverage:** TBD - Needs investigation

**Note:** Kiln schedules can be standalone or attached to specific projects for glass firing documentation.

---

### Workflow 20: Track Purchase Records

**User Journey:**
> Record purchases of glass items, track spending, view purchase history.

**Implementation Location:** Purchases view

**Features to Test:**
- Add new purchase record
- Record items purchased, quantities, prices
- Track store/vendor information
- View purchase history
- Filter/search purchases
- Edit purchase records
- Delete purchase records
- Link purchases to inventory additions
- Generate spending reports

**Known Issues/Questions:**
- ⚠️ **IMPLEMENTATION STATUS UNCLEAR:** Purchases feature may not be implemented yet
- ⚠️ **LAUNCH DECISION:** Might need to turn this feature off for launch if not complete

**Test Coverage:** TBD - Needs investigation (feature may not exist)

**Note:** Status of this feature needs to be verified - may need to be disabled for initial release.

---

### Workflow 21: Browse Locations (Stores and Classes)

**User Journey:**
> View stores and classes, filter by technique, get directions to a store, view store information and details.

**Implementation Location:** Locations view

**Features to Test:**
- View list of stores
- View list of classes
- Filter locations by technique (flameworking, fusing, etc.)
- View store details:
  - Name, address, contact info
  - Hours of operation
  - Website/social media links
  - Store description
- Get directions to store (Maps integration)
- View class details:
  - Class name, description
  - Instructor information
  - Schedule/dates
  - Location/venue
  - Registration information
- Search locations
- Filter by distance/proximity
- Save favorite locations
- Add custom stores/classes
- Edit location information

**Known Issues/Questions:**
- 🐛 **BUG:** Seems to have lost the ability to suggest a new location - need to add this back
- 🐛 **UI BUG:** Somehow we have two chevrons to indicate clicking into a row - should only be one
- ⚠️ **MAP BEHAVIOR:** Map shouldn't be able to be rotated, just zoom in/out
- 💡 **FEATURE REQUEST:** Add "Suggest a Change or Deletion" button at the bottom of location detail view
  - Should open the same form as "suggest new location"
  - Form should be pre-filled with existing location information
  - User can then suggest edits or mark for deletion

**Test Coverage:** TBD - Needs investigation

**Note:** Helps users find local glass shops and flameworking/fusing classes.

---

### Workflow 22: Submit Photo for Official Product Image

**User Journey:**
> Submit a photo to be used as the main/official photo for a glass item in the app's catalog (community contribution).

**Implementation Location:** Item detail view, photo submission

**Features to Test:**
- Find "Submit Photo" or similar button/option on item detail
- Select photo from library or take new photo
- Preview photo before submission
- Add optional description/notes about the photo
- Submit photo to review queue
- Confirmation that photo was submitted
- Track submission status
- View submitted photos pending approval
- Receive notification when photo is approved/rejected
- See photo become the main product image after approval

**Known Issues/Questions:**
- ⚠️ **LIKELY BUG:** User photo submission workflow may not be working/tested
- ⚠️ **UNCLEAR:** Does this feature exist? Where is the submit button?
- ⚠️ **UNCLEAR:** What's the approval process? Who reviews submissions?
- ⚠️ **UNCLEAR:** Can users see if their photo was accepted?

**Test Coverage:** TBD - Needs investigation (feature existence unclear)

**Note:** This is different from Workflow 11 (adding personal custom photos) - this is about submitting photos to become the official catalog image everyone sees.

---

### Workflow 23: Settings and Preferences

**User Journey:**
> Access and configure app settings, preferences, account information, and feature toggles.

**Implementation Location:** Settings view

**Features to Test:**
- Navigate to Settings
- View all settings categories
- Update user preferences
- Configure display options
- Manage account settings
- Enable/disable features
- Reset to defaults
- Export/import settings
- Privacy settings
- Notification preferences
- Data management options

**Known Issues/Questions:**
- 🔥 **CRITICAL:** Need to do a **VERY** serious audit and re-organization of the settings screen

**Test Coverage:** TBD - Needs investigation

**Note:** Settings screen needs major reorganization work before launch.

---

### Workflow 24: Inventory Sharing with Expirable Links

**User Journey:**
> Set up a temporary, expirable share of your inventory that others can view.

**Implementation Location:** Inventory view, sharing settings

**Features to Test:**
- Create shareable link for inventory
- Set expiration date/time for share
- Configure what's included in share (all items, filtered items, etc.)
- Share link via various methods (AirDrop, Messages, Email, etc.)
- View shared inventory (recipient perspective)
- Expire share automatically after time limit
- Manually revoke/cancel share before expiration
- View list of active shares
- Edit share settings (extend expiration, change permissions)
- Notifications when share expires

**Test Coverage:** TBD - Needs investigation

**Note:** Enables temporary inventory sharing without permanent access.

---

## Coverage Summary

**Total Workflows Identified:** 24
**Workflows with Full Coverage:** 0
**Workflows with Partial Coverage:** 1 (Workflow 1: Unit tests strong, UI tests missing)
**Workflows with No Coverage:** 23 (Workflows 2, 9, 15, 17, 21, 22, 23: BUGS/ISSUES; Workflows 3-8, 10-14, 16, 18-20, 24: TBD - includes planned/incomplete features)

---

## 🚨 FEATURE FLAG ANALYSIS (FeatureFlags.swift)

This section reorganizes bugs and features based on what's **enabled in production** (must fix before launch) vs **disabled** (can fix post-launch).

### 📊 Quick Summary

**ENABLED = MUST FIX FOR LAUNCH:**
- 13 critical bugs/todos in enabled features
- Top priority: COE filter (enabled but broken!), label printing crash, shopping checkout UX, inventory notes not saving
- Must test: Import/export, catalog updates, inventory sharing

**DISABLED = POST-LAUNCH:**
- 7 bugs in disabled features (Projects, Kiln Schedules, Purchases, Recipes, Tools)
- Can defer until features are re-enabled

### ✅ ENABLED IN PRODUCTION - MUST WORK FOR LAUNCH

**Core Features (Always On):**
- Glass catalog and inventory (always enabled)
- Coatings (`ENABLE_COATINGS = true`)
- Shopping Lists (`ENABLE_SHOPPING_LISTS = true`)
- Data Export (`ENABLE_DATA_EXPORT = true`)
- Data Import (`ENABLE_DATA_IMPORT = true`)
- Catalog Updates/Downloads (`ENABLE_CATALOG_UPDATES = true`)
- COE Glass Filter (`coeGlassFilter = true`)

**🔥 CRITICAL BUGS IN ENABLED FEATURES (Fix Before Launch):**

10. **TODO:** Test inventory import/export (ENABLED: `ENABLE_DATA_IMPORT/EXPORT = true`)
    - Existing features need testing
    - Explore server-side improvements

12. **Workflow 11:** Photo UI inconsistency (ENABLED: Throughout app)
    - Should say "Add a Photo" not "Select a Photo"


### ❌ DISABLED IN PRODUCTION - CAN FIX POST-LAUNCH

**Disabled Features:**
- Tools (`ENABLE_TOOLS = false`)
- Projects (`ENABLE_PROJECTS = false`)
- Kiln Schedules (`ENABLE_KILN_SCHEDULES = false`)
- Purchases (`ENABLE_PURCHASES = false`)
- Recipes (`ENABLE_RECIPES = false`)

**🐛 BUGS IN DISABLED FEATURES (Post-Launch Priority):**

1. **Workflow 10:** Project viewing mix of edit/view modes (DISABLED: `ENABLE_PROJECTS = false`)
   - Critical UX issue but feature is disabled
   - Can fix when re-enabling projects

2. **Workflow 14:** Create logbook entries as project instances (DISABLED: `ENABLE_PROJECTS = false`)
   - Feature disabled for launch

3. **Workflow 15:** Standalone logbook entries (DISABLED: `ENABLE_PROJECTS = false`)
   - Sale price field disappeared
   - Cannot click to view saved entries
   - Feature disabled for launch

4. **Workflow 19:** Kiln schedules (DISABLED: `ENABLE_KILN_SCHEDULES = false`)
   - Feature disabled for launch
   - Enhancements can wait

5. **Workflow 20:** Purchases feature (DISABLED: `ENABLE_PURCHASES = false`)
   - May not be implemented
   - Feature explicitly disabled

6. **Workflow 18:** Recipes missing photo support (DISABLED: `ENABLE_RECIPES = false`)
   - Feature disabled for launch

7. **Workflow 13:** Project file format naming (DISABLED: `ENABLE_PROJECTS = false`)
   - Says "moltenplan" - should be ".molten"
   - Not critical since projects disabled

**💡 FUTURE FEATURES (Post-Launch):**

1. **Workflow 16:** QR code scanning (Not yet implemented)
2. **Workflow 15:** Auto-deduct glass on project completion (Future enhancement)
3. **Eyedropper tool:** Extract color from photos
4. **Color-based search:** Search by hex color with distance
5. **OCR on images:** Extract text from images for search
6. **Physical inventory counting using QR codes:** Scan inventory QR code labels to perform physical inventory counts/audits

---

## Bugs and Issues Summary

### 🔥 Critical Bugs (Must Fix Before Launch)

1. **Workflow 2:** Notes not saved when adding inventory item
   - Notes field exists and collects input but never calls UserNotesRepository
   - Zero test coverage for this functionality

2. **Workflow 17:** Label printing screen crashes entire app
   - Major test coverage gap - this wasn't caught in any tests
   - Described as "our most awesome feature" but completely broken

3. **Workflow 22:** Settings screen needs VERY serious audit and re-organization
   - Critical UX issue affecting discoverability and usability

### 🐛 High Priority Bugs

4. **Workflow 9:** Shopping checkout experience is very confusing
   - Critical UX issue - entire checkout experience needs complete overhaul
   - Missing checkout button (instructions reference it but doesn't exist)
   - Unclear if quantity can be modified in shopping mode

5. **Workflow 15:** Two logbook bugs
   - Sale price/amount field has disappeared from screen
   - Cannot click on saved logbook entry to view it

6. **Workflow 10:** Project viewing is awful mix of edit/view modes
   - Critical UX issue - need clear separation between view and edit

7. **Workflow 21:** Multiple location issues
   - Lost ability to suggest new location
   - Two chevrons showing instead of one on rows
   - Map rotation should be disabled (zoom only)

8. **Workflow 22:** User photo submission for official catalog images
   - Likely bug - workflow may not be working or tested
   - Unclear if feature exists, where submit button is located
   - Approval process unclear

9. **Settings:** COE filter doesn't work anymore
   - COE filter in Settings is broken/non-functional
   - Users cannot filter catalog by COE rating (90, 96, 104) via Settings
   - Needs investigation and fix
   - Test coverage needed for COE filter functionality

10. **Image Display:** Incorrect fallback text shown when gradient not displayed
    - Text about "approximating the image when we don't have permission" appears even when no gradient is being displayed
    - This text should only appear when we're actually showing a gradient fallback
    - Need to fix conditional logic: Only show explanation text when gradient is actually present
    - Confusing to users who see the message but no gradient
    - **Test Coverage Needed:**
      - [ ] Verify text only appears when gradient is displayed
      - [ ] Test with photo permissions granted (no text, real image)
      - [ ] Test with photo permissions denied (text + gradient shown)
      - [ ] Test when image is missing/unavailable (no text if no gradient)
      - [ ] Test different image states (loading, error, missing)

### ⚠️ Missing/Incomplete Features

11. **Workflow 20:** Purchases feature may not be implemented
    - Status unclear - might need to disable for launch

12. **Workflow 18:** Recipes missing photo support
    - Photos likely don't exist in recipes today

13. **Workflow 11:** Photo UI inconsistency
    - Should say "Add a Photo" not "Select a Photo" everywhere

14. **Workflow 13:** File format naming issues
    - Currently says "moltenplan" - should not specify that
    - Need to ensure using `.molten` extension (not `.moltenplan`)

### 💡 Feature Requests (Post-Launch)

15. **Workflow 10/18:** Inventory checking and shopping list integration
    - Check if you have recipe/project items in inventory
    - Add recipe/project items to shopping list (with multiples)

16. **Workflow 15:** Auto-deduct glass from inventory on project completion
    - Requested feature, not planned for initial launch

17. **Workflow 16:** QR code scanning for inventory management
    - Planned feature - still want to add
    - Unclear if adding via QR scan is smart

18. **Workflow 19:** Kiln schedule enhancements
    - Add default annealing info display
    - Include schedules in project PDFs

19. **Workflow 21:** Location suggestion improvements
    - Add "Suggest a Change or Deletion" button with pre-filled form

---

## Test Coverage Priorities (Based on Feature Flags)

### 🔥 CRITICAL - ENABLED FEATURES (Fix Before Launch)

**Immediate Action Required:**
1. **Fix COE filter** (Feature flag enabled but broken!)
2. **Add UI test** for label printing crash (Workflow 17 - Core inventory)
3. **Add unit tests** for notes saving when adding inventory (Workflow 2 - Core inventory)
4. **Fix and test shopping mode checkout flow** (Workflow 9 - `ENABLE_SHOPPING_LISTS = true`)
5. **Test inventory import/export** (`ENABLE_DATA_IMPORT/EXPORT = true`)
6. **Test catalog updates/downloads** (`ENABLE_CATALOG_UPDATES = true`)

**High Priority - ENABLED Features:**
- Fix image display fallback text bug (Core catalog)
- Test and fix location features (Workflow 21 - Core locations)
  - Verify store suggestion works
  - Fix multiple chevrons bug
  - Disable map rotation
- Fix photo UI inconsistency ("Add a Photo" not "Select a Photo")
- Add accessibility identifiers to enabled feature elements
- Create end-to-end UI tests for critical enabled features:
  - Catalog browsing and search
  - Inventory management (add, edit, delete)
  - Shopping list workflows
  - Import/export workflows
- Test inventory sharing with expirable links (Workflow 24)
- Verify user photo submission workflow (Workflow 22)

**Medium Priority - ENABLED Features:**
- Unit tests for filtering/sorting in catalog and inventory
- Settings screen re-organization audit (UX improvement)
- Coatings catalog and inventory tests (`ENABLE_COATINGS = true`)

### ⏳ POST-LAUNCH - DISABLED FEATURES (Lower Priority)

**Projects** (`ENABLE_PROJECTS = false`):
- Test project view/edit mode separation (Workflow 10)
- Fix logbook viewing bugs (Workflow 15)
- Test logbook entries as project instances (Workflow 14)
- Fix project file format naming (Workflow 13)
- Integration tests for project/recipe inventory checking

**Kiln Schedules** (`ENABLE_KILN_SCHEDULES = false`):
- Tests for kiln schedule calculations and visualization (Workflow 19)

**Purchases** (`ENABLE_PURCHASES = false`):
- Complete purchases feature implementation and testing (Workflow 20)

**Recipes** (`ENABLE_RECIPES = false`):
- Add photo support and testing (Workflow 18)

**Tools** (`ENABLE_TOOLS = false`):
- Tools catalog and inventory tests (when re-enabled)

**Future Features** (Not yet implemented):
- QR code scanning tests (Workflow 16)
- Eyedropper tool tests
- Color-based search tests
- OCR on images tests

---

## Notes

- This document is actively being updated during manual testing sessions
- Each workflow entry includes:
  - Description of the workflow
  - Current test coverage status
  - Recommended tests to add
  - Implementation notes

## Future Work / Technical Debt

### Platform Expansion
- ⌚ **Apple Watch App**
  - Feature request: Add watchOS companion app
  - Potential features:
    - Quick inventory lookup
    - Shopping list view/checklist
    - QR code scanning for quick inventory removal
    - View project steps while working
    - Timer for kiln schedules
    - Low stock notifications
  - Would require watchOS-specific UI/UX design
  - Needs consideration for what features make sense on watch vs phone

### Code Quality Review (When Budget Allows)
- 📝 **Request non-idiomatic Swift code review**
  - When weekly budget has room to spare
  - Likely have missed Swift best practices throughout codebase
  - Would benefit from expert review of Swift idioms and patterns
  - Could improve code maintainability and performance

### OCR (Optical Character Recognition) on Images
- 🔍 **Image OCR for Search**
  - **FEATURE:** App can perform OCR on images to extract text
  - **USE CASE:** When searching, OCR text from images is included in search results
  - **CRITICAL GAP:** 🚨 **NO TESTING** - This feature has NEVER been tested!
  - **Test Coverage Needed:**
    - [ ] Unit tests: OCR text extraction from images
    - [ ] Integration tests: OCR results stored/indexed for search
    - [ ] Search tests: Verify items with text in images appear in search results
    - [ ] Performance tests: OCR processing time for various image types
    - [ ] Edge cases:
      - Images with no text
      - Images with poor quality/unreadable text
      - Images with multiple languages
      - Large images
      - Images with handwriting vs printed text
    - [ ] UI tests: End-to-end workflow of adding image → searching for text in image → finding item
  - **Questions to Answer:**
    - Which images are processed? (User images only? Manufacturer images? All images?)
    - When does OCR occur? (On upload? Async background job? On-demand during search?)
    - Where is OCR text stored? (Core Data attribute? Separate index? In-memory cache?)
    - What OCR library/framework is used? (Vision framework? Third-party?)
    - Does OCR work offline or require network?
    - Are users notified when OCR is processing or complete?
    - Can users manually trigger OCR re-processing if it failed?
  - **Implementation Location:** TBD - Needs investigation
  - **Repositories Involved:** Likely UserImageRepository, Search utilities
  - **Performance Concerns:** OCR can be computationally expensive - needs testing with large image sets

### Color-Based Search
- 🎨 **Search by Hex Color with Distance/Similarity**
  - **FEATURE REQUEST:** Allow users to search for glass items by hex color code and find similar colors within a specified distance
  - **USE CASES:**
    - User has a hex color from a design tool (e.g., #FF5733) and wants to find matching glass
    - User wants to find all colors "close to" a specific shade (e.g., within 10% color distance)
    - Color matching for projects - find glass that matches a color palette
    - Find alternatives when exact color match doesn't exist
  - **Implementation Considerations:**
    - **Color Distance Algorithm:**
      - Use Delta E (ΔE) color difference formula (industry standard for perceptual color distance)
      - Consider CIEDE2000 algorithm (most accurate perceptual difference)
      - Alternative: Euclidean distance in RGB/HSL color space (simpler but less accurate)
    - **User Interface:**
      - Color picker to select target color
      - Hex input field for direct hex code entry
      - Slider to adjust "similarity threshold" (how close colors must be)
      - Visual feedback showing color distance (e.g., "95% match", "Close", "Similar")
      - Preview of selected color vs item colors
    - **Data Requirements:**
      - Glass items need color data (hex codes or RGB values)
      - May need to extract dominant colors from product images if not in catalog data
      - Consider storing multiple colors per item (some glass has multiple colors/patterns)
    - **Performance:**
      - Color distance calculation for thousands of items could be expensive
      - Consider pre-computing color clusters/indexing for faster search
      - Cache color distance calculations
  - **Test Coverage Needed:**
    - [ ] Unit tests: Color distance calculation algorithms
    - [ ] Unit tests: Hex code validation and parsing
    - [ ] Unit tests: RGB/HSL/LAB color space conversions
    - [ ] Search tests: Find items within color distance threshold
    - [ ] Search tests: Handle invalid hex codes gracefully
    - [ ] Search tests: Handle items without color data
    - [ ] Performance tests: Color search with large catalog (2,659+ items)
    - [ ] UI tests: Enter hex code → adjust threshold → verify results update
    - [ ] Edge cases:
      - Invalid hex codes (#GGG, #12, etc.)
      - Extreme thresholds (0%, 100%)
      - Items with no color data
      - Black/white/transparent colors
      - Multicolor glass items
  - **Questions to Answer:**
    - Does catalog data include color information? If not, how to obtain it?
    - Should this work with user-uploaded images? (Extract dominant color from photo)
    - What's a reasonable default threshold? (e.g., ΔE < 10 = very similar)
    - Should results be sorted by color similarity?
    - How to handle multicolor glass (strikers, frits, dichroic)?
    - Should this be a filter or a separate search mode?
  - **Implementation Location:**
    - Add to search/filter UI in CatalogView, InventoryView, ShoppingListView
    - Utilities/ColorMatching.swift (new file for color algorithms)
    - May need to extend GlassItemModel with color data
    - Search/filtering logic in ViewModels
  - **Dependencies:**
    - Color science libraries (if not using built-in Swift/SwiftUI)
    - May need Core Image for color extraction from images
  - **User Experience Enhancements:**
    - "Find similar colors" button on item detail view (finds similar to that item's color)
    - Color palette search (upload image, find glass matching colors in the image)
    - Save favorite color searches
    - Color collections/tags (e.g., "warm tones", "earth tones", "pastels")

### Eyedropper Tool for Photo Color Extraction
- 🎨 **Extract Color from Photo & Search for Matching Glass**
  - **FEATURE REQUEST:** Use an eyedropper/color picker tool on iPhone photos to extract a specific color, then search the glass catalog for similar colors
  - **USE CASES:**
    - User sees a color in a photo they want to match with glass
    - User photographs a piece of artwork/design and wants to find matching glass colors
    - User takes photo of existing glasswork to identify colors used
    - User wants to match colors from reference images (Pinterest, Instagram, tutorials)
    - Color matching from real-world objects (flowers, fabrics, painted walls)
  - **User Flow:**
    1. User selects "Find Glass by Photo Color" option
    2. Choose photo from library OR take new photo with camera
    3. Photo opens in eyedropper mode
    4. User taps/drags finger on photo to select exact pixel/color
    5. Show selected color with hex value and preview swatch
    6. Option to adjust selection (zoom, fine-tune position)
    7. Tap "Find Similar Glass" button
    8. App searches catalog using color distance algorithm (see Color-Based Search section)
    9. Results show glass items sorted by color similarity
    10. Can save color for later searches or comparisons
  - **Implementation Considerations:**
    - **Color Extraction:**
      - Use Core Graphics/UIImage to read pixel color at touch point
      - Convert UIColor → RGB → Hex
      - Handle different color spaces (sRGB, Display P3, etc.)
      - Average surrounding pixels for more stable color (e.g., 3x3 or 5x5 pixel area)
    - **User Interface:**
      - **Zoom lens/loupe effect** - Magnified circle showing area around finger (like iOS text selection loupe)
      - Crosshair or reticle showing exact selected pixel
      - Color preview swatch showing selected color
      - Live hex value display as user moves finger
      - "Lock in" button to confirm color selection
      - "Adjust Tolerance" slider (how similar colors must be)
      - Grid overlay option for precision
    - **Photo Handling:**
      - Support PHPickerViewController (iOS 14+) for photo selection
      - Support camera integration for live color picking
      - Handle high-resolution images (downsample if needed for performance)
      - Preserve image orientation (EXIF data)
      - Handle different image formats (JPEG, PNG, HEIC, etc.)
    - **Gesture Support:**
      - Tap to select color at point
      - Drag finger to explore colors in photo
      - Pinch to zoom in/out on photo
      - Double-tap to zoom to 100%
      - Two-finger tap to reset zoom
    - **Color Accuracy:**
      - Account for screen brightness/color temperature
      - Warn if photo has filters applied
      - Option to calibrate colors ("This photo was taken in bright sunlight")
      - Display color in multiple formats (Hex, RGB, HSL)
  - **Test Coverage Needed:**
    - [ ] Unit tests: Extract pixel color from CGImage at coordinates
    - [ ] Unit tests: Convert UIColor → Hex string
    - [ ] Unit tests: Handle different color spaces correctly
    - [ ] Unit tests: Average surrounding pixels algorithm
    - [ ] Unit tests: Handle out-of-bounds touch coordinates
    - [ ] Integration tests: Load photo → extract color → search catalog
    - [ ] Integration tests: Camera photo → extract color → search
    - [ ] Integration tests: High-resolution photo handling (20MP+ images)
    - [ ] UI tests: Select photo → tap color → verify hex displayed
    - [ ] UI tests: Complete flow: photo → eyedropper → search → results
    - [ ] UI tests: Zoom gestures work correctly
    - [ ] Edge cases:
      - Black/white/transparent images
      - Very dark or very bright photos
      - Photos with extreme color casts
      - Corrupted/invalid image files
      - Photos with no color profile
      - Monochrome/grayscale photos
      - Screenshots with UI elements
      - Photos taken in different lighting (daylight, tungsten, fluorescent)
  - **Questions to Answer:**
    - Should this be integrated into existing search UI or separate feature?
    - Can users save multiple colors from same photo? (color palette extraction)
    - Should app detect dominant colors automatically (not just eyedropper)?
    - Can users compare selected color to item details (side-by-side)?
    - Should there be color history (last 10 colors picked)?
    - Can users share/export selected colors (hex codes)?
    - Should this work with screenshots of web pages? (yes/no policy)
  - **Implementation Location:**
    - Views/Catalog/Components/ColorPickerView.swift (new component)
    - Views/Catalog/Components/PhotoEyedropperView.swift (eyedropper UI)
    - Utilities/ColorExtraction.swift (color extraction logic)
    - Utilities/ColorMatching.swift (reuse from Color-Based Search feature)
    - Integration point in CatalogView search/filter UI
  - **Dependencies:**
    - PHPickerViewController (photo selection)
    - UIImagePickerController (camera access) OR AVFoundation for live camera
    - Core Graphics (pixel color extraction)
    - Core Image (optional: color space conversions)
    - Shares color distance algorithm with Color-Based Search feature
  - **User Experience Enhancements:**
    - **Multi-color palette extraction:**
      - Extract 3-5 dominant colors from entire photo
      - "Find glass for all these colors" (project planning)
      - Visual palette display with percentages
    - **Color history & favorites:**
      - Save recent colors picked
      - Bookmark favorite colors with names ("Sky blue from that photo")
      - Export color palettes
    - **Live camera mode:**
      - Point camera at object → see matching glass in real-time
      - AR-style overlay showing "This matches Bullseye 001"
      - Useful in stores or studios
    - **Color comparison:**
      - Compare selected color side-by-side with glass item photos
      - Show color difference percentage
      - "This glass is 92% similar to your photo"
    - **Smart suggestions:**
      - "This looks like a sunset palette - try these warm colors"
      - "For this blue, consider these striker glasses that turn this color when heated"
    - **Integration with other features:**
      - Save color search to project (project planning)
      - Add matching glass to shopping list from photo
      - Tag inventory items with colors extracted from work photos
  - **Accessibility Considerations:**
    - VoiceOver support: Announce selected color ("Red, hex FF0000")
    - High contrast mode support
    - Haptic feedback when color locked in
    - Voice control: "Select color at center"
  - **Performance Considerations:**
    - Downsample very large images (4K+ photos) for faster color extraction
    - Cache extracted colors to avoid recomputation
    - Debounce color updates while dragging (don't update every pixel)
    - Lazy load images (don't load full resolution until needed)
  - **Privacy Considerations:**
    - Photos never leave device (color extraction is local)
    - Request photo library permission with clear explanation
    - User can grant access to individual photos (iOS 14+ limited access)
    - Don't require camera permission unless user chooses camera option
  - **Related Features:**
    - This feature **integrates with** Color-Based Search (uses same color distance algorithm)
    - This feature **enhances** project planning (match colors from inspiration photos)
    - This feature **could feed into** OCR search (extract both colors AND text from photos)

### Inventory Import/Export Testing & Server-Side Improvements
- 📋 **Test & Improve Inventory Import/Export**
  - **TODO:** Need to test existing inventory import/export functionality
  - **TODO:** Explore server-side improvements now that we're using the server more
  - **Current State:**
    - Feature exists but test coverage unknown
    - Implementation details need investigation
    - Server-side capabilities have expanded since original implementation
  - **Testing Needs:**
    - [ ] Test export inventory to file
    - [ ] Test import inventory from file
    - [ ] Test file format validation
    - [ ] Test handling of large inventories (1000+ items)
    - [ ] Test duplicate detection during import
    - [ ] Test merge vs replace strategies
    - [ ] Test import with missing/invalid data
    - [ ] Test cross-device import/export (iOS → iOS)
    - [ ] Test version compatibility (old export format → new app version)
  - **Potential Server-Side Improvements:**
    - **Cloud backup/restore:**
      - Store inventory backups on server (not just local files)
      - Automatic periodic backups
      - "Restore from backup" with date selection
      - Cross-device sync via server (not just CloudKit)
    - **Import validation:**
      - Server-side validation before import
      - Detect malformed data early
      - Provide detailed error messages
      - Suggest corrections for common issues
    - **Smart merge:**
      - Server-side conflict resolution
      - "You have 50 items locally, 75 in backup - merge or replace?"
      - Show preview of changes before applying
      - Undo/rollback capability
    - **Format flexibility:**
      - Support multiple export formats (CSV, JSON, XML)
      - Export to Google Sheets/Excel format
      - Import from competitor apps (standardized formats)
    - **Sharing improvements:**
      - Share inventory with other users via server link
      - Collaborative inventory (shared studios)
      - "Import from [Friend's Name]'s inventory"
  - **Questions to Investigate:**
    - What format is currently used? (JSON? CSV? Custom binary?)
    - Is it human-readable/editable?
    - Does it include all inventory data? (notes, images, locations, etc.)
    - Can users edit exported files manually?
    - Is there version tracking in export format?
    - Does export include catalog data or just references (stable_ids)?
    - How are conflicts handled during import?
    - Is there an undo option after import?
  - **User Experience Improvements:**
    - Progress indicators for large imports/exports
    - Preview before import ("This will add 150 items, update 25, skip 10 duplicates")
    - Export filters (export only COE 90, only low stock, only specific manufacturers)
    - Scheduled automatic exports
    - Email export to self
    - Import from QR code (scan code, auto-import inventory)
  - **Implementation Location:**
    - Likely: Services/DataLoading/ or Services/Coordination/
    - Repository layer for data serialization/deserialization
    - Settings UI for import/export controls
  - **Related to:**
    - CloudKit sync (different mechanism - import/export is manual, CloudKit is automatic)
    - Project sharing (Workflow 13 - similar file format concepts)
    - Backup/restore functionality

### Store Suggestion Verification
- 🏪 **Verify Store Suggestion Workflow Works**
  - **TODO:** Test that suggesting a new store/location works properly
  - **Context:** Workflow 21 noted "Lost ability to suggest new location" - need to verify this
  - **Testing Needs:**
    - [ ] Navigate to Locations/Stores view
    - [ ] Find "Suggest a Store" or "Add Location" button
    - [ ] Fill out store suggestion form
    - [ ] Submit suggestion
    - [ ] Verify submission confirmation
    - [ ] Check if suggestion appears in user's local view (pending approval)
    - [ ] Test form validation (required fields, address format, etc.)
    - [ ] Test photo upload for store suggestion
    - [ ] Test "Suggest a Change" for existing store
    - [ ] Test "Report Closed/Incorrect" for existing store
  - **Expected Behavior:**
    - User can suggest new stores/classes
    - Form includes: Name, Address, Phone, Website, Hours, Description, Photos
    - Submission goes to review queue (server-side)
    - User sees confirmation "Thanks for your suggestion!"
    - Optionally: User can track status of their suggestions
  - **If Broken:**
    - Document exact failure point
    - Check if button is missing or just non-functional
    - Check if server endpoint exists and is reachable
    - Verify network requests are being sent
    - Check error logs for submission failures
  - **Related Issues:**
    - Workflow 21 bug: "Lost ability to suggest new location"
    - Also need "Suggest a Change or Deletion" feature (not yet implemented)
  - **Implementation Location:**
    - Views/Locations/ (location browsing and suggestion UI)
    - Likely needs server API endpoint for submissions
    - Form validation and submission logic

### Catalog Update Notifications with Smart Download Management
- 📦 **Check for Catalog Updates & Notify Before Download**
  - **FEATURE REQUEST:** Check for catalog updates and notify users about availability, size, and estimated download time before actually downloading
  - **USE CASES:**
    - User is on cellular - see update is available, see it's 50MB, decide to wait for WiFi
    - User is on WiFi - see update is 50MB (~30 seconds), download immediately
    - User wants to know what's new before downloading (changelog/release notes)
    - User wants to defer download to later (e.g., before bed, when charging)
    - User has limited storage - know catalog size before downloading
  - **User Flow:**
    1. App checks for updates (background or manual refresh)
    2. If update available → Show notification/banner
    3. Display update info:
       - Catalog version (e.g., "v2.5" or "December 2025")
       - File size (e.g., "52.3 MB")
       - What's new (new items, updated prices, discontinued items)
       - Estimated download time based on connection type
    4. User decides: "Download Now", "Download on WiFi", "Remind Me Later", "Skip This Update"
    5. Download happens in background with progress indicator
    6. Notify when complete and ready to use
  - **Implementation Considerations:**
    - **Update Check Mechanism:**
      - Lightweight metadata endpoint (JSON response with version, size, checksum, changelog)
      - Check on app launch (if last check > 24 hours)
      - Manual "Check for Updates" button in Settings
      - Background fetch for periodic checks (iOS Background App Refresh)
    - **Network Detection:**
      - Use NWPathMonitor to detect WiFi vs Cellular vs Ethernet
      - Detect expensive connections (cellular roaming, hotspot)
      - Respect user's Low Data Mode setting
    - **Download Time Estimation:**
      - Measure actual download speed during first few KB
      - Provide ranges: "30 sec - 2 min" (WiFi), "5-15 min" (4G), "15-45 min" (3G)
      - Historical data: track past download speeds to improve estimates
      - Conservative estimates (better to underestimate than disappoint)
    - **Storage Considerations:**
      - Check available disk space before offering download
      - Warn if space is tight (e.g., "Update needs 50MB, you have 120MB free")
      - Clean up old catalog versions after successful update
    - **Download Management:**
      - Pausable/resumable downloads (URLSession background tasks)
      - Download progress indicator (percentage, MB downloaded/total)
      - Cancel download option
      - Verify download integrity (checksum validation)
      - Atomic replacement (don't delete old catalog until new one is verified)
    - **User Preferences:**
      - Setting: "Auto-download on WiFi only"
      - Setting: "Auto-download on any connection"
      - Setting: "Always ask before downloading"
      - Setting: "Check for updates automatically" (on/off)
  - **Test Coverage Needed:**
    - [ ] Unit tests: Parse update metadata JSON
    - [ ] Unit tests: Calculate download time estimates
    - [ ] Unit tests: Validate network type detection
    - [ ] Unit tests: File size formatting (bytes → MB/GB)
    - [ ] Unit tests: Checksum validation
    - [ ] Integration tests: Download catalog over simulated slow connection
    - [ ] Integration tests: Resume interrupted download
    - [ ] Integration tests: Handle corrupt download (bad checksum)
    - [ ] Integration tests: Handle insufficient storage
    - [ ] Integration tests: Replace old catalog with new one atomically
    - [ ] UI tests: See update notification → view details → download
    - [ ] UI tests: Defer download to WiFi → switch to WiFi → auto-download
    - [ ] UI tests: Cancel in-progress download
    - [ ] Edge cases:
      - No internet connection
      - Connection drops mid-download
      - Server returns invalid metadata
      - User has latest version (no update available)
      - Multiple rapid checks for updates
      - App backgrounded/killed during download
      - Disk full during download
  - **Questions to Answer:**
    - Where is catalog hosted? (App Store asset delivery? CDN? Custom server?)
    - What format is catalog? (SQLite database? JSON? Zip archive?)
    - How are versions tracked? (Semantic versioning? Date-based? Build number?)
    - Should updates be incremental (delta updates) or full catalog replacement?
    - What's included in "what's new"? (Item count changes? Specific new items? Changelog?)
    - Should users be able to rollback to previous catalog version?
    - How to handle failed updates? (Retry? Stay on old version? Alert user?)
    - Should there be a "force update" mechanism for critical catalog bugs?
  - **Implementation Location:**
    - Services/DataLoading/CatalogUpdateService.swift (new service)
    - Utilities/NetworkMonitor.swift (network type detection)
    - Utilities/DownloadManager.swift (download handling with progress)
    - Views/Settings/ (update preferences)
    - App/MoltenApp.swift (background update checks)
    - UI: Banner/sheet in CatalogView or app-wide notification
  - **Dependencies:**
    - NWPathMonitor (network monitoring)
    - URLSession background tasks (downloads)
    - UserDefaults (last update check timestamp, user preferences)
    - Possibly Background App Refresh entitlement
  - **User Experience Enhancements:**
    - Changelog view: "What's New in This Update"
      - X new items added
      - Y items updated (price changes, new images, etc.)
      - Z items discontinued
      - List of notable additions (e.g., "50 new Effetre colors")
    - Update history: View past catalog versions and when they were installed
    - Bandwidth usage tracking: "This month: 150MB catalog updates"
    - Smart scheduling: "Download tonight at 2 AM when charging on WiFi"
    - Notification badges: Show update availability in Settings tab
  - **Performance & Battery Considerations:**
    - Don't check for updates more than once per day (unless manual)
    - Use background fetch (not continuous polling)
    - Compress metadata responses (gzip)
    - Cache metadata to avoid redundant checks
    - Pause downloads when battery is low (<20%) unless charging
  - **Privacy Considerations:**
    - Update checks reveal app usage patterns - minimize data sent
    - Don't send user inventory/project data when checking for updates
    - Only send: app version, current catalog version, platform (iOS version)
    - Allow users to disable automatic update checks entirely

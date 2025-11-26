# Manual Testing Checklist

This document lists features that require explicit manual testing because they cannot be reliably tested with XCUITest automation.

## Why Manual Testing is Required

SwiftUI's `NavigationLink` combined with iOS 17+'s `NavigationStack` has a known issue where XCUITest taps on list items don't trigger navigation. The accessibility identifier is placed on the inner button, and while XCUITest can find and tap the element, the navigation action doesn't fire.

This affects any workflow that requires:
1. Tapping a list item to navigate to a detail view
2. Testing interactions within that detail view

---

## Inventory Detail Workflow (Workflow 1)

**Pre-requisite**: Ensure inventory has at least one item (Settings > Debug Settings > Test Data Generator)

### Navigation Tests

- [ ] **Navigate to Item Detail**
  1. Open Inventory tab
  2. Tap any inventory item
  3. Verify: Detail view appears with item information and Actions menu button in toolbar

- [ ] **Navigate Back from Detail**
  1. From inventory detail view, tap back button
  2. Verify: Returns to inventory list

### Manufacturer Notes Tests

- [ ] **Expand/Collapse Manufacturer Notes**
  1. Navigate to item detail (for an item with manufacturer notes)
  2. Look for "Show More" or expand button for manufacturer notes
  3. Tap to expand - verify full notes are visible
  4. Tap again to collapse - verify notes are truncated
  5. Verify: App remains responsive throughout

### FAB (Floating Action Button) Menu Tests

All FAB tests start from the item detail view:

- [ ] **Add to Inventory**
  1. Tap Actions menu (ellipsis button in toolbar)
  2. Tap "Add to Inventory"
  3. Verify: Add inventory form appears (or upgrade prompt if not premium)
  4. Tap Cancel to dismiss

- [ ] **Add to Shopping List**
  1. Tap Actions menu
  2. Tap "Add to Shopping List"
  3. Verify: Shopping list options sheet appears
  4. Tap Cancel to dismiss

- [ ] **Add Note**
  1. Tap Actions menu
  2. Tap "Add Note"
  3. Verify: Notes editor appears with Save/Cancel buttons
  4. Tap Cancel to dismiss

- [ ] **Manage Tags**
  1. Tap Actions menu
  2. Tap "Manage Tags"
  3. Verify: Tags editor appears with Done button
  4. Tap Done to dismiss

- [ ] **Add Image**
  1. Tap Actions menu
  2. Tap "Add Image"
  3. Verify: Photo picker appears (system picker)
  4. Tap Cancel to dismiss

### User Notes Tests

- [ ] **Expand User Notes**
  1. Navigate to item detail (for an item with user notes)
  2. Look for expand button for user notes section
  3. Tap to expand
  4. Verify: Full user notes are visible

### Manufacturer Link Tests

- [ ] **Manufacturer Website Link**
  1. Navigate to item detail (for an item with manufacturer website)
  2. Look for manufacturer website link
  3. Verify: Link is visible and tappable (don't tap - opens Safari)

### Complete Workflow Tests

- [ ] **Add Tag Workflow**
  1. Navigate to item detail
  2. Tap Actions menu > Manage Tags
  3. In tag editor, type a new tag name (e.g., "test-tag")
  4. Tap Add button
  5. Tap Done
  6. Verify: Returns to detail view
  7. (Optional) Re-open tags to verify tag was saved

---

## Add Inventory - Notes Verification (Workflow 2)

The `AddInventoryUITests.testNotesAreSavedWithInventory` test attempts to verify notes are saved by navigating to the item detail after saving. This navigation step fails due to the same NavigationLink issue.

**Pre-requisite**: Have the Add Inventory form ready

- [ ] **Verify Notes Are Saved with Inventory**
  1. Open Inventory tab
  2. Tap Add button to open Add Inventory form
  3. Search and select a glass item (e.g., search "clear")
  4. Enter quantity (e.g., "5")
  5. Scroll down to Notes field
  6. Enter a unique note (e.g., "Manual Test Note - Should Be Saved")
  7. Tap Save
  8. **After form dismisses, tap the newly added inventory item**
  9. Verify: "Your Notes" section appears in detail view
  10. Verify: The note text you entered is visible

**Why this needs manual testing**: The automated test can fill the form and save, but cannot navigate to the detail view to verify the note was actually persisted.

---

## Automated Tests Status

### Tests That Work (No Navigation Required)

These UI test files work because they don't require tapping list items to navigate to detail views:

**ShoppingListUITests.swift** - All tests work:
- `testShoppingListAccess` - Tab navigation
- `testEnterShoppingMode` - Toolbar button
- `testCancelShoppingMode` - Toolbar button
- `testCheckoutButtonVisibility` - List-level interaction
- `testCheckoutSheetOpens` - Sheet presentation
- `testAddItemToShoppingList` - Toolbar button + sheet
- `testAddItemToBasket` - List-level tap (toggles checkbox, doesn't navigate)
- `testCompleteCheckoutWorkflow` - End-to-end at list level
- `testStoreFilter` - Toolbar button
- `testShoppingModeInstructions` - Toolbar button

**InventoryListUITests.swift** - All tests work (list-level, no detail navigation):
- `testSearchBarExists` - Search field presence
- `testSearchFiltersResults` - Search filtering
- `testClearSearchRestoresResults` - Clear search
- `testTagsFilterSheet` - Tags filter sheet
- `testCOEFilterSheet` - COE filter sheet
- `testManufacturerFilterSheet` - Manufacturer filter sheet
- `testSortOptionChange` - Sort options
- `testInventoryMenuOpens` - Menu access
- `testMenuAddInventory` - Menu > Add Inventory
- `testMenuInventorySharing` - Menu > Sharing
- `testMenuPrintLabels` - Menu > Print Labels
- `testAddButtonOpensForm` - Toolbar add button
- `testEmptyStateDisplay` - Empty state
- `testPullToRefresh` - Refresh gesture
- `testClearFiltersFromEmptyState` - Clear filters
- `testLocationFilter` - Location filter
- `testInventoryTypeFilter` - Type filter

**AddInventoryUITests.swift** - Most tests work:
- `testAddInventoryFormOpens` - Toolbar button
- `testAddInventoryFormCancel` - Sheet interaction
- `testGlassItemSearch` - Form interaction
- `testQuantityField` - Form interaction
- `testTypePicker` - Form interaction
- `testLocationField` - Form interaction
- `testNotesFieldExists` - Form interaction
- `testSaveButtonDisabledWithoutRequiredFields` - Form validation
- `testCompleteAddInventoryWorkflow` - Form workflow
- `testAddInventoryViaMenu` - Menu interaction
- ~~`testNotesAreSavedWithInventory`~~ - **FAILS** (requires navigation to detail)

**LabelPrintingUITests.swift** - All tests work:
- `testLabelDesignerOpensWithoutCrash` - Menu navigation
- `testLabelDesignerBasicNavigation` - Designer UI
- `testLabelFormatSelection` - Designer interaction
- `testPresetManagement` - Designer interaction
- `testPDFGeneration` - Designer interaction
- `testLabelBuilderFieldToggles` - Designer interaction

### Tests That Fail (Navigation Required)

**InventoryDetailUITests.swift** - All tests fail due to navigation issue:
- `testNavigateToItemDetail`
- `testNavigateBackFromDetail`
- `testExpandCollapseManufacturerNotes`
- `testFABAddInventory`
- `testFABAddToShoppingList`
- `testFABAddNote`
- `testFABManageTags`
- `testFABAddImage`
- `testExpandUserNotes`
- `testManufacturerWebsiteLink`
- `testAddTagWorkflow`

---

## Future Workflows

If these views use NavigationLink for list-to-detail navigation, they will likely have the same issue:

### Catalog Detail Workflow
- Tapping catalog item to view glass details
- Would need manual testing if automated tests fail

### Purchase Detail Workflow
- Tapping purchase record to view line items
- Would need manual testing if automated tests fail

### Project Detail Workflow
- Tapping project to view steps/logs
- Would need manual testing if automated tests fail

---

## Testing Tips

1. **Test on Physical Device**: Some XCUITest issues only appear in simulator
2. **Test on Multiple iOS Versions**: iOS 17+ uses NavigationStack differently
3. **Check Landscape Mode**: Some UI issues only appear in landscape orientation
4. **Enable Premium Mode**: Settings > Debug Settings > Override Subscription > Premium

---

## Related Issues

- SwiftUI NavigationLink + XCUITest: Known issue where taps don't trigger navigation
- iOS 17+ NavigationStack: Changed how navigation works internally
- Accessibility identifiers on NavigationLink: Placed on inner Button, not the cell

---

*Last updated: November 2024*

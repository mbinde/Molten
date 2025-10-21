# 📱 CloudKit Multi-Device Sync Testing Guide

## Overview
This guide will help you manually verify that user-uploaded images sync correctly across your devices via CloudKit.

---

## 🔧 Prerequisites

### 1. **Verify CloudKit is Enabled in Xcode**

1. Open your Xcode project
2. Select the **Molten** target
3. Go to **Signing & Capabilities** tab
4. Verify **iCloud** capability is present
5. Ensure these are checked:
   - ☑️ CloudKit
   - ☑️ CloudKit Containers (with your container ID)

### 2. **Required Devices**

You'll need **at least 2 devices** with:
- Same iCloud account signed in
- iOS 17.0+ (or your minimum deployment target)
- Good internet connection (WiFi recommended)

**Recommended setup:**
- Device A: Your iPhone
- Device B: iPad, another iPhone, or iOS Simulator signed into same iCloud account

### 3. **Pre-Test Setup**

1. **Sign into same iCloud account on both devices**
   - Settings → [Your Name] → iCloud
   - Verify iCloud Drive is ON

2. **Install Molten app on both devices**
   - Either via Xcode (Debug builds) or TestFlight (Beta builds)

3. **Launch the app on both devices**
   - Verify no crash on launch
   - CloudKit should initialize automatically

---

## 🧪 Test Scenarios

### **Test 1: Basic Image Upload & Sync**

**Goal:** Verify images uploaded on one device appear on another device

#### Steps:

1. **On Device A:**
   ```
   ✓ Open Molten app
   ✓ Navigate to a glass item (e.g., "Bullseye Clear 001")
   ✓ Tap on the item to view details
   ✓ Tap "Add Image" or camera icon
   ✓ Take a photo or select from library
   ✓ Verify image appears immediately on Device A
   ✓ Note the time: __________
   ```

2. **On Device B:**
   ```
   ✓ Wait 10-30 seconds (CloudKit sync delay)
   ✓ Pull to refresh (if your app has this)
   ✓ Navigate to the same glass item
   ✓ Verify the uploaded image appears
   ✓ Note the time it appeared: __________
   ```

**Expected Result:** ✅ Image appears on Device B within 30 seconds

**If it fails:**
- Wait up to 2 minutes (CloudKit can be slow)
- Check internet connection on both devices
- Verify both devices are signed into same iCloud account
- Check Xcode console for CloudKit errors

---

### **Test 2: Image Deletion Sync**

**Goal:** Verify image deletions sync across devices

#### Steps:

1. **On Device B:**
   ```
   ✓ Find the image you uploaded in Test 1
   ✓ Swipe to delete (or tap delete button)
   ✓ Confirm deletion
   ✓ Verify image disappears on Device B
   ✓ Note the time: __________
   ```

2. **On Device A:**
   ```
   ✓ Wait 10-30 seconds
   ✓ Pull to refresh (if available)
   ✓ Navigate to the same glass item
   ✓ Verify the image is gone
   ✓ Note the time it disappeared: __________
   ```

**Expected Result:** ✅ Image deleted on Device A within 30 seconds

---

### **Test 3: Primary Image Replacement**

**Goal:** Verify primary image promotion syncs correctly

#### Steps:

1. **On Device A:**
   ```
   ✓ Upload a primary image (red background)
   ✓ Wait for sync (30 seconds)
   ```

2. **On Device B:**
   ```
   ✓ Verify primary image appears (red)
   ✓ Upload a NEW primary image (blue background)
   ✓ This should demote the red image to alternate
   ```

3. **On Device A:**
   ```
   ✓ Wait 30 seconds
   ✓ Refresh the item
   ✓ Verify primary image is now BLUE
   ✓ Verify red image is now in alternates section (if visible)
   ```

**Expected Result:** ✅ Primary image updated, old primary demoted to alternate

---

### **Test 4: Offline Upload & Sync**

**Goal:** Verify images uploaded offline sync when back online

#### Steps:

1. **On Device A:**
   ```
   ✓ Enable Airplane Mode (Settings → Airplane Mode ON)
   ✓ Open Molten app
   ✓ Navigate to a glass item
   ✓ Upload an image
   ✓ Verify image appears locally (stored in Core Data)
   ✓ Note: CloudKit won't sync yet
   ```

2. **On Device A (still):**
   ```
   ✓ Disable Airplane Mode (turn WiFi/Cellular back ON)
   ✓ Wait 1-2 minutes for CloudKit to sync
   ✓ (CloudKit queues changes while offline)
   ```

3. **On Device B:**
   ```
   ✓ Wait 1-2 minutes
   ✓ Refresh the app
   ✓ Navigate to the same glass item
   ✓ Verify the offline-uploaded image now appears
   ```

**Expected Result:** ✅ Image syncs after coming back online (within 2 minutes)

**If it fails:**
- Wait up to 5 minutes (offline queue can be slower)
- Try closing and reopening the app on Device B
- Check Settings → iCloud → iCloud Drive is ON

---

### **Test 5: Conflict Resolution**

**Goal:** Verify CloudKit handles conflicts gracefully

#### Steps:

1. **Setup - Create conflict scenario:**
   ```
   ✓ Put BOTH devices in Airplane Mode
   ✓ On Device A: Upload image "A" as primary to glass item
   ✓ On Device B: Upload image "B" as primary to SAME glass item
   ✓ Both devices should show their own image locally
   ```

2. **Trigger sync:**
   ```
   ✓ Turn OFF Airplane Mode on Device A (wait 30 seconds)
   ✓ Turn OFF Airplane Mode on Device B (wait 30 seconds)
   ✓ CloudKit will detect conflict and merge
   ```

3. **Verify merge policy:**
   ```
   ✓ On both devices, refresh the glass item
   ✓ One image should be primary (likely the last one synced)
   ✓ The other should be demoted to alternate
   ✓ BOTH images should be present (no data loss)
   ```

**Expected Result:** ✅ Both images preserved, one as primary, one as alternate

**Note:** CloudKit uses `NSMergeByPropertyStoreTrumpMergePolicy`, so the "last write wins" but both images are kept.

---

### **Test 6: Multiple Images Per Item**

**Goal:** Verify multiple images sync correctly

#### Steps:

1. **On Device A:**
   ```
   ✓ Upload 5 images to the same glass item
     - 1 primary
     - 4 alternates
   ✓ Wait 30 seconds
   ```

2. **On Device B:**
   ```
   ✓ Navigate to the same glass item
   ✓ Verify all 5 images appear
   ✓ Verify primary image is shown first
   ✓ Verify alternates are in correct order (by date)
   ```

**Expected Result:** ✅ All 5 images sync, correct order

---

### **Test 7: Large Image Sync**

**Goal:** Verify large images are resized and sync efficiently

#### Steps:

1. **On Device A:**
   ```
   ✓ Take a full-resolution photo with camera (12MP+)
   ✓ Upload to glass item as primary
   ✓ Note: App should resize to max 2048px
   ✓ Wait 30 seconds
   ```

2. **On Device B:**
   ```
   ✓ Navigate to the glass item
   ✓ Verify image appears
   ✓ Verify image is NOT full resolution (should be resized)
   ✓ Verify image quality is still good (JPEG 0.85 quality)
   ```

**Expected Result:** ✅ Large image syncs quickly, appears resized

**Performance Check:**
- Upload should take < 5 seconds
- Sync should take < 30 seconds
- Image should look good (not overly compressed)

---

### **Test 8: Different Owner Types**

**Goal:** Verify images for different owner types don't interfere

#### Steps:

1. **On Device A:**
   ```
   ✓ Upload image to Glass Item "A" (ownerType: glassItem)
   ✓ Upload image to Project Plan "B" (ownerType: projectPlan)
   ✓ Upload standalone image (ownerType: standalone)
   ```

2. **On Device B:**
   ```
   ✓ Verify Glass Item "A" shows its image
   ✓ Verify Project Plan "B" shows its image
   ✓ Verify standalone image appears in gallery
   ✓ Verify images don't cross-contaminate
   ```

**Expected Result:** ✅ Each owner type maintains separate images

---

## 📊 Multi-Device Sync Tests (All Data Types)

### **Test 9: Inventory Changes Sync**

**Goal:** Verify inventory quantity changes sync across devices (CRITICAL)

#### Steps:

1. **On Device A:**
   ```
   ✓ Navigate to Catalog
   ✓ Find "Bullseye Clear 001" (or any glass item)
   ✓ View inventory details
   ✓ Add 10 rods to inventory
   ✓ Verify quantity shows 10 on Device A
   ✓ Note the time: __________
   ```

2. **On Device B:**
   ```
   ✓ Wait 10-30 seconds
   ✓ Navigate to same glass item
   ✓ Verify quantity shows 10 rods
   ✓ Deduct 5 rods from inventory
   ✓ Verify quantity now shows 5
   ✓ Note the time: __________
   ```

3. **On Device A:**
   ```
   ✓ Wait 10-30 seconds
   ✓ Refresh the item view
   ✓ Verify quantity shows 5 rods (the change from Device B)
   ```

**Expected Result:** ✅ Inventory changes sync bidirectionally within 30 seconds

---

### **Test 10: Purchase Records Sync**

**Goal:** Verify purchase records sync correctly

#### Steps:

1. **On Device A:**
   ```
   ✓ Navigate to Purchases
   ✓ Create new purchase record
     - Vendor: "Test Vendor"
     - Date: Today
     - Total: $100.00
     - Add 3 items to purchase
   ✓ Save purchase
   ✓ Note the time: __________
   ```

2. **On Device B:**
   ```
   ✓ Wait 30 seconds
   ✓ Navigate to Purchases
   ✓ Verify new purchase appears in list
   ✓ Open purchase details
   ✓ Verify all 3 items present
   ✓ Verify total is $100.00
   ✓ Edit purchase (change total to $95.00)
   ✓ Save changes
   ```

3. **On Device A:**
   ```
   ✓ Wait 30 seconds
   ✓ Refresh purchase list
   ✓ Open same purchase
   ✓ Verify total now shows $95.00
   ```

**Expected Result:** ✅ Purchase records and edits sync correctly

---

### **Test 11: Project Logs Sync**

**Goal:** Verify project logs sync across devices

#### Steps:

1. **On Device A:**
   ```
   ✓ Navigate to Projects
   ✓ Create new project log
     - Title: "Test Project Sync"
     - Status: "In Progress"
     - Add notes
     - Add glass items used
   ✓ Save project
   ✓ Note the time: __________
   ```

2. **On Device B:**
   ```
   ✓ Wait 30 seconds
   ✓ Navigate to Projects
   ✓ Verify "Test Project Sync" appears
   ✓ Open project
   ✓ Verify all details present
   ✓ Update status to "Completed"
   ✓ Add more notes
   ✓ Save changes
   ```

3. **On Device A:**
   ```
   ✓ Wait 30 seconds
   ✓ Refresh projects
   ✓ Open same project
   ✓ Verify status is "Completed"
   ✓ Verify new notes appear
   ```

**Expected Result:** ✅ Project logs and updates sync correctly

---

### **Test 12: User Notes & Tags Sync**

**Goal:** Verify custom notes and tags sync

#### Steps:

1. **On Device A:**
   ```
   ✓ Navigate to a glass item
   ✓ Add user note: "Test note from Device A"
   ✓ Save note
   ✓ Add tag: "TestTag1"
   ✓ Note the time: __________
   ```

2. **On Device B:**
   ```
   ✓ Wait 30 seconds
   ✓ Navigate to same glass item
   ✓ Verify note appears: "Test note from Device A"
   ✓ Verify tag "TestTag1" appears
   ✓ Add another tag: "TestTag2"
   ✓ Edit note: "Updated from Device B"
   ```

3. **On Device A:**
   ```
   ✓ Wait 30 seconds
   ✓ Refresh item
   ✓ Verify note shows "Updated from Device B"
   ✓ Verify both tags appear (TestTag1, TestTag2)
   ```

**Expected Result:** ✅ Notes and tags sync bidirectionally

---

### **Test 13: Shopping List Sync**

**Goal:** Verify shopping list items sync

#### Steps:

1. **On Device A:**
   ```
   ✓ Navigate to Shopping List
   ✓ Add 3 items to shopping list
   ✓ Note the time: __________
   ```

2. **On Device B:**
   ```
   ✓ Wait 30 seconds
   ✓ Navigate to Shopping List
   ✓ Verify all 3 items appear
   ✓ Mark 1 item as purchased
   ✓ Delete 1 item
   ```

3. **On Device A:**
   ```
   ✓ Wait 30 seconds
   ✓ Refresh shopping list
   ✓ Verify 1 item marked as purchased
   ✓ Verify deleted item is gone
   ✓ Verify 1 item still pending
   ```

**Expected Result:** ✅ Shopping list changes sync correctly

---

### **Test 14: Location Management Sync**

**Goal:** Verify storage locations sync

#### Steps:

1. **On Device A:**
   ```
   ✓ Navigate to Settings or Location management
   ✓ Create new location: "Test Shelf A"
   ✓ Note the time: __________
   ```

2. **On Device B:**
   ```
   ✓ Wait 30 seconds
   ✓ Navigate to inventory item
   ✓ Try to assign location
   ✓ Verify "Test Shelf A" appears in location picker
   ✓ Assign item to "Test Shelf A"
   ```

3. **On Device A:**
   ```
   ✓ Wait 30 seconds
   ✓ Navigate to same inventory item
   ✓ Verify location shows "Test Shelf A"
   ```

**Expected Result:** ✅ Locations and assignments sync correctly

---

### **Test 15: Project Plans/Templates Sync**

**Goal:** Verify project templates sync

#### Steps:

1. **On Device A:**
   ```
   ✓ Navigate to Project Plans
   ✓ Create new project template
     - Title: "Test Template"
     - Add steps
     - Add required glass items
     - Set difficulty level
   ✓ Save template
   ✓ Note the time: __________
   ```

2. **On Device B:**
   ```
   ✓ Wait 30 seconds
   ✓ Navigate to Project Plans
   ✓ Verify "Test Template" appears
   ✓ Open template
   ✓ Verify all steps present
   ✓ Verify glass items list correct
   ✓ Edit template (add another step)
   ✓ Save changes
   ```

3. **On Device A:**
   ```
   ✓ Wait 30 seconds
   ✓ Refresh templates
   ✓ Open same template
   ✓ Verify new step appears
   ```

**Expected Result:** ✅ Project templates and edits sync correctly

---

### **Test 16: Cascade Deletions Sync**

**Goal:** Verify that deleting a parent entity deletes related child entities on all devices

#### Steps:

1. **On Device A:**
   ```
   ✓ Create a project log with 3 images attached
   ✓ Wait for sync (30 seconds)
   ```

2. **On Device B:**
   ```
   ✓ Verify project appears with all 3 images
   ✓ Delete the entire project
   ✓ Confirm deletion
   ✓ Note the time: __________
   ```

3. **On Device A:**
   ```
   ✓ Wait 30 seconds
   ✓ Refresh projects list
   ✓ Verify project is deleted
   ✓ Verify project images are also gone (cascade delete)
   ```

**Expected Result:** ✅ Cascade deletions sync correctly, no orphaned data

---

### **Test 17: Complex Multi-Entity Workflow**

**Goal:** Verify complex operations spanning multiple entities

#### Steps:

1. **On Device A:**
   ```
   ✓ Add 20 rods of "Bullseye Red" to inventory
   ✓ Create purchase record for this glass
   ✓ Add to shopping list for future purchase
   ✓ Add note: "Great for holiday projects"
   ✓ Add tag: "Seasonal"
   ✓ Create project plan using this glass
   ✓ Note the time: __________
   ```

2. **On Device B:**
   ```
   ✓ Wait 1 minute (complex sync may take longer)
   ✓ Verify inventory shows 20 rods
   ✓ Verify purchase record exists
   ✓ Verify shopping list item exists
   ✓ Verify note and tag appear
   ✓ Verify project plan includes this glass
   ✓ Deduct 5 rods (simulate project usage)
   ✓ Mark shopping list item as purchased
   ```

3. **On Device A:**
   ```
   ✓ Wait 1 minute
   ✓ Refresh all views
   ✓ Verify inventory now shows 15 rods
   ✓ Verify shopping list item marked purchased
   ✓ Verify all other data intact
   ```

**Expected Result:** ✅ Complex multi-entity operations sync correctly

---

## 🐛 Troubleshooting

### **Images not syncing?**

1. **Check iCloud sync status:**
   ```
   Settings → [Your Name] → iCloud → iCloud Drive
   Should show "On" and syncing
   ```

2. **Check network connection:**
   ```
   Open Safari, load a webpage
   Verify internet works
   ```

3. **Check Xcode Console (during debugging):**
   ```
   Look for errors containing:
   - "CloudKit"
   - "CKError"
   - "NSCloudKitMirroringDelegate"
   ```

4. **Force CloudKit sync:**
   ```swift
   // In Xcode console, you can trigger manual sync:
   // (This is for debugging only, not production)
   po try? await NSPersistentCloudKitContainer.initializeCloudKitSchema(...)
   ```

5. **Common CloudKit errors:**
   - `CKErrorNetworkUnavailable` → Check internet
   - `CKErrorNotAuthenticated` → Sign into iCloud
   - `CKErrorQuotaExceeded` → iCloud storage full
   - `CKErrorZoneBusy` → Wait a few minutes, CloudKit is busy

### **Sync is very slow (> 2 minutes)?**

This can happen if:
- Poor network connection (try WiFi instead of cellular)
- CloudKit servers are busy (rare, but happens)
- Large backlog of changes (first sync after many changes)

**Solution:** Just wait longer. CloudKit guarantees eventual consistency, not immediate sync.

### **Images appear on Device B but not Device A?**

Check:
1. Is Device A's app in the background? (Bring to foreground)
2. Try closing and reopening the app
3. CloudKit syncs both ways, so this indicates a one-way sync issue
4. Check if Device A has CloudKit disabled in Settings

---

## 📊 Test Results Template

Copy this template to track your testing:

```markdown
## CloudKit Sync Test Results

**Date:** _____________
**Devices Tested:**
- Device A: _____________ (iOS version: _______)
- Device B: _____________ (iOS version: _______)

**iCloud Account:** _____________

---

### Test 1: Basic Upload & Sync
- [ ] Image uploaded on Device A
- [ ] Image appeared on Device B
- Time to sync: ______ seconds
- Status: ✅ PASS / ❌ FAIL
- Notes: _________________________________

### Test 2: Deletion Sync
- [ ] Image deleted on Device B
- [ ] Deletion synced to Device A
- Time to sync: ______ seconds
- Status: ✅ PASS / ❌ FAIL
- Notes: _________________________________

### Test 3: Primary Image Replacement
- [ ] Primary image uploaded on Device A
- [ ] New primary uploaded on Device B
- [ ] Old primary demoted to alternate
- [ ] Changes synced correctly
- Status: ✅ PASS / ❌ FAIL
- Notes: _________________________________

### Test 4: Offline Upload
- [ ] Image uploaded while offline
- [ ] Image synced after reconnecting
- Time to sync after reconnect: ______ seconds
- Status: ✅ PASS / ❌ FAIL
- Notes: _________________________________

### Test 5: Conflict Resolution
- [ ] Conflict created (both devices offline)
- [ ] Both images preserved after sync
- [ ] Merge handled gracefully
- Status: ✅ PASS / ❌ FAIL
- Notes: _________________________________

### Test 6: Multiple Images
- [ ] 5 images uploaded
- [ ] All 5 synced to Device B
- [ ] Correct ordering maintained
- Status: ✅ PASS / ❌ FAIL
- Notes: _________________________________

### Test 7: Large Image
- [ ] Large image resized correctly
- [ ] Sync completed quickly
- [ ] Quality acceptable
- Status: ✅ PASS / ❌ FAIL
- Notes: _________________________________

### Test 8: Different Owner Types
- [ ] Glass item images isolated
- [ ] Project plan images isolated
- [ ] Standalone images isolated
- Status: ✅ PASS / ❌ FAIL
- Notes: _________________________________

### Test 9: Inventory Changes
- [ ] Inventory added on Device A
- [ ] Synced to Device B
- [ ] Deducted on Device B
- [ ] Synced back to Device A
- Status: ✅ PASS / ❌ FAIL
- Notes: _________________________________

### Test 10: Purchase Records
- [ ] Purchase created on Device A
- [ ] Synced to Device B
- [ ] Edited on Device B
- [ ] Edit synced to Device A
- Status: ✅ PASS / ❌ FAIL
- Notes: _________________________________

### Test 11: Project Logs
- [ ] Project created on Device A
- [ ] Synced to Device B
- [ ] Updated on Device B
- [ ] Update synced to Device A
- Status: ✅ PASS / ❌ FAIL
- Notes: _________________________________

### Test 12: User Notes & Tags
- [ ] Note/tag added on Device A
- [ ] Synced to Device B
- [ ] Edited on Device B
- [ ] Edit synced to Device A
- Status: ✅ PASS / ❌ FAIL
- Notes: _________________________________

### Test 13: Shopping List
- [ ] Items added on Device A
- [ ] Synced to Device B
- [ ] Modified on Device B
- [ ] Changes synced to Device A
- Status: ✅ PASS / ❌ FAIL
- Notes: _________________________________

### Test 14: Locations
- [ ] Location created on Device A
- [ ] Synced to Device B
- [ ] Assignment made on Device B
- [ ] Synced to Device A
- Status: ✅ PASS / ❌ FAIL
- Notes: _________________________________

### Test 15: Project Plans
- [ ] Template created on Device A
- [ ] Synced to Device B
- [ ] Edited on Device B
- [ ] Edit synced to Device A
- Status: ✅ PASS / ❌ FAIL
- Notes: _________________________________

### Test 16: Cascade Deletions
- [ ] Parent entity deleted
- [ ] Cascade deletion synced
- [ ] No orphaned data
- Status: ✅ PASS / ❌ FAIL
- Notes: _________________________________

### Test 17: Complex Multi-Entity
- [ ] Complex workflow completed
- [ ] All entities synced correctly
- [ ] Data integrity maintained
- Status: ✅ PASS / ❌ FAIL
- Notes: _________________________________

---

## Overall Result: ✅ PASS / ❌ FAIL

**Issues Found:** _________________________________

**Performance Notes:** _________________________________
```

---

## ⏱️ Expected Timing

Based on typical CloudKit behavior:

| Operation | Expected Time | Acceptable Range |
|-----------|---------------|------------------|
| Local save | < 1 second | Instant |
| Sync to CloudKit | 5-15 seconds | Up to 30 seconds |
| Sync to other device | 10-30 seconds | Up to 2 minutes |
| Offline queue sync | 30-60 seconds | Up to 5 minutes |
| Conflict resolution | 1-2 minutes | Up to 5 minutes |

**Note:** First sync after app install can take longer (2-5 minutes) as CloudKit initializes.

---

## 🎯 Success Criteria

Your CloudKit implementation is working correctly if:

✅ All 8 tests pass
✅ Sync times are within acceptable ranges
✅ No data loss occurs
✅ Conflicts are resolved without crashes
✅ Offline changes sync when back online
✅ Images appear correctly on all devices
✅ No CloudKit errors in console (minor warnings OK)

---

## 📝 Additional Notes

### **CloudKit Limitations to be aware of:**

1. **Sync is eventual, not immediate**
   - Don't expect instant sync like Dropbox
   - 30-second delay is normal and acceptable

2. **Network dependency**
   - Requires internet connection
   - Won't sync over cellular if "iCloud Drive" cellular is disabled

3. **iCloud storage quota**
   - User's iCloud storage can fill up
   - Handle `CKErrorQuotaExceeded` gracefully (show user a message)

4. **CloudKit throttling**
   - If you upload 100s of images rapidly, CloudKit may throttle
   - This is normal and self-resolves

### **What you DON'T need to test:**

- ❌ CloudKit authentication (handled by iOS)
- ❌ Network error handling (CloudKit handles retries automatically)
- ❌ Merge conflicts at database level (NSMergePolicy handles this)
- ❌ Background sync (CloudKit does this automatically)

You only need to test the **user-visible behavior** (images appearing/disappearing).

---

Good luck with your testing! 🚀

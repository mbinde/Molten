# Share Extension Setup Instructions

This document explains the Share Extension for Molten, which allows users to share photos directly from the Photos app (or any other app) into Molten project ideas.

## ✅ Status: COMPLETE

The Share Extension has been successfully implemented and builds without errors!

## Files Created

The following files have been created in the `MoltenShareExtension` directory:

1. **ShareViewController.swift** - Main extension logic with Core Data integration
2. **Base.lproj/MainInterface.storyboard** - UI storyboard

## Implementation Details

The Share Extension uses the **all-in Core Data approach** for the best user experience:
- Photos are saved directly to the shared Core Data store
- Projects with photos appear immediately in the main app
- No temporary files or delayed import needed
- Seamless CloudKit sync across devices

## Setup Steps in Xcode

### 1. Verify Extension Configuration

The Share Extension target should already be created. In Xcode:

1. Select the **MoltenShareExtension** target
2. Go to **Info** tab
3. Under **NSExtension → NSExtensionAttributes**, verify:
   - **NSExtensionActivationRule**: Should allow images

If you need to add the activation rule manually, add this to the Info section:
- **NSExtensionActivationRule** (Dictionary)
  - **NSExtensionActivationSupportsImageWithMaxCount** = 10 (Number)

### 2. Configure App Groups

App Groups allow the main app and the Share Extension to share Core Data storage.

**In Main App Target (Molten):**
1. Select the **Molten** target in project settings
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability** → **App Groups**
4. Click **+** to add a new App Group: `group.com.melissabinde.molten`
5. Ensure it's checked

**In Share Extension Target:**
1. Select the **MoltenShareExtension** target
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability** → **App Groups**
4. Check the same App Group: `group.com.melissabinde.molten`

### 3. Add Shared Code to Extension Target

The Share Extension needs access to Core Data files from the main app:

1. Select the following files in the Project Navigator
2. Open the File Inspector (right sidebar)
3. Under **Target Membership**, check **MoltenShareExtension** in addition to **Molten**:

**Required Files:**
- `Molten/Molten.xcdatamodeld` (entire folder - contains all entity definitions)
- `Molten/Sources/Repositories/CoreData/CoreDataEntities.swift` (Entity base classes)

**Note:**
- The extension creates its own Core Data stack, so `Persistence.swift` is NOT needed
- Info.plist is auto-generated from build settings - no manual plist file needed

### 4. Build and Test

1. Select the **Molten** scheme
2. Build the project (⌘B)
3. Run on a simulator or device (⌘R)
4. Open the Photos app
5. Select a photo
6. Tap the Share button
7. Look for **Molten** in the share sheet
8. Tap Molten → enter a title and notes → Save

## How It Works

### User Flow

1. User selects photos in Photos app (or any app)
2. Taps Share → Molten
3. Extension loads and displays:
   - Photo preview(s)
   - Title field (auto-focuses)
   - Notes field (optional)
4. User enters title and taps Save
5. Extension creates:
   - New Project (type: "idea") in Core Data
   - UserImage entities for each photo
   - Photos immediately available in main app

### Technical Details

**Data Sharing:**
- Core Data store is in App Group container: `group.com.melissabinde.molten`
- Both main app and extension access the same database
- Changes sync immediately via CloudKit

**Image Storage:**
- Images stored as Core Data `UserImage` entities with embedded imageData
- JPEG format with 0.85 compression quality
- Linked to Project via `ownerType = "project"` and `ownerId = project.id`
- First image is marked as `imageType = "primary"`

**Benefits of Core Data Approach:**
- ✅ Photos immediately visible in main app
- ✅ No temporary files or delayed import
- ✅ Seamless user experience
- ✅ CloudKit sync across devices
- ✅ Success feedback in share sheet

**Limitations:**
- Maximum 10 images per share (configurable in Info.plist)
- UI is minimal (quick import focused)
- No project selection (always creates new project)

## Future Enhancements

### Phase 2: Project Selection
- Let user choose existing project or create new
- Show recent projects in extension

### Phase 3: Rich Metadata
- Capture photo location (if available)
- Store original capture date
- Tag photos with glass types

## Troubleshooting

**Extension doesn't appear in share sheet:**
- Verify App Group is configured correctly
- Check that MoltenShareExtension target is building
- Try restarting the iOS device/simulator

**Can't save to Core Data:**
- Verify App Group identifier matches in both targets: `group.com.melissabinde.molten`
- Check that Molten.xcdatamodeld is included in extension target
- Check that CoreDataEntities.swift is included in extension target
- Look for errors in Xcode console (extension creates its own Core Data stack)

**Images not appearing in main app:**
- Verify Core Data sync is working (check console logs)
- Ensure both app and extension use same App Group container
- Try force-quitting and reopening the main app

## Testing Checklist

- [ ] Share single photo from Photos app
- [ ] Share multiple photos (2-10)
- [ ] Verify project appears in main app
- [ ] Verify images are attached to project
- [ ] Test with empty title (should auto-generate)
- [ ] Test cancel button
- [ ] Test on real device (not just simulator)
- [ ] Test with very large photos
- [ ] Verify CloudKit sync works after extension import

## App Store Submission Notes

When submitting to App Store:
- Extension will automatically be included with main app
- No separate submission needed
- Users will see "Molten" in share sheets after installing
- Privacy policy should mention photo import capability

# App Store Review Compliance Checklist

*Analysis Date: 2025-11-13*
*App: Molten - Glass Art Studio Management*

---

## 🔴 CRITICAL ISSUES (Will Cause Immediate Rejection)

### 1. **Missing Privacy Policy** (Guideline 5.1.1)
**Status:** ❌ Not found
**Requirement:** All apps MUST have a privacy policy that clearly discloses data collection, usage, and sharing practices.

**What you need:**
- Create a privacy policy URL (host it on a website, GitHub Pages, or similar)
- Add the URL to App Store Connect during submission
- Must disclose:
  - CloudKit sync of user data (inventory, purchases, projects, shopping lists)
  - RevenueCat subscription management
  - Camera/photo library access for logbook images
  - Location data for store finding (optional feature)
  - Inventory sharing feature (server upload of user data)
  - No third-party analytics or tracking
  - Data retention and deletion policies

**Location in code:** None - needs to be created externally and linked in App Store Connect

---

### 2. **Missing Location Permission Description** (Guideline 5.1.2)
**Status:** ❌ Missing NSLocationWhenInUseUsageDescription
**Impact:** App will CRASH when requesting location permission

**Current state:**
- ✅ Camera: "Flameworker needs access..." (defined in project.pbxproj:1578)
- ✅ Photo Library: "Flameworker needs access..." (defined in project.pbxproj:1579)
- ❌ Location: **NOT DEFINED**

**What you need:** Add to `project.pbxproj` or Info.plist:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Molten uses your location to help you find nearby glass art supply stores on the map.</string>
```

**Files affected:** `Molten/Sources/Utilities/LocationManager.swift:36` calls `requestWhenInUseAuthorization()`

---

### 3. **Placeholder API URL** (Guideline 2.1)
**Status:** ❌ Using "https://api.example.com"
**Location:** `Molten/Sources/Services/Sharing/InventorySharingAPIClient.swift:26`

**Requirement:** Apps must be "final versions" with functional backend services during review.

**Options:**
1. Replace with production API URL before submission
2. OR disable the inventory sharing feature until backend is ready
3. OR provide a demo/sandbox API for review purposes

---

### 4. **Branding Inconsistency** (Guideline 2.3.8)
**Status:** ⚠️ Still references "Flameworker" in permission descriptions
**Locations:**
- `project.pbxproj:1578` - Camera description says "Flameworker"
- `project.pbxproj:1579` - Photo library description says "Flameworker"

**Fix:** Update both to say "Molten" instead of "Flameworker"

---

## 🟡 HIGH PRIORITY (Likely Rejection)

### 5. **Privacy Manifest (PrivacyInfo.xcprivacy)** (Guideline 5.1.2)
**Status:** ❌ Not found
**Requirement:** As of iOS 17, apps using certain APIs must include a privacy manifest.

**Your app uses:**
- User defaults (for settings)
- File timestamps (Core Data)
- System boot time (potentially via Core Data timestamps)

**What you need:** Create `Molten/PrivacyInfo.xcprivacy` declaring:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array>
        <!-- Your data collection declarations -->
    </array>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <!-- UserDefaults, FileTimestamp APIs -->
    </array>
</dict>
</plist>
```

---

### 6. **Subscription Terms Disclosure** (Guideline 3.1.2)
**Status:** ⚠️ Needs verification
**Requirement:** Auto-renewable subscriptions require clear disclosure of:
- Subscription length
- Price
- Auto-renewal terms
- How to cancel
- Link to privacy policy and terms of service

**Current state:** You have RevenueCat integration - verify that your paywall UI includes all required disclosures.

**What to check:**
- Does the subscription screen show all required information?
- Is there a link to privacy policy and terms of service?
- Can users easily find how to manage/cancel subscriptions?

**Location:** Settings view has manage subscriptions link (`SettingsView.swift:1112`), but need to verify paywall disclosures.

---

### 7. **Account Deletion** (Guideline 5.1.1)
**Status:** ⚠️ Unclear if implemented
**Requirement:** Apps that allow account creation must provide account deletion.

**Your app:**
- Uses RevenueCat (which creates customer accounts)
- Stores data in CloudKit (tied to Apple ID)

**What you need:**
- If users can create RevenueCat accounts, provide a way to delete the account and all associated data
- Document in privacy policy how users can request data deletion
- Consider adding a "Delete Account" option in Settings

---

## 🟠 MEDIUM PRIORITY (May Cause Issues)

### 8. **CloudKit Data Export** (Guideline 5.1.1)
**Status:** ⚠️ Not clear if implemented
**Recommendation:** Provide a way for users to export all their data.

**Current capabilities:**
- ✅ PDF export for logbook entries
- ✅ CSV import for catalog data
- ❌ No full data export visible

**Suggestion:** Add "Export All Data" feature in Settings to export inventory, purchases, projects, etc. to CSV/JSON.

---

### 9. **App Store Screenshots & Metadata** (Guideline 2.3)
**Status:** ⚠️ Not verified
**Requirements:**
- Screenshots must show actual app usage (not splash screens)
- App preview videos must use only screen recordings
- App description must accurately represent features
- No misleading marketing text

**Files:** I see screenshot automation exists (`ScreenshotAutomation/README.md`) - ensure screenshots are up to date.

---

### 10. **Subscription Restore** (Guideline 3.1.1)
**Status:** ⚠️ Needs verification
**Requirement:** Must provide a clear way to restore purchases.

**What to verify:**
- Is there a "Restore Purchases" button on the subscription screen?
- Does it work correctly for users who reinstall the app?
- RevenueCat handles this automatically, but verify UI provides access

---

### 11. **Demo Account for Review** (Guideline 2.1)
**Status:** ⚠️ Not found
**Recommendation:** Provide test credentials in App Review notes.

**What to include:**
- Demo account credentials (if applicable)
- Instructions for testing premium features without purchasing
- Any special setup needed for reviewers

**Note:** RevenueCat supports sandbox testing - document this in review notes.

---

## 🟢 BEST PRACTICES (Recommended Improvements)

### 12. **App Transport Security** (Guideline 2.5.3)
**Status:** ✅ Good - Using HTTPS only
**Current:** API client uses `https://api.example.com` (secure)
**Recommendation:** Ensure production API also uses HTTPS with valid certificates

---

### 13. **Error Handling** (Guideline 2.1)
**Status:** ⚠️ Should verify
**Recommendation:** Ensure app handles edge cases gracefully:
- No internet connection (CloudKit sync failures)
- Subscription verification failures
- Location permission denied
- Camera/photo library permission denied

**Check:** Do these scenarios show user-friendly error messages instead of crashes?

---

### 14. **IPv6 Compatibility** (Guideline 2.1)
**Status:** ⚠️ Needs testing
**Requirement:** Apps must work on IPv6-only networks.

**What to test:**
- RevenueCat SDK connectivity
- CloudKit sync
- Inventory sharing API (when implemented)

**Testing:** Use Xcode's IPv6 simulator or create IPv6-only network

---

### 15. **Accessibility** (Guideline 2.5.7)
**Status:** ⚠️ Not verified
**Recommendation:** Ensure VoiceOver support for critical features:
- Inventory management
- Shopping lists
- Settings
- Subscription management

---

### 16. **Terms of Service** (Best Practice)
**Status:** ❌ Not found
**Recommendation:** While not strictly required, consider adding terms of service that cover:
- Acceptable use of the app
- Liability disclaimers
- Subscription terms and refund policy
- User responsibilities

---

## 📋 Pre-Submission Checklist

Before submitting to App Store, complete these tasks:

### MUST DO (Will Fail Review)
- [ ] Create and publish privacy policy URL
- [ ] Add privacy policy URL to App Store Connect
- [ ] Fix NSLocationWhenInUseUsageDescription in project settings
- [ ] Replace "Flameworker" with "Molten" in permission descriptions
- [ ] Replace "api.example.com" with production URL OR disable sharing feature
- [ ] Create PrivacyInfo.xcprivacy manifest

### SHOULD DO (May Fail Review)
- [ ] Verify subscription paywall shows all required disclosures
- [ ] Add account deletion mechanism (if applicable)
- [ ] Verify "Restore Purchases" functionality
- [ ] Test app on physical device with all permission scenarios
- [ ] Prepare demo account credentials for reviewers
- [ ] Test IPv6 connectivity

### NICE TO HAVE (Improves User Experience)
- [ ] Add full data export feature
- [ ] Update screenshots and preview videos
- [ ] Test VoiceOver accessibility
- [ ] Add terms of service
- [ ] Test all error scenarios (no internet, permission denied, etc.)

---

## 📝 Estimated Timeline

- **Critical fixes:** 1-2 days (privacy policy, permissions, branding)
- **High priority:** 2-3 days (privacy manifest, subscription verification, account deletion)
- **Testing & polish:** 2-3 days (screenshots, testing, documentation)

**Total:** ~5-8 days before submission

---

## 🔗 Key Resources

- **Privacy Policy Generators:**
  - https://www.privacypolicies.com/
  - https://app-privacy-policy-generator.nisrulz.com/

- **Privacy Manifest Guide:**
  - https://developer.apple.com/documentation/bundleresources/privacy_manifest_files

- **App Store Review Guidelines:**
  - https://developer.apple.com/app-store/review/guidelines/

---

## App Features Summary (for Reference)

### Core Features
1. **Catalog Management** - 2,500+ glass items (read-only reference database)
2. **Inventory Tracking** - Multi-location stock management with quantities and alerts
3. **Purchase History** - Vendor tracking, line items, amounts, notes
4. **Project Planning** - Multiple project types with glass requirements and reference URLs
5. **Project Execution Logs** - Logbook entries with images, metadata, and PDF export
6. **Kiln Schedules** - Custom firing schedules with temperature segments
7. **Recipes** - Glass mixing recipes with ingredient tracking
8. **Shopping Lists** - Item minimums and low-stock alerts
9. **Inventory Sharing** - Friend sharing via cryptographically signed share codes
10. **Settings** - Dark/Light mode, manufacturer filters, author attribution

### Monetization Model
- **Freemium subscription** via StoreKit 2 + RevenueCat SDK
- **Free tier limits**: 50 inventory items, 5 projects, 30 logbook entries, basic label printing
- **Premium tier**: Unlimited items, batch label printing, QR scanning, custom tags/notes/images
- **Universal features**: Catalog access, CloudKit sync, CSV import, PDF export, basic label printing

### Data Storage
- **Two-store Core Data architecture**: Local store (catalog data, no CloudKit) + Cloud store (user data, optional CloudKit sync)
- **Database entities**: 28+ entities across both stores
- **Optional iCloud sync** via CloudKit
- **Sharing feature**: Server-based inventory snapshots with cryptographic signing

### Permissions & Capabilities
- **Location**: CoreLocation for store finding (optional, requestWhenInUseAuthorization)
- **Camera/Photos**: Via UIImagePickerController for logbook/project images
- **Background notifications**: Enabled for CloudKit sync
- **No**: Microphone, Calendar, Contacts, Health, HomeKit access

### Third-Party Dependencies
- **RevenueCat** - Subscription management and entitlement checking
- **StoreKit 2** - In-app purchases
- **CoreData + CloudKit** - Data persistence and sync
- **CryptoKit** - Cryptographic signing for sharing feature
- **CoreLocation** - Location services
- **No tracking/analytics**: No Firebase, Amplitude, Segment, or Google Analytics

### Security & Privacy
- **HTTPS only** for network communication
- **Certificate pinning** support
- **App Attest** for sharing API requests
- **Cryptographic signatures** on shared data
- **No PII collection** - App operates anonymously
- **No data tracking** - Privacy-first approach
- **Purchase verification** via StoreKit transaction verification

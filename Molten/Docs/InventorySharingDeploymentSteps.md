# Inventory Sharing Deployment Steps

This file contains the step-by-step instructions for deploying the inventory sharing feature with the backend server.

---

## ✅ Completed (Already Done)

- [x] iOS app implementation (all features)
- [x] Comprehensive security (App Attest + Certificate Pinning + Ownership Verification)
- [x] All 117 tests passing
- [x] Server requirements documented
- [x] Backend server implementation (see server code in this project)

---

## 📋 TODO: iOS App Configuration Steps

### Step 1: Extract Server SSL Certificate

Once your server is deployed with HTTPS, extract its certificate:

```bash
# Replace api.yourdomain.com with your actual domain
openssl s_client -connect api.yourdomain.com:443 -showcerts < /dev/null \
  | openssl x509 -outform DER > server-cert.der
```

**Result:** You'll have a `server-cert.der` file

---

### Step 2: Add Certificate to iOS App

1. Open `Molten.xcodeproj` in Xcode
2. Right-click on the `Molten` folder in Project Navigator
3. Select "Add Files to Molten..."
4. Choose `server-cert.der`
5. Ensure "Copy items if needed" is checked
6. Ensure "Molten" target is selected
7. Click "Add"

**Verify:** Certificate appears in Xcode project under Molten folder

---

### Step 3: Update AppDependencies with Pinned Certificate

**File:** `Molten/Sources/App/Factories/AppDependencies.swift`

Find the `createInventorySharingManager()` method and update it:

```swift
/// Creates an InventorySharingManager for sharing inventory with friends
@MainActor
static func createInventorySharingManager() -> InventorySharingManager {
    // Load pinned certificate
    guard let certURL = Bundle.main.url(forResource: "server-cert", withExtension: "der"),
          let certData = try? Data(contentsOf: certURL) else {
        fatalError("Missing server certificate for inventory sharing")
    }

    // Create API client with actual server URL and pinned certificate
    let apiClient = InventorySharingAPIClient(
        baseURL: URL(string: "https://api.yourdomain.com")!,  // ⚠️ UPDATE THIS
        pinnedCertificates: [certData]
    )

    // Create service with custom API client
    let sharingService = InventorySharingService(apiClient: apiClient)

    // Create coordinator and manager
    let coordinator = InventorySharingCoordinator(sharingService: sharingService)
    return InventorySharingManager(coordinator: coordinator)
}
```

**⚠️ IMPORTANT:** Replace `https://api.yourdomain.com` with your actual API base URL

---

### Step 4: Update AttestationManager Configuration (Optional)

If you want to customize the App Attest configuration:

**File:** `Molten/Sources/Services/Sharing/AttestationManager.swift`

The current implementation uses default settings. No changes needed unless you want to customize attestation behavior.

---

### Step 5: Test Certificate Pinning

**Test with correct certificate (should succeed):**
```swift
let client = InventorySharingAPIClient(
    baseURL: URL(string: "https://api.yourdomain.com")!,
    pinnedCertificates: [correctCertData]
)
// Requests should work
```

**Test with wrong certificate (should fail):**
```swift
let wrongCert = Data([0x00, 0x01, 0x02])  // Invalid cert
let client = InventorySharingAPIClient(
    baseURL: URL(string: "https://api.yourdomain.com")!,
    pinnedCertificates: [wrongCert]
)
// Requests should fail with authentication challenge error
```

---

### Step 6: Register App Attest Key (First Launch)

Add this to your app's first-launch or settings initialization:

**File:** `Molten/Sources/Views/Sharing/ViewModels/InventorySharingViewModel.swift`

Add a registration method:

```swift
/// Register App Attest key with server (call once per device)
func registerAppAttest() async {
    guard attestationManager.isSupported else {
        // App Attest not supported, skip
        return
    }

    // Check if already registered
    if attestationManager.currentKeyId != nil {
        return  // Already registered
    }

    isLoading = true
    errorMessage = nil

    do {
        // 1. Generate attestation key
        let keyId = try await attestationManager.generateKey()

        // 2. Get server challenge
        let challenge = try await fetchServerChallenge()

        // 3. Attest the key
        let attestation = try await attestationManager.attestKey(
            keyId: keyId,
            challenge: challenge
        )

        // 4. Send attestation to server
        try await sendAttestationToServer(
            keyId: keyId,
            attestation: attestation,
            challenge: challenge
        )

    } catch {
        errorMessage = "Failed to register with server: \(error.localizedDescription)"
    }

    isLoading = false
}

private func fetchServerChallenge() async throws -> Data {
    // TODO: Implement server challenge fetch
    // GET https://api.yourdomain.com/attest/challenge
    fatalError("Not yet implemented")
}

private func sendAttestationToServer(keyId: String, attestation: Data, challenge: Data) async throws {
    // TODO: Implement attestation registration
    // POST https://api.yourdomain.com/attest/register
    fatalError("Not yet implemented")
}
```

**Then call on first share creation:**

```swift
func createMyShare() async {
    // Register App Attest if needed
    await registerAppAttest()

    // ... rest of existing code
}
```

---

### Step 7: Update Info.plist (App Transport Security)

If your server is not using standard SSL configuration, you may need to update `Info.plist`:

**File:** `Molten/Info.plist`

Add (only if needed for development/testing):

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>api.yourdomain.com</key>
        <dict>
            <key>NSExceptionRequiresForwardSecrecy</key>
            <false/>
        </dict>
    </dict>
</dict>
```

**⚠️ PRODUCTION:** Remove `NSAllowsArbitraryLoads` and exceptions before App Store submission.

---

### Step 8: Test End-to-End Flow

**Manual testing checklist:**

1. **Create Share:**
   - [ ] Open Inventory Sharing view
   - [ ] Tap "Create My Share"
   - [ ] Verify share code appears
   - [ ] Verify data uploaded to server
   - [ ] Check server logs for App Attest assertion

2. **Copy Share Code:**
   - [ ] Tap copy button
   - [ ] Verify share code copied to clipboard

3. **Add Friend:**
   - [ ] On second device, tap "Add Friend"
   - [ ] Enter friend's name and share code
   - [ ] Tap "Add"
   - [ ] Verify friend appears in list

4. **View Friend Inventory:**
   - [ ] Tap on friend
   - [ ] Tap "Load Inventory"
   - [ ] Verify inventory items display
   - [ ] Verify signature validation (should be valid)

5. **Refresh Friend Inventory:**
   - [ ] Tap refresh button
   - [ ] Verify updated data appears
   - [ ] Check last refreshed timestamp

6. **Update My Share:**
   - [ ] Add/remove inventory items
   - [ ] Tap "Refresh My Share"
   - [ ] Verify ownership signature sent
   - [ ] Verify update succeeds

7. **Delete My Share:**
   - [ ] Tap "Delete My Share"
   - [ ] Confirm deletion
   - [ ] Verify ownership signature sent
   - [ ] Verify share removed from server

8. **Remove Friend:**
   - [ ] Swipe left on friend
   - [ ] Tap "Delete"
   - [ ] Verify friend removed from list

9. **Certificate Pinning Test:**
   - [ ] Replace server certificate with invalid cert
   - [ ] Try to create share
   - [ ] Verify request fails (certificate mismatch)
   - [ ] Restore correct certificate
   - [ ] Verify requests work again

---

### Step 9: Certificate Rotation Plan

When your SSL certificate expires:

**Preparation (30 days before expiration):**
1. Generate new certificate on server
2. Deploy new certificate to server (keep old cert active)
3. Extract new certificate: `openssl s_client -connect api.yourdomain.com:443 ...`
4. Add new certificate to iOS app
5. Update code to pin BOTH certificates:
   ```swift
   let oldCert = ... // existing cert
   let newCert = ... // new cert
   let apiClient = InventorySharingAPIClient(
       pinnedCertificates: [oldCert, newCert]  // Accept both
   )
   ```
6. Release app update

**After app adoption reaches 95%:**
1. Remove old certificate from iOS app
2. Release new app version
3. Remove old certificate from server

---

### Step 10: Production Checklist

Before App Store submission:

**Security:**
- [ ] Server uses HTTPS with valid certificate
- [ ] Certificate pinning configured with production certificate
- [ ] App Attest registration implemented
- [ ] All rate limiting configured on server
- [ ] Ownership verification enforced on server

**Configuration:**
- [ ] Production API base URL set
- [ ] No development/testing exceptions in Info.plist
- [ ] Certificate file included in app bundle
- [ ] No hardcoded test share codes

**Testing:**
- [ ] All 117 tests passing
- [ ] Manual end-to-end testing completed
- [ ] Certificate pinning tested
- [ ] Rate limiting tested
- [ ] Error handling tested

**Privacy:**
- [ ] Privacy policy updated to mention inventory sharing
- [ ] User consent for data sharing
- [ ] Clear explanation of what data is shared

**Monitoring:**
- [ ] Server monitoring configured
- [ ] Error logging implemented
- [ ] Rate limit alerts configured
- [ ] Certificate expiration monitoring

---

## 🆘 Troubleshooting

### "Certificate verification failed"
**Cause:** Certificate doesn't match pinned certificate
**Fix:** Ensure you extracted the correct certificate from your production server

### "App Attest not supported"
**Cause:** Running on simulator or iOS < 14
**Fix:** Test on real device with iOS 14+, or skip App Attest for development

### "Ownership signature invalid"
**Cause:** Share was created with different key pair
**Fix:** Delete share and recreate, or fix key pair mismatch

### "Rate limit exceeded"
**Cause:** Too many requests from same IP
**Fix:** Wait for rate limit window to reset (1 hour)

### "Share code not found"
**Cause:** Share expired or was deleted
**Fix:** Ask friend to recreate their share

---

## 📞 Support

**iOS App Issues:**
- See `InventorySharingViewModel.swift` for UI logic
- See `InventorySharingManager.swift` for business logic
- See `AttestationManager.swift` for App Attest

**Server Issues:**
- See `InventorySharingServerRequirements.md` for API spec
- Check server logs for detailed errors
- Verify App Attest validation

**Certificate Issues:**
- Verify certificate is DER format (not PEM)
- Ensure certificate matches server exactly
- Check certificate expiration date

---

## 📝 Notes

- **Certificate pinning** prevents MITM but requires app updates for certificate rotation
- **App Attest** requires iOS 14+, gracefully degrades on older devices
- **Ownership signatures** prevent unauthorized modifications even if API is reverse-engineered
- **Rate limiting** on server is critical to prevent abuse
- **Share codes** are 6 characters, base-31 encoding (887 million combinations)

---

**Last Updated:** 2025-11-07
**Status:** iOS app complete, server implementation complete, ready for iOS configuration

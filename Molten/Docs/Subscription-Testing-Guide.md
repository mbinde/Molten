# Subscription Testing Guide

This guide explains how to test subscription features (free vs premium tiers) both manually and in automated tests.

## Manual Testing (Settings UI)

The easiest way to test premium features without making a purchase is to use the debug tier override in Settings:

1. **Open Settings**
   - Navigate to the Settings tab in the app

2. **Find Debug Section**
   - Scroll to the "Debug" section (near the bottom)

3. **Enable Tier Override**
   - Toggle "Override Subscription Tier" ON
   - This enables the debug tier setting

4. **Select Tier**
   - Use the segmented control to switch between "Free" and "Premium"
   - The current tier status is shown below the picker

5. **Test Features**
   - Navigate to any feature in the app
   - Premium features will be enabled/disabled based on the selected tier
   - Try adding inventory items, creating projects, etc.

### What You Can Test

With the tier override enabled, you can test:
- **Quantity limits**: Try exceeding the free tier limits for inventory, shopping, projects, logbook
- **Premium features**: Test QR code scanning, custom tags, notes, images for inventory items
- **Upgrade prompts**: Switch to free tier and trigger the upgrade prompt by hitting limits

## Automated Testing

### Unit Tests

For unit tests, you can create an `EntitlementService` with a specific tier:

```swift
@Test("Free tier should limit inventory items")
func testFreeTierInventoryLimit() {
    // Create service with free tier
    let service = EntitlementService(tier: .free)

    // Test that limits are enforced
    #expect(service.canAddInventoryItem(currentCount: 49) == true)
    #expect(service.canAddInventoryItem(currentCount: 50) == false)
    #expect(service.getInventoryLimit() == 50)
}

@Test("Premium tier should have unlimited inventory")
func testPremiumTierUnlimitedInventory() {
    // Create service with premium tier
    let service = EntitlementService(tier: .premium)

    // Test that limits don't apply
    #expect(service.canAddInventoryItem(currentCount: 1000) == true)
    #expect(service.getInventoryLimit() == nil)  // nil = unlimited
}
```

### Using Debug Override in Tests

You can also use the debug override programmatically in tests:

```swift
@Test("Test with debug override")
func testWithDebugOverride() {
    // Enable debug override
    DebugConfig.debugOverrideSubscriptionTier = true
    DebugConfig.debugSubscriptionTierValue = 1  // 1 = premium

    // Create service - it will use the debug tier
    let service = EntitlementService(tier: .free)  // This is ignored when override is enabled

    // Test premium features
    #expect(service.currentTier == .premium)
    #expect(service.canUseQRCodeScanning() == true)

    // Cleanup
    DebugConfig.debugOverrideSubscriptionTier = false
}
```

### ViewModel Tests

When testing ViewModels that depend on `EntitlementService`, inject a service with the desired tier:

```swift
@Test("Inventory view should show upgrade prompt at limit")
func testInventoryUpgradePrompt() async throws {
    // Create test data with exactly 50 items (free tier limit)
    let builder = try await TestDataBuilder()
        .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
        .withInventory(manufacturer: "bullseye", sku: "001", quantity: 50.0, type: "rod")
        .build()

    // Create service with free tier
    let entitlementService = EntitlementService(tier: .free)

    // Create view model
    let viewModel = InventoryViewModel(
        inventoryTrackingService: builder.inventoryTrackingService,
        catalogService: builder.catalogService,
        entitlementService: entitlementService
    )

    // Test that trying to add more shows upgrade prompt
    let canAdd = entitlementService.canAddInventoryItem(currentCount: 50)
    #expect(canAdd == false)
}
```

## Configuration Details

### DebugConfig Properties

The debug override is controlled by three properties in `DebugConfig`:

```swift
// Enable/disable the override
@AppStorage("debugOverrideSubscriptionTier")
static var debugOverrideSubscriptionTier = false

// The tier value (0 = free, 1 = premium)
@AppStorage("debugSubscriptionTierValue")
static var debugSubscriptionTierValue = 0

// Computed property for convenience
static var debugSubscriptionTier: SubscriptionTier {
    return debugSubscriptionTierValue == 1 ? .premium : .free
}
```

These use `@AppStorage` so the setting persists across app launches.

### How It Works

1. **EntitlementService** checks `DebugConfig.debugOverrideSubscriptionTier` in its `currentTier` property
2. If override is enabled, it returns `DebugConfig.debugSubscriptionTier` instead of the actual tier
3. All entitlement checks use `currentTier`, so they respect the override

## Best Practices

### Manual Testing
- ✅ Test both free and premium tiers for every new feature
- ✅ Test the transition from free to premium (toggle the override)
- ✅ Test upgrade prompts at various limits
- ✅ Remember to disable the override when testing actual purchase flows

### Automated Testing
- ✅ Always inject `EntitlementService` with explicit tier in tests
- ✅ Don't rely on the global override in tests (not predictable)
- ✅ Test both tiers for any feature that has subscription gating
- ✅ Test boundary conditions (at limit, just below limit, just above limit)

### Production Safety
- ✅ The debug override only affects the UI setting and manual testing
- ✅ In production, `SubscriptionManager` will update the actual tier from StoreKit
- ✅ The override is stored in UserDefaults (not synced to iCloud)
- ✅ Turning off the override immediately restores the actual subscription status

## Testing Checklist

When adding a new subscription-gated feature:

- [ ] Test free tier - feature should be disabled or limited
- [ ] Test premium tier - feature should be fully enabled
- [ ] Test upgrade prompt appears at appropriate time
- [ ] Write unit tests for both tiers
- [ ] Update this guide if adding new testable features

## Troubleshooting

**Override not working?**
- Check that "Override Subscription Tier" toggle is ON in Settings
- Verify the picker is set to the desired tier
- Try force-quitting and relaunching the app

**Tests failing unexpectedly?**
- Make sure you're injecting `EntitlementService` with explicit tier
- Check that tests aren't relying on the global debug override
- Verify `DebugConfig.debugOverrideSubscriptionTier` is false at test start

**Production behavior unexpected?**
- Disable the override in Settings
- Check `SubscriptionManager` is properly updating the tier from StoreKit
- Verify the actual subscription status in App Store Connect

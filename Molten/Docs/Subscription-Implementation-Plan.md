# Subscription Implementation Plan

This document outlines the subscription infrastructure and next steps for implementing the freemium model.

## Overview

Molten uses a freemium model where core features are free with limits, and premium unlocks unlimited usage plus advanced features.

**Pricing** (proposed):
- **Free**: Generous limits to build habit (50 inventory items, 15 shopping list items, 5 projects, 30 logbook entries)
- **Premium**: $5/month or $50/year (unlimited everything + advanced features)

## Infrastructure (Completed)

### 1. SubscriptionConfig (`Molten/Sources/App/Configuration/SubscriptionConfig.swift`)
Centralized configuration for all subscription limits. **To adjust limits, edit values here:**

```swift
struct FreeTierLimits {
    static let maxInventoryItems = 50         // ADJUST HERE
    static let maxShoppingListItems = 15     // ADJUST HERE
    static let maxProjects = 5               // ADJUST HERE
    static let maxLogbookEntries = 30        // ADJUST HERE
    static let allowBatchLabelPrinting = false
}
```

### 2. EntitlementService (`Molten/Sources/Services/Core/EntitlementService.swift`)
Actor-based service that checks subscription tier and enforces limits:
- `canAddInventoryItem(currentCount:)` - Check before adding inventory
- `canAddShoppingListItem(currentCount:)` - Check before adding to shopping list
- `canAddProject(currentCount:)` - Check before creating projects
- `canAddLogbookEntry(currentCount:)` - Check before creating logbook entries
- `canUseBatchLabelPrinting()` - Check before batch operations
- `canUseCSVImport()` - Premium feature gate
- `canUseBulkEditing()` - Premium feature gate
- `canUseCustomFields()` - Premium feature gate

### 3. SubscriptionTier Enum
Simple enum representing user tier:
```swift
enum SubscriptionTier: Sendable {
    case free
    case premium
}
```

### 4. Tests (`Tests/MoltenTests/Services/EntitlementServiceTests.swift`)
Comprehensive test coverage for all entitlement checks.

## Next Steps (Not Yet Implemented)

### Phase 1: StoreKit Integration
**Goal**: Connect to App Store for subscription management

**Files to create:**
1. `Molten/Sources/Services/Core/SubscriptionService.swift`
   - Manage StoreKit 2 transactions
   - Handle purchase/restore/cancel flows
   - Update `EntitlementService` with current tier
   - Persist subscription status locally

2. `Molten/Sources/App/Configuration/Products.storekit`
   - Define in-app purchase products
   - Monthly: `com.moltenglass.premium.monthly` ($4.99)
   - Annual: `com.moltenglass.premium.annual` ($49.99)

**Implementation notes:**
- Use StoreKit 2 (async/await APIs)
- Store subscription state in UserDefaults + verify with App Store
- Handle subscription lifecycle (purchase, renew, expire, cancel)
- Support family sharing if desired

**References:**
- Apple StoreKit 2 docs: https://developer.apple.com/storekit/
- WWDC sessions on subscriptions

### Phase 2: Enforcement Points
**Goal**: Check limits before allowing operations

**Where to add enforcement** (grep these files for TODO comments):

1. **Inventory** (`Views/Inventory/AddInventoryItemView.swift`):
   ```swift
   // Before adding new inventory item:
   let canAdd = await entitlementService.canAddInventoryItem(currentCount: currentItemCount)
   if !canAdd {
       // Show paywall
   }
   ```

2. **Shopping List** (`Views/Shopping/AddShoppingListItemView.swift`):
   ```swift
   // Before adding to shopping list:
   let canAdd = await entitlementService.canAddShoppingListItem(currentCount: currentItemCount)
   if !canAdd {
       // Show paywall
   }
   ```

3. **Projects** (`Views/ProjectLog/AddProjectView.swift`):
   ```swift
   // Before creating project:
   let canAdd = await entitlementService.canAddProject(currentCount: currentProjectCount)
   if !canAdd {
       // Show paywall
   }
   ```

4. **Logbook** (`Views/ProjectLog/AddLogbookEntryView.swift`):
   ```swift
   // Before creating logbook entry:
   let canAdd = await entitlementService.canAddLogbookEntry(currentCount: currentEntryCount)
   if !canAdd {
       // Show paywall
   }
   ```

5. **Label Printing** (`Views/Inventory/LabelPrintingView.swift`):
   ```swift
   // Before batch printing:
   let canBatch = await entitlementService.canUseBatchLabelPrinting()
   if !canBatch {
       // Show "Premium only" message
   }
   ```

6. **CSV Import** (when implemented):
   ```swift
   // Before importing CSV:
   let canImport = await entitlementService.canUseCSVImport()
   if !canImport {
       // Show paywall
   }
   ```

**Pattern to follow:**
1. Inject `EntitlementService` into views (default parameter in init)
2. Check entitlement before operation
3. If blocked, show paywall with upgrade button
4. After successful upgrade, refresh entitlement and allow operation

### Phase 3: Paywall UI
**Goal**: Beautiful upgrade screen with clear value proposition

**Files to create:**
1. `Molten/Sources/Views/Settings/SubscriptionPaywallView.swift`
   - Show pricing options (monthly/annual)
   - Highlight premium features
   - "Continue with Free" option
   - Terms and privacy links

2. `Molten/Sources/Views/Settings/SubscriptionManagementView.swift`
   - Show current subscription status
   - Manage/cancel subscription
   - Restore purchases button
   - Usage stats (e.g., "Using 45/50 inventory items")

3. `Molten/Sources/Views/Shared/Components/LimitReachedBannerView.swift`
   - Inline banner shown when approaching limits
   - Soft prompt to upgrade

**Design principles:**
- Never nag - only show paywall when user hits limit
- Make free tier genuinely useful (not crippled)
- Clear upgrade value ("Get unlimited + these features")
- Easy to dismiss and continue with free

### Phase 4: Integration with AppDependencies
**Goal**: Make EntitlementService easily accessible

**Update** `Molten/Sources/App/Factories/AppDependencies.swift`:
```swift
static func createEntitlementService() -> EntitlementService {
    // In production, fetch tier from SubscriptionService
    // For now, default to free
    return EntitlementService(tier: .free)
}
```

**Update** `MoltenApp.swift`:
- Create singleton EntitlementService at app launch
- Inject into environment for easy access in views:
  ```swift
  @StateObject private var entitlementService = AppDependencies.createEntitlementService()

  var body: some Scene {
      WindowGroup {
          ContentView()
              .environmentObject(entitlementService)
      }
  }
  ```

### Phase 5: Analytics & Optimization
**Goal**: Understand conversion funnel

**Metrics to track:**
- How many users hit each limit
- Where in the flow do they upgrade
- Conversion rate free → paid
- Feature usage by tier

**Tools:**
- TelemetryDeck or similar privacy-focused analytics
- A/B test limit values
- Monitor churn and retention

## Testing Strategy

### Unit Tests (Completed)
- ✅ EntitlementService logic
- ✅ Tier detection
- ✅ Limit enforcement

### Integration Tests (TODO)
- [ ] StoreKit sandbox purchases
- [ ] Subscription state persistence
- [ ] Restore purchases flow
- [ ] Expiration handling

### UI Tests (TODO)
- [ ] Paywall appearance when limit hit
- [ ] Successful upgrade flow
- [ ] "Continue with Free" dismissal
- [ ] Usage banner visibility

## Rollout Plan

1. **Internal Testing** (TestFlight)
   - Test subscription flow with team
   - Verify StoreKit integration
   - Confirm limits work as expected

2. **Soft Launch** (25% of users)
   - Enable for subset of users
   - Monitor conversion metrics
   - Gather feedback

3. **Full Launch**
   - Enable for all users
   - Marketing push
   - Monitor support volume

## Future Considerations

### Pricing Experiments
- Test different tier limits
- Try annual-only option
- Consider lifetime unlock ($99?)
- Family sharing toggle

### Premium Features (Beyond Limits)
- Advanced analytics dashboard
- Custom reporting
- Batch operations
- Integration with external tools
- Priority support

### Competitive Analysis
- Kiln control app: $5/month or $50/year
- No direct competitors for glass inventory
- Price reflects unique value prop

## Support & Edge Cases

### What if user downgrades?
- Keep existing data (don't delete)
- Block adding new items beyond free limit
- Allow editing existing items
- Show upgrade prompt on add attempts

### What if subscription expires?
- Grace period (7 days?)
- Soft lock (can't add, can edit)
- Clear messaging about renewal

### What about refunds?
- Follow App Store policy
- Don't punish users (keep data)
- Graceful degradation to free tier

## Questions to Resolve

- [ ] Should we offer a trial period? (7 days free premium?)
- [ ] Do we need multiple premium tiers? (Basic vs Pro?)
- [ ] Should images be limited per-project vs per-user?
- [ ] Do we need regional pricing?
- [ ] Should we support promo codes?

---

**Last Updated**: October 28, 2025
**Status**: Infrastructure complete, ready for Phase 1 (StoreKit integration)

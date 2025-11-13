# RevenueCat Integration Guide

This guide explains how to use the RevenueCat subscription system in Molten Glass.

## Architecture Overview

The RevenueCat integration follows Molten's 3-layer clean architecture:

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 1: Domain Models                                       │
│ - SubscriptionStatus, EntitlementInfo, SubscriptionError     │
│ - CustomerInfo                                                │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 2: Services                                             │
│ - SubscriptionServiceProtocol                                 │
│ - RevenueCatSubscriptionService (Production)                  │
│ - MockSubscriptionService (Testing)                           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 3: Views                                                │
│ - SubscriptionViewModel (Protocol-based)                      │
│ - SubscriptionStatusView                                      │
│ - Integration points throughout app                           │
└─────────────────────────────────────────────────────────────┘
```

## Configuration

RevenueCat is configured in `MoltenApp.swift` during app initialization:

```swift
init() {
    configureRevenueCat()
}

private func configureRevenueCat() {
    Purchases.configure(
        with: Configuration.Builder(withAPIKey: "test_oIPjDwQxUqwuGvJpuCZEuaWmQTL")
            .with(entitlementVerificationMode: .informational)
            .build()
    )
}
```

## Products & Entitlements

**Products** (configured in RevenueCat dashboard):
- `monthly` - Monthly subscription
- `yearly` - Annual subscription
- `lifetime` - One-time purchase

**Entitlement**: All products unlock the `molten_glass_pro` entitlement.

## Usage Examples

### 1. Adding Subscription View to Settings

```swift
import SwiftUI

struct SettingsView: View {
    // Create service ONCE in init (follows CLAUDE.md pattern)
    private let subscriptionService: SubscriptionServiceProtocol

    @State private var viewModel: SubscriptionViewModel

    init(subscriptionService: SubscriptionServiceProtocol = AppDependencies.createSubscriptionService()) {
        self.subscriptionService = subscriptionService
        self._viewModel = State(initialValue: SubscriptionViewModel(subscriptionService: subscriptionService))
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Subscription") {
                    NavigationLink {
                        SubscriptionStatusView(viewModel: viewModel)
                    } label: {
                        HStack {
                            Image(systemName: viewModel.hasProAccess ? "star.fill" : "star")
                                .foregroundStyle(viewModel.hasProAccess ? .yellow : .gray)
                            Text(viewModel.hasProAccess ? "Pro Member" : "Upgrade to Pro")
                        }
                    }
                }

                // ... other settings sections
            }
            .navigationTitle("Settings")
            .task {
                await viewModel.loadSubscriptionStatus()
            }
        }
    }
}
```

### 2. Protecting Premium Features

```swift
struct CatalogView: View {
    private let subscriptionService: SubscriptionServiceProtocol
    @State private var hasProAccess = false

    init(subscriptionService: SubscriptionServiceProtocol = AppDependencies.createSubscriptionService()) {
        self.subscriptionService = subscriptionService
    }

    var body: some View {
        VStack {
            // Regular content
            catalogContent

            // Pro-only feature
            if hasProAccess {
                advancedFilteringView
            } else {
                proUpsellBanner
            }
        }
        .task {
            hasProAccess = await subscriptionService.hasProAccess()
        }
    }

    private var proUpsellBanner: some View {
        Button {
            Task {
                try? await subscriptionService.presentPaywall()
            }
        } label: {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                Text("Unlock Advanced Filters with Pro")
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding()
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(DesignSystem.CornerRadius.medium)
        }
        .accessibilityIdentifier("catalog.proUpsell")
    }
}
```

### 3. Checking Specific Entitlements

```swift
// Check for Pro access
let hasPro = await subscriptionService.hasProAccess()

// Check specific entitlement by name
let hasCustomEntitlement = await subscriptionService.checkEntitlement("custom_feature")

// Get full customer info
let customerInfo = try await subscriptionService.getCustomerInfo()
print("User ID: \(customerInfo.originalAppUserId)")
print("Active entitlements: \(customerInfo.activeEntitlements)")
```

### 4. Presenting Paywall Directly

```swift
Button("Upgrade to Pro") {
    Task {
        do {
            try await subscriptionService.presentPaywall()
        } catch {
            print("Error showing paywall: \(error)")
        }
    }
}
```

### 5. Presenting Customer Center

```swift
Button("Manage Subscription") {
    Task {
        do {
            try await subscriptionService.presentCustomerCenter()
        } catch {
            print("Error showing customer center: \(error)")
        }
    }
}
```

### 6. Restoring Purchases

```swift
Button("Restore Purchases") {
    Task {
        do {
            let customerInfo = try await subscriptionService.restorePurchases()
            print("✅ Purchases restored. Has Pro: \(customerInfo.subscriptionStatus.isActive)")
        } catch {
            print("❌ Failed to restore purchases: \(error)")
        }
    }
}
```

## Testing

### Unit Tests with Mock Service

```swift
import Testing
@testable import Molten

@Suite("Feature Tests")
@MainActor
struct MyFeatureTests {

    @Test("Should show Pro feature for Pro users")
    func testProFeatureAccess() async throws {
        // Arrange: Create mock service with Pro access
        let mockService = MockSubscriptionService(hasProAccess: true)

        // Act: Check access
        let hasAccess = await mockService.hasProAccess()

        // Assert
        #expect(hasAccess == true)
    }

    @Test("Should block feature for free users")
    func testFreeUserBlocked() async throws {
        // Arrange: Create mock service without Pro access
        let mockService = MockSubscriptionService(hasProAccess: false)

        // Act: Check access
        let hasAccess = await mockService.hasProAccess()

        // Assert
        #expect(hasAccess == false)
    }
}
```

### SwiftUI Previews

```swift
#Preview("Free User") {
    SubscriptionStatusView(
        viewModel: MockSubscriptionViewModel(hasProAccess: false)
    )
}

#Preview("Pro User") {
    SubscriptionStatusView(
        viewModel: MockSubscriptionViewModel(hasProAccess: true)
    )
}

#Preview("Loading") {
    SubscriptionStatusView(
        viewModel: MockSubscriptionViewModel(isLoading: true)
    )
}
```

## Best Practices

### ✅ DO:

1. **Use AppDependencies** for dependency injection:
   ```swift
   let service = AppDependencies.createSubscriptionService()
   ```

2. **Create services in `init()` with default parameters** (NOT in `.task` or `.onAppear`):
   ```swift
   init(service: SubscriptionServiceProtocol = AppDependencies.createSubscriptionService()) {
       self.service = service
   }
   ```

3. **Use protocol-based ViewModels** for testability:
   ```swift
   struct MyView<ViewModel: SubscriptionViewModelProtocol>: View {
       @ObservedObject var viewModel: ViewModel
   }
   ```

4. **Use mock services in tests**:
   ```swift
   let mockService = MockSubscriptionService(hasProAccess: true)
   ```

5. **Check entitlements on the server side** (RevenueCat does this automatically)

### ❌ DON'T:

1. **Don't create services in `.onAppear` or `.task`** - causes crashes (see CLAUDE.md)
2. **Don't hardcode subscription logic** - use the service layer
3. **Don't trust client-side validation only** - RevenueCat validates server-side
4. **Don't forget to configure products in RevenueCat dashboard**
5. **Don't skip tests** - write tests first with TDD

## RevenueCat Dashboard Setup

1. Go to https://app.revenuecat.com
2. Select your project
3. Navigate to **Products** → **Offerings**
4. Create an offering (e.g., "default")
5. Add your products:
   - **monthly** - Monthly subscription
   - **yearly** - Annual subscription
   - **lifetime** - One-time purchase
6. Create Entitlement:
   - Identifier: **molten_glass_pro**
   - Attach all three products to this entitlement

## Troubleshooting

### "No offerings found"
- Ensure you've configured offerings in the RevenueCat dashboard
- Check that your API key is correct
- Verify network connection

### "User already subscribed but app doesn't recognize it"
- Call `restorePurchases()` to sync with RevenueCat servers
- Check that entitlement identifier matches: `molten_glass_pro`

### Crashes when presenting paywall
- Ensure RevenueCat is configured in `init()` before any views are created
- Check that you're not creating services in `.onAppear` or `.task`

### Tests failing
- Ensure `AppDependencies.configureForTesting()` is called in test setup
- Use `MockSubscriptionService` instead of production service
- Don't let tests touch RevenueCat servers

## File Locations

```
Molten/
├── Sources/
│   ├── Models/Domain/
│   │   └── SubscriptionModels.swift
│   ├── Services/Core/
│   │   ├── SubscriptionServiceProtocol.swift
│   │   ├── RevenueCatSubscriptionService.swift
│   │   └── MockSubscriptionService.swift
│   ├── Views/Subscriptions/
│   │   ├── ViewModels/
│   │   │   ├── SubscriptionViewModelProtocol.swift
│   │   │   ├── SubscriptionViewModel.swift
│   │   │   └── MockSubscriptionViewModel.swift
│   │   └── Components/
│   │       └── SubscriptionStatusView.swift
│   └── App/
│       ├── MoltenApp.swift (RevenueCat configuration)
│       └── Factories/
│           └── AppDependencies.swift (service creation)
└── Tests/MoltenTests/
    ├── Models/
    │   └── SubscriptionModelsTests.swift
    ├── Services/
    │   └── SubscriptionServiceTests.swift
    └── Views/
        └── SubscriptionViewModelTests.swift
```

## Additional Resources

- [RevenueCat Documentation](https://www.revenuecat.com/docs)
- [RevenueCat Paywalls](https://www.revenuecat.com/docs/tools/paywalls)
- [RevenueCat Customer Center](https://www.revenuecat.com/docs/tools/customer-center)
- [Project Architecture (CLAUDE.md)](/Users/binde/projects/iap/CLAUDE.md)

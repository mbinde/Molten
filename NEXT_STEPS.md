# RevenueCat Integration - Next Steps

## ✅ What's Been Created

All code has been implemented following your project's TDD and clean architecture patterns:

### Domain Models
- ✅ `SubscriptionModels.swift` - Business logic for subscriptions
- ✅ `SubscriptionModelsTests.swift` - Unit tests for models

### Service Layer
- ✅ `SubscriptionServiceProtocol.swift` - Service interface
- ✅ `RevenueCatSubscriptionService.swift` - Production implementation
- ✅ `MockSubscriptionService.swift` - Testing implementation
- ✅ `SubscriptionServiceTests.swift` - Service unit tests

### ViewModel Layer
- ✅ `SubscriptionViewModelProtocol.swift` - ViewModel interface
- ✅ `SubscriptionViewModel.swift` - Production ViewModel
- ✅ `MockSubscriptionViewModel.swift` - Testing/Preview ViewModel
- ✅ `SubscriptionViewModelTests.swift` - ViewModel unit tests

### Views
- ✅ `SubscriptionStatusView.swift` - Main subscription UI with 6 preview states

### Configuration
- ✅ `RepositoryFactory.swift` - Added subscription service creation
- ✅ `MoltenApp.swift` - Added RevenueCat SDK configuration

### Documentation
- ✅ `RevenueCat-Integration-Guide.md` - Complete usage guide

---

## 🚀 Steps to Complete Integration

### Step 1: Install RevenueCat SDK (REQUIRED)

**In Xcode:**

1. Open `Molten.xcodeproj`
2. Select your project in the navigator
3. Select "Molten" target
4. Go to "Package Dependencies" tab
5. Click "+" button
6. Enter URL: `https://github.com/RevenueCat/purchases-ios-spm.git`
7. Version: Up to Next Major (5.0.0 < 6.0.0)
8. Add packages: `RevenueCat`, `RevenueCatUI`
9. Click "Add Package"

⚠️ **CRITICAL**: Without this step, the project won't build!

---

### Step 2: Add Test Files to Xcode (REQUIRED)

The following test files need to be added to the Xcode project:

**For MoltenTests target:**
```
Tests/MoltenTests/Models/SubscriptionModelsTests.swift
Tests/MoltenTests/Services/SubscriptionServiceTests.swift
Tests/MoltenTests/Views/SubscriptionViewModelTests.swift
```

**To add them:**

1. Open Xcode
2. Right-click on `Tests/MoltenTests/Models` folder
3. Select "Add Files to Molten..."
4. Navigate to and select `SubscriptionModelsTests.swift`
5. Ensure "MoltenTests" target is checked
6. Click "Add"
7. Repeat for the other two test files in their respective folders

OR use the script (if xcodeproj gem is installed):
```bash
ruby add-test-to-xcode.rb Tests/MoltenTests/Models/SubscriptionModelsTests.swift
ruby add-test-to-xcode.rb Tests/MoltenTests/Services/SubscriptionServiceTests.swift
ruby add-test-to-xcode.rb Tests/MoltenTests/Views/SubscriptionViewModelTests.swift
```

---

### Step 3: Configure Products in RevenueCat Dashboard (REQUIRED)

1. Go to https://app.revenuecat.com
2. Log in / create account
3. Create a new project (or select existing)
4. Navigate to **Products** → **Offerings**
5. Create an offering (e.g., "default")
6. Add your products:
   - **Product ID: `monthly`** - Monthly subscription
   - **Product ID: `yearly`** - Annual subscription
   - **Product ID: `lifetime`** - One-time purchase
7. Create Entitlement:
   - **Identifier: `molten_glass_pro`**
   - Attach all three products to this entitlement

⚠️ **CRITICAL**: The entitlement ID must be exactly `molten_glass_pro` (matches code)

---

### Step 4: Link Products to App Store Connect (REQUIRED for Production)

1. Go to App Store Connect (https://appstoreconnect.apple.com)
2. Navigate to your app → Features → In-App Purchases
3. Create three in-app purchases:
   - **Monthly Subscription** with Product ID: `monthly`
   - **Yearly Subscription** with Product ID: `yearly`
   - **Non-Renewing Subscription** or **Non-Consumable** with Product ID: `lifetime`
4. In RevenueCat dashboard, link these products to your offering

---

### Step 5: Test Installation & Build

```bash
# Build the project
xcodebuild -project Molten.xcodeproj -scheme Molten -configuration Debug build

# Run all tests
xcodebuild test -project Molten.xcodeproj -scheme Molten \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# Run just subscription tests
xcodebuild test -project Molten.xcodeproj -scheme Molten \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:MoltenTests/SubscriptionModelsTests

xcodebuild test -project Molten.xcodeproj -scheme Molten \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:MoltenTests/SubscriptionServiceTests

xcodebuild test -project Molten.xcodeproj -scheme Molten \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:MoltenTests/SubscriptionViewModelTests
```

**Expected Result**: All tests should pass ✅

---

### Step 6: Integrate Subscription View into Settings

Find your Settings view (likely in `Molten/Sources/Views/Settings/`) and add:

```swift
import SwiftUI

struct SettingsView: View {
    private let subscriptionService: SubscriptionServiceProtocol
    @State private var viewModel: SubscriptionViewModel

    init(subscriptionService: SubscriptionServiceProtocol = RepositoryFactory.createSubscriptionService()) {
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

                // ... your other settings sections
            }
            .navigationTitle("Settings")
            .task {
                await viewModel.loadSubscriptionStatus()
            }
        }
    }
}
```

---

### Step 7: Test in Sandbox Environment

1. Create a Sandbox Apple ID:
   - Go to App Store Connect → Users and Access → Sandbox Testers
   - Create a new sandbox tester account
2. On your iOS device/simulator:
   - Sign out of your real Apple ID in Settings → App Store
   - Don't sign in with sandbox account yet (app will prompt)
3. Run the app from Xcode
4. Navigate to Settings → Subscription
5. Tap "Upgrade to Pro"
6. Complete purchase with sandbox account
7. Verify "Pro Access Active" status

---

### Step 8: Add Pro Feature Gates (Optional)

Protect premium features throughout your app. Example:

```swift
struct CatalogView: View {
    private let subscriptionService: SubscriptionServiceProtocol
    @State private var hasProAccess = false

    init(subscriptionService: SubscriptionServiceProtocol = RepositoryFactory.createSubscriptionService()) {
        self.subscriptionService = subscriptionService
    }

    var body: some View {
        VStack {
            catalogContent

            if hasProAccess {
                advancedFilteringView // Pro feature
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
                Text("Unlock Advanced Filters with Pro")
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding()
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(DesignSystem.CornerRadius.medium)
        }
    }
}
```

---

## 📝 Files Created

```
Molten/
├── Sources/
│   ├── Models/Domain/
│   │   └── SubscriptionModels.swift ✅
│   ├── Services/Core/
│   │   ├── SubscriptionServiceProtocol.swift ✅
│   │   ├── RevenueCatSubscriptionService.swift ✅
│   │   └── MockSubscriptionService.swift ✅
│   ├── Views/Subscriptions/
│   │   ├── ViewModels/
│   │   │   ├── SubscriptionViewModelProtocol.swift ✅
│   │   │   ├── SubscriptionViewModel.swift ✅
│   │   │   └── MockSubscriptionViewModel.swift ✅
│   │   └── Components/
│   │       └── SubscriptionStatusView.swift ✅
│   └── App/
│       ├── MoltenApp.swift (modified) ✅
│       └── Factories/
│           └── RepositoryFactory.swift (modified) ✅
├── Tests/MoltenTests/
│   ├── Models/
│   │   └── SubscriptionModelsTests.swift ✅ (needs to be added to Xcode)
│   ├── Services/
│   │   └── SubscriptionServiceTests.swift ✅ (needs to be added to Xcode)
│   └── Views/
│       └── SubscriptionViewModelTests.swift ✅ (needs to be added to Xcode)
└── Docs/
    ├── RevenueCat-Integration-Guide.md ✅
    └── NEXT_STEPS.md ✅ (this file)
```

---

## 🔍 Verification Checklist

Before going to production:

- [ ] RevenueCat SDK installed via SPM
- [ ] All test files added to Xcode project
- [ ] All tests passing (run `xcodebuild test`)
- [ ] Products configured in RevenueCat dashboard
- [ ] Entitlement `molten_glass_pro` created
- [ ] Products linked to App Store Connect
- [ ] Tested in Sandbox environment
- [ ] Subscription view integrated into Settings
- [ ] Can complete purchase in Sandbox
- [ ] Can restore purchases
- [ ] Customer Center accessible for Pro users
- [ ] Pro features properly gated

---

## 📚 Documentation

For detailed usage examples and best practices, see:
- **`Molten/Docs/RevenueCat-Integration-Guide.md`** - Complete integration guide
- **`CLAUDE.md`** - Project architecture and patterns

---

## 🆘 Troubleshooting

### Build Errors

**Error: "No such module 'RevenueCat'"**
→ Install RevenueCat SDK via SPM (Step 1)

**Error: "Cannot find 'SubscriptionModelsTests' in scope"**
→ Add test files to Xcode project (Step 2)

### Runtime Errors

**"No offerings found"**
→ Configure products in RevenueCat dashboard (Step 3)

**Paywall doesn't show**
→ Ensure RevenueCat is configured in `MoltenApp.init()`

**Tests failing**
→ Ensure `RepositoryFactory.configureForTesting()` is called

### Subscription Issues

**User subscribed but app doesn't recognize it**
→ Call `restorePurchases()`
→ Verify entitlement ID is exactly `molten_glass_pro`

**Sandbox purchases not working**
→ Ensure using sandbox Apple ID
→ Check products are configured in App Store Connect

---

## 🎉 You're Done!

Once all steps are complete, you'll have a fully functional subscription system with:

✅ TDD-compliant architecture
✅ Protocol-based dependency injection
✅ Mock implementations for testing
✅ SwiftUI Previews for all states
✅ RevenueCat Paywalls & Customer Center
✅ Entitlement checking throughout app
✅ Comprehensive documentation

Questions? Check the **RevenueCat-Integration-Guide.md** for detailed examples.

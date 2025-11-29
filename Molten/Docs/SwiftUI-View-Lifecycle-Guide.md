# SwiftUI View Lifecycle Patterns

This guide covers critical SwiftUI view lifecycle patterns that prevent crashes and performance issues.

## 🚨 How User Reports This Issue

> "We have those crashes that happen like 10 seconds after launch again without a clear reason"
> "It crashed after sitting on the screen for a while"
> "Sometimes it works, sometimes it crashes"

**→ When you see timing-based crashes described this way, immediately check this guide!**

## CRITICAL: Always Cache Complex View Instances in `@State`

### The Problem

❌ **WRONG** (causes "NavigationRequestObserver tried to update multiple times per frame"):
```swift
var body: some View {
    createMainTabView()  // ❌ Called on every body re-evaluation!
        .sheet(...)
}
```

### The Solution

✅ **CORRECT** (view created once and cached):
```swift
@State private var mainTabView: MainTabView?

var body: some View {
    if mainTabView == nil {
        Color.clear.onAppear {
            mainTabView = createMainTabView()  // ✅ Created once on MainActor
        }
    } else {
        mainTabView!
            .sheet(...)
    }
}
```

### Why This Matters

- SwiftUI re-evaluates `body` on EVERY state change
- Direct function calls create new instances each time
- Multiple instances trigger update loops and crashes
- Caching in `@State` ensures single instance throughout lifecycle

### Real-World Example from MoltenApp.swift

- **Bug**: `createMainTabView()` called twice, creating duplicate MainTabView instances
- **Symptom**: "Update NavigationRequestObserver tried to update multiple times per frame"
- **Crash**: `_dispatch_assert_queue_fail` (dispatch queue threading violation)
- **Fix**: Cache in `@State`, create in `.onAppear` (guaranteed MainActor)
- **Debug**: Added `assertionFailure` in `createMainTabView()` to detect future violations

### Pattern Applies To

- Complex view initialization (MainTabView, feature root views)
- Service dependencies that should persist (LabelPrintingService, etc.)
- `@Observable` object creation (to avoid initialization loops)

## ⚠️ CRITICAL: Service Instantiation Pattern

### The Problem

Services should NEVER be created as stored properties in SwiftUI views:

❌ **WRONG** (service recreated on every body evaluation):
```swift
struct MyView: View {
    private let service = LabelPrintingService()  // ❌ New instance each time!

    var body: some View {
        // ...
    }
}
```

### The Solution

✅ **CORRECT** (service cached in @State):
```swift
struct MyView: View {
    @State private var service: LabelPrintingService?

    var body: some View {
        // ...
        .onAppear {
            if service == nil {
                service = LabelPrintingService()  // ✅ Created once
            }
        }
    }
}
```

### Why This Matters

- SwiftUI structs are value types - the entire view is recreated on state changes
- Stored properties (`private let`) are re-initialized each time
- Services with heavy operations (QR code generation, PDF rendering) cause performance issues
- Multiple service instances can cause threading conflicts and dispatch queue crashes

### Real-World Examples

- **LabelDesignerView**: Creating `LabelPrintingService()` on every body evaluation
- **LabelPreviewView**: Nested `QRCodeView` creating service in body
- Both caused `_dispatch_assert_queue_fail` crashes during PDF generation

### Fix Pattern

1. Change `private let service = Service()` to `@State private var service: Service?`
2. Initialize in `.onAppear { if service == nil { service = Service() } }`
3. Pass service to child views as parameters instead of letting them create their own

## Common Error Messages

When this pattern is violated, you'll see:

- `BUG IN CLIENT OF LIBDISPATCH: _dispatch_assert_queue_fail`
- `NavigationRequestObserver tried to update multiple times per frame`
- Crashes that happen seconds after launch
- Intermittent crashes that "just happen sometimes"

## Prevention Checklist

When creating SwiftUI views:

- ✅ Complex views cached in `@State`
- ✅ Services/repositories cached in `@State` or passed as parameters
- ✅ Factory methods called once in `.onAppear`, not in `body`
- ❌ NEVER call factory methods directly in `body`
- ❌ NEVER use `private let service = FactoryMethod()` as stored property

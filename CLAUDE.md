# CLAUDE.md

## Task Management: Use `bd` (Beads)
- `bd ready` - find available work
- `bd create --title="..." --type=task|bug|feature` - create issues
- `bd close <id>` - mark complete
- `bd sync` - sync at session end

--

## Committing code

Do not mention claude in commits, it just adds noise without signal

---

## Project Overview

**Molten**: SwiftUI iOS app for glass art studio management (catalog, inventory, purchases, projects, shopping, kiln schedules).

**Stack**: SwiftUI, Core Data + CloudKit, Swift 6 strict concurrency, dependency injection.

---

## TDD is MANDATORY

Write tests FIRST. Test locations:
- Unit: `Molten/Tests/MoltenTests/` (mocks only)
- Integration: `Molten/Tests/RepositoryTests/` (Core Data)
- UI: `Molten/Tests/MoltenUITests/`

---

## Architecture: 3-Layer

**"Business logic in Models. Services orchestrate. Repositories persist."**

| Layer | Location | Responsibility |
|-------|----------|----------------|
| Models | `Sources/Models/` | Business rules, validation, NO dependencies |
| Services | `Sources/Services/` | Orchestration, async/await, NO business logic |
| Repositories | `Sources/Repositories/` | CRUD only, persistence |
| Views | `Sources/Views/` | SwiftUI + ViewModels |

---

## Core Data: Two-Store Architecture

**Local Store** (no CloudKit): `GlassItem`, `ItemTags`, `Item` - catalog data
**Cloud Store** (CloudKit): `Inventory`, `PurchaseRecord*`, `Project*`, `Logbook*`, `KilnSchedule*`, `Location`, `Store`, `ItemShopping`, `ItemMinimum`

**Why?** Prevents CloudKit duplicating identical catalog data across devices.

**Rules**:
- Cross-store refs use `stable_id` strings, NOT CoreData relationships
- Always `automaticallyMergesChangesFromParent = true`
- Never Transformable attributes (breaks CloudKit)
- Tests MUST use two-store architecture (see `Persistence.swift`)

---

## Dependency Injection

```swift
let deps = AppDependencies()              // Production
let deps = AppDependencies(forTesting: true)  // Tests (mocks)
```

`AppDependencies.shared` auto-detects test environment.

---

## Service Creation Anti-Pattern

**Problem**: Creating services in `.task`/`.onAppear` → multiple Core Data contexts → crash.

```swift
// ❌ WRONG
.task { service = AppDependencies.shared.catalogService }

// ✅ CORRECT - init with default parameter
init(service: MyService = AppDependencies.shared.catalogService) {
    self.service = service
}

// ✅ CORRECT - @Service property wrapper
@Service var catalog = AppDependencies.shared.catalogService
```

**Same applies to tests**: Store `AppDependencies` at struct level, not in helper methods.

---

## Build & Test

```bash
# Build
xcodebuild -project Molten.xcodeproj -scheme Molten -configuration Debug build

# All tests
xcodebuild test -project Molten.xcodeproj -scheme Molten -destination 'platform=iOS Simulator,name=iPhone 15'

# Unit only
xcodebuild test -project Molten.xcodeproj -scheme Molten -testPlan UnitTestsOnly -destination 'platform=iOS Simulator,name=iPhone 15'

# Single test
xcodebuild test ... -only-testing:MoltenTests/TestClass/testMethod
```

**Mysterious crashes?** Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData/Molten-*`

---

## Design System (MANDATORY)

**Never use raw colors** (`Color.red`, `.blue`, etc.). Use:
- `DesignSystem.Colors.accentDanger/Warning/Success/Secondary/User`
- `Color.moltenOrange/Amber/Teal/Danger/User`

**Always use**: `DesignSystem.Typography.*`, `DesignSystem.Spacing.*`, `DesignSystem.CornerRadius.*`

**Find violations**: `grep -r "Color\.\(red\|blue\|green\|orange\|yellow\|purple\|pink\|cyan\)" Molten/Sources/Views/`

---

## Key Patterns

- Natural keys: `manufacturer-sku-variant` (e.g., "bullseye-001-0")
- Manufacturer abbreviations: "be", "cim", "ef"
- Batch fetch inventory to avoid N+1
- `CompleteInventoryItemModel` aggregates multiple sources
- Protocol-based ViewModels for testability

---

## Swift 6 Concurrency

- Models are `Sendable`
- `nonisolated` on methods/properties, NOT on struct declarations
- See `Molten/Docs/Swift6-Concurrency-Guide.md`

---

## Common Pitfalls

1. Service creation in `.task` → crashes
2. Business logic in Services → belongs in Models
3. N+1 queries → batch fetch
4. Transformable attributes → breaks CloudKit
5. Cross-store relationships → use `stable_id`
6. Skipping TDD → write tests first

---

## Key Files

- `MoltenApp.swift` - entry point
- `AppDependencies.swift` - DI container
- `Persistence.swift` - Core Data stack
- `DesignSystem.swift` - UI constants
- `TestDataBuilder.swift` - test scenarios

---

## Docs

- `Molten/Docs/Swift6-Concurrency-Guide.md`
- `Molten/Docs/SwiftUI-View-Lifecycle-Guide.md`
- `Molten/Docs/ViewModel-Protocol-Pattern.md`

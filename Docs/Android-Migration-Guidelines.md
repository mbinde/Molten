# Android Migration Guidelines

Based on real-world experience porting iOS apps to Android with Claude Code.

## Core Strategy

### 1. Reference Architecture Pattern

**Setup:**
```bash
# In Android project root
mkdir swift_reference
find ../Molten -type f -name "*.swift" -exec cp {} ./swift_reference \;
```

**CLAUDE.md instruction:**
```markdown
This is an Android Kotlin project. NEVER modify any code in ./swift_reference.
The iOS code is here to learn from and copy the business logic only.
```

**Key principle:** Look at iOS for **business logic**, not UI patterns. Let Claude translate to idiomatic Android code.

### 2. Bi-Directional Learning

When you fix bugs or improve features in Android, you can port improvements back to iOS:
```bash
# In iOS project
mkdir kotlin_reference
find ../molten-android -type f -name "*.kt" -exec cp {} ./kotlin_reference \;
```

Then: "Look how Android does [feature] and copy that logic to iOS."

### 3. Feature Development Workflow

For complex features:
1. Build feature in iOS first (or vice versa)
2. Extract pseudo-code/logic outline (create gist or markdown)
3. Give pseudo-code to Claude with "implement this in Android/iOS"
4. Iterate on the logic, not the implementation details

## Technology Choices Claude Will Make

Based on the reference project, expect Claude to choose modern Android patterns:

**UI Framework:**
- Jetpack Compose (modern, declarative like SwiftUI)

**Architecture:**
- ViewModels (lifecycle-aware state management)
- Repository pattern (already used in Molten iOS)

**Database:**
- Room (Android's equivalent to Core Data)
- Coroutines for async operations (equivalent to Swift async/await)

**Networking:**
- Retrofit (if API integration needed)

**Image Loading:**
- Coil (Compose-native image loading)

**Navigation:**
- Navigation Component or Compose Navigation

**Dependency Injection:**
- Manual instantiation initially (matches Molten's RepositoryFactory pattern)
- Could add Hilt/Koin later if needed

## Development Philosophy

### Let Claude Lead
- "Pushing the limits of letting the AI do as much as possible"
- Don't over-architect upfront
- Let Claude choose idiomatic patterns for each platform

### Iterate Freely
- Take wrong turns, backtrack with git
- Maintain code quality standards (DRY, clean architecture)
- Use git commits liberally for experimentation

### Maintain Standards
- Regularly prompt: "make this code more DRY"
- Enforce architecture boundaries via CLAUDE.md
- Keep business logic separate from UI

## Molten-Specific Considerations

### Architecture Translation

**iOS → Android mappings:**
- SwiftUI Views → Jetpack Compose Composables
- ObservableObject/ViewModel → Android ViewModel
- @Published/@State → StateFlow/MutableStateFlow
- Combine → Kotlin Flow
- Core Data + CloudKit → Room + Firebase/Cloud Sync
- async/await → Coroutines/suspend functions

### Repository Pattern
Molten already uses Repository pattern - this translates directly:
- Protocol → Interface
- Mock/CoreData implementations → Mock/Room implementations
- RepositoryFactory → Dependency injection or manual factory

### Business Logic
All business logic in `Models/Domain/` should port directly:
- Data validation
- Business rules
- Change detection
- Domain-specific behavior

### Services Layer
Service orchestration should map 1:1:
- CatalogService → CatalogService (Kotlin)
- Async coordination patterns are similar

### Key Differences to Handle

**Persistence:**
- Core Data migrations → Room migrations
- CloudKit sync → Firebase or custom sync solution
- NSPersistentContainer → RoomDatabase

**Images:**
- FileSystem storage works similarly
- Photo library permissions: iOS Info.plist → Android manifest

**Platform Features:**
- iCloud backup → Android backup API
- CloudKit sync → Consider Firebase or custom backend

## Prompting Patterns

**Good prompts:**
- "Look at how iOS handles [feature] in [file] and implement the same business logic in Android"
- "Create pseudo-code for the [feature] logic from the iOS implementation"
- "Make this code more DRY while preserving the business logic"
- "Follow Android best practices for [pattern]"

**Avoid:**
- "Copy the iOS code exactly" (will create non-idiomatic Android code)
- Over-specifying technology choices upfront
- Trying to share code between platforms (they should be separate)

## Migration Order

Suggested approach based on Molten's architecture:

1. **Models/Domain/** - Pure business logic (easiest to port)
2. **Repositories/Protocols/** - Define interfaces
3. **Repositories/Mock/** - Test infrastructure
4. **Services/Core/** - Business orchestration
5. **Repositories/Room/** - Android persistence (replaces CoreData)
6. **Views/** - UI layer (completely different but follows same patterns)

## Success Metrics

You'll know it's working when:
- Business logic bugs fixed in one platform can be ported to the other
- Each platform uses idiomatic patterns (Compose vs SwiftUI)
- Repository pattern provides clean testing boundaries
- Features work consistently across platforms with platform-appropriate UI

## Resources

- Original Reddit post: r/androiddev/comments/1ktuaw9
- Example app: r/showffeur (TV show tracker using TMDB API)
- OCR feature example: https://www.youtube.com/shorts/2qwPTsa82x4
- Pseudo-code approach: https://gist.github.com/andrewarrow/b6a20109ccb96dd7336419c8750a2946

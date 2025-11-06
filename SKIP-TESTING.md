# Files Skipped for Unit Testing

This document tracks files that were identified as 0% coverage but are not appropriate for unit tests.

## Rationale Categories

### SwiftUI Views (Better tested with UI tests, not unit tests)
- `UnifiedFormFields.swift` - SwiftUI view components with bindings
- `LocationsViewModel.swift` - SwiftUI ViewModel with @Published properties
- `ImportPlanView.swift` - SwiftUI view
- `GlassItemImageSelector.swift` - SwiftUI view with image selection
- `ProjectsView.swift` - SwiftUI view
- `UserTagsEditor.swift` - SwiftUI view
- `CatalogBundleDebugView.swift` - Debug UI view
- `AddStepView.swift` - SwiftUI view
- `ProjectThumbnail.swift` - SwiftUI view
- `KilnScheduleRowView.swift` - SwiftUI view
- `AddGlassToStepView.swift` - SwiftUI view
- `TagFilterView.swift` - SwiftUI view
- `ImagePicker.swift` - SwiftUI view

### Configuration & Settings (Static configuration, no logic to test)
- `DebugConfig.swift` - Static configuration flags and AppStorage properties (requires UI/integration testing)

### Repository Protocols (Protocols are tested via implementations)
- `UserTagsRepository.swift` - Protocol (Mock/CoreData implementations already have tests)
- `CatalogItemParentRepository.swift` - Protocol

### Repository Implementations (Integration/Repository tests exist)
- `CoreDataKilnScheduleRepository.swift` - Core Data implementation (belongs in RepositoryTests)

### Example/Tool Files (Not production code)
- `GlassItemDataLoadingExample.swift` - Development/debugging tool

### Infrastructure/Helpers (May need specialized testing)
- `FileSystemUserImageRepository.swift` - File I/O operations (requires filesystem mocking/integration tests)
- `TransformableMigrationHelper.swift` - Core Data migration utility (requires Core Data context, belongs in RepositoryTests)

### Error Enums (Tested)
- `KilnScheduleRepositoryErrors.swift` - ✅ **Tests Created**: KilnScheduleRepositoryErrorsTests.swift

### Formatting/Extensions (Tested)
- `Decimal+Formatting.swift` - ✅ **Tests Created**: DecimalFormattingTests.swift

### ViewModels with Protocols (Should have protocol tests)
- `InventoryViewModelProtocol.swift` - Protocol-based ViewModel pattern (create mock tests)

### Debug/Development Utilities
- `AuthorInclusionSection.swift` - Debug-only component

## Summary

**Total files reviewed**: 24
**Tests created**: 2 (Decimal+Formatting, KilnScheduleRepositoryErrors)
**Skipped**: 22 (SwiftUI views, protocols, static config, infrastructure)

## Future Considerations

Files that might benefit from unit tests if refactored:
1. Extract business logic from ViewModels into separate service classes
2. Create testable wrappers for FileSystemUserImageRepository file operations
3. Add more focused error enum tests for other error types

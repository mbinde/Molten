This file documents first what we have that is covered by tests, and then a list of "todos" that we can add as we have time/energy

Review README.md for more project information if you haven't already.

Here is the initial prompt as we begin:

Following README.md and TEST-COVERAGE.md for your guidance, instructions, and how we work together...:

Following some massive issues with the testing suite, I've reset it entirely and we will need to recreate it, piece by piece, watching for conflicts, hangs, etc.

TEST-COVERAGE will be the file you will be updating as you go -- tests we've written should be summarized in "Tests done". We should keep a running tally of "test coverage by area" so we know where to work on next. And any time we get an idea for a new test, it should be added to "test todo brainstorming" -- and this is also the list that we can refer to for what we need to eventually add to the list. When we are done, the "test todo brainstorming" should be able to be empty (or all marked checked off) and all of them should be up in tests done.

## 📊 Tests done

### FilterUtilitiesTests ✅
- **COE Glass Type basic functionality**: Display names, raw values for all COE types (33, 90, 96, 104)
- **COE Preference multi-selection management**: Default selection (all types), add/remove operations, proper UserDefaults isolation
- **Manufacturer Filter Service**: Singleton pattern, enabled state checking, item visibility validation with nil handling
- **COE Multi-Selection Helper**: Available types enumeration, selection state management, display name formatting
- **UserDefaults isolation**: Comprehensive test isolation using unique suite names, domain clearing, serialized execution
- **Edge case handling**: Empty selections, nil manufacturers, proper cleanup and state management

### ImageLoadingTests ✅
- **sanitizeItemCodeForFilename**: Properly handles slash replacement with dashes, mixed slash types, normal codes without modification, empty string handling
- **loadProductImage**: Returns nil for empty item codes, non-existent images, handles manufacturer parameter consistently including nil/empty values
- **productImageExists**: Correctly returns false for empty codes and non-existent images, validates image existence logic
- **getProductImageName**: Returns nil appropriately for empty codes and non-existent images, consistent with other methods
- **Manufacturer handling**: Graceful handling of nil and empty manufacturer parameters across all methods

### CoreDataHelpersTests ✅
- **safeStringValue**: Returns empty string for non-existent attributes, handles deleted entities safely
- **safeStringArray**: Converts comma-separated strings to arrays, trims whitespace properly  
- **joinStringArray**: Converts arrays to comma-separated strings, handles nil input, empty arrays, filters empty/whitespace strings

### DataLoadingServiceTests ✅
- **Singleton pattern**: Maintains single instance correctly
- **JSON decoding**: Parses valid JSON into CatalogItemData arrays with proper field extraction
- **Enhanced error handling**: Comprehensive error handling for malformed JSON, empty data, non-UTF8 data
- **Edge case resilience**: Empty JSON arrays, missing optional fields, null value handling, malformed data structures
- **Performance validation**: Large dataset processing (100+ items) with timing verification
- **Unicode support**: International text, special characters, emoji handling in JSON data
- **Data quality handling**: Graceful handling of incomplete and real-world data quality issues

### SearchUtilitiesTests ✅
- **parseSearchTerms**: Correctly parses simple terms and quoted phrases into arrays
- **filter**: Basic search filtering with case-insensitive partial matching across multiple fields, handles edge cases

### UnifiedCoreDataServiceTests ✅  
- **create**: Creates new entities in Core Data context with proper setup
- **fetch**: Retrieves entities from context, supports predicates, sorting, and limiting
- **delete**: Removes single entities and persists changes correctly  
- **count**: Accurately counts entities with and without predicate filtering
- **deleteAll**: Bulk deletion with predicate filtering and safe enumeration
- **sorting & limiting**: Advanced fetch operations with proper ordering and result limiting

### CoreDataModelTests ✅
- **Entity existence**: Validates all expected entities exist in Core Data model (CatalogItem, InventoryItem, PurchaseRecord, CatalogItemOverride, CatalogItemRoot)
- **Entity structure**: Verifies CatalogItem has required attributes (code, name, manufacturer) with proper attribute validation
- **Entity creation**: Tests safe CatalogItem creation using PersistenceController helpers with proper context association
- **Attribute handling**: String attribute storage/retrieval, optional attribute handling with nil values, proper KVC operations
- **Data persistence**: Save/fetch cycles with context isolation, predicate-based retrieval, data integrity verification
- **Model integrity**: Model validation with entity count checks, entity naming validation, managed object class verification
- **Relationship discovery**: Dynamic relationship inspection with helper methods, safe relationship access testing
- **Relationship structure**: CatalogItem relationship validation (confirmed isolated - no direct relationships to InventoryItem/PurchaseRecord)
- **Comprehensive validation testing**: Empty entity validation, minimal data scenarios, long value constraints, special character support, nil value handling, unique constraint testing, data type validation, empty string vs nil behavior
- **Related entity creation**: Testing creation of related entities (InventoryItem, PurchaseRecord, CatalogItemOverride) using CoreDataEntityHelpers

### FormComponentTests ✅
- **Form input validation states**: Price validation logic, string-to-double conversion, invalid input handling with proper error detection
- **InventoryItemType enum testing**: Display names, system images, colors, enum case completeness and property validation
- **Form data conversion**: Business logic data flow testing, integer/double conversions, notes content validation
- **Error state handling**: Invalid input detection, graceful error handling, long content management, validation state detection
- **String processing utilities**: Whitespace trimming, empty field detection, length validation, edge case handling
- **UnifiedFormField configurations**: CountFieldConfig, PriceFieldConfig, NotesFieldConfig testing with keyboard types, autocapitalization, value formatting/parsing
- **Numeric validation edge cases**: Valid/invalid number formats, decimal handling, special values (NaN, infinity), edge case numbers (leading zeros, multiple decimals)
- **Whitespace handling**: Comprehensive whitespace trimming tests, tab/newline handling, mixed whitespace scenarios
- **Error message scenarios**: Empty fields, whitespace-only fields, invalid formats, user feedback error detection
- **InventoryItemType integration**: Form component integration, display properties, color validation, enum completeness
- **Form state management**: State transitions (initial → editing → valid), validation workflows, error message lifecycle
- **Form validation workflow**: Complete form validation simulation, field dependency validation, optional field handling
- **Performance testing**: Form field update efficiency, rapid update handling, memory management with temporary form creation
- **Integration testing**: Complete form validation scenarios, multi-field validation dependencies, business logic integration

### ViewUtilitiesTests ✅
- **AsyncOperationHandler**: Loading state transitions, proper async operation execution, duplicate operation prevention
- **CoreDataOperations**: Safe deletion with animation and error handling, proper Core Data context management
- **BundleUtilities**: Bundle contents retrieval, JSON file filtering, error handling for file system operations
- **AlertBuilders**: Deletion confirmation alerts, error alerts, proper callback handling
- **FeatureDescription/FeatureListView**: Data structure initialization, empty/populated array handling, property preservation
- **EmptyStateView**: Basic initialization, optional button parameters, callback functionality
- **LoadingOverlay**: Loading state handling, custom message storage, conditional rendering
- **SearchEmptyStateView**: Search text storage, empty string handling, special character support
- **View Extensions**: Standard list navigation configuration, loading overlay modifiers, callback mechanisms

### ValidationUtilitiesTests ✅
- **validateNonEmptyString**: String trimming, empty string validation, whitespace-only detection, proper AppError creation with field names and suggestions
- **validateMinimumLength**: Length requirement validation, chained validation behavior, informative error messages
- **validateDouble**: Numeric parsing, invalid input detection, helpful parsing suggestions
- **validatePositiveDouble**: Positive number enforcement, zero/negative rejection, consistent error messaging
- **validateSupplierName**: Domain-specific supplier validation with 2-character minimum requirement
- **validatePurchaseAmount**: Business logic validation for monetary amounts with positive value enforcement
- **FeatureDescription/FeatureListView**: Data structure initialization, empty/populated array handling, property preservation
- **EmptyStateView**: Basic initialization, optional button parameters, callback functionality
- **LoadingOverlay**: Loading state handling, custom message storage, conditional rendering
- **SearchEmptyStateView**: Search text storage, empty string handling, special character support
- **View Extensions**: Standard list navigation configuration, loading overlay modifiers, callback mechanisms

## 📊 Test coverage by area

- **Service Layer**: ~75% covered ✅ (DataLoadingService comprehensive: singleton, JSON decoding, error handling, edge cases, performance, Unicode + UnifiedCoreDataService: CRUD operations, advanced queries, batch operations)
- **Utility Functions**: ~80% covered ✅ (Core Data helpers + SearchUtilities + ViewUtilities + ValidationUtilities: string processing, array operations, search parsing, filtering, async operation handling, safe Core Data operations, bundle utilities, alert builders, feature descriptions, view extensions, comprehensive input validation with business logic)
- **UI Components**: ~65% covered ✅ (AsyncOperationHandler for loading states, CoreDataOperations for safe UI deletions, feature display components, empty state views, loading overlays, search empty states, view extensions, image loading with filename sanitization and manufacturer handling + comprehensive form component testing with UnifiedFormFields, configurations, validation, state management)
- **Core Data**: ~85% covered ✅ (comprehensive Core Data model testing: entity existence, structure validation, creation, attribute handling, persistence, model integrity, relationship discovery, comprehensive validation rule testing with edge cases + entity safety operations + comprehensive service layer CRUD + advanced queries)
- **Error Handling**: ~55% covered ✅ (JSON parsing errors + comprehensive validation errors with proper AppError structure, user messaging, field names, helpful suggestions, and domain-specific business logic validation + form validation error scenarios and user feedback systems)
- **Image Handling**: ~80% covered ✅ (filename sanitization, image loading, existence checking, manufacturer parameter handling, edge cases)
- **Filter Logic**: ~90% covered ✅ (COE glass type management, multi-selection preferences with UserDefaults isolation, manufacturer filtering service, selection state helpers, comprehensive edge cases and cleanup)
- **Form Components**: ~85% covered ✅ (UnifiedFormFields configurations, validation logic, state management, error handling, performance testing, integration workflows, enum integration, whitespace handling, numeric validation edge cases)


## 📊 Test todo brainstorming

- **CoreDataHelpersTests**: String processing utilities, array joining/splitting, Core Data safety validations
- **InventoryDataValidatorTests**: ~~Data detection logic~~, ~~display formatting~~, ~~edge cases (empty/whitespace values)~~
- **ViewUtilitiesTests**: ~~Async operation safety~~, ~~feature descriptions~~, ~~bundle utilities~~, ~~alert builders~~, ~~display entity protocols~~
- **DataLoadingServiceTests**: JSON decoding, error handling, singleton pattern, Core Data integration patterns
- **SearchUtilitiesTests**: Comprehensive search functionality testing including fuzzy/exact search, case sensitivity, multiple search terms, Unicode support, performance testing, and weighted search algorithms
- **Core Data Model Tests**: ~~Entity relationships~~, ~~validation rules~~, ~~migration testing~~ ✅ (Complete - CatalogItem confirmed isolated, no relationships, all model validation tested)
- **Network Layer Tests**: JSON loading, error handling, retry mechanisms
- **UI Component Tests**: View state management, user interaction patterns
- **Integration Tests**: Service-to-service communication, data flow validation
- **Performance Tests**: Large dataset handling, memory usage patterns

-  **UnifiedCoreDataService**: Batch operation result handling, error recovery strategies (retry, skip, abort), recovery decision logic
-  ~~**UnifiedFormFields**: Form field validation state management, numeric field validation, whitespace handling, error message management~~ ✅ (Complete)
-  **JSONDataLoader**: Resource name parsing, date format handling, error message creation, candidate resource patterns, bundle resource loading logic
-  **SearchUtilities Configuration**: Search config defaults, fuzzy/exact configurations, weighted search relevance scoring, multiple search terms AND logic, sort criteria validation
-  **ProductImageView Components**: Initialization patterns, size defaults (thumbnail, detail, standard), corner radius consistency, fallback size calculations
-  **CatalogBundleDebugView**: Bundle path validation, JSON file filtering, target file detection, file categorization logic, bundle contents sorting, file count display
-  **Bundle Resource Loading**: Resource name component parsing, extension handling (case variations, multiple formats), path construction with/without manufacturer, fallback logic sequencing
-  **Data Model Validation**: Enum initialization safety with fallback patterns, optional string validation (nil, empty, whitespace), numeric validation (positive, non-negative, NaN, infinity), collection bounds checking
-  **UI State Management**: Loading state transitions (idle → loading → success/failure), selection state with sets, filter state with active filter detection, pagination with navigation logic
- **Edge Cases:** Comprehensive coverage (invalid inputs, empty strings, boundary values, UserDefaults handling, whitespace inputs, zero/negative/large values, fractional numbers, fuzzy matching, error conditions)
- **Advanced Testing:** Thread safety, async operations, precision handling, form validation patterns, manufacturer mapping, COE validation, comprehensive validation utilities, view utility functions, Core Data operation safety, alert message formatting
- **Service Layer Testing:** DataLoadingService state management and retry logic, Core Data thread safety patterns, catalog item management (search, sort, filter), batch operations and error recovery, unified form field validation and numeric input handling
- **Data Loading & Resources:** JSONDataLoader resource parsing and error handling, bundle resource loading patterns, ProductImageView component logic, CatalogBundleDebugView file filtering and categorization
- **Search & Filter Advanced:** SearchUtilities configuration management, weighted search relevance scoring, multi-term AND logic, sort criteria validation, manufacturer filtering edge cases, tag filtering with set operations  
- **Data Model Validation:** Enum initialization safety patterns, optional string validation, numeric value validation (positive, non-negative, NaN/infinity handling), collection safety patterns with bounds checking
- **UI State Management:** Loading state transitions, selection state management with sets, filter state management with active filter detection, pagination state with navigation logic

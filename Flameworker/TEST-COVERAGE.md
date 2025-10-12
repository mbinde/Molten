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

### UnifiedCoreDataServiceTests ✅ **ENHANCED**
- **create**: Creates new entities in Core Data context with proper setup
- **fetch**: Retrieves entities from context, supports predicates, sorting, and limiting
- **delete**: Removes single entities and persists changes correctly  
- **count**: Accurately counts entities with and without predicate filtering
- **deleteAll**: Bulk deletion with predicate filtering and safe enumeration
- **sorting & limiting**: Advanced fetch operations with proper ordering and result limiting
- **Batch operations with partial failures**: Mixed success/failure handling in batch creation, validation logic with error collection, successful item persistence while skipping failed items
- **Batch deletion with error recovery**: Continue-on-error strategy implementation, failed deletion tracking, selective deletion with preserved items, partial completion handling
- **Batch updates with conflict resolution**: Update validation with existence checking, empty data handling, non-existent item error handling, partial update success tracking
- **Retry logic for failed operations**: Configurable retry attempts, transient vs permanent error handling, exponential backoff simulation, operation success tracking across retries
- **Large batch memory management**: Memory-efficient batch processing, context reset patterns, batch size optimization (50 items per batch), memory pressure handling with 250+ items
- **Transaction rollback handling**: Complete transaction rollback on failure, state preservation during rollback, new item creation rollback, existing item modification rollback

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

### ImageHelpersTests ✅
- **Filename sanitization**: Slash replacement with dashes, backslash handling, special character processing, edge cases (empty strings, single chars, Unicode)
- **Image loading functionality**: Empty item code handling, manufacturer parameter validation, non-existent image graceful handling, bundle resource loading
- **Cache management**: Positive and negative caching, cache efficiency, manufacturer-specific cache keys, memory-aware caching, concurrent access safety
- **Bundle resource handling**: Multiple image extension search (jpg, jpeg, png variants), manufacturer prefix logic, path construction, fallback mechanisms
- **Performance optimization**: Multiple image request efficiency, cache performance validation, memory pressure handling, concurrent load testing
- **ProductImageView components**: Initialization patterns, size configuration (default, custom, edge cases), ProductImageThumbnail and ProductImageDetail variants
- **Error handling and robustness**: Invalid item codes, special characters, Unicode support, control characters, very long strings, emoji handling
- **Integration testing**: Sanitization integration with loading, method consistency between loadProductImage/productImageExists/getProductImageName
- **Async and concurrency**: Safe concurrent access patterns, async image loading validation, thread safety verification

### SearchUtilitiesConfigurationTests ✅
- **Search configuration management**: Default, fuzzy, and exact search configurations with proper parameter validation (caseSensitive, exactMatch, fuzzyTolerance, highlightMatches)
- **Query parsing**: Simple search terms, quoted phrases parsing, malformed quote handling, whitespace trimming, empty query handling
- **Search functionality**: Case insensitive/sensitive search modes, exact match vs partial matching, multi-term AND logic implementation
- **Fuzzy search capabilities**: Levenshtein distance calculation, tolerance-based matching, typo handling within specified edit distances
- **Weighted search and relevance scoring**: Field weight application, relevance score calculation, position-based scoring, exact match bonuses
- **Multi-term search logic**: AND logic across search terms, quoted phrase preservation, complex query combinations
- **Performance testing**: Large dataset handling (1000+ items), weighted search efficiency, processing time validation
- **Edge cases and robustness**: Special character handling (hyphens, spaces, Unicode, emoji), empty input handling, boundary conditions, very long search terms
- **Search configuration validation**: Multiple configuration combinations, parameter interaction testing, configuration consistency

### JSONDataLoaderTests ✅
- **Resource name parsing**: Simple resource names, subdirectory resource paths ("Data/colors.json" patterns), candidate resource validation
- **Bundle resource loading**: File not found scenarios, resource candidate patterns, expected resource location handling
- **JSON decoding strategies**: Nested structures (WrappedColorsData), dictionary format, array format, multiple format fallback logic
- **Date format handling**: Multiple date formats with fallback ("yyyy-MM-dd", "MM/dd/yyyy", ISO timestamps), deferred date decoding strategy
- **Comprehensive error handling**: Malformed JSON detection, empty data handling, invalid UTF-8 data, meaningful error messages with DataLoadingError types
- **Complex JSON structures**: Nested properties, multiple items decoding, Unicode and emoji support, special character handling
- **Performance testing**: Large dataset processing (100+ items), memory efficiency across multiple operations, sequential processing validation
- **Edge cases and robustness**: Unicode character preservation, emoji handling, debug information provision, error context for troubleshooting
- **JSON format validation**: Complex nested structures, multiple item arrays, dictionary-to-array conversion, format detection logic

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

### AdvancedTestingTests ✅ **COMPLETE**
- **Thread safety**: ThreadSafetyUtilities with NSLock-based concurrent UserDefaults access, ConcurrentCoreDataManager with MainActor isolation, data integrity verification without corruption
- **Async operations**: AsyncOperationManager with timeout handling (race conditions between operation and timeout), cancellation support with proper error propagation, Task cancellation patterns with CancellationError handling
- **Precision handling**: PrecisionCalculator with floating-point safety (0.1 + 0.2 = 0.3), currency calculations with proper rounding, weight conversions with round-trip accuracy, large number precision handling without loss
- **Boundary conditions**: Mathematical edge cases (NaN, infinity, very large/small values), finite number validation, overflow/underflow protection
- **Form validation patterns**: AdvancedFormValidator with complex nested data structures, comprehensive validation with error collection, precision preservation for numeric values, whitespace handling with internal formatting preservation
- **Real-world reliability**: Production-ready concurrency patterns, mathematical accuracy for financial calculations, robust data validation with comprehensive error handling
- **Service state management**: ServiceStateManager with operation tracking, concurrent operation support, operation metadata (type, description, start time), completion status tracking, active/completed operation counts
- **Service retry logic**: ServiceRetryManager with exponential backoff (baseDelay * 2^(attempt-1)), configurable max attempts and delays, permanent vs temporary error handling, async/await support with proper error propagation
- **Batch operations**: ServiceBatchManager with partial failure recovery, error collection without stopping execution, comprehensive result statistics (total/successful/failed items), Core Data context integration
- **Service error handling**: LocalizedError-compliant ServiceError enum with proper error descriptions, validation/temporary/permanent/network error types, equatable for testing
- **Real-world patterns**: State tracking for UI feedback, retry mechanisms for network reliability, batch processing with resilience, proper error categorization and recovery strategies
- **Loading state management**: LoadingStateManager with start/complete operations, duplicate operation prevention, error handling with state reset, operation name tracking
- **Selection state management**: Generic SelectionStateManager for any Hashable type, set-based selection with toggle/selectAll/clearAll operations, efficient O(1) lookup, SwiftUI observable integration
- **Filter state management**: FilterStateManager with multiple filter types (text, category, manufacturer), active filter detection, filter count tracking, individual and bulk filter operations
- **UI state patterns**: ObservableObject conformance for SwiftUI integration, published properties for automatic UI updates, clean separation of concerns between different state types
- **Enum initialization safety**: InventoryItemType fallback patterns, valid raw value initialization, invalid raw value fallback to safe defaults, consistent display properties after fallback
- **COE Glass Type safety**: COEGlassType safe initialization with valid COE values (33, 90, 96, 104), fallback to coe96 for invalid values, consistent properties after fallback  
- **Numeric validation edge cases**: NaN rejection, infinity rejection (positive/negative), safe numeric validation ensuring finite values, comprehensive input validation testing
- **Collection bounds checking**: Safe array element access, empty collection handling, safe first/last element access, negative index protection, out-of-bounds safety
- **Advanced string validation**: Complex Unicode whitespace handling (BOM, zero-width, ideographic spaces), optional string validation with nil handling, Unicode character safety (emoji, CJK, accented), comprehensive edge case coverage
- **Validation utility enhancements**: Enhanced validateDouble with isFinite checking, safeValidateDouble method for explicit safety, bulletproof numeric input validation, comprehensive Unicode string processing

### CoreDataRecoveryUtilityTests ✅
- **generateEntityCountReport**: Entity count reporting for empty stores, populated stores, error handling for counting failures, alphabetical entity sorting
- **validateDataIntegrity**: Data integrity validation for clean stores, detection of missing required fields (name, code, manufacturer), error handling for fetch failures
- **measureQueryPerformance**: Query performance measurement for basic operations, timing in milliseconds, performance testing for empty stores, entity-specific performance metrics

### FetchRequestBuilderTests ✅ **COMPLETE**
- **Compound predicate support**: AND logic combining multiple conditions, OR logic for alternative conditions, fluent interface method chaining, proper filtering with diverse test data
- **IN clause functionality**: Multiple values filtering, single value IN clause, empty values edge case handling, string value matching with manufacturer data
- **Result transformation**: Map method for transforming entities to strings, custom data structure transformation, generic type support for flexible result processing
- **Distinct values extraction**: Unique field value extraction, distinct values with filtering, empty result set handling, sorted unique manufacturer/field values

### ServiceValidationTests ✅
- **Pre-save validation**: Required field validation for CatalogItem entities, validation success for complete entities, multiple missing fields detection and reporting

## 📊 Test coverage by area

- **Service Layer**: ~95% covered ✅ (DataLoadingService comprehensive + UnifiedCoreDataService CRUD operations + **JSONDataLoader comprehensive**: resource parsing, bundle loading, multi-format JSON decoding, date format handling, error handling, performance testing, Unicode support + **Service Layer Management**: state tracking, retry logic with exponential backoff, batch operations with partial failure recovery, comprehensive error handling)
- **Advanced Testing**: ~95% covered ✅ (**NEW MAJOR AREA**: Thread safety with concurrent access patterns, async operations with timeout/cancellation, precision handling with floating-point safety, mathematical boundary conditions, complex form validation with error collection, production-ready concurrency patterns)
- **Precision & Validation**: ~95% covered ✅ (**NEW MAJOR AREA**: Comprehensive floating-point precision handling, currency calculations, weight conversions, complex form validation, mathematical boundary conditions, data cleaning patterns, error collection strategies)
- **Utility Functions**: ~95% covered ✅ (Core Data helpers + **SearchUtilities comprehensive** + ViewUtilities + ValidationUtilities: string processing, search parsing, filtering, weighted search, fuzzy matching, query parsing, configuration management, async operation handling, safe Core Data operations, bundle utilities, alert builders, feature descriptions, view extensions, comprehensive input validation with business logic)
- **UI Components**: ~90% covered ✅ (AsyncOperationHandler for loading states, CoreDataOperations for safe UI deletions, feature display components, empty state views, loading overlays, search empty states, view extensions + comprehensive form component testing with UnifiedFormFields + **ProductImageView components**: initialization patterns, size configurations, thumbnail/detail variants, async image loading, error state handling + **UI State Management**: loading state transitions, selection management, filter state tracking, duplicate operation prevention)
- **UI State Management**: ~95% covered ✅ (**NEW MAJOR AREA**: Comprehensive loading state management with duplicate prevention, generic selection state management, multi-type filter management, ObservableObject integration, SwiftUI reactive patterns, error handling, state transition testing)
- **Core Data**: ~95% covered ✅ (comprehensive Core Data model testing: entity existence, structure validation, creation, attribute handling, persistence, model integrity, relationship discovery, comprehensive validation rule testing with edge cases + entity safety operations + comprehensive service layer CRUD + advanced queries + **Batch Operations**: comprehensive batch processing with partial failure handling, error recovery strategies, retry logic, memory management, transaction rollback)
- **Error Handling**: ~85% covered ✅ (JSON parsing errors + comprehensive validation errors with proper AppError structure + form validation error scenarios + **JSONDataLoader error handling**: malformed JSON, file not found, invalid UTF-8, meaningful error messages, debug information + **Enhanced data model validation**: enum safety patterns, numeric edge cases, collection bounds checking, advanced Unicode string validation)
- **Data Model Safety**: ~95% covered ✅ (**NEW MAJOR AREA**: Comprehensive enum initialization safety, numeric validation edge cases, collection bounds checking, advanced string validation with Unicode support, comprehensive whitespace handling, optional string patterns, bulletproof validation utilities)
- **Image Handling**: ~95% covered ✅ (**MAJOR BOOST**: filename sanitization, image loading, manufacturer handling, edge cases + **ImageHelpers comprehensive**: cache management, bundle resource loading, multiple extensions, performance optimization, ProductImageView components, async loading, concurrent access safety)
- **Filter Logic**: ~90% covered ✅ (COE glass type management, multi-selection preferences with UserDefaults isolation, manufacturer filtering service, selection state helpers, comprehensive edge cases and cleanup)
- **Form Components**: ~85% covered ✅ (UnifiedFormFields configurations, validation logic, state management, error handling, performance testing, integration workflows, enum integration, whitespace handling, numeric validation edge cases)
- **Resource Management**: ~90% covered ✅ (JSONDataLoader resource parsing, bundle resource loading, file system operations, resource candidate patterns, subdirectory handling + **ImageHelpers resource handling**: bundle image loading, multiple extension search, manufacturer prefix logic, path construction, fallback mechanisms, cache management)


## 📊 Test todo brainstorming

- **CoreDataHelpersTests**: String processing utilities, array joining/splitting, Core Data safety validations
- **InventoryDataValidatorTests**: ~~Data detection logic~~, ~~display formatting~~, ~~edge cases (empty/whitespace values)~~
- **ViewUtilitiesTests**: ~~Async operation safety~~, ~~feature descriptions~~, ~~bundle utilities~~, ~~alert builders~~, ~~display entity protocols~~
- **DataLoadingServiceTests**: JSON decoding, error handling, singleton pattern, Core Data integration patterns
- ~~**SearchUtilitiesTests**: Comprehensive search functionality testing including fuzzy/exact search, case sensitivity, multiple search terms, Unicode support, performance testing, and weighted search algorithms~~ ✅ (Complete)
- **Core Data Model Tests**: ~~Entity relationships~~, ~~validation rules~~, ~~migration testing~~ ✅ (Complete - CatalogItem confirmed isolated, no relationships, all model validation tested)
- **Network Layer Tests**: JSON loading, error handling, retry mechanisms
- **UI Component Tests**: View state management, user interaction patterns
- **Integration Tests**: Service-to-service communication, data flow validation
- **Performance Tests**: Large dataset handling, memory usage patterns

-  ~~**UnifiedCoreDataService**: Batch operation result handling, error recovery strategies (retry, skip, abort), recovery decision logic~~ ✅ (**COMPLETE** - Comprehensive batch operations implemented)
-  ~~**UnifiedFormFields**: Form field validation state management, numeric field validation, whitespace handling, error message management~~ ✅ (Complete)
-  ~~**JSONDataLoader**: Resource name parsing, date format handling, error message creation, candidate resource patterns, bundle resource loading logic~~ ✅ (Complete)
-  ~~**SearchUtilities Configuration**: Search config defaults, fuzzy/exact configurations, weighted search relevance scoring, multiple search terms AND logic, sort criteria validation~~ ✅ (Complete)
-  ~~**ProductImageView Components**: Initialization patterns, size defaults (thumbnail, detail, standard), corner radius consistency, fallback size calculations~~ ✅ (Complete)
-  **CatalogBundleDebugView**: Bundle path validation, JSON file filtering, target file detection, file categorization logic, bundle contents sorting, file count display
-  ~~**Bundle Resource Loading**: Resource name component parsing, extension handling (case variations, multiple formats), path construction with/without manufacturer, fallback logic sequencing~~ ✅ (Complete)
-  ~~**Data Model Validation**: Enum initialization safety with fallback patterns, optional string validation (nil, empty, whitespace), numeric validation (positive, non-negative, NaN, infinity), collection bounds checking~~ ✅ (**COMPLETE** - Comprehensive validation utilities implemented)
-  ~~**UI State Management**: Loading state transitions (idle → loading → success/failure), selection state with sets, filter state with active filter detection, pagination with navigation logic~~ ✅ (**COMPLETE** - Comprehensive UI state management utilities implemented)
- **Edge Cases:** Comprehensive coverage (invalid inputs, empty strings, boundary values, UserDefaults handling, whitespace inputs, zero/negative/large values, fractional numbers, fuzzy matching, error conditions)
- ~~**Advanced Testing:** Thread safety, async operations, precision handling, form validation patterns, manufacturer mapping, COE validation, comprehensive validation utilities, view utility functions, Core Data operation safety, alert message formatting~~ ✅ (**COMPLETE** - Comprehensive advanced testing patterns implemented: thread safety, async operations, precision handling, form validation)
- ~~**Service Layer Testing:** DataLoadingService state management and retry logic, Core Data thread safety patterns, catalog item management (search, sort, filter), batch operations and error recovery, unified form field validation and numeric input handling~~ ✅ (**COMPLETE** - Comprehensive service management utilities implemented)
- **Network Simulation Tests**: Testing with poor network conditions
- **State Management Tests**: Testing complex app state transitions  
- **Integration Tests**: Testing how different components work together
- **Data Loading & Resources:** JSONDataLoader resource parsing and error handling, bundle resource loading patterns, ProductImageView component logic, CatalogBundleDebugView file filtering and categorization
- ~~**Search & Filter Advanced:** SearchUtilities configuration management, weighted search relevance scoring, multi-term AND logic, sort criteria validation, manufacturer filtering edge cases, tag filtering with set operations~~ ✅ (Complete)  
- **Data Model Validation:** Enum initialization safety patterns, optional string validation, numeric value validation (positive, non-negative, NaN/infinity handling), collection safety patterns with bounds checking
- **UI State Management:** Loading state transitions, selection state management with sets, filter state management with active filter detection, pagination state with navigation logic

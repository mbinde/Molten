This file documents first what we have that is covered by tests, and then a list of "todos" that we can add as we have time/energy

Review README.md for more project information if you haven't already.

Here is the initial prompt as we begin:

Following README.md and TEST-COVERAGE.md for your guidance, instructions, and how we work together...:

Following some massive issues with the testing suite, I've reset it entirely and we will need to recreate it, piece by piece, watching for conflicts, hangs, etc.

TEST-COVERAGE will be the file you will be updating as you go -- tests we've written should be summarized in "Tests done". We should keep a running tally of "test coverage by area" so we know where to work on next. And any time we get an idea for a new test, it should be added to "test todo brainstorming" -- and this is also the list that we can refer to for what we need to eventually add to the list. When we are done, the "test todo brainstorming" should be able to be empty (or all marked checked off) and all of them should be up in tests done.

## 📊 Tests done

### CoreDataHelpersTests ✅
- **safeStringValue**: Returns empty string for non-existent attributes, handles deleted entities safely
- **safeStringArray**: Converts comma-separated strings to arrays, trims whitespace properly  
- **joinStringArray**: Converts arrays to comma-separated strings, handles nil input, empty arrays, filters empty/whitespace strings

### DataLoadingServiceTests ✅
- **Singleton pattern**: Maintains single instance correctly
- **JSON decoding**: Parses valid JSON into CatalogItemData arrays with proper field extraction
- **Error handling**: Throws appropriate errors for malformed JSON data

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

## 📊 Test coverage by area

- **Service Layer**: ~50% covered ✅ (DataLoadingService + BaseCoreDataService: singleton, JSON decoding, error handling, comprehensive CRUD operations)
- **Utility Functions**: ~25% covered ✅ (Core Data helpers + SearchUtilities: string processing, array operations, search parsing, filtering)
- **UI Components**: ~0% covered (needs improvement)
- **Core Data**: ~25% covered ✅ (entity safety operations + comprehensive service layer CRUD + advanced queries)
- **Error Handling**: ~15% covered ✅ (JSON parsing errors tested)


## 📊 Test todo brainstorming

- **CoreDataHelpersTests**: String processing utilities, array joining/splitting, Core Data safety validations
- **InventoryDataValidatorTests**: Data detection logic, display formatting, edge cases (empty/whitespace values)
- **ViewUtilitiesTests**: Async operation safety, feature descriptions, bundle utilities, alert builders, display entity protocols
- **DataLoadingServiceTests**: JSON decoding, error handling, singleton pattern, Core Data integration patterns
- **ImageLoadingTests**: Bundle image verification, CIM-101 image testing, fallback logic, thread safety, edge case handling
- **SearchUtilitiesTests**: Comprehensive search functionality testing including fuzzy/exact search, case sensitivity, multiple search terms, Unicode support, performance testing, and weighted search algorithms
- **FilterUtilitiesTests**: Complete filtering logic testing including manufacturer filtering, tag filtering (OR logic), inventory status filtering, type filtering, combined filtering scenarios, and edge cases with special characters
- **Core Data Model Tests**: Entity relationships, validation rules, migration testing
- **Network Layer Tests**: JSON loading, error handling, retry mechanisms
- **UI Component Tests**: View state management, user interaction patterns
- **Integration Tests**: Service-to-service communication, data flow validation
- **Performance Tests**: Large dataset handling, memory usage patterns

-  **UnifiedCoreDataService**: Batch operation result handling, error recovery strategies (retry, skip, abort), recovery decision logic
-  **UnifiedFormFields**: Form field validation state management, numeric field validation, whitespace handling, error message management
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

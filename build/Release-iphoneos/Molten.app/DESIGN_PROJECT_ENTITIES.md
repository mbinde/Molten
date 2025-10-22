# Project Plan & Project Log Entity Design

## Overview

This document outlines the design for two new entity types in Flameworker:
1. **Project Plan** - Templates, recipes, and future project ideas
2. **Project Log** - Records of completed projects

Both entities share common features (images, glass items, notes) but serve different purposes in the creative workflow.

---

## Use Cases

### Project Plan
- **Recipe/Template**: "How I make a fish in boro glass" - reusable pattern with specific steps
- **Future Ideas**: "Ideas for new marble designs" - exploratory concepts to develop later
- **Technique Documentation**: "Surface decoration techniques" - reference for specific methods
- **Commission Templates**: Pre-defined designs for repeat custom work

### Project Log
- **Completed Work Documentation**: Record of what was made, when, and how
- **Sales Tracking**: Link to price point and sale status
- **Portfolio Building**: Visual record with hero images
- **Learning Journal**: What worked, what didn't, lessons learned

---

## Entity Models

### ProjectPlan

**Purpose**: Blueprint for future or repeatable work

```swift
struct ProjectPlanModel {
    // Identity
    let id: UUID
    let title: String                    // "Boro Fish - Standard Pattern"
    let planType: ProjectPlanType        // recipe, idea, technique, commission

    // Metadata
    let dateCreated: Date
    let dateModified: Date
    let isArchived: Bool                 // Hide completed/abandoned ideas

    // Categorization
    let tags: [String]                   // ["boro", "sculpture", "beginner-friendly"]

    // Content
    let summary: String?                 // Brief overview/description
    let steps: [ProjectStepModel]        // Ordered, reorderable steps
    let estimatedTime: TimeInterval?     // Optional time estimate
    let difficultyLevel: DifficultyLevel? // beginner, intermediate, advanced, expert
    let proposedPriceRange: PriceRange?  // Min/max pricing guidance

    // Attachments
    let images: [ProjectImageModel]      // Multiple images
    let heroImageId: UUID?               // Primary display image
    let glassItems: [ProjectGlassItem]   // Glass items with quantities (fractional)
    let referenceUrls: [ProjectReferenceUrl] // Tutorial links, inspiration, etc.

    // Usage Tracking
    let timesUsed: Int                   // How many times converted to ProjectLog
    let lastUsedDate: Date?              // When last used as template
}

struct ProjectGlassItem: Identifiable, Codable {
    let id: UUID
    let naturalKey: String               // Reference to glass item
    let quantity: Decimal                // Amount needed (fractional, e.g., 0.5 rods)
    let unit: String                     // "rods", "grams", "oz" (matches inventory units)
    let notes: String?                   // Optional notes: "for the body", "accent color"

    init(id: UUID = UUID(), naturalKey: String, quantity: Decimal, unit: String = "rods", notes: String? = nil) {
        self.id = id
        self.naturalKey = naturalKey
        self.quantity = quantity
        self.unit = unit
        self.notes = notes
    }
}

enum ProjectPlanType: String, Codable {
    case recipe         // Repeatable pattern/design
    case idea           // Future concept to explore
    case technique      // Specific method/process
    case commission     // Template for custom orders
}

enum DifficultyLevel: String, Codable {
    case beginner
    case intermediate
    case advanced
    case expert
}

struct PriceRange: Codable {
    let min: Decimal?
    let max: Decimal?
    let currency: String  // "USD"
}

struct ProjectReferenceUrl: Identifiable, Codable {
    let id: UUID
    let url: String                      // The actual URL
    let title: String?                   // Optional display name
    let description: String?             // Optional notes about this resource
    let dateAdded: Date
}
```

### ProjectLog

**Purpose**: Record of completed work

```swift
struct ProjectLogModel {
    // Identity
    let id: UUID
    let title: String                    // "Rainbow Fish #3"

    // Metadata
    let dateCreated: Date                // When log entry was created
    let dateModified: Date
    let projectDate: Date?               // When project was actually completed (may differ)

    // Source
    let basedOnPlanId: UUID?             // Optional link to source ProjectPlan

    // Categorization
    let tags: [String]                   // ["boro", "sculpture", "sold"]

    // Content
    let summary: String?                 // Overall description
    let notes: String?                   // Detailed notes, reflections, lessons learned
    let techniquesUsed: [String]?        // ["flamework", "cold-working", "fuming"]

    // Time Tracking
    let hoursSpent: Decimal?             // Actual time invested

    // Attachments
    let images: [ProjectImageModel]      // Multiple images
    let heroImageId: UUID?               // Primary portfolio image
    let glassItems: [ProjectGlassItem]   // Glass items with quantities actually used

    // Business
    let pricePoint: Decimal?             // Actual sale price or valuation
    let saleDate: Date?                  // When sold (if applicable)
    let buyerInfo: String?               // Customer name or notes
    let status: ProjectStatus            // in_progress, completed, sold, gifted, kept

    // Inventory Impact
    let inventoryDeductionRecorded: Bool // Track if glass usage was deducted
}

enum ProjectStatus: String, Codable {
    case inProgress = "in_progress"
    case completed
    case sold
    case gifted
    case kept                            // Personal collection
    case broken                          // Didn't survive
}
```

### Shared: ProjectStepModel

**Purpose**: Individual steps in a ProjectPlan (reorderable)

```swift
struct ProjectStepModel: Identifiable {
    let id: UUID
    let planId: UUID                     // Parent ProjectPlan
    let order: Int                       // 0-indexed position
    let title: String                    // "Gather and shape the body"
    let description: String?             // Detailed instructions
    let imageId: UUID?                   // Optional step illustration
    let estimatedMinutes: Int?           // Time estimate for this step
    let glassItemsNeeded: [ProjectGlassItem]? // Specific glass for this step (with quantities)
}
```

### Shared: ProjectImageModel

**Purpose**: Images attached to projects (hero + supplementary)

```swift
struct ProjectImageModel: Identifiable {
    let id: UUID
    let projectId: UUID                  // Parent project (Plan or Log)
    let projectType: ProjectType         // plan or log
    let imageType: ProjectImageType      // hero or supplementary
    let fileExtension: String            // "jpg", "png"
    let caption: String?                 // Optional description
    let dateAdded: Date
    let order: Int                       // Display order

    var fileName: String {
        "\(id.uuidString).\(fileExtension)"
    }
}

enum ProjectType: String, Codable {
    case plan
    case log
}

enum ProjectImageType: String, Codable {
    case hero                            // Primary display image
    case supplementary                   // Additional images
}
```

---

## Data Relationships

### ProjectPlan → ProjectLog
- ProjectLog can reference a ProjectPlan via `basedOnPlanId`
- When creating a ProjectLog from a Plan, copy over:
  - Title (with optional counter: "Fish #3")
  - Steps converted to notes
  - Glass items list
  - Tags
  - Reference URLs (copied to ProjectLog notes section)
- Track usage: increment `ProjectPlan.timesUsed`

**Important: Deletion Behavior**
- `basedOnPlanId` is an **optional** reference (soft link, not a foreign key constraint)
- Deleting a ProjectPlan does NOT delete related ProjectLogs
- ProjectLogs maintain their `basedOnPlanId` value even if the plan is deleted
- UI should handle missing plans gracefully:
  - Show "Original plan deleted" if basedOnPlanId points to non-existent plan
  - Alternatively: nullify `basedOnPlanId` on plan deletion

**Archive vs Delete Strategy**:

The app supports BOTH archiving and deletion, with clear use cases:

**Archive** (Primary workflow, recommended):
- Sets `isArchived = true` on ProjectPlan
- Removes from default list view
- Remains accessible via "View Archived Plans" section
- Preserves all data and relationships
- Can be unarchived at any time
- **Use case**: "I don't make this design anymore, but I want to keep it for reference"

**Delete** (Permanent removal):
- Completely removes ProjectPlan from database
- Deletes associated steps and images from disk
- ProjectLogs with `basedOnPlanId` retain the UUID reference
- UI shows "Based on archived/deleted plan" in ProjectLog detail view
- **Use case**: "I never want to see this plan again, it was a bad idea"

**UI Flow**:
1. Default view shows only active (non-archived) plans
2. Settings/Filter toggle to "Show Archived Plans"
3. Archived plans displayed with gray/muted styling and "Archived" badge
4. Archive action available from:
   - Swipe actions on list
   - Detail view menu
   - Bulk selection mode
5. Delete requires confirmation: "This will permanently delete the plan. Projects based on this plan will show 'Original template unavailable'. Continue?"

**Recommended Flow**:
- Default action: Archive (safe, reversible)
- Delete: Requires explicit user intent + confirmation
- Both are valid workflows depending on user needs

### ProjectPlan/ProjectLog → GlassItem
- Store array of `ProjectGlassItem` objects with natural keys and quantities
- Quantities are **Decimal** to support fractional amounts (e.g., 0.5 rods, 2.3 oz)
- Load full `GlassItemModel` details via `CatalogService` when needed
- Allows viewing glass details, checking inventory, adding to shopping list

**Shopping List Integration**:
- "Add to Shopping List" action on ProjectPlan detail view
- Dialog prompts: "How many of this project do you plan to make?" (default: 1)
- Multiplies all glass quantities by the count
- Example: Plan needs 0.5 rods of Clear, making 3 projects → add 1.5 rods to shopping list
- Checks current inventory and only adds the deficit to shopping list
- If inventory is sufficient, shows "You have enough in stock" message

### ProjectPlan → ProjectStepModel
- One-to-many relationship
- Steps must be reorderable (update `order` field)
- Deletion: cascade delete steps when plan is deleted

### ProjectPlan/ProjectLog → ProjectImageModel
- One-to-many relationship
- One image can be marked as hero (`imageType = .hero`)
- Enforce: maximum one hero image per project
- Deletion: cascade delete images and files when project is deleted

### ProjectPlan → ProjectReferenceUrl
- One-to-many relationship (ProjectPlans can have multiple reference URLs)
- Stored as JSON array in Core Data for simplicity
- Examples:
  - Tutorial video: "https://www.youtube.com/watch?v=..."
  - Blog post: "https://glassartblog.com/technique-guide"
  - Pinterest board: "https://pinterest.com/board/..."
  - PDF reference: Link to cloud storage
- UI displays as clickable links with optional titles

---

## Repository Layer

### Protocols

```swift
protocol ProjectPlanRepository {
    func createPlan(_ plan: ProjectPlanModel) async throws -> ProjectPlanModel
    func getPlan(id: UUID) async throws -> ProjectPlanModel?
    func getAllPlans(includeArchived: Bool) async throws -> [ProjectPlanModel]
    func getActivePlans() async throws -> [ProjectPlanModel]  // Convenience: excludes archived
    func getArchivedPlans() async throws -> [ProjectPlanModel]  // Convenience: only archived
    func getPlans(type: ProjectPlanType?, includeArchived: Bool) async throws -> [ProjectPlanModel]
    func updatePlan(_ plan: ProjectPlanModel) async throws
    func deletePlan(id: UUID) async throws  // Permanent deletion
    func archivePlan(id: UUID, isArchived: Bool) async throws  // Toggle archive status
    func unarchivePlan(id: UUID) async throws  // Convenience: shorthand for archivePlan(id, false)

    // Steps
    func addStep(_ step: ProjectStepModel) async throws -> ProjectStepModel
    func updateStep(_ step: ProjectStepModel) async throws
    func deleteStep(id: UUID) async throws
    func reorderSteps(planId: UUID, stepIds: [UUID]) async throws

    // Reference URLs
    func addReferenceUrl(_ url: ProjectReferenceUrl, to planId: UUID) async throws
    func updateReferenceUrl(_ url: ProjectReferenceUrl) async throws
    func deleteReferenceUrl(id: UUID, from planId: UUID) async throws
}

protocol ProjectLogRepository {
    func createLog(_ log: ProjectLogModel) async throws -> ProjectLogModel
    func getLog(id: UUID) async throws -> ProjectLogModel?
    func getAllLogs() async throws -> [ProjectLogModel]
    func getLogs(status: ProjectStatus?) async throws -> [ProjectLogModel]
    func updateLog(_ log: ProjectLogModel) async throws
    func deleteLog(id: UUID) async throws

    // Business queries
    func getLogsByDateRange(start: Date, end: Date) async throws -> [ProjectLogModel]
    func getSoldLogs() async throws -> [ProjectLogModel]
    func getTotalRevenue() async throws -> Decimal
}

protocol ProjectImageRepository {
    func saveImage(_ image: UIImage, for projectId: UUID, type: ProjectType, imageType: ProjectImageType) async throws -> ProjectImageModel
    func loadImage(_ model: ProjectImageModel) async throws -> UIImage?
    func getImages(for projectId: UUID, type: ProjectType) async throws -> [ProjectImageModel]
    func getHeroImage(for projectId: UUID, type: ProjectType) async throws -> ProjectImageModel?
    func deleteImage(id: UUID) async throws
    func setAsHero(id: UUID) async throws
    func reorderImages(projectId: UUID, type: ProjectType, imageIds: [UUID]) async throws
}
```

---

## Service Layer

### ProjectPlanningService

```swift
class ProjectPlanningService {
    private let projectPlanRepository: ProjectPlanRepository
    private let projectImageRepository: ProjectImageRepository
    private let catalogService: CatalogService

    // CRUD operations
    func createPlan(title: String, type: ProjectPlanType, ...) async throws -> ProjectPlanModel
    func updatePlan(_ plan: ProjectPlanModel) async throws
    func deletePlan(id: UUID) async throws  // Permanent deletion
    func archivePlan(id: UUID, isArchived: Bool) async throws
    func unarchivePlan(id: UUID) async throws

    // Queries
    func getActivePlans(type: ProjectPlanType?) async throws -> [ProjectPlanModel]
    func getArchivedPlans() async throws -> [ProjectPlanModel]

    // Step management
    func addStep(to planId: UUID, title: String, ...) async throws -> ProjectStepModel
    func reorderSteps(planId: UUID, newOrder: [UUID]) async throws

    // Image management
    func addImage(to planId: UUID, image: UIImage, asHero: Bool) async throws -> ProjectImageModel
    func setHeroImage(imageId: UUID) async throws

    // Template usage
    func createLogFromPlan(planId: UUID) async throws -> ProjectLogModel

    // Glass item association
    func addGlassItem(to planId: UUID, naturalKey: String, quantity: Decimal, unit: String, notes: String?) async throws -> ProjectGlassItem
    func updateGlassItem(_ glassItem: ProjectGlassItem, in planId: UUID) async throws
    func removeGlassItem(id: UUID, from planId: UUID) async throws
    func getRequiredGlass(for planId: UUID) async throws -> [(glass: GlassItemModel, quantity: Decimal, unit: String)]

    // Shopping list integration
    func addToShoppingList(planId: UUID, projectCount: Int) async throws -> ShoppingListResult

    // Reference URLs
    func addReferenceUrl(to planId: UUID, url: String, title: String?, description: String?) async throws -> ProjectReferenceUrl
    func updateReferenceUrl(_ url: ProjectReferenceUrl, in planId: UUID) async throws
    func deleteReferenceUrl(id: UUID, from planId: UUID) async throws
}

struct ShoppingListResult {
    let itemsAdded: Int
    let itemsAlreadyInStock: Int
    let totalItemsChecked: Int
    let insufficientGlass: [(naturalKey: String, needed: Decimal, available: Decimal)]
}
```

### ProjectLogService

```swift
class ProjectLogService {
    private let projectLogRepository: ProjectLogRepository
    private let projectImageRepository: ProjectImageRepository
    private let catalogService: CatalogService
    private let inventoryService: InventoryTrackingService

    // CRUD operations
    func createLog(title: String, basedOnPlanId: UUID?, ...) async throws -> ProjectLogModel
    func updateLog(_ log: ProjectLogModel) async throws
    func deleteLog(id: UUID) async throws

    // Image management
    func addImage(to logId: UUID, image: UIImage, asHero: Bool) async throws -> ProjectImageModel
    func setHeroImage(imageId: UUID) async throws

    // Business operations
    func markAsSold(logId: UUID, price: Decimal, buyer: String?, date: Date) async throws
    func recordInventoryUsage(logId: UUID) async throws  // Deduct glass from inventory

    // Glass item association
    func addGlassItem(to logId: UUID, naturalKey: String, quantity: Decimal, unit: String, notes: String?) async throws -> ProjectGlassItem
    func updateGlassItem(_ glassItem: ProjectGlassItem, in logId: UUID) async throws
    func removeGlassItem(id: UUID, from logId: UUID) async throws
    func getUsedGlass(for logId: UUID) async throws -> [(glass: GlassItemModel, quantity: Decimal, unit: String)]

    // Analytics
    func getRevenueByDateRange(start: Date, end: Date) async throws -> Decimal
    func getAveragePrice(for tags: [String]?) async throws -> Decimal?
    func getProductivityStats(year: Int, month: Int?) async throws -> ProductivityStats
}

struct ProductivityStats {
    let projectsCompleted: Int
    let projectsSold: Int
    let totalRevenue: Decimal
    let averagePrice: Decimal
    let totalHoursSpent: Decimal
    let averageHoursPerProject: Decimal
}
```

---

## Storage Strategy

### Core Data Entities

```
ProjectPlanEntity (Core Data - Implemented)
- id: UUID, optional (set in repository code)
- title: String, optional
- plan_type: String, optional (enum raw value)
- date_created: Date, optional
- date_modified: Date, optional
- is_archived: Boolean, optional, default: NO
- summary: String, optional
- estimated_time: Double, optional, default: 0.0
- difficulty_level: String, optional (enum raw value)
- proposed_price_min: Decimal, optional, default: 0.0
- proposed_price_max: Decimal, optional, default: 0.0
- price_currency: String, optional
- times_used: Int32, optional, default: 0
- last_used_date: Date, optional
- tags: Transformable ([String]), optional, NSSecureUnarchiveFromDataTransformer
- glass_items_data: Transformable (Data), optional (stores [ProjectGlassItem] as JSON)
- reference_urls_data: Transformable (Data), optional (stores [ProjectReferenceUrl] as JSON)
- hero_image_id: UUID, optional
- Relationships:
  - steps: To-Many → ProjectStepEntity, Cascade delete, inverse: plan
  - images: To-Many → ProjectImageEntity, Cascade delete, inverse: plan

ProjectLogEntity (Core Data - Implemented)
- id: UUID, optional (set in repository code)
- title: String, optional
- date_created: Date, optional
- date_modified: Date, optional
- project_date: Date, optional
- based_on_plan_id: UUID, optional (soft link, preserved after plan deletion)
- notes: String, optional
- techniques_used: Transformable ([String]), optional, NSSecureUnarchiveFromDataTransformer
- hours_spent: Decimal, optional, default: 0.0
- price_point: Decimal, optional, default: 0.0
- sale_date: Date, optional
- buyer_info: String, optional
- status: String, optional (enum raw value)
- inventory_deduction_recorded: Boolean, optional
- tags: Transformable ([String]), optional, NSSecureUnarchiveFromDataTransformer
- glass_items_data: Transformable (Data), optional (stores [ProjectGlassItem] as JSON)
- hero_image_id: UUID, optional
- Relationships:
  - images: To-Many → ProjectImageEntity, Cascade delete, inverse: log

ProjectStepEntity (Core Data - Implemented)
- id: UUID, optional (set in repository code)
- order_index: Int32, optional, default: 0
- title: String, optional
- step_description: String, optional
- image_id: UUID, optional
- estimated_minutes: Int32, optional, default: 0
- glass_items_needed_data: Transformable (Data), optional (stores [ProjectGlassItem] as JSON)
- Relationships:
  - plan: To-One → ProjectPlanEntity, Nullify delete, inverse: steps

ProjectImageEntity (Core Data - Implemented)
- id: UUID, optional (set in repository code)
- file_name: String, optional
- file_extension: String, optional
- caption: String, optional
- date_added: Date, optional
- order_index: Int32, optional, default: 0
- Relationships:
  - plan: To-One → ProjectPlanEntity, Nullify delete, inverse: images, optional
  - log: To-One → ProjectLogEntity, Nullify delete, inverse: images, optional
- Note: Each image belongs to either plan OR log, not both
- Files stored in Application Support/ProjectImages/ directory
```

### File Storage

Similar to UserImageRepository:
- Store images in Application Support: `ProjectImages/`
- Filename: `{UUID}.{extension}`
- Metadata in Core Data
- Support JPEG with 0.85 quality, 2048px max dimension

---

## UI Considerations

### ProjectPlan Views
- **List View**: Grid of plans with hero images, titles, tags
  - Default: Shows only active (non-archived) plans
  - Filter toggle: "Show Archived" to include archived plans
  - Archived plans have muted styling + "Archived" badge
  - Swipe actions: Archive, Delete (with confirmation)
- **Detail View**: Full recipe/template with steps, images carousel, glass list, reference URLs
  - Reference URLs displayed as clickable cards with titles/descriptions
  - "Open in Safari" action for each URL
  - Glass list shows quantities: "Clear (0.5 rods)", "CIM-511 (2.3 oz)"
  - "Add to Shopping List" button with dialog:
    - "How many projects?" input (default: 1)
    - Shows calculation: "0.5 rods × 3 = 1.5 rods"
    - After adding: Shows result summary
  - Menu actions: Archive/Unarchive, Delete
  - If archived: Banner at top saying "This plan is archived"
- **Edit View**:
  - Reorderable steps (drag handles)
  - Add/remove images with hero designation
  - Glass picker (search catalog):
    - Select glass item
    - Enter quantity (decimal input: 0.5, 1.25, etc.)
    - Select unit (rods, grams, oz - matches inventory)
    - Optional notes field
  - Tag editor
  - URL manager (add/edit/delete reference URLs)
- **Archived Plans View**: Dedicated section to browse archived plans
  - Access via settings or filter toggle
  - Can unarchive or permanently delete
- **Create from Template**: Button to generate ProjectLog from plan (works for archived plans too)

### ProjectLog Views
- **List View**: Grid/timeline of completed projects
  - Filter by: status, date range, tags
  - Sort by: date, price, hours spent
- **Detail View**:
  - Hero image prominent
  - Notes and reflections
  - Glass used (with quantities): "Clear (0.5 rods)", "CIM-511 (2.3 oz)"
  - Business info (price, buyer, sale date)
  - Source plan section:
    - If `basedOnPlanId` exists and plan found: Link to view/edit original plan
    - If `basedOnPlanId` exists but plan deleted: "Based on archived/deleted plan"
    - If `basedOnPlanId` is null: "Created manually" or no section
  - Optional: "Deduct from inventory" action (if `inventoryDeductionRecorded` is false)
- **Analytics View**:
  - Revenue charts
  - Productivity metrics
  - Popular techniques/glass

### Shared Components
- **GlassItemPicker**: Search and select from catalog with quantity input
  - Decimal quantity field (supports 0.1, 0.5, 1.25, etc.)
  - Unit picker (rods, grams, oz)
  - Optional notes field
- **GlassItemList**: Display glass items with quantities and units
  - Tap to view glass details in catalog
  - Shows inventory status: "✓ In stock" or "⚠️ Low stock"
- **ImageCarousel**: Display multiple images with hero indicator
- **TagEditor**: Add/remove tags with autocomplete
- **PriceInput**: Decimal input with currency formatting
- **ReferenceUrlEditor**: Add/edit/delete URLs with title and description fields
- **ReferenceUrlCard**: Display clickable URL with title, description, favicon preview
- **ProjectCountDialog**: "How many projects?" input for shopping list calculation

---

## Migration Strategy

### Phase 1: Core Entities
1. Add Core Data model version with new entities
2. Implement Mock repositories for testing
3. Implement Core Data repositories
4. Create services with basic CRUD

### Phase 2: Images
1. Implement ProjectImageRepository (FileSystem)
2. Add image upload to plan/log creation
3. Hero image selection

### Phase 3: Glass Integration
1. Connect to CatalogService for glass lookups
2. Glass picker UI component
3. Display glass details in project views

### Phase 4: Advanced Features
1. Step reordering
2. Plan → Log template conversion
3. Inventory deduction on log creation
4. Analytics and reporting

### Phase 5: Polish
1. Search and filtering
2. Bulk operations (archive multiple plans)
3. Export (PDF, share as recipe)
4. CloudKit sync (if desired)

---

## Design Decisions Summary

Based on user feedback, here are the finalized decisions:

### ✅ Confirmed Features (MVP)

1. **Reference URLs**: ProjectPlans can reference one or more tutorial/inspiration URLs
   - Stored as array of `ProjectReferenceUrl` objects
   - Each URL has optional title and description
   - Displayed as clickable cards in detail view

2. **Recipe Sharing**: YES - ProjectPlans will be exportable/importable
   - Format: JSON with embedded images as base64 or external URLs
   - Will be implemented in Phase 2

3. **No Automatic Inventory Deduction**: Creating ProjectLog does NOT auto-deduct inventory
   - User has full control over when/if to deduct
   - Optional manual operation if desired in future

### ⏸️ Deferred Features

4. **Material Cost Tracking**: Deferred for future implementation
   - Not in MVP
   - Will revisit after core functionality is stable

5. **Step Variations**: Use simple duplication approach
   - Duplicate entire ProjectPlan for variations ("Boro Fish - Blue", "Boro Fish - Red")
   - Use consistent tags for grouping related plans
   - May add `basedOnPlanId` reference in future for lineage tracking

### 📋 Implementation Order

**Phase 1 (MVP - Start Here)**:
1. Core entities (Plan, Log, Steps, Images, ReferenceUrls, ProjectGlassItem)
2. Basic CRUD operations (with deletion strategy for plan/log relationship)
3. Image upload with hero selection
4. Glass items attachment with fractional quantities
5. Reference URL management
6. Plan → Log conversion (copies reference URLs to notes)
7. Reorderable steps
8. Shopping list integration ("Add to Shopping List" with project count multiplier)

**Phase 2 (Export/Import)**:
9. Recipe export/import system (see detailed design below)
10. Share functionality with multiple methods

**Phase 3 (Enhancement)**:
11. Archive management UI
    - Filter toggle for showing/hiding archived plans
    - Dedicated "Archived Plans" view
    - Bulk archive/unarchive operations
12. Search and filtering (across active and archived)
13. Basic analytics (revenue, project count)
14. Productivity tracking

---

## Testing Strategy

**CRITICAL**: This project follows strict **Test-Driven Development (TDD)**. Write tests FIRST, then implement.

### Test Structure

**FlameworkerTests** (Unit Tests - Use Mocks Only):
- Uses `RepositoryFactory.configureForTesting()` with mock repositories
- NO Core Data access - fast, isolated tests
- Test business logic, service orchestration, model behavior

**RepositoryTests** (Repository Layer Tests - Uses Core Data):
- Uses `RepositoryFactory.configureForTestingWithCoreData()` with isolated test controllers
- Tests Core Data implementations directly
- Tests persistence, relationships, cascade deletion

### TDD Workflow (RED → GREEN → REFACTOR)

**Phase 1: Domain Models & Shared Types**

1. **Write Tests First**:
   - `ProjectGlassItemTests.swift` - Test Codable, validation, quantity handling
   - `ProjectReferenceUrlTests.swift` - Test URL validation, Codable
   - `ProjectPlanModelTests.swift` - Test model construction, business rules
   - `ProjectLogModelTests.swift` - Test model construction, status transitions

2. **Implement Models**:
   - `ProjectGlassItem` struct with Decimal quantities
   - `ProjectReferenceUrl` struct
   - `ProjectPlanModel`, `ProjectLogModel`, enums

3. **Refactor**: Clean up, extract common patterns

**Phase 2: Repository Layer**

1. **Write Repository Protocol Tests** (in RepositoryTests):
   ```swift
   @Test("Create project plan persists all data")
   func testCreateProjectPlan() async throws {
       let repo = createTestRepository()
       let plan = ProjectPlanModel(...)
       let saved = try await repo.createPlan(plan)
       #expect(saved.id == plan.id)
       #expect(saved.title == plan.title)
   }

   @Test("Delete plan with logs preserves based_on_plan_id")
   func testDeletePlanPreservesLogReference() async throws {
       // Create plan
       // Create log based on plan
       // Delete plan
       // Verify log still has based_on_plan_id UUID
   }

   @Test("Archive plan hides from active list")
   func testArchivePlan() async throws {
       // Create plan
       // Archive it
       // Verify not in getActivePlans()
       // Verify in getArchivedPlans()
   }

   @Test("Fractional quantities persist correctly")
   func testFractionalQuantities() async throws {
       // Create plan with 0.5 rods, 2.3 oz
       // Load plan
       // Verify exact Decimal values
   }
   ```

2. **Write Mock Repository Implementation** (for FlameworkerTests):
   - `MockProjectPlanRepository` - In-memory dictionary storage
   - `MockProjectLogRepository`
   - `MockProjectImageRepository`

3. **Write Core Data Repository Implementation**:
   - `CoreDataProjectPlanRepository`
   - `CoreDataProjectLogRepository`
   - `FileSystemProjectImageRepository` (mirrors UserImageRepository pattern)

4. **Test Edge Cases**:
   - Empty glass items array
   - Multiple reference URLs
   - Hero image on plan with no images
   - Deleting archived plans
   - Reordering steps

**Phase 3: Service Layer**

1. **Write Service Tests** (in FlameworkerTests with mocks):
   ```swift
   @Test("Create plan from service generates UUID")
   func testCreatePlan() async throws {
       RepositoryFactory.configureForTesting()
       let service = RepositoryFactory.createProjectPlanningService()

       let plan = try await service.createPlan(
           title: "Test Plan",
           type: .recipe,
           tags: ["boro"]
       )

       #expect(plan.id != nil)
       #expect(plan.title == "Test Plan")
       #expect(plan.planType == .recipe)
   }

   @Test("Add to shopping list multiplies quantities")
   func testAddToShoppingList() async throws {
       // Create plan with glass items
       // Call addToShoppingList(planId: id, projectCount: 3)
       // Verify quantities multiplied by 3
       // Verify only deficit added to shopping list
   }

   @Test("Convert plan to log copies data")
   func testConvertPlanToLog() async throws {
       // Create plan with steps, glass, reference URLs
       // Call createLogFromPlan()
       // Verify log has same title, glass items
       // Verify steps converted to notes
       // Verify reference URLs in notes section
       // Verify plan.timesUsed incremented
   }

   @Test("Archive plan removes from active list")
   func testArchivePlan() async throws {
       // Create plan
       // Archive it
       // Verify not in getActivePlans()
       // Can still create log from archived plan
   }
   ```

2. **Implement Services**:
   - `ProjectPlanningService`
   - `ProjectLogService`

3. **Test Business Logic**:
   - Promoting alternate image to hero demotes existing hero
   - Shopping list handles insufficient inventory
   - Can't delete plan that doesn't exist
   - Archive/unarchive toggles correctly

**Phase 4: Image Repository**

1. **Write Image Repository Tests** (in RepositoryTests):
   ```swift
   @Test("Save and load image from file system")
   func testSaveLoadImage() async throws {
       // Similar to FileSystemUserImageRepositoryTests
       // Save image for plan
       // Load it back
       // Verify image data matches
   }

   @Test("Delete image removes file and metadata")
   func testDeleteImage() async throws {
       // Save image
       // Delete it
       // Verify file removed from disk
       // Verify metadata removed from Core Data
   }

   @Test("Set hero image demotes existing hero")
   func testSetHeroImage() async throws {
       // Create plan with 2 images, one hero
       // Set different image as hero
       // Verify only one hero remains
   }
   ```

2. **Implement FileSystemProjectImageRepository**:
   - Mirror FileSystemUserImageRepository pattern
   - Store in Application Support/ProjectImages/
   - Metadata in Core Data (ProjectImageEntity)

**Phase 5: Integration Tests**

1. **Write Integration Tests**:
   ```swift
   @Test("Full workflow: Create plan, convert to log, mark sold")
   func testFullWorkflow() async throws {
       RepositoryFactory.configureForTestingWithCoreData()

       // Create plan with steps, glass, images
       // Convert to log
       // Add images to log
       // Mark as sold with price
       // Verify all data persisted
   }

   @Test("Glass item lookup integration")
   func testGlassItemLookup() async throws {
       // Create plan with glass natural keys
       // Use CatalogService to resolve glass details
       // Verify manufacturer, COE, etc. populated
   }
   ```

### Test Coverage Requirements

**Minimum Coverage**:
- Models: 100% (simple structs, easy to test)
- Repositories: 90%+ (test all CRUD, edge cases)
- Services: 85%+ (test orchestration, business logic)

**Key Test Scenarios**:

1. **Archive vs Delete**:
   - Archive plan → remains in DB, filtered from UI
   - Delete plan → removed from DB, logs keep UUID reference
   - Unarchive plan → back in active list
   - Delete archived plan → works correctly

2. **Fractional Quantities**:
   - 0.5 rods persists as exact Decimal
   - 2.3 oz calculates correctly in shopping list
   - Multiplication: 0.5 × 3 = 1.5 (exact)

3. **Image Management**:
   - Upload multiple images
   - Set hero image
   - Change hero to different image
   - Delete images
   - Cascade delete when plan deleted

4. **Reference URLs**:
   - Add multiple URLs
   - Persist with title and description
   - Copy to log notes when converting

5. **Shopping List Integration**:
   - Check inventory before adding
   - Only add deficit
   - Multiply by project count
   - Show result summary

6. **Plan → Log Conversion**:
   - Copies all relevant data
   - Increments timesUsed counter
   - Updates lastUsedDate
   - Creates new UUID for log
   - Preserves basedOnPlanId reference

### Test Organization

```
Tests/
├── FlameworkerTests/          # Unit tests with mocks
│   ├── Models/
│   │   ├── ProjectGlassItemTests.swift
│   │   ├── ProjectReferenceUrlTests.swift
│   │   ├── ProjectPlanModelTests.swift
│   │   └── ProjectLogModelTests.swift
│   ├── Services/
│   │   ├── ProjectPlanningServiceTests.swift
│   │   └── ProjectLogServiceTests.swift
│   └── Mocks/
│       ├── MockProjectPlanRepository.swift
│       ├── MockProjectLogRepository.swift
│       └── MockProjectImageRepository.swift
│
└── RepositoryTests/           # Repository tests with Core Data
    ├── CoreDataProjectPlanRepositoryTests.swift
    ├── CoreDataProjectLogRepositoryTests.swift
    ├── FileSystemProjectImageRepositoryTests.swift
    └── ProjectIntegrationTests.swift
```

### Running Tests

```bash
# Unit tests only (fast)
xcodebuild test -project Flameworker.xcodeproj -scheme Flameworker -testPlan UnitTestsOnly -destination 'platform=iOS Simulator,name=iPhone 17'

# Repository tests only
xcodebuild test -project Flameworker.xcodeproj -scheme Flameworker -testPlan RepositoryTests -destination 'platform=iOS Simulator,name=iPhone 17'

# All tests
xcodebuild test -project Flameworker.xcodeproj -scheme Flameworker -destination 'platform=iOS Simulator,name=iPhone 17'
```

### Continuous Testing During Development

**After each change**:
1. Run relevant test suite
2. Ensure all tests pass
3. Add new tests for new scenarios discovered
4. Refactor if needed (tests should still pass)

**Never commit code without tests**:
- Every new method needs tests
- Every bug fix needs a regression test
- Every edge case needs coverage

---

## Estimated Complexity

### Phase 1 (MVP)
- **Core Models & Repositories**: 2-3 sessions
- **Service Layer**: 1-2 sessions
- **Basic UI (List + Detail)**: 2-3 sessions
- **Advanced UI (Edit, Reorder, URLs)**: 2-3 sessions
- **Images Integration**: 1-2 sessions
- **Glass Integration**: 1-2 sessions

**Phase 1 Total**: 9-15 sessions

### Phase 2 (Export/Import)
- **Export/Import Logic**: 1-2 sessions
- **JSON Serialization with Images**: 1 session
- **Share UI**: 1 session

**Phase 2 Total**: 3-4 sessions

### Phase 3 (Enhancement)
- **Search & Filtering**: 1-2 sessions
- **Analytics**: 1-2 sessions

**Phase 3 Total**: 2-4 sessions

**Overall Total**: 14-23 sessions (full implementation)

---

## Next Steps

1. **Review this design**: Feedback on entity structure, relationships, features
2. **Prioritize features**: Which features are MVP vs nice-to-have?
3. **Start implementation**: Begin with Core Data models and Mock repositories
4. **Iterative development**: Build and test incrementally

---

## Recipe Sharing & Import/Export Design

### Overview

Project Plans can be exported and shared with other users. This enables recipe sharing, community contributions, and backup/restore functionality.

---

### Export/Import Methods

#### **Method 1: Native iOS Share Sheet (Recommended Primary)**

**Export Flow**:
1. User taps "Share" button on ProjectPlan detail view
2. System generates `.flameworker` file (JSON with embedded images)
3. iOS Share Sheet appears with options:
   - AirDrop to nearby device
   - Save to Files app (iCloud Drive, Dropbox, etc.)
   - Share via Messages, Mail, etc.
   - Copy to clipboard (base64 encoded)

**Import Flow**:
1. User receives `.flameworker` file (via AirDrop, Files, email attachment, etc.)
2. iOS recognizes file type, shows "Open in Flameworker" option
3. App imports and shows preview: "Import 'Boro Fish Recipe' by [Author]?"
4. User confirms, plan is added to their library

**Pros**:
- Native iOS experience, familiar to users
- Works with all iOS sharing mechanisms (AirDrop, Files, iCloud)
- Can attach files to Messages, email, etc.
- File-based: easy to backup, version control

**Cons**:
- Requires file handling setup in iOS
- Images make files larger (but manageable with compression)

---

#### **Method 2: QR Code (Great for in-person sharing)**

**Export Flow**:
1. User taps "Share via QR Code"
2. System generates QR code containing:
   - URL to recipe: `flameworker://import?data=<base64>`
   - Or URL to cloud storage if too large
3. Display QR code full screen
4. Other user scans with camera

**Import Flow**:
1. User scans QR code with camera
2. iOS opens Flameworker app with deep link
3. App decodes and shows import preview
4. User confirms import

**Pros**:
- Instant sharing at workshops, classes, meetups
- No need for accounts or network (for small recipes)
- Cool factor / discoverability

**Cons**:
- QR codes have size limits (~4KB text, ~2KB binary)
- May need cloud storage URL for recipes with many images
- Requires camera permission

---

#### **Method 3: Clipboard / Share String (Like Factorio)**

**Export Flow**:
1. User taps "Copy Share Link"
2. System generates compact base64 string
3. Copies to clipboard
4. User pastes into Messages, Discord, Reddit, etc.

**Import Flow**:
1. User copies share string
2. Opens Flameworker app
3. App detects recipe string in clipboard
4. Shows banner: "Recipe detected in clipboard. Import?"
5. User taps to import

**Pros**:
- Works everywhere (text-based)
- Can paste into forums, Discord, social media
- Simple implementation

**Cons**:
- Long strings are ugly and unwieldy
- Clipboard detection can be intrusive
- Size limits make it impractical for image-heavy recipes

---

#### **Method 4: Cloud Community Repository (Future/Advanced)**

**Export Flow**:
1. User taps "Publish to Community"
2. Upload to community server (or GitHub, Gist, etc.)
3. Get shareable URL: `flameworker.app/recipe/abc123`
4. Share URL anywhere

**Import Flow**:
1. User taps URL
2. Opens in Flameworker app
3. Downloads and previews recipe
4. User confirms import

**Pros**:
- Discoverability (browseable recipe library)
- Versioning (updates to recipes)
- Ratings, comments, forks
- No size limits

**Cons**:
- Requires backend server or third-party service
- Moderation needs
- Privacy concerns (public vs private)
- Much more complex

---

### Recommended Implementation Strategy

**Phase 2A (MVP - First Implementation)**:
- **Method 1: iOS Share Sheet** with `.flameworker` files
- **Method 3: Clipboard strings** (as fallback for text-based sharing)

**Phase 2B (Enhancement)**:
- **Method 2: QR Code** support (great for workshops)

**Phase 3 (Future/Optional)**:
- **Method 4: Community repository** (if user demand exists)

---

### File Format Specification

#### `.flameworker` File Structure

```json
{
  "version": "1.0",
  "type": "project-plan",
  "exportedAt": "2025-01-15T10:30:00Z",
  "exportedBy": "user@example.com",  // Optional

  "plan": {
    "id": "uuid-not-imported",  // Generate new UUID on import
    "title": "Boro Fish - Standard Pattern",
    "planType": "recipe",
    "summary": "A classic boro fish pattern...",
    "tags": ["boro", "sculpture", "beginner-friendly"],
    "estimatedTime": 7200,  // seconds
    "difficultyLevel": "intermediate",
    "proposedPriceRange": {
      "min": 50.00,
      "max": 100.00,
      "currency": "USD"
    },

    "steps": [
      {
        "order": 0,
        "title": "Gather and shape the body",
        "description": "Start with a clear punty...",
        "estimatedMinutes": 20,
        "glassItemsNeeded": [
          {
            "naturalKey": "bullseye-clear-0",
            "quantity": 0.5,
            "unit": "rods",
            "notes": "for the body"
          }
        ]
      }
    ],

    "glassItems": [
      {
        "naturalKey": "bullseye-clear-0",
        "quantity": 0.5,
        "unit": "rods",
        "notes": "main body"
      },
      {
        "naturalKey": "cim-511-0",
        "quantity": 0.25,
        "unit": "rods",
        "notes": "blue accent"
      }
    ],

    "referenceUrls": [
      {
        "url": "https://youtube.com/watch?v=...",
        "title": "Video tutorial",
        "description": "Great walkthrough of this technique"
      }
    ],

    "images": [
      {
        "id": "uuid",
        "imageType": "hero",
        "caption": "Finished fish",
        "order": 0,
        "data": "base64-encoded-jpeg-data-here..."
      },
      {
        "id": "uuid",
        "imageType": "supplementary",
        "caption": "Step 3 detail",
        "order": 1,
        "data": "base64-encoded-jpeg-data-here..."
      }
    ]
  },

  "metadata": {
    "appVersion": "1.0.0",
    "glassCatalogVersion": "2025.1",  // For compatibility checking
    "imageCompressionQuality": 0.6,   // Reduced for file size
    "totalImages": 2,
    "fileSizeBytes": 245000
  }
}
```

**Image Handling**:
- Images embedded as base64 JPEG at 60% quality (smaller file size for sharing)
- Max 5 images per recipe (to keep file size reasonable)
- Alternatively: Reference external URLs for large image sets

**Glass Item Compatibility**:
- Store natural keys (manufacturer-SKU format)
- On import, try to match to user's catalog
- If glass not found: Show warning with option to:
  - Import anyway (mark glass as "unavailable")
  - Skip this recipe
  - Search catalog for similar items

---

### Share String Format (Clipboard Method)

**Format**: `FLAMEWORKER:v1:<base64-compressed-json>`

**Example**:
```
FLAMEWORKER:v1:eyJwbGFuIjp7InRpdGxlIjoiQm9ybyBGaXNoI...
```

**Size Optimization**:
- Use gzip compression before base64 encoding
- Omit images in share strings (too large)
- Include image URLs if hosted externally
- Target: <10KB for typical recipe

---

### Import Validation & Safety

**Security Checks**:
1. Validate JSON schema version
2. Sanitize all string inputs (title, descriptions, URLs)
3. Check file size limits (max 10MB per file)
4. Validate image data is actual JPEG/PNG
5. Limit number of images (max 5)
6. Check glass catalog compatibility

**Import Preview Screen**:
```
┌─────────────────────────────────┐
│  Import Recipe                  │
├─────────────────────────────────┤
│  [Hero Image]                   │
│                                 │
│  Boro Fish - Standard Pattern   │
│  by user@example.com            │
│                                 │
│  📋 5 steps                     │
│  🎨 3 glass colors              │
│  ⏱️ ~2 hours                    │
│  💰 $50-100 suggested price     │
│                                 │
│  Glass Needed:                  │
│  ✅ Clear (0.5 rods)            │
│  ✅ CIM-511 Blue (0.25 rods)    │
│  ⚠️ Special Frit (not in catalog)│
│                                 │
│  [Import]  [Cancel]             │
└─────────────────────────────────┘
```

**Import Options**:
- Import as-is
- Import and edit before saving
- Import to archived (try it later)

---

### Service Layer Methods

```swift
// ProjectPlanningService additions

func exportPlan(id: UUID, includeImages: Bool) async throws -> ExportedPlan
func exportPlanToFile(id: UUID) async throws -> URL  // Returns .flameworker file URL
func exportPlanToShareString(id: UUID) async throws -> String  // Returns base64 string
func exportPlanToQRCode(id: UUID) async throws -> UIImage  // Returns QR code image

func importPlan(from data: Data) async throws -> ImportPreview
func confirmImport(preview: ImportPreview, options: ImportOptions) async throws -> ProjectPlanModel

struct ExportedPlan: Codable {
    let version: String
    let type: String
    let exportedAt: Date
    let plan: ProjectPlanExportModel  // Simplified model for export
    let metadata: ExportMetadata
}

struct ImportPreview {
    let plan: ProjectPlanModel  // Preview model (not saved yet)
    let compatibilityIssues: [CompatibilityIssue]
    let missingGlassItems: [String]  // Natural keys not in user's catalog
    let originalExportDate: Date
    let exportedBy: String?
}

struct ImportOptions {
    let importAsArchived: Bool
    let skipMissingGlass: Bool
    let replaceExisting: Bool  // If plan with same ID exists
}

enum CompatibilityIssue {
    case newerAppVersion(required: String, current: String)
    case missingGlassItems([String])
    case invalidImageData
    case schemaMismatch
}
```

---

### iOS Integration

#### Document Types (Info.plist)

```xml
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>Flameworker Project Plan</string>
        <key>LSHandlerRank</key>
        <string>Owner</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>com.flameworker.project-plan</string>
        </array>
    </dict>
</array>

<key>UTExportedTypeDeclarations</key>
<array>
    <dict>
        <key>UTTypeConformsTo</key>
        <array>
            <string>public.json</string>
            <string>public.data</string>
        </array>
        <key>UTTypeDescription</key>
        <string>Flameworker Project Plan</string>
        <key>UTTypeIdentifier</key>
        <string>com.flameworker.project-plan</string>
        <key>UTTypeTagSpecification</key>
        <dict>
            <key>public.filename-extension</key>
            <array>
                <string>flameworker</string>
            </array>
            <key>public.mime-type</key>
            <array>
                <string>application/vnd.flameworker.project-plan+json</string>
            </array>
        </dict>
    </dict>
</array>
```

#### Deep Links (URL Scheme)

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>flameworker</string>
        </array>
    </dict>
</array>
```

**Supported URLs**:
- `flameworker://import?data=<base64>` - Import from share string
- `flameworker://import?url=<url>` - Import from web URL
- `flameworker://recipe/<id>` - Open specific recipe (if community repo exists)

---

### UI Flow Examples

#### Share Flow
1. User on ProjectPlan detail view
2. Taps Share button
3. Share sheet shows:
   - "Share as File" → Generates `.flameworker`, opens iOS share sheet
   - "Copy Share Link" → Copies base64 string to clipboard
   - "Show QR Code" → Displays QR code for scanning

#### Import Flow (from file)
1. User receives `boro-fish.flameworker` via AirDrop
2. Taps file, iOS asks "Open in Flameworker?"
3. App opens, shows import preview
4. User reviews, taps "Import"
5. Plan added to library, confirmation shown

#### Import Flow (from clipboard)
1. User copies share string from Discord
2. Opens Flameworker app
3. Banner appears: "Recipe detected. Import 'Boro Fish'?"
4. Taps banner
5. Import preview shown
6. Confirms import

---

### Testing Strategy

**Export Tests**:
- Export plan with all data
- Export plan without images
- Validate JSON schema
- Check file size limits
- Verify image compression

**Import Tests**:
- Import valid plan
- Import plan with missing glass items
- Import plan with invalid data
- Import plan with newer schema version
- Import plan with corrupted images
- Duplicate import handling

**Round-trip Tests**:
- Export then import, verify data integrity
- Export plan A, import to device B, verify identical

---

### Privacy & Attribution

**Optional Attribution**:
- User can optionally include their name/email on export
- "Created by @username" shown on import
- Not required (can be anonymous)

**License/Terms**:
- Default: "Shared for personal use"
- Optional: Add Creative Commons license tag
- User agreement on first share: "By sharing, you grant others permission to use this recipe"

---

---

## Material Cost Estimation System

### Overview

Users can optionally configure default pricing for glass to estimate material costs for projects. This uses a **cascading defaults** system: global defaults → COE-specific → manufacturer-specific → item-specific.

**Important**: This is NOT a database of actual prices. Prices vary by region, retailer, and time. This is purely for **user's personal cost estimation**.

---

### Pricing Hierarchy (Cascade)

When calculating cost for a glass item, the system checks in this order:

1. **Item-specific price** (if user set one for this exact glass item)
2. **Manufacturer-specific price** (e.g., "$10/rod for Northstar")
3. **COE-specific price** (e.g., "$5/rod for COE 104")
4. **Global default price** (e.g., "$3/rod for all glass")
5. **No price** (if nothing configured, show "Price not set")

**Example**:
- Global default: $3/rod
- COE 104: $5/rod
- Northstar (COE 104): $10/rod
- Northstar NS-33 Clear: $12/rod (special item)

When calculating cost for:
- Effetre Clear (COE 104): Uses $5/rod (COE default)
- Northstar NS-43 Yellow: Uses $10/rod (manufacturer default)
- Northstar NS-33 Clear: Uses $12/rod (item-specific override)
- Bullseye Clear (COE 90): Uses $3/rod (global default, no COE 90 price set)

---

### User Settings Model

```swift
struct GlassPricingSettings: Codable {
    // Global defaults
    var globalDefaultPricePerRod: Decimal?        // e.g., $3.00
    var globalDefaultPricePerGram: Decimal?       // e.g., $0.05
    var globalDefaultPricePerOunce: Decimal?      // e.g., $1.50

    // COE-specific defaults (keyed by COE value)
    var coeSpecificPrices: [Int32: COEPricing]    // e.g., [104: COEPricing(...), 90: ...]

    // Manufacturer-specific defaults (keyed by manufacturer abbreviation)
    var manufacturerSpecificPrices: [String: ManufacturerPricing]  // e.g., ["northstar": ...]

    // Item-specific overrides (keyed by natural key)
    var itemSpecificPrices: [String: ItemPricing] // e.g., ["northstar-ns33-0": ...]

    // Metadata
    var currency: String                          // "USD", "EUR", etc.
    var lastUpdated: Date
    var notes: String?                            // Optional user notes
}

struct COEPricing: Codable {
    let coe: Int32
    let pricePerRod: Decimal?
    let pricePerGram: Decimal?
    let pricePerOunce: Decimal?
    let notes: String?  // e.g., "Soft glass average"
}

struct ManufacturerPricing: Codable {
    let manufacturer: String  // Abbreviation (e.g., "northstar", "effetre")
    let pricePerRod: Decimal?
    let pricePerGram: Decimal?
    let pricePerOunce: Decimal?
    let notes: String?  // e.g., "Frantz average pricing"
}

struct ItemPricing: Codable {
    let naturalKey: String
    let pricePerRod: Decimal?
    let pricePerGram: Decimal?
    let pricePerOunce: Decimal?
    let notes: String?  // e.g., "Special sale price"
}
```

**Storage**: Store in UserDefaults as JSON (lightweight, per-user configuration)

---

### Pricing Service

```swift
class GlassPricingService {
    private var settings: GlassPricingSettings
    private let catalogService: CatalogService

    // Get price for a specific glass item and unit
    func getPrice(for naturalKey: String, unit: String) async throws -> Decimal? {
        // Get glass item details
        guard let glassItem = try await catalogService.getGlassItem(naturalKey: naturalKey) else {
            return nil
        }

        // 1. Check item-specific price
        if let itemPrice = settings.itemSpecificPrices[naturalKey] {
            if let price = priceForUnit(unit, from: itemPrice) {
                return price
            }
        }

        // 2. Check manufacturer-specific price
        if let mfgPrice = settings.manufacturerSpecificPrices[glassItem.manufacturer] {
            if let price = priceForUnit(unit, from: mfgPrice) {
                return price
            }
        }

        // 3. Check COE-specific price
        if let coePrice = settings.coeSpecificPrices[glassItem.coe] {
            if let price = priceForUnit(unit, from: coePrice) {
                return price
            }
        }

        // 4. Check global default
        switch unit {
        case "rods": return settings.globalDefaultPricePerRod
        case "grams": return settings.globalDefaultPricePerGram
        case "oz": return settings.globalDefaultPricePerOunce
        default: return nil
        }
    }

    // Calculate total cost for a project
    func calculateMaterialCost(for glassItems: [ProjectGlassItem]) async throws -> MaterialCostBreakdown {
        var totalCost: Decimal = 0
        var itemizedCosts: [(naturalKey: String, quantity: Decimal, unit: String, cost: Decimal)] = []
        var unpricedItems: [String] = []

        for glassItem in glassItems {
            if let price = try await getPrice(for: glassItem.naturalKey, unit: glassItem.unit) {
                let cost = price * glassItem.quantity
                totalCost += cost
                itemizedCosts.append((glassItem.naturalKey, glassItem.quantity, glassItem.unit, cost))
            } else {
                unpricedItems.append(glassItem.naturalKey)
            }
        }

        return MaterialCostBreakdown(
            totalCost: totalCost,
            itemizedCosts: itemizedCosts,
            unpricedItems: unpricedItems,
            currency: settings.currency
        )
    }

    // CRUD for settings
    func updateGlobalDefault(pricePerRod: Decimal?, pricePerGram: Decimal?, pricePerOunce: Decimal?) async throws
    func setCOEPrice(coe: Int32, pricing: COEPricing) async throws
    func setManufacturerPrice(manufacturer: String, pricing: ManufacturerPricing) async throws
    func setItemPrice(naturalKey: String, pricing: ItemPricing) async throws
    func removeItemPrice(naturalKey: String) async throws
}

struct MaterialCostBreakdown {
    let totalCost: Decimal
    let itemizedCosts: [(naturalKey: String, quantity: Decimal, unit: String, cost: Decimal)]
    let unpricedItems: [String]  // Items without configured prices
    let currency: String

    var hasUnpricedItems: Bool {
        !unpricedItems.isEmpty
    }
}
```

---

### UI Design

#### Settings View: Glass Pricing Configuration

```
┌─────────────────────────────────────┐
│  Glass Pricing Settings             │
├─────────────────────────────────────┤
│                                     │
│  💰 Global Defaults                 │
│  ┌─────────────────────────────┐   │
│  │ Per Rod:    $3.00           │   │
│  │ Per Gram:   $0.05           │   │
│  │ Per Ounce:  $1.50           │   │
│  └─────────────────────────────┘   │
│                                     │
│  🎨 COE-Specific Pricing            │
│  ┌─────────────────────────────┐   │
│  │ COE 104 (Soft Glass)        │   │
│  │ Per Rod: $5.00              │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │ COE 33 (Boro)               │   │
│  │ Per Rod: $8.00              │   │
│  └─────────────────────────────┘   │
│  [+ Add COE Pricing]                │
│                                     │
│  🏭 Manufacturer-Specific Pricing   │
│  ┌─────────────────────────────┐   │
│  │ Northstar                   │   │
│  │ Per Rod: $10.00             │   │
│  │ Notes: Premium boro         │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │ Effetre                     │   │
│  │ Per Rod: $3.50              │   │
│  └─────────────────────────────┘   │
│  [+ Add Manufacturer Pricing]       │
│                                     │
│  📦 Item-Specific Pricing           │
│  (Tap glass item to set price)     │
│  ┌─────────────────────────────┐   │
│  │ Northstar NS-33 Clear       │   │
│  │ Per Rod: $12.00             │   │
│  │ Notes: Special clear        │   │
│  └─────────────────────────────┘   │
│                                     │
│  Currency: USD                      │
│  Last Updated: Jan 15, 2025         │
└─────────────────────────────────────┘
```

#### ProjectPlan Detail View: Material Cost Estimate

```
┌─────────────────────────────────────┐
│  Boro Fish Recipe                   │
├─────────────────────────────────────┤
│  [Hero Image]                       │
│                                     │
│  Glass Required:                    │
│  ┌─────────────────────────────┐   │
│  │ Clear (0.5 rods)            │   │
│  │ $5.00                       │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │ NS-43 Yellow (0.25 rods)    │   │
│  │ $2.50                       │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │ Sparkle Frit (10g)          │   │
│  │ Price not set               │   │
│  │ [Set Price]                 │   │
│  └─────────────────────────────┘   │
│                                     │
│  💰 Est. Material Cost: $7.50       │
│  (1 item not priced)                │
│                                     │
│  📊 Estimated Profit:               │
│  Suggested Price: $50-100           │
│  Material Cost: ~$7.50              │
│  Potential Margin: ~85-92%          │
└─────────────────────────────────────┘
```

#### Quick Actions

**From Glass Item Detail in Catalog**:
- "Set Custom Price" button
- Shows current effective price with cascade info:
  ```
  Current price: $10.00/rod
  (Using Northstar manufacturer default)

  [Set Custom Price for this Item]
  ```

**From ProjectPlan Glass List**:
- Tap glass item → Shows price
- If no price: "Price not set - [Set Price]" button
- If priced: Shows calculated cost

---

### Project Analytics Integration

Once pricing is configured, ProjectLog can show actual vs estimated costs:

```swift
extension ProjectLogModel {
    // Calculated properties
    var estimatedMaterialCost: Decimal? {
        // Calculate from glassItems using GlassPricingService
    }

    var profitMargin: Decimal? {
        guard let materialCost = estimatedMaterialCost,
              let salePrice = pricePoint else { return nil }
        return (salePrice - materialCost) / salePrice
    }

    var profitAmount: Decimal? {
        guard let materialCost = estimatedMaterialCost,
              let salePrice = pricePoint else { return nil }
        return salePrice - materialCost
    }
}
```

**ProjectLog Detail View**:
```
┌─────────────────────────────────────┐
│  Rainbow Fish #3                    │
│  Status: Sold                       │
├─────────────────────────────────────┤
│  💰 Financial Summary               │
│  Sale Price: $75.00                 │
│  Est. Materials: $8.25              │
│  Est. Profit: $66.75 (89%)          │
│                                     │
│  ⏱️ Time Investment: 2.5 hours      │
│  Hourly Rate: ~$26.70/hour          │
└─────────────────────────────────────┘
```

---

### Default Pricing Suggestions

To help users get started, provide common starting points:

```swift
enum DefaultPricingTemplate {
    case usBoro
    case usSoftGlass
    case euroSoftGlass
    case custom

    func settings() -> GlassPricingSettings {
        switch self {
        case .usBoro:
            return GlassPricingSettings(
                globalDefaultPricePerRod: 8.00,
                coeSpecificPrices: [
                    33: COEPricing(coe: 33, pricePerRod: 8.00, notes: "Boro average")
                ],
                manufacturerSpecificPrices: [
                    "northstar": ManufacturerPricing(manufacturer: "northstar", pricePerRod: 10.00),
                    "glass-alchemy": ManufacturerPricing(manufacturer: "glass-alchemy", pricePerRod: 12.00)
                ],
                currency: "USD"
            )
        case .usSoftGlass:
            return GlassPricingSettings(
                globalDefaultPricePerRod: 3.00,
                coeSpecificPrices: [
                    104: COEPricing(coe: 104, pricePerRod: 3.50, notes: "Soft glass average")
                ],
                manufacturerSpecificPrices: [
                    "effetre": ManufacturerPricing(manufacturer: "effetre", pricePerRod: 3.00),
                    "bullseye": ManufacturerPricing(manufacturer: "bullseye", pricePerRod: 5.00)
                ],
                currency: "USD"
            )
        // ... other templates
        }
    }
}
```

**Settings UI**:
- "Use Template" button when pricing is empty
- Shows template options with preview
- User can customize after applying

---

### Import/Export Integration

**When exporting recipes**, pricing info is **NOT included** (too user-specific). Only include:
- Suggested price range (min/max)
- This is guidance, not actual costs

**When importing recipes**, pricing is calculated using **recipient's** pricing settings.

---

### Implementation Priority

**Phase 3** (Deferred from MVP, as originally planned):
- User pricing settings (global, COE, manufacturer, item)
- Material cost calculation in ProjectPlans
- Profit margin display in ProjectLogs
- Settings UI for pricing configuration
- Default pricing templates

**Phase 4** (Analytics Enhancement):
- Average profit margin by tag
- Most/least profitable projects
- Material cost trends over time
- ROI analysis (time + materials vs sale price)

---

## Notes

- This design follows the existing repository pattern and TDD approach
- Image storage mirrors UserImageRepository implementation
- Services orchestrate, business logic in models
- Glass items stored as natural keys for flexibility
- Both entities support rich metadata for future analytics
- Recipe sharing enables community building and knowledge sharing
- Pricing is user-specific, not a centralized database (prices vary too much by region/time)

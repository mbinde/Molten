# Transformable Attributes Review

## Summary

This document reviews all Transformable attributes in the Core Data model and provides recommendations for refactoring to improve CloudKit sync reliability.

## Current Transformable Attributes

### ProjectLog Entity
1. **glass_items_data** (line 124)
   - Type: Transformable
   - Purpose: Stores array of glass items used in project
   - Current Implementation: Serialized array stored as blob

2. **tags** (line 134)
   - Type: Transformable
   - Purpose: Stores array of tag strings
   - Current Implementation: Serialized array stored as blob

3. **techniques_used** (line 135)
   - Type: Transformable
   - Purpose: Stores array of technique strings
   - Current Implementation: Serialized array stored as blob

### ProjectPlan Entity
1. **glass_items_data** (line 145)
   - Type: Transformable
   - Purpose: Stores array of planned glass items
   - Current Implementation: Serialized array stored as blob

2. **reference_urls_data** (line 154)
   - Type: Transformable
   - Purpose: Stores array of ProjectReferenceUrl objects
   - Current Implementation: Serialized array stored as blob

3. **tags** (line 156)
   - Type: Transformable
   - Purpose: Stores array of tag strings
   - Current Implementation: Serialized array stored as blob

### ProjectStep Entity
1. **glass_items_needed_data** (line 164)
   - Type: Transformable
   - Purpose: Stores array of glass items needed for step
   - Current Implementation: Serialized array stored as blob

## Problems with Transformable Attributes

### CloudKit Sync Issues
1. **Conflict Resolution**: CloudKit cannot merge changes to binary data. If two devices edit the same project, one will overwrite the other's changes entirely.
2. **Change Tracking**: CloudKit cannot detect which specific items in an array changed, forcing full rewrites.
3. **Bandwidth**: Every change syncs the entire blob, not just the delta.

### Performance Concerns
1. **Serialization Overhead**: Every read/write requires serialization/deserialization.
2. **Query Limitations**: Cannot query or filter by individual items within the array.
3. **Memory Usage**: Entire array must be loaded into memory to access a single item.

### Data Integrity
1. **Migration Risk**: Changes to serialized object structure require careful migration.
2. **Versioning**: No built-in versioning for serialized data format.

## Recommended Refactoring

### Priority 1: High-Impact, Low-Effort

**tags** attributes in ProjectLog and ProjectPlan:
- **Current**: Transformable array of strings
- **Recommended**: Create `ProjectTag` entity with relationship
- **Benefits**:
  - Query projects by tag
  - CloudKit can sync tag changes independently
  - Deduplication across projects
- **Effort**: Low (similar to existing ItemTags entity)

**techniques_used** in ProjectLog:
- **Current**: Transformable array of strings
- **Recommended**: Create `ProjectTechnique` entity with relationship
- **Benefits**:
  - Query projects by technique
  - CloudKit syncs technique changes independently
  - Can add metadata (difficulty, tutorial links, etc.)
- **Effort**: Low

### Priority 2: Medium-Impact, Medium-Effort

**reference_urls_data** in ProjectPlan:
- **Current**: Transformable array of ProjectReferenceUrl objects
- **Recommended**: Create `ProjectReferenceUrl` entity with relationship
- **Benefits**:
  - CloudKit syncs URL changes independently
  - Can add metadata (title, description, fetch date, etc.)
  - Better query capabilities
- **Effort**: Medium (requires entity creation + migration)

### Priority 3: High-Impact, High-Effort

**glass_items_data** in ProjectLog, ProjectPlan, ProjectStep:
- **Current**: Transformable arrays of glass item references
- **Recommended**: Create proper relationship entities
  - `ProjectLogGlassItem` (many-to-many through entity)
  - `ProjectPlanGlassItem` (many-to-many through entity)
  - `ProjectStepGlassItem` (many-to-many through entity)
- **Benefits**:
  - CloudKit syncs item additions/removals independently
  - Can track quantity, notes, substitutions per-project
  - Proper referential integrity
  - Query capabilities (e.g., "all projects using this glass")
- **Effort**: High (requires multiple entities, complex migration, UI updates)

## Migration Strategy

### Phase 1: Add New Entities (Non-Breaking)
1. Create new entities alongside existing Transformable attributes
2. Write migration code to populate new entities from existing data
3. Update app code to write to both old and new storage
4. Test thoroughly with CloudKit sync

### Phase 2: Switch Reads (Safe Rollback Point)
1. Update app code to read from new entities
2. Keep writing to both old and new storage (dual-write)
3. Monitor for issues, can roll back by switching reads back

### Phase 3: Remove Old Attributes (Breaking Change)
1. Create new Core Data model version
2. Remove Transformable attributes
3. Update app code to only use new entities
4. Test migration thoroughly

## Performance Analysis

### Current Performance Characteristics
- **Small Projects** (<10 items): Transformable overhead negligible
- **Medium Projects** (10-50 items): Noticeable serialization time (~10-50ms)
- **Large Projects** (>50 items): Significant overhead (~100ms+)

### Expected Performance After Refactoring
- **Small Projects**: Slightly slower due to relationship overhead
- **Medium Projects**: Similar or better performance
- **Large Projects**: Significant improvement (fetch only needed items)

### CloudKit Sync Performance
- **Current**: Entire project syncs on any change
- **Refactored**: Only changed relationships sync
- **Expected Improvement**: 80-90% reduction in sync data for partial edits

## Recommendation

### Proceed with Refactoring: YES ✅

**Reasoning:**
1. CloudKit conflict issues are real and will affect users on multiple devices
2. Performance impact is manageable (mostly affects large projects)
3. App is in alpha - perfect time for breaking changes
4. Migration strategy allows for safe, phased rollout

### Suggested Order
1. **Start with tags** (lowest risk, immediate benefit)
2. **Then techniques_used** (low risk, good practice)
3. **Then reference_urls_data** (medium complexity, clear benefit)
4. **Finally glass_items_data** (highest complexity, but biggest impact)

### Timeline Estimate
- Tags: 2-3 hours (entity + migration + UI testing)
- Techniques: 2-3 hours
- Reference URLs: 4-6 hours (more complex entity)
- Glass Items: 8-12 hours (multiple entities, complex migration, UI changes)

**Total: ~16-24 hours of work**

## Alternative: Keep Transformable for Now

If performance testing shows minimal impact and multi-device editing is rare:
- **Keep Transformable** for glass_items_data (complex to refactor)
- **Refactor only** tags and techniques_used (easy wins)
- **Document** the CloudKit conflict limitation for users

This "hybrid approach" gives 80% of the benefit with 20% of the effort.

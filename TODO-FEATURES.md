# ML Image Generation Features - TODO

## Generate Your Aesthetic

Feature for generating AI images based on user's inventory color distribution.

### User Experience Flow

1. **Entry Point**: Three-dot menu in Inventory section
2. **Date Range Slider**:
   - Filter inventory by `dateAdded`
   - Default: All time (earliest to latest)
   - Dual-ended slider allowing user to adjust both start and end dates
3. **Color Preview Bar**:
   - Single horizontal line showing color distribution
   - Uses RGB values from inventory items
   - Shows approximate percentages of each color
4. **Theme Selection**: (To be designed)
   - Interface for picking style keywords (modern, spooky, christmas, etc.)
5. **Generate Button**: "Generate Your Aesthetic" or similar
6. **Display Result**: Show generated image

### Technical Details

**Inventory Counting**:
- 1 rod = 1 oz of frit = 1 unit
- Sheet glass: TBD (defer for later)
- Clear/colorless glass: EXCLUDE from color calculation

**Data Source**:
- Filter by: `InventoryModel.dateAdded`
- Color data: `dominant_colors` field (to be added to catalog)
  - Will contain hex color codes
  - Currently in commit message but not yet in actual database/JSON

**API Integration**:
- Endpoint: `/api/v1/generate-color-image` (molten-website)
- Model: Flux-1-Schnell (free tier, good quality)
- Input format: Array of `{hex: "#RRGGBB", weight: 0.25}` objects
- Note: Flux generates 512x512 images (can't customize aspect ratio)

**Implementation Location**:
- Platform: iOS app (SwiftUI)
- Initial placement: Inventory section three-dot menu
- Final placement: TBD

### Open Questions

1. Where should this live long-term? (New tab? Settings? Standalone feature?)
2. What should the theme selection UI look like?
3. How to handle sheet glass in weight calculations?
4. Should we cache generated images or regenerate each time?
5. Rate limiting considerations (free tier limits)

### Dependencies

- [ ] Add `dominant_colors` field to catalog.sqlite
- [ ] Update Core Data model to expose dominant_colors
- [ ] Design theme selection UI
- [ ] Implement date range slider component
- [ ] Create color distribution calculation logic
- [ ] Build color preview bar visualization
- [ ] Integrate with Cloudflare Workers AI API

### Related Files

**Backend (molten-website)**:
- `/api/v1/generate-color-image.ts` - API endpoint
- `/lib/color-prompt-builder.ts` - Color to prompt conversion
- `/test-color-generator.astro` - Test UI (currently disabled)

**iOS App (Molten)**:
- TBD - Feature not yet implemented

# Color Tagging Workflow

Automated color tag suggestion system using AI vision analysis + text parsing, with web-based human review.

## Overview

This system helps identify and tag glass colors by:
1. Analyzing product images with AI vision
2. Extracting colors from product names/descriptions
3. Presenting suggestions in a web interface for review
4. Tracking your decisions over time
5. Merging approved tags back into the database

## Color Taxonomy

**Primary Colors:** red, blue, green, yellow, orange, purple, pink

**Extended Colors:** brown, gray, black, white, clear, teal, amber, lavender, aqua, cream, magenta

**Attributes:** transparent, opaque, sparkle, striker, reducing

## Workflow

### 1. Generate Suggestions

Run the analyzer to process new/changed products:

```bash
# Analyze all new/changed products
python3 color_tag_analyzer.py

# Test on 10 products first
python3 color_tag_analyzer.py --limit 10

# Force re-analyze everything
python3 color_tag_analyzer.py --force
```

**Output:** `color_tag_suggestions.json`

**What it does:**
- Analyzes product names/descriptions for color keywords
- Marks products that need image analysis
- Compares against previously approved tags
- Shows what's new/removed/unchanged
- Tracks image checksums to detect photo changes

### 2. Enhance with Image Analysis

*(Coming next - requires Claude API integration)*

This step will analyze product images to detect colors visually, adding high-confidence tags from actual photos.

### 3. Review in Web Interface

Open the web review interface:

```bash
# Start a local web server
cd "Tools/Scraping Tools"
python3 -m http.server 8080

# Open in your browser
open http://localhost:8080/color_tag_review.html
```

**The interface allows you to:**
- See each product image, title, description
- Review suggested tags with visual indicators
- Check/uncheck tags
- Add manual/custom tags
- Filter by status, manufacturer, or search
- Track progress (total/approved/pending)
- Approve products individually
- Save all approvals to JSON

**Visual indicators:**
- ✅ Pre-checked: Tags you approved before that we still suggest
- 🟢 GREEN badge: Tags we're newly suggesting
- 🔴 RED badge: Tags you approved before that we no longer detect

**Features:**
- Filter by status: All / Needs Review / Approved / Unchanged
- Filter by manufacturer
- Search products by name
- Real-time stats tracking
- Bulk save all approvals

**When you're done:**
1. Click "Save All Approvals"
2. This downloads `color_tag_approvals.json`
3. Move the downloaded file to replace the existing one in the directory

**Output:** `color_tag_approvals.json`

### 4. Merge Approved Tags

Apply your approved tags back to the database:

```bash
# Preview changes
python3 merge_approved_tags.py --dry-run

# Apply changes
python3 merge_approved_tags.py

# Apply and auto-commit to git
python3 merge_approved_tags.py --commit
```

**What it does:**
- Reads your approvals from the web interface
- Updates `glass_database.json` with approved tags
- Re-exports to `glass_database_export.json`
- Shows detailed diff of changes
- Optionally commits to git

### 5. Deploy to App

```bash
# Copy updated catalog to app
cp glass_database_export.json ../../Sources/Resources/glass_catalog.json

# Rebuild app to see new tags
```

## File Reference

| File | Purpose |
|------|---------|
| `color_tag_analyzer.py` | Analyzes products and generates suggestions |
| `color_tag_review.html` | Web interface for reviewing and approving tags |
| `color_tag_suggestions.json` | AI-generated tag suggestions (read by web UI) |
| `color_tag_approvals.json` | Your approved tags (written by web UI) |
| `merge_approved_tags.py` | Applies approved tags to database |
| `glass_database.json` | Source of truth for all product data |
| `glass_database_export.json` | Export for app consumption |

## Incremental Updates

The system is designed for incremental updates:

**First time:**
- Analyzer processes all ~2700 products
- You review and approve tags for everything
- Merge applies your decisions

**Later updates:**
- Analyzer only processes new/changed products
  - New products added to catalog
  - Products with new/different images
  - When analysis logic improves (version bump)
- Web UI shows what changed vs your previous decisions
- You only review products that changed
- Merge only updates changed products

## Change Tracking

The system tracks:
- **Image checksum:** Detects when manufacturer updates product photo
- **Analysis version:** Re-analyzes when detection logic improves
- **Previously approved:** Remembers what you decided last time
- **Tag deltas:** Shows new/removed/unchanged tags

## Example: Second Review

You previously approved **["red", "opaque"]** for a product.

**Scenario 1: Manufacturer updates photo**
- New image shows it's actually **red-orange**
- System suggests: **["red", "orange", "opaque"]**
- UI shows:
  - ✅ red (unchanged)
  - ✅ opaque (unchanged)
  - ⭐ **orange (NEW)**

**Scenario 2: You improve detection**
- Better text analysis now detects "striker"
- System suggests: **["red", "opaque", "striker"]**
- UI shows:
  - ✅ red (unchanged)
  - ✅ opaque (unchanged)
  - ⭐ **striker (NEW)**

**Scenario 3: False positive removed**
- Old logic mistakenly suggested "metallic"
- You approved it, but new logic doesn't suggest it
- System suggests: **["red", "opaque"]**
- UI shows:
  - ✅ red (still suggested)
  - ✅ opaque (still suggested)
  - ⚠️ **metallic (you approved before, but we no longer detect - keep it?)**

## Tips

**For best results:**
1. Review in batches by manufacturer (they have consistent photo styles)
2. Start with high-confidence suggestions (from image analysis)
3. Cross-reference manufacturer's website when unsure
4. Be conservative - it's okay to not tag uncertain colors
5. Add attributes (transparent/opaque) when clearly visible

**Common cases:**
- Glass on colored backgrounds → Look past the background to the glass itself
- Finished pieces (marbles, pipes) → Identify the glass colors in the piece
- Multi-color glass → Tag all visible colors
- UV/reactive glass → Tag both the base color AND the attribute (uv, striker, etc.)

## Future Enhancements

- [ ] Batch image analysis via Claude API
- [ ] Confidence scoring from image analysis
- [ ] Auto-approve high-confidence suggestions
- [ ] Track approval accuracy over time
- [ ] Suggest corrections when user consistently overrides
- [ ] Export tagged image dataset for training

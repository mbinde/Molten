# CLAUDE.md - Glass Scraper Development Guide

This file contains instructions for Claude Code when working in the Scraping Tools directory.

## Directory Purpose

This directory contains Python scrapers for collecting glass product data from manufacturer websites. The scrapers combine data from 5 manufacturers into a single CSV file for import into the Flameworker iOS app.

## Project Structure

```
Scraping Tools/
├── update_database.py           # NEW RECOMMENDED ENTRY POINT - Git+JSON database
├── combined_glass_scraper.py    # Legacy CSV output (still works)
├── glass_database.json          # Version-controlled product database (generated)
├── test_scrapers.py             # Test suite - MUST pass before commits
├── color_extractor.py           # Shared color tagging utility
├── README_SCRAPERS.md           # User-facing documentation
├── CLAUDE.md                    # This file (Claude-specific instructions)
│
├── scrapers/                    # Manufacturer scraper modules
│   ├── __init__.py             # Package init (imports all scrapers)
│   ├── boro_batch.py           # Boro Batch (BB) scraper
│   ├── cim.py                  # Creation is Messy (CIM) scraper
│   ├── double_helix.py         # Double Helix (DH) scraper
│   ├── glass_alchemy.py        # Glass Alchemy (GA) scraper
│   └── tag.py                  # Trautman Art Glass (TAG) scraper
│
├── image_downloader.py         # Separate tool (run after scraping)
├── csv_to_json_converter.py   # Legacy tool (for Google Sheets workflow)
└── [legacy single-file scrapers - kept for reference]
```

## Development Workflow

### CRITICAL: Always Run Tests

**BEFORE making any changes:**
```bash
python3 test_scrapers.py
```

**AFTER making any changes:**
```bash
python3 test_scrapers.py
```

Tests MUST pass. If tests fail, do NOT proceed with other changes.

### Test-Driven Development

When adding features or fixing bugs:

1. **Write/update tests first** in `test_scrapers.py`
2. **Run tests** - they should fail (RED)
3. **Implement the fix/feature**
4. **Run tests** - they should pass (GREEN)
5. **Refactor if needed**
6. **Run tests again** - ensure still passing

### Testing Individual Manufacturers

```bash
# Test a specific manufacturer (fast, 2-3 items)
python3 combined_glass_scraper.py --mfr BB --test

# Test with more items
python3 combined_glass_scraper.py --mfr CIM --max-items 5
```

## Module Interface Contract

Each scraper module in `scrapers/` MUST implement:

### Required Functions

```python
def scrape(test_mode=False, max_items=None):
    """
    Scrape products from manufacturer website.

    Args:
        test_mode (bool): If True, limit to 2-3 items for testing
        max_items (int): Maximum items to scrape (overrides test_mode)

    Returns:
        tuple: (products_list, duplicates_list)
            products_list: List of product dicts
            duplicates_list: List of duplicate product dicts (for reporting)
    """
    pass


def format_products_for_csv(products):
    """
    Format product dicts into CSV-ready dicts with standard fields.

    Args:
        products: List of product dictionaries from scrape()

    Returns:
        List of dictionaries with these EXACT keys:
            - manufacturer
            - code
            - name
            - start_date
            - end_date
            - manufacturer_description
            - tags
            - synonyms
            - coe
            - type
            - manufacturer_url
            - image_path
            - image_url
            - stock_type
    """
    pass
```

### Required Module Constants

```python
MANUFACTURER_CODE = 'XX'  # e.g., 'BB', 'CIM', 'DH', 'GA', 'TAG'
MANUFACTURER_NAME = 'Full Name'
COE = '33'  # or '104'
```

## CSV Field Requirements

ALL scrapers MUST output these fields (in this order):

1. **manufacturer** - Manufacturer code (BB, CIM, DH, GA, TAG)
2. **code** - Product SKU/code
3. **name** - Cleaned product name (brand/type removed)
4. **start_date** - Product availability start (empty for now)
5. **end_date** - Product discontinuation (empty for now)
6. **manufacturer_description** - Full description from manufacturer
7. **tags** - Color tags (from color_extractor.py)
8. **synonyms** - Alternative names (empty for now)
9. **coe** - Coefficient of Expansion (33 or 104)
10. **type** - Product type (rod, frit, tube, stringer, sheet, other)
11. **manufacturer_url** - Link to product page
12. **image_path** - Local image path (empty - populated later)
13. **image_url** - Remote image URL
14. **stock_type** - Stock status (only DH uses this: available/oos/discontinued)

**IMPORTANT**: If a field doesn't apply, use empty string `''`, never `None` or omit it.

## Color Tagging

Use the shared `color_extractor.py` module:

```python
from color_extractor import extract_tags_from_name

tags = extract_tags_from_name("Sky Blue Rod")
# Returns: '"blue"'

tags = extract_tags_from_name("Red and Green Frit")
# Returns: '"green", "red"'  (sorted alphabetically)

tags = extract_tags_from_name("Something Unknown")
# Returns: '"unknown"'
```

**Rules:**
- Extracts from cleaned product name (after removing brand/type)
- Maps ~160 specific colors to base colors
- Returns comma-separated quoted color names
- Always returns `"unknown"` if no colors found

## Adding a New Manufacturer

1. **Create new scraper module**: `scrapers/new_manufacturer.py`
   - Implement `scrape()` and `format_products_for_csv()`
   - Define MANUFACTURER_CODE, MANUFACTURER_NAME, COE constants
   - Import color_extractor for tagging

2. **Register in package**: Edit `scrapers/__init__.py`
   ```python
   from . import new_manufacturer
   ```

3. **Register in combined scraper**: Edit `combined_glass_scraper.py`
   ```python
   MANUFACTURERS = {
       # ... existing ...
       'NEW': {
           'name': 'New Manufacturer',
           'module': new_manufacturer,
           'enabled': True
       }
   }
   ```

4. **Add to tests**: Edit `test_scrapers.py`
   ```python
   MANUFACTURER_MODULES = [..., 'new_manufacturer']
   ```

5. **Run tests** to verify everything works

## Modifying Existing Scrapers

### Boro Batch & Glass Alchemy
- Use Shopify JSON API (fast, reliable)
- Pattern: `https://example.com/collections/all/products.json?page=X&limit=250`

### Creation is Messy (CiM)
- Custom ASP.NET site with palette pages
- Scrapes color links from palette pages, then details from each color page
- More complex HTML parsing

### Double Helix & TAG
- WooCommerce sites (WordPress)
- HTML parsing with product gallery detection
- Double Helix tracks stock_type (available/oos/discontinued)

### When Modifying:
1. **Understand the existing pattern** - read the module code
2. **Write tests** for your changes
3. **Test with `--test` flag** first (2-3 items)
4. **Run full test suite** before committing
5. **Update README** if changing user-facing behavior

## Error Handling Philosophy

**Stop on Error**: If ANY manufacturer scraper fails, the combined scraper stops immediately.

**Why?** Prevents partial data imports that could corrupt the database. Better to have no data than bad data.

**When debugging:**
- Use `--mfr` flag to test single manufacturer
- Use `--max-items 2` for very quick tests
- Check error messages carefully - they usually point to website structure changes

## Common Issues

### Import Errors
- Make sure you're running from `Scraping Tools/` directory
- Python needs to find `scrapers/` package and `color_extractor.py`

### Website Structure Changes
- Manufacturers change their websites - scrapers break
- Check the HTML structure manually in browser
- Update parser classes (DescriptionParser, ProductParser, etc.)
- Test with `--test` flag before full run

### Duplicate SKUs
- Each scraper tracks seen SKUs and skips duplicates
- Duplicates are reported in summary
- If too many duplicates, check SKU extraction logic

### Missing Fields in CSV
- Run `python3 test_scrapers.py` - it will catch this
- Check `format_products_for_csv()` returns all required fields
- Use empty string `''` for missing values, not `None`

## Performance Considerations

- **Rate limiting** built into all scrapers (0.5-1 sec delays)
- **Full scrapes** take 10-30 minutes
- **Test mode** takes ~30 seconds
- Run during off-peak hours to be nice to manufacturer servers

## User Workflow (for context)

### New Workflow (Recommended):
1. Run `update_database.py` → Updates `glass_database.json`
2. Review diff output (shows new/updated/discontinued products)
3. Commit to Git (manual or `--auto-commit`)
4. Export to JSON with `--export` flag
5. Optionally run `image_downloader.py`
6. Add JSON to Flameworker app

### Legacy Workflow (Still Supported):
1. Run combined scraper → CSV file
2. Import CSV into Google Sheets
3. Manual review/edits in Sheets
4. Export as TSV from Sheets
5. Run `csv_to_json_converter.py` → JSON
6. Optionally run `image_downloader.py`
7. Add JSON to Flameworker app

## Database Update System

The `update_database.py` script provides:

**Version Control**:
- Git-based version history
- Never loses discontinued products
- Tracks when products were "last_seen"
- Automatic change detection

**Duplicate Detection**:
- Checks for duplicate keys before saving
- Prevents data corruption
- Reports conflicts clearly

**Smart Updates**:
- New products → added with `status="available"`, `added_date`, `last_seen`
- Existing products → updates fields, updates `last_seen`
- Missing products → marks `status="discontinued"`, sets `discontinued_date`
- Reappearing products → reverts to `status="available"`

**Database Schema**:
```json
{
  "version": "1.0",
  "last_updated": "2025-01-15T10:30:00",
  "products": {
    "BB:TEST-001": {
      "status": "available|discontinued",
      "added_date": "2025-01-01",
      "last_seen": "2025-01-15",
      "discontinued_date": null,
      "manufacturer": "BB",
      "code": "TEST-001",
      "name": "Product Name",
      // ... all CSV fields
    }
  }
}
```

**Command-Line Options**:
```bash
update_database.py                    # Update from all manufacturers
update_database.py --test             # Test with 2-3 items
update_database.py --mfr BB           # Update single manufacturer
update_database.py --dry-run          # Show changes without saving
update_database.py --auto-commit      # Automatically commit to Git
update_database.py --export out.json  # Export to JSON file
```

## Future Enhancements

Ideas for improvement (add tests first!):

- [ ] Add `stock_type` tracking for all manufacturers (currently only DH)
- [ ] Implement `start_date` and `end_date` tracking
- [ ] Add progress bars for long scrapes
- [ ] Parallel scraping of multiple manufacturers
- [ ] Automatic retry on network errors
- [ ] Validate image URLs before saving
- [ ] Add more color mappings to color_extractor.py

## When in Doubt

1. **Check tests**: `python3 test_scrapers.py`
2. **Read README**: `README_SCRAPERS.md` has user-facing docs
3. **Test with --test**: Always test with limited items first
4. **Follow TDD**: Write test → implement → verify

## Git Best Practices

- **Commit after tests pass**
- **Include test results** in commit message if adding features
- **Update README** if changing user-facing behavior
- **Don't commit CSV output files** (they're large and change frequently)

---

*This file is for Claude Code. User-facing documentation is in README_SCRAPERS.md.*

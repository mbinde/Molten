# Tag Configuration Files - Quick Reference

This directory contains three configuration files for managing product tags during scraping. Each serves a different purpose.

## Overview

| File | Purpose | When to Use |
|------|---------|-------------|
| `tag_overrides.txt` | Hard-code exact tags | Auto-detection fails completely |
| `tag_exclusions.txt` | Remove specific false positive tags | Auto-detection works but includes wrong tags |
| `excluded_urls.txt` | Exclude entire products | Product shouldn't be in database at all |

## tag_overrides.txt

**Purpose**: Completely replace auto-detected tags with hard-coded values.

**Format**: `URL<TAB>tag1,tag2,tag3`

**Example**:
```
# Single tag
https://glassalchemy.com/products/amazon-night-987	green

# Multiple tags (comma-separated, spaces optional)
https://doublehelixglassworks.com/product/mystery-glass/	blue,striking,reducing
https://example.com/another-product/	red, amber-purple, sparkle
```

**Notes**:
- Comma-separated for multiple tags
- Spaces after commas are optional (will be trimmed automatically)
- Tags will be sorted alphabetically in output
- Tags will be quoted automatically

**Use When**:
- Product name contains no useful color information
- Description is misleading or incomplete
- Auto-detection produces completely wrong results
- You need exact control over all tags for specific product

**Effect**: Bypasses all color and property detection. Only the specified tags will be used.

---

## tag_exclusions.txt

**Purpose**: Remove specific auto-detected tags that are false positives.

**Format**: `URL<TAB>excluded_tag1,excluded_tag2`

**Example**:
```
https://doublehelixglassworks.com/product/beautiful-red/	striking
https://glassalchemy.com/product/silver-sparkle/	silver
```

**Use When**:
- Auto-detection mostly works correctly
- One or two specific tags are wrong (e.g., "striking" used to mean "beautiful")
- You want to keep other auto-detected tags

**Effect**: Removes only the specified tags. Other auto-detected color and property tags remain.

---

## excluded_urls.txt

**Purpose**: Completely exclude specific products from the database.

**Format**: `URL` (one per line)

**Example**:
```
https://doublehelixglassworks.com/product/beginners-pack/
https://glassalchemy.com/products/sample-set/
```

**Use When**:
- Product is a sample pack, gift set, or bundle
- Product is not an individual glass item
- Product should never appear in the database

**Effect**: Product is filtered out before any processing. Never appears in database.

---

## Decision Flowchart

```
Is this product a sample pack/bundle/non-individual item?
├─ YES → Use excluded_urls.txt (exclude entire product)
└─ NO → Continue
    ↓
    Does auto-detection produce completely wrong tags?
    ├─ YES → Use tag_overrides.txt (hard-code correct tags)
    └─ NO → Continue
        ↓
        Are most tags correct but 1-2 are false positives?
        ├─ YES → Use tag_exclusions.txt (remove specific wrong tags)
        └─ NO → Nothing needed! Auto-detection works correctly.
```

---

## All Files Use Tab-Separated Format

**IMPORTANT**: All three files use TAB characters as separators (not spaces).

**How to enter a TAB**:
- In text editors: Press the Tab key
- Copy-paste from existing entries
- In vim/emacs: `Ctrl+V Tab`

**Common mistake**: Using spaces instead of tabs will cause entries to be ignored.

---

## Examples by Scenario

### Scenario 1: Sample Pack
**Problem**: "Beginner's Glass Pack" shouldn't be in database at all.

**Solution**: Add to `excluded_urls.txt`:
```
https://doublehelixglassworks.com/product/beginners-pack/
```

---

### Scenario 2: Misleading Description
**Problem**: "Amazon Night" - name gives no color info, description doesn't help.

**Solution**: Add to `tag_overrides.txt`:
```
https://glassalchemy.com/products/amazon-night-987	green
```

---

### Scenario 3: False Positive Keyword
**Problem**: Description says "This is a striking color!" meaning "beautiful", not the technical term.

**Solution**: Add to `tag_exclusions.txt`:
```
https://glassalchemy.com/product/beautiful-red/	striking
```
(Other auto-detected tags like "red" remain)

**Similar cases**: "sparkle" meaning "shiny" instead of actual glitter, "silver" as in "silver anniversary" instead of actual silver content, etc.

---

### Scenario 4: Multiple Issues
**Problem**: Product has both false positive "silver" (from "silver anniversary") AND wrong auto-detected colors.

**Solution**: Use `tag_overrides.txt` (not `tag_exclusions.txt`):
```
https://example.com/anniversary-glass/	blue,gold
```
(Tag overrides completely replace auto-detection, solving both problems)

---

## Testing Your Changes

After editing any configuration file, test with a small scrape:

```bash
python3 update_database.py --test --mfr GA --dry-run
```

This will:
- Scrape 2-3 items from Glass Alchemy
- Apply your configuration files
- Show results without saving to database

---

## File Locations

All three files must be in the same directory as the scraper scripts:
```
Scraping Tools/
├── tag_overrides.txt
├── tag_exclusions.txt
├── excluded_urls.txt
├── color_extractor.py
├── update_database.py
└── combined_glass_scraper.py
```

---

## Comments and Empty Lines

All three files support:
- **Comments**: Lines starting with `#` are ignored
- **Empty lines**: Blank lines are ignored
- **Inline documentation**: Use comments to explain why entries exist

**Example**:
```
# Double Helix - Products with misleading names
https://doublehelixglassworks.com/product/mystery/	blue,green

# Glass Alchemy - Anniversary special (not actual silver)
https://glassalchemy.com/products/silver-anniversary/	striking
```

This helps you remember why you added each entry!

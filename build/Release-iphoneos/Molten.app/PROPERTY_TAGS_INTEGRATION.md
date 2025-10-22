# Property Tag Extraction Integration Guide

## Overview

The `color_extractor.py` module now supports extracting technical property tags from product descriptions in addition to color tags from product names.

## Features

### 1. Technical Property Detection

Automatically detects these technical properties in descriptions:

- **reducing** - Glass that needs a reducing flame
- **striking** - Glass that changes color when heated
- **silver** - Glass containing silver (silver glass, silver fume, etc.)
- **amber-purple** - Amber-purple shifting glass
- **sparkle** - Glass with glittery or sparkly effects
- **uv** - Glass that reacts to UV light
- **metallic** - Glass with metallic finish or metal particles

### 2. Manufacturer-Specific Naming Conventions

Some manufacturers use specific words in product names to indicate technical properties:

- **Glass Alchemy (GA)**: Products with "passion" in the name are amber-purple glass

These conventions are automatically applied based on the manufacturer code.

### 3. False Positive Exclusion

Use `tag_exclusions.txt` to exclude tags from specific products when keywords are used non-technically (e.g., "striking" meaning "beautiful").

## New Function: `combine_tags()`

Replace `extract_tags_from_name()` with `combine_tags()` to get both color and property tags:

### Old Code:
```python
from color_extractor import extract_tags_from_name

tags = extract_tags_from_name(cleaned_name)
```

### New Code:
```python
from color_extractor import combine_tags

tags = combine_tags(
    product_name=cleaned_name,
    description=product.get('description', ''),
    manufacturer_url=product.get('url', ''),
    manufacturer_code=MANUFACTURER_CODE  # e.g., 'GA', 'BB', 'DH'
)
```

## Integration Steps

### Step 1: Update Import

```python
# Change this:
from color_extractor import extract_tags_from_name

# To this:
from color_extractor import combine_tags
```

### Step 2: Update Tag Extraction Call

In your scraper's `format_products_for_csv()` function:

```python
def format_products_for_csv(products):
    csv_rows = []
    for product in products:
        cleaned_name = remove_brand_from_title(product['name'])

        # OLD WAY:
        # tags = extract_tags_from_name(cleaned_name)

        # NEW WAY:
        tags = combine_tags(
            product_name=cleaned_name,
            description=product.get('description', ''),
            manufacturer_url=product.get('url', ''),
            manufacturer_code=MANUFACTURER_CODE  # Use your module's constant
        )

        csv_rows.append({
            'manufacturer': MANUFACTURER_CODE,
            'code': product.get('sku', ''),
            'name': cleaned_name,
            # ... other fields ...
            'tags': tags,
            # ... more fields ...
        })

    return csv_rows
```

## Managing Tag Issues

### Hard-Coding Tags (tag_overrides.txt)

When auto-detection completely fails or produces wrong results, hard-code the exact tags in `tag_overrides.txt`:

```
# Format: URL<TAB>tag1,tag2,tag3
https://glassalchemy.com/products/amazon-night-987	green
https://doublehelixglassworks.com/product/mystery-glass/	blue,striking,reducing
```

**Tag overrides completely replace auto-detection.** The specified tags will be used instead of any color or property detection.

### Excluding False Positives (tag_exclusions.txt)

When auto-detection works mostly well but includes incorrect tags (e.g., "striking" meaning "pretty"), add specific tags to exclude:

```
# Format: URL<TAB>excluded_tag1,excluded_tag2
https://doublehelixglassworks.com/product/beautiful-red/	striking
https://glassalchemy.com/product/silver-sparkle/	silver,striking
```

**Tag exclusions remove specific tags from auto-detected results.** Other auto-detected tags will still be included.

### Decision Guide

- **Use tag_overrides.txt** when:
  - Auto-detection completely misses the right tags
  - Product name/description are misleading
  - You need exact control over all tags

- **Use tag_exclusions.txt** when:
  - Auto-detection works but includes 1-2 wrong tags
  - Keywords used non-technically (e.g., "striking" = "beautiful")
  - Most tags are correct, just need to remove false positives

## Pattern Detection Details

### Reducing
- "reducing"
- "reduce", "reduces", "reduced"
- "reduci" (for "reducing")

### Striking
- "striking"
- "strike", "strikes", "struck"

### Silver
- "silver glass"
- "silver fume" / "silver fuming"
- "silver leaf"
- "contains silver"
- "with silver"

### Amber-Purple
- "amber purple"
- "amber-purple"
- "amber/purple"
- "amberpurple"

### Sparkle
- Detects: "glitter", "glittery", "glittering", "glitters"
- Detects: "sparkle", "sparkles", "sparkled", "sparkly", "sparkley"
- Tag output: "sparkle"

### UV
- "UV" (case-insensitive, word boundary matched)
- Will NOT match "uv" within words like "sculpture"

### Metallic
- "metallic"
- "metal", "metals"

## Adding Manufacturer Naming Conventions

If you discover a manufacturer uses specific words in product names to indicate technical properties, add them to `color_extractor.py`:

```python
MANUFACTURER_NAMING_CONVENTIONS = {
    'GA': {  # Glass Alchemy
        'passion': ['amber-purple'],
    },
    'DH': {  # Double Helix (example)
        'oracle': ['striking'],  # Example: if all Oracle products strike
    },
}
```

**Format**:
- Key: Manufacturer code ('GA', 'BB', 'DH', 'CIM', 'TAG')
- Value: Dictionary of `pattern: [list_of_tags]`
- Patterns use word boundary matching (case-insensitive)

**When to use this**:
- Manufacturer consistently uses a word to indicate a property
- The word appears in the product name (not description)
- You want automatic tagging for all matching products

## Testing

Run the test script to verify functionality:

```bash
python3 test_property_tags.py
```

## Example Output

**Input:**
- Name: "Blue Rod"
- Description: "This is a striking color that reduces beautifully in the flame."

**Output:**
```
"blue", "reducing", "striking"
```

## Backward Compatibility

The old `extract_tags_from_name()` function still works for color-only extraction. You can migrate scrapers incrementally.

## When to Update

Update scrapers to use `combine_tags()` when:
1. You're already modifying that scraper
2. You notice missing technical property tags in the database
3. You're adding a new scraper

No rush to update all scrapers immediately - both approaches work.

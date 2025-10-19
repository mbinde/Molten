# Glass Manufacturer Scrapers

Combined scraping tool for collecting glass product data from multiple manufacturers into a single CSV file.

## Overview

This tool scrapes product information from 5 glass manufacturers:
- **Boro Batch (BB)** - COE 33 borosilicate
- **Creation is Messy (CIM)** - COE 104 soft glass
- **Double Helix (DH)** - COE 33 borosilicate
- **Glass Alchemy (GA)** - COE 33 borosilicate
- **Trautman Art Glass (TAG)** - COE 33 borosilicate

All data is combined into a single CSV file ready for import into Google Sheets.

## Quick Start

```bash
# Scrape all manufacturers (full production run)
python3 combined_glass_scraper.py

# Test mode: 2-3 items per manufacturer
python3 combined_glass_scraper.py --test

# Scrape single manufacturer
python3 combined_glass_scraper.py --mfr BB --test

# Custom output filename
python3 combined_glass_scraper.py --output my_data.csv
```

## Usage

### Basic Commands

```bash
# Full scrape (all manufacturers, all products)
python3 combined_glass_scraper.py

# Test with limited items
python3 combined_glass_scraper.py --test
python3 combined_glass_scraper.py --max-items 5
```

### Single Manufacturer

```bash
# Test Boro Batch only
python3 combined_glass_scraper.py --mfr BB --test

# Test Creation is Messy only
python3 combined_glass_scraper.py --mfr CIM --test

# Test Double Helix only
python3 combined_glass_scraper.py --mfr DH --test

# Test Glass Alchemy only
python3 combined_glass_scraper.py --mfr GA --test

# Test TAG only
python3 combined_glass_scraper.py --mfr TAG --test
```

### Command-Line Options

```
--test              Test mode: scrape 2-3 items per manufacturer
--mfr CODE          Scrape only this manufacturer (BB, CIM, DH, GA, TAG)
--max-items N       Maximum items to scrape per manufacturer
--output FILE       Output CSV filename (default: combined_glass_products.csv)
--help              Show help message
```

## Output Format

The CSV file contains these fields:

| Field | Description | Example |
|-------|-------------|---------|
| `manufacturer` | Manufacturer code | `BB`, `CIM`, `DH`, `GA`, `TAG` |
| `code` | Product SKU/code | `BB-20-M-ElectricCoconut` |
| `name` | Cleaned product name | `Electric Coconut` |
| `start_date` | Product availability start | (empty for now) |
| `end_date` | Product discontinuation date | (empty for now) |
| `manufacturer_description` | Product description from manufacturer | Long text description |
| `tags` | Color tags (auto-extracted) | `"blue", "green"` |
| `synonyms` | Alternative names | (empty for now) |
| `coe` | Coefficient of Expansion | `33`, `104` |
| `type` | Product type | `rod`, `frit`, `tube`, `stringer` |
| `manufacturer_url` | Link to product page | Full URL |
| `image_path` | Local image path | (empty - use image_downloader.py) |
| `image_url` | Remote image URL | Full URL |
| `stock_type` | Stock status (DH only) | `available`, `oos`, `discontinued` |

## Workflow

### New Workflow (Recommended): Git+JSON Database

1. **Update database** from manufacturer websites:
   ```bash
   python3 update_database.py
   ```
   This automatically:
   - Runs scrapers to get latest data
   - Detects duplicate keys
   - Updates existing products
   - Marks discontinued products (never deletes historical data)
   - Tracks "last_seen" dates
   - Shows diff before saving

2. **Review changes** in the diff output

3. **Commit to Git** (optional automatic commit with `--auto-commit`)

4. **Export to JSON** for the app:
   ```bash
   python3 update_database.py --export glassitems.json
   ```

5. **Download images** (optional) using `image_downloader.py`

### Old Workflow (Manual, still supported):

1. **Run the scraper** to get CSV output
2. **Import CSV into Google Sheets**
3. **Export as tab-separated file** from Google Sheets
4. **Convert to JSON** using `csv_to_json_converter.py`
5. **Download images** (optional) using `image_downloader.py`
6. **Add to Flameworker app** via Resources/glassitems.json

## Project Structure

```
Scraping Tools/
├── combined_glass_scraper.py    # Main entry point - run this
├── color_extractor.py            # Shared color tagging utility
├── test_scrapers.py              # Test suite
├── scrapers/                     # Manufacturer modules
│   ├── __init__.py
│   ├── boro_batch.py            # BB scraper
│   ├── cim.py                   # CIM scraper
│   ├── double_helix.py          # DH scraper
│   ├── glass_alchemy.py         # GA scraper
│   └── tag.py                   # TAG scraper
├── image_downloader.py          # (Run separately after scraping)
└── csv_to_json_converter.py    # (Run after Google Sheets export)
```

## Testing

Run the test suite to verify all modules load correctly:

```bash
python3 test_scrapers.py
```

This will:
- Verify all scraper modules can be imported
- Check that required functions exist
- Validate CSV field consistency
- Test the combined scraper interface

## Error Handling

**Stop on Error**: The scraper will stop immediately if any manufacturer fails. This prevents partial data imports that could corrupt your database.

**Duplicate Detection**: Each manufacturer scraper tracks SKUs and skips duplicates automatically.

## Adding a New Manufacturer

1. Create new file in `scrapers/new_manufacturer.py`
2. Implement two required functions:
   ```python
   def scrape(test_mode=False, max_items=None):
       """Returns: (products_list, duplicates_list)"""
       pass

   def format_products_for_csv(products):
       """Returns: list of CSV-ready dictionaries"""
       pass
   ```
3. Add to `scrapers/__init__.py`:
   ```python
   from . import new_manufacturer
   ```
4. Register in `combined_glass_scraper.py` MANUFACTURERS dict
5. Add tests in `test_scrapers.py`

## Color Tagging

The `color_extractor.py` module automatically tags products with colors:
- Maps ~160 specific color names to base colors
- Uses word boundaries for accurate matching
- Returns tags like `"blue", "green"` or `"unknown"` if no colors found

Colors are extracted from the cleaned product name (after removing brand/type).

## Tips

- **Start with --test mode** to verify everything works before running full scrape
- **Test single manufacturers** with `--mfr` flag to debug issues
- **Use --max-items** to limit data during development
- **Full scrapes take 10-30 minutes** depending on manufacturer response times
- **Rate limiting** is built-in (0.5-1 second delays between requests)

## Troubleshooting

**Import errors**: Make sure you're running from the `Scraping Tools/` directory

**Missing modules**: Verify `scrapers/` directory has all `.py` files

**No data scraped**: Check internet connection and manufacturer websites

**CSV encoding issues**: File is UTF-8 encoded - import with UTF-8 in Google Sheets

## Future Enhancements

- Add `stock_type` tracking for all manufacturers (currently DH only)
- Implement `start_date` and `end_date` tracking
- Add progress bars for long-running scrapes
- Parallel scraping of multiple manufacturers
- Automatic retry on network errors
- Validate image URLs before saving

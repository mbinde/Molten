# Glass Manufacturer Scraping Tools

This directory contains tools for scraping glass product data from multiple manufacturers and combining them into a single CSV file for import into Google Sheets.

## 🎯 Quick Start

### Update Database (Recommended)

```bash
python3 update_database.py
```

This will:
- Scrape all manufacturers
- Update `glass_database.json` with version tracking
- Detect duplicate keys automatically
- Track when products were last seen
- Mark discontinued products (never deletes historical data)
- Show changes before saving

### Test Mode (2-3 items per manufacturer)

```bash
python3 update_database.py --test
```

Test with a small sample from each manufacturer.

### Scrape to CSV (Old Method)

```bash
python3 combined_glass_scraper.py
```

This will scrape all manufacturers and create `combined_glass_products.csv`.

### Scrape Single Manufacturer

```bash
python3 combined_glass_scraper.py --mfr BB          # Boro Batch only
python3 combined_glass_scraper.py --mfr CIM --test  # Creation is Messy (test mode)
python3 combined_glass_scraper.py --mfr DH          # Double Helix only
python3 combined_glass_scraper.py --mfr GA          # Glass Alchemy only
python3 combined_glass_scraper.py --mfr TAG         # Trautman Art Glass only
```

### Limit Items (for quick tests)

```bash
python3 combined_glass_scraper.py --mfr BB --max-items 5  # Just 5 items from Boro Batch
```

## 📊 Supported Manufacturers

| Code | Manufacturer | Website | Method |
|------|--------------|---------|--------|
| BB | Boro Batch | store.borobatch.com | Shopify JSON API |
| CIM | Creation is Messy | creationismessy.com | HTML parsing (ASP.NET) |
| DH | Double Helix | doublehelixglassworks.com | WooCommerce HTML |
| GA | Glass Alchemy | glassalchemy.com | Shopify JSON API |
| TAG | Trautman Art Glass | northstarglass.com | WooCommerce HTML |

## 📁 Project Structure

```
Scraping Tools/
├── combined_glass_scraper.py    # Main entry point - run this!
├── color_extractor.py            # Shared color tagging logic
├── scrapers/                     # Individual manufacturer modules
│   ├── __init__.py
│   ├── boro_batch.py
│   ├── cim.py
│   ├── double_helix.py
│   ├── glass_alchemy.py
│   └── tag.py
├── boro_batch_scraper.py         # Legacy standalone scraper
├── cim_scraper.py                # Legacy standalone scraper
├── double_helix_scraper.py       # Legacy standalone scraper
├── glass_alchemy_scraper.py      # Legacy standalone scraper
├── tag_scraper.py                # Legacy standalone scraper
└── README.md                     # This file
```

## 🔄 Workflow

### New Workflow: Git+JSON Database (Recommended)

1. **Update database**: Run `update_database.py`
   - Automatically scrapes all manufacturers
   - Detects duplicate keys
   - Tracks version history
   - Marks discontinued products

2. **Review changes**: Check the diff output

3. **Commit to Git**: Use `--auto-commit` or commit manually
   ```bash
   git add glass_database.json
   git commit -m "Update glass database"
   git push
   ```

4. **Export to JSON**: For app deployment
   ```bash
   python3 update_database.py --export glassitems.json
   ```

5. **Download images**: (Optional) Use `image_downloader.py`

### Old Workflow: Manual Google Sheets

1. **Scrape data**: Run `combined_glass_scraper.py`
2. **Import to Google Sheets**: Upload the CSV file
3. **Process in Sheets**: Clean, dedupe, add notes
4. **Export**: Download as TSV or CSV
5. **Convert to JSON**: Use `csv_to_json_converter.py`
6. **Download images**: Use `image_downloader.py` on the JSON

## 📝 CSV Output Fields

All manufacturers output the same standardized fields:

| Field | Description | Example |
|-------|-------------|---------|
| `manufacturer` | Manufacturer code | BB, CIM, DH, GA, TAG |
| `code` | Product SKU/code | 123, BB-456, etc. |
| `name` | Product name (cleaned) | Electric Coconut |
| `start_date` | Product start date (usually empty) | |
| `end_date` | Product end date (usually empty) | |
| `manufacturer_description` | Description from manufacturer | Long text... |
| `tags` | Extracted color tags | "blue", "green" |
| `synonyms` | Alternative names (usually empty) | |
| `coe` | Coefficient of Expansion | 33, 104 |
| `type` | Product type | rod, frit, tube, sheet |
| `manufacturer_url` | Product detail page URL | https://... |
| `image_path` | Local image path (filled by image_downloader) | |
| `image_url` | Image URL from manufacturer | https://cdn... |
| `stock_type` | Stock status (DH only) | available, oos, discontinued |

## 🎨 Color Tagging

All scrapers use the shared `color_extractor.py` module which:

- Maps ~160 specific color names to base colors
- Uses word boundaries for accurate matching
- Returns standardized tags like `"blue", "green", "yellow"`
- Falls back to `"unknown"` if no colors detected

## 🛠️ Command-Line Options

```
usage: combined_glass_scraper.py [-h] [--test] [--mfr {BB,CIM,DH,GA,TAG}]
                                  [--max-items N] [--output OUTPUT]

Combined glass manufacturer scraper

optional arguments:
  -h, --help            show this help message and exit
  --test                Test mode: scrape 2-3 items per manufacturer
  --mfr {BB,CIM,DH,GA,TAG}
                        Scrape only this manufacturer (e.g., BB, CIM, DH, GA, TAG)
  --max-items N         Maximum items to scrape per manufacturer (for testing)
  --output OUTPUT, -o OUTPUT
                        Output CSV filename (default: combined_glass_products.csv)
```

## ⚠️ Important Notes

### Error Handling
- The scraper **stops immediately** if any manufacturer fails
- This ensures you don't miss data from any manufacturer
- Check error messages and retry if needed

### Rate Limiting
- Includes automatic delays between requests (0.5-1 second)
- Respects server resources
- Don't run multiple instances simultaneously

### Test Mode Recommendations
- Always run `--test` first to verify everything works
- Test individual manufacturers with `--mfr` if issues arise
- Use `--max-items` for quick spot checks

### Duplicate Handling
- Each scraper tracks duplicate SKUs within its own data
- Duplicates are skipped and reported at the end
- Check the summary for any unexpected duplicates

## 🐛 Troubleshooting

### Import Error
```
ModuleNotFoundError: No module named 'scrapers'
```
**Solution**: Make sure you're running from the "Scraping Tools" directory.

### No Products Found
**Check**:
- Website is accessible
- No major website structure changes
- Your internet connection is working

### Specific Manufacturer Failing
```bash
# Test just that manufacturer
python3 combined_glass_scraper.py --mfr BB --test --max-items 1
```

## 📚 Adding a New Manufacturer

1. Create `scrapers/new_manufacturer.py`
2. Implement two functions:
   - `scrape(test_mode=False, max_items=None)` → returns `(products, duplicates)`
   - `format_products_for_csv(products)` → returns list of CSV-ready dicts
3. Add to `MANUFACTURERS` dict in `combined_glass_scraper.py`
4. Update this README

## 📜 License

Part of the Flameworker project. Internal tools for glass inventory management.

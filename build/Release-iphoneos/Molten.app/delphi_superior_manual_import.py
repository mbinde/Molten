#!/usr/bin/env python3
"""
Delphi Superior Glass Manual Import
====================================

Since Delphi Superior's website uses JavaScript-only interface,
this script imports from a manually curated data file.

Usage:
    python3 delphi_superior_manual_import.py
"""

import csv
import sys
import os

# Add parent directory to path for color_extractor import
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from color_extractor import combine_tags


MANUFACTURER_CODE = 'DS'
MANUFACTURER_NAME = 'Delphi Superior'
COE = '90'
BASE_URL = 'https://www.delphiglass.com'
DATA_FILE = 'delphi_superior_manual.txt'


def remove_brand_from_title(title):
    """Remove Delphi Superior brand name and COE from product title"""
    if not title:
        return ''

    cleaned_title = title

    # Remove "Delphi Superior" prefix
    cleaned_title = cleaned_title.replace('Delphi Superior ', '')

    # Remove COE suffix
    cleaned_title = cleaned_title.replace(' - 90 COE', '')
    cleaned_title = cleaned_title.replace(' 90 COE', '')

    # Clean up extra whitespace
    cleaned_title = ' '.join(cleaned_title.split())

    return cleaned_title.strip()


def determine_product_type(name):
    """Determine product type from name"""
    name_lower = name.lower()

    # All Delphi Superior products appear to be sheet glass
    # based on the naming (Transparent, Opal, Streaky, Blend patterns)
    return 'sheet'


def load_manual_data(filename):
    """Load manual data from pipe-delimited file"""
    products = []

    try:
        with open(filename, 'r', encoding='utf-8') as f:
            for line_num, line in enumerate(f, 1):
                line = line.strip()
                if not line:
                    continue

                parts = line.split('|')
                if len(parts) < 2:
                    print(f"Warning: Skipping malformed line {line_num}: {line}")
                    continue

                full_name = parts[0]
                item_code = parts[1]
                url = parts[2] if len(parts) >= 3 else ''

                cleaned_name = remove_brand_from_title(full_name)

                products.append({
                    'code': item_code.strip(),
                    'name': cleaned_name,
                    'full_name': full_name.strip(),
                    'url': url.strip()
                })

        print(f"Loaded {len(products)} products from {filename}")

        # Count how many have URLs
        with_urls = sum(1 for p in products if p['url'])
        without_urls = len(products) - with_urls
        print(f"  Products with URLs: {with_urls}")
        if without_urls > 0:
            print(f"  Products without URLs: {without_urls} (need to be added manually)")

        return products

    except FileNotFoundError:
        print(f"Error: {filename} not found")
        return []
    except Exception as e:
        print(f"Error reading {filename}: {e}")
        return []


def format_products_for_csv(products):
    """Format products into CSV-ready dictionaries"""
    csv_rows = []

    for product in products:
        code = product['code']

        # Ensure code has manufacturer prefix
        if code and not code.upper().startswith(f"{MANUFACTURER_CODE}-"):
            code = f"{MANUFACTURER_CODE}-{code}"

        cleaned_name = product['name']
        product_type = determine_product_type(cleaned_name)

        # Extract tags from color name
        # No description or URL available for manual data
        tags = combine_tags(cleaned_name, '', '', MANUFACTURER_CODE)

        # Use URL if available
        manufacturer_url = product.get('url', '')

        csv_rows.append({
            'manufacturer': MANUFACTURER_CODE,
            'code': code,
            'name': cleaned_name,
            'start_date': '',
            'end_date': '',
            'manufacturer_description': '',
            'tags': tags,
            'synonyms': '',
            'coe': COE,
            'type': product_type,
            'manufacturer_url': manufacturer_url,
            'image_path': '',
            'image_url': '',  # No images available (bot-protected site)
            'stock_type': ''
        })

    return csv_rows


def main():
    """Main entry point"""
    print("=" * 60)
    print(f"Delphi Superior Glass Manual Import")
    print("=" * 60)
    print(f"Manufacturer: {MANUFACTURER_NAME} ({MANUFACTURER_CODE})")
    print(f"COE: {COE}")
    print(f"Source: {DATA_FILE} (manually curated)")
    print("=" * 60)
    print()

    # Load manual data
    products = load_manual_data(DATA_FILE)

    if not products:
        print("No products loaded. Exiting.")
        return 1

    # Format for CSV
    csv_rows = format_products_for_csv(products)

    # Write CSV
    try:
        csv_filename = 'delphi_superior_products.csv'

        fieldnames = ['manufacturer', 'code', 'name', 'start_date', 'end_date',
                     'manufacturer_description', 'tags', 'synonyms', 'coe', 'type',
                     'manufacturer_url', 'image_path', 'image_url', 'stock_type']

        with open(csv_filename, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(csv_rows)

        print(f"\n✅ Successfully wrote {len(csv_rows)} products to {csv_filename}")
        print()
        print("Note: This is a manual import from curated data.")
        print("      URLs are included where manually added.")
        print("      No images available (bot-protected website).")
        print()

        # Show sample
        print("Sample products:")
        for row in csv_rows[:5]:
            print(f"  {row['code']}: {row['name']} ({row['type']})")
            print(f"    Tags: {row['tags']}")
            if row['manufacturer_url']:
                print(f"    URL: {row['manufacturer_url']}")
            else:
                print(f"    URL: (not added yet)")

        return 0

    except Exception as e:
        print(f"\n❌ Error writing CSV: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == '__main__':
    sys.exit(main())

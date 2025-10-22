#!/usr/bin/env python3
"""
Delphi Superior Glass Scraper
==============================

Since Delphi Superior's website uses JavaScript and bot protection,
this scraper imports from a manually curated data file.

Manufacturer: Delphi Superior (DS)
COE: 90
Website: https://www.delphiglass.com
"""

import sys
import os

# Add parent directory to path for color_extractor import
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
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
    # All Delphi Superior products are sheet glass
    # based on the naming (Transparent, Opal, Streaky, Blend patterns)
    return 'sheet'


def load_manual_data(filename):
    """Load manual data from pipe-delimited file"""
    products = []
    script_dir = os.path.dirname(os.path.abspath(__file__))
    parent_dir = os.path.dirname(script_dir)
    filepath = os.path.join(parent_dir, filename)

    try:
        with open(filepath, 'r', encoding='utf-8') as f:
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

        return products

    except FileNotFoundError:
        print(f"Error: {filepath} not found")
        return []
    except Exception as e:
        print(f"Error reading {filepath}: {e}")
        return []


def scrape(test_mode=False, max_items=None):
    """
    Scrape Delphi Superior products from manual data file.

    Args:
        test_mode (bool): If True, limit to 2-3 items for testing
        max_items (int): Maximum items to scrape (overrides test_mode)

    Returns:
        tuple: (products_list, duplicates_list)
    """
    print(f"\n{'='*60}")
    print(f"Scraping {MANUFACTURER_NAME} (Manual Import)")
    print(f"{'='*60}")
    print(f"Manufacturer: {MANUFACTURER_NAME} ({MANUFACTURER_CODE})")
    print(f"COE: {COE}")
    print(f"Source: {DATA_FILE} (manually curated)")
    print(f"{'='*60}\n")

    # Load manual data
    all_products = load_manual_data(DATA_FILE)

    if not all_products:
        print("No products loaded from manual data file.")
        return [], []

    # Apply test mode or max_items limit
    if max_items:
        all_products = all_products[:max_items]
    elif test_mode:
        all_products = all_products[:3]

    print(f"Loaded {len(all_products)} products from manual data")

    # Count how many have URLs
    with_urls = sum(1 for p in all_products if p['url'])
    without_urls = len(all_products) - with_urls
    print(f"  Products with URLs: {with_urls}")
    if without_urls > 0:
        print(f"  Products without URLs: {without_urls}")

    # No duplicates in manual data (already curated)
    duplicates = []

    return all_products, duplicates


def format_products_for_csv(products):
    """
    Format product dicts into CSV-ready dicts with standard fields.

    Args:
        products: List of product dictionaries from scrape()

    Returns:
        List of dictionaries with standard CSV fields
    """
    csv_rows = []

    for product in products:
        code = product['code']

        # Ensure code has manufacturer prefix
        if code and not code.upper().startswith(f"{MANUFACTURER_CODE}-"):
            code = f"{MANUFACTURER_CODE}-{code}"

        cleaned_name = product['name']
        product_type = determine_product_type(cleaned_name)

        # Extract tags from color name
        # No description available for manual data
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


if __name__ == '__main__':
    # Allow testing this scraper standalone
    products, duplicates = scrape(test_mode=True)

    if products:
        csv_rows = format_products_for_csv(products)
        print(f"\nFormatted {len(csv_rows)} products for CSV")
        print("\nSample products:")
        for row in csv_rows[:3]:
            print(f"  {row['code']}: {row['name']} ({row['type']})")
            print(f"    Tags: {row['tags']}")
            if row['manufacturer_url']:
                print(f"    URL: {row['manufacturer_url']}")

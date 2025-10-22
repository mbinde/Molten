#!/usr/bin/env python3
"""
Lunar Glass Scraper
===================

Scrapes Lunar Glass from Artistry in Glass distributor.
Platform: X-Cart (same as Parramore and Chinese Boro)

URL: https://artistryinglass.on.ca/BEADMAKING-and-FLAMEWORKING/lunar-glass/
"""

import re
import urllib.request
import urllib.error
import urllib.parse
import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from color_extractor import extract_tags_from_name
from scraper_config import is_bot_protection_error


# Constants
MANUFACTURER_CODE = 'LUN'
MANUFACTURER_NAME = 'Lunar Glass'
COE = '33'
BASE_URL = 'https://artistryinglass.on.ca'
CATEGORY_PATH = '/BEADMAKING-and-FLAMEWORKING/lunar-glass/'


def fetch_page():
    """
    Fetch the Lunar Glass category page.

    Returns:
        str: HTML content, or None if bot protection detected
    """
    url = f'{BASE_URL}{CATEGORY_PATH}'

    try:
        req = urllib.request.Request(url)
        req.add_header('User-Agent', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36')

        with urllib.request.urlopen(req) as response:
            return response.read().decode('utf-8')
    except urllib.error.HTTPError as e:
        if is_bot_protection_error(e):
            print(f"  ⚠️  Bot protection detected (HTTP {e.code})")
            print(f"  ⚠️  Cannot scrape - site is blocking requests")
            return None
        else:
            raise


def extract_products_from_page(html_content):
    """
    Extract product names from X-Cart page using product URLs.

    Lunar Glass products have URLs like:
    "lunar-glass/blue-waves-opal.html"
    "lunar-glass/dense-amethyst-opal.html"

    Returns list of product names.
    """
    products = []

    # Pattern to match product URLs
    # Format: "lunar-glass/{product-slug}.html"
    pattern = r'lunar-glass/([a-z0-9-]+)\.html'

    matches = re.findall(pattern, html_content, re.IGNORECASE)

    for slug in matches:
        # Convert URL slug to readable product name
        # "blue-waves-opal" → "Blue Waves Opal"
        product_name = slug.replace('-', ' ').title()

        # Skip if we've already seen this product
        if product_name not in [p['name'] for p in products]:
            products.append({
                'name': product_name
            })

    return products


def scrape(test_mode=False, max_items=None):
    """
    Scrape Lunar Glass products from Artistry in Glass.

    Args:
        test_mode: If True, limit to 2-3 items for testing
        max_items: Maximum items to scrape

    Returns:
        tuple: (products_list, duplicates_list)
    """
    print(f"\nScraping {MANUFACTURER_NAME} ({MANUFACTURER_CODE})")

    # Determine item limit
    if max_items:
        item_limit = max_items
    elif test_mode:
        item_limit = 3
    else:
        item_limit = None

    all_products = []
    seen_names = set()
    duplicates = []

    # Fetch the category page (single page with all products)
    print(f"Fetching Lunar Glass products...")

    html_content = fetch_page()

    # If bot protection detected, stop scraping
    if html_content is None:
        print(f"  Stopping scrape due to bot protection")
        return None, None  # Signal bot protection to caller

    products_on_page = extract_products_from_page(html_content)

    print(f"Found {len(products_on_page)} products")

    for product in products_on_page:
        name = product['name']

        # Check for duplicates
        if name in seen_names:
            duplicates.append(product)
            continue

        seen_names.add(name)
        all_products.append(product)

        # Check item limit
        if item_limit and len(all_products) >= item_limit:
            print(f"Reached max items limit ({item_limit})")
            break

    print(f"Total products scraped: {len(all_products)}")
    if duplicates:
        print(f"Duplicates skipped: {len(duplicates)}")

    return all_products, duplicates


def generate_product_code(product_name):
    """
    Generate product code from product name.

    Example: "Blue Waves Opal" → "LUN-BLUE-WAVES-OPAL"
    """
    # Convert to uppercase and replace spaces with hyphens
    code = product_name.upper().replace(' ', '-')
    # Remove special characters except hyphens
    code = re.sub(r'[^A-Z0-9-]', '', code)
    return f"{MANUFACTURER_CODE}-{code}"


def format_products_for_csv(products):
    """
    Format products for CSV output.

    Returns list of dicts with standard CSV fields.
    """
    csv_rows = []

    for product in products:
        product_name = product['name']

        # Generate product code
        code = generate_product_code(product_name)

        # Extract color tags
        tags = extract_tags_from_name(product_name)

        # Product type is rod (based on description: "based off Trautman 33 formulas")
        product_type = 'rod'

        # Build CSV row
        row = {
            'manufacturer': MANUFACTURER_CODE,
            'code': code,
            'name': product_name,
            'start_date': '',
            'end_date': '',
            'manufacturer_description': f'Lunar Glass {product_name} Rod',
            'tags': tags,
            'synonyms': '',
            'coe': COE,
            'type': product_type,
            'manufacturer_url': f'{BASE_URL}{CATEGORY_PATH}',
            'image_path': '',
            'image_url': '',
            'stock_type': ''
        }

        csv_rows.append(row)

    return csv_rows


if __name__ == '__main__':
    # Test the scraper
    products, dupes = scrape(test_mode=True)
    print(f"\nTest results: {len(products)} products")

    if products:
        print("\nSample product:")
        sample = format_products_for_csv([products[0]])[0]
        for key, value in sample.items():
            print(f"  {key}: {value}")

#!/usr/bin/env python3
"""
Chinese Boro Glass Scraper
===========================

Scrapes Chinese borosilicate glass from Artistry in Glass distributor.
Platform: X-Cart (same as Parramore)

URL: https://artistryinglass.on.ca/BEADMAKING-and-FLAMEWORKING/chinese-glass/chinese-borosilicate-rod/
"""

import re
import urllib.request
import urllib.parse
from color_extractor import extract_tags_from_name


# Constants
MANUFACTURER_CODE = 'CHB'
MANUFACTURER_NAME = 'Chinese Boro'
COE = '33'
BASE_URL = 'https://artistryinglass.on.ca'
CATEGORY_PATH = '/BEADMAKING-and-FLAMEWORKING/chinese-glass/chinese-borosilicate-rod/'


def fetch_page(page_num=1):
    """Fetch a category page"""
    if page_num == 1:
        url = f'{BASE_URL}{CATEGORY_PATH}'
    else:
        url = f'{BASE_URL}{CATEGORY_PATH}?page={page_num}'

    req = urllib.request.Request(url)
    req.add_header('User-Agent', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36')

    with urllib.request.urlopen(req) as response:
        return response.read().decode('utf-8')


def extract_products_from_page(html_content):
    """
    Extract product names from X-Cart page using product URLs.

    Chinese Boro products have URLs like:
    "chinese-borosilicate-rod/AMBER-TRANSPARENT-BORO-ROD.html"
    "chinese-borosilicate-rod/BLUE-TRANSPARENT-BORO-ROD.html"

    Returns list of color names.
    """
    products = []

    # Pattern to match product URLs
    # Format: "chinese-borosilicate-rod/{COLOR}-{TYPE}-BORO-ROD.html"
    pattern = r'chinese-borosilicate-rod/([A-Z][A-Z\-]+)-(?:TRANSPARENT|OPAQUE|MILKY)-BORO-ROD\.html'

    matches = re.findall(pattern, html_content, re.IGNORECASE)

    for color_slug in matches:
        # Convert URL slug to readable color name
        # "BRILLIANT-BLUE" → "Brilliant Blue"
        color_name = color_slug.replace('-', ' ').title()

        # Skip if we've already seen this color
        if color_name not in [p['color'] for p in products]:
            products.append({
                'color': color_name
            })

    return products


def scrape(test_mode=False, max_items=None):
    """
    Scrape Chinese Boro products from Artistry in Glass.

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
    seen_colors = set()
    duplicates = []

    # X-Cart page shows we have 27 products across 2 pages
    total_pages = 2

    for page_num in range(1, total_pages + 1):
        print(f"Fetching page {page_num}...")

        html_content = fetch_page(page_num)
        products_on_page = extract_products_from_page(html_content)

        print(f"Found {len(products_on_page)} products on page {page_num}")

        for product in products_on_page:
            color = product['color']

            # Check for duplicates
            if color in seen_colors:
                duplicates.append(product)
                continue

            seen_colors.add(color)
            all_products.append(product)

            # Check item limit
            if item_limit and len(all_products) >= item_limit:
                print(f"Reached max items limit ({item_limit})")
                break

        if item_limit and len(all_products) >= item_limit:
            break

    print(f"Total products scraped: {len(all_products)}")
    if duplicates:
        print(f"Duplicates skipped: {len(duplicates)}")

    return all_products, duplicates


def generate_product_code(color_name):
    """
    Generate product code from color name.

    Example: "Brilliant Blue" → "CHB-BRILLIANT-BLUE"
    """
    # Convert to uppercase and replace spaces with hyphens
    code = color_name.upper().replace(' ', '-')
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
        color_name = product['color']

        # Generate product code
        code = generate_product_code(color_name)

        # Product name: just the color since "Chinese Boro" is the manufacturer
        name = color_name

        # Extract color tags
        tags = extract_tags_from_name(name)

        # Product type is rod
        product_type = 'rod'

        # Build CSV row
        row = {
            'manufacturer': MANUFACTURER_CODE,
            'code': code,
            'name': name,
            'start_date': '',
            'end_date': '',
            'manufacturer_description': f'{color_name} Chinese Coloured Borosilicate Rod',
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

#!/usr/bin/env python3
"""
Gaffer Glass Scraper
====================

Scrapes Gaffer glass from E.B. Batch Color distributor.
Platform: PinnacleCart (static HTML)

Categories:
- Opaques: https://ebbatchcolor.com/Gaffer-Opaques/
- Transparents: https://ebbatchcolor.com/Gaffer-Transparents/
- Casting Colors: https://ebbatchcolor.com/Gaffer-Casting-Colors/
"""

import re
import urllib.request
import html.parser
from color_extractor import extract_tags_from_name


# Constants
MANUFACTURER_CODE = 'GAF'
MANUFACTURER_NAME = 'Gaffer'
COE = '96'
BASE_URL = 'https://ebbatchcolor.com'

# Category URLs
CATEGORIES = [
    {'path': '/Gaffer-Opaques/', 'type': 'sheet', 'name': 'Opaques'},
    {'path': '/Gaffer-Transparents/', 'type': 'sheet', 'name': 'Transparents'},
    {'path': '/Gaffer-Casting-Colors/', 'type': 'billet', 'name': 'Casting Colors'}
]


class GafferProductParser(html.parser.HTMLParser):
    """Parse Gaffer products from PinnacleCart HTML"""

    def __init__(self):
        super().__init__()
        self.products = []
        self.in_product_title_div = False
        self.in_product_link = False
        self.current_product = None

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)

        # Product title is in <div class="catalog-product-title">
        if tag == 'div' and attrs_dict.get('class') == 'catalog-product-title':
            self.in_product_title_div = True

        # Then look for <a> tag inside the div
        elif self.in_product_title_div and tag == 'a':
            self.in_product_link = True
            href = attrs_dict.get('href', '')
            self.current_product = {'url': href}

    def handle_data(self, data):
        if self.in_product_link and self.current_product is not None:
            # Product name format: "G-101 Opal White" or "G-100 Enamel White Limited Availability"
            product_name = data.strip()
            if product_name and product_name.startswith('G-'):
                self.current_product['name'] = product_name
                self.products.append(self.current_product)
                self.current_product = None
            self.in_product_link = False

    def handle_endtag(self, tag):
        if tag == 'div' and self.in_product_title_div:
            self.in_product_title_div = False
            self.in_product_link = False


def fetch_category(category_path):
    """Fetch a category page"""
    url = f'{BASE_URL}{category_path}'

    req = urllib.request.Request(url)
    req.add_header('User-Agent', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36')

    with urllib.request.urlopen(req) as response:
        return response.read().decode('utf-8')


def extract_products_from_category(html_content):
    """Extract products from a category page using HTML parser"""
    parser = GafferProductParser()
    parser.feed(html_content)
    return parser.products


def scrape(test_mode=False, max_items=None):
    """
    Scrape Gaffer products from E.B. Batch Color.

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

    for category in CATEGORIES:
        print(f"Fetching {category['name']}...")

        html_content = fetch_category(category['path'])
        products_on_page = extract_products_from_category(html_content)

        print(f"Found {len(products_on_page)} products in {category['name']}")

        for product in products_on_page:
            name = product['name']

            # Check for duplicates
            if name in seen_names:
                duplicates.append(product)
                continue

            seen_names.add(name)

            # Add category type to product
            product['category_type'] = category['type']
            product['category_name'] = category['name']

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


def parse_product_code_and_name(full_name):
    """
    Parse Gaffer product code and name.

    Format: "G-101 Opal White"
    Returns: ("G-101", "Opal White")
    """
    # Match pattern: G-XXX followed by the rest
    match = re.match(r'(G-\d+)\s+(.+)', full_name)
    if match:
        return match.group(1), match.group(2)

    # Fallback: return full name as both code and name
    return full_name, full_name


def format_products_for_csv(products):
    """
    Format products for CSV output.

    Returns list of dicts with standard CSV fields.
    """
    csv_rows = []

    for product in products:
        full_name = product['name']

        # Parse code and color name
        code, color_name = parse_product_code_and_name(full_name)

        # Extract color tags from the color name
        tags = extract_tags_from_name(color_name)

        # Determine product type from category
        product_type = product.get('category_type', 'sheet')

        # Build full product name with category context
        if product_type == 'billet':
            full_product_name = f"{color_name} Casting Brick"
        else:
            # Opaque or Transparent
            category_name = product.get('category_name', '')
            if 'Opaque' in category_name:
                full_product_name = f"{color_name} Opaque"
            elif 'Transparent' in category_name:
                full_product_name = f"{color_name} Transparent"
            else:
                full_product_name = color_name

        # Build CSV row
        # URL is already complete from the HTML, no need to prepend BASE_URL
        product_url = product.get('url', '')
        if not product_url.startswith('http'):
            product_url = f"{BASE_URL}{product_url}"

        row = {
            'manufacturer': MANUFACTURER_CODE,
            'code': code,
            'name': full_product_name,
            'start_date': '',
            'end_date': '',
            'manufacturer_description': f'Gaffer {full_product_name}',
            'tags': tags,
            'synonyms': '',
            'coe': COE,
            'type': product_type,
            'manufacturer_url': product_url,
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
        print("\nSample products:")
        samples = format_products_for_csv(products[:3])
        for sample in samples:
            print(f"\n{sample['code']}: {sample['name']}")
            print(f"  Type: {sample['type']}")
            print(f"  Tags: {sample['tags']}")

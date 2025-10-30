#!/usr/bin/env python3
"""
Thompson Enamel Scraper
=======================

Scrapes enamel products for Effetre glass from Thompson Enamel.

Website: https://thompsonenamel.com/product-category/enamels/enamels-for-effetre/

Excludes:
- EGS-1, EGS-2, EGS-3 (multi-color sets without photos)
- Samp-B-9000 (sample set)

Products:
- ~46 individual enamel colors (9000 series)
- COE 104 (compatible with Effetre/Moretti glass)
- Available as 80 mesh powder or 6/20 bead mesh frit

Example products: 9010 White, 9105 Yellow Beige, 9180 Dark Coffee
"""

import sys
import urllib.request
import urllib.error
import html.parser
import time
import re

# Manufacturer constants
MANUFACTURER_CODE = 'THMP'
MANUFACTURER_NAME = 'Thompson Enamel'
COE = '104'  # Thompson enamels are COE 104 for Effetre glass

# Base URL for product listing
BASE_URL = 'https://thompsonenamel.com/product-category/enamels/enamels-for-effetre/'
BASE_DOMAIN = 'https://thompsonenamel.com'

# Products to exclude
EXCLUDED_PREFIXES = ['EGS-', 'Samp-']  # EGS-1/2/3 and sample sets


class ProductListParser(html.parser.HTMLParser):
    """Parser to extract products from WooCommerce product listing pages"""

    def __init__(self):
        super().__init__()
        self.products = []
        self.current_product = None
        self.in_product_title = False
        self.in_product_link = False
        self.current_tag_stack = []

    def handle_starttag(self, tag, attrs):
        self.current_tag_stack.append(tag)
        attrs_dict = dict(attrs)

        # Detect product item container
        if tag == 'li' and 'class' in attrs_dict:
            if 'product' in attrs_dict['class']:
                self.current_product = {
                    'name': None,
                    'url': None,
                    'image_url': None,
                }

        # Detect product link (contains URL)
        if tag == 'a' and 'class' in attrs_dict and self.current_product:
            if 'woocommerce-LoopProduct-link' in attrs_dict['class']:
                self.current_product['url'] = attrs_dict.get('href', '')
                self.in_product_link = True

        # Detect product title
        if tag == 'h2' and 'class' in attrs_dict and self.current_product:
            if 'woocommerce-loop-product__title' in attrs_dict['class']:
                self.in_product_title = True

        # Detect product image
        if tag == 'img' and self.current_product:
            # Try data-lazy-src first (lazy loading), then src
            image_url = attrs_dict.get('data-lazy-src') or attrs_dict.get('src')
            if image_url and not self.current_product['image_url']:
                self.current_product['image_url'] = image_url

    def handle_endtag(self, tag):
        if self.current_tag_stack and self.current_tag_stack[-1] == tag:
            self.current_tag_stack.pop()

        # End of product title
        if tag == 'h2' and self.in_product_title:
            self.in_product_title = False

        # End of product link
        if tag == 'a' and self.in_product_link:
            self.in_product_link = False

        # End of product item - save it
        if tag == 'li' and self.current_product:
            if self.current_product['name']:
                self.products.append(self.current_product)
            self.current_product = None

    def handle_data(self, data):
        # Capture product title text
        if self.in_product_title and self.current_product:
            self.current_product['name'] = data.strip()


def scrape(test_mode=False, max_items=None):
    """
    Scrape Thompson enamel products.

    Args:
        test_mode (bool): If True, limit to 2-3 items for testing
        max_items (int): Maximum items to scrape (overrides test_mode)

    Returns:
        tuple: (products_list, duplicates_list)
    """
    products = []
    duplicates = []
    seen_codes = set()

    # Determine item limit
    if test_mode and max_items is None:
        max_items = 3

    print(f"Scraping Thompson enamels from: {BASE_URL}")
    if max_items:
        print(f"  Limiting to {max_items} items")

    # WooCommerce pagination - scrape all pages
    page = 1
    max_pages = 5  # Website shows 5 pages

    while page <= max_pages:
        if max_items and len(products) >= max_items:
            break

        # Build page URL
        if page == 1:
            url = BASE_URL
        else:
            url = f"{BASE_URL}page/{page}/"

        print(f"\nPage {page}/{max_pages}: {url}")

        try:
            with urllib.request.urlopen(url, timeout=30) as response:
                html_content = response.read().decode('utf-8')
        except urllib.error.URLError as e:
            print(f"  ERROR fetching page {page}: {e}", file=sys.stderr)
            break
        except Exception as e:
            print(f"  ERROR fetching page {page}: {e}", file=sys.stderr)
            break

        # Parse HTML to extract products
        parser = ProductListParser()
        parser.feed(html_content)

        if not parser.products:
            print(f"  No products found on page {page}")
            break

        print(f"  Found {len(parser.products)} products on page {page}")

        for item in parser.products:
            if max_items and len(products) >= max_items:
                break

            try:
                # Extract product name
                full_name = item['name']
                if not full_name:
                    continue

                # Skip excluded products (EGS-1/2/3 sets and sample sets)
                if any(full_name.startswith(prefix) for prefix in EXCLUDED_PREFIXES):
                    print(f"  Skipping excluded product: {full_name}")
                    continue

                # Extract product code and name
                # Format: "9010 White" -> code="9010", name="White"
                match = re.match(r'^(\d+)\s+(.+)$', full_name)
                if not match:
                    print(f"  Warning: Could not parse product name: {full_name}")
                    continue

                code = match.group(1)
                name = match.group(2)

                # Check for duplicates
                if code in seen_codes:
                    duplicates.append({'code': code, 'name': name})
                    print(f"  Duplicate SKU: {code} - {name}")
                    continue

                seen_codes.add(code)

                # Extract product URL and image URL from parser
                product_url = item.get('url')
                image_url = item.get('image_url')

                # Determine product type (opaque vs transparent)
                # Letters in parentheses indicate opacity: (A)=transparent, (B)=translucent, (C)=semi-opaque, (G)=opaque
                # Default to "enamel" if no indicator
                stock_type = "enamel"
                if '(A)' in full_name:
                    stock_type = "transparent"
                elif '(G)' in full_name:
                    stock_type = "opaque"
                elif '(B)' in full_name:
                    stock_type = "translucent"
                elif '(C)' in full_name:
                    stock_type = "semi-opaque"

                # Extract color tags from name
                tags = extract_tags(name)

                product = {
                    'code': code,
                    'name': name,
                    'full_name': full_name,
                    'manufacturer': MANUFACTURER_CODE,
                    'manufacturer_name': MANUFACTURER_NAME,
                    'coe': COE,
                    'tags': tags,
                    'stock_type': stock_type,
                    'type': 'enamel',
                    'manufacturer_url': product_url,
                    'image_url': image_url,
                }

                products.append(product)
                print(f"  ✓ {code}: {name} ({stock_type})")

            except Exception as e:
                print(f"  ERROR parsing product: {e}", file=sys.stderr)
                continue

        # Rate limiting
        time.sleep(0.5)
        page += 1

    print(f"\n✅ Scraped {len(products)} Thompson enamel products")
    if duplicates:
        print(f"⚠️  Found {len(duplicates)} duplicates")

    return products, duplicates


def format_products_for_csv(products):
    """
    Format product dicts into CSV-ready dicts with standard fields.

    Args:
        products: List of product dictionaries from scrape()

    Returns:
        List of dictionaries with CSV field names
    """
    csv_products = []

    for product in products:
        csv_product = {
            'manufacturer': product['manufacturer'],
            'product_type': 'coating',  # Thompson enamels are coatings
            'code': product['code'],
            'name': product['name'],
            'start_date': '',
            'end_date': '',
            'manufacturer_description': '',  # Could fetch from product page if needed
            'tags': product['tags'],
            'synonyms': '',
            'coe': product['coe'],
            'type': product['type'],
            'manufacturer_url': product.get('manufacturer_url', ''),
            'image_url': product.get('image_url', ''),
            'stock_type': product.get('stock_type', 'enamel'),
        }
        csv_products.append(csv_product)

    return csv_products


def extract_tags(name):
    """
    Extract color tags from product name.

    Args:
        name: Product name (e.g., "White", "Yellow Beige", "Dark Coffee")

    Returns:
        Comma-separated quoted tags (e.g., '"white"', '"yellow", "beige"')
    """
    tags = set()
    text = name.lower()

    # Common color keywords
    colors = [
        'white', 'black', 'gray', 'grey', 'silver',
        'red', 'pink', 'orange', 'yellow', 'gold',
        'green', 'blue', 'purple', 'violet', 'brown',
        'beige', 'tan', 'khaki', 'aqua', 'turquoise',
        'clear', 'opal', 'amber'
    ]

    for color in colors:
        if color in text:
            tags.add(color)

    # Return sorted, quoted tags
    if tags:
        sorted_tags = sorted(tags)
        return ', '.join(f'"{tag}"' for tag in sorted_tags)
    return '"enamel"'  # Default tag


if __name__ == '__main__':
    # Test the scraper
    print("Testing Thompson scraper...")
    products, duplicates = scrape(test_mode=True)

    if products:
        print(f"\n{'='*70}")
        print("Sample product:")
        print(f"{'='*70}")
        for key, value in products[0].items():
            print(f"  {key}: {value}")

        print(f"\n{'='*70}")
        print("CSV Format:")
        print(f"{'='*70}")
        csv_products = format_products_for_csv(products)
        for key, value in csv_products[0].items():
            print(f"  {key}: {value}")

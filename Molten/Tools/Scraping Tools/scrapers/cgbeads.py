"""
CG Beads scraper

Scrapes tool products from CG Beads website (ShopSite platform)
Products are on two main index pages (non-paginated)
"""

import urllib.request
import urllib.error
import urllib.parse
import re
import time
import html.parser
import html
import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from scraper_config import get_page_delay, get_product_delay, is_bot_protection_error

# Constants
MANUFACTURER_CODE = 'cgbeads'
MANUFACTURER_NAME = 'CG Beads'
MANUFACTURER_URL = 'https://www.cgbeads.com'
PRODUCT_TYPE = 'tools'

# Product index pages to scrape
INDEX_PAGES = [
    f'{MANUFACTURER_URL}/cgbeadrollers_groupings_presses_index.html',  # Presses (19 items)
    f'{MANUFACTURER_URL}/cgbeadrollers_groupings_index.html'           # Bead Rollers (200+ items)
]


class ProductIndexParser(html.parser.HTMLParser):
    """Parser to extract product information from index pages"""
    def __init__(self):
        super().__init__()
        self.products = []
        self.in_link = False
        self.current_link = ""
        self.current_name = ""
        self.current_image = ""

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)

        # Detect product links (detail pages)
        if tag == 'a':
            href = attrs_dict.get('href', '')
            if 'details.html' in href:
                self.in_link = True
                # Make URL absolute
                if href.startswith('http'):
                    self.current_link = href
                elif href.startswith('/'):
                    self.current_link = MANUFACTURER_URL + href
                else:
                    self.current_link = MANUFACTURER_URL + '/' + href

        # Detect product images
        if tag == 'img':
            src = attrs_dict.get('src', '')
            if src and ('cgbeadrollers-index' in src or 'cgbead-presses-index' in src):
                # Make URL absolute
                if src.startswith('http'):
                    self.current_image = src
                elif src.startswith('/'):
                    self.current_image = MANUFACTURER_URL + src
                else:
                    self.current_image = MANUFACTURER_URL + '/' + src

    def handle_data(self, data):
        text = data.strip()

        # Capture product name when inside a link
        if self.in_link and text and not text.startswith('http'):
            # Filter out non-product text
            skip_terms = ['home', 'cart', 'checkout', 'search', 'login']
            if not any(term in text.lower() for term in skip_terms):
                self.current_name = text

    def handle_endtag(self, tag):
        if tag == 'a' and self.in_link:
            # Save product if we have both name and link
            if self.current_name and self.current_link:
                # Extract SKU from link (e.g., "press-19" from "cgbead-press_press-19-details.html")
                sku_match = re.search(r'_(br-[^_-]+|press-\d+)-details', self.current_link, re.IGNORECASE)
                if sku_match:
                    sku = sku_match.group(1).lower()
                else:
                    # Fallback: use last part of URL
                    sku = self.current_link.split('/')[-1].replace('-details.html', '').replace('_', '-')

                # Determine category from SKU/name
                if 'press' in sku or 'press' in self.current_name.lower():
                    category = 'Bead Presses'
                else:
                    category = 'Bead Rollers'

                self.products.append({
                    'name': html.unescape(self.current_name),
                    'sku': sku,
                    'product_url': self.current_link,
                    'image_url': self.current_image,
                    'category': category
                })

            # Reset for next product
            self.in_link = False
            self.current_link = ""
            self.current_name = ""
            self.current_image = ""


def scrape(test_mode=False, max_items=None):
    """
    Scrape tool products from CG Beads index pages

    Args:
        test_mode (bool): If True, limit to 2-3 items for testing
        max_items (int): Maximum items to scrape (overrides test_mode)

    Returns:
        tuple: (products_list, duplicates_list)
    """
    products = []
    duplicates = []
    seen_skus = set()

    if test_mode and max_items is None:
        max_items = 3

    print(f"\n{'='*60}")
    print(f"Scraping {MANUFACTURER_NAME}")
    print(f"{'='*60}")
    if test_mode:
        print("TEST MODE - Limited items")

    # Scrape each index page
    for page_url in INDEX_PAGES:
        if max_items and len(products) >= max_items:
            print(f"\n✓ Reached max items limit ({max_items})")
            break

        print(f"\nFetching index page: {page_url}")

        try:
            time.sleep(get_page_delay(MANUFACTURER_CODE))

            req = urllib.request.Request(
                page_url,
                headers={'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'}
            )
            with urllib.request.urlopen(req, timeout=30) as response:
                html_content = response.read().decode('utf-8', errors='ignore')

            # Parse product links
            parser = ProductIndexParser()
            parser.feed(html_content)

            print(f"  Found {len(parser.products)} products")

            # Process products
            for product_data in parser.products:
                if max_items and len(products) >= max_items:
                    print(f"\n✓ Reached max items limit ({max_items})")
                    break

                sku = product_data['sku']

                # Add default values
                product_data.update({
                    'description': '',
                    'price': None,
                    'status': 'available'
                })

                # Check for duplicates
                if sku in seen_skus:
                    duplicates.append(product_data)
                    print(f"  ⚠️  Duplicate SKU: {sku}")
                else:
                    seen_skus.add(sku)
                    products.append(product_data)
                    print(f"  ✓ {product_data['name']} (SKU: {sku})")

        except urllib.error.HTTPError as e:
            if is_bot_protection_error(e):
                print(f"  ⚠️  Bot protection detected: {e.code}")
                raise RuntimeError("Bot protection detected - please try again later")
            print(f"  ⚠️  HTTP Error {e.code}")
            break
        except Exception as e:
            print(f"  ⚠️  Error fetching page: {e}")
            break

    print(f"\n{'='*60}")
    print(f"Scraped {len(products)} products from {MANUFACTURER_NAME}")
    if duplicates:
        print(f"Found {len(duplicates)} duplicates")
    print(f"{'='*60}")

    return products, duplicates


def format_products_for_csv(products):
    """
    Format product dicts into CSV-ready dicts with standard fields.
    """
    formatted = []

    for product in products:
        formatted.append({
            'manufacturer': MANUFACTURER_CODE,
            'product_type': PRODUCT_TYPE,
            'code': product['sku'],
            'name': product['name'],
            'start_date': '',
            'end_date': '',
            'manufacturer_description': product.get('description', ''),
            'tags': '',
            'synonyms': '',
            'coe': '',
            'type': 'other',
            'manufacturer_url': product.get('product_url', ''),
            'image_url': product.get('image_url', ''),
            'stock_type': product.get('status', 'available')
        })

    return formatted


if __name__ == '__main__':
    # Test the scraper
    products, duplicates = scrape(test_mode=True)

    if products:
        print("\n" + "="*60)
        print("Sample products:")
        for product in products[:3]:
            print(f"\n{product['name']}")
            print(f"  SKU: {product['sku']}")
            print(f"  Category: {product.get('category', 'N/A')}")
            print(f"  Status: {product.get('status', 'available')}")
            print(f"  URL: {product.get('product_url', 'N/A')}")
            print(f"  Image: {product.get('image_url', 'N/A')}")

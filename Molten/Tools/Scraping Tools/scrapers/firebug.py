"""
Fire Bug Tools scraper

Scrapes tool products from Fire Bug Tools website (WooCommerce-based)
"""

import urllib.request
import urllib.error
import urllib.parse
import re
import time
import html.parser
import html
import sys
import json
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from scraper_config import get_page_delay, get_product_delay, is_bot_protection_error

# Constants
MANUFACTURER_CODE = 'firebug'
MANUFACTURER_NAME = 'Fire Bug Tools'
MANUFACTURER_URL = 'https://firebugtools.com'
PRODUCT_TYPE = 'tools'

class DescriptionParser(html.parser.HTMLParser):
    """Parser to extract product details from detail page"""
    def __init__(self):
        super().__init__()
        self.description = ""
        self.in_description = False
        self.description_texts = []
        self.image_url = ""
        self.sku = ""
        self.price = ""
        self.in_price = False
        self.category = ""
        self.in_category = False
        self.stock_status = "available"
        self.in_stock_span = False

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)

        # Extract description from .description div
        if tag == 'div' and 'class' in attrs_dict:
            class_str = attrs_dict['class'].lower()
            if 'description' in class_str:
                self.in_description = True

        # Extract price from .price span
        if tag == 'span' and 'class' in attrs_dict:
            class_str = attrs_dict['class'].lower()
            if 'price' in class_str:
                self.in_price = True
            if 'stock' in class_str:
                self.in_stock_span = True

        # Extract category from .posted_in span
        if tag == 'span' and 'class' in attrs_dict:
            class_str = attrs_dict['class'].lower()
            if 'posted_in' in class_str:
                self.in_category = True

        # Extract image from product gallery
        if tag == 'img':
            src = attrs_dict.get('src', '')

            if not src:
                return

            # Skip placeholder, icon, logo images
            skip_terms = ['icon', 'logo', '_small', '_thumb', 'placeholder', 'default',
                         'no-image', 'avatar', 'banner', 'header', 'footer', 'badge']
            if any(term in src.lower() for term in skip_terms):
                return

            # Check if this is in a product gallery
            in_product_gallery = False
            if 'class' in attrs_dict:
                class_str = attrs_dict['class'].lower()
                if any(term in class_str for term in ['woocommerce-product-gallery__image',
                                                       'wp-post-image', 'attachment-woocommerce_single']):
                    in_product_gallery = True

            # Check if it's a WordPress upload
            is_wordpress_image = 'wp-content/uploads' in src
            is_better_quality = any(term in src for term in ['-scaled', '-1024x1024', '-2048x'])

            # Use gallery images or high-quality WordPress images
            if in_product_gallery or (is_wordpress_image and is_better_quality):
                if in_product_gallery or not self.image_url or is_better_quality:
                    if src.startswith('//'):
                        self.image_url = 'https:' + src
                    elif src.startswith('http'):
                        self.image_url = src
                    elif src.startswith('/'):
                        self.image_url = MANUFACTURER_URL + src

    def handle_data(self, data):
        text = data.strip()

        if self.in_description and text:
            self.description_texts.append(text)

        if self.in_price and text:
            # Extract price (e.g., "$45.00")
            price_match = re.search(r'\$?([\d,]+\.?\d*)', text)
            if price_match:
                self.price = price_match.group(1).replace(',', '')

        if self.in_category and text:
            # Extract category name
            if text.lower() not in ['categories:', 'category:']:
                self.category = text.strip()

        if self.in_stock_span and text:
            # Check stock status
            text_lower = text.lower()
            if 'out of stock' in text_lower:
                self.stock_status = "out_of_stock"
            elif 'in stock' in text_lower:
                self.stock_status = "available"

    def handle_endtag(self, tag):
        if tag == 'div' and self.in_description:
            self.in_description = False

        if tag == 'span':
            self.in_price = False
            self.in_category = False
            self.in_stock_span = False

    def get_sku(self, product_url):
        """Extract SKU from URL slug"""
        # URL format: https://firebugtools.com/product/bowl-push-1-4/
        match = re.search(r'/product/([^/]+)/?$', product_url)
        if match:
            return match.group(1)
        return ""

    def get_description(self):
        """Extract and clean description"""
        if self.description_texts:
            full_text = ' '.join(self.description_texts)
            full_text = re.sub(r'\s+', ' ', full_text).strip()
            return full_text
        return ""


class ProductListParser(html.parser.HTMLParser):
    """Parser to extract product links from shop page"""
    def __init__(self):
        super().__init__()
        self.products = []
        self.in_product = False
        self.current_link = ""
        self.current_name = ""
        self.in_product_title = False

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)

        # Detect product links
        if tag == 'a':
            href = attrs_dict.get('href', '')
            if '/product/' in href and href not in self.products:
                self.current_link = href
                self.in_product = True

        # Detect product title heading
        if tag in ['h2', 'h3'] and self.in_product:
            self.in_product_title = True

    def handle_data(self, data):
        if self.in_product_title and data.strip():
            self.current_name = data.strip()

    def handle_endtag(self, tag):
        if tag == 'a' and self.in_product and self.current_link:
            if self.current_link not in self.products:
                self.products.append(self.current_link)
            self.in_product = False
            self.current_link = ""

        if tag in ['h2', 'h3']:
            self.in_product_title = False


def scrape_product_page(product_url):
    """Scrape a single product page for details"""
    print(f"  Fetching: {product_url}")

    try:
        time.sleep(get_product_delay(MANUFACTURER_CODE))

        req = urllib.request.Request(
            product_url,
            headers={
                'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
            }
        )
        with urllib.request.urlopen(req, timeout=30) as response:
            html_content = response.read().decode('utf-8')

        # Parse product details
        parser = DescriptionParser()
        parser.feed(html_content)

        # Extract product name from page
        name_match = re.search(r'<h1[^>]*>([^<]+)</h1>', html_content)
        name = html.unescape(name_match.group(1).strip()) if name_match else ""

        # Extract SKU from URL
        sku = parser.get_sku(product_url)

        # Get description
        description = parser.get_description()

        # Extract price if not found by parser
        if not parser.price:
            price_match = re.search(r'<span class="price">.*?\$?([\d,]+\.?\d*)', html_content)
            if price_match:
                parser.price = price_match.group(1).replace(',', '')

        return {
            'name': name,
            'sku': sku,
            'description': description,
            'price': float(parser.price) if parser.price else 0.0,
            'category': parser.category if parser.category else "Tools",
            'image_url': parser.image_url,
            'product_url': product_url,
            'status': parser.stock_status
        }

    except urllib.error.HTTPError as e:
        if is_bot_protection_error(e):
            print(f"  ⚠️  Bot protection detected: {e.code}")
            raise RuntimeError(f"Bot protection detected for {product_url}")
        print(f"  ⚠️  HTTP Error {e.code}: {product_url}")
        return None
    except Exception as e:
        print(f"  ⚠️  Error scraping product: {e}")
        return None


def scrape(test_mode=False, max_items=None):
    """
    Scrape tool products from Fire Bug Tools

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

    # Product categories to scrape
    categories = [
        'bowl-pushes',
        'reamers',
        'paddles',
        'mashers',
        'marble-tools'
    ]

    # Scrape each category
    for category in categories:
        if max_items and len(products) >= max_items:
            print(f"\n✓ Reached max items limit ({max_items})")
            break

        print(f"\n--- Category: {category} ---")
        page = 1

        while True:
            if max_items and len(products) >= max_items:
                break

            # Construct category page URL
            if page == 1:
                page_url = f"{MANUFACTURER_URL}/product-category/{category}/"
            else:
                page_url = f"{MANUFACTURER_URL}/product-category/{category}/page/{page}/"

            print(f"Fetching page {page}: {page_url}")

            try:
                time.sleep(get_page_delay(MANUFACTURER_CODE))

                req = urllib.request.Request(
                    page_url,
                    headers={
                        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
                    }
                )
                with urllib.request.urlopen(req, timeout=30) as response:
                    html_content = response.read().decode('utf-8')

                # Parse product links
                parser = ProductListParser()
                parser.feed(html_content)

                if not parser.products:
                    print("  No products found on this page")
                    break

                print(f"  Found {len(parser.products)} product links")

                # Scrape each product
                for product_url in parser.products:
                    if max_items and len(products) >= max_items:
                        print(f"\n✓ Reached max items limit ({max_items})")
                        break

                    product_data = scrape_product_page(product_url)

                    if product_data:
                        # Add category info
                        product_data['category'] = category.replace('-', ' ').title()
                        sku = product_data['sku']

                        if sku in seen_skus:
                            duplicates.append(product_data)
                            print(f"  ⚠️  Duplicate SKU: {sku}")
                        else:
                            seen_skus.add(sku)
                            products.append(product_data)
                            print(f"  ✓ {product_data['name']} (SKU: {sku})")

                page += 1

            except urllib.error.HTTPError as e:
                if e.code == 404:
                    print(f"  No more pages (404)")
                    break
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

    Returns list of dictionaries with these keys:
        - manufacturer
        - product_type
        - code
        - name
        - start_date
        - end_date
        - manufacturer_description
        - tags
        - synonyms
        - coe
        - type
        - manufacturer_url
        - image_url
        - stock_type
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
            'tags': '',  # Tools don't use color tags
            'synonyms': '',
            'coe': '',  # Tools don't have COE
            'type': 'other',  # Tool product form
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
            print(f"  Price: ${product.get('price', 0):.2f}")
            print(f"  Category: {product.get('category', 'N/A')}")
            print(f"  Status: {product.get('status', 'available')}")
            print(f"  URL: {product.get('product_url', 'N/A')}")

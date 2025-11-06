"""
Ennion Glass Tools scraper

Scrapes tool products from Ennion Glass Tools website (Shopify-based)
"""

import urllib.request
import urllib.error
import urllib.parse
import re
import time
import sys
import json
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from scraper_config import get_page_delay, get_product_delay, is_bot_protection_error

# Constants
MANUFACTURER_CODE = 'ennion'
MANUFACTURER_NAME = 'Ennion Glass Tools'
MANUFACTURER_URL = 'https://ennionglasstools.com'
PRODUCT_TYPE = 'tools'


def scrape(test_mode=False, max_items=None):
    """
    Scrape tool products from Ennion Glass Tools using Shopify JSON API

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

    page = 1

    while True:
        if max_items and len(products) >= max_items:
            print(f"\n✓ Reached max items limit ({max_items})")
            break

        # Shopify Collections JSON API endpoint
        url = f"{MANUFACTURER_URL}/collections/all/products.json?page={page}&limit=250"
        print(f"\nFetching page {page}: {url}")

        try:
            time.sleep(get_page_delay(MANUFACTURER_CODE))

            req = urllib.request.Request(
                url,
                headers={'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'}
            )
            with urllib.request.urlopen(req, timeout=30) as response:
                json_content = response.read().decode('utf-8')
                data = json.loads(json_content)

            shopify_products = data.get('products', [])

            if not shopify_products:
                print("  No more products found")
                break

            print(f"  Found {len(shopify_products)} products")

            for product in shopify_products:
                if max_items and len(products) >= max_items:
                    print(f"\n✓ Reached max items limit ({max_items})")
                    break

                # Extract product data
                product_id = str(product.get('id', ''))
                title = product.get('title', '')
                handle = product.get('handle', '')
                product_url = f"{MANUFACTURER_URL}/products/{handle}"

                # Get description (strip HTML tags)
                description = product.get('body_html', '')
                description = re.sub(r'<[^>]+>', '', description)
                description = re.sub(r'\s+', ' ', description).strip()

                # Get product type/category
                product_type = product.get('product_type', 'Tools')

                # Get first image
                images = product.get('images', [])
                image_url = images[0].get('src', '') if images else ''

                # Get SKU and price from first variant
                variants = product.get('variants', [])
                if variants:
                    variant = variants[0]
                    variant_sku = variant.get('sku', '')
                    # Use variant SKU if not empty, otherwise use handle
                    sku = variant_sku if variant_sku else handle
                    price = float(variant.get('price', 0))

                    # Check availability
                    available = variant.get('available', True)
                    status = "available" if available else "out_of_stock"
                else:
                    sku = handle
                    price = 0.0
                    status = "available"

                # Create product dict
                product_data = {
                    'name': title,
                    'sku': sku if sku else handle,
                    'description': description,
                    'price': price,
                    'category': product_type,
                    'image_url': image_url,
                    'product_url': product_url,
                    'status': status
                }

                # Check for duplicates
                if sku in seen_skus:
                    duplicates.append(product_data)
                    print(f"  ⚠️  Duplicate SKU: {sku}")
                else:
                    seen_skus.add(sku)
                    products.append(product_data)
                    print(f"  ✓ {title} (SKU: {sku})")

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
            print(f"  Price: ${product.get('price', 0):.2f}")
            print(f"  Category: {product.get('category', 'N/A')}")
            print(f"  Status: {product.get('status', 'available')}")
            print(f"  URL: {product.get('product_url', 'N/A')}")

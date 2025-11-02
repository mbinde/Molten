#!/usr/bin/env python3
"""
Asian Glass Scraper
===================

Scrapes Asian borosilicate glass from ABR Imagery (abrimagery.com).
Platform: Shopify

URL: https://abrimagery.com/collections/color-glass
Note: Formerly "Chinese Boro" - rebranded to "Asian" glass
"""

import re
import urllib.request
import urllib.error
import urllib.parse
import json
import time
import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from color_extractor import combine_tags
from scraper_config import get_page_delay, is_bot_protection_error


# Constants
MANUFACTURER_CODE = 'AB'
MANUFACTURER_NAME = 'Asian Boro'
COE = '33'
BASE_URL = 'https://abrimagery.com'


def determine_product_type(product_name, tags):
    """Determine the type of glass product from its name and tags"""
    name_lower = product_name.lower()
    tags_lower = ' '.join(tags).lower() if tags else ''

    if 'frit' in name_lower or 'frit' in tags_lower:
        return 'frit'
    elif 'tube' in name_lower or 'tubing' in name_lower or 'tube' in tags_lower:
        return 'tube'
    elif 'rod' in name_lower or 'rod' in tags_lower:
        return 'rod'
    elif 'fatboy' in name_lower:
        return 'rod'  # Fatboys are thick rods
    elif 'stringer' in name_lower or 'stringer' in tags_lower:
        return 'stringer'
    elif 'sheet' in name_lower or 'sheet' in tags_lower:
        return 'sheet'
    else:
        return 'rod'  # Default to rod


def remove_brand_from_title(title):
    """Remove Asian brand name and product dimensions from title"""
    cleaned_title = title

    # Remove "Asian" prefix
    cleaned_title = re.sub(r'^Asian\s+', '', cleaned_title, flags=re.IGNORECASE)

    # Remove size specifications (e.g., "7-8mm", "12mm", "16mm", "25mm")
    cleaned_title = re.sub(r'\b\d+(-\d+)?mm\b', '', cleaned_title)

    # Remove product type terms
    type_patterns = [r'\bRods?\b', r'\bFrit\b', r'\bPowder\b', r'\bSheet\b',
                    r'\bStringers?\b', r'\bTubes?\b', r'\bTubing\b', r'\bFatboy\b',
                    r'\bFlat\b', r'\bProfile\b']

    for pattern in type_patterns:
        cleaned_title = re.sub(pattern, '', cleaned_title, flags=re.IGNORECASE)

    # Remove frit size designations
    cleaned_title = re.sub(r'\(Fine\)', '', cleaned_title, flags=re.IGNORECASE)

    # Remove COE references
    cleaned_title = re.sub(r'\bCOE\s*33\b', '', cleaned_title, flags=re.IGNORECASE)

    # Clean up extra whitespace and dashes
    cleaned_title = re.sub(r'\s*[-–]\s*', ' ', cleaned_title)
    cleaned_title = re.sub(r'\s+', ' ', cleaned_title).strip()

    return cleaned_title


def scrape(test_mode=False, max_items=None):
    """
    Scrape Asian Glass products from ABR Imagery using Shopify API.

    Args:
        test_mode: If True, limit to 2-3 items for testing
        max_items: Maximum items to scrape

    Returns:
        tuple: (products_list, duplicates_list)
    """
    print(f"\n{'='*60}")
    print(f"Scraping {MANUFACTURER_NAME} ({MANUFACTURER_CODE})")
    print(f"{'='*60}")

    collection_handle = 'color-glass'
    all_products = []
    seen_skus = {}
    seen_base_skus = {}  # Track base SKUs to skip size variants
    duplicates = []
    page = 1

    while True:
        print(f"  Fetching page {page}...")

        url = f"{BASE_URL}/collections/{collection_handle}/products.json?page={page}&limit=250"

        try:
            req = urllib.request.Request(url)
            req.add_header('User-Agent', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36')

            with urllib.request.urlopen(req, timeout=15) as response:
                json_content = response.read().decode('utf-8')
                data = json.loads(json_content)

            products = data.get('products', [])
            products_found = len(products)

            print(f"    Found {products_found} products on page {page}")

            if products_found == 0:
                break

            asian_count = 0
            for product_data in products:
                # Only process Asian glass products
                tags = product_data.get('tags', [])
                if 'Asian' not in tags:
                    continue

                asian_count += 1
                product_name = product_data.get('title', '')

                # Skip unwanted products
                skip_terms = ['sample pack', 'sampler', 'bundle', 'set', 'gift card',
                             'sticker', 'shirt', 't-shirt', 'hoodie', 'hat', 'cap',
                             'budget tubes']  # Skip damaged/broken glass bundles
                if any(term in product_name.lower() for term in skip_terms):
                    print(f"    Skipping: {product_name}")
                    continue

                # Get first variant for SKU
                variants = product_data.get('variants', [])
                sku = variants[0].get('sku', '') if variants else ''

                # Skip size variants - keep only base SKU
                # Example: Keep "AR-AMBER", skip "AR-AMBER12", "AR-AMBER25"
                # Pattern: base SKU ends with color name, variants have size suffix (digits)
                base_sku = re.sub(r'\d+$', '', sku)  # Remove trailing digits to get base
                if base_sku in seen_base_skus:
                    # This is a size variant of a product we already have
                    print(f"    Skipping size variant: {product_name} (SKU: {sku}, base: {base_sku})")
                    continue

                # Track this base SKU
                if base_sku:
                    seen_base_skus[base_sku] = {'name': product_name, 'sku': sku}

                # Get images
                images = product_data.get('images', [])
                image_url = images[0].get('src', '') if images else ''

                # Get description
                body_html = product_data.get('body_html', '') or ''
                description = re.sub(r'<[^>]+>', '', body_html)
                description = re.sub(r'\s+', ' ', description).strip()

                # Build product URL
                product_url = f"{BASE_URL}/products/{product_data.get('handle', '')}"

                product = {
                    'name': product_name,
                    'sku': sku,
                    'url': product_url,
                    'product_type': product_data.get('product_type', ''),
                    'tags': tags,
                    'image_url': image_url,
                    'manufacturer_description': description,
                    'manufacturer_url': product_url
                }

                # Check for duplicates by SKU
                if sku and sku in seen_skus:
                    duplicates.append({
                        'sku': sku,
                        'name': product_name,
                        'url': product_url,
                        'original_name': seen_skus[sku]['name'],
                        'original_url': seen_skus[sku]['url']
                    })
                    print(f"    Skipping duplicate SKU: {sku}")
                else:
                    if sku:
                        seen_skus[sku] = {'name': product_name, 'url': product_url}
                    all_products.append(product)

                # Check limits
                if test_mode and len(all_products) >= 3:
                    print(f"  Test mode: reached 3 products")
                    return all_products, duplicates
                if max_items and len(all_products) >= max_items:
                    print(f"  Reached max items limit ({max_items})")
                    return all_products, duplicates

            print(f"    Found {asian_count} Asian glass products on this page")

            # If we got fewer than 250 products, we're on the last page
            if products_found < 250:
                break

            page += 1
            time.sleep(get_page_delay(MANUFACTURER_CODE))

        except urllib.error.HTTPError as e:
            if is_bot_protection_error(e):
                print(f"  ⚠️  Bot protection detected (HTTP {e.code})")
                print(f"  ⚠️  Cannot scrape - site is blocking requests")
                return None, None
            else:
                raise

    print(f"\n  Total Asian glass products scraped: {len(all_products)}")
    if duplicates:
        print(f"  Duplicates skipped: {len(duplicates)}")

    return all_products, duplicates


def format_products_for_csv(products):
    """
    Format products for CSV output.

    Returns list of dicts with standard CSV fields.
    """
    csv_rows = []

    for product in products:
        product_name = product['name']
        cleaned_name = remove_brand_from_title(product_name)
        sku = product.get('sku', '')

        # Determine product type
        product_type = determine_product_type(product_name, product.get('tags', []))

        # Ensure SKU has manufacturer prefix if it exists
        code = sku
        if code and not code.upper().startswith(f"{MANUFACTURER_CODE}-"):
            code = f"{MANUFACTURER_CODE}-{code}"
        elif not code:
            # Generate code from name if no SKU
            code_part = cleaned_name.upper().replace(' ', '-')
            code_part = re.sub(r'[^A-Z0-9-]', '', code_part)
            code = f"{MANUFACTURER_CODE}-{code_part}"

        # Tags handled by tag analysis system
        tags = ''

        row = {
            'manufacturer': MANUFACTURER_CODE,
            'product_type': 'glass',
            'code': code,
            'name': cleaned_name,
            'start_date': '',
            'end_date': '',
            'manufacturer_description': product.get('manufacturer_description', ''),
            'tags': tags,
            'synonyms': '',
            'coe': COE,
            'type': product_type,
            'manufacturer_url': product.get('manufacturer_url', ''),
            'image_url': product.get('image_url', ''),
            'stock_type': ''
        }

        csv_rows.append(row)

    return csv_rows


if __name__ == '__main__':
    # Test the scraper
    products, dupes = scrape(test_mode=True)

    if products is None:
        print("\n❌ Scrape failed due to bot protection")
    else:
        print(f"\nTest results: {len(products)} products")
        if dupes:
            print(f"Duplicates found: {len(dupes)}")

        if products:
            print("\nSample product:")
            sample = format_products_for_csv([products[0]])[0]
            for key, value in sample.items():
                print(f"  {key}: {value}")

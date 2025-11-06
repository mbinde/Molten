#!/usr/bin/env python3
"""
Kugler Colors Scraper
=====================

Scrapes Kugler glass from Hot Glass Color (hotglasscolor.com).
Platform: Shopify

Collections:
- Opaques: https://hotglasscolor.com/collections/opaques
- Transparents: https://hotglasscolor.com/collections/kugler-colors-transparents
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
MANUFACTURER_CODE = 'KUG'
MANUFACTURER_NAME = 'Kugler'
COE = '96'
BASE_URL = 'https://hotglasscolor.com'

# Collections to scrape
COLLECTIONS = [
    'opaques',
    'kugler-colors-transparents',
    'coe-96-colors'  # Frit mixes
]


def determine_product_type(product_name, variant_title, tags):
    """Determine the type of glass product from its name, variant, and tags"""
    combined = f"{product_name} {variant_title}".lower()
    tags_lower = ' '.join(tags).lower() if tags else ''

    if 'powder' in combined or 'powder' in tags_lower:
        return 'powder'
    elif 'frit' in combined or 'frit' in tags_lower:
        return 'frit'
    elif 'bar' in combined or 'bar' in tags_lower:
        return 'bar'
    elif 'rod' in combined or 'rod' in tags_lower:
        return 'rod'
    elif 'tube' in combined or 'tubing' in combined or 'tube' in tags_lower:
        return 'tube'
    elif 'sheet' in combined or 'sheet' in tags_lower:
        return 'sheet'
    else:
        return 'bar'  # Default for Kugler is bar stock


def remove_brand_from_title(title):
    """Remove Kugler code prefix and product type from title"""
    cleaned_title = title

    # Check if this is a frit mix (ends with "Mix" or "mix")
    is_frit_mix = re.search(r'\bmix\b\s*$', cleaned_title, flags=re.IGNORECASE)

    # Remove K-XXX prefix (e.g., "K-061", "K-218")
    cleaned_title = re.sub(r'^K-\d+\s+', '', cleaned_title, flags=re.IGNORECASE)

    # For frit mixes, ensure "Frit Mix" naming (e.g., "Passion Mix" → "Passion Frit Mix")
    if is_frit_mix:
        # Remove any existing "Frit" word before "Mix"
        cleaned_title = re.sub(r'\bFrit\s+Mix\b', 'Mix', cleaned_title, flags=re.IGNORECASE)
        # Now replace "Mix" with "Frit Mix"
        cleaned_title = re.sub(r'\bMix\b\s*$', 'Frit Mix', cleaned_title, flags=re.IGNORECASE)
    else:
        # For non-mix products, remove product type terms
        type_patterns = [r'\bBar\b', r'\bFrit\b', r'\bPowder\b', r'\bSheet\b',
                        r'\bStringers?\b', r'\bTubes?\b', r'\bTubing\b']

        for pattern in type_patterns:
            cleaned_title = re.sub(pattern, '', cleaned_title, flags=re.IGNORECASE)

        # Remove frit size designations (e.g., "Frit 0", "Frit 00", "Frit 000")
        cleaned_title = re.sub(r'\bFrit\s+0+\b', '', cleaned_title, flags=re.IGNORECASE)

    # Remove COE references
    cleaned_title = re.sub(r'\bCOE\s*96\b', '', cleaned_title, flags=re.IGNORECASE)

    # Remove "Also known as" lines
    cleaned_title = re.sub(r'\s*\(?Also known as[^)]*\)?', '', cleaned_title, flags=re.IGNORECASE)

    # Clean up extra whitespace and dashes
    cleaned_title = re.sub(r'\s*[-–]\s*', ' ', cleaned_title)
    cleaned_title = re.sub(r'\s+', ' ', cleaned_title).strip()

    return cleaned_title


def extract_kugler_code(title):
    """Extract the Kugler color code (e.g., K-061) from the title"""
    match = re.search(r'K-(\d+)', title, re.IGNORECASE)
    if match:
        return f"K-{match.group(1)}"
    return None


def scrape(test_mode=False, max_items=None):
    """
    Scrape Kugler Colors from Hot Glass Color using Shopify API.

    Args:
        test_mode: If True, limit to 2-3 items for testing
        max_items: Maximum items to scrape

    Returns:
        tuple: (products_list, duplicates_list)
    """
    print(f"\n{'='*60}")
    print(f"Scraping {MANUFACTURER_NAME} ({MANUFACTURER_CODE})")
    print(f"{'='*60}")

    all_products = []
    seen_skus = {}
    duplicates = []

    for collection_handle in COLLECTIONS:
        print(f"\n  Collection: {collection_handle}")
        page = 1

        while True:
            print(f"    Fetching page {page}...")

            url = f"{BASE_URL}/collections/{collection_handle}/products.json?page={page}&limit=250"

            try:
                req = urllib.request.Request(url)
                req.add_header('User-Agent', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36')

                with urllib.request.urlopen(req, timeout=15) as response:
                    json_content = response.read().decode('utf-8')
                    data = json.loads(json_content)

                products = data.get('products', [])
                products_found = len(products)

                print(f"      Found {products_found} products on page {page}")

                if products_found == 0:
                    break

                for product_data in products:
                    product_name = product_data.get('title', '')
                    tags = product_data.get('tags', [])

                    # Skip non-Kugler products (just in case)
                    # Note: Frit mixes have vendor "Hot Glass Color & Supply" but are Kugler products
                    vendor = product_data.get('vendor', '').lower()
                    if vendor not in ['kugler colors', 'hot glass color & supply']:
                        print(f"      Skipping non-Kugler product: {product_name} (vendor: {vendor})")
                        continue

                    # For coe-96-colors collection, only include products ending with "mix"
                    if collection_handle == 'coe-96-colors':
                        if not re.search(r'\bmix\b\s*$', product_name, flags=re.IGNORECASE):
                            print(f"      Skipping non-mix product from coe-96-colors: {product_name}")
                            continue

                    # Skip unwanted products (use word boundaries to avoid false matches like "sunset")
                    product_name_lower = product_name.lower()
                    skip_patterns = [
                        r'\bsample\s+pack\b', r'\bsampler\b', r'\bbundle\b', r'\bset\b',
                        r'\bgift\s+card\b', r'\bsticker\b', r'\bshirt\b', r'\bt-shirt\b',
                        r'\bhoodie\b', r'\bhat\b', r'\bcap\b'
                    ]
                    should_skip = False
                    for pattern in skip_patterns:
                        if re.search(pattern, product_name_lower):
                            print(f"      Skipping: {product_name}")
                            should_skip = True
                            break
                    if should_skip:
                        continue

                    # Get first variant for SKU (Kugler has multiple variants per product)
                    variants = product_data.get('variants', [])
                    if not variants:
                        continue

                    # Use first variant as primary
                    variant = variants[0]
                    sku = variant.get('sku', '')
                    variant_title = variant.get('title', '')

                    # Get images
                    images = product_data.get('images', [])
                    image_url = images[0].get('src', '') if images else ''

                    # Get description
                    body_html = product_data.get('body_html', '') or ''
                    description = re.sub(r'<[^>]+>', '', body_html)
                    description = re.sub(r'\s+', ' ', description).strip()

                    # Build product URL
                    product_url = f"{BASE_URL}/products/{product_data.get('handle', '')}"

                    # Extract Kugler code
                    kugler_code = extract_kugler_code(product_name)

                    product = {
                        'name': product_name,
                        'sku': sku,
                        'url': product_url,
                        'product_type': product_data.get('product_type', ''),
                        'tags': tags,
                        'image_url': image_url,
                        'manufacturer_description': description,
                        'manufacturer_url': product_url,
                        'kugler_code': kugler_code,
                        'variant_title': variant_title
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
                        print(f"      Skipping duplicate SKU: {sku}")
                    else:
                        if sku:
                            seen_skus[sku] = {'name': product_name, 'url': product_url}
                        all_products.append(product)

                    # Check limits
                    if test_mode and len(all_products) >= 3:
                        print(f"    Test mode: reached 3 products")
                        return all_products, duplicates
                    if max_items and len(all_products) >= max_items:
                        print(f"    Reached max items limit ({max_items})")
                        return all_products, duplicates

                # If we got fewer than 250 products, we're on the last page
                if products_found < 250:
                    break

                page += 1
                time.sleep(get_page_delay(MANUFACTURER_CODE))

            except urllib.error.HTTPError as e:
                if is_bot_protection_error(e):
                    print(f"    ⚠️  Bot protection detected (HTTP {e.code})")
                    print(f"    ⚠️  Cannot scrape - site is blocking requests")
                    return None, None
                else:
                    raise

    print(f"\n  Total Kugler products scraped: {len(all_products)}")
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
        kugler_code = product.get('kugler_code', '')
        variant_title = product.get('variant_title', '')

        # Determine product type
        product_type = determine_product_type(product_name, variant_title, product.get('tags', []))

        # Build code with manufacturer prefix
        # Use SKU as primary (it's unique per variant), fallback to Kugler code or name
        if sku:
            code = f"{MANUFACTURER_CODE}-{sku}"
        elif kugler_code:
            code = f"{MANUFACTURER_CODE}-{kugler_code}"
        else:
            # Generate code from name if no SKU or Kugler code
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
            print("\nSample products:")
            samples = format_products_for_csv(products[:3])
            for i, sample in enumerate(samples, 1):
                print(f"\n  Product {i}:")
                for key, value in sample.items():
                    if value:  # Only show non-empty fields
                        print(f"    {key}: {value}")

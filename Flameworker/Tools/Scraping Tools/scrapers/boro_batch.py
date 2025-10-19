"""
Boro Batch (BB) scraper module.
Scrapes products from store.borobatch.com using Shopify's JSON API.
"""

import urllib.request
import urllib.parse
import re
import time
import json
import hashlib
import sys
import os

# Add parent directory to path for color_extractor import
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from color_extractor import extract_tags_from_name


MANUFACTURER_CODE = 'BB'
MANUFACTURER_NAME = 'Boro Batch'
COE = '33'


def determine_product_type(product_name, product_type_field=None):
    """Determine the type of glass product from its name or product type field"""
    if product_type_field:
        type_lower = product_type_field.lower()
        if 'frit' in type_lower or 'powder' in type_lower:
            return 'frit'
        elif 'rod' in type_lower:
            return 'rod'
        elif 'sheet' in type_lower:
            return 'sheet'
        elif 'stringer' in type_lower:
            return 'stringer'
        elif 'tube' in type_lower or 'tubing' in type_lower:
            return 'tube'
        elif 'thin' in type_lower:
            return 'rod'

    name_lower = product_name.lower()
    if 'frit' in name_lower or 'powder' in name_lower:
        return 'frit'
    elif 'rod' in name_lower or 'rods' in name_lower:
        return 'rod'
    elif 'thin' in name_lower or 'thins' in name_lower:
        return 'rod'
    elif 'sheet' in name_lower:
        return 'sheet'
    elif 'stringer' in name_lower:
        return 'stringer'
    elif 'tube' in name_lower or 'tubing' in name_lower:
        return 'tube'
    else:
        return 'rod'


def remove_brand_from_title(title):
    """Remove Boro Batch brand name, SKU, and product type from product title"""
    cleaned_title = re.sub(r'^BB-\d+[A-Za-z]?\s+', '', title, flags=re.IGNORECASE)
    cleaned_title = re.sub(r'^\d{2,4}[A-Za-z]?\s+[-–]\s+', '', cleaned_title)
    cleaned_title = re.sub(r'^\d{2,4}[A-Za-z]?\s+', '', cleaned_title)

    brand_patterns = ['Boro Batch', 'BB', 'BoroBatch']
    for pattern in brand_patterns:
        cleaned_title = re.sub(f'^{re.escape(pattern)}\\s+', '', cleaned_title, flags=re.IGNORECASE)
        cleaned_title = re.sub(f'\\b{re.escape(pattern)}\\b\\s*', '', cleaned_title, flags=re.IGNORECASE)

    cleaned_title = re.sub(r'\bGlass Rods?\b\s*', '', cleaned_title, flags=re.IGNORECASE)

    type_patterns = [r'\bRods?\b', r'\bFrit\b', r'\bPowder\b', r'\bSheet\b',
                    r'\bStringers?\b', r'\bTubes?\b', r'\bTubing\b', r'\bThins?\b']
    for pattern in type_patterns:
        cleaned_title = re.sub(pattern, '', cleaned_title, flags=re.IGNORECASE)

    cleaned_title = re.sub(r'\bCOE\s*33\b', '', cleaned_title, flags=re.IGNORECASE)
    cleaned_title = re.sub(r'\bCOE\s*104\b', '', cleaned_title, flags=re.IGNORECASE)
    cleaned_title = re.sub(r'\s*[-–]\s*', ' ', cleaned_title)
    cleaned_title = re.sub(r'\s+', ' ', cleaned_title)

    return cleaned_title.strip()


def scrape(test_mode=False, max_items=None):
    """
    Scrape Boro Batch products.

    Args:
        test_mode: If True, limit scraping for testing
        max_items: Maximum number of items to scrape (for testing)

    Returns:
        tuple: (products_list, duplicates_list)
    """
    print(f"\n{'='*60}")
    print(f"Scraping {MANUFACTURER_NAME} ({MANUFACTURER_CODE})")
    print(f"{'='*60}")

    collection_handle = 'color-rods'
    all_products = []
    seen_skus = {}
    duplicates = []
    page = 1

    while True:
        print(f"  Fetching page {page}...")

        url = f"https://store.borobatch.com/collections/{collection_handle}/products.json?page={page}&limit=250"

        try:
            req = urllib.request.Request(url)
            req.add_header('User-Agent', 'Mozilla/5.0')

            with urllib.request.urlopen(req, timeout=15) as response:
                json_content = response.read().decode('utf-8')
                data = json.loads(json_content)

            products = data.get('products', [])
            products_found = len(products)

            print(f"    Found {products_found} products on page {page}")

            if products_found == 0:
                break

            for product_data in products:
                product_name = product_data.get('title', '')

                # Skip unwanted products
                skip_terms = ['bundle', 'bag of bits', 'scrap', 'gift card',
                             'sticker', 'shirt', 't-shirt', 'hoodie', 'hat', 'cap']
                if any(term in product_name.lower() for term in skip_terms) or '+' in product_name:
                    print(f"    Skipping: {product_name}")
                    continue

                product = {
                    'name': product_name,
                    'url': f"/products/{product_data.get('handle', '')}",
                    'product_type': product_data.get('product_type', ''),
                    'vendor': product_data.get('vendor', ''),
                }

                variants = product_data.get('variants', [])
                product['sku'] = variants[0].get('sku', '') if variants else ''

                images = product_data.get('images', [])
                product['image_url'] = images[0].get('src', '') if images else ''

                body_html = product_data.get('body_html', '')
                description = re.sub(r'<[^>]+>', '', body_html)
                description = re.sub(r'\s+', ' ', description).strip()
                product['manufacturer_description'] = description
                product['manufacturer_url'] = f"https://store.borobatch.com{product['url']}"

                # Extract SKU from name if not in variant
                if not product.get('sku'):
                    sku_match = re.search(r'^BB-(\d+[A-Za-z]?)', product_name, re.IGNORECASE)
                    if sku_match:
                        product['sku'] = sku_match.group(1)
                    else:
                        sku_match = re.search(r'^(\d{2,4}[A-Za-z]?)\s+[-–]', product_name)
                        if sku_match:
                            product['sku'] = sku_match.group(1)

                # Generate SKU from hash if still missing
                if not product.get('sku'):
                    cleaned_name = remove_brand_from_title(product_name)
                    name_hash = hashlib.md5(cleaned_name.encode('utf-8')).hexdigest()[:8]
                    product['sku'] = f"BB-{name_hash}"

                # Check for duplicates
                sku = product.get('sku')
                if sku in seen_skus:
                    duplicates.append({
                        'sku': sku,
                        'name': product_name,
                        'url': product['url'],
                        'original_name': seen_skus[sku]['name'],
                        'original_url': seen_skus[sku]['url']
                    })
                    print(f"    Skipping duplicate SKU {sku}")
                else:
                    seen_skus[sku] = {'name': product_name, 'url': product['url']}
                    all_products.append(product)

                if max_items and len(all_products) >= max_items:
                    print(f"  Reached max items limit ({max_items})")
                    return all_products, duplicates

            if products_found < 250:
                break

            page += 1
            time.sleep(1)

        except urllib.error.HTTPError as e:
            if e.code == 404:
                print("  No more pages found (404)")
                break
            else:
                raise Exception(f"HTTP Error {e.code}: {e.reason}")
        except Exception as e:
            raise Exception(f"Error fetching page {page}: {e}")

    print(f"  Total products found: {len(all_products)}")
    return all_products, duplicates


def format_products_for_csv(products):
    """
    Format products into CSV-ready dictionaries.

    Args:
        products: List of product dictionaries

    Returns:
        List of CSV-ready dictionaries
    """
    csv_rows = []

    for product in products:
        product_type = determine_product_type(product['name'], product.get('product_type'))
        cleaned_name = remove_brand_from_title(product['name'])
        code = product.get('sku', '')
        tags = extract_tags_from_name(cleaned_name)

        csv_rows.append({
            'manufacturer': MANUFACTURER_CODE,
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
            'image_path': '',
            'image_url': product.get('image_url', ''),
            'stock_type': ''  # BB doesn't track stock_type
        })

    return csv_rows

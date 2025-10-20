"""
Greasy Glass (GRE) scraper module.
Scrapes products from www.greasycolor.com using Shopify's JSON API.
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
from color_extractor import combine_tags


MANUFACTURER_CODE = 'GRE'
MANUFACTURER_NAME = 'Greasy Glass'
COE = '33'
BASE_URL = 'https://www.greasycolor.com'


def determine_product_type(product_name, product_type_field=None):
    """Determine the type of glass product from its name or product type field"""
    # First check the product_type field if provided
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

    # Fall back to checking name
    name_lower = product_name.lower()

    if 'frit' in name_lower or 'powder' in name_lower:
        return 'frit'
    elif 'rod' in name_lower or 'rods' in name_lower:
        return 'rod'
    elif 'sheet' in name_lower:
        return 'sheet'
    elif 'stringer' in name_lower:
        return 'stringer'
    elif 'tube' in name_lower or 'tubing' in name_lower:
        return 'tube'
    else:
        return 'rod'  # Default to 'rod' for Greasy Glass


def remove_brand_from_title(title):
    """Remove Greasy Glass brand name and product type from product title"""
    if not title:
        return ''

    cleaned_title = title

    # Remove brand patterns
    brand_patterns = ['Greasy Glass Color', 'Greasy Glass', 'Greasy', 'GRE']
    for pattern in brand_patterns:
        cleaned_title = re.sub(f'^{re.escape(pattern)}\\s+', '', cleaned_title, flags=re.IGNORECASE)
        cleaned_title = re.sub(f'\\b{re.escape(pattern)}\\b\\s*', '', cleaned_title, flags=re.IGNORECASE)

    # Remove product type terms
    type_patterns = [r'\bRods?\b', r'\bFrit\b', r'\bPowder\b', r'\bSheet\b',
                    r'\bStringers?\b', r'\bTubes?\b', r'\bTubing\b']
    for pattern in type_patterns:
        cleaned_title = re.sub(pattern, '', cleaned_title, flags=re.IGNORECASE)

    # Remove COE references
    cleaned_title = re.sub(r'\bCOE\s*33\b', '', cleaned_title, flags=re.IGNORECASE)

    # Clean up extra whitespace
    cleaned_title = re.sub(r'\s+', ' ', cleaned_title).strip()

    return cleaned_title


def scrape(test_mode=False, max_items=None):
    """
    Scrape Greasy Glass products.

    Args:
        test_mode: If True, limit scraping for testing
        max_items: Maximum number of items to scrape (for testing)

    Returns:
        tuple: (products_list, duplicates_list)
    """
    print(f"\n{'='*60}")
    print(f"Scraping {MANUFACTURER_NAME} ({MANUFACTURER_CODE})")
    print(f"{'='*60}")

    collection_handle = 'rod'
    all_products = []
    seen_skus = {}
    duplicates = []
    page = 1

    while True:
        print(f"  Fetching page {page}...")

        # Shopify Collections JSON API endpoint
        url = f"{BASE_URL}/collections/{collection_handle}/products.json?page={page}&limit=250"

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
                skip_terms = ['mystery pack', 'shorts', 'grab bag', 'gift card',
                             'sticker', 'shirt', 't-shirt', 'hoodie', 'hat', 'cap']
                if any(term in product_name.lower() for term in skip_terms):
                    print(f"    Skipping: {product_name}")
                    continue

                # Skip products with "+" in the name (bundles)
                if '+' in product_name:
                    print(f"    Skipping bundle: {product_name}")
                    continue

                product = {
                    'name': product_name,
                    'url': f"/products/{product_data.get('handle', '')}",
                    'product_type': product_data.get('product_type', ''),
                    'vendor': product_data.get('vendor', ''),
                }

                # Get SKU from first variant
                variants = product_data.get('variants', [])
                if variants:
                    product['sku'] = variants[0].get('sku', '')
                else:
                    product['sku'] = ''

                # Get image from product data
                images = product_data.get('images', [])
                if images:
                    product['image_url'] = images[0].get('src', '')
                else:
                    product['image_url'] = ''

                # Get description
                body_html = product_data.get('body_html', '')
                description = re.sub(r'<[^>]+>', '', body_html)
                description = re.sub(r'\s+', ' ', description).strip()
                product['manufacturer_description'] = description

                # Ensure manufacturer_url is absolute
                url_path = product['url']
                if url_path.startswith('/'):
                    product['manufacturer_url'] = f"{BASE_URL}{url_path}"
                elif url_path.startswith('http://') or url_path.startswith('https://'):
                    product['manufacturer_url'] = url_path
                else:
                    product['manufacturer_url'] = f"{BASE_URL}/{url_path}"

                # If no SKU, generate one from name hash
                if not product.get('sku'):
                    cleaned_name = remove_brand_from_title(product_name)
                    name_hash = hashlib.md5(cleaned_name.encode('utf-8')).hexdigest()[:8]
                    product['sku'] = f"GRE-{name_hash}"

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

            # Shopify returns less than 250 products if it's the last page
            if products_found < 250:
                print("  Last page reached.")
                break

            page += 1
            time.sleep(0.5)  # Rate limiting (parallel scraping)

        except urllib.error.HTTPError as e:
            if e.code == 404:
                print("  No more pages found (404).")
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

        # Ensure code has manufacturer prefix
        if code and not code.upper().startswith(f"{MANUFACTURER_CODE}-"):
            code = f"{MANUFACTURER_CODE}-{code}"

        description = product.get('manufacturer_description', '')
        manufacturer_url = product.get('manufacturer_url', '')
        tags = combine_tags(cleaned_name, description, manufacturer_url, MANUFACTURER_CODE)

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
            'stock_type': ''  # Greasy doesn't track stock_type in our system
        })

    return csv_rows


def main():
    """Main entry point for standalone testing"""
    test_mode = '--test' in sys.argv or '-test' in sys.argv

    if test_mode:
        print("Running in TEST MODE - will only scrape 3 items")
        print("-" * 60)

    print("Starting scrape of Greasy Glass products...")
    print("=" * 60)

    products, duplicates = scrape(test_mode=test_mode)

    print("\n" + "=" * 60)
    print(f"Total products found: {len(products)}")
    print("=" * 60 + "\n")

    # Print duplicate report
    if duplicates:
        print("\n" + "!" * 60)
        print("DUPLICATE SKUs FOUND (these were skipped):")
        print("!" * 60)
        for dup in duplicates:
            print(f"\nSKU: {dup['sku']}")
            print(f"  Original: {dup['original_name']}")
            print(f"    URL: {dup['original_url']}")
            print(f"  Duplicate: {dup['name']}")
            print(f"    URL: {dup['url']}")
        print("\n" + "!" * 60)
        print(f"Total duplicates skipped: {len(duplicates)}")
        print("!" * 60 + "\n")
    else:
        print("No duplicate SKUs found.\n")

    # Write CSV
    try:
        import csv
        csv_filename = 'greasy_products_test.csv' if test_mode else 'greasy_products.csv'

        csv_rows = format_products_for_csv(products)

        fieldnames = ['manufacturer', 'code', 'name', 'start_date', 'end_date',
                     'manufacturer_description', 'tags', 'synonyms', 'coe', 'type',
                     'manufacturer_url', 'image_path', 'image_url', 'stock_type']

        with open(csv_filename, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(csv_rows)

        print(f"CSV results saved to {csv_filename}")
    except Exception as e:
        print(f"Could not save CSV: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()

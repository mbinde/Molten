"""
Oceanside Glass (OC) scraper module.
Scrapes products from oceansidecompatible.com using Shopify JSON API.
"""

import urllib.request
import urllib.parse
import json
import re
import time
import html
import sys
import os

# Add parent directory to path for color_extractor import
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from color_extractor import combine_tags


MANUFACTURER_CODE = 'OC'
MANUFACTURER_NAME = 'Oceanside Glass'
COE = '96'
BASE_URL = 'https://oceansidecompatible.com'


def clean_html(html_text):
    """Remove HTML tags and decode entities"""
    if not html_text:
        return ''
    # Remove HTML tags
    text = re.sub(r'<[^>]+>', ' ', html_text)
    # Decode HTML entities
    text = html.unescape(text)
    # Clean up whitespace
    text = re.sub(r'\s+', ' ', text).strip()
    return text


def remove_brand_from_title(title):
    """Remove Oceanside brand names and product type from product title"""
    if not title:
        return ''

    cleaned_title = title

    # Remove product line names (Artique®, OpalArt™, Waterglass®, RainWater, etc.)
    product_lines = [
        r'Artique®?', r'OpalArt™?', r'Waterglass®?', r'RainWater',
        r'Smooth', r'Textured', r'Ripple', r'Hammered',
        r'Fusible', r'Compatible'
    ]
    for pattern in product_lines:
        cleaned_title = re.sub(pattern, '', cleaned_title, flags=re.IGNORECASE)

    # Remove brand name
    cleaned_title = re.sub(r'\bOceanside\b', '', cleaned_title, flags=re.IGNORECASE)

    # Remove texture descriptors
    cleaned_title = re.sub(r'\b(Smooth|Textured|Ripple|Hammered)\b', '', cleaned_title, flags=re.IGNORECASE)

    # Clean up extra whitespace
    cleaned_title = re.sub(r'\s+', ' ', cleaned_title).strip()

    return cleaned_title


def determine_product_type(product_name, product_type, tags):
    """Determine the type of glass product from its name and metadata"""
    if not product_name:
        return 'sheet'

    name_lower = product_name.lower()
    type_lower = product_type.lower() if product_type else ''
    tags_lower = ' '.join(tags).lower() if tags else ''

    # Check product name and tags
    if 'frit' in name_lower or 'frit' in tags_lower:
        return 'frit'
    elif 'noodle' in name_lower or 'noodles' in tags_lower:
        return 'stringer'
    elif 'stringer' in name_lower or 'stringers' in tags_lower:
        return 'stringer'
    elif 'rod' in name_lower or 'rods' in tags_lower:
        return 'rod'
    elif 'tube' in name_lower or 'tubing' in tags_lower:
        return 'tube'
    elif 'sheet' in type_lower or 'sheet' in tags_lower:
        return 'sheet'
    else:
        return 'sheet'  # Default to sheet for Oceanside


def scrape_collection(collection_handle='fusible', test_mode=False, max_items=None):
    """
    Scrape products from a Shopify collection using JSON API.

    Args:
        collection_handle: The collection handle (e.g., 'fusible')
        test_mode: If True, limit scraping for testing
        max_items: Maximum items to scrape

    Returns:
        tuple: (products_list, duplicates_list)
    """
    all_products = []
    seen_skus = {}
    duplicates = []

    page = 1
    while True:
        url = f"{BASE_URL}/collections/{collection_handle}/products.json?page={page}&limit=250"

        print(f"  Fetching page {page}...")

        try:
            req = urllib.request.Request(url)
            req.add_header('User-Agent', 'Mozilla/5.0')

            with urllib.request.urlopen(req, timeout=15) as response:
                data = json.loads(response.read().decode('utf-8'))

            products = data.get('products', [])

            if not products:
                print(f"    No more products found on page {page}")
                break

            print(f"    Found {len(products)} products on page {page}")

            for product in products:
                product_name = product.get('title', '')
                product_type = product.get('product_type', '')
                product_tags = product.get('tags', [])
                handle = product.get('handle', '')

                # Skip non-fusible products
                if 'fusible' not in product_name.lower() and 'fusible' not in ' '.join(product_tags).lower():
                    print(f"    Skipping non-fusible: {product_name}")
                    continue

                # Skip certain product types
                skip_terms = ['tool', 'kit', 'supplies', 'adhesive', 'cleaner', 'polish']
                if any(term in product_name.lower() for term in skip_terms):
                    print(f"    Skipping: {product_name}")
                    continue

                # Get SKU from first variant
                variants = product.get('variants', [])
                sku = ''
                if variants:
                    sku = variants[0].get('sku', '')

                # If no SKU, generate one from handle
                if not sku:
                    sku = f"OC-{handle}"

                # Get description from body_html
                body_html = product.get('body_html', '')
                description = clean_html(body_html)

                # Get image URL
                image_url = ''
                images = product.get('images', [])
                if images:
                    image_url = images[0].get('src', '')

                # Build product URL
                product_url = f"/collections/{collection_handle}/products/{handle}"

                product_data = {
                    'name': product_name,
                    'sku': sku,
                    'url': product_url,
                    'manufacturer_url': f"{BASE_URL}{product_url}",
                    'manufacturer_description': description,
                    'image_url': image_url,
                    'product_type': determine_product_type(product_name, product_type, product_tags)
                }

                # Check for duplicates
                if sku in seen_skus:
                    duplicates.append({
                        'sku': sku,
                        'name': product_data['name'],
                        'url': product_data['url'],
                        'original_name': seen_skus[sku]['name'],
                        'original_url': seen_skus[sku]['url']
                    })
                    print(f"    Skipping duplicate SKU {sku}")
                else:
                    seen_skus[sku] = {'name': product_data['name'], 'url': product_data['url']}
                    all_products.append(product_data)

                if max_items and len(all_products) >= max_items:
                    print(f"  Reached max items limit ({max_items})")
                    return all_products, duplicates

                if test_mode and len(all_products) >= 3:
                    print("  Test mode: stopping after 3 products")
                    return all_products, duplicates

            # Check if we should continue to next page
            if len(products) < 250:
                # Last page
                break

            page += 1
            time.sleep(0.5)  # Rate limiting (parallel scraping)

        except Exception as e:
            print(f"  Error fetching page {page}: {e}")
            break

    return all_products, duplicates


def scrape(test_mode=False, max_items=None):
    """
    Scrape Oceanside Glass products.

    Args:
        test_mode: If True, limit scraping for testing
        max_items: Maximum number of items to scrape (for testing)

    Returns:
        tuple: (products_list, duplicates_list)
    """
    print(f"\n{'='*60}")
    print(f"Scraping {MANUFACTURER_NAME} ({MANUFACTURER_CODE})")
    print(f"{'='*60}")

    # Scrape the fusible collection
    products, duplicates = scrape_collection(
        collection_handle='fusible',
        test_mode=test_mode,
        max_items=max_items
    )

    print(f"  Total products found: {len(products)}")
    return products, duplicates


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
        product_type = product.get('product_type', 'sheet')
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
            'stock_type': ''  # Oceanside doesn't track stock_type
        })

    return csv_rows


def main():
    """Main entry point for standalone testing"""
    test_mode = '--test' in sys.argv or '-test' in sys.argv

    if test_mode:
        print("Running in TEST MODE - will only scrape 3 items")
        print("-" * 60)

    print(f"Starting scrape of {MANUFACTURER_NAME} products...")
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
        csv_filename = 'oceanside_products_test.csv' if test_mode else 'oceanside_products.csv'

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

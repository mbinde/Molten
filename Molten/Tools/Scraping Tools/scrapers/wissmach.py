"""
Wissmach Glass (WM) scraper module.
Scrapes COE 96 products from wissmachglass.com using WordPress REST API.
"""

import urllib.request
import urllib.error
import urllib.parse
import json
import re
import time
import html
import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from color_extractor import combine_tags
from scraper_config import get_page_delay, get_product_delay, is_bot_protection_error


MANUFACTURER_CODE = 'WM'
MANUFACTURER_NAME = 'Wissmach Glass'
COE = '96'
BASE_URL = 'https://wissmachglass.com'


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


def extract_color_name(content_html):
    """Extract color name from content HTML"""
    if not content_html:
        return ''

    # Clean HTML first
    text = clean_html(content_html)

    # The color name is usually the first line of content
    # Look for patterns like "Green Tea Tr" or "Crystal"
    lines = [line.strip() for line in text.split('\n') if line.strip()]

    if lines:
        # First non-empty line is usually the color name
        color_name = lines[0]
        # Remove common suffixes/notes
        color_name = re.sub(r'\s+(Tr|Op|Tested compatible).*$', '', color_name, flags=re.IGNORECASE)
        return color_name.strip()

    return ''


def determine_product_type(categories):
    """Determine product type from category names"""
    if not categories:
        return 'sheet'

    categories_lower = [cat.lower() for cat in categories]

    if 'frit' in ' '.join(categories_lower):
        return 'frit'
    elif 'cullet' in ' '.join(categories_lower):
        return 'other'
    else:
        return 'sheet'  # Default to sheet for Wissmach


def get_category_names(product, taxonomies):
    """Get category names from taxonomy IDs"""
    category_ids = product.get('ept_coe-96_category', [])
    categories = []

    for cat_id in category_ids:
        if cat_id in taxonomies:
            categories.append(taxonomies[cat_id])

    return categories


def fetch_taxonomies():
    """Fetch taxonomy terms (categories and color families)"""
    taxonomies = {}

    # Fetch categories
    try:
        url = f"{BASE_URL}/wp-json/wp/v2/ept_coe-96_category?per_page=100"
        req = urllib.request.Request(url)
        req.add_header('User-Agent', 'Mozilla/5.0')

        with urllib.request.urlopen(req, timeout=15) as response:
            categories = json.loads(response.read().decode('utf-8'))
            for cat in categories:
                taxonomies[cat['id']] = cat['name']
    except Exception as e:
        print(f"  Warning: Could not fetch categories: {e}")

    return taxonomies


def scrape_products(test_mode=False, max_items=None):
    """
    Scrape products from WordPress REST API.

    Args:
        test_mode: If True, limit scraping for testing
        max_items: Maximum items to scrape

    Returns:
        tuple: (products_list, duplicates_list)
    """
    all_products = []
    seen_skus = {}
    duplicates = []

    # Fetch taxonomies first
    print("  Fetching taxonomies...")
    taxonomies = fetch_taxonomies()

    page = 1
    per_page = 100

    while True:
        url = f"{BASE_URL}/wp-json/wp/v2/ept_coe-96?per_page={per_page}&page={page}"

        print(f"  Fetching page {page}...")

        try:
            req = urllib.request.Request(url)
            req.add_header('User-Agent', 'Mozilla/5.0')

            with urllib.request.urlopen(req, timeout=15) as response:
                products = json.loads(response.read().decode('utf-8'))

                if not products:
                    print(f"    No more products on page {page}")
                    break

                print(f"    Found {len(products)} products on page {page}")

                for product in products:
                    # Get product code (SKU) from title
                    code = product['title']['rendered']

                    # Get color name from content
                    content_html = product['content']['rendered']
                    color_name = extract_color_name(content_html)

                    # If no color name found, use the code
                    if not color_name:
                        color_name = code

                    # Get categories
                    categories = get_category_names(product, taxonomies)

                    # Get featured image
                    image_url = ''
                    if product.get('featured_media'):
                        # We'll try to get the image URL from the _links
                        try:
                            media_link = product['_links']['wp:featuredmedia'][0]['href']
                            media_req = urllib.request.Request(media_link)
                            media_req.add_header('User-Agent', 'Mozilla/5.0')

                            with urllib.request.urlopen(media_req, timeout=10) as media_response:
                                media_data = json.loads(media_response.read().decode('utf-8'))
                                image_url = media_data.get('source_url', '')
                        except Exception as e:
                            print(f"    Warning: Could not fetch image for {code}: {e}")

                    # Build product URL
                    product_url = product.get('link', '')
                    if product_url.startswith(BASE_URL):
                        product_url = product_url[len(BASE_URL):]

                    # Create product data
                    product_data = {
                        'name': f"{code} - {color_name}",
                        'sku': code,
                        'url': product_url,
                        'manufacturer_url': product.get('link', ''),
                        'manufacturer_description': clean_html(content_html),
                        'image_url': image_url,
                        'product_type': determine_product_type(categories),
                        'categories': categories
                    }

                    # Check for duplicates
                    if code in seen_skus:
                        duplicates.append({
                            'sku': code,
                            'name': product_data['name'],
                            'url': product_data['url'],
                            'original_name': seen_skus[code]['name'],
                            'original_url': seen_skus[code]['url']
                        })
                        print(f"    Skipping duplicate SKU {code}")
                    else:
                        seen_skus[code] = {'name': product_data['name'], 'url': product_data['url']}
                        all_products.append(product_data)

                    if max_items and len(all_products) >= max_items:
                        print(f"  Reached max items limit ({max_items})")
                        return all_products, duplicates

                    if test_mode and len(all_products) >= 3:
                        print("  Test mode: stopping after 3 products")
                        return all_products, duplicates

                # Check if there are more pages
                if len(products) < per_page:
                    # Last page
                    break

                page += 1
                time.sleep(get_page_delay(MANUFACTURER_CODE))

        except Exception as e:
            print(f"  Error fetching page {page}: {e}")
            break

    return all_products, duplicates


def scrape(test_mode=False, max_items=None):
    """
    Scrape Wissmach Glass products.

    Args:
        test_mode: If True, limit scraping for testing
        max_items: Maximum number of items to scrape (for testing)

    Returns:
        tuple: (products_list, duplicates_list)
    """
    print(f"\n{'='*60}")
    print(f"Scraping {MANUFACTURER_NAME} ({MANUFACTURER_CODE})")
    print(f"{'='*60}")

    products, duplicates = scrape_products(
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
        code = product.get('sku', '')

        # Ensure code has manufacturer prefix
        if code and not code.upper().startswith(f"{MANUFACTURER_CODE}-"):
            code = f"{MANUFACTURER_CODE}-{code}"

        # Extract just the color name (remove the code prefix)
        full_name = product['name']
        if ' - ' in full_name:
            color_name = full_name.split(' - ', 1)[1]
        else:
            color_name = full_name

        description = product.get('manufacturer_description', '')
        manufacturer_url = product.get('manufacturer_url', '')
        tags = combine_tags(color_name, description, manufacturer_url, MANUFACTURER_CODE)

        csv_rows.append({
            'manufacturer': MANUFACTURER_CODE,
            'code': code,
            'name': color_name,
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
            'stock_type': ''  # Wissmach doesn't track stock_type
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
        csv_filename = 'wissmach_products_test.csv' if test_mode else 'wissmach_products.csv'

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

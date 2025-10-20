"""
Youghiogheny Glass (Y96) scraper module.
Scrapes COE 96 fusible sheet glass from youghioghenyglass.com.
"""

import urllib.request
import urllib.error
import urllib.parse
import re
import time
import html.parser
import sys
import os

# Add parent directory to path for color_extractor import
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from color_extractor import combine_tags
from scraper_config import is_bot_protection_error


MANUFACTURER_CODE = 'Y96'
MANUFACTURER_NAME = 'Youghiogheny Glass'
COE = '96'
BASE_URL = 'https://www.youghioghenyglass.com'
CATEGORY_URL = f'{BASE_URL}/y96.html'


class ProductParser(html.parser.HTMLParser):
    """Parser to extract product information from image alt tags"""
    def __init__(self):
        super().__init__()
        self.products = []
        self.seen_codes = set()

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)

        # Extract product info from image alt tags
        if tag == 'img' and 'alt' in attrs_dict:
            alt_text = attrs_dict['alt'].strip()
            src = attrs_dict.get('src', '')

            # Look for Y96 product codes in alt text (e.g., "Y96-202 ROOT BEER" or "U-60-7312-96 LIME")
            if alt_text and ('Y96-' in alt_text.upper() or 'U-' in alt_text.upper() and '-96' in alt_text):
                # Parse the alt text to extract code and name
                # Format examples:
                # "Y96-202 ROOT BEER"
                # "U-60-7312-96 LIME"

                # Try to split on the first space after the code
                match = re.match(r'([A-Z0-9-]+)\s+(.*)', alt_text, re.IGNORECASE)
                if match:
                    code = match.group(1).strip().upper()
                    name = match.group(2).strip().title()

                    # Skip duplicates
                    if code not in self.seen_codes:
                        self.seen_codes.add(code)

                        # Build full image URL
                        image_url = ''
                        if src:
                            if src.startswith('http'):
                                image_url = src
                            else:
                                # Remove leading slash if present
                                src_clean = src.lstrip('/')
                                image_url = f"{BASE_URL}/{src_clean}"

                        self.products.append({
                            'code': code,
                            'name': name,
                            'image_url': image_url
                        })


def scrape_category_page():
    """
    Scrape the Y96 category page.

    Returns:
        list: List of product dictionaries, or None if bot protection detected
    """
    try:
        req = urllib.request.Request(CATEGORY_URL)
        req.add_header('User-Agent', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')
        req.add_header('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8')
        req.add_header('Accept-Language', 'en-US,en;q=0.5')

        with urllib.request.urlopen(req, timeout=15) as response:
            html_content = response.read().decode('utf-8')

        parser = ProductParser()
        parser.feed(html_content)

        return parser.products

    except urllib.error.HTTPError as e:
        if is_bot_protection_error(e):
            print(f"  ⚠️  Bot protection detected (HTTP {e.code})")
            print(f"  ⚠️  Cannot scrape - site is blocking requests")
            return None
        else:
            print(f"  HTTP Error scraping category page: {e}")
            import traceback
            traceback.print_exc()
            return []
    except Exception as e:
        print(f"  Error scraping category page: {e}")
        import traceback
        traceback.print_exc()
        return []


def remove_brand_from_title(title):
    """Remove Youghiogheny brand name from product title"""
    if not title:
        return ''

    cleaned_title = title

    # Remove brand patterns
    brand_patterns = ['Youghiogheny Glass', 'Youghiogheny', 'Y96']
    for pattern in brand_patterns:
        cleaned_title = re.sub(f'^{re.escape(pattern)}\\s+', '', cleaned_title, flags=re.IGNORECASE)
        cleaned_title = re.sub(f'\\b{re.escape(pattern)}\\b\\s*', '', cleaned_title, flags=re.IGNORECASE)

    # Remove product type terms
    type_patterns = [r'\bSheet\b', r'\bFusible\b', r'\bFusing\b', r'\bGlass\b']
    for pattern in type_patterns:
        cleaned_title = re.sub(pattern, '', cleaned_title, flags=re.IGNORECASE)

    # Remove COE references
    cleaned_title = re.sub(r'\bCOE\s*96\b', '', cleaned_title, flags=re.IGNORECASE)

    # Clean up extra whitespace
    cleaned_title = re.sub(r'\s+', ' ', cleaned_title).strip()

    return cleaned_title


def scrape(test_mode=False, max_items=None):
    """
    Scrape Youghiogheny Glass products.

    Args:
        test_mode: If True, limit scraping for testing
        max_items: Maximum number of items to scrape (for testing)

    Returns:
        tuple: (products_list, duplicates_list)
    """
    print(f"\n{'='*60}")
    print(f"Scraping {MANUFACTURER_NAME} ({MANUFACTURER_CODE})")
    print(f"{'='*60}")

    print(f"  Fetching products from {CATEGORY_URL}")

    products_data = scrape_category_page()

    # If bot protection detected, stop scraping
    if products_data is None:
        print(f"  Stopping scrape due to bot protection")
        return [], []

    if not products_data:
        print("  No products found")
        return [], []

    print(f"  Found {len(products_data)} products on page")

    all_products = []
    seen_skus = {}
    duplicates = []

    for i, product_data in enumerate(products_data):
        if max_items and len(all_products) >= max_items:
            print(f"  Reached max items limit ({max_items})")
            break

        if test_mode and len(all_products) >= 3:
            print("  Test mode: stopping after 3 products")
            break

        code = product_data['code']

        product = {
            'name': product_data['name'],
            'sku': code,
            'url': CATEGORY_URL,
            'manufacturer_url': CATEGORY_URL,
            'manufacturer_description': '',
            'image_url': product_data.get('image_url', ''),
            'price': '',
            'product_type': 'sheet'  # All Y96 products are sheet glass
        }

        # Check for duplicates
        if code in seen_skus:
            duplicates.append({
                'sku': code,
                'name': product['name'],
                'url': product['url'],
                'original_name': seen_skus[code]['name'],
                'original_url': seen_skus[code]['url']
            })
            print(f"    Skipping duplicate SKU {code}")
        else:
            seen_skus[code] = {'name': product['name'], 'url': product['url']}
            all_products.append(product)

    print(f"  Total products scraped: {len(all_products)}")
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
        product_type = product.get('product_type', 'sheet')
        code = product.get('sku', '')

        # Ensure code has manufacturer prefix if it doesn't already
        # Y96 codes already start with Y96- or U- prefix, so check if it needs the manufacturer code
        if code and not code.upper().startswith(f"{MANUFACTURER_CODE}-"):
            # If code starts with Y96-, use as-is. Otherwise, add manufacturer prefix
            if not code.upper().startswith('Y96-'):
                code = f"{MANUFACTURER_CODE}-{code}"

        cleaned_name = remove_brand_from_title(product['name'])
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
            'stock_type': ''
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
        csv_filename = 'youghiogheny_products_test.csv' if test_mode else 'youghiogheny_products.csv'

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

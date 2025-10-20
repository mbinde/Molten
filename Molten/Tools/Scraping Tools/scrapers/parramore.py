"""
Parramore Glass (PAR) scraper module.
Scrapes COE 33 borosilicate rods from artistryinglass.on.ca.
"""

import urllib.request
import urllib.parse
import re
import time
import html.parser
import sys
import os
import hashlib

# Add parent directory to path for color_extractor import
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from color_extractor import combine_tags


MANUFACTURER_CODE = 'PAR'
MANUFACTURER_NAME = 'Parramore Glass'
COE = '33'
BASE_URL = 'https://artistryinglass.on.ca'
CATEGORY_URL = f'{BASE_URL}/BEADMAKING-and-FLAMEWORKING/PARRAMORE-GLASS/'


class ProductListParser(html.parser.HTMLParser):
    """Parser to extract product information from the category page"""
    def __init__(self):
        super().__init__()
        self.products = []
        self.in_product_item = False
        self.in_product_title = False
        self.in_price = False
        self.current_product = {}
        self.current_text = []

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)

        # Detect product container
        if tag == 'div' and 'class' in attrs_dict:
            classes = attrs_dict.get('class', '')
            if 'product-cell' in classes or 'product-item' in classes:
                self.in_product_item = True
                self.current_product = {}

        # Extract product image
        if self.in_product_item and tag == 'img' and 'src' in attrs_dict:
            src = attrs_dict['src']
            if '/var/images/' in src:
                self.current_product['image_url'] = BASE_URL + src if not src.startswith('http') else src

        # Extract product title/name
        if self.in_product_item and tag in ['h4', 'h3', 'a']:
            # Check if this is a product title link
            if tag == 'a' and 'href' in attrs_dict:
                href = attrs_dict['href']
                if '/BEADMAKING-and-FLAMEWORKING/PARRAMORE-GLASS/' in href:
                    self.in_product_title = True
                    self.current_text = []
                    self.current_product['url'] = BASE_URL + href if not href.startswith('http') else href
            elif tag in ['h4', 'h3']:
                self.in_product_title = True
                self.current_text = []

        # Extract price
        if self.in_product_item and tag == 'span' and 'class' in attrs_dict:
            classes = attrs_dict.get('class', '')
            if 'price' in classes.lower():
                self.in_price = True
                self.current_text = []

    def handle_data(self, data):
        text = data.strip()
        if text:
            if self.in_product_title or self.in_price:
                self.current_text.append(text)

    def handle_endtag(self, tag):
        if tag in ['h4', 'h3', 'a'] and self.in_product_title:
            name = ' '.join(self.current_text).strip()
            if name and 'PARRAMORE' in name.upper():
                self.current_product['name'] = name
            self.in_product_title = False

        if tag == 'span' and self.in_price:
            price = ' '.join(self.current_text).strip()
            if price:
                self.current_product['price'] = price
            self.in_price = False

        if tag == 'div' and self.in_product_item:
            # End of product item - save if we have a name
            if 'name' in self.current_product:
                self.products.append(self.current_product.copy())
            self.in_product_item = False
            self.current_product = {}


def scrape_category_page():
    """
    Scrape the Parramore Glass category page.

    Uses regex extraction since X-Cart loads content dynamically via JavaScript.

    Returns:
        list of product dictionaries
    """
    try:
        req = urllib.request.Request(CATEGORY_URL)
        req.add_header('User-Agent', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')
        req.add_header('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8')
        req.add_header('Accept-Language', 'en-US,en;q=0.5')

        with urllib.request.urlopen(req, timeout=15) as response:
            html_content = response.read().decode('utf-8')

        # X-Cart uses JavaScript to render products, so we use regex to extract
        # product names directly from the HTML
        products = []
        seen_names = set()

        # Find all product names that match the pattern "[COLOR] RODS by PARRAMORE GLASS"
        pattern = r'([A-Z][a-zA-Z\s]+)\s+RODS\s+by\s+PARRAMORE\s+GLASS'
        matches = re.findall(pattern, html_content)

        # Also extract image URLs
        # Pattern: <img ... src="//artistryinglass.on.ca/var/images/product/.../xyz.jpg" alt="[COLOR] RODS by PARRAMORE GLASS"
        image_pattern = r'<img[^>]+src="([^"]+)"[^>]+alt="([^"]+RODS by PARRAMORE GLASS[^"]*)"'
        image_matches = re.findall(image_pattern, html_content, re.IGNORECASE)

        # Create a mapping of product names to image URLs
        image_map = {}
        for img_url, alt_text in image_matches:
            # Fix protocol-relative URLs
            if img_url.startswith('//'):
                img_url = 'https:' + img_url
            image_map[alt_text.strip()] = img_url

        for color_name in matches:
            full_name = f"{color_name.strip()} RODS by PARRAMORE GLASS"
            if full_name not in seen_names:
                seen_names.add(full_name)
                # Look up image URL for this product
                image_url = image_map.get(full_name, '')
                products.append({
                    'name': full_name,
                    'price': 'CA$90',  # All products are $90
                    'url': CATEGORY_URL,
                    'image_url': image_url
                })

        return products

    except Exception as e:
        print(f"  Error scraping category page: {e}")
        import traceback
        traceback.print_exc()
        return []


def remove_brand_from_title(title):
    """Remove Parramore Glass brand name and product type from product title"""
    if not title:
        return ''

    cleaned_title = title

    # Remove brand patterns
    brand_patterns = ['Parramore Glass', 'Parramore', 'by PARRAMORE GLASS', 'by Parramore Glass']
    for pattern in brand_patterns:
        cleaned_title = re.sub(f'{re.escape(pattern)}', '', cleaned_title, flags=re.IGNORECASE)

    # Remove "RODS" and "ROD"
    cleaned_title = re.sub(r'\bRODS?\b', '', cleaned_title, flags=re.IGNORECASE)

    # Remove standalone "by" (left over from brand removal)
    cleaned_title = re.sub(r'\bby\b', '', cleaned_title, flags=re.IGNORECASE)

    # Remove COE references
    cleaned_title = re.sub(r'\bCOE\s*33\b', '', cleaned_title, flags=re.IGNORECASE)

    # Clean up extra whitespace and punctuation
    cleaned_title = re.sub(r'\s+', ' ', cleaned_title).strip()
    cleaned_title = cleaned_title.strip('-').strip()

    return cleaned_title


def scrape(test_mode=False, max_items=None):
    """
    Scrape Parramore Glass products.

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

        # Generate SKU from product name hash (they don't have SKUs)
        cleaned_name = remove_brand_from_title(product_data['name'])
        name_hash = hashlib.md5(cleaned_name.encode('utf-8')).hexdigest()[:8]
        sku = f"{name_hash}"

        product = {
            'name': product_data['name'],
            'sku': sku,
            'url': product_data.get('url', CATEGORY_URL),
            'manufacturer_url': product_data.get('url', CATEGORY_URL),
            'manufacturer_description': '',
            'image_url': product_data.get('image_url', ''),
            'price': product_data.get('price', ''),
            'product_type': 'rod'  # All Parramore products are rods
        }

        # Check for duplicates
        if sku in seen_skus:
            duplicates.append({
                'sku': sku,
                'name': product['name'],
                'url': product['url'],
                'original_name': seen_skus[sku]['name'],
                'original_url': seen_skus[sku]['url']
            })
            print(f"    Skipping duplicate SKU {sku}")
        else:
            seen_skus[sku] = {'name': product['name'], 'url': product['url']}
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
        product_type = product.get('product_type', 'rod')
        code = product.get('sku', '')

        # Ensure code has manufacturer prefix
        if code and not code.upper().startswith(f"{MANUFACTURER_CODE}-"):
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
        csv_filename = 'parramore_products_test.csv' if test_mode else 'parramore_products.csv'

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

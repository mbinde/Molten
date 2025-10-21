"""
Molten Aura Glass (MA) scraper module.
Scrapes COE 33 borosilicate products from moltenaura.glass.
"""

import urllib.request
import urllib.error
import urllib.parse
import re
import time
import html.parser
import sys
import os
import hashlib

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from color_extractor import combine_tags
from scraper_config import get_page_delay, get_product_delay, is_bot_protection_error


MANUFACTURER_CODE = 'MA'
MANUFACTURER_NAME = 'Molten Aura Labs'
COE = '33'
BASE_URL = 'https://moltenaura.glass'


class ProductListParser(html.parser.HTMLParser):
    """Parser to extract product links from the main glass page"""
    def __init__(self):
        super().__init__()
        self.product_links = []
        self.in_product_link = False
        self.current_link = None

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)

        # Look for product links (WooCommerce product links)
        if tag == 'a' and 'href' in attrs_dict:
            href = attrs_dict['href']
            # Product URLs contain /product/
            if '/product/' in href and href not in self.product_links:
                self.product_links.append(href)


class ProductPageParser(html.parser.HTMLParser):
    """Parser to extract product details from individual product pages"""
    def __init__(self):
        super().__init__()
        self.product_name = None
        self.description = None
        self.image_url = None
        self.in_product_title = False
        self.in_description = False
        self.current_text = []

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)

        # Extract product name from h1 with product_title class
        if tag == 'h1' and 'class' in attrs_dict:
            if 'product_title' in attrs_dict['class'] or 'entry-title' in attrs_dict['class']:
                self.in_product_title = True
                self.current_text = []

        # Extract main product image - look for WooCommerce product gallery images
        if tag == 'img' and 'src' in attrs_dict and not self.image_url:
            src = attrs_dict['src']
            img_class = attrs_dict.get('class', '')

            # Prioritize images with product gallery classes
            is_product_image = any(c in img_class for c in ['woocommerce-product-gallery', 'wp-post-image', 'attachment'])

            # Skip navigation/logo images
            if 'horiz-logo' in src or 'submenu-' in src:
                return

            # Look for product images in uploads folder
            if 'wp-content/uploads' in src:
                # Prefer product gallery images
                if is_product_image:
                    self.image_url = src
                # Otherwise, skip dimension-based thumbnails but accept _thumb images
                elif not re.search(r'-\d{2,3}x\d{2,3}', src) and not self.image_url:
                    self.image_url = src

        # Extract description from woocommerce-product-details__short-description or similar
        if tag == 'div' and 'class' in attrs_dict:
            classes = attrs_dict.get('class', '')
            if 'short-description' in classes or 'product-description' in classes:
                self.in_description = True
                self.current_text = []

    def handle_data(self, data):
        text = data.strip()
        if text:
            if self.in_product_title or self.in_description:
                self.current_text.append(text)

    def handle_endtag(self, tag):
        if tag == 'h1' and self.in_product_title:
            self.product_name = ' '.join(self.current_text).strip()
            self.in_product_title = False

        if tag == 'div' and self.in_description:
            self.description = ' '.join(self.current_text).strip()
            self.in_description = False


def scrape_product_page(product_url):
    """
    Scrape a single product page for details.

    Returns:
        dict with 'name', 'description', 'image_url', 'url'
    """
    try:
        req = urllib.request.Request(product_url)
        req.add_header('User-Agent', 'Mozilla/5.0')

        with urllib.request.urlopen(req, timeout=15) as response:
            html_content = response.read().decode('utf-8')

        parser = ProductPageParser()
        parser.feed(html_content)

        # Extract product name from URL if parser didn't find it
        if not parser.product_name:
            # URL format: https://moltenaura.glass/product/moonstone/
            product_slug = product_url.rstrip('/').split('/')[-1]
            parser.product_name = product_slug.replace('-', ' ').title()

        return {
            'name': parser.product_name,
            'description': parser.description or '',
            'image_url': parser.image_url or '',
            'url': product_url
        }

    except Exception as e:
        print(f"  Error scraping {product_url}: {e}")
        return None


def remove_brand_from_title(title):
    """Remove Molten Aura brand name and product type from product title"""
    if not title:
        return ''

    cleaned_title = title

    # Remove brand patterns
    brand_patterns = ['Molten Aura', 'Molten', 'MA']
    for pattern in brand_patterns:
        cleaned_title = re.sub(f'^{re.escape(pattern)}\\s+', '', cleaned_title, flags=re.IGNORECASE)
        cleaned_title = re.sub(f'\\b{re.escape(pattern)}\\b\\s*', '', cleaned_title, flags=re.IGNORECASE)

    # Remove product line suffixes (AuraTone, GemTone, etc.)
    line_patterns = [r'\bAuraTone[s™]*\b', r'\bGemTone[s™]*\b', r'\bOpalTone[s™]*\b',
                     r'\bEffecTone[s™]*\b', r'\bSANDCRAFTED[®]*\b']
    for pattern in line_patterns:
        cleaned_title = re.sub(pattern, '', cleaned_title, flags=re.IGNORECASE)

    # Remove product type terms
    type_patterns = [r'\bRods?\b', r'\bFrit\b', r'\bPowder\b', r'\bTubes?\b', r'\bTubing\b']
    for pattern in type_patterns:
        cleaned_title = re.sub(pattern, '', cleaned_title, flags=re.IGNORECASE)

    # Remove COE references
    cleaned_title = re.sub(r'\bCOE\s*33\b', '', cleaned_title, flags=re.IGNORECASE)
    cleaned_title = re.sub(r'\b33\s*CTE\b', '', cleaned_title, flags=re.IGNORECASE)

    # Clean up extra whitespace
    cleaned_title = re.sub(r'\s+', ' ', cleaned_title).strip()

    return cleaned_title


def scrape(test_mode=False, max_items=None):
    """
    Scrape Molten Aura Labs products.

    Args:
        test_mode: If True, limit scraping for testing
        max_items: Maximum number of items to scrape (for testing)

    Returns:
        tuple: (products_list, duplicates_list)
    """
    print(f"\n{'='*60}")
    print(f"Scraping {MANUFACTURER_NAME} ({MANUFACTURER_CODE})")
    print(f"{'='*60}")

    # Step 1: Get product links from main glass page
    print(f"  Fetching product list from {BASE_URL}/glass")

    try:
        req = urllib.request.Request(f"{BASE_URL}/glass")
        req.add_header('User-Agent', 'Mozilla/5.0')

        with urllib.request.urlopen(req, timeout=15) as response:
            html_content = response.read().decode('utf-8')

        parser = ProductListParser()
        parser.feed(html_content)

        product_urls = parser.product_links
        print(f"  Found {len(product_urls)} product links")

    except Exception as e:
        print(f"  Error fetching product list: {e}")
        return [], []

    # Step 2: Scrape each product page
    all_products = []
    seen_skus = {}
    duplicates = []

    for i, url in enumerate(product_urls):
        if max_items and len(all_products) >= max_items:
            print(f"  Reached max items limit ({max_items})")
            break

        if test_mode and len(all_products) >= 3:
            print("  Test mode: stopping after 3 products")
            break

        print(f"  [{i+1}/{len(product_urls)}] Scraping {url}")

        product_data = scrape_product_page(url)

        if not product_data:
            continue

        # Generate SKU from product name hash (they don't have SKUs)
        cleaned_name = remove_brand_from_title(product_data['name'])
        name_hash = hashlib.md5(cleaned_name.encode('utf-8')).hexdigest()[:8]
        sku = f"{name_hash}"

        product = {
            'name': product_data['name'],
            'sku': sku,
            'url': url.replace(BASE_URL, ''),  # Relative URL
            'manufacturer_url': url,
            'manufacturer_description': product_data['description'],
            'image_url': product_data['image_url'],
            'product_type': 'rod'  # All Molten Aura products are rods
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

        # Small delay to be polite
        time.sleep(get_page_delay(MANUFACTURER_CODE))

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
        csv_filename = 'molten_aura_products_test.csv' if test_mode else 'molten_aura_products.csv'

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

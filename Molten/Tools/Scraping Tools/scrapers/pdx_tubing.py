"""
PDX Tubing Co (PDX) scraper module.
Scrapes COE 33 borosilicate tubing products from pdxtubingco.com.
"""

import urllib.request
import urllib.parse
import re
import time
import html.parser
import sys
import os

# Add parent directory to path for color_extractor import
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from color_extractor import combine_tags


MANUFACTURER_CODE = 'PDX'
MANUFACTURER_NAME = 'PDX Tubing Co'
COE = '33'
BASE_URL = 'https://pdxtubingco.com'

# Collections to scrape
COLLECTIONS = [
    '/newdrop',
    '/oldglass5',
    '/oldglass4',
    '/oldglass3',
    '/oldglass2',
    '/oldglass1'
]


class ProductListParser(html.parser.HTMLParser):
    """Parser to extract product links from collection pages"""
    def __init__(self):
        super().__init__()
        self.product_links = []
        self.in_product_link = False
        self.current_link = None

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)

        # Look for product links
        if tag == 'a' and 'href' in attrs_dict:
            href = attrs_dict['href']
            # Product URLs are in collections (e.g., /newdrop/product-slug)
            # Skip navigation links, cart, etc.
            if '/' in href and href.count('/') >= 2 and not href.startswith('http'):
                # Check if it's a product link (not a collection or other page)
                parts = href.strip('/').split('/')
                if len(parts) == 2 and parts[0] in [c.strip('/') for c in COLLECTIONS]:
                    full_url = BASE_URL + href if not href.startswith('http') else href
                    if full_url not in self.product_links:
                        self.product_links.append(full_url)


class ProductPageParser(html.parser.HTMLParser):
    """Parser to extract product details from individual product pages"""
    def __init__(self):
        super().__init__()
        self.product_name = None
        self.description = None
        self.image_url = None
        self.price = None
        self.sku = None
        self.in_product_title = False
        self.in_description = False
        self.in_price = False
        self.current_text = []
        self.current_variant_sku = None

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)

        # Extract product name from h1 with product-title class
        if tag == 'h1':
            classes = attrs_dict.get('class', '')
            if 'product-title' in classes or 'ProductItem-details-title' in classes:
                self.in_product_title = True
                self.current_text = []

        # Extract main product image
        if tag == 'img' and 'src' in attrs_dict and not self.image_url:
            src = attrs_dict['src']
            # Look for product images from Squarespace CDN
            if 'squarespace' in src or 'static' in src:
                # Prefer larger images
                if '1500w' in src or '1000w' in src or not self.image_url:
                    self.image_url = src

        # Extract price
        if tag == 'span' and 'class' in attrs_dict:
            classes = attrs_dict.get('class', '')
            if 'product-price' in classes or 'sqs-money' in classes:
                self.in_price = True
                self.current_text = []

        # Extract SKU from variant data
        if tag == 'div' and 'data-variant-id' in attrs_dict:
            self.current_variant_sku = attrs_dict.get('data-variant-id', '')

        # Extract description
        if tag == 'div' and 'class' in attrs_dict:
            classes = attrs_dict.get('class', '')
            if 'product-description' in classes or 'ProductItem-details-excerpt' in classes:
                self.in_description = True
                self.current_text = []

    def handle_data(self, data):
        text = data.strip()
        if text:
            if self.in_product_title or self.in_description or self.in_price:
                self.current_text.append(text)

    def handle_endtag(self, tag):
        if tag == 'h1' and self.in_product_title:
            self.product_name = ' '.join(self.current_text).strip()
            self.in_product_title = False

        if tag == 'div' and self.in_description:
            self.description = ' '.join(self.current_text).strip()
            self.in_description = False

        if tag == 'span' and self.in_price:
            price_text = ' '.join(self.current_text).strip()
            # Extract first price if there's a range
            if '–' in price_text:
                price_text = price_text.split('–')[0].strip()
            self.price = price_text
            self.in_price = False


def scrape_product_page(product_url):
    """
    Scrape a single product page for details.

    Returns:
        dict with 'name', 'description', 'image_url', 'url', 'price', 'sku'
    """
    try:
        req = urllib.request.Request(product_url)
        req.add_header('User-Agent', 'Mozilla/5.0')

        with urllib.request.urlopen(req, timeout=15) as response:
            html_content = response.read().decode('utf-8')

        parser = ProductPageParser()
        parser.feed(html_content)

        # Try to extract SKU from page content using regex
        sku_match = re.search(r'"sku"\s*:\s*"([^"]+)"', html_content)
        if sku_match:
            parser.sku = sku_match.group(1)
        elif parser.current_variant_sku:
            parser.sku = parser.current_variant_sku
        else:
            # If no SKU found, extract from URL
            product_slug = product_url.rstrip('/').split('/')[-1]
            parser.sku = product_slug

        # Extract product name from URL if parser didn't find it
        if not parser.product_name:
            product_slug = product_url.rstrip('/').split('/')[-1]
            parser.product_name = product_slug.replace('-', ' ').title()

        return {
            'name': parser.product_name,
            'description': parser.description or '',
            'image_url': parser.image_url or '',
            'url': product_url,
            'price': parser.price or '',
            'sku': parser.sku or ''
        }

    except Exception as e:
        print(f"  Error scraping {product_url}: {e}")
        return None


def remove_brand_from_title(title):
    """Remove PDX Tubing Co brand name and product type from product title"""
    if not title:
        return ''

    cleaned_title = title

    # Remove "#1" prefix that appears on many products
    cleaned_title = re.sub(r'^#1\s+', '', cleaned_title, flags=re.IGNORECASE)

    # Remove brand patterns
    brand_patterns = ['PDX Tubing Co', 'PDX Tubing', 'PDX']
    for pattern in brand_patterns:
        cleaned_title = re.sub(f'^{re.escape(pattern)}\\s+', '', cleaned_title, flags=re.IGNORECASE)
        cleaned_title = re.sub(f'\\b{re.escape(pattern)}\\b\\s*', '', cleaned_title, flags=re.IGNORECASE)

    # Remove product type terms
    type_patterns = [r'\bTubing\b', r'\bTube\b', r'\bHand[- ]Pulled\b', r'\bBoro[- ]?Furnace\b']
    for pattern in type_patterns:
        cleaned_title = re.sub(pattern, '', cleaned_title, flags=re.IGNORECASE)

    # Remove COE references
    cleaned_title = re.sub(r'\bCOE\s*33\b', '', cleaned_title, flags=re.IGNORECASE)

    # Clean up extra whitespace
    cleaned_title = re.sub(r'\s+', ' ', cleaned_title).strip()

    return cleaned_title


def scrape(test_mode=False, max_items=None):
    """
    Scrape PDX Tubing Co products.

    Args:
        test_mode: If True, limit scraping for testing
        max_items: Maximum number of items to scrape (for testing)

    Returns:
        tuple: (products_list, duplicates_list)
    """
    print(f"\n{'='*60}")
    print(f"Scraping {MANUFACTURER_NAME} ({MANUFACTURER_CODE})")
    print(f"{'='*60}")

    all_product_urls = []

    # Step 1: Get product links from all collections
    for collection in COLLECTIONS:
        collection_url = BASE_URL + collection
        print(f"  Fetching products from {collection}...")

        try:
            req = urllib.request.Request(collection_url)
            req.add_header('User-Agent', 'Mozilla/5.0')

            with urllib.request.urlopen(req, timeout=15) as response:
                html_content = response.read().decode('utf-8')

            parser = ProductListParser()
            parser.feed(html_content)

            all_product_urls.extend(parser.product_links)
            print(f"    Found {len(parser.product_links)} products in {collection}")

            # Small delay between collection requests
            time.sleep(0.3)

        except Exception as e:
            print(f"    Error fetching {collection}: {e}")
            continue

    # Remove duplicates while preserving order
    seen = set()
    unique_urls = []
    for url in all_product_urls:
        if url not in seen:
            seen.add(url)
            unique_urls.append(url)

    all_product_urls = unique_urls
    print(f"\n  Total unique products found across all collections: {len(all_product_urls)}")

    # Step 2: Scrape each product page
    all_products = []
    seen_skus = {}
    duplicates = []

    for i, url in enumerate(all_product_urls):
        if max_items and len(all_products) >= max_items:
            print(f"  Reached max items limit ({max_items})")
            break

        if test_mode and len(all_products) >= 3:
            print("  Test mode: stopping after 3 products")
            break

        print(f"  [{i+1}/{len(all_product_urls)}] Scraping {url}")

        product_data = scrape_product_page(url)

        if not product_data:
            continue

        sku = product_data['sku']

        product = {
            'name': product_data['name'],
            'sku': sku,
            'url': url.replace(BASE_URL, ''),  # Relative URL
            'manufacturer_url': url,
            'manufacturer_description': product_data['description'],
            'image_url': product_data['image_url'],
            'price': product_data['price'],
            'product_type': 'tubing'  # All PDX products are tubing
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
        time.sleep(0.5)

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
        product_type = product.get('product_type', 'tubing')
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
        csv_filename = 'pdx_tubing_products_test.csv' if test_mode else 'pdx_tubing_products.csv'

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

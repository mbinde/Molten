"""
UST Glass (UST) scraper module.
Scrapes COE 33 borosilicate glass products from ustglass.com.
"""

import urllib.request
import urllib.error
import urllib.parse
import re
import time
import html.parser
import json
import sys
import os
import gzip

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from color_extractor import combine_tags
from scraper_config import get_page_delay, is_bot_protection_error


MANUFACTURER_CODE = 'UST'
MANUFACTURER_NAME = 'UST Glass'
COE = '33'
BASE_URL = 'https://www.ustglass.com'
CATEGORY_URL = f'{BASE_URL}/product-category/color/'


class ProductPageParser(html.parser.HTMLParser):
    """Parser to extract embedded JSON product data and additional details"""
    def __init__(self):
        super().__init__()
        self.product_name = None
        self.description = None
        self.image_url = None
        self.sku = None
        self.price = None
        self.stock_status = None
        self.in_product_title = False
        self.in_description = False
        self.current_text = []
        self.embedded_json = None

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)

        # Extract product name
        if tag == 'h1' and 'class' in attrs_dict:
            classes = attrs_dict.get('class', '')
            if 'product_title' in classes or 'entry-title' in classes:
                self.in_product_title = True
                self.current_text = []

        # Extract product image
        if tag == 'img' and 'src' in attrs_dict:
            src = attrs_dict['src']
            # Look for product images in uploads folder
            if 'wp-content/uploads' in src and not self.image_url:
                self.image_url = src

        # Extract description
        if tag == 'div' and 'class' in attrs_dict:
            classes = attrs_dict.get('class', '')
            if 'woocommerce-product-details__short-description' in classes:
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


def extract_json_from_script(html_content):
    """
    Extract embedded JSON product data from JavaScript in the page.

    UST Glass embeds product data in wpmDataLayer.products[ID] assignments
    """
    products_json = []

    # Look for individual product assignments like:
    # wpmDataLayer.products[47431] = {"id":"47431","sku":"CHINA-COL-GRE10X1.5-TLA",...}
    # Need to handle nested objects properly
    pattern = r'wpmDataLayer\.products\[(\d+)\]\s*=\s*(\{.+?\});'
    matches = re.findall(pattern, html_content, re.DOTALL)

    for product_id, json_str in matches:
        try:
            # Clean up the JSON string - sometimes there are issues with nested braces
            # Try to find the complete JSON by counting braces
            brace_count = 0
            end_pos = 0
            for i, char in enumerate(json_str):
                if char == '{':
                    brace_count += 1
                elif char == '}':
                    brace_count -= 1
                    if brace_count == 0:
                        end_pos = i + 1
                        break

            if end_pos > 0:
                clean_json = json_str[:end_pos]
                product_data = json.loads(clean_json)
                # Skip if we've already added this product (avoid duplicates)
                if not any(p.get('id') == product_data.get('id') for p in products_json):
                    products_json.append(product_data)
        except (json.JSONDecodeError, ValueError):
            continue

    return products_json


def scrape_category_page(page_num=1):
    """
    Scrape a single category page to get product data.

    Returns:
        list of product dictionaries from embedded JSON, or None if bot protection detected
    """
    url = f"{CATEGORY_URL}?product-page={page_num}"

    try:
        req = urllib.request.Request(url)
        req.add_header('User-Agent', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')
        req.add_header('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8')
        req.add_header('Accept-Language', 'en-US,en;q=0.5')
        req.add_header('Accept-Encoding', 'gzip, deflate')
        req.add_header('DNT', '1')
        req.add_header('Connection', 'keep-alive')
        req.add_header('Upgrade-Insecure-Requests', '1')

        with urllib.request.urlopen(req, timeout=15) as response:
            # Check if response is gzip compressed
            if response.info().get('Content-Encoding') == 'gzip':
                html_content = gzip.decompress(response.read()).decode('utf-8')
            else:
                html_content = response.read().decode('utf-8')

        # Extract embedded JSON product data
        products = extract_json_from_script(html_content)

        # Also extract product images from HTML
        # Images are in <img class="wp-post-image" src="..."> tags
        image_pattern = r'<img[^>]+class="wp-post-image"[^>]+src="([^"]+)"'
        image_urls = re.findall(image_pattern, html_content)

        # Match images to products (they should be in the same order)
        for i, product in enumerate(products):
            if i < len(image_urls):
                product['image_url'] = image_urls[i]

        if products:
            return products

        # Fallback: parse HTML if JSON not found
        print(f"    Warning: No JSON data found on page {page_num}, trying HTML parsing...")
        return []

    except urllib.error.HTTPError as e:
        if is_bot_protection_error(e):
            print(f"  ⚠️  Bot protection detected on page {page_num} (HTTP {e.code})")
            print(f"  ⚠️  Stopping scrape to respect site's request")
            return None
        else:
            print(f"  Error scraping page {page_num}: HTTP {e.code} - {e}")
            return []
    except Exception as e:
        print(f"  Error scraping page {page_num}: {e}")
        return []


def scrape_product_page(product_url):
    """
    Scrape individual product page for additional details.

    Returns:
        dict with additional product details
    """
    try:
        req = urllib.request.Request(product_url)
        req.add_header('User-Agent', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')
        req.add_header('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8')
        req.add_header('Accept-Language', 'en-US,en;q=0.5')

        with urllib.request.urlopen(req, timeout=15) as response:
            # Check if response is gzip compressed
            if response.info().get('Content-Encoding') == 'gzip':
                html_content = gzip.decompress(response.read()).decode('utf-8')
            else:
                html_content = response.read().decode('utf-8')

        parser = ProductPageParser()
        parser.feed(html_content)

        # Also try to extract structured data
        structured_data = {}
        sku_match = re.search(r'"sku"\s*:\s*"([^"]+)"', html_content)
        if sku_match:
            structured_data['sku'] = sku_match.group(1)

        return {
            'name': parser.product_name,
            'description': parser.description or '',
            'image_url': parser.image_url or '',
            'sku': structured_data.get('sku', parser.sku) or ''
        }

    except Exception as e:
        print(f"  Error scraping product page {product_url}: {e}")
        return None


def remove_brand_from_title(title):
    """Remove UST Glass brand name and product type from product title"""
    if not title:
        return ''

    cleaned_title = title

    # Remove brand patterns
    brand_patterns = ['UST Glass', 'UST']
    for pattern in brand_patterns:
        cleaned_title = re.sub(f'^{re.escape(pattern)}\\s+', '', cleaned_title, flags=re.IGNORECASE)
        cleaned_title = re.sub(f'\\b{re.escape(pattern)}\\b\\s*', '', cleaned_title, flags=re.IGNORECASE)

    # Remove "LA" suffix (lot/batch identifier)
    cleaned_title = re.sub(r'\s+LA$', '', cleaned_title, flags=re.IGNORECASE)

    # Remove size specifications at the beginning (e.g., "12 x 2.0")
    cleaned_title = re.sub(r'^\d+\s*x\s*\d+\.?\d*\s+', '', cleaned_title, flags=re.IGNORECASE)

    # Remove product type terms
    type_patterns = [r'\bTubing\b', r'\bTube\b', r'\bRods?\b', r'\bFrit\b']
    for pattern in type_patterns:
        cleaned_title = re.sub(pattern, '', cleaned_title, flags=re.IGNORECASE)

    # Remove COE references
    cleaned_title = re.sub(r'\bCOE\s*33\b', '', cleaned_title, flags=re.IGNORECASE)
    cleaned_title = re.sub(r'\b33\s*expansion\b', '', cleaned_title, flags=re.IGNORECASE)

    # Remove "Chinese" and "Imported" qualifiers
    cleaned_title = re.sub(r'\bChinese\b', '', cleaned_title, flags=re.IGNORECASE)
    cleaned_title = re.sub(r'\bImported\b', '', cleaned_title, flags=re.IGNORECASE)

    # Clean up extra whitespace
    cleaned_title = re.sub(r'\s+', ' ', cleaned_title).strip()

    return cleaned_title


def infer_product_type(name, sku, description):
    """Infer product type from name, SKU, or description"""
    combined = f"{name} {sku} {description}".lower()

    if 'tubing' in combined or '-t' in sku.lower():
        return 'tubing'
    elif 'rod' in combined or '-r' in sku.lower():
        return 'rod'
    elif 'frit' in combined or '-f' in sku.lower():
        return 'frit'
    elif 'stringer' in combined or 'string' in combined:
        return 'stringer'
    elif 'sheet' in combined or 'flat' in combined:
        return 'sheet'
    else:
        return 'other'


def scrape(test_mode=False, max_items=None):
    """
    Scrape UST Glass products.

    Args:
        test_mode: If True, limit scraping for testing
        max_items: Maximum number of items to scrape (for testing)

    Returns:
        tuple: (products_list, duplicates_list)
    """
    print(f"\n{'='*60}")
    print(f"Scraping {MANUFACTURER_NAME} ({MANUFACTURER_CODE})")
    print(f"{'='*60}")

    all_products = []
    seen_skus = {}
    duplicates = []

    # Determine how many pages to scrape
    # UST Glass has ~1,842 products across 77 pages (24 per page)
    if test_mode:
        max_pages = 1  # Just scrape first page in test mode
        print("  Test mode: scraping first page only (24 products)")
    elif max_items:
        max_pages = (max_items // 24) + 1
        print(f"  Scraping up to {max_pages} pages to get ~{max_items} products")
    else:
        max_pages = 77  # Full catalog
        print("  Scraping full catalog (~77 pages, ~1,842 products)")

    # Scrape category pages
    for page_num in range(1, max_pages + 1):
        if max_items and len(all_products) >= max_items:
            print(f"  Reached max items limit ({max_items})")
            break

        print(f"\n  Scraping page {page_num}/{max_pages}...")

        products_on_page = scrape_category_page(page_num)

        # If bot protection detected, stop scraping entirely
        if products_on_page is None:
            print(f"  Stopping scrape due to bot protection")
            break

        if not products_on_page:
            print(f"    No products found on page {page_num}, stopping.")
            break

        print(f"    Found {len(products_on_page)} products on page {page_num}")

        for product_data in products_on_page:
            if max_items and len(all_products) >= max_items:
                break

            if test_mode and len(all_products) >= 3:
                print("  Test mode: stopping after 3 products")
                break

            # Extract data from JSON
            name = product_data.get('name', '')
            sku = product_data.get('id', '')  # UST uses 'id' field for SKU
            price = product_data.get('price', '')
            image_url = product_data.get('image_url', '')

            # Skip invalid products (category links, not actual products)
            # These have generic single-word names like "green", "blue", etc.
            if not name or len(name.strip()) < 3:
                print(f"    Skipping invalid product with empty/short name: '{name}'")
                continue

            # Skip products with only a single color word (likely category links)
            single_word_colors = ['red', 'blue', 'green', 'yellow', 'orange', 'purple',
                                 'pink', 'brown', 'black', 'white', 'clear', 'gray']
            if name.strip().lower() in single_word_colors:
                print(f"    Skipping category link: '{name}'")
                continue

            # Try to get more details if available
            # (In JSON, we usually have name, id/sku, price, category, and now image_url)

            product_type = infer_product_type(name, str(sku), '')

            product = {
                'name': name,
                'sku': str(sku),
                'manufacturer_description': '',
                'image_url': image_url,
                'price': str(price) if price else '',
                'product_type': product_type,
                'manufacturer_url': f"{BASE_URL}/shop/{sku}/"  # Approximate URL
            }

            # Check for duplicates
            if sku in seen_skus:
                duplicates.append({
                    'sku': sku,
                    'name': product['name'],
                    'url': product.get('manufacturer_url', ''),
                    'original_name': seen_skus[sku]['name'],
                    'original_url': seen_skus[sku].get('url', '')
                })
                print(f"    Skipping duplicate SKU {sku}")
            else:
                seen_skus[sku] = {'name': product['name'], 'url': product.get('manufacturer_url', '')}
                all_products.append(product)

        # Delay between pages (respects bot protection settings)
        time.sleep(get_page_delay(MANUFACTURER_CODE))

    print(f"\n  Total products scraped: {len(all_products)}")
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
        csv_filename = 'ust_glass_products_test.csv' if test_mode else 'ust_glass_products.csv'

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

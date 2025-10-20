"""
Momka Glass (MOM) scraper module.
Scrapes products from www.momkasglasseu.com (Squarespace site).
"""

import urllib.request
import urllib.error
import urllib.parse
import re
import time
import html.parser
import sys
import os
import json
import hashlib

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from color_extractor import combine_tags
from scraper_config import get_page_delay, get_product_delay, is_bot_protection_error


MANUFACTURER_CODE = 'MOM'
MANUFACTURER_NAME = 'Momka Glass'
COE = '33'
BASE_URL = 'https://www.momkasglasseu.com'


class ProductListParser(html.parser.HTMLParser):
    """Parser to extract product links from the shop page"""
    def __init__(self):
        super().__init__()
        self.products = []
        self.in_product_link = False
        self.current_url = None
        self.current_text = []

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)

        # Look for product links in the product grid
        if tag == 'a' and 'href' in attrs_dict:
            href = attrs_dict['href']
            # Product links are like /shop/product-name
            if href.startswith('/shop/') and href != '/shop':
                self.in_product_link = True
                self.current_url = href
                self.current_text = []

    def handle_data(self, data):
        if self.in_product_link:
            text = data.strip()
            if text:
                self.current_text.append(text)

    def handle_endtag(self, tag):
        if tag == 'a' and self.in_product_link:
            if self.current_url:
                # Store the URL (we'll get details from detail page)
                self.products.append({
                    'url': self.current_url,
                    'preview_name': ' '.join(self.current_text) if self.current_text else ''
                })
            self.in_product_link = False
            self.current_url = None
            self.current_text = []


class ProductDetailParser(html.parser.HTMLParser):
    """Parser to extract product details from detail page"""
    def __init__(self):
        super().__init__()
        self.product_name = None
        self.description = ""
        self.image_url = ""
        self.sku = ""
        self.in_description = False
        self.in_title = False
        self.current_text = []
        self.all_paragraphs = []
        self.in_paragraph = False
        self.paragraph_texts = []
        self.json_data = None

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)

        # Look for product title in h1
        if tag == 'h1':
            self.in_title = True
            self.current_text = []

        # Look for description in p tags or divs with specific classes
        if tag == 'div' and 'class' in attrs_dict:
            class_str = attrs_dict['class'].lower()
            # Squarespace product description classes
            if any(keyword in class_str for keyword in ['product-description', 'productitem-details', 'product-excerpt', 'sqs-block-content']):
                self.in_description = True

        # Capture all paragraphs
        if tag == 'p':
            self.in_paragraph = True
            self.paragraph_texts = []

        # Look for Open Graph image (Squarespace uses this for product images)
        if tag == 'meta' and 'property' in attrs_dict and attrs_dict['property'] == 'og:image':
            if 'content' in attrs_dict:
                src = attrs_dict['content']
                # Skip logo images
                if 'MOMKA' not in src.upper() and 'logo' not in src.lower():
                    # Get high-res version for Squarespace
                    if 'squarespace' in src.lower() or 'static1' in src.lower():
                        if '?format=' in src:
                            src = re.sub(r'\?format=\d+w', '?format=1500w', src)
                        else:
                            src += '?format=1500w'

                    # Ensure absolute URL
                    if src.startswith('//'):
                        src = 'https:' + src
                    elif src.startswith('http'):
                        pass  # Already absolute
                    elif src.startswith('/'):
                        src = BASE_URL + src
                    else:
                        src = BASE_URL + '/' + src

                    self.image_url = src

        # Look for product images in img tags (not logos)
        if tag == 'img' and 'src' in attrs_dict:
            src = attrs_dict['src']

            # Skip empty sources
            if not src:
                return

            # Skip logo images
            if 'MOMKA' in src.upper() or 'logo' in src.lower():
                return

            # Look for actual product images (typically jpg files)
            if '.jpg' in src.lower() or '.png' in src.lower():
                # Get high-res version for Squarespace
                if 'squarespace' in src.lower():
                    if '?format=' in src:
                        src = re.sub(r'\?format=\d+w', '?format=1500w', src)
                    else:
                        src += '?format=1500w'

                # Ensure absolute URL
                if src.startswith('//'):
                    src = 'https:' + src
                elif src.startswith('http'):
                    pass  # Already absolute
                elif src.startswith('/'):
                    src = BASE_URL + src
                else:
                    src = BASE_URL + '/' + src

                # Only set if we don't have one yet (og:image takes precedence)
                if not self.image_url:
                    self.image_url = src

    def handle_data(self, data):
        text = data.strip()
        if text:
            if self.in_title:
                self.current_text.append(text)
            elif self.in_paragraph:
                self.paragraph_texts.append(text)

    def handle_endtag(self, tag):
        if tag == 'h1' and self.in_title:
            self.product_name = ' '.join(self.current_text).strip()
            self.in_title = False
            self.current_text = []

        if tag == 'p' and self.in_paragraph:
            para_text = ' '.join(self.paragraph_texts).strip()
            if para_text:
                self.all_paragraphs.append(para_text)
                # If we're in a description section, add to description
                if self.in_description:
                    if self.description:
                        self.description += ' '
                    self.description += para_text
            self.in_paragraph = False
            self.paragraph_texts = []

        if tag == 'div' and self.in_description:
            self.in_description = False

        # At the end, if we don't have a description, use first few paragraphs
    def get_description(self):
        """Get the best description we found"""
        desc = self.description if self.description else ""

        # If no explicit description, use first few paragraphs
        if not desc and self.all_paragraphs:
            # Filter out very short paragraphs and unwanted text
            good_paragraphs = []
            for p in self.all_paragraphs:
                p_lower = p.lower()
                # Skip footer/metadata paragraphs
                if any(skip in p_lower for skip in ['powered by', 'squarespace', 'cookie', 'privacy']):
                    continue
                if len(p) > 30:
                    good_paragraphs.append(p)
            if good_paragraphs:
                desc = ' '.join(good_paragraphs[:2])  # First 2 substantial paragraphs

        # Clean up description
        desc = re.sub(r'Powered by Squarespace', '', desc, flags=re.IGNORECASE)
        desc = re.sub(r'\s+', ' ', desc).strip()
        return desc


def extract_sku_from_name(name):
    """Extract SKU code from product name (e.g., 'Cobalt Blue MB011' -> 'MB011')"""
    if not name:
        return ""

    # Look for MB#### pattern
    match = re.search(r'\b(MB\d+[A-Za-z]?)\b', name, re.IGNORECASE)
    if match:
        return match.group(1).upper()

    return ""


def remove_brand_from_title(title):
    """Remove Momka brand name and SKU from product title"""
    if not title:
        return ''

    # Remove SKU (MB###)
    cleaned_title = re.sub(r'\bMB\d+[A-Za-z]?\b', '', title, flags=re.IGNORECASE)

    # Remove brand patterns
    brand_patterns = ['Momka', "Momka's Glass", 'MOM']
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


def determine_product_type(product_name):
    """Determine the type of glass product from its name"""
    if not product_name:
        return 'rod'

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
        return 'rod'  # Default to rod for Momka


def scrape_product_list(base_url, test_mode=False):
    """Scrape product links from the main shop page"""
    print(f"  Fetching product list from: {base_url}")

    # Skip non-glass products
    excluded_keywords = ['bits', 'irregulars', 'shorts', 'scrap', 'random', 'pack', 'kilos']

    try:
        req = urllib.request.Request(base_url)
        req.add_header('User-Agent', 'Mozilla/5.0')

        with urllib.request.urlopen(req, timeout=15) as response:
            html_content = response.read().decode('utf-8')

        parser = ProductListParser()
        parser.feed(html_content)

        print(f"    Found {len(parser.products)} total product links")

        # Filter out excluded products
        filtered_products = []
        for product in parser.products:
            url_lower = product['url'].lower()
            if any(keyword in url_lower for keyword in excluded_keywords):
                continue
            filtered_products.append(product)

        print(f"    {len(filtered_products)} products after filtering")

        if test_mode and len(filtered_products) > 3:
            return filtered_products[:3]

        return filtered_products

    except Exception as e:
        print(f"  Error fetching product list: {e}")
        return []


def scrape_product_detail(product_url):
    """Scrape details from a single product page"""
    try:
        full_url = f"{BASE_URL}{product_url}"

        req = urllib.request.Request(full_url)
        req.add_header('User-Agent', 'Mozilla/5.0')

        with urllib.request.urlopen(req, timeout=15) as response:
            html_content = response.read().decode('utf-8')

        # Parse HTML to extract product info
        parser = ProductDetailParser()
        parser.feed(html_content)

        product_name = parser.product_name or ''
        description = parser.get_description()
        image_url = parser.image_url

        # Try to get title from JSON if HTML parsing didn't find it
        if not product_name:
            json_match = re.search(r'Static\.SQUARESPACE_CONTEXT\s*=\s*(\{.+?\});', html_content, re.DOTALL)
            if json_match:
                try:
                    context_data = json.loads(json_match.group(1))
                    if 'item' in context_data and context_data['item']:
                        product_name = context_data['item'].get('title', '')
                except json.JSONDecodeError:
                    pass

        # Extract SKU from product name
        sku = extract_sku_from_name(product_name)

        # If no SKU found, generate one from the cleaned name
        if not sku:
            cleaned_name = remove_brand_from_title(product_name or '')
            name_hash = hashlib.md5(cleaned_name.encode('utf-8')).hexdigest()[:8]
            sku = f"MOM-{name_hash}"

        product = {
            'name': product_name,
            'sku': sku,
            'url': product_url,
            'manufacturer_url': full_url,
            'manufacturer_description': description,
            'image_url': image_url
        }

        time.sleep(get_page_delay(MANUFACTURER_CODE))

        return product

    except Exception as e:
        print(f"    Error scraping product detail: {e}")
        import traceback
        traceback.print_exc()
        return None


def scrape(test_mode=False, max_items=None):
    """
    Scrape Momka Glass products.

    Args:
        test_mode: If True, limit scraping for testing
        max_items: Maximum number of items to scrape (for testing)

    Returns:
        tuple: (products_list, duplicates_list)
    """
    print(f"\n{'='*60}")
    print(f"Scraping {MANUFACTURER_NAME} ({MANUFACTURER_CODE})")
    print(f"{'='*60}")

    # Scrape product list
    shop_url = f"{BASE_URL}/shop"
    product_links = scrape_product_list(shop_url, test_mode=test_mode)

    all_products = []
    seen_skus = {}
    duplicates = []

    for product_link in product_links:
        print(f"  Fetching: {product_link['url']}")

        product = scrape_product_detail(product_link['url'])

        if product and product.get('name'):
            sku = product.get('sku', '')

            # Check for duplicates
            if sku and sku in seen_skus:
                duplicates.append({
                    'sku': sku,
                    'name': product['name'],
                    'url': product['url'],
                    'original_name': seen_skus[sku]['name'],
                    'original_url': seen_skus[sku]['url']
                })
                print(f"    DUPLICATE SKU found: {sku}")
                continue

            if sku:
                seen_skus[sku] = {
                    'name': product['name'],
                    'url': product['url']
                }

            all_products.append(product)
            print(f"    Added: {product['name']} ({sku})")

        # Check limits
        if max_items and len(all_products) >= max_items:
            print(f"  Reached max items limit ({max_items})")
            break

        if test_mode and len(all_products) >= 3:
            print("  Test mode: stopping after 3 products")
            break

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
        product_name = product.get('name') or ''

        if not product_name:
            print(f"  WARNING: Skipping product with no name: {product}")
            continue

        product_type = determine_product_type(product_name)
        cleaned_name = remove_brand_from_title(product_name)
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
            'stock_type': ''  # Momka doesn't track stock_type in our system
        })

    return csv_rows


def main():
    """Main entry point for standalone testing"""
    test_mode = '--test' in sys.argv or '-test' in sys.argv

    if test_mode:
        print("Running in TEST MODE - will only scrape 3 items")
        print("-" * 60)

    print("Starting scrape of Momka Glass products...")
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
        csv_filename = 'momka_products_test.csv' if test_mode else 'momka_products.csv'

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

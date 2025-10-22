"""
Effetre and Vetrofond glass scraper module.
Scrapes from Frantz Art Glass collections.
"""

import urllib.request
import urllib.error
import urllib.parse
import re
import time
import html.parser
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from color_extractor import combine_tags
from scraper_config import get_page_delay, get_product_delay, is_bot_protection_error

# Module constants - using "EF" for Effetre as the primary manufacturer code
# Vetrofond products will be tagged with "VF" in the code
MANUFACTURER_CODE = 'EF'  # Primary manufacturer
MANUFACTURER_NAME = 'Effetre/Vetrofond'
COE = '104'

# SKU overrides - force specific SKUs for certain URLs
SKU_OVERRIDES = {
    '/products/red-roof-tile-machine-5-6mm-sp': '591440-M-ODD',
}

# Stock type overrides - force specific stock_type for certain URLs
STOCK_TYPE_OVERRIDES = {
    '/products/red-roof-tile-machine-5-6mm-sp': 'odd',
}


class DescriptionParser(html.parser.HTMLParser):
    """Parser to extract product description and image from detail page"""
    def __init__(self):
        super().__init__()
        self.description = ""
        self.in_description = False
        self.in_paragraph = False
        self.in_heading = False
        self.description_texts = []
        self.paragraph_texts = []
        self.all_paragraphs = []
        self.image_url = ""
        self.sku = ""
        self.depth = 0
        self.all_text = []

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)

        if tag == 'div' and 'class' in attrs_dict:
            class_str = attrs_dict['class'].lower()
            if any(keyword in class_str for keyword in ['product-description', 'product__description',
                                                         'description', 'rte', 'product-single__description',
                                                         'product__text', 'product-content', 'product__content']):
                self.in_description = True
                self.depth = 1
        elif self.in_description:
            if tag == 'div':
                self.depth += 1
            elif tag == 'p':
                self.in_paragraph = True
                self.paragraph_texts = []
            elif tag in ['h1', 'h2', 'h3', 'h4', 'h5', 'h6']:
                self.in_heading = True

        if tag == 'p':
            self.in_paragraph = True
            self.paragraph_texts = []

        if tag == 'img':
            src = attrs_dict.get('src', '')

            # Skip empty sources
            if not src:
                return

            # Skip placeholder, icon, logo images
            skip_terms = ['icon', 'logo', '_small', '_thumb', 'placeholder', 'default', 'no-image']
            if any(term in src.lower() for term in skip_terms):
                return

            # Check if this looks like a product image (from CDN or products directory)
            is_cdn_image = 'cdn/shop/files' in src or 'cdn/shop/products' in src
            is_product_path = '/products/' in src or '/product/' in src
            is_product_image = is_cdn_image or is_product_path

            is_better_quality = '_large' in src or '_grande' in src or '_master' in src or '_1024x' in src

            # Update image_url if this is a product image and we either don't have one yet or this is better quality
            if is_product_image and (not self.image_url or is_better_quality):
                if src.startswith('//'):
                    self.image_url = 'https:' + src
                elif src.startswith('http'):
                    self.image_url = src
                elif src.startswith('/'):
                    self.image_url = 'https://www.frantzartglass.com' + src

    def handle_data(self, data):
        text = data.strip()
        if text:
            self.all_text.append(text)

        if self.in_heading and text:
            starts_with_sku = re.match(r'^\d{6}\s', text)
            if starts_with_sku:
                return

        if self.in_paragraph and text:
            self.paragraph_texts.append(text)

        if self.in_description and text:
            if not self.in_paragraph:
                self.description_texts.append(text)

    def handle_endtag(self, tag):
        if tag == 'p' and self.in_paragraph:
            para_text = ' '.join(self.paragraph_texts).strip()
            if para_text:
                self.all_paragraphs.append(para_text)
                if self.in_description:
                    self.description_texts.append(para_text)
            self.in_paragraph = False
            self.paragraph_texts = []

        if tag in ['h1', 'h2', 'h3', 'h4', 'h5', 'h6']:
            self.in_heading = False

        if self.in_description and tag == 'div':
            self.depth -= 1
            if self.depth == 0:
                self.in_description = False

    def get_sku(self):
        """Extract SKU from all collected text"""
        full_text = ' '.join(self.all_text)
        # First try to find SKU with label - allow for 6 or 7 digits with various suffixes
        sku_match = re.search(r'SKU:\s*(\d{6,7}(?:[A-Z]|-[A-Z0-9]+)?)', full_text, re.IGNORECASE)
        if sku_match:
            return sku_match.group(1)
        # Fallback to finding 6 or 7 digit code in text
        sku_match = re.search(r'\b\d{6,7}(?:[A-Z]|-[A-Z0-9]+)?\b', full_text)
        if sku_match:
            return sku_match.group()
        return ""

    def get_description(self):
        """Extract and clean description from collected text"""
        if self.description_texts:
            full_text = ' '.join(self.description_texts)
            full_text = re.sub(r'\s+', ' ', full_text).strip()
        else:
            relevant_paragraphs = []
            for para in self.all_paragraphs:
                para_lower = para.lower()
                if any(skip in para_lower for skip in ['add to cart', 'buy it now', 'shipping',
                                                        'decrease quantity', 'increase quantity',
                                                        'sold out', 'view full details', 'pickup available',
                                                        'usually ready in', 'view store information',
                                                        'customer pickup hours', 'frantz art glass is known']):
                    continue
                if len(para) < 20:
                    continue
                if any(meta in para_lower for meta in ['vendor:', 'sku:', 'product type:',
                                                        'regular price', 'sale price']):
                    continue
                relevant_paragraphs.append(para)

            full_text = ' '.join(relevant_paragraphs[:3])
            full_text = re.sub(r'\s+', ' ', full_text).strip()

        if not full_text:
            return ""

        # Remove SKU/manufacturer sentences from beginning
        pattern1 = r'^\s*[A-Z][a-zA-Z\s]+(?:Ltd Run|Limited Run)?\s+\d{6}\s+by\s+[A-Za-z\s]+\([A-Za-z]+\)\s*\.\s*'
        full_text = re.sub(pattern1, '', full_text).strip()

        pattern2 = r'^\s*\d{6}\s+by\s+[A-Za-z\s]+(?:\([A-Za-z]+\))?\s*\.\s*'
        full_text = re.sub(pattern2, '', full_text).strip()

        beginning_junk = [
            'Shipping calculated at checkout.',
            'Shipping calculated at checkout',
        ]

        for junk in beginning_junk:
            if full_text.startswith(junk):
                full_text = full_text[len(junk):].strip()

        stop_phrases = [
            'Size: Diameter',
            'Size:',
            'ATTENTION:',
            'Attention:',
            'Share',
            'Vendor:',
            'SKU:',
            'Regular price',
            'Sale price',
            'Sold out',
            'Decrease quantity',
            'Increase quantity',
            'Add to cart',
            'Buy it now',
            'More payment options',
            'View full details',
            'Quantity',
            'Product type',
            'Pickup available',
            'Usually ready in',
            'View store information',
            'Customer Pickup Hours',
            'Frantz Art Glass is known'
        ]

        description_end = len(full_text)
        for phrase in stop_phrases:
            pos = full_text.find(phrase)
            if pos != -1 and pos < description_end:
                description_end = pos

        description = full_text[:description_end].strip()

        prefixes_to_remove = [
            'Description:',
            'Description',
            'Product Description:',
            'Product Description',
            'Details:',
            'Details'
        ]

        for prefix in prefixes_to_remove:
            if description.lower().startswith(prefix.lower()):
                description = description[len(prefix):].strip()
                if description.startswith(':'):
                    description = description[1:].strip()

        return description


def fetch_product_description(product_url, product_name):
    """Fetch and parse the product description and image from detail page"""
    try:
        full_url = product_url if product_url.startswith('http') else f"https://www.frantzartglass.com{product_url}"

        print(f"  Fetching description from: {full_url}")

        req = urllib.request.Request(full_url)
        req.add_header('User-Agent', 'Mozilla/5.0')

        with urllib.request.urlopen(req, timeout=10) as response:
            html_content = response.read().decode('utf-8')

        parser = DescriptionParser()
        parser.feed(html_content)
        description = parser.get_description()
        image_url = parser.image_url
        sku = parser.get_sku()

        time.sleep(get_page_delay(MANUFACTURER_CODE))

        return description, image_url, sku
    except Exception as e:
        print(f"  Error fetching description: {e}")
        return "", "", ""


def determine_product_type(product_name):
    """Determine the type of glass product from its name"""
    name_lower = product_name.lower()

    if 'rod' in name_lower or 'rods' in name_lower:
        return 'rod'
    elif 'frit' in name_lower or 'powder' in name_lower:
        return 'frit'
    elif 'sheet' in name_lower:
        return 'sheet'
    elif 'stringer' in name_lower:
        return 'stringer'
    elif 'tube' in name_lower or 'tubing' in name_lower:
        return 'tube'
    else:
        return 'other'


def remove_brand_from_title(title, manufacturer_code):
    """Remove brand name and product type from product title"""
    brand_patterns = {
        'EF': ['Effetre'],
        'VF': ['Vetrofond'],
    }

    patterns = brand_patterns.get(manufacturer_code, [])
    cleaned_title = title

    for pattern in patterns:
        cleaned_title = re.sub(f'^{re.escape(pattern)}\\s+', '', cleaned_title, flags=re.IGNORECASE)
        cleaned_title = re.sub(f'\\b{re.escape(pattern)}\\b\\s*', '', cleaned_title, flags=re.IGNORECASE)

    # Remove product type terms
    type_patterns = [r'\bRods?\b', r'\bFrit\b', r'\bPowder\b', r'\bSheet\b',
                    r'\bStringers?\b', r'\bTubes?\b', r'\bTubing\b']

    for pattern in type_patterns:
        cleaned_title = re.sub(pattern, '', cleaned_title, flags=re.IGNORECASE)

    # Remove COE references
    cleaned_title = re.sub(r'\bCOE\s*33\b', '', cleaned_title, flags=re.IGNORECASE)
    cleaned_title = re.sub(r'\bCOE\s*104\b', '', cleaned_title, flags=re.IGNORECASE)

    cleaned_title = re.sub(r'\s+', ' ', cleaned_title).strip()

    return cleaned_title


class ProductParser(html.parser.HTMLParser):
    """Simple HTML parser to extract product information"""
    def __init__(self):
        super().__init__()
        self.products = []
        self.current_product = None
        self.in_product_link = False
        self.current_text = []
        self.seen_urls = set()
        self.in_collection_grid = False

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)

        if tag == 'div' and 'class' in attrs_dict:
            class_str = attrs_dict['class']
            if 'collection' in class_str or 'product-grid' in class_str or 'grid' in class_str:
                self.in_collection_grid = True

        if tag == 'a' and 'href' in attrs_dict:
            href = attrs_dict['href']
            # Match product links (remove ?_pos= requirement as site no longer uses it)
            if '/products/' in href and href not in self.seen_urls:
                # Skip if it's just a parameter or anchor
                if '?' not in href or href.find('?') > href.find('/products/'):
                    self.current_product = {
                        'url': href,
                        'name': None,
                        'sku': None,
                        'price': None
                    }
                    self.in_product_link = True
                    self.current_text = []

    def handle_data(self, data):
        if self.in_product_link or self.current_product:
            self.current_text.append(data)

    def handle_endtag(self, tag):
        if tag == 'div':
            self.in_collection_grid = False

        if tag == 'a' and self.in_product_link and self.current_product:
            text = ' '.join(self.current_text)

            lines = [line.strip() for line in text.split('\n') if line.strip()]
            if lines:
                self.current_product['name'] = lines[0]

            if self.current_product['name']:
                price_match = re.search(r'\$[\d,]+\.?\d*', text)
                if price_match:
                    self.current_product['price'] = price_match.group()

                # First try to find SKU with label - allow for 6 or 7 digits with various suffixes
                sku_match = re.search(r'SKU:\s*(\d{6,7}(?:[A-Z]|-[A-Z0-9]+)?)', text, re.IGNORECASE)
                if sku_match:
                    self.current_product['sku'] = sku_match.group(1)
                else:
                    # Fallback to finding 6 or 7 digit code
                    sku_match = re.search(r'\b\d{6,7}(?:[A-Z]|-[A-Z0-9]+)?\b', text)
                    if sku_match:
                        self.current_product['sku'] = sku_match.group()

                self.products.append(self.current_product)
                self.seen_urls.add(self.current_product['url'])

            self.current_product = None
            self.in_product_link = False
            self.current_text = []


def scrape_collection(base_url, collection_name, test_mode=False, max_items=None):
    """
    Scrapes products from a Frantz Art Glass collection

    Args:
        base_url: The collection URL (e.g., https://www.frantzartglass.com/collections/effetre)
        collection_name: Name of collection for logging (e.g., "Effetre", "Vetrofond")
        test_mode: If True, only scrape the first page
        max_items: If set, stop after scraping this many items

    Returns:
        List of product dictionaries with manufacturer_code field set
    """
    # Determine manufacturer code from collection name
    if 'vetrofond' in collection_name.lower():
        manufacturer_code = 'VF'
    else:
        manufacturer_code = 'EF'

    print(f"\nScraping {collection_name} products (Code: {manufacturer_code}, COE: 104)...")

    all_products = []
    seen_skus = {}
    duplicates = []
    page = 1

    while True:
        print(f"  Fetching page {page}...")

        # Frantz uses ?page= or &page= for pagination depending on existing query params
        if page > 1:
            # Check if base_url already has query parameters
            if '?' in base_url:
                url = f"{base_url}&page={page}"
            else:
                url = f"{base_url}?page={page}"
        else:
            url = base_url

        try:
            req = urllib.request.Request(url)
            req.add_header('User-Agent', 'Mozilla/5.0')

            with urllib.request.urlopen(req, timeout=10) as response:
                html_content = response.read().decode('utf-8')

            parser = ProductParser()
            parser.feed(html_content)

            products_found = len(parser.products)

            # URLs to exclude (non-glass products)
            excluded_urls = [
                '/products/mini-cc',
                '/products/bobcat-torch-head'
            ]

            for product in parser.products:
                if test_mode and len(all_products) >= 1:
                    break

                # Skip excluded products
                if any(excluded in product['url'] for excluded in excluded_urls):
                    print(f"    SKIPPING excluded product: {product['url']}")
                    continue

                # Fetch description and SKU from detail page
                description, image_url, sku_from_detail = fetch_product_description(
                    product['url'],
                    product['name']
                )

                # For Effetre and Vetrofond, don't save descriptions
                product['manufacturer_description'] = ''
                product['image_url'] = image_url

                # Ensure manufacturer_url is absolute
                url = product['url']
                if url.startswith('/'):
                    product['manufacturer_url'] = f"https://www.frantzartglass.com{url}"
                elif url.startswith('http://') or url.startswith('https://'):
                    product['manufacturer_url'] = url
                else:
                    # Shouldn't happen, but handle relative URLs without leading slash
                    product['manufacturer_url'] = f"https://www.frantzartglass.com/{url}"

                product['manufacturer_code'] = manufacturer_code

                # Check for SKU override first (highest priority)
                product_url_path = product['url'].split('?')[0]  # Remove query params for matching
                if product_url_path in SKU_OVERRIDES:
                    product['sku'] = SKU_OVERRIDES[product_url_path]
                    print(f"    SKU OVERRIDE: Using forced SKU {product['sku']} for {product_url_path}")
                else:
                    # Update SKU from detail page if found
                    if sku_from_detail:
                        product['sku'] = sku_from_detail

                    # For Effetre products, remove dash and two digits suffix if present
                    if manufacturer_code == 'EF' and product.get('sku'):
                        product['sku'] = re.sub(r'-\d{2}$', '', product['sku'])

                        # Special handling for Millefiori (SKU 114153): append cleaned name
                        if product['sku'] == '114153':
                            # Remove "Glass" from name, then remove all dashes and spaces, lowercase
                            cleaned_for_sku = re.sub(r'\bGlass\b', '', product['name'], flags=re.IGNORECASE)
                            cleaned_for_sku = re.sub(r'[-\s]+', '', cleaned_for_sku).lower()
                            product['sku'] = f"114153{cleaned_for_sku}"
                            print(f"    MILLEFIORI: Generated unique SKU {product['sku']} from {product['name']}")

                # Apply stock_type override if configured
                if product_url_path in STOCK_TYPE_OVERRIDES:
                    product['stock_type'] = STOCK_TYPE_OVERRIDES[product_url_path]
                    print(f"    STOCK_TYPE OVERRIDE: Using {product['stock_type']} for {product_url_path}")
                else:
                    product['stock_type'] = ''  # Default to empty

                # Check for duplicates by SKU (for reporting only - don't skip)
                current_sku = product.get('sku')
                if current_sku and current_sku in seen_skus:
                    duplicate_info = {
                        'sku': current_sku,
                        'original_name': seen_skus[current_sku]['name'],
                        'original_url': seen_skus[current_sku]['url'],
                        'name': product['name'],
                        'url': product['url']
                    }
                    duplicates.append(duplicate_info)
                    print(f"    DUPLICATE FOUND: SKU {current_sku} (will be flagged by database update)")

                # Add to collections (including duplicates - let database updater handle them)
                if current_sku:
                    if current_sku not in seen_skus:
                        seen_skus[current_sku] = product
                all_products.append(product)

                if max_items and len(all_products) >= max_items:
                    print(f"  Reached max items limit ({max_items}), stopping.")
                    return all_products, duplicates

            if test_mode and len(all_products) >= 1:
                break

            print(f"    Found {products_found} products on page {page}")

            if products_found == 0:
                print("  No more products found.")
                break

            # Frantz collections tend to have ~50 products per page
            if products_found < 10:
                print("  Fewer products found, likely last page.")
                break

            page += 1
            time.sleep(get_page_delay(MANUFACTURER_CODE))

        except Exception as e:
            print(f"  Error fetching page {page}: {e}")
            break

    print(f"  Total products found for {collection_name}: {len(all_products)}")
    return all_products, duplicates


def scrape(test_mode=False, max_items=None):
    """
    Module interface for combined scraper.
    Scrapes both Effetre and Vetrofond collections.

    Args:
        test_mode (bool): If True, limit to 2-3 items for testing
        max_items (int): Maximum items to scrape (overrides test_mode)

    Returns:
        tuple: (products_list, duplicates_list)
    """
    print(f"\n{'='*60}")
    print(f"Scraping {MANUFACTURER_NAME}")
    print(f"{'='*60}")

    collections = [
        {
            'url': 'https://www.frantzartglass.com/collections/effetre?filter.v.option.diameter=Regular+Size+Rods&sort_by=best-selling',
            'name': 'Effetre'
        },
        {
            'url': 'https://www.frantzartglass.com/collections/vetrofond?filter.v.option.diameter=Regular+Size+Rods&sort_by=best-selling',
            'name': 'Vetrofond'
        }
    ]

    all_products = []
    all_duplicates = []

    for collection in collections:
        products, duplicates = scrape_collection(
            collection['url'],
            collection['name'],
            test_mode=test_mode,
            max_items=max_items
        )
        all_products.extend(products)
        all_duplicates.extend(duplicates)

        if test_mode and len(all_products) >= 3:
            break
        if max_items and len(all_products) >= max_items:
            break

    return all_products, all_duplicates


def format_products_for_csv(products):
    """Format products for CSV output"""
    csv_rows = []

    for product in products:
        product_type = determine_product_type(product['name'])

        # Get manufacturer code from product (set during scraping)
        manufacturer_code = product.get('manufacturer_code', 'EF')

        cleaned_name = remove_brand_from_title(product['name'], manufacturer_code)
        code = product.get('sku', '')

        # Ensure code has manufacturer prefix
        if code and not code.upper().startswith(f"{MANUFACTURER_CODE}-"):
            code = f"{MANUFACTURER_CODE}-{code}"

        # Use combine_tags with both name and description
        tags = combine_tags(
            product_name=cleaned_name,
            description=product.get('manufacturer_description', ''),
            manufacturer_url=product.get('manufacturer_url', ''),
            manufacturer_code=manufacturer_code
        )

        csv_rows.append({
            'manufacturer': manufacturer_code,
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
            'stock_type': product.get('stock_type', '')
        })

    return csv_rows

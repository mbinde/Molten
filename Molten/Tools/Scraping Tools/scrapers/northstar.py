#!/usr/bin/env python3
"""
NorthStar Glassworks Scraper
=============================

Scrapes NorthStar (NS-xxx) products from northstarglass.com.
Platform: WooCommerce (WordPress)

URL: https://northstarglass.com/shop/
Note: This scraper gets NS-xxx products. TAG products from the same site
are handled by the tag.py scraper.
"""

import urllib.request
import urllib.error
import urllib.parse
import re
import time
import html.parser
import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from color_extractor import combine_tags
from scraper_config import get_page_delay, get_product_delay, is_bot_protection_error


# Constants
MANUFACTURER_CODE = 'NS'
MANUFACTURER_NAME = 'NorthStar Glassworks'
COE = '104'  # NorthStar is COE 104


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

            # Skip placeholder, icon, logo, banner, header images
            skip_terms = ['icon', 'logo', '_small', '_thumb', 'placeholder', 'default', 'no-image',
                         'avatar', 'banner', 'header', 'footer', 'badge', 'payment', '-150x150', '-300x300']
            if any(term in src.lower() for term in skip_terms):
                return

            # Check if this is in a product gallery/image container
            in_product_gallery = False
            if 'class' in attrs_dict:
                class_str = attrs_dict['class'].lower()
                # WooCommerce specific classes for main product images
                if any(term in class_str for term in ['woocommerce-product-gallery__image', 'wp-post-image',
                                                       'attachment-woocommerce_single', 'product-main-image']):
                    in_product_gallery = True

            # Check if this looks like a product image from wp-content/uploads
            is_wordpress_image = 'wp-content/uploads' in src

            # For WooCommerce, prioritize images that are explicitly in the product gallery
            # OR high-quality WordPress uploads
            is_better_quality = any(term in src for term in ['-scaled', '-1024x1024', '-2048x', 'woocommerce_single'])

            # Only accept image if it's in product gallery OR it's a high quality WordPress image
            if in_product_gallery or (is_wordpress_image and is_better_quality):
                # If we find an image in the product gallery, always use it
                if in_product_gallery or not self.image_url or is_better_quality:
                    if src.startswith('//'):
                        self.image_url = 'https:' + src
                    elif src.startswith('http'):
                        self.image_url = src
                    elif src.startswith('/'):
                        self.image_url = 'https://northstarglass.com' + src

    def handle_data(self, data):
        text = data.strip()
        if text:
            self.all_text.append(text)

        if self.in_heading and text:
            # Skip headings that start with SKU
            starts_with_sku = re.match(r'^NS-\d+', text, re.IGNORECASE)
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
        # First try to find SKU with label - NS-xxx format
        sku_match = re.search(r'SKU:\s*(NS-\d+(?:[A-Za-z]|-[A-Za-z0-9]+)?)', full_text, re.IGNORECASE)
        if sku_match:
            return sku_match.group(1).upper()
        # Fallback to finding NS-xxx code in text
        sku_match = re.search(r'\bNS-\d+(?:[A-Za-z]|-[A-Za-z0-9]+)?\b', full_text, re.IGNORECASE)
        if sku_match:
            return sku_match.group().upper()
        return ""

    def get_description(self):
        """Extract and clean description from collected text"""
        if self.description_texts:
            full_text = ' '.join(self.description_texts)
            full_text = re.sub(r'\s+', ' ', full_text).strip()
        else:
            # Fallback to all paragraphs if no description section found
            relevant_paragraphs = []
            for para in self.all_paragraphs:
                # Skip short paragraphs and common boilerplate
                if len(para) < 20:
                    continue
                if any(skip in para.lower() for skip in ['add to cart', 'select options', 'category:', 'tags:']):
                    continue
                relevant_paragraphs.append(para)

            full_text = ' '.join(relevant_paragraphs)

        # Remove common WooCommerce UI text that appears in descriptions
        stop_phrases = [
            'Add to cart',
            'Select options',
            'Read more',
            'Categories:',
            'Category:',
            'Tags:',
            'Related products',
            'You may also like',
            'Share:',
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

        # Remove form validation boilerplate text
        boilerplate = "This field is for validation purposes and should be left unchanged."
        if boilerplate in description:
            description = description.replace(boilerplate, '').strip()

        return description


class ProductParser(html.parser.HTMLParser):
    """HTML parser to extract product information from WooCommerce site"""
    def __init__(self):
        super().__init__()
        self.products = []
        self.current_product = None
        self.in_product_link = False
        self.in_product_title = False
        self.current_text = []
        self.seen_urls = set()
        self.depth = 0

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)

        # WooCommerce product links are typically in <a> tags with class containing 'product'
        if tag == 'a':
            href = attrs_dict.get('href', '')
            class_str = attrs_dict.get('class', '').lower()

            # Look for product links (WooCommerce uses 'woocommerce-LoopProduct-link' or similar)
            if 'product' in class_str and href and '/product/' in href:
                # Only capture NS-xxx products, skip TAG products
                if 'tag-' not in href.lower() and href not in self.seen_urls:
                    self.current_product = {'url': href, 'name': ''}
                    self.in_product_link = True
                    self.seen_urls.add(href)

        # Product titles are often in h2 or h3 within product links
        if self.in_product_link and tag in ['h2', 'h3', 'span']:
            class_str = attrs_dict.get('class', '').lower()
            if 'product' in class_str or 'title' in class_str or 'name' in class_str:
                self.in_product_title = True
                self.current_text = []

    def handle_data(self, data):
        if self.in_product_title:
            text = data.strip()
            if text:
                self.current_text.append(text)

    def handle_endtag(self, tag):
        if tag in ['h2', 'h3', 'span'] and self.in_product_title:
            if self.current_product and self.current_text:
                product_name = ' '.join(self.current_text).strip()
                # Only add if it starts with NS- (NorthStar products)
                if product_name.upper().startswith('NS-'):
                    self.current_product['name'] = product_name
                    self.products.append(self.current_product)
            self.in_product_title = False
            self.current_text = []

        if tag == 'a' and self.in_product_link:
            self.in_product_link = False
            self.current_product = None


def fetch_product_description(product_url, product_name):
    """Fetch and parse the product description and image from detail page"""
    try:
        full_url = product_url if product_url.startswith('http') else f"https://northstarglass.com{product_url}"

        print(f"  Fetching description from: {full_url}")

        req = urllib.request.Request(full_url)
        req.add_header('User-Agent', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36')

        with urllib.request.urlopen(req, timeout=10) as response:
            html_content = response.read().decode('utf-8')

        parser = DescriptionParser()
        parser.feed(html_content)
        description = parser.get_description()
        image_url = parser.image_url
        sku = parser.get_sku()

        time.sleep(get_product_delay(MANUFACTURER_CODE))

        return description, image_url, sku
    except Exception as e:
        print(f"  Error fetching description: {e}")
        return "", "", ""


def determine_product_type(product_name):
    """Determine the type of glass product from its name"""
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
        return 'rod'  # Default to 'rod' for NorthStar


def remove_brand_from_title(title):
    """Remove NorthStar brand name, SKU, and product type from product title"""

    original_title = title

    # Remove SKU prefix (e.g., "NS-83" from "NS-83 Skyline Rods")
    cleaned_title = re.sub(r'^NS-\d+[A-Z]?\s+', '', title, flags=re.IGNORECASE)

    # Remove brand patterns
    brand_patterns = ['NorthStar Glassworks', 'NorthStar', 'Northstar', 'NS']

    for pattern in brand_patterns:
        cleaned_title = re.sub(f'^{re.escape(pattern)}\\s+', '', cleaned_title, flags=re.IGNORECASE)
        cleaned_title = re.sub(f'\\b{re.escape(pattern)}\\b\\s*', '', cleaned_title, flags=re.IGNORECASE)

    cleaned_title = re.sub(r'\bGlass Rods?\b\s*', '', cleaned_title, flags=re.IGNORECASE)

    # Remove product type terms
    type_patterns = [r'\bRods?\b', r'\bFrit\b', r'\bPowder\b', r'\bSheet\b',
                    r'\bStringers?\b', r'\bTubes?\b', r'\bTubing\b']

    for pattern in type_patterns:
        cleaned_title = re.sub(pattern, '', cleaned_title, flags=re.IGNORECASE)

    # Remove COE references
    cleaned_title = re.sub(r'\bCOE\s*33\b', '', cleaned_title, flags=re.IGNORECASE)
    cleaned_title = re.sub(r'\bCOE\s*104\b', '', cleaned_title, flags=re.IGNORECASE)

    # Clean up extra whitespace and dashes
    cleaned_title = re.sub(r'\s*[-–]\s*', ' ', cleaned_title)
    cleaned_title = re.sub(r'\s+', ' ', cleaned_title).strip()

    # If nothing left after cleaning, return original title
    if not cleaned_title:
        return original_title

    return cleaned_title


def scrape_northstar_products(test_mode=False, max_items=None):
    """
    Scrape NorthStar products using WooCommerce Store API.

    Args:
        test_mode: If True, limit to 2-3 items for testing
        max_items: Maximum items to scrape

    Returns:
        tuple: (products_list, duplicates_list)
    """
    import json

    all_products = []
    seen_skus = {}
    duplicates = []
    page = 1
    per_page = 100  # WooCommerce API typically allows up to 100 per page

    try:
        while True:
            url = f"https://northstarglass.com/wp-json/wc/store/products?per_page={per_page}&page={page}"
            print(f"  Fetching page {page}...")

            req = urllib.request.Request(url)
            req.add_header('User-Agent', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36')

            with urllib.request.urlopen(req, timeout=15) as response:
                json_content = response.read().decode('utf-8')
                products_data = json.loads(json_content)

            if not products_data:
                print(f"  No more products found")
                break

            print(f"    Found {len(products_data)} products on page {page}")

            for product_data in products_data:
                product_name = product_data.get('name', '')
                sku = product_data.get('sku', '')

                # Only process NorthStar products (NS-xxx), skip TAG products
                if not product_name.upper().startswith('NS-'):
                    continue

                # Skip unwanted products
                skip_terms = ['bundle', 'bag of bits', 'scrap', 'gift card',
                             'sticker', 'shirt', 't-shirt', 'hoodie', 'hat', 'cap']
                if any(term in product_name.lower() for term in skip_terms):
                    print(f"    Skipping: {product_name}")
                    continue

                # Get description (prefer long description, fall back to short)
                description = product_data.get('description', '')
                if not description:
                    description = product_data.get('short_description', '')
                # Clean HTML tags from description
                description = re.sub(r'<[^>]+>', '', description)
                description = re.sub(r'\s+', ' ', description).strip()

                # Get image URL
                image_url = ''
                images = product_data.get('images', [])
                if images:
                    image_url = images[0].get('src', '')

                # Get product URL
                permalink = product_data.get('permalink', '')

                # Extract SKU from name if not in data
                if not sku:
                    sku_match = re.search(r'NS-\d+[A-Z]?', product_name, re.IGNORECASE)
                    if sku_match:
                        sku = sku_match.group().upper()

                product = {
                    'name': product_name,
                    'sku': sku,
                    'manufacturer_url': permalink,
                    'manufacturer_description': description,
                    'image_url': image_url
                }

                # Check for duplicates by SKU
                if sku and sku in seen_skus:
                    duplicates.append({
                        'sku': sku,
                        'name': product_name,
                        'url': permalink,
                        'original_name': seen_skus[sku]['name'],
                        'original_url': seen_skus[sku]['url']
                    })
                    print(f"    Skipping duplicate SKU: {sku}")
                else:
                    if sku:
                        seen_skus[sku] = {'name': product_name, 'url': permalink}
                    all_products.append(product)

                # Check limits
                if test_mode and len(all_products) >= 3:
                    print(f"  Test mode: reached 3 products")
                    return all_products, duplicates
                if max_items and len(all_products) >= max_items:
                    print(f"  Reached max items limit ({max_items})")
                    return all_products, duplicates

            # Check if there are more pages
            if len(products_data) < per_page:
                break

            page += 1
            time.sleep(get_page_delay(MANUFACTURER_CODE))

        return all_products, duplicates

    except urllib.error.HTTPError as e:
        if is_bot_protection_error(e):
            print(f"  ⚠️  Bot protection detected (HTTP {e.code})")
            print(f"  ⚠️  Cannot scrape - site is blocking requests")
            return None, None
        else:
            raise
    except Exception as e:
        print(f"Error scraping NorthStar products: {e}")
        raise


# ===== MODULE INTERFACE FUNCTIONS =====

def scrape(test_mode=False, max_items=None):
    """
    Module interface for combined scraper.

    Args:
        test_mode: If True, limit to 2-3 items for testing
        max_items: Maximum items to scrape

    Returns:
        tuple: (products_list, duplicates_list)
    """
    print(f"\n{'='*60}")
    print(f"Scraping {MANUFACTURER_NAME} ({MANUFACTURER_CODE})")
    print(f"{'='*60}")

    # Scrape using WooCommerce Store API
    products, duplicates = scrape_northstar_products(test_mode=test_mode, max_items=max_items)

    # If bot protection detected, return None
    if products is None:
        return None, None

    return products, duplicates


def format_products_for_csv(products):
    """Format products for CSV output"""
    csv_rows = []

    for product in products:
        product_type = determine_product_type(product['name'])
        cleaned_name = remove_brand_from_title(product['name'])
        code = product.get('sku', '')

        # Ensure code has manufacturer prefix
        if code and not code.upper().startswith(f"{MANUFACTURER_CODE}-"):
            code = f"{MANUFACTURER_CODE}-{code}"

        # Tags are handled by the tag analysis system, not scrapers
        tags = ''

        csv_rows.append({
            'manufacturer': MANUFACTURER_CODE,
            'product_type': 'glass',
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
            'image_url': product.get('image_url', ''),
            'stock_type': ''
        })

    return csv_rows


if __name__ == '__main__':
    # Test the scraper
    products, dupes = scrape(test_mode=True)

    if products is None:
        print("\n❌ Scrape failed due to bot protection")
    else:
        print(f"\nTest results: {len(products)} products")
        if dupes:
            print(f"Duplicates found: {len(dupes)}")

        if products:
            print("\nSample product:")
            sample = format_products_for_csv([products[0]])[0]
            for key, value in sample.items():
                print(f"  {key}: {value}")

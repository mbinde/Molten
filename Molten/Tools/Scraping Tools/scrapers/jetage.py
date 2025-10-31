#!/usr/bin/env python3
"""
Jet Age Studio (Lumiere Lusters) Scraper

Scrapes Lumiere Luster coating products (metallic flakes, chameleon pigments, etc.)
from Jet Age Studio's Etsy Pattern shop.

Manufacturer: Jet Age Studio
Product Type: Coatings (lusters, flakes)
Website: https://jetagestudio.com/
"""

import urllib.request
import urllib.error
import urllib.parse
import re
import time
import html.parser
import json
import sys

# Manufacturer constants
MANUFACTURER_CODE = 'JET'
MANUFACTURER_NAME = 'Jet Age Studio'
PRODUCT_TYPE = 'coating'

# Collection URL for Lumiere Luster Flakes
BASE_COLLECTION_URL = 'https://jetagestudio.com/shop/23680180/lumiere-luster-flakes'

# Rate limiting
PAGE_DELAY = 2.0  # Seconds between page requests
PRODUCT_DELAY = 1.0  # Seconds between product requests


class ProductLinkParser(html.parser.HTMLParser):
    """Parser to extract product links from listing pages"""

    def __init__(self):
        super().__init__()
        self.product_links = []

    def handle_starttag(self, tag, attrs):
        if tag == 'a':
            attrs_dict = dict(attrs)
            if 'href' in attrs_dict:
                href = attrs_dict['href']
                if '/listing/' in href:
                    # Fix double-slash issue
                    href = href.replace('//jetagestudio.com/', '/')
                    if not href.startswith('http'):
                        href = 'https://jetagestudio.com' + href
                    self.product_links.append(href)


class ProductDetailParser(html.parser.HTMLParser):
    """Parser to extract product details from detail pages"""

    def __init__(self):
        super().__init__()
        self.product_data = {
            'name': None,
            'description': '',
            'image_url': None,
            'listing_id': None
        }
        self.current_tag = None
        self.in_script = False
        self.in_heading = False

    def handle_starttag(self, tag, attrs):
        self.current_tag = tag
        attrs_dict = dict(attrs)

        # Skip script/style tags
        if tag in ['script', 'style']:
            self.in_script = True
            return

        # Track heading tags for name extraction fallback
        if tag in ['h1', 'h2']:
            self.in_heading = True

        # Extract listing ID from meta tags
        if tag == 'meta':
            if attrs_dict.get('property') == 'og:url':
                content = attrs_dict.get('content', '')
                match = re.search(r'/listing/(\d+)', content)
                if match:
                    self.product_data['listing_id'] = match.group(1)

            # Try to extract description from meta description
            if attrs_dict.get('name') == 'description' or attrs_dict.get('property') == 'og:description':
                desc = attrs_dict.get('content', '').strip()
                if desc and len(desc) > len(self.product_data['description']):
                    self.product_data['description'] = desc

        # Extract main product image
        if tag == 'img':
            if 'i.etsystatic.com' in attrs_dict.get('src', ''):
                if not self.product_data['image_url']:
                    self.product_data['image_url'] = attrs_dict['src']

    def handle_endtag(self, tag):
        if tag in ['script', 'style']:
            self.in_script = False
        if tag in ['h1', 'h2']:
            self.in_heading = False

    def handle_data(self, data):
        # Skip script/style content
        if self.in_script:
            return

        text = data.strip()
        if not text:
            return

        # Extract product name from title tag (preferred)
        if self.current_tag == 'title' and not self.product_data['name']:
            # Clean up title (remove site suffix)
            name = text.split('|')[0].strip()
            # Skip generic site names
            if 'JetAgeStudio' in name or 'Jet Age Studio' in name:
                return
            # Remove extra spaces
            name = re.sub(r'\s+', ' ', name)
            if name and len(name) > 5:  # Avoid very short generic text
                self.product_data['name'] = name

        # Fallback: Extract from heading tags if no title found
        if self.in_heading and not self.product_data['name']:
            # Skip generic headings
            if 'shop' in text.lower() or 'menu' in text.lower():
                return
            # Clean up heading
            name = text.strip()
            name = re.sub(r'\s+', ' ', name)
            # Only accept if it looks like a product name (has "Flake", "Luster", or descriptive words)
            if name and len(name) > 10 and ('-' in name or 'Flake' in name or 'Luster' in name):
                self.product_data['name'] = name


def fetch_page(url, delay=PAGE_DELAY):
    """Fetch a page with rate limiting"""
    time.sleep(delay)
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'})

    try:
        with urllib.request.urlopen(req, timeout=15) as response:
            return response.read().decode('utf-8')
    except Exception as e:
        print(f"  Error fetching {url}: {e}", file=sys.stderr)
        return None


def get_all_product_links(test_mode=False, max_items=None):
    """
    Get all product links from all pages of the Lumiere Luster collection

    Args:
        test_mode: If True, only scrape page 1
        max_items: Maximum number of product links to return

    Returns:
        List of product URLs
    """
    product_links = []
    page = 1

    while True:
        if test_mode and page > 1:
            break

        url = f"{BASE_COLLECTION_URL}?page={page}" if page > 1 else BASE_COLLECTION_URL
        print(f"  Fetching listing page {page}...", file=sys.stderr)

        html = fetch_page(url)
        if not html:
            break

        parser = ProductLinkParser()
        parser.feed(html)

        if not parser.product_links:
            # No more products, we've reached the end
            break

        # Remove duplicates while preserving order
        new_links = []
        for link in parser.product_links:
            if link not in product_links and link not in new_links:
                new_links.append(link)

        product_links.extend(new_links)

        print(f"  Found {len(new_links)} products on page {page} (total: {len(product_links)})", file=sys.stderr)

        # Check if we have fewer than 20 products - means last page
        if len(new_links) < 20:
            break

        # Check max_items limit
        if max_items and len(product_links) >= max_items:
            product_links = product_links[:max_items]
            break

        page += 1

    return product_links


def scrape_product(url):
    """
    Scrape a single product detail page

    Args:
        url: Product detail page URL

    Returns:
        Dictionary with product data or None if failed
    """
    html = fetch_page(url, delay=PRODUCT_DELAY)
    if not html:
        return None

    parser = ProductDetailParser()
    parser.feed(html)

    data = parser.product_data

    # Fallback: Extract listing ID from URL if not found in page
    if not data['listing_id']:
        match = re.search(r'/listing/(\d+)', url)
        if match:
            data['listing_id'] = match.group(1)

    # Validate we got essential data
    if not data['name'] or not data['listing_id']:
        print(f"  Warning: Missing essential data for {url}", file=sys.stderr)
        print(f"    Found name: {data['name']}, listing_id: {data['listing_id']}", file=sys.stderr)
        return None

    return {
        'listing_id': data['listing_id'],
        'name': data['name'],
        'description': data['description'].strip(),
        'image_url': data['image_url'] or '',
        'manufacturer_url': url,
        'product_type': PRODUCT_TYPE
    }


def clean_product_name(name):
    """Clean product name by removing brand prefixes and redundant text"""
    # Remove "- Lumiere Lusters" from name (keep space before dash)
    name = re.sub(r'\s*-\s*Lumiere Lusters?\s*', ' ', name, flags=re.IGNORECASE)

    # Remove trailing descriptive phrases (everything after the base name)
    name = re.sub(r'\s+(Transparent|Opaque|Color\s+Changing|Color\s+Shifting|Chameleon|Metallic|Foil|Dichroic|Art\s+Flake|Art\s+Pigment).*$', '', name, flags=re.IGNORECASE)

    # Clean up multiple spaces
    name = re.sub(r'\s+', ' ', name).strip()

    return name


def scrape(test_mode=False, max_items=None):
    """
    Scrape Jet Age Studio Lumiere Luster products

    Args:
        test_mode: If True, limit to first page (2-3 items)
        max_items: Maximum items to scrape (overrides test_mode)

    Returns:
        tuple: (products_list, duplicates_list)
    """
    print(f"Scraping {MANUFACTURER_NAME} ({MANUFACTURER_CODE})", file=sys.stderr)

    # Get all product links
    product_links = get_all_product_links(test_mode=test_mode, max_items=max_items)
    print(f"  Found {len(product_links)} total products to scrape", file=sys.stderr)

    products = []
    duplicates = []
    seen_codes = set()

    for i, url in enumerate(product_links, 1):
        print(f"  [{i}/{len(product_links)}] Scraping product...", file=sys.stderr)

        product = scrape_product(url)
        if not product:
            continue

        # Check for duplicates
        code = product['listing_id']
        if code in seen_codes:
            duplicates.append(product)
            print(f"  Warning: Duplicate listing ID {code}", file=sys.stderr)
            continue

        seen_codes.add(code)
        products.append(product)

    print(f"  Scraped {len(products)} products ({len(duplicates)} duplicates)", file=sys.stderr)
    return products, duplicates


def format_products_for_csv(products):
    """
    Format products into CSV-ready dictionaries

    Args:
        products: List of product dictionaries from scrape()

    Returns:
        List of CSV-ready dictionaries
    """
    csv_rows = []

    for product in products:
        cleaned_name = clean_product_name(product['name'])
        code = product['listing_id']

        # Extract tags from name/description
        tags = ''  # Tags handled by tag analysis system

        csv_rows.append({
            'manufacturer': MANUFACTURER_CODE,
            'product_type': PRODUCT_TYPE,
            'code': code,
            'name': cleaned_name,
            'start_date': '',
            'end_date': '',
            'manufacturer_description': product['description'],
            'tags': tags,
            'synonyms': '',
            'coe': '',  # Not applicable for coatings
            'type': 'luster',  # Product form: luster flakes
            'manufacturer_url': product['manufacturer_url'],
            
            'image_url': product['image_url'],
            'stock_type': ''  # Could parse from page if needed
        })

    return csv_rows


def extract_tags(name, description):
    """
    Extract color and effect tags from product name and description

    Args:
        name: Product name
        description: Product description

    Returns:
        Comma-separated quoted tags (e.g., '"blue", "chameleon"')
    """
    tags = set()
    text = (name + ' ' + description).lower()

    # Color keywords
    colors = ['red', 'orange', 'yellow', 'green', 'blue', 'purple', 'pink',
              'black', 'white', 'gold', 'silver', 'copper', 'bronze']
    for color in colors:
        if color in text:
            tags.add(color)

    # Effect keywords
    effects = ['chameleon', 'holographic', 'metallic', 'opal', 'aurora',
               'color shifting', 'color changing', 'iridescent', 'dichroic']
    for effect in effects:
        if effect in text:
            tags.add(effect.replace(' ', '_'))

    # Return sorted, quoted tags
    if tags:
        sorted_tags = sorted(tags)
        return ', '.join(f'"{tag}"' for tag in sorted_tags)
    return '"luster"'  # Default tag


if __name__ == "__main__":
    # Test the scraper
    products, duplicates = scrape(test_mode=True)
    print(f"\nScraped {len(products)} products")

    if products:
        csv_products = format_products_for_csv(products)
        print(f"\nSample product:")
        print(json.dumps(csv_products[0], indent=2))

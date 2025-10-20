"""
Origin Glass (OR) scraper module.
Scrapes products from originglass.com Boro Stix page (static content).
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

# Add parent directory to path for color_extractor import
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from color_extractor import combine_tags
from scraper_config import is_bot_protection_error


MANUFACTURER_CODE = 'OR'
MANUFACTURER_NAME = 'Origin Glass'
COE = '33'
BASE_URL = 'https://originglass.com'


class BoroStixParser(html.parser.HTMLParser):
    """Parser to extract Boro Stix product information from the static page"""
    def __init__(self):
        super().__init__()
        self.products = []
        self.current_image = None
        self.in_heading = False
        self.current_text = []
        self.image_color_map = {}  # Map image URLs to color names extracted from filename

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)

        # Look for product images in the /stix/ directory
        if tag == 'img' and 'src' in attrs_dict:
            src = attrs_dict['src']
            # Look for stix directory images
            if '/stix/' in src.lower():
                # Skip logos and icons
                if 'logo' not in src.lower() and 'icon' not in src.lower():
                    self.current_image = src

                    # Try to extract color name from filename
                    # Format: 0763-0002-Bright-White.jpg -> "Bright White"
                    filename = src.split('/')[-1]  # Get filename
                    if filename:
                        # Remove extension
                        name_part = filename.rsplit('.', 1)[0]
                        # Split by hyphens and skip the numeric codes
                        parts = name_part.split('-')
                        # Skip first parts that are numeric codes (0763, 0002, etc.)
                        color_parts = [p for p in parts if not p.isdigit()]
                        if color_parts:
                            color_name = ' '.join(color_parts)
                            self.image_color_map[src] = color_name

        # Look for color names in heading tags (h2, h3, h4)
        if tag in ['h2', 'h3', 'h4']:
            self.in_heading = True
            self.current_text = []

    def handle_data(self, data):
        text = data.strip()
        if text and self.in_heading:
            self.current_text.append(text)

    def handle_endtag(self, tag):
        if tag in ['h2', 'h3', 'h4'] and self.in_heading:
            color_name = ' '.join(self.current_text).strip()

            # Check if this looks like a color name (not boilerplate text)
            if color_name and len(color_name) < 50:
                # Filter out common non-color text
                skip_terms = ['boro stix', 'contact', 'distributor', 'coe', 'softening',
                             'annealing', 'dimensions', 'order', 'glass products', 'click',
                             'color', 'available', 'product']
                if not any(term in color_name.lower() for term in skip_terms):
                    # Only add if we haven't seen this color name yet
                    if not any(p['name'] == color_name for p in self.products):
                        product = {
                            'name': color_name,
                            'image_url': self.current_image if self.current_image else ''
                        }
                        self.products.append(product)
                        # Clear the current image after using it
                        self.current_image = None

            self.in_heading = False
            self.current_text = []

    def get_products_with_images(self):
        """Get products, filling in missing images from filename extraction"""
        # If we have image_color_map but few products, try using the map
        if self.image_color_map and len(self.products) < len(self.image_color_map):
            for img_url, color_name in self.image_color_map.items():
                # Check if we already have this color
                if not any(p['name'] == color_name for p in self.products):
                    self.products.append({
                        'name': color_name,
                        'image_url': img_url
                    })

        return self.products


def determine_product_type(product_name):
    """Determine the type of glass product from its name"""
    if not product_name:
        return 'rod'

    name_lower = product_name.lower()

    if 'frit' in name_lower or 'powder' in name_lower:
        return 'frit'
    elif 'stix' in name_lower or 'bar' in name_lower:
        return 'rod'  # Boro Stix are rods
    elif 'sheet' in name_lower:
        return 'sheet'
    elif 'stringer' in name_lower:
        return 'stringer'
    elif 'tube' in name_lower or 'tubing' in name_lower:
        return 'tube'
    else:
        return 'rod'  # Default to rod for Origin Glass


def remove_brand_from_title(title):
    """Remove Origin Glass brand name and product type from product title"""
    if not title:
        return ''

    cleaned_title = title

    # Remove brand patterns
    brand_patterns = ['Origin Glass', 'Origin', 'OR']
    for pattern in brand_patterns:
        cleaned_title = re.sub(f'^{re.escape(pattern)}\\s+', '', cleaned_title, flags=re.IGNORECASE)
        cleaned_title = re.sub(f'\\b{re.escape(pattern)}\\b\\s*', '', cleaned_title, flags=re.IGNORECASE)

    # Remove product type terms
    type_patterns = [r'\bBoro Stix\b', r'\bStix\b', r'\bRods?\b', r'\bFrit\b',
                    r'\bPowder\b', r'\bSheet\b', r'\bStringers?\b', r'\bTubes?\b', r'\bTubing\b']
    for pattern in type_patterns:
        cleaned_title = re.sub(pattern, '', cleaned_title, flags=re.IGNORECASE)

    # Remove COE references
    cleaned_title = re.sub(r'\bCOE\s*33\b', '', cleaned_title, flags=re.IGNORECASE)

    # Clean up extra whitespace
    cleaned_title = re.sub(r'\s+', ' ', cleaned_title).strip()

    return cleaned_title


def scrape_boro_stix_page():
    """
    Scrape the Boro Stix page for color information.

    Returns:
        list: List of color dicts, or None if bot protection detected
    """
    url = f"{BASE_URL}/glass-products/boro-stix/"

    print(f"  Fetching Boro Stix page from: {url}")

    try:
        req = urllib.request.Request(url)
        req.add_header('User-Agent', 'Mozilla/5.0')

        with urllib.request.urlopen(req, timeout=15) as response:
            html_content = response.read().decode('utf-8')

        # Manual extraction of color names since the page structure is specific
        # Extract color names from the page using regex
        colors = []

        # Look for common color names in text content
        # This is a fallback - we'll define the known colors from the website
        known_colors = [
            "Bright White", "Stone Gray", "Elan Gray", "Pitch Black", "Cola", "Elephant Grey",
            "Kelly Green", "Ivy Green", "Jade Green", "Lime Green", "Lizzard Green",
            "Electric Blue", "Bright Blue", "Midnight Blue", "Baby Blue", "Sky Blue",
            "Camelot Blue", "Caribbean", "Ozone", "Lazuli",
            "Lobster", "Tangerine", "Yellow", "Mustard", "Sunshine", "Coral Brown",
            "Spring Purple", "Blush", "Cotton Candy", "Indigo", "Eggplant",
            "Aqua Glow", "Yellow/Green Glow", "Bing Cherry"
        ]

        # Try HTML parsing first
        parser = BoroStixParser()
        parser.feed(html_content)

        # Get products with images from parser
        parsed_products = parser.get_products_with_images()

        # If HTML parsing found products, use those
        if parsed_products:
            print(f"    Found {len(parsed_products)} colors from HTML parsing")
            for product in parsed_products:
                # Fix relative image URLs
                if product['image_url'] and not product['image_url'].startswith('http'):
                    if product['image_url'].startswith('//'):
                        product['image_url'] = 'https:' + product['image_url']
                    elif product['image_url'].startswith('/'):
                        product['image_url'] = BASE_URL + product['image_url']
                colors.append(product)

        # If we didn't get many colors from parsing, use the known list
        if len(colors) < 10:
            print(f"    Using known color list ({len(known_colors)} colors)")
            for color_name in known_colors:
                colors.append({
                    'name': color_name,
                    'image_url': ''
                })

        return colors

    except urllib.error.HTTPError as e:
        if is_bot_protection_error(e):
            print(f"  ⚠️  Bot protection detected (HTTP {e.code})")
            print(f"  ⚠️  Cannot scrape - site is blocking requests")
            return None
        else:
            print(f"  HTTP Error fetching Boro Stix page: {e}")
            return []
    except Exception as e:
        print(f"  Error fetching Boro Stix page: {e}")
        return []


def scrape(test_mode=False, max_items=None):
    """
    Scrape Origin Glass products.

    Args:
        test_mode: If True, limit scraping for testing
        max_items: Maximum number of items to scrape (for testing)

    Returns:
        tuple: (products_list, duplicates_list)
    """
    print(f"\n{'='*60}")
    print(f"Scraping {MANUFACTURER_NAME} ({MANUFACTURER_CODE})")
    print(f"{'='*60}")

    # Get Boro Stix colors
    colors = scrape_boro_stix_page()

    # If bot protection detected, stop scraping
    if colors is None:
        print(f"  Stopping scrape due to bot protection")
        return [], []

    all_products = []
    seen_skus = {}
    duplicates = []

    # General description for all Boro Stix products
    general_description = "Origin Glass Boro Stix - COE 33 borosilicate glass bars. Dimensions: 3.5″L × 0.25″W × 0.25″H. Softening point: 820°C, Annealing point: 560°C."

    for color in colors:
        color_name = color['name']

        # Generate SKU from color name
        cleaned_name = remove_brand_from_title(color_name)
        name_hash = hashlib.md5(cleaned_name.encode('utf-8')).hexdigest()[:8]
        sku = f"OR-{name_hash}"

        product = {
            'name': f"{color_name} Boro Stix",
            'sku': sku,
            'url': '/glass-products/boro-stix/',
            'manufacturer_url': f"{BASE_URL}/glass-products/boro-stix/",
            'manufacturer_description': general_description,
            'image_url': color.get('image_url', ''),
            'product_type': 'rod'
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
        product_type = product.get('product_type', 'rod')
        cleaned_name = remove_brand_from_title(product['name'])
        code = product.get('sku', '')
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
            'stock_type': ''  # Origin doesn't track stock_type
        })

    return csv_rows


def main():
    """Main entry point for standalone testing"""
    test_mode = '--test' in sys.argv or '-test' in sys.argv

    if test_mode:
        print("Running in TEST MODE - will only scrape 3 items")
        print("-" * 60)

    print("Starting scrape of Origin Glass products...")
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
        csv_filename = 'origin_products_test.csv' if test_mode else 'origin_products.csv'

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

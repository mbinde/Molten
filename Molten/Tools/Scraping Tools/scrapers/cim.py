"""
Creation is Messy (CIM) scraper module.
Scrapes products from creationismessy.com palette pages.
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


MANUFACTURER_CODE = 'CIM'
MANUFACTURER_NAME = 'Creation is Messy'
COE = '104'


class DescriptionParser(html.parser.HTMLParser):
    """Parser to extract product description and image from detail page"""
    def __init__(self):
        super().__init__()
        self.description = ""
        self.in_paragraph = False
        self.in_heading = False
        self.in_tester_feedback = False
        self.paragraph_texts = []
        self.all_paragraphs = []
        self.tester_feedback = []
        self.current_feedback = []
        self.image_url = ""
        self.sku = ""
        self.all_text = []

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)

        # Check for tester feedback sections (td with class="text")
        if tag == 'td' and 'class' in attrs_dict:
            if 'text' in attrs_dict['class'].lower():
                self.in_tester_feedback = True
                self.current_feedback = []

        if tag == 'p':
            self.in_paragraph = True
            self.paragraph_texts = []

        if tag in ['h1', 'h2', 'h3', 'h4', 'h5', 'h6']:
            self.in_heading = True

        if tag == 'img':
            src = attrs_dict.get('src', '')

            if not src:
                return

            should_capture = False
            if 'images/' in src.lower() or '/images/' in src.lower():
                should_capture = True

            if any(keyword in src.lower() for keyword in ['color', 'swatch', 'palette', 'glass', 'rod', 'bead']):
                should_capture = True

            if any(skip in src.lower() for skip in ['icon', 'logo', 'button', 'banner', 'header', 'footer', 'nav', 'menu']):
                should_capture = False

            if should_capture:
                if src.startswith('//'):
                    full_src = 'https:' + src
                elif src.startswith('http'):
                    full_src = src
                elif src.startswith('/'):
                    full_src = 'https://creationismessy.com' + src
                else:
                    full_src = 'https://creationismessy.com/' + src

                if not self.image_url or any(x in src.lower() for x in ['_large', '_grande', 'large', 'main']):
                    self.image_url = full_src

    def handle_data(self, data):
        text = data.strip()
        if text:
            self.all_text.append(text)

        if self.in_heading and text:
            starts_with_sku = re.match(r'^\d{6,7}\s', text)
            if starts_with_sku:
                return

        if self.in_paragraph and text:
            self.paragraph_texts.append(text)

        if self.in_tester_feedback and text:
            self.current_feedback.append(text)

    def handle_endtag(self, tag):
        if tag == 'p' and self.in_paragraph:
            para_text = ' '.join(self.paragraph_texts).strip()
            if para_text:
                # Filter out boilerplate and very short paragraphs
                if len(para_text) > 10 and not para_text.startswith('511'):
                    # Skip obvious boilerplate
                    skip_keywords = ['buy now', 'all messy colors available', 'most messy colors available',
                                   'join trudi doherty', 'click here for other interesting',
                                   'creation is messy, all rights reserved']
                    if not any(keyword in para_text.lower() for keyword in skip_keywords):
                        self.all_paragraphs.append(para_text)
            self.in_paragraph = False
            self.paragraph_texts = []

        if tag in ['h1', 'h2', 'h3', 'h4', 'h5', 'h6']:
            self.in_heading = False

        if tag == 'td' and self.in_tester_feedback:
            feedback_text = ' '.join(self.current_feedback).strip()
            if feedback_text and len(feedback_text) > 20:
                self.tester_feedback.append(feedback_text)
            self.in_tester_feedback = False
            self.current_feedback = []

    def get_sku(self):
        """Extract SKU from all collected text and remove 511 prefix"""
        full_text = ' '.join(self.all_text)
        sku_match = re.search(r'\b511(\d{4})\b', full_text)
        if sku_match:
            return sku_match.group(1)
        sku_match = re.search(r'\b511(\d{3})\b', full_text)
        if sku_match:
            return sku_match.group(1)
        sku_match = re.search(r'\b511(\d{3,4})\b', full_text)
        if sku_match:
            return sku_match.group(1)
        return ""

    def get_description(self):
        """Return the collected description text"""
        description_parts = []

        # Add main product paragraphs (usually the short description)
        if self.all_paragraphs:
            description_parts.extend(self.all_paragraphs)

        # Add just the first tester feedback
        # This gives the most relevant information without overwhelming
        if self.tester_feedback:
            description_parts.append(self.tester_feedback[0])

        return ' '.join(description_parts)


class ColorDetailParser(html.parser.HTMLParser):
    """HTML parser to extract color information from detail page"""
    def __init__(self):
        super().__init__()
        self.name = None
        self.sku = None
        self.description = None
        self.current_text = []
        self.in_heading = False
        self.all_text = []

    def handle_starttag(self, tag, attrs):
        if tag in ['h1', 'h2', 'h3']:
            self.in_heading = True
            self.current_text = []

    def handle_data(self, data):
        text = data.strip()
        if text:
            self.all_text.append(text)
            if self.in_heading:
                self.current_text.append(text)

    def handle_endtag(self, tag):
        if tag in ['h1', 'h2', 'h3'] and self.in_heading:
            heading_text = ' '.join(self.current_text)
            match = re.match(r'511(\d{4})\s*[-–]\s*(.+)', heading_text)
            if match and not self.name:
                self.sku = match.group(1)
                self.name = match.group(2).strip()
            else:
                match = re.match(r'511(\d{3})\s*[-–]\s*(.+)', heading_text)
                if match and not self.name:
                    self.sku = match.group(1)
                    self.name = match.group(2).strip()
                elif heading_text and not self.name:
                    self.name = heading_text
            self.in_heading = False
            self.current_text = []


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
        return 'rod'


def remove_brand_from_title(title):
    """Remove Creation is Messy brand name, SKU, and product type from product title"""
    if not title:
        return ''

    cleaned_title = re.sub(r'^\d{6,7}\s+[-–]\s+', '', title)
    cleaned_title = re.sub(r'^\d{6,7}\s+', '', cleaned_title)
    cleaned_title = cleaned_title.replace('™', '').replace('®', '').replace('©', '')

    brand_patterns = ['Creation is Messy', 'CiM', 'Messy Color', 'Messy']
    for pattern in brand_patterns:
        cleaned_title = re.sub(f'^{re.escape(pattern)}\\s+', '', cleaned_title, flags=re.IGNORECASE)
        cleaned_title = re.sub(f'\\b{re.escape(pattern)}\\b\\s*', '', cleaned_title, flags=re.IGNORECASE)

    cleaned_title = re.sub(r'\bGlass Rods?\b\s*', '', cleaned_title, flags=re.IGNORECASE)

    type_patterns = [r'\bRods?\b', r'\bFrit\b', r'\bPowder\b', r'\bSheet\b',
                    r'\bStringers?\b', r'\bTubes?\b', r'\bTubing\b']
    for pattern in type_patterns:
        cleaned_title = re.sub(pattern, '', cleaned_title, flags=re.IGNORECASE)

    cleaned_title = re.sub(r'\bLtd\.?\s*Run\b', '', cleaned_title, flags=re.IGNORECASE)
    cleaned_title = re.sub(r'\bLimited\s*Run\b', '', cleaned_title, flags=re.IGNORECASE)
    cleaned_title = re.sub(r'\bCOE\s*104\b', '', cleaned_title, flags=re.IGNORECASE)
    cleaned_title = re.sub(r'\s+[-–",]\s*', ' ', cleaned_title).strip()
    cleaned_title = ' '.join(cleaned_title.split())

    return cleaned_title.strip()


def clean_description(description):
    """
    Remove boilerplate text from CIM product descriptions.

    Args:
        description: Raw product description

    Returns:
        Cleaned description with boilerplate removed
    """
    if not description:
        return ''

    # Remove the item number at the start if present (e.g., "511309 - ")
    cleaned = re.sub(r'^\d{6,7}\s*[-–]\s*', '', description)

    # Remove the reseller boilerplate text (usually in the middle)
    # Pattern matches from "BUY NOW" through "Visit our complete reseller listing."
    reseller_patterns = [
        # Full pattern with both sections
        r'BUY NOW\s+All Messy Colors available at:.*?Visit our complete reseller listing\.',
        # Variation without "BUY NOW" prefix
        r'All Messy Colors available at:.*?Visit our complete reseller listing\.',
        # Just "Most Messy Colors" section if "All Messy Colors" is missing
        r'Most Messy Colors available at:.*?Visit our complete reseller listing\.',
    ]

    for pattern in reseller_patterns:
        cleaned = re.sub(pattern, '', cleaned, flags=re.IGNORECASE | re.DOTALL)

    # Remove the resources/copyright boilerplate at the end
    # Pattern starts with "Join Trudi Doherty's FB group" and ends with copyright
    resource_patterns = [
        # Full pattern with all resources and copyright
        r'Join Trudi Doherty\'s FB group.*?Creation is Messy,\s*All Rights Reserved',
        # Variation starting with any of the resource links
        r'(?:Join|Claudia Eidenbenz|See Kay Powell|Browse Serena|Check out Miriam|Consult Jolene).*?Creation is Messy,\s*All Rights Reserved',
        # Just the copyright line if resources are missing
        r'©\s*document\.write.*?Creation is Messy,\s*All Rights Reserved',
        r'©.*?Creation is Messy,\s*All Rights Reserved',
    ]

    for pattern in resource_patterns:
        cleaned = re.sub(pattern, '', cleaned, flags=re.IGNORECASE | re.DOTALL)

    # Clean up excessive whitespace
    cleaned = re.sub(r'\s+', ' ', cleaned).strip()

    return cleaned


def scrape_palette_page(palette_url, test_mode=False):
    """Scrapes product links from a CiM palette page"""
    print(f"  Scraping palette: {palette_url}")

    if 'palette.aspx?id=' not in palette_url.lower():
        print(f"    WARNING: Not a palette URL, skipping: {palette_url}")
        return []

    try:
        req = urllib.request.Request(palette_url)
        req.add_header('User-Agent', 'Mozilla/5.0')

        with urllib.request.urlopen(req, timeout=10) as response:
            html_content = response.read().decode('utf-8')

        color_pattern = r'color\.aspx\?id=(\d+)'
        matches = re.findall(color_pattern, html_content, re.IGNORECASE)

        seen_ids = set()
        valid_products = []

        for color_id in matches:
            if color_id not in seen_ids:
                seen_ids.add(color_id)
                full_url = f'https://creationismessy.com/color.aspx?id={color_id}'
                valid_products.append(full_url)

        print(f"    Found {len(valid_products)} unique color links")

        if test_mode and valid_products:
            return [valid_products[0]]

        return valid_products
    except Exception as e:
        print(f"    Error scraping palette: {e}")
        return []


def scrape_color_detail(color_url):
    """Scrapes details from a single color page"""
    if 'color.aspx?id=' not in color_url.lower():
        print(f"    WARNING: Not a color detail URL, skipping: {color_url}")
        return None

    try:
        req = urllib.request.Request(color_url)
        req.add_header('User-Agent', 'Mozilla/5.0')

        with urllib.request.urlopen(req, timeout=10) as response:
            html_content = response.read().decode('utf-8')

        parser = ColorDetailParser()
        parser.feed(html_content)

        desc_parser = DescriptionParser()
        desc_parser.feed(html_content)

        image_url = desc_parser.image_url
        if not image_url:
            img_patterns = [
                r'src=["\'](images/[^"\']+\.(?:jpg|jpeg|png|gif))["\']',
                r'src=["\'](/images/[^"\']+\.(?:jpg|jpeg|png|gif))["\']',
                r'src=["\'](https?://[^"\']*creationismessy[^"\']+\.(?:jpg|jpeg|png|gif))["\']'
            ]

            for pattern in img_patterns:
                matches = re.findall(pattern, html_content, re.IGNORECASE)
                if matches:
                    img_src = matches[0]
                    if img_src.startswith('http'):
                        image_url = img_src
                    elif img_src.startswith('/'):
                        image_url = 'https://creationismessy.com' + img_src
                    else:
                        image_url = 'https://creationismessy.com/' + img_src
                    break

        # Clean the description to remove boilerplate
        raw_description = desc_parser.get_description()
        cleaned_description = clean_description(raw_description)

        product = {
            'url': color_url,
            'name': parser.name,
            'sku': parser.sku or desc_parser.get_sku(),
            'manufacturer_description': cleaned_description,
            'image_url': image_url
        }

        time.sleep(get_page_delay(MANUFACTURER_CODE))
        return product
    except Exception as e:
        print(f"    Error scraping color detail: {e}")
        return None


def scrape(test_mode=False, max_items=None):
    """
    Scrape Creation is Messy products.

    Args:
        test_mode: If True, limit scraping for testing
        max_items: Maximum number of items to scrape (for testing)

    Returns:
        tuple: (products_list, duplicates_list)
    """
    print(f"\n{'='*60}")
    print(f"Scraping {MANUFACTURER_NAME} ({MANUFACTURER_CODE})")
    print(f"{'='*60}")

    palette_urls = [
        'https://creationismessy.com/palette.aspx?id=3',   # Reds
        'https://creationismessy.com/palette.aspx?id=4',   # Oranges
        'https://creationismessy.com/palette.aspx?id=5',   # Yellows
        'https://creationismessy.com/palette.aspx?id=6',   # Greens
        'https://creationismessy.com/palette.aspx?id=7',   # Blues
        'https://creationismessy.com/palette.aspx?id=8',   # Purples
        'https://creationismessy.com/palette.aspx?id=9',   # Browns
        'https://creationismessy.com/palette.aspx?id=10',  # Neutrals
        'https://creationismessy.com/palette.aspx?id=11',  # Pinks
    ]

    if test_mode:
        palette_urls = [palette_urls[0]]  # Just first palette in test mode

    all_products = []
    seen_skus = {}
    duplicates = []

    for palette_url in palette_urls:
        color_links = scrape_palette_page(palette_url, test_mode=test_mode)

        print(f"  Processing {len(color_links)} color links from this palette...")

        for color_link in color_links:
            product = scrape_color_detail(color_link)

            if product:
                sku = product.get('sku', '')

                if sku and sku in seen_skus:
                    duplicates.append({
                        'sku': sku,
                        'name': product.get('name', ''),
                        'url': product.get('url', ''),
                        'original_name': seen_skus[sku]['name'],
                        'original_url': seen_skus[sku]['url']
                    })
                    print(f"    DUPLICATE SKU found: {sku}")
                    continue

                if sku:
                    seen_skus[sku] = {
                        'name': product.get('name', ''),
                        'url': product.get('url', '')
                    }

                all_products.append(product)
                print(f"    Added: {product.get('name', 'Unknown')} ({sku})")

            if max_items and len(all_products) >= max_items:
                print(f"  Reached max items limit ({max_items})")
                return all_products, duplicates

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
        manufacturer_url = product.get('url', '')
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
            'manufacturer_url': product.get('url', ''),
            'image_path': '',
            'image_url': product.get('image_url', ''),
            'stock_type': ''  # CIM doesn't track stock_type
        })

    return csv_rows

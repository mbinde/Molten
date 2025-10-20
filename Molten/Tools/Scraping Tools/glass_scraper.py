import urllib.request
import urllib.parse
import re
import time
import html.parser
import sys
import json

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
        
        # Remove SKU/manufacturer sentences from end
        pattern3 = r'\s*[A-Z][a-zA-Z\s]+(?:Ltd Run|Limited Run)?\s+\d{6}\s+by\s+[A-Za-z\s]+\([A-Za-z]+\)\s*\.\s*$'
        
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
            'All Northstar rods are first quality',
            'Due to the weight and length',
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
        
        if description:
            # First try to remove trailing SKU sentences
            pattern_trail1 = r'\s*[A-Z][a-zA-Z\s]+(?:Ltd Run|Limited Run)?\s+\d{6}\s+by\s+[A-Za-z\s]+\([A-Za-z]+\)\s*\.\s*$'
        
        time.sleep(0.5)
        
        return description, image_url, sku
    except Exception as e:
        print(f"  Error fetching description: {e}")
        return "", "", ""


def extract_tags_from_name(product_name):
    """Extract tags from product name, particularly color names"""
    tags = []
    
    color_simplifications = {
        'lilac': ['purple', 'pink'],
        'lavender': ['purple', 'blue'],
        'mauve': ['purple', 'pink'],
        'violet': ['purple'],
        'indigo': ['purple', 'blue'],
        'magenta': ['purple', 'pink'],
        'amethyst': ['purple'],
        'plum': ['purple'],
        'hyacinth': ['purple', 'blue'],
        'blackberry': ['purple', 'black'],
        'boysenberry': ['purple', 'red'],
        
        'sky': ['blue'],
        'ocean': ['blue'],
        'oceanic': ['blue', 'green'],
        'cyan': ['blue', 'green'],
        'aqua': ['blue', 'green'],
        'teal': ['blue', 'green'],
        'turquoise': ['blue', 'green'],
        'turquesa': ['blue', 'green'],
        'cobalt': ['blue'],
        'navy': ['blue'],
        'sapphire': ['blue'],
        'glacier': ['blue', 'white'],
        'midnight': ['black', 'blue'],
        'nile': ['blue', 'green'],
        'periwinkle': ['blue', 'purple'],
        'caribbean': ['blue', 'green'],
        'neptune': ['blue', 'green'],
        'lapis': ['blue'],
        'ink': ['blue', 'black'],
        'petroleum': ['green', 'blue', 'black'],
        'lagoon': ['blue', 'green'],
        'denim': ['blue'],
        'mariner': ['blue'],
        'tidepool': ['blue', 'green'],
        'heron': ['blue', 'gray'],
        'wisteria': ['purple', 'blue'],
        'atlantis': ['blue', 'green'],
        'azure': ['blue'],
        
        'lime': ['green', 'yellow'],
        'mint': ['green'],
        'olive': ['green', 'brown'],
        'jade': ['green'],
        'emerald': ['green'],
        'spruce': ['green', 'blue'],
        'beryl': ['green'],
        'moss': ['green'],
        'absinthe': ['green'],
        'evergreen': ['green'],
        'forest': ['green'],
        'sage': ['green'],
        'grass': ['green'],
        'kelp': ['green', 'brown'],
        'avocado': ['green'],
        'pea': ['green'],
        'grasshopper': ['green'],
        'army': ['green'],
        'pine': ['green'],
        'pistachio': ['green'],
        'amazon': ['green'],
        'julep': ['green'],
        'bloodstone': ['green', 'red'],
        'eucalyptus': ['green', 'gray'],
        'limeade': ['green', 'yellow'],
        'mojito': ['green'],
        'bayou': ['green', 'brown'],
        'aloe': ['green'],
        
        'canary': ['yellow'],
        'lemon': ['yellow'],
        'gold': ['yellow', 'orange'],
        'amber': ['yellow', 'orange'],
        'topaz': ['yellow', 'orange'],
        'brass': ['yellow'],
        'goldenrod': ['yellow', 'orange'],
        'honey': ['yellow', 'orange'],
        'mead': ['yellow', 'orange'],
        'butterscotch': ['yellow', 'orange', 'brown'],
        'straw': ['yellow', 'brown'],
        'mustard': ['yellow', 'brown'],
        'dijon': ['yellow', 'brown'],
        'mimosa': ['yellow'],
        'daffodil': ['yellow'],
        
        'caramel': ['yellow', 'brown', 'orange'],
        'butternut': ['brown', 'yellow'],
        'apricot': ['orange', 'yellow'],
        
        'peach': ['orange', 'pink'],
        'coral': ['orange', 'pink'],
        'salmon': ['orange', 'pink'],
        'canyon': ['orange', 'brown', 'red'],
        'pumpkin': ['orange'],
        'carrot': ['orange'],
        'persimmon': ['orange', 'red'],
        'daisy': ['orange'],
        
        'crimson': ['red'],
        'scarlet': ['red'],
        'ruby': ['red'],
        'maroon': ['red', 'brown'],
        'burgundy': ['red', 'purple'],
        'rose': ['red', 'pink'],
        'lava': ['red', 'orange'],
        'dahlia': ['pink', 'purple', 'red'],
        'pomegranate': ['red'],
        'garnet': ['red'],
        'poppy': ['red'],
        'cherry': ['red'],
        'bubblegum': ['pink'],
        'tongue': ['pink'],
        'lychee': ['pink', 'white'],
        'blush': ['pink'],
        'raspberry': ['red', 'pink'],
        
        'tan': ['brown', 'orange', 'yellow'],
        'beige': ['brown', 'yellow'],
        'ochre': ['brown', 'orange', 'yellow'],
        'sienna': ['brown', 'red', 'orange'],
        'umber': ['brown'],
        'bronze': ['brown', 'orange'],
        'copper': ['brown', 'orange', 'red'],
        'timber': ['brown'],
        'sable': ['brown', 'black'],
        'sandstorm': ['brown', 'orange', 'yellow'],
        'grizzly': ['brown', 'gray'],
        'maple syrup': ['brown', 'yellow', 'orange'],
        'rootbeer': ['brown'],
        'sand': ['brown', 'yellow'],
        'sandstone': ['brown', 'yellow'],
        'cocoa': ['brown'],
        'cedar': ['brown', 'red'],
        'birchwood': ['brown', 'white'],
        'biscotti': ['brown', 'yellow'],
        'beaver': ['brown'],
        'cappuccino': ['brown'],
        
        'cream': ['white', 'yellow'],
        'ivory': ['white', 'yellow'],
        'pearl': ['white'],
        'champagne': ['white', 'yellow'],
        'ghost': ['white'],
        'blizzard': ['white'],
        'moonshine': ['white', 'silver'],
        'alabaster': ['white'],
        
        'silver': ['gray'],
        'charcoal': ['black', 'gray'],
        'ebony': ['black'],
        'onyx': ['black'],
        'jet': ['black'],
        
        'slate': ['gray', 'blue'],
        'nimbus': ['gray', 'white'],
        
        'mai tai': ['pink', 'orange', 'yellow'],
        'multi': ['multicolored'],
        'irrid': ['multicolored'],
    }
    
    unique_colors = [
        'pink', 'clear', 'multicolored'
    ]
    
    # Remove opacity_terms - we don't want to add these as tags anymore
    # opacity_terms = [
    #     'milky', 'misty'
    # ]
    
    base_colors = ['red', 'blue', 'green', 'yellow', 'orange', 'purple', 
                   'brown', 'black', 'white', 'gray', 'grey']
    
    name_lower = product_name.lower()
    
    found_colors = set()
    
    for specific_color, base_color_list in color_simplifications.items():
        if specific_color in name_lower:
            for base_color in base_color_list:
                found_colors.add(base_color)
    
    for color in unique_colors:
        if color in name_lower:
            found_colors.add(color)
    
    for color in base_colors:
        if color in name_lower and color not in found_colors:
            found_colors.add(color)
    
    # Removed opacity terms section - no longer adding these as tags
    
    if found_colors:
        tags = [f'"{color}"' for color in sorted(found_colors)]
        return ', '.join(tags)
    else:
        # If no colors found, return "unknown" tag
        return '"unknown"'


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


def remove_brand_from_title(title, manufacturer_abbrev, product_type):
    """Remove brand name and product type from product title"""
    brand_patterns = {
        'NS': ['Northstar', 'Northstar Glassworks'],
        'EF': ['Effetre'],
        'CiM': ['Creation is Messy', 'CiM'],
        'VF': ['Vetrofond'],
        'TAG': ['Trautman Art Glass', 'TAG', 'Trautman'],
        'BB': ['Boro Batch'],
        'GA': ['Glass Alchemy'],
        'SI': ['Simax'],
        'DH': ['Double Helix'],
        'RE': ['Reichenbach']
    }
    
    patterns = brand_patterns.get(manufacturer_abbrev, [])
    cleaned_title = title
    
    for pattern in patterns:
        cleaned_title = re.sub(f'^{re.escape(pattern)}\\s+', '', cleaned_title, flags=re.IGNORECASE)
        cleaned_title = re.sub(f'\\b{re.escape(pattern)}\\b\\s*', '', cleaned_title, flags=re.IGNORECASE)
    
    cleaned_title = re.sub(r'\bGlass Rods?\b\s*', '', cleaned_title, flags=re.IGNORECASE)
    
    if manufacturer_abbrev == 'BB':
        cleaned_title = re.sub(r'\bThins\b\s*', '', cleaned_title, flags=re.IGNORECASE)
    
    type_patterns = {
        'rod': [r'\bRods?\b'],
        'frit': [r'\bFrit\b', r'\bPowder\b'],
        'sheet': [r'\bSheet\b'],
        'stringer': [r'\bStringers?\b'],
        'tube': [r'\bTubes?\b', r'\bTubing\b']
    }
    
    if product_type in type_patterns:
        for pattern in type_patterns[product_type]:
            cleaned_title = re.sub(pattern, '', cleaned_title, flags=re.IGNORECASE)
    
    # Remove COE references
    cleaned_title = re.sub(r'\bCOE\s*33\b', '', cleaned_title, flags=re.IGNORECASE)
    cleaned_title = re.sub(r'\bCOE\s*104\b', '', cleaned_title, flags=re.IGNORECASE)
    
    cleaned_title = re.sub(r'\s+', ' ', cleaned_title)
    
    return cleaned_title.strip()


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
            if '/products/' in href and '?_pos=' in href and href not in self.seen_urls:
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


def scrape_vendor_products(base_url, vendor_name, test_mode=False, single_item_mode=False, max_items=None):
    """
    Scrapes products for a specific vendor from Frantz Art Glass
    
    Args:
        base_url: The base collection URL
        vendor_name: The vendor name to filter by
        test_mode: If True, only scrape the first page
        single_item_mode: If True, only scrape the first item
        max_items: If set, stop after scraping this many items
    """
    params = {
        'filter.p.vendor': vendor_name,
        'sort_by': 'manual'
    }
    
    manufacturer_config = {
        'Northstar': {'abbrev': 'NS', 'coe': '33'},
        'Effetre': {'abbrev': 'EF', 'coe': '104'},
        'Creation is Messy': {'abbrev': 'CiM', 'coe': '104'},
        'CiM': {'abbrev': 'CiM', 'coe': '104'},
        'Vetrofond': {'abbrev': 'VF', 'coe': '104'},
        'Trautman': {'abbrev': 'TAG', 'coe': '33'},
        'TAG': {'abbrev': 'TAG', 'coe': '33'},
        'Boro Batch': {'abbrev': 'BB', 'coe': '33'},
        'Glass Alchemy': {'abbrev': 'GA', 'coe': '33'},
        'Simax': {'abbrev': 'SI', 'coe': '33'},
        'Double Helix': {'abbrev': 'DH', 'coe': '33'},
        'Reichenbach': {'abbrev': 'RE', 'coe': '104'}
    }
    
    manufacturer_abbrev = None
    manufacturer_coe = "0"
    
    for mfg_name, config in manufacturer_config.items():
        if mfg_name in vendor_name:
            manufacturer_abbrev = config['abbrev']
            manufacturer_coe = config['coe']
            break
    
    if manufacturer_abbrev is None:
        manufacturer_abbrev = "UNK"
        manufacturer_coe = "0"
    
    print(f"\nScraping {vendor_name} products (Abbrev: {manufacturer_abbrev}, COE: {manufacturer_coe})...")
    
    all_products = []
    page = 1
    
    while True:
        print(f"  Fetching page {page}...")
        
        if page > 1:
            params['page'] = page
        
        url = f"{base_url}?{urllib.parse.urlencode(params)}"
        
        try:
            req = urllib.request.Request(url)
            req.add_header('User-Agent', 'Mozilla/5.0')
            
            with urllib.request.urlopen(req, timeout=10) as response:
                html_content = response.read().decode('utf-8')
            
            parser = ProductParser()
            parser.feed(html_content)
            
            products_found = len(parser.products)
            
            for product in parser.products:
                if not any(p['url'] == product['url'] for p in all_products):
                    product['manufacturer_abbrev'] = manufacturer_abbrev
                    product['coe'] = manufacturer_coe
                    
                    # Fetch description and SKU for all products
                    description, image_url, sku_from_detail = fetch_product_description(product['url'], product['name'])
                    
                    # For Effetre, Reichenbach, and Vetrofond: skip saving description
                    if manufacturer_abbrev in ['EF', 'RE', 'VF']:
                        # Don't save description for these manufacturers
                        product['manufacturer_description'] = ''
                    else:
                        # Save description for other manufacturers
                        product['manufacturer_description'] = description
                    
                    # Always save image URL
                    product['image_url'] = image_url
                    
                    # Update SKU from detail page if found
                    if sku_from_detail:
                        product['sku'] = sku_from_detail
                    
                    # For Effetre products, remove dash and two digits suffix if present
                    if manufacturer_abbrev == 'EF' and product.get('sku'):
                        product['sku'] = re.sub(r'-\d{2}$', '', product['sku'])
                    
                    all_products.append(product)
                    
                    if single_item_mode:
                        print("  Single item mode: stopping after first product.")
                        return all_products
                    
                    if max_items and len(all_products) >= max_items:
                        print(f"  Reached max items limit ({max_items}), stopping.")
                        return all_products
            
            print(f"    Found {products_found} products on page {page}")
            
            if test_mode:
                print("  Test mode: stopping after first page.")
                break
            
            if products_found == 0:
                print("  No more products found.")
                break
            
            if products_found < 10:
                print("  Fewer products found, likely last page.")
                break
            
            page += 1
            
            time.sleep(1)
            
        except Exception as e:
            print(f"  Error fetching page {page}: {e}")
            break
    
    print(f"  Total products found for {vendor_name}: {len(all_products)}")
    return all_products


def main():
    test_mode = '--test' in sys.argv or '-test' in sys.argv
    testall_mode = '--testall' in sys.argv or '-testall' in sys.argv
    
    if test_mode:
        print("Running in TEST MODE - will only scrape 1 item from Double Helix")
        print("-" * 60)
    elif testall_mode:
        print("Running in TESTALL MODE - will only scrape first page per vendor")
        print("-" * 60)
    
    print("Starting scrape of glass products from multiple vendors...")
    print("=" * 60)
    
    if test_mode:
        vendors = [
            {'url': 'https://www.frantzartglass.com/collections/effetre-rods', 'name': 'Double Helix'},
        ]
    else:
        vendors = [
            {'url': 'https://www.frantzartglass.com/collections/effetre-rods', 'name': 'CiM Creation is Messy'},
            {'url': 'https://www.frantzartglass.com/collections/effetre-rods', 'name': 'Effetre'},
            {'url': 'https://www.frantzartglass.com/collections/effetre-rods', 'name': 'Double Helix'},
            {'url': 'https://www.frantzartglass.com/collections/effetre-rods', 'name': 'Reichenbach'},
            {'url': 'https://www.frantzartglass.com/collections/effetre-rods', 'name': 'Vetrofond'},
            {'url': 'https://www.frantzartglass.com/collections/boro-rod', 'name': 'Boro Batch'},
            {'url': 'https://www.frantzartglass.com/collections/boro-rod', 'name': 'Glass Alchemy'},
            {'url': 'https://www.frantzartglass.com/collections/boro-rod', 'name': 'Northstar Glassworks'},
            {'url': 'https://www.frantzartglass.com/collections/boro-rod', 'name': 'TAG Trautman Art Glass'},
        ]
    
    all_products = []
    
    limit_to_first_page = testall_mode
    max_items = 1 if test_mode else None
    
    for vendor in vendors:
        products = scrape_vendor_products(vendor['url'], vendor['name'], 
                                         test_mode=limit_to_first_page, 
                                         single_item_mode=False,
                                         max_items=max_items)
        all_products.extend(products)
    
    print("\n" + "=" * 60)
    print(f"Total products found across all vendors: {len(all_products)}")
    print("=" * 60 + "\n")
    
    print("Summary by vendor:")
    vendor_counts = {}
    for product in all_products:
        mfg = product.get('manufacturer_abbrev', 'UNK')
        vendor_counts[mfg] = vendor_counts.get(mfg, 0) + 1
    
    for mfg, count in sorted(vendor_counts.items()):
        print(f"  {mfg}: {count} products")
    print()
    
    try:
        import csv
        if test_mode:
            csv_filename = 'glass_products_test.csv'
        elif testall_mode:
            csv_filename = 'glass_products_testall.csv'
        else:
            csv_filename = 'glass_products.csv'
        
        with open(csv_filename, 'w', newline='', encoding='utf-8') as f:
            fieldnames = ['manufacturer', 'code', 'name', 'start_date', 'end_date', 
                         'manufacturer_description', 'tags', 'synonyms', 'coe', 'type',
                         'manufacturer_url', 'image_path', 'image_url']
            
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            
            for product in all_products:
                manufacturer = product.get('manufacturer_abbrev', 'UNK')
                
                product_type = determine_product_type(product['name'])
                
                cleaned_name = remove_brand_from_title(product['name'], manufacturer, product_type)
                
                code = product['sku'] if product['sku'] else ""
                
                coe = product.get('coe', "0")
                
                tags = extract_tags_from_name(cleaned_name)
                
                writer.writerow({
                    'manufacturer': manufacturer,
                    'code': code,
                    'name': cleaned_name,
                    'start_date': '',
                    'end_date': '',
                    'manufacturer_description': product.get('manufacturer_description', ''),
                    'tags': tags,
                    'synonyms': '',
                    'coe': coe,
                    'type': product_type,
                    'manufacturer_url': '',
                    'image_path': '',
                    'image_url': product.get('image_url', '')
                })
        
        print(f"CSV results saved to {csv_filename}")
    except Exception as e:
        print(f"Could not save CSV: {e}")


if __name__ == "__main__":
    main()

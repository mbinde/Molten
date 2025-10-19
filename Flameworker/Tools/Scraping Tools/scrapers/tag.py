import urllib.request
import urllib.parse
import re
import time
import html.parser
import sys
import json
import hashlib

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
            starts_with_sku = re.match(r'^\d{6,7}\s', text)
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
        sku_match = re.search(r'SKU:\s*(\d{6,7}(?:[A-Za-z]|-[A-Za-z0-9]+)?)', full_text, re.IGNORECASE)
        if sku_match:
            return sku_match.group(1)
        # Fallback to finding 6 or 7 digit code in text
        sku_match = re.search(r'\b\d{6,7}(?:[A-Za-z]|-[A-Za-z0-9]+)?\b', full_text)
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
                                                        'customer pickup hours']):
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
        pattern1 = r'^\s*[A-Z][a-zA-Z\s]+(?:Ltd Run|Limited Run)?\s+\d{6,7}\s+by\s+[A-Za-z\s]+\([A-Za-z]+\)\s*\.\s*'
        full_text = re.sub(pattern1, '', full_text).strip()
        
        pattern2 = r'^\s*\d{6,7}\s+by\s+[A-Za-z\s]+(?:\([A-Za-z]+\))?\s*\.\s*'
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
        full_url = product_url if product_url.startswith('http') else f"https://northstarglass.com{product_url}"
        
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
        
        time.sleep(0.5)
        
        return description, image_url, sku
    except Exception as e:
        print(f"  Error fetching description: {e}")
        return "", "", ""


def extract_tags_from_name(product_name):
    """Extract tags from product name, particularly color names"""
    # Import from color_extractor if available
    try:
        from color_extractor import extract_tags_from_name as extract_colors
        return extract_colors(product_name)
    except ImportError:
        # Fallback to basic extraction if color_extractor not available
        return '"unknown"'


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
        return 'rod'  # Default to 'rod' for TAG


def remove_brand_from_title(title):
    """Remove TAG brand name, SKU, and product type from product title"""
    
    original_title = title
    
    # Remove SKU prefix (e.g., "TAG-07L" from "TAG-07L Light Ruby Rods")
    cleaned_title = re.sub(r'^TAG-[A-Z0-9]+\s+', '', title, flags=re.IGNORECASE)
    
    # Remove brand patterns
    brand_patterns = ['Trautman Art Glass', 'Trautman', 'TAG']
    
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
    
    # Clean up extra whitespace
    cleaned_title = re.sub(r'\s+', ' ', cleaned_title).strip()
    
    # If nothing left after cleaning, return original title
    if not cleaned_title:
        return original_title
    
    return cleaned_title


# WooCommerce-specific product parser for Northstar
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
        
        # Look for product links
        if tag == 'a' and 'href' in attrs_dict:
            href = attrs_dict['href']
            if '/product/' in href and href not in self.seen_urls:
                self.in_product_link = True
                self.current_product = {
                    'url': href,
                    'name': None,
                    'sku': None,
                    'price': None
                }
                self.current_text = []
                self.depth = 0
        
        # Track depth within product link
        if self.in_product_link:
            if tag in ['h2', 'h3', 'span', 'div']:
                self.depth += 1
    
    def handle_data(self, data):
        if self.in_product_link:
            text = data.strip()
            if text:
                self.current_text.append(text)
    
    def handle_endtag(self, tag):
        if self.in_product_link:
            if tag in ['h2', 'h3', 'span', 'div']:
                self.depth -= 1
            
            if tag == 'a':
                # End of product link - extract name from collected text
                if self.current_text:
                    # First non-empty text is usually the product name
                    self.current_product['name'] = self.current_text[0]
                    
                    # Look for price in the text
                    for text in self.current_text:
                        if '$' in text:
                            self.current_product['price'] = text
                            break
                
                if self.current_product['name'] and self.current_product['url']:
                    self.products.append(self.current_product)
                    self.seen_urls.add(self.current_product['url'])
                
                self.in_product_link = False
                self.current_product = None
                self.current_text = []


def scrape_tag_products(base_url, test_mode=False):
    """
    Scrapes TAG products from a WooCommerce category page
    
    Args:
        base_url: The category URL to scrape
        test_mode: If True, only scrape the first item
    """
    print(f"\nScraping TAG products from: {base_url}")
    
    all_products = []
    seen_skus = {}  # Track SKUs and their products for duplicate detection
    duplicates = []  # Track duplicate products
    page = 1
    
    while True:
        print(f"  Fetching page {page}...")
        
        # WooCommerce pagination format
        if page > 1:
            url = f"{base_url}page/{page}/"
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
            
            # Debug: print some HTML if no products found
            if products_found == 0 and page == 1:
                print("  DEBUG: No products found. Checking HTML structure...")
                # Look for any 'product' mentions in class attributes
                product_classes = re.findall(r'class="[^"]*product[^"]*"', html_content)
                if product_classes:
                    print(f"  Found {len(product_classes)} elements with 'product' in class")
                    print(f"  Sample: {product_classes[0] if product_classes else 'none'}")
                else:
                    print("  No elements found with 'product' in class attribute")
                
                # Check for product links
                product_links = re.findall(r'href="[^"]*\/product\/[^"]*"', html_content)
                if product_links:
                    print(f"  Found {len(product_links)} product links")
                    print(f"  Sample: {product_links[0] if product_links else 'none'}")
            
            for product in parser.products:
                # Skip products named "Boro Short"
                if 'boro short' in product['name'].lower():
                    print(f"    Skipping Boro Short product: {product['name']}")
                    continue
                
                if not any(p['url'] == product['url'] for p in all_products):
                    # Extract SKU from product name first (format: "TAG-07L Light Ruby Rods")
                    name = product['name']
                    sku_match = re.search(r'^TAG-([A-Z0-9]+)', name, re.IGNORECASE)
                    if sku_match:
                        product['sku'] = sku_match.group(1)
                    
                    # Fetch description and SKU from detail page
                    description, image_url, sku_from_detail = fetch_product_description(product['url'], product['name'])
                    
                    product['manufacturer_description'] = description
                    product['image_url'] = image_url
                    product['manufacturer_url'] = product['url']  # Store the product detail page URL
                    
                    # Update SKU from detail page only if we don't already have one from the title
                    if sku_from_detail and not product.get('sku'):
                        product['sku'] = sku_from_detail
                    
                    # If no SKU, generate one
                    if not product.get('sku'):
                        # Get the cleaned name for hashing
                        cleaned_name = remove_brand_from_title(product['name'])
                        # Generate MD5 hash of the cleaned name
                        name_hash = hashlib.md5(cleaned_name.encode('utf-8')).hexdigest()
                        product['sku'] = f"x999-{name_hash}"
                    
                    # Check for duplicate SKUs
                    sku = product.get('sku')
                    if sku:
                        if sku in seen_skus:
                            # Found a duplicate - track it but don't add to all_products
                            duplicates.append({
                                'sku': sku,
                                'name': product['name'],
                                'url': product['url'],
                                'original_name': seen_skus[sku]['name'],
                                'original_url': seen_skus[sku]['url']
                            })
                            print(f"    Skipping duplicate SKU {sku}: {product['name']}")
                        else:
                            # First time seeing this SKU
                            seen_skus[sku] = {'name': product['name'], 'url': product['url']}
                            all_products.append(product)
                    else:
                        # No SKU - add it anyway
                        all_products.append(product)
                    
                    if test_mode and len(all_products) >= 3:
                        print("  Test mode: stopping after 3 products.")
                        return all_products, duplicates
            
            print(f"    Found {products_found} products on page {page}")
            
            if products_found == 0:
                print("  No more products found.")
                break
            
            # Check if there's a next page in the HTML
            if 'page/' + str(page + 1) + '/' not in html_content and 'page=' + str(page + 1) not in html_content:
                print("  No more pages found.")
                break
            
            page += 1
            time.sleep(1)
            
        except Exception as e:
            print(f"  Error fetching page {page}: {e}")
            break
    
    print(f"  Total products found: {len(all_products)}")
    return all_products, duplicates


def main():
    test_mode = '--test' in sys.argv or '-test' in sys.argv
    
    if test_mode:
        print("Running in TEST MODE - will only scrape 3 items")
        print("-" * 60)
    
    print("Starting scrape of TAG glass products...")
    print("=" * 60)
    
    # Only TAG rods
    urls = [
        'https://northstarglass.com/product-category/tag-rods/',
    ]
    
    all_products = []
    all_duplicates = []
    
    for url in urls:
        products, duplicates = scrape_tag_products(url, test_mode=test_mode)
        all_products.extend(products)
        all_duplicates.extend(duplicates)
        
        if test_mode and len(all_products) >= 3:
            print("Test mode: stopping after 3 products.")
            break
    
    print("\n" + "=" * 60)
    print(f"Total products found: {len(all_products)}")
    print("=" * 60 + "\n")
    
    # Print duplicate report
    if all_duplicates:
        print("\n" + "!" * 60)
        print("DUPLICATE SKUs FOUND (these were skipped):")
        print("!" * 60)
        for dup in all_duplicates:
            print(f"\nSKU: {dup['sku']}")
            print(f"  Original: {dup['original_name']}")
            print(f"    URL: {dup['original_url']}")
            print(f"  Duplicate: {dup['name']}")
            print(f"    URL: {dup['url']}")
        print("\n" + "!" * 60)
        print(f"Total duplicates skipped: {len(all_duplicates)}")
        print("!" * 60 + "\n")
    else:
        print("No duplicate SKUs found.\n")
    
    try:
        import csv
        csv_filename = 'tag_products_test.csv' if test_mode else 'tag_products.csv'
        
        with open(csv_filename, 'w', newline='', encoding='utf-8') as f:
            fieldnames = ['manufacturer', 'code', 'name', 'start_date', 'end_date', 
                         'manufacturer_description', 'tags', 'synonyms', 'coe', 'type',
                         'manufacturer_url', 'image_path', 'image_url']
            
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            
            for product in all_products:
                product_type = determine_product_type(product['name'])
                
                cleaned_name = remove_brand_from_title(product['name'])
                code = product.get('sku', '')
                
                tags = extract_tags_from_name(cleaned_name)
                
                writer.writerow({
                    'manufacturer': 'TAG',
                    'code': code,
                    'name': cleaned_name,
                    'start_date': '',
                    'end_date': '',
                    'manufacturer_description': product.get('manufacturer_description', ''),
                    'tags': tags,
                    'synonyms': '',
                    'coe': '33',  # TAG is COE 33
                    'type': product_type,
                    'manufacturer_url': product.get('manufacturer_url', ''),
                    'image_path': '',
                    'image_url': product.get('image_url', '')
                })
        
        print(f"CSV results saved to {csv_filename}")
    except Exception as e:
        print(f"Could not save CSV: {e}")


if __name__ == "__main__":
    main()



# ===== MODULE INTERFACE FUNCTIONS (Added for combined_glass_scraper) =====

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

MANUFACTURER_CODE = 'TAG'
MANUFACTURER_NAME = 'Trautman Art Glass'
COE = '33'


def scrape(test_mode=False, max_items=None):
    """
    Module interface for combined scraper.
    Calls the existing scrape_tag_products function.
    """
    print(f"\n{'='*60}")
    print(f"Scraping {MANUFACTURER_NAME} ({MANUFACTURER_CODE})")
    print(f"{'='*60}")
    
    url = 'https://northstarglass.com/product-category/tag-rods/'
    products, duplicates = scrape_tag_products(url, test_mode=test_mode)
    
    # Limit if max_items specified
    if max_items and len(products) > max_items:
        products = products[:max_items]
    
    return products, duplicates


def format_products_for_csv(products):
    """Format products for CSV output"""
    csv_rows = []
    
    for product in products:
        product_type = determine_product_type(product['name'])
        cleaned_name = remove_brand_from_title(product['name'])
        code = product.get('sku', '')
        tags = extract_tags_from_name(cleaned_name)
        
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


import urllib.request
import urllib.parse
import re
import time
import html.parser
import sys
import json
import hashlib
from color_extractor import combine_tags

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
            srcset = attrs_dict.get('srcset', '')
            
            # Skip empty sources
            if not src:
                return
            
            # Skip placeholder, icon, logo, banner, header images
            skip_terms = ['icon', 'logo', '_small', '_thumb', 'placeholder', 'default', 'no-image', 
                         'avatar', 'banner', 'header', 'footer', 'badge', 'payment', '-150x150', '-300x300']
            if any(term in src.lower() for term in skip_terms):
                return
            
            # Check if this is in a product gallery/image container by checking parent class
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
                        self.image_url = 'https://doublehelixglassworks.com' + src
    
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
        # First try to find SKU with label - allow for 6 or 7 digits with various suffixes (including lowercase)
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
            return "", ""
        
        # Check if description has format: "words Description rest of text"
        # Look for "Description" as a standalone word (case insensitive)
        summary_text = ""
        desc_match = re.search(r'^(.+?)\s+Description\s+(.+)$', full_text, re.IGNORECASE)
        if desc_match:
            summary_text = desc_match.group(1).strip()
            rest_of_description = desc_match.group(2).strip()
            # Reformat: "Summary: {words before Description}. Description: {rest of text}"
            full_text = f"Summary: {summary_text}. Description: {rest_of_description}"
        
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
            'Technical Description:',
            'Technical Description',
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
        
        return description, summary_text


def fetch_product_description(product_url, product_name):
    """Fetch and parse the product description and image from detail page"""
    try:
        full_url = product_url if product_url.startswith('http') else f"https://doublehelixglassworks.com{product_url}"
        
        print(f"  Fetching description from: {full_url}")
        
        req = urllib.request.Request(full_url)
        req.add_header('User-Agent', 'Mozilla/5.0')
        
        with urllib.request.urlopen(req, timeout=10) as response:
            html_content = response.read().decode('utf-8')
        
        parser = DescriptionParser()
        parser.feed(html_content)
        description, summary_text = parser.get_description()
        image_url = parser.image_url
        sku = parser.get_sku()

        time.sleep(0.5)  # Rate limiting (parallel scraping)
        
        return description, image_url, sku, summary_text
    except Exception as e:
        print(f"  Error fetching description: {e}")
        return "", "", "", ""


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
        return 'rod'  # Default to 'rod' if type is unknown


def remove_brand_from_title(title):
    """Remove Double Helix brand name, SKU prefix, unit info, and product type from product title"""
    
    # Remove inventory number prefix (e.g., "933." or "KRS-953 " or "SKX-951 ")
    # Pattern 1: Number followed by period (e.g., "933.Bone" -> "Bone")
    cleaned_title = re.sub(r'^\d{3,4}\.', '', title)
    
    # Pattern 2: Code with dashes followed by space (e.g., "KRS-953 Color" -> "Color")
    cleaned_title = re.sub(r'^[A-Z]{2,3}-?\d{3,4}[A-Z]?\s+', '', cleaned_title)
    
    # Remove unit information in parentheses (e.g., "(1/4 lb)", "(1 lb)", etc.)
    cleaned_title = re.sub(r'\s*\([^)]*lb[^)]*\)', '', cleaned_title, flags=re.IGNORECASE)
    cleaned_title = re.sub(r'\s*\([^)]*oz[^)]*\)', '', cleaned_title, flags=re.IGNORECASE)
    
    # Remove brand patterns
    brand_patterns = ['Double Helix', 'DH']
    
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
    
    # FIXED: If nothing left after cleaning, return original title
    if not cleaned_title:
        return title  # Changed from original_title to title
    
    return cleaned_title


# WooCommerce-specific product parser for Double Helix
class ProductParser(html.parser.HTMLParser):
    """HTML parser to extract product information from WooCommerce site"""
    def __init__(self):
        super().__init__()
        self.products = []
        self.current_product = None
        self.in_product = False
        self.in_product_title = False
        self.in_price = False
        self.current_text = []
        self.seen_urls = set()
        
    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)
        
        # WooCommerce product wrapper
        if tag == 'li' and 'class' in attrs_dict:
            class_str = attrs_dict['class']
            if 'product' in class_str and 'type-product' in class_str:
                self.in_product = True
                self.current_product = {
                    'url': None,
                    'name': None,
                    'sku': None,
                    'price': None
                }
        
        # Product link
        if self.in_product and tag == 'a' and 'href' in attrs_dict:
            href = attrs_dict['href']
            if '/product/' in href and href not in self.seen_urls:
                self.current_product['url'] = href
        
        # Product title
        if self.in_product and tag == 'h2' and 'class' in attrs_dict:
            if 'woocommerce-loop-product__title' in attrs_dict['class']:
                self.in_product_title = True
                self.current_text = []
        
        # Price
        if self.in_product and tag == 'span' and 'class' in attrs_dict:
            if 'price' in attrs_dict['class'] or 'amount' in attrs_dict['class']:
                self.in_price = True
                self.current_text = []
    
    def handle_data(self, data):
        if self.in_product_title or self.in_price:
            self.current_text.append(data)
    
    def handle_endtag(self, tag):
        if tag == 'h2' and self.in_product_title:
            self.current_product['name'] = ' '.join(self.current_text).strip()
            self.in_product_title = False
            self.current_text = []
        
        if tag == 'span' and self.in_price:
            price_text = ' '.join(self.current_text).strip()
            if price_text and not self.current_product['price']:
                self.current_product['price'] = price_text
            self.in_price = False
            self.current_text = []
        
        if tag == 'li' and self.in_product:
            if self.current_product['name'] and self.current_product['url']:
                # Extract SKU from product name if it's in format like "KRS-953 (1/4 lb)" or "RO-670b"
                name = self.current_product['name']
                sku_match = re.search(r'^([A-Z]{2,3}-?\d{3,4}[A-Za-z]?)', name)
                if sku_match:
                    self.current_product['sku'] = sku_match.group(1)
                elif re.match(r'^\d{3,4}\.', name):  # Format like "933.Bone"
                    sku_match = re.search(r'^(\d{3,4})', name)
                    if sku_match:
                        self.current_product['sku'] = sku_match.group(1)
                
                self.products.append(self.current_product)
                self.seen_urls.add(self.current_product['url'])
            
            self.in_product = False
            self.current_product = None


def scrape_double_helix_products(base_url, test_mode=False, stock_type='available'):
    """
    Scrapes Double Helix products from a WooCommerce category page

    Args:
        base_url: The category URL to scrape
        test_mode: If True, only scrape the first item
        stock_type: The stock type value to assign to products from this URL
            Valid values: 'available', 'oos', 'discontinued', 'test'
    """
    print(f"\nScraping Double Helix products from: {base_url}")
    
    all_products = []
    seen_skus = {}  # Track SKUs and their products for duplicate detection
    duplicates = []  # Track duplicate products
    seen_zephyr_names = set()  # Track Zephyr product names (keep only first)
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
            
            # Process each product
            for product in parser.products:
                if test_mode and len(all_products) >= 1:
                    break
                
                # Fetch description and additional info from detail page
                description, image_url, sku_from_detail, summary_text = fetch_product_description(
                    product['url'], 
                    product['name']
                )
                
                product['manufacturer_description'] = description
                product['summary_text'] = summary_text
                product['image_url'] = image_url

                # Ensure manufacturer_url is absolute
                url = product['url']
                if url.startswith('/'):
                    product['manufacturer_url'] = f"https://doublehelixglassworks.com{url}"
                elif url.startswith('http://') or url.startswith('https://'):
                    product['manufacturer_url'] = url
                else:
                    # Shouldn't happen, but handle relative URLs without leading slash
                    product['manufacturer_url'] = f"https://doublehelixglassworks.com/{url}"

                # Check if this is a test batch from description or name
                # Override stock_type if test batch is detected
                is_test_batch = False
                if description and 'test batch' in description.lower():
                    is_test_batch = True
                elif product['name'] and 'test batch' in product['name'].lower():
                    is_test_batch = True
                elif summary_text and 'test batch' in summary_text.lower():
                    is_test_batch = True

                product['stock_type'] = 'test' if is_test_batch else stock_type
                
                # Use SKU from detail page if we didn't get one from the listing
                if sku_from_detail and not product.get('sku'):
                    product['sku'] = sku_from_detail

                # Check if this is a Zephyr product (keep only first one)
                # Do this BEFORE generating SKUs so we skip duplicates early
                cleaned_name = remove_brand_from_title(product['name'])
                if cleaned_name.startswith('Zephyr'):
                    if 'Zephyr' in seen_zephyr_names:
                        print(f"    SKIPPING additional Zephyr product: {product['name']}")
                        continue  # Skip this product
                    else:
                        seen_zephyr_names.add('Zephyr')
                        print(f"    KEEPING first Zephyr product: {product['name']}")

                # If still no SKU or SKU is placeholder "000000", generate from cleaned name
                current_sku = product.get('sku')
                if not current_sku or current_sku == '000000':
                    # For 000000 placeholder, use cleaned name with dashes and spaces removed
                    if current_sku == '000000':
                        # Remove all dashes and spaces: "Oracle Opal 2" -> "oracleopal2"
                        product['sku'] = re.sub(r'[-\s]+', '', cleaned_name).lower()
                    else:
                        # For completely missing SKU, use hash-based code
                        name_hash = hashlib.md5(cleaned_name.encode('utf-8')).hexdigest()
                        product['sku'] = f"DH-{name_hash[:8]}"

                # Check for duplicates by SKU (for reporting only - don't skip)
                current_sku = product.get('sku')
                if current_sku and current_sku in seen_skus:
                    # Record duplicate for reporting
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
            
            if test_mode and len(all_products) >= 1:
                break
            
            print(f"    Found {products_found} products on page {page}")
            
            if products_found == 0:
                print("  No more products found.")
                break
            
            # Check if there's a next page in the HTML
            if 'page/' + str(page + 1) + '/' not in html_content and 'page=' + str(page + 1) not in html_content:
                print("  No more pages found.")
                break
            
            page += 1
            time.sleep(0.5)  # Rate limiting (parallel scraping)
            
        except Exception as e:
            print(f"  Error fetching page {page}: {e}")
            break
    
    print(f"  Total products found: {len(all_products)}")
    return all_products, duplicates


def main():
    test_mode = '--test' in sys.argv or '-test' in sys.argv
    
    if test_mode:
        print("Running in TEST MODE - will only scrape 1 item")
        print("-" * 60)
    
    print("Starting scrape of Double Helix glass products...")
    print("=" * 60)
    
    urls = [
        'https://doublehelixglassworks.com/product-category/glass/glass-rods/',
        'https://doublehelixglassworks.com/product-category/glass/glass-rods/limited-glass-rods/',
        'https://doublehelixglassworks.com/product-category/glass/other-glass/',
        'https://doublehelixglassworks.com/product-category/color-archives/oracle-archive/',
    ]

    oos_urls = [
        'https://doublehelixglassworks.com/product-category/color-archives/outofstock/',
    ]

    test_urls = [
        'https://doublehelixglassworks.com/product-category/color-archives/test-batches-archive/',
    ]

    retired_urls = [
        'https://doublehelixglassworks.com/product-category/color-archives/retired-colors/',
    ]
    
    all_products = []
    all_duplicates = []
    
    # Scrape available products
    for url in urls:
        products, duplicates = scrape_double_helix_products(url, test_mode=test_mode, stock_type='available')
        all_products.extend(products)
        all_duplicates.extend(duplicates)
        
        if test_mode and len(all_products) >= 1:
            print("Test mode: stopping after first product.")
            break
    
    # Scrape OOS (out of stock) products
    if not test_mode or len(all_products) == 0:
        for url in oos_urls:
            products, duplicates = scrape_double_helix_products(url, test_mode=test_mode, stock_type='oos')
            all_products.extend(products)
            all_duplicates.extend(duplicates)

            if test_mode and len(all_products) >= 1:
                print("Test mode: stopping after first product.")
                break

    # Scrape test batch products
    if not test_mode or len(all_products) == 0:
        for url in test_urls:
            products, duplicates = scrape_double_helix_products(url, test_mode=test_mode, stock_type='test')
            all_products.extend(products)
            all_duplicates.extend(duplicates)

            if test_mode and len(all_products) >= 1:
                print("Test mode: stopping after first product.")
                break

    # Scrape retired/discontinued products
    if not test_mode or len(all_products) == 0:
        for url in retired_urls:
            products, duplicates = scrape_double_helix_products(url, test_mode=test_mode, stock_type='discontinued')
            all_products.extend(products)
            all_duplicates.extend(duplicates)

            if test_mode and len(all_products) >= 1:
                print("Test mode: stopping after first product.")
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
        csv_filename = 'double_helix_products_test.csv' if test_mode else 'double_helix_products.csv'
        
        with open(csv_filename, 'w', newline='', encoding='utf-8') as f:
            fieldnames = ['manufacturer', 'code', 'name', 'start_date', 'end_date', 
                         'manufacturer_description', 'tags', 'synonyms', 'coe', 'type',
                         'manufacturer_url', 'image_path', 'image_url', 'stock_type']
            
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            
            for product in all_products:
                product_type = determine_product_type(product['name'])
                
                # Skip frit items
                if product_type == 'frit':
                    continue
                
                cleaned_name = remove_brand_from_title(product['name'])
                code = product.get('sku', '')
                
                # Use summary text for tag extraction if available, otherwise use cleaned name
                tag_source = product.get('summary_text', '') or cleaned_name
                tags = extract_tags_from_name(tag_source)
                
                writer.writerow({
                    'manufacturer': 'DH',
                    'code': code,
                    'name': cleaned_name,
                    'start_date': '',
                    'end_date': '',
                    'manufacturer_description': product.get('manufacturer_description', ''),
                    'tags': tags,
                    'synonyms': '',
                    'coe': '33',  # Double Helix is COE 33
                    'type': product_type,
                    'manufacturer_url': product.get('manufacturer_url', ''),
                    'image_path': '',
                    'image_url': product.get('image_url', ''),
                    'stock_type': product.get('stock_type', '')
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

MANUFACTURER_CODE = 'DH'
MANUFACTURER_NAME = 'Double Helix'
COE = '33'


def scrape(test_mode=False, max_items=None):
    """
    Module interface for combined scraper.
    Calls the existing scrape_double_helix_products function.
    """
    print(f"\n{'='*60}")
    print(f"Scraping {MANUFACTURER_NAME} ({MANUFACTURER_CODE})")
    print(f"{'='*60}")
    
    urls = [
        'https://doublehelixglassworks.com/product-category/glass/glass-rods/',
        'https://doublehelixglassworks.com/product-category/glass/glass-rods/limited-glass-rods/',
        'https://doublehelixglassworks.com/product-category/glass/other-glass/',
        'https://doublehelixglassworks.com/product-category/color-archives/oracle-archive/',
    ]
    
    all_products = []
    all_duplicates = []
    
    for url in urls:
        products, duplicates = scrape_double_helix_products(
            url, 
            test_mode=test_mode,
            stock_type='available'
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
        
        # Skip frit
        if product_type == 'frit':
            continue
        
        cleaned_name = remove_brand_from_title(product['name'])
        code = product.get('sku', '')

        # Ensure code has manufacturer prefix
        if code and not code.upper().startswith(f"{MANUFACTURER_CODE}-"):
            code = f"{MANUFACTURER_CODE}-{code}"

        tag_source = product.get('summary_text', '') or cleaned_name
        description = product.get('manufacturer_description', '')
        manufacturer_url = product.get('manufacturer_url', '')
        tags = combine_tags(tag_source, description, manufacturer_url, 'DH')
        
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
            'stock_type': product.get('stock_type', '')
        })
    
    return csv_rows


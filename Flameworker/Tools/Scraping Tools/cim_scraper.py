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
            
            # For CiM, look for images that might be color swatches or product images
            # They often have 'images' in the path or color-related names
            should_capture = False
            
            # Check if it's in an images directory
            if 'images/' in src.lower() or '/images/' in src.lower():
                should_capture = True
            
            # Check for color or product related keywords
            if any(keyword in src.lower() for keyword in ['color', 'swatch', 'palette', 'glass', 'rod', 'bead']):
                should_capture = True
            
            # Skip obvious non-product images
            if any(skip in src.lower() for skip in ['icon', 'logo', 'button', 'banner', 'header', 'footer', 'nav', 'menu']):
                should_capture = False
            
            if should_capture:
                # Build full URL
                if src.startswith('//'):
                    full_src = 'https:' + src
                elif src.startswith('http'):
                    full_src = src
                elif src.startswith('/'):
                    full_src = 'https://creationismessy.com' + src
                else:
                    full_src = 'https://creationismessy.com/' + src
                
                # Prefer larger images
                if not self.image_url or any(x in src.lower() for x in ['_large', '_grande', 'large', 'main']):
                    self.image_url = full_src
                    print(f"      DEBUG: Captured image: {full_src}")
    
    def handle_data(self, data):
        text = data.strip()
        if text:
            self.all_text.append(text)
        
        if self.in_heading and text:
            # Check if starts with SKU pattern (6 or 7 digits)
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
        """Extract SKU from all collected text and remove 511 prefix"""
        full_text = ' '.join(self.all_text)
        # CiM uses 6 or 7-digit SKUs starting with 511
        # Try 7-digit first (more specific)
        sku_match = re.search(r'\b511(\d{4})\b', full_text)
        if sku_match:
            return sku_match.group(1)  # Return just the last 4 digits
        # Then try 6-digit
        sku_match = re.search(r'\b511(\d{3})\b', full_text)
        if sku_match:
            return sku_match.group(1)  # Return just the last 3 digits
        # Fallback to any 6 or 7-digit code starting with 511
        sku_match = re.search(r'\b511(\d{3,4})\b', full_text)
        if sku_match:
            return sku_match.group(1)
        return ""
    
    def get_description(self):
        """Return the collected description text"""
        if self.description_texts:
            return ' '.join(self.description_texts)
        elif self.all_paragraphs:
            return ' '.join(self.all_paragraphs)
        return ""


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
            # Try to extract name and SKU from heading
            # Format can be: "511XXX - Color Name" or "511XXXX - Color Name" (6 or 7 digits)
            # Try 7-digit first and remove the 511 prefix
            match = re.match(r'511(\d{4})\s*[-–]\s*(.+)', heading_text)
            if match and not self.name:
                self.sku = match.group(1)  # Just the last 4 digits
                self.name = match.group(2).strip()
            else:
                # Try 6-digit and remove the 511 prefix
                match = re.match(r'511(\d{3})\s*[-–]\s*(.+)', heading_text)
                if match and not self.name:
                    self.sku = match.group(1)  # Just the last 3 digits
                    self.name = match.group(2).strip()
                elif heading_text and not self.name:
                    # Fallback: use heading as name
                    self.name = heading_text
            self.in_heading = False
            self.current_text = []


def fetch_product_description(product_url, product_name):
    """Fetch the full product description from the detail page"""
    print(f"    Fetching details for: {product_name}")
    
    try:
        req = urllib.request.Request(product_url)
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
    # Handle None or empty values
    if not product_name:
        return 'rod'  # Default to 'rod' for CiM
    
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
        return 'rod'  # Default to 'rod' for CiM


def remove_brand_from_title(title):
    """Remove Creation is Messy brand name, SKU, and product type from product title"""
    
    # Handle None or empty values
    if not title:
        return ''
    
    original_title = title
    
    # Remove SKU prefix (6 or 7-digit numbers, especially those starting with 511)
    cleaned_title = re.sub(r'^\d{6,7}\s+[-–]\s+', '', title)
    cleaned_title = re.sub(r'^\d{6,7}\s+', '', cleaned_title)
    
    # Remove trademark symbols
    cleaned_title = cleaned_title.replace('™', '')
    cleaned_title = cleaned_title.replace('®', '')
    cleaned_title = cleaned_title.replace('©', '')
    
    # Remove brand patterns
    brand_patterns = ['Creation is Messy', 'CiM', 'Messy Color', 'Messy']
    
    for pattern in brand_patterns:
        cleaned_title = re.sub(f'^{re.escape(pattern)}\\s+', '', cleaned_title, flags=re.IGNORECASE)
        cleaned_title = re.sub(f'\\b{re.escape(pattern)}\\b\\s*', '', cleaned_title, flags=re.IGNORECASE)
    
    # Remove "Glass Rods" and similar
    cleaned_title = re.sub(r'\bGlass Rods?\b\s*', '', cleaned_title, flags=re.IGNORECASE)
    
    # Remove product type terms
    type_patterns = [r'\bRods?\b', r'\bFrit\b', r'\bPowder\b', r'\bSheet\b', 
                    r'\bStringers?\b', r'\bTubes?\b', r'\bTubing\b']
    
    for pattern in type_patterns:
        cleaned_title = re.sub(pattern, '', cleaned_title, flags=re.IGNORECASE)
    
    # Remove "Ltd Run" and "Limited Run"
    cleaned_title = re.sub(r'\bLtd\.?\s*Run\b', '', cleaned_title, flags=re.IGNORECASE)
    cleaned_title = re.sub(r'\bLimited\s*Run\b', '', cleaned_title, flags=re.IGNORECASE)
    
    # Remove COE references
    cleaned_title = re.sub(r'\bCOE\s*104\b', '', cleaned_title, flags=re.IGNORECASE)
    
    # Clean up extra whitespace and punctuation
    cleaned_title = re.sub(r'\s+[-–",]\s*', ' ', cleaned_title).strip()
    cleaned_title = ' '.join(cleaned_title.split())
    
    return cleaned_title.strip()


def scrape_palette_page(palette_url, test_mode=False):
    """
    Scrapes product links from a CiM palette page
    ONLY scrapes color.aspx links from palette pages, nothing else
    
    Args:
        palette_url: The palette URL to scrape (e.g., palette.aspx?id=7)
        test_mode: If True, only scrape the first item
    """
    print(f"\nScraping palette: {palette_url}")
    
    # Validate that this is actually a palette URL
    if 'palette.aspx?id=' not in palette_url.lower():
        print(f"  WARNING: Not a palette URL, skipping: {palette_url}")
        return []
    
    try:
        req = urllib.request.Request(palette_url)
        req.add_header('User-Agent', 'Mozilla/5.0')
        
        with urllib.request.urlopen(req, timeout=10) as response:
            html_content = response.read().decode('utf-8')
        
        # Use regex to find all color.aspx?id=XX links
        # This will catch them even if they're not in proper <a> tags
        color_pattern = r'color\.aspx\?id=(\d+)'
        matches = re.findall(color_pattern, html_content, re.IGNORECASE)
        
        print(f"  DEBUG: Found {len(matches)} color.aspx links using regex")
        
        # Build full URLs and remove duplicates
        seen_ids = set()
        valid_products = []
        
        for color_id in matches:
            if color_id not in seen_ids:
                seen_ids.add(color_id)
                full_url = f'https://creationismessy.com/color.aspx?id={color_id}'
                valid_products.append(full_url)
                print(f"    Found color ID: {color_id}")
        
        print(f"  Found {len(valid_products)} unique color links")
        
        if test_mode and valid_products:
            return [valid_products[0]]
        
        return valid_products
    except Exception as e:
        print(f"  Error scraping palette: {e}")
        import traceback
        traceback.print_exc()
        return []


def scrape_color_detail(color_url):
    """
    Scrapes details from a single color page
    ONLY processes color.aspx?id= URLs
    
    Args:
        color_url: The color detail URL (e.g., color.aspx?id=90)
    """
    # Validate that this is actually a color detail URL
    if 'color.aspx?id=' not in color_url.lower():
        print(f"  WARNING: Not a color detail URL, skipping: {color_url}")
        return None
    
    try:
        req = urllib.request.Request(color_url)
        req.add_header('User-Agent', 'Mozilla/5.0')
        
        with urllib.request.urlopen(req, timeout=10) as response:
            html_content = response.read().decode('utf-8')
        
        # Parse the page
        parser = ColorDetailParser()
        parser.feed(html_content)
        
        # Also use description parser for more details
        desc_parser = DescriptionParser()
        desc_parser.feed(html_content)
        
        # If no image found by parser, try regex to find image URLs
        image_url = desc_parser.image_url
        if not image_url:
            # Look for image URLs in the HTML using regex
            # Common patterns: src="images/..." or src="/images/..."
            img_patterns = [
                r'src=["\'](images/[^"\']+\.(?:jpg|jpeg|png|gif))["\']',
                r'src=["\'](/images/[^"\']+\.(?:jpg|jpeg|png|gif))["\']',
                r'src=["\'](https?://[^"\']*creationismessy[^"\']+\.(?:jpg|jpeg|png|gif))["\']'
            ]
            
            for pattern in img_patterns:
                matches = re.findall(pattern, html_content, re.IGNORECASE)
                if matches:
                    # Take the first match and build full URL
                    img_src = matches[0]
                    if img_src.startswith('http'):
                        image_url = img_src
                    elif img_src.startswith('/'):
                        image_url = 'https://creationismessy.com' + img_src
                    else:
                        image_url = 'https://creationismessy.com/' + img_src
                    print(f"      DEBUG: Found image via regex: {image_url}")
                    break
        
        product = {
            'url': color_url,
            'name': parser.name,
            'sku': parser.sku or desc_parser.get_sku(),
            'manufacturer_description': desc_parser.get_description(),
            'image_url': image_url
        }
        
        time.sleep(0.5)
        
        return product
    except Exception as e:
        print(f"  Error scraping color detail: {e}")
        return None


def main():
    """Main function to scrape all CiM colors from palette pages ONLY"""
    
    # Check for test mode
    test_mode = '--test' in sys.argv
    
    print("=" * 60)
    print("Creation is Messy Color Scraper")
    print("STRICT MODE: Only scraping color.aspx pages from palette pages")
    print("=" * 60)
    
    if test_mode:
        print("TEST MODE: Only scraping first color from first palette")
    
    # Define palette URLs - ONLY official palette pages
    # NOTE: Skipping palette ID 1 (All) as it appears to be a navigation page
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
    
    all_products = []
    seen_skus = {}  # Track SKUs to avoid duplicates
    duplicates = []
    
    # In test mode, just use the first palette
    if test_mode:
        palette_urls = [palette_urls[0]]
    
    for palette_url in palette_urls:
        color_links = scrape_palette_page(palette_url, test_mode=test_mode)
        
        print(f"  Processing {len(color_links)} color links from this palette...")
        
        for color_link in color_links:
            product = scrape_color_detail(color_link)
            
            if product:
                sku = product.get('sku', '')
                
                # Check for duplicates
                if sku and sku in seen_skus:
                    duplicates.append({
                        'sku': sku,
                        'name': product.get('name', ''),
                        'url': product.get('url', ''),
                        'original_name': seen_skus[sku]['name'],
                        'original_url': seen_skus[sku]['url']
                    })
                    print(f"  DUPLICATE SKU found: {sku}")
                    continue
                
                # Track this SKU
                if sku:
                    seen_skus[sku] = {
                        'name': product.get('name', ''),
                        'url': product.get('url', '')
                    }
                
                all_products.append(product)
                print(f"    Added: {product.get('name', 'Unknown')} ({sku})")
            
            time.sleep(0.5)
    
    print("\n" + "=" * 60)
    print(f"Total products found: {len(all_products)}")
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
    
    # Save to CSV
    try:
        import csv
        csv_filename = 'cim_products_test.csv' if test_mode else 'cim_products.csv'
        
        with open(csv_filename, 'w', newline='', encoding='utf-8') as f:
            fieldnames = ['manufacturer', 'code', 'name', 'start_date', 'end_date', 
                         'manufacturer_description', 'tags', 'synonyms', 'coe', 'type',
                         'manufacturer_url', 'image_path', 'image_url']
            
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            
            for product in all_products:
                # Safely get name with None check
                product_name = product.get('name') or ''
                
                # Skip products with no name
                if not product_name:
                    print(f"  WARNING: Skipping product with no name: {product}")
                    continue
                
                product_type = determine_product_type(product_name)
                cleaned_name = remove_brand_from_title(product_name)
                code = product.get('sku', '')
                
                tags = extract_tags_from_name(cleaned_name)
                
                writer.writerow({
                    'manufacturer': 'CIM',
                    'code': code,
                    'name': cleaned_name,
                    'start_date': '',
                    'end_date': '',
                    'manufacturer_description': product.get('manufacturer_description', ''),
                    'tags': tags,
                    'synonyms': '',
                    'coe': '104',  # CiM is COE 104
                    'type': product_type,
                    'manufacturer_url': product.get('url', ''),
                    'image_path': '',
                    'image_url': product.get('image_url', '')
                })
        
        print(f"CSV results saved to {csv_filename}")
        print(f"\nSummary: Scraped {len(all_products)} colors from palette pages only")
    except Exception as e:
        print(f"Could not save CSV: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()

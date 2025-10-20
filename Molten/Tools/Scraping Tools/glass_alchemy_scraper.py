import urllib.request
import urllib.parse
import re
import time
import sys
import json
import hashlib
from color_extractor import extract_tags_from_name

def fetch_product_description(product_url, product_name):
    """Fetch and parse the product description and image from detail page"""
    try:
        full_url = product_url if product_url.startswith('http') else f"https://glassalchemy.com{product_url}"
        
        print(f"  Fetching description from: {full_url}")
        
        # Try to fetch the JSON endpoint first
        json_url = full_url.replace('/products/', '/products/') + '.json'
        
        req = urllib.request.Request(json_url)
        req.add_header('User-Agent', 'Mozilla/5.0')
        
        try:
            with urllib.request.urlopen(req, timeout=10) as response:
                json_content = response.read().decode('utf-8')
                product_data = json.loads(json_content)
                
                product_info = product_data.get('product', {})
                description = product_info.get('body_html', '')
                
                # Strip HTML tags from description
                description = re.sub(r'<[^>]+>', '', description)
                description = re.sub(r'\s+', ' ', description).strip()
                
                # Get image URL
                images = product_info.get('images', [])
                image_url = images[0].get('src', '') if images else ''
                
                # Get SKU from first variant
                variants = product_info.get('variants', [])
                sku = variants[0].get('sku', '') if variants else ''
                
                time.sleep(0.5)
                return description, image_url, sku
        except:
            # Fallback to regular HTML fetch if JSON fails
            pass
        
        time.sleep(0.5)
        return "", "", ""
        
    except Exception as e:
        print(f"  Error fetching description: {e}")
        return "", "", ""


def determine_product_type(product_name, product_type_field=None):
    """Determine the type of glass product from its name or product type field"""
    # First check the product_type field if provided
    if product_type_field:
        type_lower = product_type_field.lower()
        if 'frit' in type_lower or 'powder' in type_lower:
            return 'frit'
        elif 'rod' in type_lower:
            return 'rod'
        elif 'sheet' in type_lower:
            return 'sheet'
        elif 'stringer' in type_lower:
            return 'stringer'
        elif 'tube' in type_lower or 'tubing' in type_lower:
            return 'tube'
    
    # Fall back to checking name
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
        return 'rod'  # Default to 'rod' for Glass Alchemy


def remove_brand_from_title(title):
    """Remove Glass Alchemy brand name, SKU, and product type from product title"""
    
    # Extract name before comma if present (e.g., "Amazon Lagoon, 587" -> "Amazon Lagoon")
    if ',' in title:
        title = title.split(',')[0].strip()
    
    # Remove SKU prefix (e.g., "103" from "103 Ketchup" or "974," from "974, Black Violet")
    cleaned_title = re.sub(r'^\d{3,4}[,\s]+', '', title)
    
    # Remove brand patterns
    brand_patterns = ['Glass Alchemy', 'GA']
    
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
    cleaned_title = re.sub(r'\s+', ' ', cleaned_title)
    
    return cleaned_title.strip()


def scrape_glass_alchemy_products(collection_handle='all', test_mode=False):
    """
    Scrapes Glass Alchemy products using Shopify's JSON API
    
    Args:
        collection_handle: The collection handle (e.g., 'all', 'first-gen-transparents')
        test_mode: If True, only scrape the first item
    """
    print(f"\nScraping Glass Alchemy collection: {collection_handle}")
    
    all_products = []
    seen_skus = {}
    duplicates = []
    page = 1
    
    while True:
        print(f"  Fetching page {page}...")
        
        # Shopify Collections JSON API endpoint
        url = f"https://glassalchemy.com/collections/{collection_handle}/products.json?page={page}&limit=250"
        
        try:
            req = urllib.request.Request(url)
            req.add_header('User-Agent', 'Mozilla/5.0')
            
            with urllib.request.urlopen(req, timeout=15) as response:
                json_content = response.read().decode('utf-8')
                data = json.loads(json_content)
            
            products = data.get('products', [])
            products_found = len(products)
            
            print(f"    Found {products_found} products on page {page}")
            
            if products_found == 0:
                print("  No more products found.")
                break
            
            for product_data in products:
                product_name = product_data.get('title', '')
                
                # Skip bundles
                if 'bundle' in product_name.lower():
                    print(f"    Skipping bundle: {product_name}")
                    continue
                
                # Skip products with "+" in the name
                if '+' in product_name:
                    print(f"    Skipping product with '+': {product_name}")
                    continue
                
                # Skip "Bag of Bits"
                if 'bag of bits' in product_name.lower():
                    print(f"    Skipping Bag of Bits: {product_name}")
                    continue
                
                # Skip "Gift Card"
                if 'gift card' in product_name.lower():
                    print(f"    Skipping Gift Card: {product_name}")
                    continue
                
                # Skip "Logo Mug"
                if 'logo mug' in product_name.lower():
                    print(f"    Skipping Logo Mug: {product_name}")
                    continue
                
                product = {
                    'name': product_name,
                    'url': f"/products/{product_data.get('handle', '')}",
                    'product_type': product_data.get('product_type', ''),
                    'vendor': product_data.get('vendor', ''),
                }
                
                # Get SKU from first variant
                variants = product_data.get('variants', [])
                if variants:
                    product['sku'] = variants[0].get('sku', '')
                else:
                    product['sku'] = ''
                
                # Get image from product data
                images = product_data.get('images', [])
                if images:
                    product['image_url'] = images[0].get('src', '')
                else:
                    product['image_url'] = ''
                
                # Get description
                body_html = product_data.get('body_html', '')
                description = re.sub(r'<[^>]+>', '', body_html)
                description = re.sub(r'\s+', ' ', description).strip()
                product['manufacturer_description'] = description
                
                product['manufacturer_url'] = f"https://glassalchemy.com{product['url']}"
                
                # Extract SKU from name if not in variant
                if not product.get('sku'):
                    name = product['name']
                    sku_match = re.search(r'^(\d{3,4})[,\s]', name)
                    if sku_match:
                        product['sku'] = sku_match.group(1)
                
                # If still no SKU, generate one from name hash
                if not product.get('sku'):
                    cleaned_name = remove_brand_from_title(product['name'])
                    name_hash = hashlib.md5(cleaned_name.encode('utf-8')).hexdigest()[:8]
                    product['sku'] = f"GA-{name_hash}"
                
                # Check for duplicate SKUs
                sku = product.get('sku')
                if sku:
                    if sku in seen_skus:
                        duplicates.append({
                            'sku': sku,
                            'name': product['name'],
                            'url': product['url'],
                            'original_name': seen_skus[sku]['name'],
                            'original_url': seen_skus[sku]['url']
                        })
                        print(f"    Skipping duplicate SKU {sku}: {product['name']}")
                    else:
                        seen_skus[sku] = {'name': product['name'], 'url': product['url']}
                        all_products.append(product)
                else:
                    all_products.append(product)
                
                if test_mode:
                    print("  Test mode: stopping after first product.")
                    return all_products, duplicates
            
            # Shopify returns less than 250 products if it's the last page
            if products_found < 250:
                print("  Last page reached.")
                break
            
            page += 1
            time.sleep(1)
            
        except urllib.error.HTTPError as e:
            if e.code == 404:
                print("  No more pages found (404).")
                break
            else:
                print(f"  HTTP Error {e.code}: {e.reason}")
                break
        except Exception as e:
            print(f"  Error fetching page {page}: {e}")
            import traceback
            traceback.print_exc()
            break
    
    print(f"  Total products found: {len(all_products)}")
    return all_products, duplicates


def main():
    test_mode = '--test' in sys.argv or '-test' in sys.argv
    
    if test_mode:
        print("Running in TEST MODE - will only scrape 1 item")
        print("-" * 60)
    
    print("Starting scrape of Glass Alchemy glass products...")
    print("=" * 60)
    
    # Scrape from the 'all' collection
    collection_handle = 'all'
    
    all_products, all_duplicates = scrape_glass_alchemy_products(
        collection_handle=collection_handle,
        test_mode=test_mode
    )
    
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
        csv_filename = 'glass_alchemy_products_test.csv' if test_mode else 'glass_alchemy_products.csv'
        
        with open(csv_filename, 'w', newline='', encoding='utf-8') as f:
            fieldnames = ['manufacturer', 'code', 'name', 'start_date', 'end_date', 
                         'manufacturer_description', 'tags', 'synonyms', 'coe', 'type',
                         'manufacturer_url', 'image_path', 'image_url']
            
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            
            for product in all_products:
                product_type = determine_product_type(product['name'], product.get('product_type'))
                
                cleaned_name = remove_brand_from_title(product['name'])
                code = product.get('sku', '')
                
                tags = extract_tags_from_name(cleaned_name)
                
                writer.writerow({
                    'manufacturer': 'GA',
                    'code': code,
                    'name': cleaned_name,
                    'start_date': '',
                    'end_date': '',
                    'manufacturer_description': product.get('manufacturer_description', ''),
                    'tags': tags,
                    'synonyms': '',
                    'coe': '33',  # Glass Alchemy is COE 33
                    'type': product_type,
                    'manufacturer_url': product.get('manufacturer_url', ''),
                    'image_path': '',
                    'image_url': product.get('image_url', '')
                })
        
        print(f"CSV results saved to {csv_filename}")
    except Exception as e:
        print(f"Could not save CSV: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()

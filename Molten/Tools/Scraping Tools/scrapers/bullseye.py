"""
Bullseye Glass (BE) scraper module.
Scrapes COE 90 products from shop.bullseyeglass.com using NetSuite API.
"""

import urllib.request
import urllib.error
import urllib.parse
import json
import re
import time
import html
import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from color_extractor import combine_tags
from scraper_config import get_page_delay, is_bot_protection_error


MANUFACTURER_CODE = 'BE'
MANUFACTURER_NAME = 'Bullseye Glass'
COE = '90'
BASE_URL = 'https://shop.bullseyeglass.com'


def clean_html(html_text):
    """Remove HTML tags and decode entities"""
    if not html_text:
        return ''
    # Remove HTML tags
    text = re.sub(r'<[^>]+>', ' ', html_text)
    # Decode HTML entities
    text = html.unescape(text)
    # Clean up whitespace
    text = re.sub(r'\s+', ' ', text).strip()
    return text


def extract_color_name(display_name):
    """
    Extract color name from display name.
    Bullseye display names include the full color description.
    Example: "Aventurine Bronze Transparent, Double-rolled, 3 mm, Fusible"
    We want just "Aventurine Bronze Transparent"
    """
    if not display_name:
        return ''

    # Remove common suffixes
    # Split on comma and take the first part (color name)
    parts = display_name.split(',')
    if parts:
        color_name = parts[0].strip()
        # Remove "Fusible" if it appears at the start/end
        color_name = re.sub(r'\s*\bFusible\b\s*', '', color_name, flags=re.IGNORECASE)
        return color_name.strip()

    return display_name


def determine_product_type(display_name):
    """
    Determine product type from display name.
    Bullseye makes sheet glass and frit.
    Examples:
    - "Aventurine Bronze Transparent, Double-rolled, 3 mm, Fusible" -> sheet
    - "Peacock Blue Transparent, Powder Frit, Fusible" -> frit
    """
    name_lower = display_name.lower() if display_name else ''

    if 'frit' in name_lower or 'powder' in name_lower:
        return 'frit'
    elif 'rod' in name_lower or 'stringer' in name_lower:
        return 'rod'
    elif 'billet' in name_lower or 'chunk' in name_lower:
        return 'other'
    else:
        return 'sheet'  # Default for Bullseye


def scrape_products(test_mode=False, max_items=None):
    """
    Scrape products from NetSuite API.

    Args:
        test_mode: If True, limit scraping for testing
        max_items: Maximum items to scrape

    Returns:
        tuple: (products_list, duplicates_list)
    """
    all_products = []
    seen_skus = {}
    duplicates = []

    # Track products by base color code (first 6 digits of SKU)
    # Format: base_code -> {'preferred': product_data, 'variants': [product_data, ...]}
    color_codes = {}

    # NetSuite API parameters
    # We fetch all items and filter for fusible (COE 90) glass in code
    # Fusible items end with -F
    limit = 50  # Items per page (max that works reliably)
    offset = 0

    while True:
        # Build API URL - simple query, we'll filter in code
        params = {
            'fieldset': 'search',
            'limit': str(limit),
            'offset': str(offset),
            'sort': 'itemid:asc'
        }

        url = f"{BASE_URL}/api/items?{urllib.parse.urlencode(params)}"

        print(f"  Fetching items {offset} to {offset + limit}...")

        try:
            req = urllib.request.Request(url)
            req.add_header('User-Agent', 'Mozilla/5.0')
            req.add_header('Accept', 'application/json')

            with urllib.request.urlopen(req, timeout=15) as response:
                data = json.loads(response.read().decode('utf-8'))

                total = data.get('total', 0)
                items = data.get('items', [])

                if not items:
                    print(f"    No more items at offset {offset}")
                    break

                print(f"    Found {len(items)} items (total: {total})")

                for item in items:
                    # Get item ID (SKU)
                    item_id = item.get('itemid', '')

                    if not item_id:
                        continue

                    # FILTER: Only include fusible (COE 90) glass items
                    # Fusible items end with -F
                    if not item_id.endswith('-F'):
                        continue

                    # Get display name
                    display_name = item.get('displayname', '') or item.get('storedisplayname2', '')

                    if not display_name:
                        display_name = item_id

                    # Extract color name from display name
                    color_name = extract_color_name(display_name)

                    # Get description
                    description = item.get('storedetaileddescription', '')

                    # Get product URL from urlcomponent (the proper slug)
                    url_component = item.get('urlcomponent', '')
                    if url_component:
                        product_url = f"/{url_component}"
                    else:
                        # Fallback: try _url field
                        product_url = item.get('_url', '')
                        if not product_url:
                            # Last resort: construct from item ID (lowercase SKU)
                            url_slug = item_id.lower().replace('_', '-')
                            product_url = f"/{url_slug}"

                    # Get image URL
                    image_url = ''
                    images = item.get('itemimages_detail', {}).get('urls', [])
                    if images and len(images) > 0:
                        image_url = images[0].get('url', '')
                        # Make absolute URL
                        if image_url and not image_url.startswith('http'):
                            image_url = f"{BASE_URL}{image_url}"

                    # Determine product type from display name
                    product_type = determine_product_type(display_name)

                    # Create product data
                    product_data = {
                        'name': color_name,
                        'sku': item_id,
                        'url': product_url,
                        'manufacturer_url': f"{BASE_URL}{product_url}" if product_url else '',
                        'manufacturer_description': clean_html(description),
                        'image_url': image_url,
                        'product_type': product_type,
                        'display_name': display_name  # Keep for reference
                    }

                    # Extract base color code (first 6 digits of SKU)
                    # Format: 001016-0030-F -> base code is 001016
                    base_code = item_id[:6] if len(item_id) >= 6 else item_id

                    # Check if this is the preferred variant (-30- for 3mm thickness)
                    is_preferred = '-30-' in item_id or '-0030-' in item_id

                    # Track by base color code
                    if base_code not in color_codes:
                        # First time seeing this color
                        color_codes[base_code] = {
                            'preferred': product_data if is_preferred else None,
                            'first': product_data,
                            'variants': [item_id]
                        }
                    else:
                        # Already have this color
                        color_codes[base_code]['variants'].append(item_id)

                        # Update preferred if this is the -30- variant
                        if is_preferred and not color_codes[base_code]['preferred']:
                            color_codes[base_code]['preferred'] = product_data

                    if max_items and len(color_codes) >= max_items:
                        print(f"  Reached max items limit ({max_items})")
                        break

                    if test_mode and len(color_codes) >= 3:
                        print("  Test mode: stopping after 3 unique colors")
                        break

                # Break out of both loops if we hit max_items or test_mode limit
                if (max_items and len(color_codes) >= max_items) or (test_mode and len(color_codes) >= 3):
                    break

                # Check if there are more items
                if offset + len(items) >= total:
                    # We've fetched all items
                    print(f"  Fetched all {total} items")
                    break

                offset += limit
                time.sleep(get_page_delay(MANUFACTURER_CODE))

        except urllib.error.HTTPError as e:
            if is_bot_protection_error(e):
                print(f"  ⚠️  Bot protection detected (HTTP {e.code})")
                print(f"  ⚠️  Stopping scrape to respect site's request")
                break
            else:
                print(f"  Error fetching items at offset {offset}: HTTP {e.code} - {e}")
                import traceback
                traceback.print_exc()
                break
        except Exception as e:
            print(f"  Error fetching items at offset {offset}: {e}")
            import traceback
            traceback.print_exc()
            break

    # Convert color_codes to final product list
    # For each color, use preferred variant (-30-) if available, otherwise use first variant
    print(f"\n  Processing {len(color_codes)} unique color codes...")

    for base_code, data in color_codes.items():
        # Select the product to keep
        selected_product = data['preferred'] if data['preferred'] else data['first']

        # Update the SKU to be just the base color code (first 6 digits)
        original_sku = selected_product['sku']
        selected_product['sku'] = base_code
        selected_product['original_sku'] = original_sku  # Keep original for reference

        all_products.append(selected_product)

        # Track duplicates (variants that were not selected)
        if len(data['variants']) > 1:
            selected_sku = selected_product['sku']
            for variant_sku in data['variants']:
                if variant_sku != selected_sku:
                    duplicates.append({
                        'sku': variant_sku,
                        'base_code': base_code,
                        'reason': f"Duplicate color {base_code} (kept {selected_sku})"
                    })

    print(f"  Selected {len(all_products)} products ({len(duplicates)} variants skipped)")

    return all_products, duplicates


def scrape(test_mode=False, max_items=None):
    """
    Scrape Bullseye Glass products.

    Args:
        test_mode: If True, limit scraping for testing
        max_items: Maximum number of items to scrape (for testing)

    Returns:
        tuple: (products_list, duplicates_list)
    """
    print(f"\n{'='*60}")
    print(f"Scraping {MANUFACTURER_NAME} ({MANUFACTURER_CODE})")
    print(f"{'='*60}")

    products, duplicates = scrape_products(
        test_mode=test_mode,
        max_items=max_items
    )

    print(f"  Total products found: {len(products)}")
    return products, duplicates


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
        product_type = product.get('product_type', 'sheet')
        code = product.get('sku', '')

        # Ensure code has manufacturer prefix
        if code and not code.upper().startswith(f"{MANUFACTURER_CODE}-"):
            code = f"{MANUFACTURER_CODE}-{code}"

        color_name = product.get('name', '')

        # Extract tags from color name and description
        description = product.get('manufacturer_description', '')
        manufacturer_url = product.get('manufacturer_url', '')
        tags = combine_tags(color_name, description, manufacturer_url, MANUFACTURER_CODE)

        csv_rows.append({
            'manufacturer': MANUFACTURER_CODE,
            'code': code,
            'name': color_name,
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
            'stock_type': ''  # Bullseye doesn't track stock_type in our system
        })

    return csv_rows


def main():
    """Main entry point for standalone testing"""
    test_mode = '--test' in sys.argv or '-test' in sys.argv

    if test_mode:
        print("Running in TEST MODE - will only scrape 3 items")
        print("-" * 60)

    print(f"Starting scrape of {MANUFACTURER_NAME} products...")
    print("=" * 60)

    products, duplicates = scrape(test_mode=test_mode)

    print("\n" + "=" * 60)
    print(f"Total products found: {len(products)}")
    print("=" * 60 + "\n")

    # Print duplicate report
    if duplicates:
        print("\n" + "!" * 60)
        print("DUPLICATE VARIANTS FOUND (these were skipped):")
        print("!" * 60)
        for dup in duplicates:
            print(f"\nSKU: {dup['sku']}")
            print(f"  Base Code: {dup['base_code']}")
            print(f"  Reason: {dup['reason']}")
        print("\n" + "!" * 60)
        print(f"Total variants skipped: {len(duplicates)}")
        print("!" * 60 + "\n")
    else:
        print("No duplicate variants found.\n")

    # Write CSV
    try:
        import csv
        csv_filename = 'bullseye_products_test.csv' if test_mode else 'bullseye_products.csv'

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

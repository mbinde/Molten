"""
Mike Peterson Glass scraper

Since Mike Peterson has a small, manually-curated catalog of 6 specialty tools,
this scraper returns a static list rather than scraping the website.
"""

import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Constants
MANUFACTURER_CODE = 'mikepeterson'
MANUFACTURER_NAME = 'Mike Peterson'
MANUFACTURER_URL = 'https://mpme-glass.com'
PRODUCT_TYPE = 'tools'

# Static product catalog (manually maintained)
# Mike Peterson specializes in unique, custom-built equipment
PRODUCTS = [
    {
        'name': 'NQALHA',
        'sku': 'nqalha',
        'category': 'Equipment',
        'description': 'Custom glass equipment by Mike Peterson',
        'price': None,
        'status': 'available',
        'product_url': f'{MANUFACTURER_URL}',
        'image_url': f'{MANUFACTURER_URL}/Nqalha/NqalhaImages/Version-2-8.jpg'
    },
    {
        'name': 'Torch Armadillo',
        'sku': 'torch-armadillo',
        'category': 'Torches',
        'description': 'Custom torch equipment by Mike Peterson',
        'price': None,
        'status': 'available',
        'product_url': f'{MANUFACTURER_URL}',
        'image_url': f'{MANUFACTURER_URL}/TorchArmadillo/VerticalMount.jpg'
    },
    {
        'name': 'Glass Lathe',
        'sku': 'glass-lathe',
        'category': 'Equipment',
        'description': 'Custom glass lathe equipment by Mike Peterson',
        'price': None,
        'status': 'available',
        'product_url': f'{MANUFACTURER_URL}',
        'image_url': f'{MANUFACTURER_URL}/ILWS-2-2025.jpg'
    },
    {
        'name': 'Octavius Squeezer',
        'sku': 'octavius-squeezer',
        'category': 'Hand Tools',
        'description': 'Custom hand tool by Mike Peterson',
        'price': None,
        'status': 'available',
        'product_url': f'{MANUFACTURER_URL}',
        'image_url': f'{MANUFACTURER_URL}/Squeezer/Squeezer.jpg'
    },
    {
        'name': 'Lap Wheel',
        'sku': 'lap-wheel',
        'category': 'Equipment',
        'description': 'Custom lap wheel equipment by Mike Peterson',
        'price': None,
        'status': 'available',
        'product_url': f'{MANUFACTURER_URL}',
        'image_url': f'{MANUFACTURER_URL}/LapWheelImages/001.jpg'
    },
    {
        'name': 'Wet Saw',
        'sku': 'wet-saw',
        'category': 'Equipment',
        'description': 'Custom wet saw equipment by Mike Peterson',
        'price': None,
        'status': 'available',
        'product_url': f'{MANUFACTURER_URL}',
        'image_url': f'{MANUFACTURER_URL}/WetSawImages/103.JPG'
    }
]


def scrape(test_mode=False, max_items=None):
    """
    Return Mike Peterson's static product catalog

    Args:
        test_mode (bool): If True, limit to 2-3 items for testing
        max_items (int): Maximum items to scrape (overrides test_mode)

    Returns:
        tuple: (products_list, duplicates_list)
    """
    print(f"\n{'='*60}")
    print(f"Loading {MANUFACTURER_NAME} catalog (static)")
    print(f"{'='*60}")

    products = PRODUCTS.copy()
    duplicates = []

    if test_mode and max_items is None:
        max_items = 3

    if max_items:
        products = products[:max_items]

    print(f"Loaded {len(products)} products from {MANUFACTURER_NAME}")

    for product in products:
        print(f"  ✓ {product['name']} (SKU: {product['sku']})")

    print(f"{'='*60}")

    return products, duplicates


def format_products_for_csv(products):
    """
    Format product dicts into CSV-ready dicts with standard fields.
    """
    formatted = []

    for product in products:
        formatted.append({
            'manufacturer': MANUFACTURER_CODE,
            'product_type': PRODUCT_TYPE,
            'code': product['sku'],
            'name': product['name'],
            'start_date': '',
            'end_date': '',
            'manufacturer_description': product.get('description', ''),
            'tags': '',
            'synonyms': '',
            'coe': '',
            'type': 'other',
            'manufacturer_url': product.get('product_url', ''),
            'image_url': product.get('image_url', ''),
            'stock_type': product.get('status', 'available')
        })

    return formatted


if __name__ == '__main__':
    # Test the scraper
    products, duplicates = scrape(test_mode=False)

    if products:
        print("\n" + "="*60)
        print("All products:")
        for product in products:
            print(f"\n{product['name']}")
            print(f"  SKU: {product['sku']}")
            print(f"  Category: {product.get('category', 'N/A')}")
            print(f"  Status: {product.get('status', 'available')}")

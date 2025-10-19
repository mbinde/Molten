#!/usr/bin/env python3
"""
Combined Glass Scraper
======================

Unified scraper that combines data from multiple glass manufacturers into a single CSV file.

Manufacturers:
- Boro Batch (BB)
- Creation is Messy (CIM
- Double Helix (DH)
- Glass Alchemy (GA)
- Trautman Art Glass (TAG)

Usage:
    python3 combined_glass_scraper.py                    # Run all manufacturers
    python3 combined_glass_scraper.py --test             # Test mode: 2-3 items per manufacturer
    python3 combined_glass_scraper.py --mfr BB          # Run specific manufacturer only
    python3 combined_glass_scraper.py --mfr BB --test   # Test specific manufacturer
"""

import sys
import csv
import argparse
from datetime import datetime

# Import manufacturer scrapers
from scrapers import boro_batch, cim, double_helix, glass_alchemy, tag


# Manufacturer registry
MANUFACTURERS = {
    'BB': {
        'name': 'Boro Batch',
        'module': boro_batch,
        'enabled': True
    },
    'CIM': {
        'name': 'Creation is Messy',
        'module': cim,
        'enabled': True
    },
    'DH': {
        'name': 'Double Helix',
        'module': double_helix,
        'enabled': True
    },
    'GA': {
        'name': 'Glass Alchemy',
        'module': glass_alchemy,
        'enabled': True
    },
    'TAG': {
        'name': 'Trautman Art Glass (TAG)',
        'module': tag,
        'enabled': True
    }
}


# CSV field names (standardized across all manufacturers)
FIELDNAMES = [
    'manufacturer',
    'code',
    'name',
    'start_date',
    'end_date',
    'manufacturer_description',
    'tags',
    'synonyms',
    'coe',
    'type',
    'manufacturer_url',
    'image_path',
    'image_url',
    'stock_type'  # Only DH uses this currently
]


def print_banner():
    """Print the application banner"""
    print("=" * 70)
    print("             COMBINED GLASS MANUFACTURER SCRAPER")
    print("=" * 70)
    print()


def print_summary(results):
    """Print summary of scraping results"""
    print("\n" + "=" * 70)
    print("SCRAPING SUMMARY")
    print("=" * 70)

    total_products = 0
    total_duplicates = 0

    for mfr_code, data in results.items():
        if data:
            products_count = len(data.get('products', []))
            duplicates_count = len(data.get('duplicates', []))
            total_products += products_count
            total_duplicates += duplicates_count

            print(f"\n{MANUFACTURERS[mfr_code]['name']} ({mfr_code}):")
            print(f"  Products: {products_count}")
            if duplicates_count > 0:
                print(f"  Duplicates skipped: {duplicates_count}")

    print(f"\nTOTAL PRODUCTS: {total_products}")
    if total_duplicates > 0:
        print(f"TOTAL DUPLICATES SKIPPED: {total_duplicates}")
    print("=" * 70)


def scrape_manufacturer(mfr_code, test_mode=False, max_items=None):
    """
    Scrape a single manufacturer.

    Args:
        mfr_code: Manufacturer code (e.g., 'BB', 'CIM')
        test_mode: If True, limit scraping for testing
        max_items: Maximum items to scrape (for testing)

    Returns:
        dict: {'products': list, 'duplicates': list, 'csv_rows': list}
    """
    mfr_info = MANUFACTURERS.get(mfr_code)
    if not mfr_info:
        raise ValueError(f"Unknown manufacturer: {mfr_code}")

    module = mfr_info['module']

    try:
        # Call the scraper's scrape() function
        products, duplicates = module.scrape(test_mode=test_mode, max_items=max_items)

        # Format products for CSV
        csv_rows = module.format_products_for_csv(products)

        return {
            'products': products,
            'duplicates': duplicates,
            'csv_rows': csv_rows
        }

    except Exception as e:
        print(f"\n❌ ERROR scraping {mfr_info['name']}: {e}")
        import traceback
        traceback.print_exc()
        raise  # Re-raise to stop execution per user requirement


def main(argv=None):
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description='Combined glass manufacturer scraper',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument(
        '--test',
        action='store_true',
        help='Test mode: scrape 2-3 items per manufacturer'
    )
    parser.add_argument(
        '--mfr',
        choices=list(MANUFACTURERS.keys()),
        help='Scrape only this manufacturer (e.g., BB, CIM, DH, GA, TAG)'
    )
    parser.add_argument(
        '--max-items',
        type=int,
        metavar='N',
        help='Maximum items to scrape per manufacturer (for testing)'
    )
    parser.add_argument(
        '--output',
        '-o',
        default='combined_glass_products.csv',
        help='Output CSV filename (default: combined_glass_products.csv)'
    )

    args = parser.parse_args(argv)

    print_banner()

    # Determine which manufacturers to scrape
    if args.mfr:
        manufacturers_to_scrape = [args.mfr]
        print(f"Scraping single manufacturer: {MANUFACTURERS[args.mfr]['name']} ({args.mfr})")
    else:
        manufacturers_to_scrape = [code for code, info in MANUFACTURERS.items() if info['enabled']]
        print(f"Scraping {len(manufacturers_to_scrape)} manufacturers: {', '.join(manufacturers_to_scrape)}")

    if args.test:
        print("🧪 TEST MODE: Limiting to 2-3 items per manufacturer")

    if args.max_items:
        print(f"📊 MAX ITEMS: {args.max_items} per manufacturer")

    print()

    # Scrape each manufacturer
    results = {}
    all_csv_rows = []

    for mfr_code in manufacturers_to_scrape:
        try:
            result = scrape_manufacturer(
                mfr_code,
                test_mode=args.test,
                max_items=args.max_items or (3 if args.test else None)
            )
            results[mfr_code] = result
            all_csv_rows.extend(result['csv_rows'])

        except Exception as e:
            print(f"\n❌ FATAL ERROR: Scraping failed for {MANUFACTURERS[mfr_code]['name']}")
            print("Stopping execution (per requirement: stop on any manufacturer failure)")
            return False

    # Print summary
    print_summary(results)

    # Write combined CSV
    output_filename = args.output
    if args.test and not args.output != 'combined_glass_products.csv':
        output_filename = 'combined_glass_products_test.csv'

    try:
        print(f"\n📝 Writing {len(all_csv_rows)} products to {output_filename}...")

        with open(output_filename, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=FIELDNAMES)
            writer.writeheader()
            writer.writerows(all_csv_rows)

        print(f"✅ Successfully wrote {output_filename}")
        print(f"\n🎉 Done! You can now import {output_filename} into Google Sheets.")
        return True

    except Exception as e:
        print(f"\n❌ ERROR writing CSV: {e}")
        import traceback
        traceback.print_exc()
        return False


if __name__ == '__main__':
    success = main()
    sys.exit(0 if success else 1)

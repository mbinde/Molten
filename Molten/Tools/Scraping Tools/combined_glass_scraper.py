#!/usr/bin/env python3
"""
Combined Glass Scraper
======================

Unified scraper that combines data from multiple glass manufacturers into a single CSV file.

Manufacturers:
- Boro Batch (BB)
- Bullseye Glass (BE)
- Creation is Messy (CIM)
- Delphi Superior (DS)
- Double Helix (DH)
- Effetre/Vetrofond (EF)
- Glass Alchemy (GA)
- Greasy Glass (GRE)
- Molten Aura Glass (MA)
- Momka Glass (MOM)
- Oceanside Glass (OC)
- Origin Glass (OR)
- Trautman Art Glass (TAG)
- Wissmach Glass (WM)

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
from concurrent.futures import ThreadPoolExecutor, as_completed

# Import manufacturer scrapers
from scrapers import boro_batch, bullseye, cim, delphi_superior, double_helix, effetre_vetrofond, glass_alchemy, greasy, molten_aura, momka, oceanside, origin, tag, wissmach


# Manufacturer registry
MANUFACTURERS = {
    'BB': {
        'name': 'Boro Batch',
        'module': boro_batch,
        'enabled': True
    },
    'BE': {
        'name': 'Bullseye Glass',
        'module': bullseye,
        'enabled': True
    },
    'CIM': {
        'name': 'Creation is Messy',
        'module': cim,
        'enabled': True
    },
    'DS': {
        'name': 'Delphi Superior',
        'module': delphi_superior,
        'enabled': True
    },
    'DH': {
        'name': 'Double Helix',
        'module': double_helix,
        'enabled': True
    },
    'EF': {
        'name': 'Effetre/Vetrofond',
        'module': effetre_vetrofond,
        'enabled': True
    },
    'GA': {
        'name': 'Glass Alchemy',
        'module': glass_alchemy,
        'enabled': True
    },
    'GRE': {
        'name': 'Greasy Glass',
        'module': greasy,
        'enabled': True
    },
    'MA': {
        'name': 'Molten Aura Glass',
        'module': molten_aura,
        'enabled': True
    },
    'MOM': {
        'name': 'Momka Glass',
        'module': momka,
        'enabled': True
    },
    'OC': {
        'name': 'Oceanside Glass',
        'module': oceanside,
        'enabled': True
    },
    'OR': {
        'name': 'Origin Glass',
        'module': origin,
        'enabled': True
    },
    'TAG': {
        'name': 'Trautman Art Glass (TAG)',
        'module': tag,
        'enabled': True
    },
    'WM': {
        'name': 'Wissmach Glass',
        'module': wissmach,
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
        help='Scrape only this manufacturer (e.g., BB, BE, CIM, DS, DH, EF, GA, GRE, MA, MOM, OC, OR, TAG, WM)'
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

    # Scrape each manufacturer in parallel
    results = {}
    all_csv_rows = []

    print("🚀 Running scrapers in parallel...\n")

    # Use ThreadPoolExecutor to run manufacturers in parallel
    # I/O-bound operations benefit from threading (waiting for network responses)
    max_workers = min(len(manufacturers_to_scrape), 12)  # Limit to 12 concurrent scrapers

    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        # Submit all scraping tasks
        future_to_mfr = {
            executor.submit(
                scrape_manufacturer,
                mfr_code,
                test_mode=args.test,
                max_items=args.max_items or (3 if args.test else None)
            ): mfr_code
            for mfr_code in manufacturers_to_scrape
        }

        # Process results as they complete
        for future in as_completed(future_to_mfr):
            mfr_code = future_to_mfr[future]
            try:
                result = future.result()
                results[mfr_code] = result
                all_csv_rows.extend(result['csv_rows'])
                print(f"✓ Completed: {MANUFACTURERS[mfr_code]['name']} ({len(result['csv_rows'])} products)")

            except Exception as e:
                print(f"\n❌ FATAL ERROR: Scraping failed for {MANUFACTURERS[mfr_code]['name']}")
                print(f"   Error: {e}")
                print("Stopping execution (per requirement: stop on any manufacturer failure)")
                # Cancel remaining tasks
                for f in future_to_mfr:
                    f.cancel()
                return False

    # Filter out assortment items (sample packs, sets, etc.)
    print("\n🔍 Filtering out assortment items...")
    original_count = len(all_csv_rows)
    all_csv_rows = [
        row for row in all_csv_rows
        if 'assortment' not in row.get('name', '').lower()
        and 'assortment' not in row.get('manufacturer_description', '').lower()
    ]
    filtered_count = original_count - len(all_csv_rows)
    if filtered_count > 0:
        print(f"   Filtered out {filtered_count} assortment items")

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

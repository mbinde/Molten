#!/usr/bin/env python3
"""
Combined Coatings Scraper
==========================

Unified scraper that combines data from multiple coating manufacturers into a single CSV file.

Coatings include: enamels, mica powders, lusters, and other surface applications.

Manufacturers:
- Jet Age Studio (JET) - Lumiere Lusters

Usage:
    python3 combined_coatings_scraper.py                    # Run all manufacturers
    python3 combined_coatings_scraper.py --test             # Test mode: 2-3 items per manufacturer
    python3 combined_coatings_scraper.py --mfr JET          # Run specific manufacturer only
    python3 combined_coatings_scraper.py --mfr JET --test   # Test specific manufacturer
"""

import sys
import csv
import argparse
from datetime import datetime
from url_utils import clean_manufacturer_url

# Import manufacturer scrapers
from scrapers import jetage
from scrapers import thompson


# Manufacturer registry
MANUFACTURERS = {
    'JET': {
        'name': 'Jet Age Studio',
        'module': jetage,
        'enabled': True
    },
    'THMP': {
        'name': 'Thompson Enamel',
        'module': thompson,
        'enabled': True
    },
}


# CSV output field names (must match what scrapers return)
FIELDNAMES = [
    'manufacturer',
    'product_type',  # Category: coating
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
    'stock_type'
]


def run_scraper(mfr_code, mfr_info, test_mode=False, max_items=None):
    """Run a single scraper and return its products"""
    print(f"\n{'='*70}")
    print(f"Scraping {mfr_info['name']} ({mfr_code})")
    print(f"{'='*70}\n")

    module = mfr_info['module']

    try:
        # Run scraper
        products, duplicates = module.scrape(test_mode=test_mode, max_items=max_items)
        print(f"  Scraped {len(products)} products ({len(duplicates)} duplicates)")

        # Format for CSV
        csv_products = module.format_products_for_csv(products)

        # Clean URLs
        for product in csv_products:
            product['manufacturer_url'] = clean_manufacturer_url(product['manufacturer_url'])

        return csv_products

    except Exception as e:
        print(f"  ❌ ERROR: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return []


def main(argv=None):
    """Main entry point"""
    parser = argparse.ArgumentParser(description='Combined coatings scraper')
    parser.add_argument('--test', action='store_true', help='Test mode: scrape only 2-3 items per manufacturer')
    parser.add_argument('--mfr', type=str, help='Scrape specific manufacturer only (e.g., JET)')
    parser.add_argument('--max-items', type=int, help='Maximum items to scrape per manufacturer')
    parser.add_argument('--output', type=str, default='coatings_catalog.csv', help='Output CSV file')
    args = parser.parse_args(argv)

    # Determine which manufacturers to scrape
    if args.mfr:
        if args.mfr not in MANUFACTURERS:
            print(f"ERROR: Unknown manufacturer '{args.mfr}'", file=sys.stderr)
            print(f"Available: {', '.join(MANUFACTURERS.keys())}", file=sys.stderr)
            sys.exit(1)

        manufacturers_to_scrape = {args.mfr: MANUFACTURERS[args.mfr]}
    else:
        manufacturers_to_scrape = {k: v for k, v in MANUFACTURERS.items() if v['enabled']}

    print(f"Scraping {len(manufacturers_to_scrape)} manufacturer(s)...")
    if args.test:
        print("⚠️  TEST MODE: Limiting to 2-3 items per manufacturer")
    if args.max_items:
        print(f"⚠️  Limiting to {args.max_items} items per manufacturer")

    # Run all scrapers
    all_products = []
    for mfr_code, mfr_info in manufacturers_to_scrape.items():
        products = run_scraper(mfr_code, mfr_info, test_mode=args.test, max_items=args.max_items)
        all_products.extend(products)

    # Write combined CSV
    print(f"\n{'='*70}")
    print(f"Writing combined CSV: {args.output}")
    print(f"{'='*70}\n")

    with open(args.output, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=FIELDNAMES)
        writer.writeheader()
        writer.writerows(all_products)

    print(f"✅ Wrote {len(all_products)} products to {args.output}")
    print(f"\nNext steps:")
    print(f"  1. Review the CSV file")
    print(f"  2. Run: python3 update_coatings_database.py")
    print(f"  3. Commit to git")

    return True


if __name__ == "__main__":
    main()

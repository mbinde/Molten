#!/usr/bin/env python3
"""
Export Coatings for App
========================

Converts coatings_database.json to app-ready coatings_app.json format.

This creates a temporary file that can be:
1. Inspected/debugged before copying to the app
2. Used by image_downloader.py to fetch images
3. Manually copied to Sources/Resources/coatings.json when ready

Usage:
    python3 export_coatings_for_app.py                # Export all coatings
    python3 export_coatings_for_app.py --output custom.json  # Custom output name
"""

import json
import argparse
from datetime import datetime


def export_for_app(database_file='coatings_database.json', output_file='coatings_app.json'):
    """
    Export coatings database to app-ready JSON format.

    Args:
        database_file: Path to coatings_database.json
        output_file: Path to output file (default: coatings_app.json)
    """
    print(f"Loading database: {database_file}")

    # Load the coatings database
    with open(database_file, 'r') as f:
        db = json.load(f)

    # Convert to app format
    coatings = []
    for key, product in db['products'].items():
        # Only include available products (skip discontinued)
        if product.get('status') != 'available':
            continue

        coating = {
            'stable_id': product['stable_id'],
            'code': product['code'],
            'name': product['name'],
            'manufacturer': product['manufacturer'],
            'manufacturer_description': product.get('manufacturer_description', ''),
            'tags': product.get('tags', ''),
            'image_url': product.get('image_url', ''),
            'image_path': product.get('image_path', ''),
            'manufacturer_url': product.get('manufacturer_url', ''),
            'product_type': 'coating',
            'coe': product.get('coe', '')
        }
        coatings.append(coating)

    # Sort by manufacturer then name
    coatings.sort(key=lambda x: (x['manufacturer'], x['name']))

    # Create output structure
    output = {
        'version': '1.0',
        'generated': datetime.now().isoformat(),
        'item_count': len(coatings),
        'coatings': coatings
    }

    # Write to file
    print(f"Writing {len(coatings)} coatings to: {output_file}")
    with open(output_file, 'w') as f:
        json.dump(output, f, indent=2)

    # Print summary
    manufacturers = {}
    for coating in coatings:
        mfr = coating['manufacturer']
        manufacturers[mfr] = manufacturers.get(mfr, 0) + 1

    print(f"\n✅ Export complete!")
    print(f"   Total: {len(coatings)} coatings")
    for mfr, count in sorted(manufacturers.items()):
        print(f"   {mfr}: {count} products")

    print(f"\n📁 Output file: {output_file}")
    print(f"\nNext steps:")
    print(f"  1. Review {output_file}")
    print(f"  2. Copy to app: cp {output_file} ../../Sources/Resources/coatings.json")
    print(f"  3. (Optional) Download images: python3 image_downloader.py {output_file}")


def main():
    parser = argparse.ArgumentParser(description='Export coatings database to app-ready JSON')
    parser.add_argument('--input', default='coatings_database.json', help='Input database file')
    parser.add_argument('--output', default='coatings_app.json', help='Output JSON file')
    args = parser.parse_args()

    export_for_app(args.input, args.output)


if __name__ == '__main__':
    main()

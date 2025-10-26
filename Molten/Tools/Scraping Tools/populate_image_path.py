#!/usr/bin/env python3
"""
Populate image_path Field in glass_database.json
=================================================

Updates the image_path field to use stable_id-based filenames.

Current: image_path = ""
New:     image_path = "{stable_id}.{ext}"

The extension is extracted from image_url.

Usage:
    python3 populate_image_path.py           # Dry run (show changes)
    python3 populate_image_path.py --execute # Actually update database
"""

import json
import sys
import argparse
from pathlib import Path
from urllib.parse import urlparse
import os


def get_extension_from_url(url):
    """
    Extract file extension from URL.

    Returns: extension (without dot) or 'jpg' as default
    """
    if not url:
        return 'jpg'

    parsed = urlparse(url)
    path = parsed.path

    # Get extension from path
    ext = os.path.splitext(path)[1]

    if ext:
        # Remove leading dot and convert to lowercase
        ext = ext.lstrip('.').lower()

        # Normalize common extensions
        if ext in ['jpeg']:
            return 'jpg'
        elif ext in ['webp', 'png', 'jpg', 'gif', 'heic', 'avif']:
            return ext
        else:
            # Unknown extension, default to jpg
            return 'jpg'
    else:
        # No extension in URL, default to jpg
        return 'jpg'


def populate_image_paths(database_path, dry_run=True):
    """
    Populate image_path field in glass_database.json.

    Returns: (updated_count, skipped_count, errors)
    """
    # Load database
    with open(database_path, 'r') as f:
        data = json.load(f)

    if 'products' not in data:
        raise ValueError("Database missing 'products' key")

    products = data['products']
    updated = 0
    skipped = 0
    errors = []

    print(f"Processing {len(products)} products...")

    for key, product in products.items():
        stable_id = product.get('stable_id')
        image_url = product.get('image_url')
        current_image_path = product.get('image_path', '')

        # Skip if missing stable_id
        if not stable_id:
            skipped += 1
            errors.append({
                'key': key,
                'reason': 'Missing stable_id',
                'code': product.get('code', 'UNKNOWN')
            })
            continue

        # Skip if missing image_url
        if not image_url:
            skipped += 1
            # Don't count as error - some items legitimately don't have images yet
            continue

        # Extract extension from URL
        ext = get_extension_from_url(image_url)

        # Generate new image_path
        new_image_path = f"{stable_id}.{ext}"

        # Update if different
        if current_image_path != new_image_path:
            product['image_path'] = new_image_path
            updated += 1

            if updated <= 10:
                print(f"  {key}: '' → '{new_image_path}'")

    # Show summary
    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)
    print(f"Total products: {len(products)}")
    print(f"Updated: {updated}")
    print(f"Skipped (no change needed): {len(products) - updated - skipped}")
    print(f"Skipped (missing data): {skipped}")

    if errors:
        print(f"\nErrors: {len(errors)}")
        for error in errors[:10]:
            print(f"  {error['key']}: {error['reason']}")

    if dry_run:
        print("\n" + "=" * 70)
        print("DRY RUN - Database not modified")
        print("=" * 70)
        print("\nTo execute the update, run:")
        print("  python3 populate_image_path.py --execute")
        return (updated, skipped, errors)

    # Save updated database
    with open(database_path, 'w') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    print("\n✅ Database updated successfully!")
    print(f"   Updated {updated} products")
    print(f"\nNext steps:")
    print("  1. Test export:")
    print("     python3 update_database.py --export ../../Sources/Resources/glassitems.json --strip-metadata")
    print("  2. Verify image_path in exported file:")
    print("     grep -A 2 'stable_id.*4CzH9v' ../../Sources/Resources/glassitems.json")

    return (updated, skipped, errors)


def main():
    parser = argparse.ArgumentParser(
        description='Populate image_path field in glass_database.json',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument(
        '--execute',
        action='store_true',
        help='Actually update database (default is dry run)'
    )
    parser.add_argument(
        '--database',
        default='glass_database.json',
        help='Path to glass_database.json (default: glass_database.json)'
    )

    args = parser.parse_args()

    # Resolve path
    database_path = Path(args.database)

    if not database_path.exists():
        print(f"❌ ERROR: {database_path} not found")
        return False

    try:
        updated, skipped, errors = populate_image_paths(
            database_path,
            dry_run=not args.execute
        )

        # Check for blockers
        if errors:
            serious_errors = [e for e in errors if e['reason'] == 'Missing stable_id']
            if serious_errors:
                print(f"\n⚠️  WARNING: {len(serious_errors)} products missing stable_id")
                print("   These products will not have image_path set")

        return True

    except Exception as e:
        print(f"❌ ERROR: {e}")
        import traceback
        traceback.print_exc()
        return False


if __name__ == '__main__':
    success = main()
    sys.exit(0 if success else 1)

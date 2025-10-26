#!/usr/bin/env python3
"""
Rename Product Images to stable_id Format
==========================================

Renames all product images from code-based filenames to stable_id-based filenames.

Current format: {manufacturer}-{code}.{ext} (e.g., BB-01-T-Mead.png)
New format:     {stable_id}.{ext}           (e.g., 2wjEBu.png)

Usage:
    python3 rename_images_to_stable_id.py           # Dry run (show what would happen)
    python3 rename_images_to_stable_id.py --execute # Actually rename files
    python3 rename_images_to_stable_id.py --verify  # Verify renamed files exist
"""

import json
import os
import sys
import argparse
from pathlib import Path
from collections import defaultdict


def load_glassitems(json_path):
    """Load glassitems.json and return items with mapping info"""
    with open(json_path, 'r') as f:
        data = json.load(f)

    # Handle different JSON structures
    if isinstance(data, list):
        items = data
    elif isinstance(data, dict) and 'glassitems' in data:
        items = data['glassitems']
    else:
        raise ValueError("Unknown JSON structure")

    return items


def find_existing_image(code, image_dir):
    """
    Find existing image file for a given code.

    Returns: (Path, extension) or (None, None) if not found
    """
    # Common extensions to try
    extensions = ['png', 'jpg', 'jpeg', 'PNG', 'JPG', 'JPEG', 'webp', 'gif', 'heic', 'avif']

    for ext in extensions:
        # Try exact match
        path = image_dir / f"{code}.{ext}"
        if path.exists():
            return (path, ext)

    return (None, None)


def analyze_mapping(items, image_dir):
    """
    Analyze the mapping between current files and new stable_id names.

    Returns: dict with statistics and mapping details
    """
    stats = {
        'total_items': len(items),
        'items_with_stable_id': 0,
        'items_with_code': 0,
        'existing_images_found': 0,
        'missing_images': 0,
        'duplicate_stable_ids': 0,
        'duplicate_codes': 0,
    }

    mappings = []  # List of (old_path, new_name, stable_id, code)
    missing = []   # List of (stable_id, code) for items without images

    stable_id_counts = defaultdict(int)
    code_counts = defaultdict(int)

    for item in items:
        stable_id = item.get('stable_id')
        code = item.get('code')

        if stable_id:
            stats['items_with_stable_id'] += 1
            stable_id_counts[stable_id] += 1

        if code:
            stats['items_with_code'] += 1
            code_counts[code] += 1

        if not stable_id or not code:
            continue

        # Find existing image
        existing_path, ext = find_existing_image(code, image_dir)

        if existing_path:
            stats['existing_images_found'] += 1
            new_name = f"{stable_id}.{ext}"
            mappings.append({
                'old_path': existing_path,
                'new_name': new_name,
                'stable_id': stable_id,
                'code': code,
                'manufacturer': item.get('manufacturer', 'UNKNOWN')
            })
        else:
            stats['missing_images'] += 1
            missing.append({
                'stable_id': stable_id,
                'code': code,
                'manufacturer': item.get('manufacturer', 'UNKNOWN')
            })

    # Count duplicates
    stats['duplicate_stable_ids'] = sum(1 for count in stable_id_counts.values() if count > 1)
    stats['duplicate_codes'] = sum(1 for count in code_counts.values() if count > 1)

    # Find stable_id duplicates
    duplicate_stable_ids = {sid: count for sid, count in stable_id_counts.items() if count > 1}

    return {
        'stats': stats,
        'mappings': mappings,
        'missing': missing,
        'duplicate_stable_ids': duplicate_stable_ids
    }


def print_analysis(analysis):
    """Print analysis results"""
    stats = analysis['stats']

    print("=" * 70)
    print("RENAME ANALYSIS")
    print("=" * 70)
    print(f"\nItems in glassitems.json: {stats['total_items']}")
    print(f"  - With stable_id: {stats['items_with_stable_id']}")
    print(f"  - With code: {stats['items_with_code']}")

    print(f"\nImage files:")
    print(f"  ✓ Found: {stats['existing_images_found']}")
    print(f"  ✗ Missing: {stats['missing_images']}")

    if stats['duplicate_stable_ids'] > 0:
        print(f"\n⚠️  WARNING: {stats['duplicate_stable_ids']} duplicate stable_ids found!")
        print("   This could cause file collisions!")

    if stats['duplicate_codes'] > 0:
        print(f"\n⚠️  WARNING: {stats['duplicate_codes']} duplicate codes found!")

    # Show sample mappings
    if analysis['mappings']:
        print("\n" + "=" * 70)
        print("SAMPLE MAPPINGS (first 10)")
        print("=" * 70)
        for mapping in analysis['mappings'][:10]:
            old_name = mapping['old_path'].name
            new_name = mapping['new_name']
            print(f"{old_name:50} → {new_name}")

    # Show duplicate stable_ids if any
    if analysis['duplicate_stable_ids']:
        print("\n" + "!" * 70)
        print("DUPLICATE STABLE_IDs")
        print("!" * 70)
        for stable_id, count in analysis['duplicate_stable_ids'].items():
            print(f"{stable_id}: {count} occurrences")

    # Show missing images (first 20)
    if analysis['missing']:
        print("\n" + "?" * 70)
        print(f"MISSING IMAGES (showing first 20 of {len(analysis['missing'])})")
        print("?" * 70)
        for item in analysis['missing'][:20]:
            print(f"{item['code']:50} (stable_id: {item['stable_id']})")


def execute_rename(mappings, image_dir):
    """
    Execute the rename operation.

    Returns: (success_count, error_count)
    """
    success = 0
    errors = 0

    print("\n" + "=" * 70)
    print("EXECUTING RENAME")
    print("=" * 70)

    for mapping in mappings:
        old_path = mapping['old_path']
        new_name = mapping['new_name']
        new_path = image_dir / new_name

        try:
            # Check if target already exists
            if new_path.exists():
                print(f"⚠️  SKIP: {new_name} already exists")
                continue

            # Rename
            old_path.rename(new_path)
            success += 1

            if success % 100 == 0:
                print(f"✓ Renamed {success} files...")

        except Exception as e:
            errors += 1
            print(f"✗ ERROR renaming {old_path.name}: {e}")

    print(f"\n✅ Successfully renamed: {success}")
    if errors > 0:
        print(f"❌ Errors: {errors}")

    return (success, errors)


def verify_renamed_files(items, image_dir):
    """
    Verify that renamed files exist with stable_id names.

    Returns: (found_count, missing_count)
    """
    found = 0
    missing = 0
    missing_details = []

    print("\n" + "=" * 70)
    print("VERIFYING RENAMED FILES")
    print("=" * 70)

    for item in items:
        stable_id = item.get('stable_id')
        if not stable_id:
            continue

        # Try common extensions
        extensions = ['png', 'jpg', 'jpeg', 'PNG', 'JPG', 'JPEG', 'webp', 'gif', 'heic', 'avif']
        found_file = False

        for ext in extensions:
            path = image_dir / f"{stable_id}.{ext}"
            if path.exists():
                found += 1
                found_file = True
                break

        if not found_file:
            missing += 1
            missing_details.append({
                'stable_id': stable_id,
                'code': item.get('code', 'UNKNOWN'),
                'manufacturer': item.get('manufacturer', 'UNKNOWN')
            })

    print(f"\n✓ Found: {found} files")
    print(f"✗ Missing: {missing} files")

    if missing_details and missing <= 50:
        print("\nMissing files:")
        for item in missing_details:
            print(f"  {item['stable_id']} ({item['code']})")

    return (found, missing)


def main():
    parser = argparse.ArgumentParser(
        description='Rename product images to stable_id format',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument(
        '--execute',
        action='store_true',
        help='Actually rename files (default is dry run)'
    )
    parser.add_argument(
        '--verify',
        action='store_true',
        help='Verify that renamed files exist'
    )
    parser.add_argument(
        '--json',
        default='../../Sources/Resources/glassitems.json',
        help='Path to glassitems.json (default: ../../Sources/Resources/glassitems.json)'
    )
    parser.add_argument(
        '--images',
        default='../../Sources/Resources/product-images',
        help='Path to product-images directory (default: ../../Sources/Resources/product-images)'
    )

    args = parser.parse_args()

    # Resolve paths
    script_dir = Path(__file__).parent
    json_path = script_dir / args.json
    image_dir = script_dir / args.images

    if not json_path.exists():
        print(f"❌ ERROR: {json_path} not found")
        return False

    if not image_dir.exists():
        print(f"❌ ERROR: {image_dir} not found")
        return False

    # Load items
    print(f"Loading {json_path}...")
    items = load_glassitems(json_path)
    print(f"Loaded {len(items)} items\n")

    if args.verify:
        # Verify mode
        verify_renamed_files(items, image_dir)
        return True

    # Analyze mapping
    analysis = analyze_mapping(items, image_dir)
    print_analysis(analysis)

    # Check for blockers
    if analysis['duplicate_stable_ids']:
        print("\n❌ BLOCKED: Cannot proceed with duplicate stable_ids")
        print("   Fix duplicates in the database first")
        return False

    if args.execute:
        # Execute rename
        success, errors = execute_rename(analysis['mappings'], image_dir)

        if errors == 0:
            print("\n✅ Rename completed successfully!")
            print("\nYou can verify with:")
            print("  python3 rename_images_to_stable_id.py --verify")
            return True
        else:
            print(f"\n⚠️  Rename completed with {errors} errors")
            return False
    else:
        # Dry run
        print("\n" + "=" * 70)
        print("DRY RUN - No files were renamed")
        print("=" * 70)
        print("\nTo execute the rename, run:")
        print("  python3 rename_images_to_stable_id.py --execute")
        return True


if __name__ == '__main__':
    success = main()
    sys.exit(0 if success else 1)

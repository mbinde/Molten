#!/usr/bin/env python3
"""
Bulk Import Suggested Tags - Applies AI-suggested tags to the database without marking as approved.

This script:
1. Reads color_tag_suggestions.json (AI-generated suggestions)
2. Updates glass_database.json with suggested tags
3. Does NOT mark tags as approved (they remain pending for manual review)
4. Re-exports to glass_database_export.json

Usage:
    python3 bulk_import_suggestions.py              # Import and show diff
    python3 bulk_import_suggestions.py --commit     # Import and commit to git
    python3 bulk_import_suggestions.py --dry-run    # Show what would change
"""

import json
import sys
import argparse
from datetime import datetime
from pathlib import Path

# Paths
SCRIPT_DIR = Path(__file__).parent
DATABASE_PATH = SCRIPT_DIR / "glass_database.json"
EXPORT_PATH = SCRIPT_DIR / "glass_database_export.json"
SUGGESTIONS_PATH = SCRIPT_DIR / "color_tag_suggestions.json"


def load_database():
    """Load the glass products database."""
    with open(DATABASE_PATH, 'r') as f:
        return json.load(f)


def load_suggestions():
    """Load AI-generated tag suggestions."""
    if not SUGGESTIONS_PATH.exists():
        print(f"❌ No suggestions file found at: {SUGGESTIONS_PATH}")
        print("   Run color_tag_analyzer.py first to generate suggestions.")
        sys.exit(1)

    with open(SUGGESTIONS_PATH, 'r') as f:
        return json.load(f)


def import_tags(db, suggestions, dry_run=False):
    """
    Import suggested tags into database without marking as approved.

    Returns: dict with statistics
    """
    stats = {
        'total_suggestions': 0,
        'products_updated': 0,
        'tags_added': 0,
        'tags_removed': 0,
        'tags_unchanged': 0,
        'products_not_found': []
    }

    suggested_products = suggestions.get('products', {})
    stats['total_suggestions'] = len(suggested_products)

    if stats['total_suggestions'] == 0:
        print("⚠️  No suggested products found in suggestions file")
        return stats

    db_products = db.get('products', {})

    # Build stable_id lookup
    stable_id_to_key = {}
    for key, product in db_products.items():
        sid = product.get('stable_id')
        if sid:
            stable_id_to_key[sid] = key

    for stable_id, suggestion in suggested_products.items():
        # Find product in database by stable_id
        if stable_id not in stable_id_to_key:
            stats['products_not_found'].append(stable_id)
            print(f"⚠️  Product not found in database: {stable_id}")
            continue

        product_key = stable_id_to_key[stable_id]
        product = db_products[product_key]
        suggested_tags = suggestion.get('suggested_tags', [])

        # Current tags in database
        current_tags = product.get('tags', [])
        if isinstance(current_tags, str):
            # Parse if it's a JSON string
            try:
                current_tags = json.loads(f'[{current_tags}]') if current_tags else []
            except:
                current_tags = []

        # Normalize to lowercase list
        if not isinstance(current_tags, list):
            current_tags = []
        current_tags = [str(t).strip().lower() for t in current_tags if t]

        # Normalize suggested tags
        suggested_tags = [str(t).strip().lower() for t in suggested_tags if t]

        # Calculate changes
        current_set = set(current_tags)
        suggested_set = set(suggested_tags)

        added = suggested_set - current_set
        removed = current_set - suggested_set
        unchanged = current_set & suggested_set

        if added or removed:
            stats['products_updated'] += 1
            stats['tags_added'] += len(added)
            stats['tags_removed'] += len(removed)
            stats['tags_unchanged'] += len(unchanged)

            print(f"\n{product.get('manufacturer', '?')}-{product.get('name', '?')} ({stable_id}):")
            if added:
                print(f"  + Added: {sorted(added)}")
            if removed:
                print(f"  - Removed: {sorted(removed)}")

            # Update database (if not dry run)
            if not dry_run:
                product['tags'] = sorted(list(suggested_set))

    return stats


def export_database(db):
    """Export database to JSON format for app (excludes discontinued and excluded products)."""
    print(f"\nExporting to: {EXPORT_PATH}")

    # Filter to only available products (exclude discontinued and excluded)
    available_products = [
        product for product in db.get('products', {}).values()
        if product.get('status') == 'available'
    ]

    export_data = {
        "version": "1.0",
        "generated": datetime.now().isoformat(),
        "item_count": len(available_products),
        "glassitems": available_products
    }

    with open(EXPORT_PATH, 'w') as f:
        json.dump(export_data, f, indent=2)

    excluded_count = sum(1 for p in db.get('products', {}).values() if p.get('status') == 'excluded')
    discontinued_count = sum(1 for p in db.get('products', {}).values() if p.get('status') == 'discontinued')

    print(f"✅ Exported {export_data['item_count']} available glass items")
    if excluded_count > 0:
        print(f"   (Excluded {excluded_count} items marked as excluded)")
    if discontinued_count > 0:
        print(f"   (Excluded {discontinued_count} items marked as discontinued)")


def main():
    parser = argparse.ArgumentParser(description='Bulk import AI-suggested tags without marking as approved')
    parser.add_argument('--dry-run', action='store_true', help='Show changes without modifying database')
    parser.add_argument('--commit', action='store_true', help='Commit changes to git')
    args = parser.parse_args()

    print("=" * 70)
    print("BULK IMPORT SUGGESTED TAGS")
    print("=" * 70)
    print()
    print("⚠️  WARNING: This will replace ALL existing tags with AI suggestions!")
    print("   Tags will NOT be marked as approved - you can still review them later.")
    print()

    if args.dry_run:
        print("⚠️  DRY RUN MODE - No changes will be saved")
        print()

    # Load data
    print("Loading database...")
    db = load_database()
    print(f"  Found {len(db.get('products', {}))} products")

    print("Loading suggestions...")
    suggestions = load_suggestions()
    suggestion_count = len(suggestions.get('products', {}))
    print(f"  Found {suggestion_count} suggested products")

    if suggestion_count == 0:
        print("\n❌ No suggested products to import!")
        print("   Run color_tag_analyzer.py first to generate suggestions.")
        return

    # Import tags
    print()
    print("=" * 70)
    print("IMPORTING TAGS")
    print("=" * 70)

    stats = import_tags(db, suggestions, dry_run=args.dry_run)

    # Summary
    print()
    print("=" * 70)
    print("SUMMARY")
    print("=" * 70)
    print(f"Total suggestions processed: {stats['total_suggestions']}")
    print(f"Products updated: {stats['products_updated']}")
    print(f"Tags added: {stats['tags_added']}")
    print(f"Tags removed: {stats['tags_removed']}")
    print(f"Tags unchanged: {stats['tags_unchanged']}")

    if stats['products_not_found']:
        print(f"\n⚠️  Products not found in database: {len(stats['products_not_found'])}")

    if args.dry_run:
        print("\n✅ Dry run complete - no changes saved")
        return

    if stats['products_updated'] == 0:
        print("\n✅ No changes needed - all tags already up to date")
        return

    # Save database
    print()
    print("Saving updated database...")
    with open(DATABASE_PATH, 'w') as f:
        json.dump(db, f, indent=2)
    print(f"✅ Saved: {DATABASE_PATH}")

    # Export for app
    export_database(db)

    # Git commit
    if args.commit:
        print()
        print("Committing to git...")
        import subprocess

        # Add files
        subprocess.run(['git', 'add', str(DATABASE_PATH), str(EXPORT_PATH)], cwd=SCRIPT_DIR)

        # Commit with summary
        commit_msg = f"Bulk import suggested tags: {stats['products_updated']} products, +{stats['tags_added']} -{stats['tags_removed']} tags"
        subprocess.run(['git', 'commit', '-m', commit_msg], cwd=SCRIPT_DIR)

        print(f"✅ Committed: {commit_msg}")

    print()
    print("=" * 70)
    print("✅ IMPORT COMPLETE!")
    print("=" * 70)
    print()
    print("Next steps:")
    print("  1. Review changes with 'git diff'")
    if not args.commit:
        print("  2. Commit changes with 'git commit'")
    print(f"  {2 if not args.commit else 1}. Use review_color_tags.sh to manually review/approve tags")
    print(f"  {3 if not args.commit else 2}. Copy glass_database_export.json to app Resources/")
    print(f"  {4 if not args.commit else 3}. Rebuild app to see new tags")


if __name__ == "__main__":
    main()

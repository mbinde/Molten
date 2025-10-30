#!/usr/bin/env python3
"""
Merge Approved Tags - Applies user-approved color tags back to the database.

This script:
1. Reads color_tag_approvals.json (from web review interface)
2. Updates glass_database.json with approved tags
3. Re-exports to glass_database_export.json
4. Optionally commits changes to git

Usage:
    python3 merge_approved_tags.py              # Merge and show diff
    python3 merge_approved_tags.py --commit     # Merge and commit to git
    python3 merge_approved_tags.py --dry-run    # Show what would change
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
APPROVALS_PATH = SCRIPT_DIR / "color_tag_approvals.json"


def load_database():
    """Load the glass products database."""
    with open(DATABASE_PATH, 'r') as f:
        return json.load(f)


def load_approvals():
    """Load user approvals."""
    if not APPROVALS_PATH.exists():
        print(f"❌ No approvals file found at: {APPROVALS_PATH}")
        print("   Run the web review interface first to create approvals.")
        sys.exit(1)

    with open(APPROVALS_PATH, 'r') as f:
        return json.load(f)


def merge_tags(db, approvals, dry_run=False):
    """
    Merge approved tags into database.

    Returns: dict with statistics
    """
    stats = {
        'total_approvals': 0,
        'products_updated': 0,
        'products_excluded': 0,
        'tags_added': 0,
        'tags_removed': 0,
        'tags_unchanged': 0,
        'products_not_found': []
    }

    approved_products = approvals.get('products', {})
    stats['total_approvals'] = len(approved_products)

    if stats['total_approvals'] == 0:
        print("⚠️  No approved products found in approvals file")
        return stats

    db_products = db.get('products', {})

    # Build stable_id lookup
    stable_id_to_key = {}
    for key, product in db_products.items():
        sid = product.get('stable_id')
        if sid:
            stable_id_to_key[sid] = key

    for stable_id, approval in approved_products.items():
        # Handle excluded products
        if approval.get('status') == 'excluded':
            # Find product in database by stable_id
            if stable_id not in stable_id_to_key:
                stats['products_not_found'].append(stable_id)
                print(f"⚠️  Product not found in database: {stable_id}")
                continue

            product_key = stable_id_to_key[stable_id]
            product = db_products[product_key]

            # Mark as excluded
            if not dry_run:
                product['status'] = 'excluded'
                stats['products_excluded'] += 1
                print(f"\n⊗ Excluded: {product.get('manufacturer', '?')}-{product.get('name', '?')} ({stable_id})")
                if approval.get('excluded_reason'):
                    print(f"  Reason: {approval.get('excluded_reason')}")
            continue

        # Skip if not actually approved
        if approval.get('status') != 'approved':
            continue

        # Find product in database by stable_id
        if stable_id not in stable_id_to_key:
            stats['products_not_found'].append(stable_id)
            print(f"⚠️  Product not found in database: {stable_id}")
            continue

        product_key = stable_id_to_key[stable_id]
        product = db_products[product_key]
        approved_tags = approval.get('approved_tags', [])

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

        # Normalize approved tags
        approved_tags = [str(t).strip().lower() for t in approved_tags if t]

        # Calculate changes
        current_set = set(current_tags)
        approved_set = set(approved_tags)

        added = approved_set - current_set
        removed = current_set - approved_set
        unchanged = current_set & approved_set

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
                product['tags'] = sorted(list(approved_set))

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
    parser = argparse.ArgumentParser(description='Merge approved color tags into database')
    parser.add_argument('--dry-run', action='store_true', help='Show changes without modifying database')
    parser.add_argument('--commit', action='store_true', help='Commit changes to git')
    args = parser.parse_args()

    print("=" * 70)
    print("MERGE APPROVED COLOR TAGS")
    print("=" * 70)

    if args.dry_run:
        print("⚠️  DRY RUN MODE - No changes will be saved")

    print()

    # Load data
    print("Loading database...")
    db = load_database()
    print(f"  Found {len(db.get('products', {}))} products")

    print("Loading approvals...")
    approvals = load_approvals()
    approved_count = len([p for p in approvals.get('products', {}).values() if p.get('status') == 'approved'])
    print(f"  Found {approved_count} approved products")

    if approved_count == 0:
        print("\n❌ No approved products to merge!")
        print("   Use the web interface at /admin/color-tags to review and approve tags.")
        return

    # Merge tags
    print()
    print("=" * 70)
    print("MERGING TAGS")
    print("=" * 70)

    stats = merge_tags(db, approvals, dry_run=args.dry_run)

    # Summary
    print()
    print("=" * 70)
    print("SUMMARY")
    print("=" * 70)
    print(f"Total approvals processed: {stats['total_approvals']}")
    print(f"Products updated: {stats['products_updated']}")
    print(f"Products excluded: {stats['products_excluded']}")
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
        subprocess.run(['git', 'add', str(DATABASE_PATH), str(EXPORT_PATH)], cwd=SCRIPT_DIR.parent.parent)

        # Commit with summary
        commit_parts = [f"Update color tags: {stats['products_updated']} products"]
        if stats['products_excluded'] > 0:
            commit_parts.append(f"{stats['products_excluded']} excluded")
        commit_parts.append(f"+{stats['tags_added']} -{stats['tags_removed']} tags")
        commit_msg = ", ".join(commit_parts)
        subprocess.run(['git', 'commit', '-m', commit_msg], cwd=SCRIPT_DIR.parent.parent)

        print(f"✅ Committed: {commit_msg}")

    print()
    print("=" * 70)
    print("✅ MERGE COMPLETE!")
    print("=" * 70)
    print()
    print("Next steps:")
    print("  1. Review changes with 'git diff'")
    if not args.commit:
        print("  2. Commit changes with 'git commit'")
    print(f"  {2 if not args.commit else 1}. Copy glass_database_export.json to app Resources/")
    print(f"  {3 if not args.commit else 2}. Rebuild app to see new tags")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
Git+JSON Database Updater for Glass Products
==============================================

This script maintains a version-controlled JSON database of glass products:
- Runs scrapers to get latest data from manufacturer websites
- Filters out excluded URLs (see excluded_urls.txt)
- Applies SKU overrides for products with missing/incorrect codes (see sku_overrides.txt)
- Removes duplicates with identical URLs (same product in multiple lists)
- Compares with existing database
- Automatically detects duplicate keys with different URLs
- Tracks when products were last seen
- Marks discontinued products (never deletes historical data)
- Shows diff before saving
- Commits changes to Git

Usage:
    python3 update_database.py                    # Update from all manufacturers
    python3 update_database.py --test             # Test mode (2-3 items)
    python3 update_database.py --mfr BB           # Update single manufacturer
    python3 update_database.py --dry-run          # Show changes without saving
    python3 update_database.py --auto-commit      # Automatically commit to Git

URL Exclusion:
    Edit excluded_urls.txt to add product URLs that should never be included
    (e.g., sample packs, gift sets, non-individual products)

SKU Overrides:
    Edit sku_overrides.txt to fix products with missing or incorrect SKU codes
    Format: URL<TAB>SKU (tab-separated, one per line)
"""

import json
import csv
import subprocess
import sys
from datetime import datetime
from collections import defaultdict
import argparse
import os
import hashlib

# Import the combined scraper
import combined_glass_scraper


# Database schema version (increment when schema changes)
DATABASE_VERSION = "1.0"
DATABASE_FILE = "glass_database.json"
EXCLUDED_URLS_FILE = "excluded_urls.txt"
SKU_OVERRIDES_FILE = "sku_overrides.txt"


def generate_stable_id(manufacturer, code, existing_ids):
    """
    Generate a short, stable ID from manufacturer and SKU code.

    Uses hash-based generation for determinism. If collision occurs,
    increments the last character until unique.

    Args:
        manufacturer: Manufacturer code (e.g., 'BB', 'CIM')
        code: Product SKU (e.g., '001', 'TEST-123')
        existing_ids: Set of already-assigned stable IDs

    Returns:
        6-character alphanumeric stable ID (e.g., 'A3F9K2')
    """
    # Combine manufacturer and code for hashing
    combined = f"{manufacturer}:{code}"

    # Hash it with SHA-256
    hash_bytes = hashlib.sha256(combined.encode('utf-8')).digest()

    # Base62 character set (alphanumeric, excluding confusing chars)
    # Removed: I, O, l (look like 1, 0, 1)
    base62_chars = "0123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz"

    # Take first 4 bytes (32 bits), convert to base62
    num = int.from_bytes(hash_bytes[:4], byteorder='big')

    # Generate 6-character ID
    stable_id = ''
    for _ in range(6):
        stable_id = base62_chars[num % len(base62_chars)] + stable_id
        num //= len(base62_chars)

    # Handle collision (very rare, but possible)
    original_id = stable_id
    collision_counter = 0

    while stable_id in existing_ids:
        collision_counter += 1
        # Increment last character: A3F9K2 → A3F9K3, A3F9K4, etc.
        last_char = stable_id[-1]
        last_char_index = base62_chars.index(last_char)
        new_last_char = base62_chars[(last_char_index + collision_counter) % len(base62_chars)]
        stable_id = stable_id[:-1] + new_last_char

        # Safety: if we've wrapped around, modify second-to-last char too
        if collision_counter > len(base62_chars):
            # This should never happen in practice
            raise ValueError(f"Unable to resolve collision for {manufacturer}:{code} after {collision_counter} attempts")

    return stable_id


class ProductDatabase:
    """Manages the glass product database with version control"""

    def __init__(self, filepath=DATABASE_FILE):
        self.filepath = filepath
        self.data = self._load_database()
        self.excluded_urls = self._load_excluded_urls()
        self.sku_overrides = self._load_sku_overrides()

    def _load_database(self):
        """Load existing database or create new one"""
        if os.path.exists(self.filepath):
            with open(self.filepath, 'r', encoding='utf-8') as f:
                return json.load(f)
        else:
            return {
                'version': DATABASE_VERSION,
                'last_updated': None,
                'products': {}
            }

    def _load_excluded_urls(self):
        """Load list of URLs to exclude from database"""
        excluded = set()
        if os.path.exists(EXCLUDED_URLS_FILE):
            with open(EXCLUDED_URLS_FILE, 'r', encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    # Skip comments and empty lines
                    if line and not line.startswith('#'):
                        excluded.add(line)
        return excluded

    def _load_sku_overrides(self):
        """Load SKU override mappings from file"""
        overrides = {}
        if os.path.exists(SKU_OVERRIDES_FILE):
            with open(SKU_OVERRIDES_FILE, 'r', encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    # Skip comments and empty lines
                    if line and not line.startswith('#'):
                        parts = line.split('\t')
                        if len(parts) == 2:
                            url, sku = parts
                            overrides[url] = sku
        return overrides

    def filter_excluded_urls(self, products_csv):
        """
        Remove products with URLs in the exclusion list.

        Returns: (filtered_list, excluded_count)
        """
        if not self.excluded_urls:
            return products_csv, 0

        filtered = []
        excluded_count = 0

        for row in products_csv:
            url = row.get('manufacturer_url', '')
            if url in self.excluded_urls:
                excluded_count += 1
                print(f"   ⊗ Excluded: {row['manufacturer']} - {row['name']} ({row['code']})")
            else:
                filtered.append(row)

        return filtered, excluded_count

    def apply_sku_overrides(self, products_csv):
        """
        Apply SKU overrides for products with missing or incorrect SKUs.

        Returns: (products_list, override_count)
        """
        if not self.sku_overrides:
            return products_csv, 0

        override_count = 0

        for row in products_csv:
            url = row.get('manufacturer_url', '')
            if url in self.sku_overrides:
                old_sku = row['code']
                new_sku = self.sku_overrides[url]
                row['code'] = new_sku
                override_count += 1
                print(f"   ⟳ SKU Override: {row['manufacturer']} - {row['name']}: {old_sku} → {new_sku}")

        return products_csv, override_count

    def save_database(self):
        """Save database to JSON file"""
        self.data['last_updated'] = datetime.now().isoformat()

        with open(self.filepath, 'w', encoding='utf-8') as f:
            json.dump(self.data, f, indent=2, ensure_ascii=False)

        print(f"\n✅ Database saved to {self.filepath}")

    def get_product_key(self, manufacturer, code):
        """Generate unique product key"""
        return f"{manufacturer}:{code}"

    def deduplicate_same_url(self, products_csv):
        """
        Remove duplicates with identical URLs (same product in multiple lists).
        Keep only the first occurrence.

        Returns: (deduplicated_list, dedup_count)
        """
        seen_keys = {}
        deduplicated = []
        dedup_count = 0

        for row in products_csv:
            key = self.get_product_key(row['manufacturer'], row['code'])
            url = row.get('manufacturer_url', '')

            if key not in seen_keys:
                # First time seeing this key
                seen_keys[key] = url
                deduplicated.append(row)
            else:
                # Duplicate key - check if URL matches
                if seen_keys[key] == url and url:
                    # Same URL - skip this duplicate (same product, multiple lists)
                    dedup_count += 1
                else:
                    # Different URL or no URL - keep for error reporting
                    deduplicated.append(row)

        return deduplicated, dedup_count

    def detect_duplicates(self, new_products_csv):
        """
        Detect duplicate keys with DIFFERENT URLs (actual conflicts)
        Returns: (has_duplicates, duplicate_report)
        """
        key_counts = defaultdict(list)

        for row in new_products_csv:
            key = self.get_product_key(row['manufacturer'], row['code'])
            key_counts[key].append({
                'manufacturer': row['manufacturer'],
                'code': row['code'],
                'name': row['name'],
                'manufacturer_url': row.get('manufacturer_url', '')
            })

        duplicates = {k: v for k, v in key_counts.items() if len(v) > 1}

        if duplicates:
            report = "\n❌ DUPLICATE KEYS DETECTED (Different URLs):\n"
            report += "=" * 70 + "\n"
            for key, products in duplicates.items():
                report += f"\nKey: {key}\n"
                for p in products:
                    report += f"  - {p['manufacturer']} / {p['code']} / {p['name']}\n"
                    if p['manufacturer_url']:
                        report += f"    URL: {p['manufacturer_url']}\n"
            report += "\n⚠️  Please resolve duplicates before updating database.\n"
            return True, report

        return False, None

    def update_from_scraped_data(self, csv_filepath, dry_run=False, scraped_manufacturers=None, bot_protected_manufacturers=None):
        """
        Update database from scraped CSV data

        Args:
            csv_filepath: Path to CSV file with scraped products
            dry_run: If True, don't save changes
            scraped_manufacturers: List of manufacturer codes that were scraped in this run
                                  (only check discontinued for these). None = all manufacturers.
            bot_protected_manufacturers: List of manufacturer codes that hit bot protection
                                        (skip discontinued check for these)

        Returns: (stats_dict, changes_summary)
        """
        if bot_protected_manufacturers is None:
            bot_protected_manufacturers = []

        today = datetime.now().strftime('%Y-%m-%d')

        # Load CSV data
        with open(csv_filepath, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            new_products = list(reader)

        # Filter out excluded URLs
        new_products, excluded_count = self.filter_excluded_urls(new_products)
        if excluded_count > 0:
            print(f"ℹ️  Excluded {excluded_count} product(s) from blocked URL list")

        # Apply SKU overrides for products with missing/incorrect SKUs
        new_products, override_count = self.apply_sku_overrides(new_products)
        if override_count > 0:
            print(f"ℹ️  Applied {override_count} SKU override(s) from override list")

        # Remove duplicates with same URL (same product in multiple lists)
        new_products, dedup_count = self.deduplicate_same_url(new_products)
        if dedup_count > 0:
            print(f"ℹ️  Removed {dedup_count} duplicate(s) with identical URLs (same product in multiple lists)")

        # Check for remaining duplicates (different URLs - actual conflicts)
        has_duplicates, duplicate_report = self.detect_duplicates(new_products)
        if has_duplicates:
            return None, duplicate_report

        # Track changes
        stats = {
            'new': 0,
            'updated': 0,
            'discontinued': 0,
            'unchanged': 0
        }

        changes = []

        # Build set of keys from new data
        new_keys = set()
        for row in new_products:
            key = self.get_product_key(row['manufacturer'], row['code'])
            new_keys.add(key)

        # Process new/updated products
        for row in new_products:
            key = self.get_product_key(row['manufacturer'], row['code'])

            if key not in self.data['products']:
                # New product
                product = self._create_product_record(row, today)
                self.data['products'][key] = product
                stats['new'] += 1
                changes.append(f"  + NEW: {row['manufacturer']} - {row['name']} ({row['code']})")

            else:
                # Existing product
                existing = self.data['products'][key]

                # Check if any fields changed
                changed_fields = []
                for field in row.keys():
                    if field in existing and existing[field] != row[field]:
                        changed_fields.append(field)

                if changed_fields:
                    # Update changed fields
                    for field in row.keys():
                        existing[field] = row[field]

                    existing['last_seen'] = today

                    # If it was discontinued, mark as available again
                    if existing['status'] == 'discontinued':
                        existing['status'] = 'available'
                        existing['discontinued_date'] = None
                        changes.append(f"  ↻ REACTIVATED: {row['manufacturer']} - {row['name']} ({row['code']})")
                    else:
                        changes.append(f"  ✎ UPDATED: {row['manufacturer']} - {row['name']} ({row['code']}) - Changed: {', '.join(changed_fields)}")

                    stats['updated'] += 1

                else:
                    # No changes, just update last_seen
                    existing['last_seen'] = today

                    # If it was discontinued, mark as available again
                    if existing['status'] == 'discontinued':
                        existing['status'] = 'available'
                        existing['discontinued_date'] = None
                        changes.append(f"  ↻ REACTIVATED: {row['manufacturer']} - {row['name']} ({row['code']})")
                        stats['updated'] += 1
                    else:
                        stats['unchanged'] += 1

        # Mark discontinued products (in database but not in new scrape)
        # Only check discontinued for manufacturers that were scraped in this run
        # SKIP manufacturers that hit bot protection (we don't want to mark them discontinued)
        for key, product in self.data['products'].items():
            manufacturer = product.get('manufacturer', '')

            # Skip manufacturers that weren't scraped in this run
            # (e.g., when using --mfr flag to update just one manufacturer)
            if scraped_manufacturers is not None and manufacturer not in scraped_manufacturers:
                continue

            # Skip bot-protected manufacturers
            if manufacturer in bot_protected_manufacturers:
                continue

            if key not in new_keys and product['status'] == 'available':
                product['status'] = 'discontinued'
                product['discontinued_date'] = today
                stats['discontinued'] += 1
                changes.append(f"  - DISCONTINUED: {product['manufacturer']} - {product['name']} ({product['code']})")

        # Build summary
        summary = "\n" + "=" * 70 + "\n"
        summary += "DATABASE UPDATE SUMMARY\n"
        summary += "=" * 70 + "\n"
        summary += f"New products:         {stats['new']}\n"
        summary += f"Updated products:     {stats['updated']}\n"
        summary += f"Discontinued:         {stats['discontinued']}\n"
        summary += f"Unchanged:            {stats['unchanged']}\n"
        summary += f"Total in database:    {len(self.data['products'])}\n"

        # Show which manufacturers were checked for discontinued products
        if scraped_manufacturers is not None:
            checked_manufacturers = [m for m in scraped_manufacturers if m not in bot_protected_manufacturers]
            if checked_manufacturers:
                summary += f"\n📋 Discontinued Check:\n"
                summary += f"   Checked {len(checked_manufacturers)} manufacturer(s) for discontinued products:\n"
                for mfr_code in checked_manufacturers:
                    summary += f"     - {mfr_code}\n"

            not_checked = set(scraped_manufacturers) - set(checked_manufacturers) if scraped_manufacturers else set()
            if not_checked or bot_protected_manufacturers:
                summary += f"\n⚠️  Skipped Manufacturers:\n"
                for mfr_code in bot_protected_manufacturers:
                    summary += f"     - {mfr_code} (bot protection - products preserved)\n"
        elif bot_protected_manufacturers:
            summary += f"\n⚠️  Bot Protection Notice:\n"
            summary += f"   {len(bot_protected_manufacturers)} manufacturer(s) hit bot protection and were skipped:\n"
            for mfr_code in bot_protected_manufacturers:
                summary += f"     - {mfr_code} (products preserved, not marked discontinued)\n"

        if changes:
            summary += "\n" + "=" * 70 + "\n"
            summary += "DETAILED CHANGES:\n"
            summary += "=" * 70 + "\n"
            summary += '\n'.join(changes)

        summary += "\n" + "=" * 70 + "\n"

        if not dry_run:
            self.save_database()
        else:
            summary += "\n⚠️  DRY RUN - No changes saved\n"

        return stats, summary

    def _create_product_record(self, csv_row, date_added):
        """Create a new product record from CSV row"""
        return {
            'status': 'available',
            'added_date': date_added,
            'last_seen': date_added,
            'discontinued_date': None,
            **csv_row  # Include all CSV fields
        }

    def assign_stable_ids(self):
        """
        Assign stable_id to all products that don't have one.

        Processes products in sorted order (by key) for determinism.
        Never modifies existing stable_ids - only assigns to products
        that are missing them.

        Returns: (assigned_count, collision_count)
        """
        print("\n" + "=" * 70)
        print("ASSIGNING STABLE IDs")
        print("=" * 70)

        # First pass: collect all existing stable_ids
        existing_stable_ids = set()
        products_with_ids = 0
        products_without_ids = 0

        for key, product in self.data['products'].items():
            if 'stable_id' in product and product['stable_id']:
                existing_stable_ids.add(product['stable_id'])
                products_with_ids += 1
            else:
                products_without_ids += 1

        print(f"Products with stable_id:    {products_with_ids}")
        print(f"Products without stable_id: {products_without_ids}")

        if products_without_ids == 0:
            print("\n✅ All products already have stable_ids!")
            return 0, 0

        print(f"\nGenerating stable_ids for {products_without_ids} products...")

        # Second pass: assign stable_ids to products that don't have one
        # Process in sorted order for determinism
        assigned_count = 0
        collision_count = 0

        for key in sorted(self.data['products'].keys()):
            product = self.data['products'][key]

            # Skip if already has stable_id
            if 'stable_id' in product and product['stable_id']:
                continue

            # Generate new stable_id
            manufacturer = product['manufacturer']
            code = product['code']

            original_stable_id = generate_stable_id(manufacturer, code, set())  # Generate without collision check
            stable_id = generate_stable_id(manufacturer, code, existing_stable_ids)

            # Check if we had a collision
            if stable_id != original_stable_id:
                collision_count += 1
                print(f"   ⚠️  Collision resolved: {manufacturer}:{code} → {stable_id} (was {original_stable_id})")

            # Assign stable_id
            product['stable_id'] = stable_id
            existing_stable_ids.add(stable_id)
            assigned_count += 1

            # Print progress every 100 items
            if assigned_count % 100 == 0:
                print(f"   Assigned {assigned_count}/{products_without_ids} stable_ids...")

        print(f"\n✅ Assigned {assigned_count} stable_ids")
        if collision_count > 0:
            print(f"   ⚠️  Resolved {collision_count} hash collision(s)")

        print("=" * 70)

        return assigned_count, collision_count

    def export_to_json(self, output_filepath, include_discontinued=True, strip_metadata=False):
        """
        Export database to JSON format for app

        Args:
            output_filepath: Where to save JSON (relative or absolute path)
            include_discontinued: Include discontinued products (default: True)
            strip_metadata: Remove database tracking fields before export (default: False)
        """
        # Convert to absolute path so it works regardless of where script is run from
        output_filepath = os.path.abspath(output_filepath)

        products = []

        for key, product in self.data['products'].items():
            if not include_discontinued and product['status'] == 'discontinued':
                continue

            # Create a copy of the product
            product_copy = dict(product)

            # Convert malformed tags string to proper array
            # Input: "\"blue\", \"green\"" or '"blue", "green"'
            # Output: ["blue", "green"]
            if 'tags' in product_copy and isinstance(product_copy['tags'], str):
                tags_str = product_copy['tags']
                if tags_str:
                    # Parse comma-separated quoted tags
                    tags_list = [
                        tag.strip().strip('"').strip("'")
                        for tag in tags_str.split(',')
                    ]
                    # Filter out empty strings and "unknown"
                    tags_list = [tag for tag in tags_list if tag and tag != 'unknown']
                    product_copy['tags'] = tags_list if tags_list else []
                else:
                    product_copy['tags'] = []

            # Convert malformed synonyms string to proper array
            if 'synonyms' in product_copy and isinstance(product_copy['synonyms'], str):
                synonyms_str = product_copy['synonyms']
                if synonyms_str:
                    # Parse comma-separated quoted synonyms
                    synonyms_list = [
                        syn.strip().strip('"').strip("'")
                        for syn in synonyms_str.split(',')
                    ]
                    synonyms_list = [syn for syn in synonyms_list if syn]
                    product_copy['synonyms'] = synonyms_list if synonyms_list else []
                else:
                    product_copy['synonyms'] = []

            # Optionally strip internal tracking metadata
            if strip_metadata:
                # Remove internal fields
                for field in ['status', 'added_date', 'last_seen', 'discontinued_date']:
                    product_copy.pop(field, None)

            products.append(product_copy)

        # Sort by manufacturer, then name
        products.sort(key=lambda p: (p['manufacturer'], p['name']))

        # Use 'glassitems' instead of 'products' for clarity
        output = {
            'version': self.data['version'],
            'generated': datetime.now().isoformat(),
            'item_count': len(products),
            'glassitems': products
        }

        # Create parent directories if they don't exist
        output_dir = os.path.dirname(output_filepath)
        if output_dir:  # Only create if there's actually a directory component
            os.makedirs(output_dir, exist_ok=True)

        with open(output_filepath, 'w', encoding='utf-8') as f:
            json.dump(output, f, indent=2, ensure_ascii=False)

        print(f"✅ Exported {len(products)} glass items to {output_filepath}")
        print(f"   Version: {output['version']}")
        print(f"   Generated: {output['generated']}")
        if not strip_metadata:
            print(f"   (Database tracking fields included)")
        else:
            print(f"   (Database tracking fields stripped)")


def git_commit_changes(message):
    """Commit database changes to Git"""
    try:
        # Check if we're in a git repo
        subprocess.run(['git', 'status'], check=True, capture_output=True)

        # Add database file
        subprocess.run(['git', 'add', DATABASE_FILE], check=True)

        # Commit
        subprocess.run(['git', 'commit', '-m', message], check=True)

        print("✅ Changes committed to Git")
        print(f"   Message: {message}")

        return True

    except subprocess.CalledProcessError as e:
        print(f"⚠️  Git commit failed: {e}")
        print("   You can commit manually later")
        return False


def main():
    parser = argparse.ArgumentParser(
        description='Update glass product database from manufacturer websites'
    )
    parser.add_argument('--test', action='store_true',
                       help='Test mode: scrape 2-3 items per manufacturer')
    parser.add_argument('--mfr', choices=list(combined_glass_scraper.MANUFACTURERS.keys()),
                       help='Update only this manufacturer')
    parser.add_argument('--dry-run', action='store_true',
                       help='Show changes without saving')
    parser.add_argument('--auto-commit', action='store_true',
                       help='Automatically commit changes to Git')
    parser.add_argument('--export', type=str,
                       help='Export database to JSON file')
    parser.add_argument('--include-discontinued', action='store_true', default=True,
                       help='Include discontinued products in export (default: True)')
    parser.add_argument('--strip-metadata', action='store_true',
                       help='Remove database tracking fields from export (status, dates)')

    args = parser.parse_args()

    print("=" * 70)
    print("GLASS PRODUCT DATABASE UPDATER")
    print("=" * 70)
    print()

    # Step 1: Run scrapers
    print("Step 1: Running scrapers...")
    print("-" * 70)

    csv_filename = 'combined_glass_products_temp.csv'

    # Build scraper arguments
    scraper_args = ['--output', csv_filename]
    if args.test:
        scraper_args.append('--test')
    if args.mfr:
        scraper_args.extend(['--mfr', args.mfr])

    # Run combined scraper
    success = combined_glass_scraper.main(scraper_args)

    if not success:
        print("❌ Scraping failed. Aborting database update.")
        return 1

    print()

    # Step 2: Update database
    print("Step 2: Updating database...")
    print("-" * 70)

    # Check for scraped manufacturers file
    # This tells us which manufacturers were included in this scrape run
    scraped_file = csv_filename.replace('.csv', '_scraped.txt')
    scraped_manufacturers = None  # None means "all manufacturers" (backward compatibility)
    if os.path.exists(scraped_file):
        with open(scraped_file, 'r') as f:
            scraped_manufacturers = [line.strip() for line in f if line.strip()]
        print(f"ℹ️  This run scraped {len(scraped_manufacturers)} manufacturer(s):")
        for mfr_code in scraped_manufacturers:
            print(f"   - {mfr_code}")
        print()

    # Check for bot-protected manufacturers file
    bot_protected_file = csv_filename.replace('.csv', '_bot_protected.txt')
    bot_protected_manufacturers = []
    if os.path.exists(bot_protected_file):
        with open(bot_protected_file, 'r') as f:
            bot_protected_manufacturers = [line.strip() for line in f if line.strip()]
        if bot_protected_manufacturers:
            print(f"ℹ️  {len(bot_protected_manufacturers)} manufacturer(s) hit bot protection:")
            for mfr_code in bot_protected_manufacturers:
                print(f"   - {mfr_code} (will skip discontinued check)")
            print()

    db = ProductDatabase(DATABASE_FILE)
    stats, summary = db.update_from_scraped_data(
        csv_filename,
        dry_run=args.dry_run,
        scraped_manufacturers=scraped_manufacturers,
        bot_protected_manufacturers=bot_protected_manufacturers
    )

    if stats is None:
        # Duplicates detected
        print(summary)
        return 1

    print(summary)

    # Step 2.5: Assign stable IDs (after database update, before export)
    if not args.dry_run:
        print("\nStep 2.5: Assigning stable IDs...")
        print("-" * 70)
        assigned_count, collision_count = db.assign_stable_ids()

        # Save database again if we assigned any stable_ids
        if assigned_count > 0:
            db.save_database()

    # Step 3: Export if requested
    if args.export:
        print("\nStep 3: Exporting to JSON...")
        print("-" * 70)
        db.export_to_json(
            args.export,
            include_discontinued=args.include_discontinued,
            strip_metadata=args.strip_metadata
        )

    # Step 4: Git commit if requested
    if args.auto_commit and not args.dry_run and stats['new'] + stats['updated'] + stats['discontinued'] > 0:
        print("\nStep 4: Committing to Git...")
        print("-" * 70)

        commit_msg = f"Update glass database: {stats['new']} new, {stats['updated']} updated, {stats['discontinued']} discontinued"
        git_commit_changes(commit_msg)

    # Keep the CSV file for review (don't delete)
    print(f"\n📄 CSV file saved: {csv_filename}")
    print(f"   You can load this into Google Sheets to review tags and identify overrides needed")

    print("\n✅ Database update complete!")
    return 0


if __name__ == '__main__':
    sys.exit(main())

#!/usr/bin/env python3
"""
Clean up duplicate Parramore entries with 'by' at the end of names.

This removes old entries like "AQUA by" when we have corrected entries like "AQUA".
"""

import json
import sys

DATABASE_FILE = 'glass_database.json'

def main():
    print("Loading database...")
    with open(DATABASE_FILE, 'r', encoding='utf-8') as f:
        db = json.load(f)

    print(f"Total products before cleanup: {len(db['products'])}")

    # Find all PAR products with "by" at the end
    old_par_keys = []
    for key, product in db['products'].items():
        if product.get('manufacturer') == 'PAR' and product.get('name', '').endswith(' by'):
            old_par_keys.append(key)
            print(f"  Will remove: {key} - {product['name']}")

    if not old_par_keys:
        print("\n✅ No old Parramore entries found!")
        return 0

    print(f"\n📝 Found {len(old_par_keys)} old Parramore entries to remove")

    # Confirm removal
    response = input("\nRemove these entries? (yes/no): ")
    if response.lower() != 'yes':
        print("❌ Cancelled")
        return 1

    # Remove old entries
    for key in old_par_keys:
        del db['products'][key]

    print(f"\n✅ Removed {len(old_par_keys)} old entries")
    print(f"Total products after cleanup: {len(db['products'])}")

    # Save database
    print("\n💾 Saving cleaned database...")
    with open(DATABASE_FILE, 'w', encoding='utf-8') as f:
        json.dump(db, f, indent=2, ensure_ascii=False)

    print("✅ Database cleaned successfully!")
    return 0

if __name__ == '__main__':
    sys.exit(main())

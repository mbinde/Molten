#!/usr/bin/env python3
"""
Export Database to JSON (No Scraping)
======================================

Exports the existing glass_database.json to app format WITHOUT running scrapers.
Use this when you've manually updated the database and just want to export.

Usage:
    python3 export_only.py ../../Sources/Resources/glassitems.json --strip-metadata
"""

import sys
import argparse
from update_database import ProductDatabase


def main():
    parser = argparse.ArgumentParser(description='Export database to JSON (no scraping)')
    parser.add_argument('output', help='Output JSON file path')
    parser.add_argument('--include-discontinued', action='store_true', default=True,
                       help='Include discontinued products (default: True)')
    parser.add_argument('--strip-metadata', action='store_true',
                       help='Remove database tracking fields from export')

    args = parser.parse_args()

    print("=" * 70)
    print("EXPORT DATABASE TO JSON (No Scraping)")
    print("=" * 70)
    print()

    # Load database
    db = ProductDatabase('glass_database.json')

    # Export
    db.export_to_json(
        args.output,
        include_discontinued=args.include_discontinued,
        strip_metadata=args.strip_metadata
    )

    print("\n✅ Export complete!")
    return 0


if __name__ == '__main__':
    sys.exit(main())

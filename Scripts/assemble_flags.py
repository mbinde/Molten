#!/usr/bin/env python3
"""
Assemble batch flag files into final CatalogFlagExport format.

Run this after generate_flags.py completes to combine all batch_*.json files
into a single export file that can be imported into the app.
"""

import json
from pathlib import Path
from datetime import datetime

OUTPUT_DIR = Path(__file__).parent.parent / "FlagOutput"
FINAL_OUTPUT = OUTPUT_DIR / "catalog_flags_export.json"


def main():
    if not OUTPUT_DIR.exists():
        print(f"ERROR: Output directory not found: {OUTPUT_DIR}")
        return 1

    # Find all batch files
    batch_files = sorted(OUTPUT_DIR.glob("batch_*.json"))
    if not batch_files:
        print("ERROR: No batch files found")
        return 1

    # Check for error files
    error_files = list(OUTPUT_DIR.glob("batch_*_ERROR.txt"))
    if error_files:
        print(f"WARNING: Found {len(error_files)} error files:")
        for ef in error_files:
            print(f"  - {ef.name}")
        print("You may want to re-run generate_flags.py to retry these batches.")
        print()

    # Collect all flags
    all_flags = []
    total_items = 0
    items_with_flags = 0
    parse_errors = 0

    print(f"Assembling {len(batch_files)} batch files...")

    for batch_file in batch_files:
        with open(batch_file) as f:
            data = json.load(f)

        for result in data['results']:
            total_items += 1

            if result.get('parse_error'):
                parse_errors += 1
                continue

            flags = result.get('flags', [])
            if flags:
                items_with_flags += 1

            for flag in flags:
                all_flags.append({
                    'item_stable_id': result['stable_id'],
                    'flag_key': flag['key'],
                    'flag_value': flag.get('value', True),
                    'flag_numeric': flag.get('numeric')
                })

    # Create export format matching CatalogFlagExport
    export = {
        'version': '1.0',
        'exported_at': datetime.now().isoformat(),
        'metadata': {
            'total_items_analyzed': total_items,
            'items_with_flags': items_with_flags,
            'total_flags': len(all_flags),
            'parse_errors': parse_errors
        },
        'flags': [
            {
                'item_stable_id': f['item_stable_id'],
                'flag_key': f['flag_key'],
                'flag_value': f['flag_value'],
                'flag_numeric': f['flag_numeric']
            }
            for f in all_flags
        ],
        'description_replacements': []  # Not generating these in this pass
    }

    # Write final output
    with open(FINAL_OUTPUT, 'w') as f:
        json.dump(export, f, indent=2)

    print()
    print("=" * 50)
    print("ASSEMBLY COMPLETE!")
    print(f"Total items analyzed: {total_items:,}")
    print(f"Items with flags: {items_with_flags:,}")
    print(f"Total flags generated: {len(all_flags):,}")
    if parse_errors:
        print(f"Parse errors (items skipped): {parse_errors}")
    print()
    print(f"Output written to: {FINAL_OUTPUT}")

    # Also print flag distribution
    print()
    print("Flag distribution:")
    flag_counts = {}
    for f in all_flags:
        key = f['flag_key']
        flag_counts[key] = flag_counts.get(key, 0) + 1

    for key, count in sorted(flag_counts.items(), key=lambda x: -x[1]):
        print(f"  {key}: {count}")

    return 0


if __name__ == "__main__":
    exit(main())

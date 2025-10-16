#!/usr/bin/env python3
"""
JSON Verification Tool
Analyzes colors.json for duplicate ID values and reports statistics.
"""

import json
from collections import Counter
from pathlib import Path


def find_colors_json():
    """Find the colors.json file in the Resources directory."""
    script_dir = Path(__file__).parent
    project_root = script_dir.parent.parent
    colors_json = project_root / "Sources" / "Resources" / "colors.json"

    if not colors_json.exists():
        raise FileNotFoundError(f"Could not find colors.json at {colors_json}")

    return colors_json


def analyze_duplicate_ids(json_file):
    """Analyze the JSON file for duplicate ID values."""
    with open(json_file, 'r') as f:
        data = json.load(f)

    # Handle both array format and object with "colors" key
    if isinstance(data, dict) and 'colors' in data:
        items = data['colors']
    elif isinstance(data, list):
        items = data
    else:
        raise ValueError("Unexpected JSON structure")

    # Extract all IDs
    ids = []
    for item in items:
        if 'id' in item and item['id'] is not None:
            ids.append(item['id'])

    # Count occurrences
    id_counts = Counter(ids)

    # Find duplicates (IDs that appear more than once)
    duplicates = {id_val: count for id_val, count in id_counts.items() if count > 1}

    return {
        'total_items': len(items),
        'total_ids': len(ids),
        'unique_ids': len(id_counts),
        'duplicate_ids': duplicates,
        'duplicate_count': len(duplicates)
    }


def main():
    """Main entry point."""
    try:
        colors_json = find_colors_json()
        print(f"Analyzing: {colors_json}")
        print()

        results = analyze_duplicate_ids(colors_json)

        print(f"Total items in JSON: {results['total_items']}")
        print(f"Items with IDs: {results['total_ids']}")
        print(f"Unique IDs: {results['unique_ids']}")
        print()

        if results['duplicate_count'] > 0:
            print(f"Found {results['duplicate_count']} duplicate ID(s):")
            print()
            for id_val, count in sorted(results['duplicate_ids'].items()):
                print(f"  ID '{id_val}': appears {count} times")
        else:
            print("No duplicate IDs found!")

    except FileNotFoundError as e:
        print(f"Error: {e}")
        return 1
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON: {e}")
        return 1
    except Exception as e:
        print(f"Unexpected error: {e}")
        return 1

    return 0


if __name__ == '__main__':
    exit(main())

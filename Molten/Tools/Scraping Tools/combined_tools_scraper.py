#!/usr/bin/env python3
"""
Combined Tool Scrapers - Master runner for all tool manufacturers

Runs all tool scrapers and combines results into a single JSON file:
  tools_new.json → moved to ../../Data/Tools/tools.json

Manufacturers:
- Fire Bug Tools (WooCommerce)
- Leonardo Lampwork (Shopify)
- Taglia Tool (Shopify)
- Ennion Glass Tools (Shopify)
- CG Beads (ShopSite)
- Mike Peterson (Static catalog)

Usage:
    python3 combined_tools_scraper.py              # Run all manufacturers
    python3 combined_tools_scraper.py --test       # Test mode (2-3 items each)
    python3 combined_tools_scraper.py --mfr firebug  # Single manufacturer
    python3 combined_tools_scraper.py --max-items 5  # Limit items per manufacturer
"""

import json
import argparse
import sys
from pathlib import Path
from datetime import datetime

# Import scraper modules
from scrapers import firebug, leonardo, taglia, ennion, cgbeads, mikepeterson

# Manufacturer registry
MANUFACTURERS = {
    'firebug': {
        'name': 'Fire Bug Tools',
        'module': firebug,
        'enabled': True
    },
    'leonardo': {
        'name': 'Leonardo Lampwork',
        'module': leonardo,
        'enabled': True
    },
    'taglia': {
        'name': 'Taglia Tool',
        'module': taglia,
        'enabled': True
    },
    'ennion': {
        'name': 'Ennion Glass Tools',
        'module': ennion,
        'enabled': True
    },
    'cgbeads': {
        'name': 'CG Beads',
        'module': cgbeads,
        'enabled': True
    },
    'mikepeterson': {
        'name': 'Mike Peterson',
        'module': mikepeterson,
        'enabled': True
    }
}


def run_scrapers(test_mode=False, max_items=None, single_mfr=None):
    """
    Run all enabled tool scrapers and combine results.

    Args:
        test_mode (bool): If True, limit to 2-3 items per manufacturer
        max_items (int): Maximum items per manufacturer
        single_mfr (str): If provided, only run this manufacturer

    Returns:
        dict: Combined results with metadata
    """
    all_tools = []
    summary = {}
    duplicates_found = {}
    errors = []

    # Filter to single manufacturer if requested
    if single_mfr:
        if single_mfr not in MANUFACTURERS:
            print(f"❌ Unknown manufacturer: {single_mfr}")
            print(f"Available: {', '.join(MANUFACTURERS.keys())}")
            sys.exit(1)
        mfr_list = {single_mfr: MANUFACTURERS[single_mfr]}
    else:
        mfr_list = {k: v for k, v in MANUFACTURERS.items() if v['enabled']}

    print(f"\n{'='*80}")
    print(f"COMBINED TOOL SCRAPER")
    print(f"{'='*80}")
    if test_mode:
        print("🧪 TEST MODE - Limited items")
    if max_items:
        print(f"📊 Max items per manufacturer: {max_items}")
    if single_mfr:
        print(f"🎯 Single manufacturer: {MANUFACTURERS[single_mfr]['name']}")
    print()

    # Run each manufacturer scraper
    for code, info in mfr_list.items():
        name = info['name']
        module = info['module']

        try:
            print(f"\n{'─'*80}")
            print(f"Running {name} ({code})...")
            print(f"{'─'*80}")

            products, duplicates = module.scrape(test_mode=test_mode, max_items=max_items)

            # Add manufacturer code to each product
            for product in products:
                if 'manufacturer' not in product:
                    product['manufacturer'] = code

            all_tools.extend(products)
            summary[code] = len(products)

            if duplicates:
                duplicates_found[code] = len(duplicates)

            print(f"✅ {name}: {len(products)} tools scraped")
            if duplicates:
                print(f"   ⚠️  {len(duplicates)} duplicates found")

        except Exception as e:
            error_msg = f"{name} ({code}): {str(e)}"
            errors.append(error_msg)
            print(f"❌ ERROR: {error_msg}")
            # Stop on error (consistent with glass scraper)
            print(f"\n{'='*80}")
            print("⛔ STOPPING - Fix errors before continuing")
            print(f"{'='*80}\n")
            sys.exit(1)

    # Summary
    print(f"\n{'='*80}")
    print("SCRAPING SUMMARY")
    print(f"{'='*80}")
    total_tools = len(all_tools)
    print(f"✅ Total tools scraped: {total_tools}")
    print(f"\nBreakdown by manufacturer:")
    for code, count in summary.items():
        print(f"  {MANUFACTURERS[code]['name']:.<40} {count:>4} tools")
        if code in duplicates_found:
            print(f"  {'  (duplicates)':.<40} {duplicates_found[code]:>4} items")

    if errors:
        print(f"\n❌ Errors encountered: {len(errors)}")
        for error in errors:
            print(f"  - {error}")

    print(f"{'='*80}\n")

    return {
        'tools': all_tools,
        'summary': summary,
        'total_tools': total_tools,
        'errors': errors
    }


def save_json(tools_data, output_path):
    """
    Save tools to JSON file with metadata.

    Args:
        tools_data (dict): Combined scraper results
        output_path (Path): Where to save JSON
    """
    # Create JSON structure (following coatings.json pattern)
    output = {
        'version': '1.0',
        'generated': datetime.now().isoformat(),
        'item_count': tools_data['total_tools'],
        'tools': tools_data['tools']
    }

    # Write JSON
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    print(f"💾 Saved {tools_data['total_tools']} tools to:")
    print(f"   {output_path}")


def move_to_data_directory(source_path, data_dir_path):
    """
    Move tools_new.json to Data/Tools/tools.json.

    Args:
        source_path (Path): Source file (tools_new.json)
        data_dir_path (Path): Target directory (Data/Tools/)
    """
    target_path = data_dir_path / 'tools.json'

    # Ensure target directory exists
    data_dir_path.mkdir(parents=True, exist_ok=True)

    # Copy file to target location
    import shutil
    shutil.copy2(source_path, target_path)

    print(f"📦 Moved to:")
    print(f"   {target_path}")


def main():
    parser = argparse.ArgumentParser(
        description='Run all tool scrapers and combine into single JSON file',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                   # Run all manufacturers
  %(prog)s --test            # Test mode (2-3 items each)
  %(prog)s --mfr firebug     # Single manufacturer
  %(prog)s --max-items 10    # Limit to 10 items per manufacturer
        """
    )

    parser.add_argument('--test', action='store_true',
                        help='Test mode: limit to 2-3 items per manufacturer')
    parser.add_argument('--max-items', type=int,
                        help='Maximum items to scrape per manufacturer')
    parser.add_argument('--mfr', type=str,
                        help='Run single manufacturer (firebug, leonardo, taglia, ennion, cgbeads, mikepeterson)')
    parser.add_argument('--output', type=str, default='tools_new.json',
                        help='Output filename (default: tools_new.json)')
    parser.add_argument('--no-move', action='store_true',
                        help='Do not move to Data/Tools directory')

    args = parser.parse_args()

    # Run scrapers
    results = run_scrapers(
        test_mode=args.test,
        max_items=args.max_items,
        single_mfr=args.mfr
    )

    # Save to output file
    output_path = Path(args.output)
    save_json(results, output_path)

    # Move to Data/Tools directory (unless --no-move)
    if not args.no_move:
        # Calculate path to Data/Tools
        script_dir = Path(__file__).parent  # Scraping Tools/
        data_dir = script_dir.parent.parent / 'Data' / 'Tools'  # ../../Data/Tools/

        move_to_data_directory(output_path, data_dir)

    print("\n✅ Done!")


if __name__ == '__main__':
    main()

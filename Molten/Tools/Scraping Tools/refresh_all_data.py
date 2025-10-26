#!/usr/bin/env python3
"""
Unified Data Refresh Script
============================

Runs the complete data refresh workflow:
1. Scrape all manufacturers and update database
2. Export to app's glassitems.json
3. Download/update product images

Usage:
    python3 refresh_all_data.py              # Full refresh
    python3 refresh_all_data.py --test       # Test mode (limited items)
    python3 refresh_all_data.py --no-images  # Skip image download
"""

import sys
import subprocess
import argparse
from pathlib import Path


def run_command(cmd, description):
    """Run a command and handle errors"""
    print(f"\n{'='*70}")
    print(f"  {description}")
    print(f"{'='*70}\n")

    try:
        result = subprocess.run(cmd, check=True)
        print(f"\n✅ {description} completed successfully")
        return True
    except subprocess.CalledProcessError as e:
        print(f"\n❌ {description} failed with exit code {e.returncode}")
        return False
    except KeyboardInterrupt:
        print(f"\n⚠️  {description} interrupted by user")
        return False


def main():
    parser = argparse.ArgumentParser(
        description='Refresh all glass product data',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument(
        '--test',
        action='store_true',
        help='Test mode: scrape 2-3 items per manufacturer'
    )
    parser.add_argument(
        '--no-images',
        action='store_true',
        help='Skip image download step'
    )
    parser.add_argument(
        '--auto-commit',
        action='store_true',
        help='Automatically commit changes to git'
    )

    args = parser.parse_args()

    print("="*70)
    print("         GLASS PRODUCT DATA REFRESH")
    print("="*70)
    print("\nThis script will:")
    print("  1. Scrape all manufacturer websites")
    print("  2. Update glass_database.json")
    print("  3. Export to app's glassitems.json")
    if not args.no_images:
        print("  4. Download/update product images")
    print()

    # Step 1: Update database (scrape + update)
    update_cmd = ['python3', 'update_database.py']
    if args.test:
        update_cmd.append('--test')
    if args.auto_commit:
        update_cmd.append('--auto-commit')

    if not run_command(update_cmd, "Step 1: Scraping and updating database"):
        print("\n❌ Database update failed. Stopping.")
        return False

    # Step 2: Export to app format
    app_json_path = '../../Sources/Resources/glassitems.json'
    export_cmd = [
        'python3', 'update_database.py',
        '--export', app_json_path,
        '--strip-metadata'
    ]

    if not run_command(export_cmd, "Step 2: Exporting to app format"):
        print("\n❌ Export failed. Stopping.")
        return False

    # Step 3: Download images (optional)
    if not args.no_images:
        image_cmd = ['python3', 'image_downloader.py', app_json_path]
        if args.test:
            image_cmd.append('--max-downloads')
            image_cmd.append('10')

        if not run_command(image_cmd, "Step 3: Downloading product images"):
            print("\n⚠️  Image download failed, but database is updated")
            print("     You can run image_downloader.py manually later")

    # Summary
    print("\n" + "="*70)
    print("  REFRESH COMPLETE")
    print("="*70)
    print("\nUpdated files:")
    print("  - glass_database.json (source of truth)")
    print(f"  - {app_json_path} (app data)")
    if not args.no_images:
        print("  - Images in ../../Sources/Resources/Images/")

    # Show git status
    print("\nGit status:")
    subprocess.run(['git', 'status', '--short'])

    if not args.auto_commit:
        print("\n💡 Tip: Review changes and commit with:")
        print("   git add .")
        print("   git commit -m \"Update glass product data\"")

    return True


if __name__ == '__main__':
    success = main()
    sys.exit(0 if success else 1)

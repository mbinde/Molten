#!/usr/bin/env python3
"""
Extract screenshots from Xcode test results (.xcresult bundle)
Saves them to the Screenshots directory for WordPress publishing
"""

import subprocess
import json
import os
import sys
from pathlib import Path

# Configuration
SCRIPT_DIR = Path(__file__).parent
OUTPUT_DIR = SCRIPT_DIR


def find_latest_xcresult():
    """Find the most recent xcresult bundle"""
    cmd = [
        'find',
        os.path.expanduser('~/Library/Developer/Xcode/DerivedData'),
        '-name', '*.xcresult',
        '-type', 'd',
        '-mtime', '-1'
    ]

    result = subprocess.run(cmd, capture_output=True, text=True)
    xcresults = [line for line in result.stdout.split('\n') if line and '/Test/' in line]

    if not xcresults:
        return None

    # Return the most recent one
    return sorted(xcresults)[-1]


def get_xcresult_json(xcresult_path):
    """Get JSON representation of xcresult bundle"""
    cmd = [
        'xcrun', 'xcresulttool', 'get',
        '--legacy',
        '--format', 'json',
        '--path', xcresult_path
    ]

    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error getting xcresult data: {result.stderr}")
        return None

    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON: {e}")
        return None


def find_screenshots(data, screenshots=None):
    """Recursively find screenshot attachments in xcresult data"""
    if screenshots is None:
        screenshots = []

    if isinstance(data, dict):
        # Check if this is an attachment
        if data.get('_type', {}).get('_name') == 'ActionTestAttachment':
            name = data.get('name', {}).get('_value', '')
            # Look for our numbered screenshot patterns
            if '.png' in name and any(c.isdigit() for c in name.split('-')[0]):
                attachment_id = data.get('payloadRef', {}).get('id', {}).get('_value')
                if attachment_id:
                    screenshots.append((name, attachment_id))

        # Recurse into dict values
        for value in data.values():
            find_screenshots(value, screenshots)

    elif isinstance(data, list):
        # Recurse into list items
        for item in data:
            find_screenshots(item, screenshots)

    return screenshots


def export_screenshot(xcresult_path, attachment_id, output_path):
    """Export a single screenshot using xcresulttool"""
    cmd = [
        'xcrun', 'xcresulttool', 'export',
        '--legacy',
        '--type', 'file',
        '--path', xcresult_path,
        '--id', attachment_id,
        '--output-path', str(output_path)
    ]

    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.returncode == 0


def main():
    print("📸 Screenshot Extraction Tool")
    print("=" * 50)
    print()

    # Find latest xcresult
    print("Looking for recent test results...")
    xcresult_path = find_latest_xcresult()

    if not xcresult_path:
        print("❌ No recent test results found!")
        print()
        print("Run the screenshot tests first:")
        print("  cd '/Users/binde/Library/Mobile Documents/com~apple~CloudDocs/Molten'")
        print("  xcodebuild test -project Molten.xcodeproj -scheme Molten \\")
        print("    -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \\")
        print("    -only-testing:ScreenshotAutomation/ScreenshotAutomation/testGenerateMarketingScreenshots")
        return 1

    print(f"✓ Found: {os.path.basename(xcresult_path)}")
    print()

    # Parse xcresult data
    print("Reading test results...")
    data = get_xcresult_json(xcresult_path)
    if not data:
        print("❌ Failed to read test results")
        return 1

    # Find screenshots
    screenshots = find_screenshots(data)
    print(f"✓ Found {len(screenshots)} screenshots")
    print()

    # Export each screenshot
    print("Extracting screenshots...")
    success_count = 0

    for name, attachment_id in screenshots:
        output_path = OUTPUT_DIR / name
        print(f"  📤 {name}... ", end='', flush=True)

        if export_screenshot(xcresult_path, attachment_id, output_path):
            print("✅")
            success_count += 1
        else:
            print("❌")

    print()
    print("=" * 50)
    print(f"✅ Extraction complete! {success_count}/{len(screenshots)} screenshots saved")
    print(f"   Output directory: {OUTPUT_DIR}")
    print()
    print("Next step: Run ./publish_to_wordpress.py to upload to WordPress")

    return 0


if __name__ == '__main__':
    sys.exit(main())

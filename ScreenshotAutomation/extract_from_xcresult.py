#!/usr/bin/env python3

"""
Extract all screenshots from .xcresult bundle
Uses SQLite database queries and xcresulttool for extraction
"""

import sqlite3
import subprocess
import os
from pathlib import Path

# Paths
DERIVED_DATA = Path.home() / "Library/Developer/Xcode/DerivedData"
PROJECT_DIR = Path("/Users/binde/Library/Mobile Documents/com~apple~CloudDocs/Molten")
OUTPUT_DIR = PROJECT_DIR / "Screenshots"

# Colors for terminal output
class Colors:
    BLUE = '\033[0;34m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    RED = '\033[0;31m'
    NC = '\033[0m'  # No Color

def find_molten_derived_data():
    """Find the Molten Derived Data folder"""
    molten_dirs = list(DERIVED_DATA.glob("Molten-*"))
    if not molten_dirs:
        print(f"{Colors.RED}❌ Could not find Molten Derived Data{Colors.NC}")
        return None
    return molten_dirs[0]

def find_latest_xcresult(derived_data_path):
    """Find the most recent .xcresult bundle"""
    test_logs = derived_data_path / "Logs/Test"
    xcresults = list(test_logs.glob("*.xcresult"))
    if not xcresults:
        print(f"{Colors.RED}❌ No .xcresult bundles found{Colors.NC}")
        return None

    # Sort by modification time, most recent first
    xcresults.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    return xcresults[0]

def extract_screenshots(xcresult_path, output_dir):
    """Extract all PNG screenshots from xcresult bundle"""
    db_path = xcresult_path / "database.sqlite3"

    if not db_path.exists():
        print(f"{Colors.RED}❌ No database found in xcresult{Colors.NC}")
        return 0

    # Connect to database
    conn = sqlite3.connect(str(db_path))
    cursor = conn.cursor()

    # Query for unique PNG attachments (excluding launch screens)
    query = """
        SELECT DISTINCT name, xcResultKitPayloadRefId
        FROM Attachments
        WHERE uniformTypeIdentifier = 'public.png'
          AND name NOT LIKE 'Launch Screen'
        ORDER BY name
    """

    cursor.execute(query)
    attachments = cursor.fetchall()
    conn.close()

    if not attachments:
        print(f"{Colors.YELLOW}⚠️  No screenshot attachments found{Colors.NC}")
        return 0

    print(f"{Colors.GREEN}✅ Found {len(attachments)} screenshots{Colors.NC}")
    print()

    # Create output directory
    output_dir.mkdir(parents=True, exist_ok=True)

    # Extract each screenshot
    extracted_count = 0
    for name, payload_id in attachments:
        # Sanitize filename
        safe_name = "".join(c if c.isalnum() or c in "-_" else "_" for c in name)
        output_path = output_dir / f"{safe_name}.png"

        print(f"  📸 Extracting: {name}")

        # Use xcresulttool to export
        result = subprocess.run([
            "xcrun", "xcresulttool", "export",
            "--type", "file",
            "--id", payload_id,
            "--path", str(xcresult_path),
            "--output-path", str(output_path),
            "--legacy"
        ], capture_output=True, text=True)

        if result.returncode == 0:
            extracted_count += 1
            file_size = output_path.stat().st_size / 1024  # KB
            print(f"     {Colors.GREEN}✓{Colors.NC} Saved to: {output_path.name} ({file_size:.1f} KB)")
        else:
            print(f"     {Colors.RED}✗{Colors.NC} Failed: {result.stderr}")

    return extracted_count

def main():
    print(f"{Colors.BLUE}╔═══════════════════════════════════════════════════╗{Colors.NC}")
    print(f"{Colors.BLUE}║     📸 SCREENSHOT EXTRACTOR 📸                    ║{Colors.NC}")
    print(f"{Colors.BLUE}╚═══════════════════════════════════════════════════╝{Colors.NC}")
    print()

    # Find Derived Data
    derived_data = find_molten_derived_data()
    if not derived_data:
        return 1

    print(f"{Colors.GREEN}✅ Found Derived Data: {derived_data.name}{Colors.NC}")

    # Find latest xcresult
    xcresult = find_latest_xcresult(derived_data)
    if not xcresult:
        return 1

    print(f"{Colors.GREEN}✅ Found test results: {xcresult.name}{Colors.NC}")
    print()

    # Extract screenshots
    count = extract_screenshots(xcresult, OUTPUT_DIR)

    print()
    print(f"{Colors.BLUE}╔═══════════════════════════════════════════════════╗{Colors.NC}")
    print(f"{Colors.BLUE}║              ✅ EXTRACTION COMPLETE ✅             ║{Colors.NC}")
    print(f"{Colors.BLUE}╚═══════════════════════════════════════════════════╝{Colors.NC}")
    print()
    print(f"{Colors.GREEN}📂 Extracted {count} screenshots to:{Colors.NC}")
    print(f"   {OUTPUT_DIR}")
    print()
    print(f"{Colors.YELLOW}💡 Next steps:{Colors.NC}")
    print(f'  1. Review: open "{OUTPUT_DIR}"')
    print(f"  2. Upload to WordPress: cd ScreenshotAutomation && ./publish_screenshots.sh --skip-generation")
    print()

    return 0

if __name__ == "__main__":
    exit(main())

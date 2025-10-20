import json
import os
import urllib.request
import urllib.error
import time
from pathlib import Path
from urllib.parse import urlparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import threading

# Import centralized configuration
from scraper_config import get_image_download_delay

def download_single_image(item, output_dir, force=False):
    """
    Download a single image.

    Returns: dict with status ('downloaded', 'skipped_exists', 'skipped_no_data', 'failed')
    """
    # Extract fields
    item_id = item.get('code') or item.get('id')
    manufacturer = item.get('manufacturer')
    url = item.get('image_url')

    # Check for missing data
    if not item_id:
        return {
            'status': 'skipped_no_data',
            'id': 'UNKNOWN',
            'reason': 'Missing item code/id',
            'name': item.get('name', 'N/A')
        }

    if not url:
        return {
            'status': 'skipped_no_data',
            'id': item_id,
            'reason': 'Missing image URL',
            'manufacturer_url': item.get('manufacturer_url', 'N/A')
        }

    if not manufacturer:
        return {
            'status': 'skipped_no_data',
            'id': item_id,
            'reason': 'Missing manufacturer code',
            'url': url
        }

    # Fix protocol-relative URLs (//example.com/image.jpg)
    if url.startswith('//'):
        url = 'https:' + url

    # Get file extension from URL
    parsed_url = urlparse(url)
    ext = os.path.splitext(parsed_url.path)[1] or '.jpg'

    # Clean the item_id: replace slashes and backslashes with dashes
    clean_id = item_id.replace('/', '-').replace('\\', '-')

    # Create output filename
    output_file = output_dir / f"{clean_id}{ext}"

    # Check if file already exists
    if output_file.exists() and not force:
        return {
            'status': 'skipped_exists',
            'id': item_id
        }

    # Download the image
    try:
        # Create request with a user agent to avoid being blocked
        req = urllib.request.Request(url)
        req.add_header('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')

        with urllib.request.urlopen(req, timeout=30) as response:
            image_data = response.read()

        # Save the image
        with open(output_file, 'wb') as f:
            f.write(image_data)

        # Rate limiting - be polite to servers
        time.sleep(get_image_download_delay())

        return {
            'status': 'downloaded',
            'id': item_id,
            'file': output_file
        }

    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as e:
        return {
            'status': 'failed',
            'id': item_id,
            'url': url,
            'error': str(e)
        }

def download_images_from_json(json_file, test_mode=False, force=False, max_workers=8):
    """
    Downloads images from URLs in a JSON file and saves them with SKU names.

    Args:
        json_file: Path to the JSON file containing image URLs and SKUs
        test_mode: If True, stops after 3 successful downloads
        force: If True, re-download files that already exist (default: False)
        max_workers: Number of parallel downloads (default: 8)
    """
    # Create product-images directory if it doesn't exist
    output_dir = Path("product-images")
    output_dir.mkdir(exist_ok=True)
    
    # Load the JSON file
    try:
        with open(json_file, 'r') as f:
            data = json.load(f)
    except FileNotFoundError:
        print(f"Error: {json_file} not found")
        return
    except json.JSONDecodeError:
        print(f"Error: {json_file} is not valid JSON")
        return
    
    # Process each item in the JSON
    # Handle various JSON structures
    if isinstance(data, list):
        items = data
    elif isinstance(data, dict):
        # Check for common database formats
        if 'glassitems' in data:
            # Database format: {"version": "1.0", "glassitems": [...]}
            items = data['glassitems']
        else:
            # Check if any values are lists (common format: {"colors": [...]})
            list_values = [v for v in data.values() if isinstance(v, list)]
            if list_values:
                # Use the first list found
                items = list_values[0]
            else:
                # Treat dict values as items
                items = list(data.values())
    else:
        items = [data]
    
    downloaded = 0
    failed = 0
    skipped_no_url = 0
    skipped_exists = 0
    failed_items = []  # Track failed downloads with details
    skipped_items = []  # Track items skipped due to missing data

    print(f"Found {len(items)} items in JSON file")
    if not force:
        print("Skipping existing files (use --force to re-download)\n")
    else:
        print("Force mode: Re-downloading all files\n")
    
    # Debug: Show first few items
    print("DEBUG: Checking first 5 items:")
    for i, item in enumerate(list(items)[:5]):
        if isinstance(item, dict):
            item_code = item.get('code') or item.get('id')
            print(f"  Item {i}: code={item_code}, has image_url={bool(item.get('image_url'))}")
            if item.get('image_url'):
                print(f"    URL: {item.get('image_url')[:80]}...")
        else:
            print(f"  Item {i}: Not a dict, type={type(item)}")
    print()

    # Filter items to only valid dicts
    valid_items = [item for item in items if isinstance(item, dict)]

    print(f"🚀 Downloading images in parallel (max {max_workers} concurrent downloads)...\n")

    # Use ThreadPoolExecutor for parallel downloads
    # Thread-safe counter for test mode
    download_count = {'value': 0}
    count_lock = threading.Lock()

    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        # Submit all download tasks
        future_to_item = {
            executor.submit(download_single_image, item, output_dir, force): item
            for item in valid_items
        }

        # Process results as they complete
        for future in as_completed(future_to_item):
            result = future.result()

            if result['status'] == 'downloaded':
                downloaded += 1
                print(f"✓ Downloaded: {result['id']}")

                # Check test mode limit with thread-safe counter
                with count_lock:
                    download_count['value'] += 1
                    if test_mode and download_count['value'] >= 3:
                        print("\nTest mode: Stopping after 3 downloads")
                        # Cancel remaining tasks
                        for f in future_to_item:
                            f.cancel()
                        break

            elif result['status'] == 'skipped_exists':
                skipped_exists += 1

            elif result['status'] == 'skipped_no_data':
                skipped_no_url += 1
                skipped_items.append(result)

            elif result['status'] == 'failed':
                failed += 1
                failed_items.append(result)

    # Print summary
    print("\n" + "=" * 70)
    print("DOWNLOAD SUMMARY")
    print("=" * 70)
    print(f"✓ Downloaded: {downloaded}")
    print(f"✗ Failed: {failed}")
    print(f"⊘ Skipped (already exists): {skipped_exists}")
    print(f"⊘ Skipped (no image URL): {skipped_no_url}")
    print(f"Total processed: {downloaded + failed + skipped_exists + skipped_no_url}")

    # Print failed items if any
    if failed_items:
        print("\n" + "!" * 70)
        print("FAILED DOWNLOADS:")
        print("!" * 70)
        for item in failed_items:
            print(f"\n{item['id']}:")
            print(f"  URL: {item['url']}")
            print(f"  Error: {item['error']}")
        print("\n" + "!" * 70)

    # Print skipped items (missing data) if any
    if skipped_items:
        print("\n" + "?" * 70)
        print("SKIPPED ITEMS (Missing Data):")
        print("?" * 70)
        for item in skipped_items:
            print(f"\n{item['id']}:")
            print(f"  Reason: {item['reason']}")
            # Print additional context based on what's available
            if 'name' in item:
                print(f"  Name: {item['name']}")
            if 'manufacturer_url' in item:
                print(f"  Manufacturer URL: {item['manufacturer_url']}")
            if 'url' in item:
                print(f"  Image URL: {item['url']}")
        print("\n" + "?" * 70)

if __name__ == "__main__":
    import sys

    # Parse command line arguments
    test_mode = "--test" in sys.argv
    force = "--force" in sys.argv
    json_file = "glassitems.json"
    max_workers = 8  # Default

    i = 1
    while i < len(sys.argv):
        arg = sys.argv[i]
        if arg == "--test":
            pass  # Already handled
        elif arg == "--force":
            pass  # Already handled
        elif arg == "--workers" and i + 1 < len(sys.argv):
            max_workers = int(sys.argv[i + 1])
            i += 1  # Skip the next argument
        elif not arg.startswith("--"):
            json_file = arg
        i += 1

    if test_mode:
        print("Running in TEST MODE - will stop after 3 downloads\n")

    print(f"Processing {json_file}...")
    print(f"Parallel workers: {max_workers}\n")
    download_images_from_json(json_file, test_mode=test_mode, force=force, max_workers=max_workers)

import json
import os
import urllib.request
import urllib.error
from pathlib import Path
from urllib.parse import urlparse

def download_images_from_json(json_file, test_mode=False):
    """
    Downloads images from URLs in a JSON file and saves them with SKU names.
    
    Args:
        json_file: Path to the JSON file containing image URLs and SKUs
        test_mode: If True, stops after 3 successful downloads
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
    skipped = 0
    
    print(f"Found {len(items)} items in JSON file\n")
    
    # Debug: Show first few items
    print("DEBUG: Checking first 5 items:")
    for i, item in enumerate(list(items)[:5]):
        if isinstance(item, dict):
            print(f"  Item {i}: id={item.get('id')}, has image_url={bool(item.get('image_url'))}")
            if item.get('image_url'):
                print(f"    URL: {item.get('image_url')[:80]}...")
        else:
            print(f"  Item {i}: Not a dict, type={type(item)}")
    print()
    
    for item in items:
        # Handle nested structures
        if not isinstance(item, dict):
            continue
            
        # Extract fields based on colors.json format
        item_id = item.get('id')  # Full ID like "NS-137" or "EF-591046"
        manufacturer = item.get('manufacturer')  # Short code like "NS", "EF", "GA"
        url = item.get('image_url')  # The actual image URL
        
        if not item_id:
            skipped += 1
            continue
        
        if not url:
            skipped += 1
            continue
        
        if not manufacturer:
            skipped += 1
            continue
        
        # Get file extension from URL
        parsed_url = urlparse(url)
        ext = os.path.splitext(parsed_url.path)[1] or '.jpg'
        
        # Clean the item_id: replace slashes and backslashes with dashes
        clean_id = item_id.replace('/', '-').replace('\\', '-')
        
        # Create output filename with manufacturer-id format
        # The id already contains manufacturer info, so use it directly
        output_file = output_dir / f"{clean_id}{ext}"
        
        # Download the image
        try:
            print(f"Downloading {item_id} from {url}...")
            
            # Create request with a user agent to avoid being blocked
            req = urllib.request.Request(url)
            req.add_header('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')
            
            with urllib.request.urlopen(req, timeout=30) as response:
                image_data = response.read()
            
            # Save the image
            with open(output_file, 'wb') as f:
                f.write(image_data)
            
            print(f"✓ Successfully saved {output_file}")
            downloaded += 1
            
            # Stop after 3 downloads in test mode
            if test_mode and downloaded >= 3:
                print("\nTest mode: Stopping after 3 downloads")
                break
            
        except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as e:
            print(f"✗ Failed to download {item_id}: {e}")
            failed += 1
    
    print(f"\nSummary: {downloaded} downloaded, {failed} failed, {skipped} skipped (no image URL)")

if __name__ == "__main__":
    import sys
    
    # Parse command line arguments
    test_mode = "--test" in sys.argv
    json_file = "colors.json"
    
    for arg in sys.argv[1:]:
        if arg != "--test":
            json_file = arg
    
    if test_mode:
        print("Running in TEST MODE - will stop after 3 downloads\n")
    
    print(f"Processing {json_file}...")
    download_images_from_json(json_file, test_mode=test_mode)

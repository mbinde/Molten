#!/usr/bin/env python3
"""
Color Tag Analyzer - Suggests color tags for glass products using image and text analysis.

This script:
1. Analyzes product images using Claude's vision API
2. Analyzes product names/descriptions using Claude API
3. Generates suggested tags in JSON format for web review
4. Tracks image checksums to detect changes
5. Only re-analyzes new/changed products

Usage:
    python3 color_tag_analyzer.py              # Analyze new/changed products
    python3 color_tag_analyzer.py --force      # Re-analyze all products
    python3 color_tag_analyzer.py --limit 10   # Analyze only 10 products (testing)
"""

import json
import os
import sys
import hashlib
from datetime import datetime
from pathlib import Path
import base64
import argparse
import time
from anthropic import Anthropic

# Full color taxonomy (expanded from original)
COLOR_TAXONOMY = [
    # Primary colors
    "red", "blue", "green", "yellow", "orange", "purple", "pink",
    # Extended colors
    "brown", "gray", "black", "white", "clear",
    "teal", "amber", "lavender", "aqua", "cream", "magenta",
    # Attributes
    "transparent", "opaque", "sparkle", "striker", "reducing", "uv"
]

# Paths
SCRIPT_DIR = Path(__file__).parent
DATABASE_PATH = SCRIPT_DIR / "glass_database.json"
SUGGESTIONS_PATH = SCRIPT_DIR / "color_tag_suggestions.json"
APPROVALS_PATH = SCRIPT_DIR / "color_tag_approvals.json"
IMAGES_DIR = Path("/Users/binde/projects/misc/Molten/Sources/Resources/product-images")

# Analysis version - increment when improving detection logic
ANALYSIS_VERSION = "2.0"  # Updated to use LLM for text analysis

# Initialize Anthropic client (will use ANTHROPIC_API_KEY env var)
anthropic_client = None


def get_anthropic_client():
    """Get or create Anthropic client."""
    global anthropic_client
    if anthropic_client is None:
        api_key = os.environ.get('ANTHROPIC_API_KEY')
        if not api_key:
            raise ValueError("ANTHROPIC_API_KEY environment variable not set")
        anthropic_client = Anthropic(api_key=api_key)
    return anthropic_client


def calculate_image_checksum(image_path):
    """Calculate MD5 checksum of an image file."""
    if not os.path.exists(image_path):
        return None

    md5 = hashlib.md5()
    with open(image_path, 'rb') as f:
        for chunk in iter(lambda: f.read(4096), b""):
            md5.update(chunk)
    return md5.hexdigest()


def load_database():
    """Load the glass products database."""
    with open(DATABASE_PATH, 'r') as f:
        return json.load(f)


def load_existing_suggestions():
    """Load existing suggestions file, or return empty structure."""
    if SUGGESTIONS_PATH.exists():
        with open(SUGGESTIONS_PATH, 'r') as f:
            return json.load(f)

    return {
        "version": "1.0",
        "analysis_version": ANALYSIS_VERSION,
        "generated": datetime.now().isoformat(),
        "taxonomy": COLOR_TAXONOMY,
        "products": {}
    }


def load_approvals():
    """Load previous approvals file if it exists."""
    if APPROVALS_PATH.exists():
        with open(APPROVALS_PATH, 'r') as f:
            return json.load(f)
    return {
        "version": "1.0",
        "approved_date": None,
        "products": {}
    }


def needs_analysis(product, existing_suggestions, force=False):
    """
    Determine if a product needs (re)analysis.

    Returns: (needs_analysis: bool, reason: str)
    """
    stable_id = product['stable_id']

    # Force mode: analyze everything
    if force:
        return True, "force mode"

    # Not in suggestions yet: new product
    if stable_id not in existing_suggestions['products']:
        return True, "new product"

    existing = existing_suggestions['products'][stable_id]

    # Analysis version changed: improved detection
    if existing.get('analysis_version') != ANALYSIS_VERSION:
        return True, "analysis version updated"

    # Find image file
    image_path = find_image_file(stable_id)
    if not image_path:
        return False, "no image"

    # Image checksum changed: new photo
    current_checksum = calculate_image_checksum(image_path)
    if current_checksum != existing.get('image_checksum'):
        return True, "image changed"

    return False, "up to date"


def find_image_file(stable_id):
    """Find the image file for a product (checks jpg, jpeg, png)."""
    for ext in ['.jpg', '.jpeg', '.png']:
        path = IMAGES_DIR / f"{stable_id}{ext}"
        if path.exists():
            return path
    return None


def analyze_text_for_colors(name, description):
    """
    Extract color tags from product name and description using Claude API.
    Returns list of color/attribute tags from the taxonomy.
    """
    client = get_anthropic_client()

    # Build the taxonomy list for the prompt
    taxonomy_str = ", ".join(COLOR_TAXONOMY)

    prompt = f"""You are analyzing a glass product for a flameworking catalog. Based on the product name and description, identify which colors and attributes apply.

Product Name: {name}
Description: {description}

Available tags (choose ONLY from this list):
{taxonomy_str}

Rules:
- Only return tags that are clearly indicated by the name or description
- Consider context (e.g., "Blue Honey" is blue glass, not honey-colored)
- Return multiple colors if the glass has multiple colors
- Include attributes like "transparent", "opaque", "sparkle", "striker", "reducing", "uv" if mentioned
- If no colors/attributes are clearly indicated, return an empty list

Return ONLY a JSON array of applicable tags, like: ["blue", "transparent"]
Do not include any explanation or additional text."""

    try:
        # Rate limit: 1 request per second
        time.sleep(1)

        response = client.messages.create(
            model="claude-3-5-haiku-20241022",  # Fast, cheap model
            max_tokens=100,
            messages=[{"role": "user", "content": prompt}]
        )

        # Parse the response
        response_text = response.content[0].text.strip()

        # Extract JSON array from response
        try:
            tags = json.loads(response_text)
            if isinstance(tags, list):
                # Validate tags are in taxonomy
                valid_tags = [t.lower() for t in tags if t.lower() in [c.lower() for c in COLOR_TAXONOMY]]
                return valid_tags
            else:
                print(f"  Warning: LLM returned non-list: {response_text}")
                return []
        except json.JSONDecodeError:
            print(f"  Warning: LLM returned invalid JSON: {response_text}")
            return []

    except Exception as e:
        print(f"  Error calling Claude API: {e}")
        return []


def encode_image_base64(image_path):
    """Encode image to base64 for API."""
    with open(image_path, 'rb') as f:
        return base64.b64encode(f.read()).decode('utf-8')


def analyze_image_with_claude(image_path, product_name):
    """
    Analyze image using Claude API for color detection.

    NOTE: This is a placeholder that will be called by the user (Claude Code).
    When running the script, you'll need to integrate with the Anthropic API
    or have the user (me) analyze images in batches.
    """
    # This will be implemented as a separate step where images are analyzed
    # For now, return empty list - we'll do a two-phase approach:
    # Phase 1: Generate text-based suggestions
    # Phase 2: User runs analysis with Claude to enhance suggestions

    print(f"  Image analysis needed for: {product_name}")
    return []


def calculate_tag_changes(current_db_tags, suggested_tags, previously_approved):
    """
    Calculate what's new, removed, or unchanged in tag suggestions.

    Returns: dict with new, removed, unchanged tags
    """
    current_set = set(current_db_tags)
    suggested_set = set(suggested_tags)
    previous_set = set(previously_approved) if previously_approved else set()

    # Compare against what was previously approved (if exists), else current DB
    comparison_base = previous_set if previous_set else current_set

    return {
        "new": sorted(list(suggested_set - comparison_base)),
        "removed": sorted(list(comparison_base - suggested_set)),
        "unchanged": sorted(list(suggested_set & comparison_base))
    }


def analyze_product(product, existing_suggestions, approvals):
    """Analyze a single product and generate tag suggestions."""
    stable_id = product['stable_id']
    name = product.get('name', '')
    description = product.get('manufacturer_description', '')
    manufacturer = product.get('manufacturer', '')
    manufacturer_url = product.get('manufacturer_url', '')

    # Handle tags - might be list or JSON string
    current_tags = product.get('tags', [])
    if isinstance(current_tags, str):
        import json as json_lib
        try:
            current_tags = json_lib.loads(f'[{current_tags}]') if current_tags else []
        except:
            current_tags = []

    # Ensure current_tags is a list of strings
    if not isinstance(current_tags, list):
        current_tags = []
    current_tags = [str(t).strip().lower() for t in current_tags if t]

    # Find image
    image_path = find_image_file(stable_id)
    image_checksum = calculate_image_checksum(image_path) if image_path else None

    # Analyze text
    text_tags = analyze_text_for_colors(name, description)

    # Analyze image (placeholder for now)
    image_tags = []
    needs_image_analysis = bool(image_path)  # Track if image analysis is needed

    # Combine suggestions (remove duplicates, lowercase)
    # Don't include internal markers like __NEEDS_IMAGE_ANALYSIS__
    suggested_tags = sorted(list(set([t.lower() for t in text_tags + image_tags if t and not t.startswith('__')])))

    # Get previously approved tags if they exist
    previous_approval = approvals.get('products', {}).get(stable_id, {})
    previously_approved = previous_approval.get('approved_tags', [])

    # Calculate tag changes
    tag_changes = calculate_tag_changes(current_tags, suggested_tags, previously_approved)

    # Determine review status
    if previously_approved:
        # Has been reviewed before
        if tag_changes['new'] or tag_changes['removed']:
            review_status = "needs_review"  # Changes detected
        else:
            review_status = "unchanged"  # Same as before
    else:
        # First time review
        review_status = "needs_review"

    # Determine confidence
    confidence = "medium"
    if len(text_tags) > 0 and image_tags:
        confidence = "high"  # Text + image analysis
    elif len(text_tags) == 0 and len(image_tags) == 0:
        confidence = "low"   # No tags detected

    # Check if this is a re-analysis
    is_reanalysis = stable_id in existing_suggestions['products']
    first_analyzed = existing_suggestions['products'][stable_id].get('first_analyzed') if is_reanalysis else datetime.now().isoformat()

    return {
        "stable_id": stable_id,
        "manufacturer": manufacturer,
        "name": name,
        "description": description,
        "manufacturer_url": manufacturer_url,
        "image_path": image_path.name if image_path else None,
        "image_checksum": image_checksum,
        "current_tags": current_tags,
        "suggested_tags": suggested_tags,
        "previously_approved": previously_approved,
        "tag_changes": tag_changes,
        "review_status": review_status,
        "confidence": confidence,
        "needs_image_analysis": needs_image_analysis,
        "detection_sources": {
            "text": text_tags,
            "image": image_tags
        },
        "analysis_version": ANALYSIS_VERSION,
        "first_analyzed": first_analyzed,
        "last_analyzed": datetime.now().isoformat()
    }


def main():
    parser = argparse.ArgumentParser(description='Analyze glass products for color tags')
    parser.add_argument('--force', action='store_true', help='Re-analyze all products')
    parser.add_argument('--limit', type=int, help='Limit number of products to analyze (for testing)')
    args = parser.parse_args()

    print("=" * 70)
    print("GLASS PRODUCT COLOR TAG ANALYZER")
    print("=" * 70)
    print()

    # Check for API key
    if not os.environ.get('ANTHROPIC_API_KEY'):
        print("❌ ERROR: ANTHROPIC_API_KEY environment variable not set")
        print("\nThis analyzer uses Claude API for intelligent text analysis.")
        print("Please set your API key:")
        print("  export ANTHROPIC_API_KEY='your-api-key-here'")
        print()
        return False

    # Load data
    print("Loading database...")
    db = load_database()
    products = db.get('products', {})
    print(f"  Found {len(products)} products in database")

    print("Loading existing suggestions...")
    suggestions = load_existing_suggestions()
    print(f"  Found {len(suggestions.get('products', {}))} existing suggestions")

    print("Loading previous approvals...")
    approvals = load_approvals()
    approved_count = len([p for p in approvals.get('products', {}).values() if p.get('status') == 'approved'])
    print(f"  Found {approved_count} previously approved products")
    print()

    # Filter to available and discontinued glass products
    # (discontinued glass may still be sold/used)
    # Only analyze glass products (future: will have tools, etc.)
    available_products = [
        p for p in products.values()
        if p.get('status') in ['available', 'discontinued']
        and p.get('product_type', 'glass') == 'glass'  # Default to 'glass' for backward compatibility
    ]
    print(f"Filtering to available+discontinued glass products: {len(available_products)}")

    # Determine which products need analysis
    print()
    print("Checking which products need analysis...")
    to_analyze = []
    reasons = {}

    for product in available_products:
        needs, reason = needs_analysis(product, suggestions, force=args.force)
        if needs:
            to_analyze.append(product)
            reasons[reason] = reasons.get(reason, 0) + 1

    print(f"  Products needing analysis: {len(to_analyze)}")
    for reason, count in sorted(reasons.items()):
        print(f"    - {reason}: {count}")

    if not to_analyze:
        print("\n✅ All products are up to date!")
        return

    # Apply limit if specified
    if args.limit:
        to_analyze = to_analyze[:args.limit]
        print(f"\n⚠️  Limited to {args.limit} products for testing")

    # Analyze products
    print()
    print(f"Analyzing {len(to_analyze)} products using Claude API...")
    print("⏱️  This will take approximately {:.1f} minutes (1 second per product)".format(len(to_analyze) / 60))
    print("-" * 70)

    analyzed_count = 0
    start_time = time.time()

    for product in to_analyze:
        stable_id = product['stable_id']
        name = product.get('name', 'Unknown')

        # Show progress for every product (since it's slow)
        elapsed = time.time() - start_time
        if analyzed_count > 0:
            rate = analyzed_count / elapsed
            remaining = (len(to_analyze) - analyzed_count) / rate
            print(f"[{analyzed_count}/{len(to_analyze)}] {stable_id} - {name[:50]} (ETA: {remaining/60:.1f}m)")
        else:
            print(f"[{analyzed_count}/{len(to_analyze)}] {stable_id} - {name[:50]}")

        result = analyze_product(product, suggestions, approvals)
        suggestions['products'][stable_id] = result

        analyzed_count += 1

    print("-" * 70)
    elapsed = time.time() - start_time
    print(f"✅ Analyzed {analyzed_count} products in {elapsed/60:.1f} minutes")

    # Update metadata
    suggestions['generated'] = datetime.now().isoformat()
    suggestions['analysis_version'] = ANALYSIS_VERSION
    suggestions['taxonomy'] = COLOR_TAXONOMY

    # Save suggestions
    print()
    print(f"Saving suggestions to: {SUGGESTIONS_PATH}")
    with open(SUGGESTIONS_PATH, 'w') as f:
        json.dump(suggestions, f, indent=2)

    print()
    print("=" * 70)
    print("SUMMARY")
    print("=" * 70)
    print(f"Total products in suggestions: {len(suggestions['products'])}")
    print(f"Newly analyzed: {analyzed_count}")

    # Count by review status
    status_counts = {}
    for p in suggestions['products'].values():
        status = p.get('review_status', 'unknown')
        status_counts[status] = status_counts.get(status, 0) + 1

    print(f"\nReview status:")
    for status, count in sorted(status_counts.items()):
        print(f"  {status}: {count}")

    needs_image = sum(1 for p in suggestions['products'].values() if p.get('needs_image_analysis', False))
    print(f"\nProducts with images (can be enhanced with vision analysis): {needs_image}")

    print()
    print("Next steps:")
    print("  1. Review suggestions: ./review_color_tags.sh --review")
    print("  2. Or run full workflow: ./review_color_tags.sh --all")
    print()
    print("Note: Text analysis now uses Claude API for intelligent color detection.")


if __name__ == "__main__":
    main()

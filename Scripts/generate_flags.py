#!/usr/bin/env python3
"""
Generate catalog flags using Claude API analysis.

Analyzes glass item names, tags, and manufacturer descriptions to suggest
appropriate flags from the GlassFlagKey enum.

Each batch is written to its own file for resilience.
Run assemble_flags.py afterward to combine into final export format.
"""

import anthropic
import sqlite3
import json
import os
import time
from pathlib import Path
from datetime import datetime

# Configuration
BATCH_SIZE = 20
MODEL = "claude-sonnet-4-20250514"
OUTPUT_DIR = Path(__file__).parent.parent / "FlagOutput"
CATALOG_DB = Path(__file__).parent.parent / "Molten/Sources/Resources/catalog.sqlite"
MFRDESC_DB = Path(__file__).parent.parent / "Molten/Sources/Resources/mfrdesc.sqlite"

# All available flag keys with descriptions for the prompt
FLAG_DEFINITIONS = """
Available flags (use exactly these keys):

BOOLEAN FLAGS (apply if true for this glass):
- no_deep_encase: Glass should NOT be deeply encased (will cause issues)
- can_deep_encase: Glass CAN be safely deep-encased
- beginner_color: Easy to work with, forgiving, good for beginners
- advanced_color: Difficult to work with, requires experience
- needs_long_anneal: Requires longer than normal annealing time
- needs_short_anneal: Can use shorter annealing time
- color_matures_in_kiln: Color develops/changes during kiln annealing
- striking_color: Color must be "struck" (reheated) to develop
- mottled_color: Has a mottled, variegated, or streaky appearance
- reduction_color: Color changes/develops in a reducing flame
- reacts_with_silver: Reacts with silver-containing glasses
- reacts_with_copper: Reacts with copper-containing glasses
- shocky: Prone to thermal shock, needs careful heating/cooling
- boils_easily: Tends to boil/bubble if overheated
- devitrifies: Prone to devitrification (crystallization on surface)
- sensitive_to_cooling_rate: Color/properties affected by cooling speed
- contains_silver: Contains silver in the formulation
- good_for_stringers: Stretches well into thin stringers
- transparent: Fully transparent/clear
- opaque: Fully opaque (blocks light)
- melts_smoothly: Melts evenly without issues
- melt_neutral_oxidizing: Best worked in neutral to oxidizing flame
- heat_slowly: Should be heated slowly to avoid issues
- cadmium: Contains cadmium (safety consideration)

PARAMETRIC FLAGS (include numeric value if mentioned):
- custom_anneal_temp: Specific annealing temperature in °F
- max_working_temp: Maximum working temperature in °F
- hold_time: Recommended hold time in minutes
- ramp_down_rate: Cooling rate in °F/hour
"""

SYSTEM_PROMPT = f"""You are analyzing glass items for a lampworking/glassblowing catalog.
For each item, based on its name, tags, and manufacturer description, determine which flags apply.

{FLAG_DEFINITIONS}

IMPORTANT GUIDELINES:
1. Only include flags you're reasonably confident about based on the available information
2. If description is empty/missing, you can still infer some flags from name and tags (e.g., "opal" suggests mottled, "transparent" tag means transparent)
3. For parametric flags, include the numeric value
4. Be conservative - it's better to miss a flag than to incorrectly assign one
5. Many items won't have any flags - that's fine, return an empty list

Return JSON array with one object per item:
[
  {{
    "stable_id": "xxx",
    "flags": [
      {{"key": "flag_key", "value": true}},
      {{"key": "parametric_flag", "value": true, "numeric": 950}}
    ]
  }},
  ...
]

Return ONLY the JSON array, no other text."""


def load_catalog_data():
    """Load glass items and their descriptions."""
    items = []

    # Load glass items
    conn = sqlite3.connect(CATALOG_DB)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute("SELECT stable_id, name, tags, manufacturer FROM glass_items")
    glass_items = {row['stable_id']: dict(row) for row in cursor.fetchall()}
    conn.close()

    # Load manufacturer descriptions
    conn = sqlite3.connect(MFRDESC_DB)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute("SELECT stable_id, manufacturer_description_orig FROM manufacturer_descriptions")
    descriptions = {row['stable_id']: row['manufacturer_description_orig'] for row in cursor.fetchall()}
    conn.close()

    # Combine data
    for stable_id, item in glass_items.items():
        items.append({
            'stable_id': stable_id,
            'name': item['name'],
            'tags': item['tags'] or '',
            'manufacturer': item['manufacturer'],
            'description': descriptions.get(stable_id, '') or ''
        })

    return items


def format_items_for_prompt(items):
    """Format a batch of items for the Claude prompt."""
    lines = []
    for item in items:
        lines.append(f"---")
        lines.append(f"stable_id: {item['stable_id']}")
        lines.append(f"name: {item['name']}")
        lines.append(f"manufacturer: {item['manufacturer']}")
        lines.append(f"tags: {item['tags']}")
        lines.append(f"description: {item['description'][:500] if item['description'] else '(none)'}")
    return "\n".join(lines)


def process_batch(client, items, batch_num):
    """Process a batch of items and return the results."""
    prompt = f"Analyze these {len(items)} glass items and return flags for each:\n\n{format_items_for_prompt(items)}"

    response = client.messages.create(
        model=MODEL,
        max_tokens=4096,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": prompt}]
    )

    # Parse the response
    response_text = response.content[0].text.strip()

    # Handle markdown code blocks if present
    if response_text.startswith("```"):
        lines = response_text.split("\n")
        # Remove first line (```json) and last line (```)
        response_text = "\n".join(lines[1:-1])

    try:
        results = json.loads(response_text)
    except json.JSONDecodeError as e:
        print(f"  WARNING: Failed to parse JSON for batch {batch_num}: {e}")
        print(f"  Response was: {response_text[:200]}...")
        # Return empty results for this batch - we'll note it for manual review
        results = [{"stable_id": item['stable_id'], "flags": [], "parse_error": True} for item in items]

    return results, response.usage


def get_completed_batches():
    """Get list of already completed batch numbers."""
    if not OUTPUT_DIR.exists():
        return set()

    completed = set()
    for f in OUTPUT_DIR.glob("batch_*.json"):
        try:
            num = int(f.stem.split("_")[1])
            completed.add(num)
        except (ValueError, IndexError):
            pass
    return completed


def main():
    # Load API key
    api_key_path = Path.home() / ".ANTHROPIC_API_KEY"
    if not api_key_path.exists():
        print("ERROR: ~/.ANTHROPIC_API_KEY not found")
        return 1

    api_key = api_key_path.read_text().strip()
    client = anthropic.Anthropic(api_key=api_key)

    # Create output directory
    OUTPUT_DIR.mkdir(exist_ok=True)

    # Load data
    print("Loading catalog data...")
    items = load_catalog_data()
    print(f"Loaded {len(items)} glass items")

    # Check for already completed batches (for resume capability)
    completed = get_completed_batches()
    if completed:
        print(f"Found {len(completed)} already completed batches, will skip those")

    # Process in batches
    total_batches = (len(items) + BATCH_SIZE - 1) // BATCH_SIZE
    total_input_tokens = 0
    total_output_tokens = 0

    print(f"Processing {total_batches} batches of {BATCH_SIZE} items each...")
    print(f"Output directory: {OUTPUT_DIR}")
    print()

    for batch_num in range(total_batches):
        # Skip if already completed
        if batch_num in completed:
            print(f"Batch {batch_num + 1}/{total_batches}: SKIPPED (already done)")
            continue

        start_idx = batch_num * BATCH_SIZE
        end_idx = min(start_idx + BATCH_SIZE, len(items))
        batch_items = items[start_idx:end_idx]

        print(f"Batch {batch_num + 1}/{total_batches}: items {start_idx}-{end_idx-1}...", end=" ", flush=True)

        try:
            results, usage = process_batch(client, batch_items, batch_num)
            total_input_tokens += usage.input_tokens
            total_output_tokens += usage.output_tokens

            # Count flags found
            flags_count = sum(len(r.get('flags', [])) for r in results)

            # Write batch results immediately
            batch_file = OUTPUT_DIR / f"batch_{batch_num:04d}.json"
            with open(batch_file, 'w') as f:
                json.dump({
                    'batch_num': batch_num,
                    'timestamp': datetime.now().isoformat(),
                    'items_processed': len(batch_items),
                    'flags_found': flags_count,
                    'results': results
                }, f, indent=2)

            print(f"OK ({flags_count} flags found, {usage.input_tokens}+{usage.output_tokens} tokens)")

            # Small delay to avoid rate limits
            time.sleep(0.5)

        except Exception as e:
            print(f"ERROR: {e}")
            # Write error file so we know this batch needs retry
            error_file = OUTPUT_DIR / f"batch_{batch_num:04d}_ERROR.txt"
            with open(error_file, 'w') as f:
                f.write(f"Error at {datetime.now().isoformat()}: {e}\n")
            continue

    # Print summary
    print()
    print("=" * 50)
    print("COMPLETE!")
    print(f"Total input tokens: {total_input_tokens:,}")
    print(f"Total output tokens: {total_output_tokens:,}")

    # Estimate cost (Sonnet pricing)
    input_cost = total_input_tokens * 3 / 1_000_000
    output_cost = total_output_tokens * 15 / 1_000_000
    print(f"Estimated cost: ${input_cost:.2f} (input) + ${output_cost:.2f} (output) = ${input_cost + output_cost:.2f}")
    print()
    print(f"Run 'python assemble_flags.py' to combine batch files into final export.")

    return 0


if __name__ == "__main__":
    exit(main())

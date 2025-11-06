#!/usr/bin/env python3
"""
Tool Title Cleanup Script

Cleans up tool product names according to these rules:
1. Move leading measurements to end with comma (e.g., "2 piece tool set" → "Tool Set, 2 piece")
2. Convert to Title Case (except measurements and abbreviations)
3. Remove SKU codes from titles (e.g., "(BP14)" → removed)

Measurement patterns to move:
- "10 pieces", "2 piece"
- '1.5" x 3"', '1/4"', '3/8"'
- "10:1", "2:1"
- "14 point", "3 sided"
- Numbers at start followed by descriptive words

Example transformations:
- "1/4\" bowl push (BP14)" → "Bowl Push, 1/4\""
- "2 piece marble tool set" → "Marble Tool Set, 2 Piece"
- "10:1 ratio tweezers" → "Ratio Tweezers, 10:1"
"""

import json
import re
import sys
from pathlib import Path


# Words that should stay lowercase in title case (articles, conjunctions, prepositions)
LOWERCASE_WORDS = {'a', 'an', 'the', 'and', 'but', 'or', 'for', 'nor', 'on', 'at', 'to', 'from', 'by', 'of', 'in', 'with'}

# Measurement units and abbreviations that should stay as-is or uppercase
PRESERVE_CASE = {
    'mm', 'cm', 'oz', 'lb', 'kg', 'g',  # metric/imperial units
    'bp', 'bk', 'mk', 'mf', 'ms', 'xs', 'sm', 'md', 'lg', 'xl',  # common tool SKU prefixes and sizes
}


def extract_sku_from_title(title):
    """
    Extract and remove SKU codes from title

    Patterns:
    - (BP14), (BK-12), (MK 3), (model # M58)
    - [BP14], [BK-12]
    - (1" marble tool), (1/2" marble tool) - measurement descriptions
    - Leading SKU codes: MS1.5, MF1, MF12 (only if followed by parentheses)

    Returns:
        tuple: (cleaned_title, extracted_sku_or_measurement or None)
    """
    # Match parenthesized or bracketed codes and measurements
    patterns = [
        # Model number patterns: (model # M58), (Model P1.5)
        (r'\s*\(model\s*#?\s*[A-Z0-9.]+\)', True),  # True = remove

        # SKU codes: (BP14), (BK-12), (MK 3)
        (r'\s*\(([A-Z]{2,}[-\s]?\d+[A-Z]?)\)', True),  # True = remove
        (r'\s*\[([A-Z]{2,}[-\s]?\d+[A-Z]?)\]', True),

        # Measurement descriptions: (1" marble tool), (1/2" tool), (1.5" marble tool)
        (r'\s*\((\d+(?:\.\d+)?(?:/\d+)?"\s+[^)]+)\)', False),  # False = keep as measurement

        # Leading SKU codes before parentheses: "MS1.5 (1.5" marble tool)" → remove MS1.5
        (r'^([A-Z]{2}\d+\.?\d*)\s+\(', True),  # Remove leading SKU like MS1.5, MF1
    ]

    extracted = None
    for pattern, should_remove in patterns:
        match = re.search(pattern, title, re.IGNORECASE)
        if match:
            if should_remove:
                # Remove SKU entirely
                title = re.sub(pattern, '', title, flags=re.IGNORECASE)
                # For leading SKU pattern, keep the opening paren
                if pattern.startswith('^'):
                    title = '(' + title
            else:
                # Extract for repositioning (measurements)
                extracted = match.group(1).strip() if match.lastindex else None
                title = re.sub(pattern, '', title, flags=re.IGNORECASE)
            break

    return title.strip(), extracted


def extract_leading_measurement(title):
    """
    Extract measurements/numbers from the beginning of the title

    Returns:
        tuple: (remaining_title, measurement or None)
    """
    patterns = [
        # Complex measurements: 2 1/2", 1.5" x 3" (must come before simple fractions)
        (r'^(\d+\s+\d+/\d+")\s*[\s-]*', r'\1'),  # e.g., "2 1/2""
        (r'^(\d+\.?\d*"\s*x\s*\d+\.?\d*")\s*[\s-]*', r'\1'),  # e.g., "1.5" x 3""

        # Simple fractions with units: 1/4", 3/8"
        (r'^(\d+/\d+")\s*[\s-]*', r'\1'),
        (r'^(\d+\.?\d*")\s*[\s-]*', r'\1'),

        # Ratios: 10:1, 2:1
        (r'^(\d+:\d+)[\s-]*', r'\1'),

        # Piece counts: 2 piece, 10 pieces
        (r'^(\d+\s*pieces?)[\s-]*', r'\1', 'lower'),

        # Point/sided: 14 point, 3 sided
        (r'^(\d+\s*(?:point|sided))[\s-]*', r'\1', 'lower'),

        # Generic number + descriptor: 2 pack, 10 set
        (r'^(\d+\s*(?:pack|set|kit))[\s-]*', r'\1', 'lower'),

        # Just a number at the start (less specific, lower priority)
        (r'^(\d+)[\s-]+', r'\1'),
    ]

    for pattern_info in patterns:
        pattern = pattern_info[0]
        keep_case = pattern_info[2] if len(pattern_info) > 2 else None

        match = re.match(pattern, title, re.IGNORECASE)
        if match:
            measurement = match.group(1)
            remaining = title[match.end():].strip()

            # Clean up measurement
            if keep_case == 'lower':
                measurement = measurement.lower()

            return remaining, measurement

    return title, None


def to_smart_title_case(text):
    """
    Convert to title case with smart handling of special cases

    Rules:
    - First word always capitalized
    - Articles/conjunctions/prepositions lowercase (unless first word)
    - Measurements and units preserved as-is
    - Abbreviations preserved
    - Text within parentheses preserved as lowercase
    """
    if not text:
        return text

    # Lowercase "x" in dimension patterns like "1.5" x 3"" → "1.5" x 3""
    text = re.sub(r'(\d+\.?\d*")\s*[Xx]\s*(\d+\.?\d*")', r'\1 x \2', text)

    # Extract and preserve parenthetical content
    paren_content = {}
    paren_counter = [0]  # Use list to allow modification in nested function

    def replace_paren(match):
        placeholder = f'__PAREN{paren_counter[0]}__'
        # Keep parenthetical content as lowercase
        paren_content[placeholder] = f'({match.group(1).lower()})'
        paren_counter[0] += 1
        return placeholder

    text = re.sub(r'\(([^)]+)\)', replace_paren, text)

    words = text.split()
    result = []

    for i, word in enumerate(words):
        # Check if it's a placeholder for parenthetical content
        if word.startswith('__PAREN') and word.endswith('__'):
            result.append(paren_content[word])
        # Check if it's a measurement or unit (contains numbers or units)
        elif re.search(r'[0-9/"]', word):
            # Preserve measurements as-is
            result.append(word)
        # Check if word contains quotes - preserve content inside
        elif "'" in word:
            # Preserve quoted content as-is
            result.append(word)
        # Check if it's lowercase "x" (for dimensions)
        elif word == 'x' or word == 'X':
            result.append('x')
        # Check if it's a known abbreviation
        elif word.lower() in PRESERVE_CASE:
            result.append(word.upper())
        # Check if it's a small word (but not first word)
        elif i > 0 and word.lower() in LOWERCASE_WORDS:
            result.append(word.lower())
        # Standard title case
        else:
            # Handle hyphenated words: "double-edge" → "Double-Edge"
            if '-' in word:
                parts = word.split('-')
                result.append('-'.join(p.capitalize() for p in parts))
            else:
                result.append(word.capitalize())

    return ' '.join(result)


def clean_tool_title(title):
    """
    Apply all cleaning rules to a tool title

    Returns:
        str: Cleaned title
    """
    if not title:
        return title

    original = title

    # Step 0: Handle special case of SKU-only titles like "MF1 (1" marble tool)"
    # Extract the product description from parentheses and use as main title
    sku_only_match = re.match(r'^([A-Z]{2}\d+\.?\d*)\s+\((\d+(?:\.\d+)?(?:/\d+)?"\s+(.+?))\)$', title)
    if sku_only_match:
        # Extract: measurement (e.g., "1"") and product name (e.g., "marble tool")
        measurement = sku_only_match.group(2).split()[0]  # "1""
        product_name = ' '.join(sku_only_match.group(2).split()[1:])  # "marble tool"
        title = f"{product_name}, {measurement}"
        # Apply title case and return early
        return to_smart_title_case(title)

    # Step 1: Extract and handle SKU codes / measurement descriptions in parens
    title, extracted_paren = extract_sku_from_title(title)

    # Step 2: Extract leading measurements
    title, leading_measurement = extract_leading_measurement(title)

    # Step 3: Clean up extra whitespace
    title = re.sub(r'\s+', ' ', title).strip()

    # Step 4: Apply title case
    title = to_smart_title_case(title)

    # Step 5: Add measurements back at the end
    # Priority: leading measurement, then parenthetical measurement
    measurement_to_add = leading_measurement or (extracted_paren if extracted_paren and '"' in extracted_paren else None)

    if measurement_to_add:
        # Clean up the measurement
        measurement_to_add = to_smart_title_case(measurement_to_add)
        title = f"{title}, {measurement_to_add}"

    return title


def process_tools_json(file_path, dry_run=False):
    """
    Process a tool JSON file and clean all product names

    Args:
        file_path: Path to the tool JSON file
        dry_run: If True, show changes without writing

    Returns:
        tuple: (num_changed, changes_list)
    """
    print(f"\n{'='*60}")
    print(f"Processing: {file_path.name}")
    print(f"{'='*60}")

    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    changes = []
    num_changed = 0

    for tool in data['tools']:
        original_name = tool['name']
        cleaned_name = clean_tool_title(original_name)

        if cleaned_name != original_name:
            num_changed += 1
            changes.append((original_name, cleaned_name))
            tool['name'] = cleaned_name

            print(f"\n  BEFORE: {original_name}")
            print(f"  AFTER:  {cleaned_name}")

    if num_changed > 0:
        print(f"\n  Total changes: {num_changed}/{len(data['tools'])}")

        if not dry_run:
            # Write back to file with pretty formatting
            with open(file_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
            print(f"  ✓ File updated")
        else:
            print(f"  (DRY RUN - no changes written)")
    else:
        print(f"\n  No changes needed")

    return num_changed, changes


def main():
    """Main entry point"""
    import argparse

    parser = argparse.ArgumentParser(description='Clean up tool product titles')
    parser.add_argument('--dry-run', action='store_true',
                        help='Show changes without writing files')
    parser.add_argument('--file', type=str,
                        help='Process single file instead of all')

    args = parser.parse_args()

    # Find tool JSON files
    tools_dir = Path(__file__).parent.parent.parent / 'Data' / 'Tools'

    if args.file:
        files = [Path(args.file)]
    else:
        files = sorted(tools_dir.glob('*_tools.json'))

    if not files:
        print("No tool JSON files found!")
        return 1

    print(f"Tool Title Cleanup Script")
    print(f"{'='*60}")
    if args.dry_run:
        print("DRY RUN MODE - No files will be modified")
    print(f"\nFound {len(files)} file(s) to process")

    total_changed = 0
    all_changes = []

    for file_path in files:
        num_changed, changes = process_tools_json(file_path, dry_run=args.dry_run)
        total_changed += num_changed
        all_changes.extend(changes)

    # Summary
    print(f"\n{'='*60}")
    print(f"SUMMARY")
    print(f"{'='*60}")
    print(f"Total files processed: {len(files)}")
    print(f"Total titles changed: {total_changed}")

    if args.dry_run and total_changed > 0:
        print(f"\nRe-run without --dry-run to apply changes")

    return 0


if __name__ == '__main__':
    sys.exit(main())

#!/usr/bin/env python3
"""
Quick test to demonstrate property tag extraction from descriptions.
"""

from color_extractor import combine_tags, extract_property_tags_from_description, extract_manufacturer_convention_tags

# Test cases
test_cases = [
    {
        'name': 'Blue Rod',
        'description': 'This is a striking color that reduces beautifully in the flame.',
        'url': 'https://example.com/blue-rod',
        'manufacturer': None,
        'expected': 'blue, reducing, striking'
    },
    {
        'name': 'Clear Glass',
        'description': 'Contains silver for beautiful effects.',
        'url': 'https://example.com/clear-silver',
        'manufacturer': None,
        'expected': 'clear, silver'
    },
    {
        'name': 'Purple Frit',
        'description': 'This amber purple color is fantastic!',
        'url': 'https://example.com/purple-frit',
        'manufacturer': None,
        'expected': 'amber-purple, purple'
    },
    {
        'name': 'Red Sheet',
        'description': 'This is a striking color! Really beautiful.',
        'url': 'https://example.com/red-sheet-false-positive',
        'manufacturer': None,
        'expected': 'red, striking (but might be false positive)'
    },
    {
        'name': 'Amazon Night 987',
        'description': 'A mysterious dark glass with complex colors.',
        'url': 'https://glassalchemy.com/products/amazon-night-987',
        'manufacturer': 'GA',
        'expected': 'green, striking (hard-coded override)'
    },
    {
        'name': 'Silver Glitter Rod',
        'description': 'Beautiful sparkly effects with glittery finish.',
        'url': 'https://example.com/silver-glitter',
        'manufacturer': None,
        'expected': 'gray, sparkle (detects both glitter and sparkle keywords)'
    },
    {
        'name': 'Passion Frit',
        'description': 'A beautiful reactive glass.',
        'url': 'https://glassalchemy.com/products/passion-frit',
        'manufacturer': 'GA',
        'expected': 'amber-purple (from GA naming convention)'
    },
    {
        'name': 'Purple Rod',
        'description': 'This glass reacts to UV light beautifully.',
        'url': 'https://example.com/uv-reactive',
        'manufacturer': None,
        'expected': 'purple, uv'
    },
    {
        'name': 'Clear Sculpture Base',
        'description': 'Perfect for sculpture work with no special properties.',
        'url': 'https://example.com/sculpture',
        'manufacturer': None,
        'expected': 'clear (should NOT detect uv from sculpture)'
    },
]

print("=" * 70)
print("PROPERTY TAG EXTRACTION TEST")
print("=" * 70)

for i, test in enumerate(test_cases, 1):
    print(f"\nTest {i}:")
    print(f"  Name: {test['name']}")
    print(f"  Description: {test['description']}")
    if test.get('manufacturer'):
        print(f"  Manufacturer: {test['manufacturer']}")
    print(f"  Expected: {test['expected']}")

    # Test property extraction only
    properties = extract_property_tags_from_description(test['description'])
    print(f"  Properties found: {properties}")

    # Test manufacturer convention extraction
    if test.get('manufacturer'):
        convention_tags = extract_manufacturer_convention_tags(test['name'], test['manufacturer'])
        if convention_tags:
            print(f"  Manufacturer conventions: {convention_tags}")

    # Test combined tags
    result = combine_tags(
        test['name'],
        test['description'],
        test['url'],
        test.get('manufacturer')
    )
    print(f"  Combined tags: {result}")

print("\n" + "=" * 70)
print("\nTo exclude false positives, add to tag_exclusions.txt:")
print("https://example.com/red-sheet-false-positive\tstriking")
print("\nTo hard-code specific tags, add to tag_overrides.txt:")
print("https://glassalchemy.com/products/amazon-night-987\tgreen")

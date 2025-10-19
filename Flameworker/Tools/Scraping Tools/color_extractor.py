"""
Color extraction utilities for glass product scrapers.
Extracts color tags from product names using color simplification mappings.
Also extracts technical property tags from descriptions (uv, cfl, striker, reducing, sparkle, luster).
"""

import re
import os


# Color simplification mappings - maps specific color names to base colors
COLOR_SIMPLIFICATIONS = {
    'lilac': ['purple', 'pink'],
    'lavender': ['purple', 'blue'],
    'mauve': ['purple', 'pink'],
    'violet': ['purple'],
    'indigo': ['purple', 'blue'],
    'magenta': ['purple', 'pink'],
    'amethyst': ['purple'],
    'plum': ['purple'],
    'hyacinth': ['purple', 'blue'],
    'blackberry': ['purple', 'black'],
    'boysenberry': ['purple', 'red'],
    'nightshade': ['purple', 'black'],
    
    'sky': ['blue'],
    'ocean': ['blue'],
    'oceanic': ['blue', 'green'],
    'cyan': ['blue', 'green'],
    'aqua': ['blue', 'green'],
    'agua': ['blue'],
    'teal': ['blue', 'green'],
    'turquoise': ['blue', 'green'],
    'cobalt': ['blue'],
    'navy': ['blue'],
    'sapphire': ['blue'],
    'glacier': ['blue', 'white'],
    'midnight': ['black', 'blue'],
    'periwinkle': ['blue', 'purple'],
    'caribbean': ['blue', 'green'],
    'neptune': ['blue', 'green'],
    'lapis': ['blue'],
    'ink': ['blue', 'black'],
    'petroleum': ['green', 'blue', 'black'],
    'lagoon': ['blue', 'green'],
    'denim': ['blue'],
    'azure': ['blue'],
    'teally': ['blue', 'green'],
    'atlantis': ['blue'],
    'dusk': ['purple', 'blue', 'black'],
    'peacock': ['blue', 'green'],
    'zen': ['blue', 'green'],
    
    'lime': ['green', 'yellow'],
    'mint': ['green'],
    'olive': ['green', 'brown'],
    'jade': ['green'],
    'emerald': ['green'],
    'spruce': ['green', 'blue'],
    'moss': ['green'],
    'absinthe': ['green'],
    'evergreen': ['green'],
    'forest': ['green'],
    'sage': ['green'],
    'grass': ['green'],
    'kelp': ['green', 'brown'],
    'avocado': ['green'],
    'pea': ['green'],
    'grasshopper': ['green'],
    'army': ['green'],
    'pine': ['green'],
    'pistachio': ['green'],
    'shamrock': ['green'],
    'chartreuse': ['green', 'yellow'],
    
    'canary': ['yellow'],
    'lemon': ['yellow'],
    'gold': ['yellow'],
    'amber': ['yellow', 'orange'],
    'topaz': ['yellow', 'orange'],
    'brass': ['yellow'],
    'goldenrod': ['yellow', 'orange'],
    'honey': ['yellow', 'orange'],
    'butterscotch': ['yellow', 'orange', 'brown'],
    'straw': ['yellow', 'brown'],
    'mustard': ['yellow', 'brown'],
    'mimosa': ['yellow'],
    'daffodil': ['yellow'],
    'banana': ['yellow'],
    'citron': ['yellow', 'green'],
    
    'caramel': ['yellow', 'brown', 'orange'],
    'apricot': ['orange', 'yellow'],
    
    'peach': ['orange', 'pink'],
    'coral': ['orange', 'pink'],
    'salmon': ['orange', 'pink'],
    'canyon': ['orange', 'brown', 'red'],
    'pumpkin': ['orange'],
    'carrot': ['orange'],
    'persimmon': ['orange', 'red'],
    'flamingo': ['pink', 'orange'],
    'ketchup': ['red', 'orange'],
    
    'crimson': ['red'],
    'scarlet': ['red'],
    'ruby': ['red'],
    'maroon': ['red', 'brown'],
    'burgundy': ['red', 'purple'],
    'rose': ['red', 'pink'],
    'lava': ['red', 'orange'],
    'pomegranate': ['red'],
    'garnet': ['red'],
    'poppy': ['red'],
    'cherry': ['red'],
    'bubblegum': ['pink'],
    'blush': ['pink'],
    'raspberry': ['red', 'pink'],
    'passion': ['red', 'purple'],
    'blood': ['red'],
    
    'tan': ['brown', 'orange', 'yellow'],
    'beige': ['brown', 'yellow'],
    'ochre': ['brown', 'orange', 'yellow'],
    'sienna': ['brown', 'red', 'orange'],
    'umber': ['brown'],
    'bronze': ['brown', 'orange'],
    'copper': ['brown', 'orange', 'red'],
    'timber': ['brown'],
    'sandstorm': ['brown', 'orange', 'yellow'],
    'rootbeer': ['brown'],
    'sand': ['brown', 'yellow'],
    'cocoa': ['brown'],
    'walnut': ['brown'],
    'chocolate': ['brown'],
    
    'cream': ['white', 'yellow'],
    'ivory': ['white', 'yellow'],
    'pearl': ['white'],
    'ghost': ['white'],
    'alabaster': ['white'],
    'vanilla': ['white', 'yellow'],
    
    'silver': ['gray'],
    'charcoal': ['black', 'gray'],
    'ebony': ['black'],
    'onyx': ['black'],
    'jet': ['black'],
    'raven': ['black'],
    'eclipse': ['black'],
    
    'slate': ['gray', 'blue'],
    'nimbus': ['gray', 'white'],
    'gray': ['gray'],
    'grey': ['gray'],
    'portland': ['gray'],
    
    'multi': ['multicolored'],
    'irrid': ['multicolored'],
    'starry': ['multicolored', 'blue'],
    'twilight': ['multicolored', 'purple'],
    'sunrise': ['multicolored', 'orange', 'yellow'],
    'plasma': ['multicolored'],
    'serum': ['multicolored'],
}

# Unique colors that don't map to other colors
UNIQUE_COLORS = [
    'pink', 'clear', 'multicolored'
]

# Base color names
BASE_COLORS = [
    'red', 'blue', 'green', 'yellow', 'orange', 'purple',
    'brown', 'black', 'white', 'gray', 'grey'
]

# Technical property tags to extract from descriptions
TECHNICAL_PROPERTIES = {
    'reducing': [
        r'\breducing\b',
        r'\breduc[ei](?:s|d)?\b',  # reduce, reduces, reduced, reduci
        r'\breduction\b',
    ],
    'striker': [
        r'\bstriking\b',
        r'\bstriker\b',
        r'\bstrike(?:s|d)?\b',  # strike, strikes, struck
    ],
    'silver': [
        r'\bsilver\s+(?:glass|fume|fuming|leaf)\b',  # "silver glass", "silver fume", etc.
        r'\bcontains?\s+silver\b',  # "contains silver"
        r'\bwith\s+silver\b',  # "with silver"
        r'\bsilvered\b',  # "silvered"
    ],
    'amber-purple': [
        r'\bamber[\s\-/]purple\b',  # "amber purple", "amber-purple", "amber/purple"
        r'\bamberpurple\b',  # "amberpurple" (no space)
    ],
    'sparkle': [
        r'\bglitter(?:y|ing|s)?\b',  # glitter, glittery, glittering, glitters
        r'\bsparkle(?:s|d)?\b',  # sparkle, sparkles, sparkled
        r'\bsparkl(?:ey|y)\b',  # sparkley (misspelling), sparkly (correct)
        r'\bshimmer(?:y|ing|s)?\b',  # shimmer, shimmery, shimmering
    ],
    'uv': [
        r'\buv\b',  # UV as a standalone word (case-insensitive)
        r'\bultraviolet\b',
        r'\bblack\s+light\b',
        r'\bblacklight\b',
    ],
    'cfl': [
        r'\bcfl\b',  # CFL as a standalone word
        r'\bfluorescent\s+light\b',
        r'\bfluorescent\s+lighting\b',
        r'\bfluorescen[ct]e?\b',  # fluorescent, fluorescence
        r'\bcolor[\s-]?chang(?:e|es|ing)\s+(?:under|in)\s+fluorescent\b',
    ],
    'luster': [
        r'\bluster\b',  # luster
        r'\bmetallic\b',  # metallic
        r'\bmetal(?:s|lic)?\b',  # metal, metals, metallic
        r'\biridescen[ct]e?\b',  # iridescent, iridescence
    ],
}

TAG_EXCLUSIONS_FILE = "tag_exclusions.txt"
TAG_OVERRIDES_FILE = "tag_overrides.txt"

# Manufacturer-specific naming conventions
# Maps manufacturer code to product name patterns and their associated tags
MANUFACTURER_NAMING_CONVENTIONS = {
    'GA': {  # Glass Alchemy
        'passion': ['amber-purple'],  # Products with "passion" in name are amber-purple
    },
}


def extract_tags_from_name(product_name):
    """
    Extract color tags from product name.
    
    Args:
        product_name: The product name to extract colors from
        
    Returns:
        A comma-separated string of quoted color tags (e.g., '"blue", "green"')
        or '"unknown"' if no colors are found
    """
    name_lower = product_name.lower()
    found_colors = set()
    
    # Use word boundaries to match complete words only
    for specific_color, base_color_list in COLOR_SIMPLIFICATIONS.items():
        pattern = r'\b' + re.escape(specific_color) + r'\b'
        if re.search(pattern, name_lower):
            for base_color in base_color_list:
                found_colors.add(base_color)
    
    for color in UNIQUE_COLORS:
        pattern = r'\b' + re.escape(color) + r'\b'
        if re.search(pattern, name_lower):
            found_colors.add(color)
    
    for color in BASE_COLORS:
        pattern = r'\b' + re.escape(color) + r'\b'
        if re.search(pattern, name_lower) and color not in found_colors:
            found_colors.add(color)
    
    if found_colors:
        tags = [f'"{color}"' for color in sorted(found_colors)]
        return ', '.join(tags)
    else:
        return '"unknown"'


def get_color_simplifications():
    """
    Get the color simplification dictionary.
    
    Returns:
        Dictionary mapping specific color names to lists of base colors
    """
    return COLOR_SIMPLIFICATIONS.copy()


def get_unique_colors():
    """
    Get the list of unique colors.
    
    Returns:
        List of unique color names
    """
    return UNIQUE_COLORS.copy()


def get_base_colors():
    """
    Get the list of base colors.

    Returns:
        List of base color names
    """
    return BASE_COLORS.copy()


def _load_tag_exclusions():
    """
    Load tag exclusion mappings from file.

    Returns:
        Dictionary mapping URLs to sets of excluded tag names
    """
    exclusions = {}
    if os.path.exists(TAG_EXCLUSIONS_FILE):
        with open(TAG_EXCLUSIONS_FILE, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                # Skip comments and empty lines
                if line and not line.startswith('#'):
                    parts = line.split('\t')
                    if len(parts) == 2:
                        url, tags = parts
                        # Parse comma-separated tags into a set
                        excluded_tags = {tag.strip() for tag in tags.split(',')}
                        exclusions[url] = excluded_tags
    return exclusions


def _load_tag_overrides():
    """
    Load tag override mappings from file.

    Returns:
        Dictionary mapping URLs to sets of hard-coded tag names
    """
    overrides = {}
    if os.path.exists(TAG_OVERRIDES_FILE):
        with open(TAG_OVERRIDES_FILE, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                # Skip comments and empty lines
                if line and not line.startswith('#'):
                    parts = line.split('\t')
                    if len(parts) == 2:
                        url, tags = parts
                        # Parse comma-separated tags into a set
                        override_tags = {tag.strip() for tag in tags.split(',')}
                        overrides[url] = override_tags
    return overrides


def extract_property_tags_from_description(description):
    """
    Extract technical property tags from product description.

    Args:
        description: The product description text

    Returns:
        Set of property tag names found in the description
    """
    if not description:
        return set()

    desc_lower = description.lower()
    found_properties = set()

    for property_name, patterns in TECHNICAL_PROPERTIES.items():
        for pattern in patterns:
            if re.search(pattern, desc_lower, re.IGNORECASE):
                found_properties.add(property_name)
                break  # Found this property, no need to check other patterns

    return found_properties


def extract_manufacturer_convention_tags(product_name, manufacturer_code):
    """
    Extract tags based on manufacturer-specific naming conventions.

    Args:
        product_name: The product name
        manufacturer_code: The manufacturer code (e.g., 'GA', 'BB', 'DH')

    Returns:
        Set of tag names based on manufacturer naming conventions
    """
    if not product_name or not manufacturer_code:
        return set()

    found_tags = set()
    name_lower = product_name.lower()

    # Check if this manufacturer has naming conventions
    if manufacturer_code in MANUFACTURER_NAMING_CONVENTIONS:
        conventions = MANUFACTURER_NAMING_CONVENTIONS[manufacturer_code]

        # Check each naming pattern
        for pattern, tags in conventions.items():
            if re.search(r'\b' + re.escape(pattern) + r'\b', name_lower):
                found_tags.update(tags)

    return found_tags


def combine_tags(product_name, description, manufacturer_url=None, manufacturer_code=None):
    """
    Combine color tags from name and property tags from description.
    Respects tag overrides (hard-coded tags), manufacturer naming conventions, and tag exclusions.

    Args:
        product_name: The product name to extract colors from
        description: The product description to extract properties from
        manufacturer_url: Optional URL to check for tag overrides/exclusions
        manufacturer_code: Optional manufacturer code (e.g., 'GA', 'BB') for naming conventions

    Returns:
        A comma-separated string of quoted tags (e.g., '"blue", "striking"')
        or '"unknown"' if no tags are found
    """
    # Check for hard-coded tag overrides first
    if manufacturer_url:
        overrides = _load_tag_overrides()
        if manufacturer_url in overrides:
            # Use override tags instead of auto-detection
            override_tags = overrides[manufacturer_url]
            if override_tags:
                tags = [f'"{tag}"' for tag in sorted(override_tags)]
                return ', '.join(tags)
            else:
                return '"unknown"'

    all_tags = set()

    # Extract color tags from name
    color_tags_str = extract_tags_from_name(product_name)
    if color_tags_str != '"unknown"':
        # Parse the quoted tags back into a set
        # Input format: '"blue", "green"' -> {'blue', 'green'}
        color_tags = {tag.strip('"') for tag in color_tags_str.replace('"', '').split(', ')}
        all_tags.update(color_tags)

    # Extract property tags from description
    property_tags = extract_property_tags_from_description(description)
    all_tags.update(property_tags)

    # Extract manufacturer-specific naming convention tags
    if manufacturer_code:
        convention_tags = extract_manufacturer_convention_tags(product_name, manufacturer_code)
        all_tags.update(convention_tags)

    # Apply exclusions if URL is provided
    if manufacturer_url:
        exclusions = _load_tag_exclusions()
        if manufacturer_url in exclusions:
            excluded_tags = exclusions[manufacturer_url]
            all_tags -= excluded_tags  # Remove excluded tags

    # Format and return
    if all_tags:
        tags = [f'"{tag}"' for tag in sorted(all_tags)]
        return ', '.join(tags)
    else:
        return '"unknown"'

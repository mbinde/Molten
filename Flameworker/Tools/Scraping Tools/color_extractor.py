"""
Color extraction utilities for glass product scrapers.
Extracts color tags from product names using color simplification mappings.
"""

import re


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
    'gold': ['yellow', 'orange'],
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

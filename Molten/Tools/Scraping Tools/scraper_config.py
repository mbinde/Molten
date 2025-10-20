"""
Scraper Configuration
=====================

Centralized configuration for all manufacturer scrapers.
Manages rate limiting delays, retry logic, and bot protection handling.
"""

# Default rate limiting delays (in seconds)
# These delays are used for parallel scraping to be respectful to servers
DEFAULT_DELAY_BETWEEN_PAGES = 0.5      # Between category/list pages
DEFAULT_DELAY_BETWEEN_PRODUCTS = 0.5   # Between individual product pages
DEFAULT_IMAGE_DOWNLOAD_DELAY = 1.0     # Between image downloads

# Manufacturer-specific delay overrides
# Some sites have bot protection or stricter rate limiting requirements
MANUFACTURER_DELAYS = {
    # Sites with known bot protection (use longer delays)
    'GAF': {  # Gaffer Glass (via E.B. Batch Color)
        'page_delay': 1.0,
        'product_delay': 1.0,
        'reason': 'Site has bot protection (HTTP 403)'
    },
    'UST': {  # UST Glass
        'page_delay': 1.0,
        'product_delay': 1.0,
        'reason': 'Site has bot protection (HTTP 406)'
    },
}

# HTTP error codes that indicate bot protection
BOT_PROTECTION_ERROR_CODES = [403, 406, 429]

# Error messages that indicate bot protection
BOT_PROTECTION_ERROR_MESSAGES = [
    'forbidden',
    'not acceptable',
    'too many requests',
    'rate limit',
    'blocked',
]


def get_page_delay(manufacturer_code):
    """
    Get the appropriate delay between page requests for a manufacturer.

    Args:
        manufacturer_code: Manufacturer code (e.g., 'GAF', 'UST', 'BE')

    Returns:
        float: Delay in seconds
    """
    if manufacturer_code in MANUFACTURER_DELAYS:
        return MANUFACTURER_DELAYS[manufacturer_code].get('page_delay', DEFAULT_DELAY_BETWEEN_PAGES)
    return DEFAULT_DELAY_BETWEEN_PAGES


def get_product_delay(manufacturer_code):
    """
    Get the appropriate delay between product requests for a manufacturer.

    Args:
        manufacturer_code: Manufacturer code (e.g., 'GAF', 'UST', 'BE')

    Returns:
        float: Delay in seconds
    """
    if manufacturer_code in MANUFACTURER_DELAYS:
        return MANUFACTURER_DELAYS[manufacturer_code].get('product_delay', DEFAULT_DELAY_BETWEEN_PRODUCTS)
    return DEFAULT_DELAY_BETWEEN_PRODUCTS


def get_image_download_delay():
    """
    Get the delay between image downloads.

    Returns:
        float: Delay in seconds
    """
    return DEFAULT_IMAGE_DOWNLOAD_DELAY


def is_bot_protection_error(error):
    """
    Check if an error indicates bot protection.

    Args:
        error: Exception object (typically urllib.error.HTTPError)

    Returns:
        bool: True if this looks like bot protection
    """
    # Check HTTP error codes
    if hasattr(error, 'code') and error.code in BOT_PROTECTION_ERROR_CODES:
        return True

    # Check error message
    error_msg = str(error).lower()
    for msg in BOT_PROTECTION_ERROR_MESSAGES:
        if msg in error_msg:
            return True

    return False


def get_delay_reason(manufacturer_code):
    """
    Get the reason for a manufacturer's custom delay (for logging).

    Args:
        manufacturer_code: Manufacturer code

    Returns:
        str: Reason for custom delay, or empty string if using default
    """
    if manufacturer_code in MANUFACTURER_DELAYS:
        return MANUFACTURER_DELAYS[manufacturer_code].get('reason', '')
    return ''

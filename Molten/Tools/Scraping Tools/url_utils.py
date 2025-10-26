"""
URL utilities for cleaning manufacturer URLs
"""

from urllib.parse import urlparse, urlunparse, parse_qs, urlencode


def clean_manufacturer_url(url):
    """
    Clean manufacturer URL by removing tracking and analytics parameters.

    Removes common tracking parameters while preserving product-specific ones:
    - Removes: _pos, _fid, _ss (search/filter tracking)
    - Keeps: variant (product-specific, often needed)

    Args:
        url: URL string to clean

    Returns:
        Cleaned URL string with tracking params removed

    Examples:
        >>> clean_manufacturer_url("https://example.com/product?_pos=1&_fid=abc&variant=123")
        'https://example.com/product?variant=123'

        >>> clean_manufacturer_url("https://example.com/product")
        'https://example.com/product'
    """
    if not url:
        return url

    # Parse URL into components
    parsed = urlparse(url)

    # If there are no query parameters, return as-is
    if not parsed.query:
        return url

    # Parse query parameters
    params = parse_qs(parsed.query, keep_blank_values=True)

    # List of tracking parameters to remove
    tracking_params = {
        '_pos',      # Position in search results
        '_fid',      # Filter ID
        '_sid',      # Session ID
        '_ss',       # Search session
        'fbclid',    # Facebook click ID
        'gclid',     # Google click ID
        'utm_source',
        'utm_medium',
        'utm_campaign',
        'utm_term',
        'utm_content',
        'mc_cid',    # Mailchimp campaign ID
        'mc_eid',    # Mailchimp email ID
    }

    # Remove tracking parameters
    cleaned_params = {k: v for k, v in params.items() if k not in tracking_params}

    # If no params left, return URL without query string
    if not cleaned_params:
        return urlunparse((
            parsed.scheme,
            parsed.netloc,
            parsed.path,
            parsed.params,
            '',  # Empty query
            parsed.fragment
        ))

    # Rebuild query string
    # Use first value for each parameter (parse_qs returns lists)
    cleaned_query = urlencode({k: v[0] for k, v in cleaned_params.items()})

    # Rebuild URL
    return urlunparse((
        parsed.scheme,
        parsed.netloc,
        parsed.path,
        parsed.params,
        cleaned_query,
        parsed.fragment
    ))

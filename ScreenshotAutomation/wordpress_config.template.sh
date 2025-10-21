#!/bin/bash

# WordPress.com Configuration Template
# Copy this file to wordpress_config.sh and fill in your credentials
# IMPORTANT: wordpress_config.sh is in .gitignore - it will NOT be committed to git

# Your WordPress.com site URL (without trailing slash)
WP_SITE_URL="https://moltenglass.app"

# Your WordPress.com username (email or username)
WP_USERNAME="your-username-here"

# Your WordPress.com Application Password
# Get this from: https://wordpress.com/me/security/application-passwords
# Create a new password named "Molten Screenshot Automation"
WP_APP_PASSWORD="your-application-password-here"

# Page IDs to update (find these in WordPress admin URL when editing pages)
WP_HOMEPAGE_ID=""  # e.g., "123"
WP_FEATURES_PAGE_ID=""  # e.g., "456"

# Optional: Social media configuration (for future use)
TWITTER_ENABLED=false
INSTAGRAM_ENABLED=false

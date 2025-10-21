#!/bin/bash

# Test WordPress.com API connection
# Verifies that credentials work and API is accessible

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_FILE="$SCRIPT_DIR/wordpress_config.sh"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}     WordPress Connection Test${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# Load configuration
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}❌ Configuration file not found!${NC}"
    echo ""
    echo "Please run setup first:"
    echo "  ./setup_wordpress.sh"
    echo ""
    exit 1
fi

source "$CONFIG_FILE"

# Verify required variables are set
if [ -z "$WP_USERNAME" ] || [ -z "$WP_APP_PASSWORD" ]; then
    echo -e "${RED}❌ Configuration incomplete!${NC}"
    echo ""
    echo "WP_USERNAME or WP_APP_PASSWORD not set in $CONFIG_FILE"
    exit 1
fi

echo -e "${YELLOW}Testing connection to: $WP_SITE_URL${NC}"
echo ""

# Test 1: Get site info
echo -e "${BLUE}Test 1: Fetching site information...${NC}"

response=$(curl -s -w "\n%{http_code}" \
    -u "$WP_USERNAME:$WP_APP_PASSWORD" \
    "$WP_SITE_URL/wp-json/wp/v2/")

http_code=$(echo "$response" | tail -n 1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✅ Successfully connected to WordPress REST API${NC}"

    # Parse site info
    site_name=$(echo "$body" | grep -o '"name":"[^"]*' | head -1 | cut -d'"' -f4)
    site_desc=$(echo "$body" | grep -o '"description":"[^"]*' | head -1 | cut -d'"' -f4)

    echo -e "${GREEN}   Site: $site_name${NC}"
    echo -e "${GREEN}   Description: $site_desc${NC}"
else
    echo -e "${RED}❌ Connection failed (HTTP $http_code)${NC}"
    echo ""
    echo "Response:"
    echo "$body" | head -20
    exit 1
fi

echo ""

# Test 2: Check media upload permissions
echo -e "${BLUE}Test 2: Checking media upload permissions...${NC}"

response=$(curl -s -w "\n%{http_code}" \
    -u "$WP_USERNAME:$WP_APP_PASSWORD" \
    "$WP_SITE_URL/wp-json/wp/v2/media")

http_code=$(echo "$response" | tail -n 1)

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✅ Media library accessible${NC}"

    media_count=$(echo "$response" | sed '$d' | grep -o '"id":' | wc -l | tr -d ' ')
    echo -e "${GREEN}   Found $media_count existing media items${NC}"
else
    echo -e "${RED}❌ Cannot access media library (HTTP $http_code)${NC}"
    exit 1
fi

echo ""

# Test 3: Check pages access
echo -e "${BLUE}Test 3: Checking pages access...${NC}"

response=$(curl -s -w "\n%{http_code}" \
    -u "$WP_USERNAME:$WP_APP_PASSWORD" \
    "$WP_SITE_URL/wp-json/wp/v2/pages")

http_code=$(echo "$response" | tail -n 1)

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✅ Pages accessible${NC}"

    pages_count=$(echo "$response" | sed '$d' | grep -o '"id":' | wc -l | tr -d ' ')
    echo -e "${GREEN}   Found $pages_count pages${NC}"

    # Show first few pages
    echo ""
    echo -e "${YELLOW}   Your pages:${NC}"
    echo "$response" | sed '$d' | grep -o '"id":[0-9]*,"title":{"rendered":"[^"]*' | \
        sed 's/"id":/   ID /' | sed 's/,"title":{"rendered":"/ - /' | head -5
else
    echo -e "${RED}❌ Cannot access pages (HTTP $http_code)${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ All tests passed!${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""
echo "Your WordPress connection is working correctly."
echo ""
echo "Next step: Generate and publish screenshots"
echo "  ./publish_screenshots.sh"
echo ""

#!/bin/bash

# Complete screenshot generation and WordPress publishing pipeline
# This script:
#   1. Generates screenshots from Xcode UI tests
#   2. Uploads them to WordPress media library
#   3. Optionally updates website pages with new images

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="/Users/binde/Library/Mobile Documents/com~apple~CloudDocs/Molten"
CONFIG_FILE="$SCRIPT_DIR/wordpress_config.sh"
SCREENSHOTS_DIR="$PROJECT_DIR/Screenshots"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                   ║${NC}"
echo -e "${BLUE}║     📸 MOLTEN SCREENSHOT PUBLISHER 📸             ║${NC}"
echo -e "${BLUE}║                                                   ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

# Load WordPress configuration
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}❌ WordPress configuration not found!${NC}"
    echo "Please run: ./setup_wordpress.sh"
    exit 1
fi

source "$CONFIG_FILE"

# Parse command line options
SKIP_GENERATION=false
UPLOAD_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-generation)
            SKIP_GENERATION=true
            shift
            ;;
        --upload-only)
            UPLOAD_ONLY=true
            SKIP_GENERATION=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--skip-generation] [--upload-only]"
            exit 1
            ;;
    esac
done

# Step 1: Generate Screenshots (unless skipped)
if [ "$SKIP_GENERATION" = false ]; then
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Step 1: Generating screenshots from Xcode tests...${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Run the screenshot generation script
    cd "$SCRIPT_DIR"
    if [ -f "./generate_screenshots.sh" ]; then
        ./generate_screenshots.sh
    else
        echo -e "${YELLOW}⚠️  generate_screenshots.sh not found, running tests directly...${NC}"

        # Run tests directly
        xcodebuild \
            -project "$PROJECT_DIR/Molten.xcodeproj" \
            -scheme "Molten" \
            -destination "platform=iOS Simulator,name=iPhone 15 Pro" \
            -only-testing:ScreenshotAutomation/ScreenshotAutomation/testGenerateMarketingScreenshots \
            test || {
                echo -e "${RED}❌ Screenshot generation failed${NC}"
                exit 1
            }
    fi
else
    echo -e "${YELLOW}⏭️  Skipping screenshot generation (using existing screenshots)${NC}"
    echo ""
fi

# Verify screenshots exist
if [ ! -d "$SCREENSHOTS_DIR" ] || [ -z "$(ls -A "$SCREENSHOTS_DIR" 2>/dev/null)" ]; then
    echo -e "${RED}❌ No screenshots found in $SCREENSHOTS_DIR${NC}"
    echo "Please generate screenshots first or check the path."
    exit 1
fi

screenshot_count=$(find "$SCREENSHOTS_DIR" -name "*.png" | wc -l | tr -d ' ')
echo -e "${GREEN}✅ Found $screenshot_count screenshots to upload${NC}"
echo ""

# Step 2: Upload Screenshots to WordPress
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Step 2: Uploading screenshots to WordPress...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Array to store uploaded media IDs
declare -a MEDIA_IDS=()
declare -a MEDIA_URLS=()

# Upload each screenshot
for screenshot in "$SCREENSHOTS_DIR"/*.png; do
    if [ -f "$screenshot" ]; then
        filename=$(basename "$screenshot")
        echo -e "${YELLOW}📤 Uploading: $filename${NC}"

        # Upload to WordPress media library
        response=$(curl -s -w "\n%{http_code}" \
            -u "$WP_USERNAME:$WP_APP_PASSWORD" \
            -F "file=@$screenshot" \
            "$WP_SITE_URL/wp-json/wp/v2/media")

        http_code=$(echo "$response" | tail -n 1)
        body=$(echo "$response" | sed '$d')

        if [ "$http_code" = "201" ]; then
            # Extract media ID and URL from response
            media_id=$(echo "$body" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
            media_url=$(echo "$body" | grep -o '"source_url":"[^"]*' | head -1 | cut -d'"' -f4)

            MEDIA_IDS+=("$media_id")
            MEDIA_URLS+=("$media_url")

            echo -e "${GREEN}   ✅ Uploaded (ID: $media_id)${NC}"
        else
            echo -e "${RED}   ❌ Upload failed (HTTP $http_code)${NC}"
            echo "   Response: $body" | head -3
        fi

        # Rate limiting - be nice to WordPress
        sleep 1
    fi
done

uploaded_count=${#MEDIA_IDS[@]}
echo ""
echo -e "${GREEN}✅ Uploaded $uploaded_count screenshots successfully${NC}"
echo ""

# Step 3: Update Website Pages (optional for now)
if [ "$UPLOAD_ONLY" = false ]; then
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Step 3: Updating website pages...${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    echo -e "${YELLOW}📝 Media IDs for manual page editing:${NC}"
    for i in "${!MEDIA_IDS[@]}"; do
        echo "   ${MEDIA_IDS[$i]} - ${MEDIA_URLS[$i]}"
    done
    echo ""

    echo -e "${YELLOW}💡 Tip: Copy these URLs to use in your WordPress page editor${NC}"
    echo ""
fi

# Summary
echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                   ║${NC}"
echo -e "${BLUE}║              ✅ PUBLISH COMPLETE ✅                ║${NC}"
echo -e "${BLUE}║                                                   ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Summary:${NC}"
echo -e "  📸 Screenshots generated: $screenshot_count"
echo -e "  ☁️  Uploaded to WordPress: $uploaded_count"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Visit https://moltenglass.app/wp-admin/upload.php"
echo "  2. View your newly uploaded screenshots"
echo "  3. Add them to your pages using the WordPress editor"
echo ""
echo -e "${BLUE}Or run with --upload-only to skip screenshot generation:${NC}"
echo "  ./publish_screenshots.sh --upload-only"
echo ""

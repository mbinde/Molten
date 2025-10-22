#!/bin/bash

# Extract screenshots from .xcresult bundle using xcresulttool
# Modern approach that works with Xcode 15+

set -e

PROJECT_DIR="/Users/binde/Library/Mobile Documents/com~apple~CloudDocs/Molten"
OUTPUT_DIR="$PROJECT_DIR/Screenshots"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     📸 SCREENSHOT EXTRACTOR V2 📸                 ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

# Find Derived Data folder for Molten project
DERIVED_DATA=$(find ~/Library/Developer/Xcode/DerivedData -name "Molten-*" -type d -maxdepth 1 2>/dev/null | head -1)

if [ -z "$DERIVED_DATA" ]; then
    echo -e "${RED}❌ Could not find Molten Derived Data folder${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Found Derived Data: $DERIVED_DATA${NC}"

# Find the most recent .xcresult bundle
XCRESULT=$(find "$DERIVED_DATA/Logs/Test" -name "*.xcresult" -type d 2>/dev/null | head -1)

if [ -z "$XCRESULT" ]; then
    echo -e "${RED}❌ No .xcresult bundle found${NC}"
    echo "Run the screenshot tests in Xcode first (⌘+U)"
    exit 1
fi

echo -e "${GREEN}✅ Found test results: $(basename "$XCRESULT")${NC}"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo -e "${BLUE}🔍 Extracting screenshots...${NC}"
echo ""

# List all files in the xcresult bundle to find screenshots
# Screenshots are stored with specific reference IDs
# We'll use xcresulttool to get the manifest first

# Get the test reference
TEST_REF=$(xcrun xcresulttool get --legacy --format json --path "$XCRESULT" 2>/dev/null | \
    python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    # Navigate to find test references
    actions = data.get('actions', {}).get('_values', [])
    for action in actions:
        test_ref = action.get('actionResult', {}).get('testsRef', {}).get('id', {}).get('_value', '')
        if test_ref:
            print(test_ref)
            break
except:
    pass
" 2>/dev/null)

if [ -z "$TEST_REF" ]; then
    echo -e "${YELLOW}⚠️  Could not extract test reference automatically${NC}"
    echo ""
    echo -e "${BLUE}📂 Trying direct file search in bundle...${NC}"

    # Look for PNG files directly in the bundle
    screenshots=$(find "$XCRESULT" -name "*.png" -type f 2>/dev/null)
    count=0

    while IFS= read -r screenshot; do
        if [ -f "$screenshot" ]; then
            ((count++))
            output_name=$(printf "screenshot-%02d.png" $count)
            cp "$screenshot" "$OUTPUT_DIR/$output_name"
            echo -e "  ${GREEN}✓${NC} Extracted: $output_name"
        fi
    done <<< "$screenshots"

    if [ "$count" -eq 0 ]; then
        echo -e "${RED}❌ No PNG files found in bundle${NC}"
        echo ""
        echo "The tests may not have captured any screenshots yet."
        echo "Try running the tests again and make sure they complete successfully."
        exit 1
    fi

    echo ""
    echo -e "${GREEN}✅ Extracted $count screenshots${NC}"
else
    echo -e "${GREEN}✅ Found test reference: $TEST_REF${NC}"

    # Try to extract attachments using the test reference
    # This is more complex but would preserve better naming

    # For now, fall back to direct file search
    screenshots=$(find "$XCRESULT" -name "*.png" -type f 2>/dev/null)
    count=0

    while IFS= read -r screenshot; do
        if [ -f "$screenshot" ]; then
            ((count++))
            # Try to extract a meaningful name from the path
            # Paths often contain the attachment name
            basename_only=$(basename "$screenshot" .png)

            # If the basename contains "Screenshot" or similar, use it
            if [[ "$basename_only" == *"Screenshot"* ]] || [[ "$basename_only" == *"screenshot"* ]]; then
                output_name=$(printf "screenshot-%02d.png" $count)
            else
                output_name="${basename_only}.png"
            fi

            cp "$screenshot" "$OUTPUT_DIR/$output_name"
            echo -e "  ${GREEN}✓${NC} Extracted: $output_name"
        fi
    done <<< "$screenshots"

    echo ""
    echo -e "${GREEN}✅ Extracted $count screenshots${NC}"
fi

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              ✅ EXTRACTION COMPLETE ✅             ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}📂 Screenshots saved to:${NC}"
echo "   $OUTPUT_DIR"
echo ""
echo -e "${YELLOW}💡 Next steps:${NC}"
echo "  1. Review screenshots: open \"$OUTPUT_DIR\""
echo "  2. Upload to WordPress: cd ScreenshotAutomation && ./publish_screenshots.sh --skip-generation"
echo ""

#!/bin/bash

# Extract screenshots from Xcode test results to Screenshots/ folder
# This finds the latest test run and copies all screenshot attachments

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="/Users/binde/Library/Mobile Documents/com~apple~CloudDocs/Molten"
OUTPUT_DIR="$PROJECT_DIR/Screenshots"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                   ║${NC}"
echo -e "${BLUE}║     📸 SCREENSHOT EXTRACTOR 📸                    ║${NC}"
echo -e "${BLUE}║                                                   ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

# Find Derived Data folder for Molten project
DERIVED_DATA=$(find ~/Library/Developer/Xcode/DerivedData -name "Molten-*" -type d -maxdepth 1 2>/dev/null | head -1)

if [ -z "$DERIVED_DATA" ]; then
    echo -e "${RED}❌ Could not find Molten Derived Data folder${NC}"
    echo ""
    echo "Make sure you've run the tests at least once in Xcode."
    echo "Location should be: ~/Library/Developer/Xcode/DerivedData/Molten-*/"
    exit 1
fi

echo -e "${GREEN}✅ Found Derived Data: $DERIVED_DATA${NC}"
echo ""

# Find test attachments folder
ATTACHMENTS_DIR="$DERIVED_DATA/Logs/Test/Attachments"

if [ ! -d "$ATTACHMENTS_DIR" ]; then
    echo -e "${RED}❌ No test attachments found${NC}"
    echo ""
    echo "Run the screenshot tests first in Xcode:"
    echo "  Product → Test (⌘+U)"
    exit 1
fi

# Find all PNG screenshots
echo -e "${BLUE}🔍 Searching for screenshots...${NC}"
screenshots=$(find "$ATTACHMENTS_DIR" -name "*.png" -type f 2>/dev/null)
screenshot_count=$(echo "$screenshots" | grep -c "png" || echo "0")

if [ "$screenshot_count" -eq 0 ]; then
    echo -e "${RED}❌ No PNG screenshots found${NC}"
    echo ""
    echo "Screenshots location: $ATTACHMENTS_DIR"
    echo "Make sure the tests completed successfully."
    exit 1
fi

echo -e "${GREEN}✅ Found $screenshot_count screenshots${NC}"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Copy screenshots with better naming
echo -e "${BLUE}📁 Copying screenshots to: $OUTPUT_DIR${NC}"
echo ""

counter=1
while IFS= read -r screenshot; do
    if [ -f "$screenshot" ]; then
        # Extract filename
        filename=$(basename "$screenshot")

        # Try to find a better name from parent directory structure
        # Screenshots often have names like "Screenshot_<UUID>.png"
        # We can look at the test case name in the path

        # For now, use sequential numbering
        new_name=$(printf "screenshot-%02d.png" $counter)

        cp "$screenshot" "$OUTPUT_DIR/$new_name"
        echo -e "  ${GREEN}✓${NC} Copied: $new_name"

        ((counter++))
    fi
done <<< "$screenshots"

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                   ║${NC}"
echo -e "${BLUE}║              ✅ EXTRACTION COMPLETE ✅             ║${NC}"
echo -e "${BLUE}║                                                   ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}📊 Summary:${NC}"
echo -e "  Screenshots extracted: $screenshot_count"
echo -e "  Output directory: $OUTPUT_DIR"
echo ""
echo -e "${YELLOW}💡 Next steps:${NC}"
echo "  1. Review screenshots: open $OUTPUT_DIR"
echo "  2. Rename with descriptive names if needed"
echo "  3. Upload to WordPress: ./publish_screenshots.sh --skip-generation"
echo ""

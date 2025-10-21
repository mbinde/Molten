#!/bin/bash

# generate_screenshots.sh
# Automated screenshot generation for Molten app
# Generates screenshots for marketing, App Store, and documentation

set -e  # Exit on error

# Configuration
PROJECT_DIR="/Users/binde/Library/Mobile Documents/com~apple~CloudDocs/Molten"
SCHEME="Molten"
TEST_PLAN="ScreenshotAutomation"
OUTPUT_DIR="$PROJECT_DIR/Screenshots"
DERIVED_DATA_DIR="$PROJECT_DIR/.screenshot-derived-data"

# Device configurations for screenshots
declare -a DEVICES=(
    "iPhone 15 Pro"
    "iPhone SE (3rd generation)"
    "iPad Pro (12.9-inch) (6th generation)"
)

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                   ║${NC}"
echo -e "${BLUE}║     📸 MOLTEN SCREENSHOT GENERATOR 📸             ║${NC}"
echo -e "${BLUE}║                                                   ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Function to run tests for a specific device
run_screenshots_for_device() {
    local device_name="$1"
    local appearance="${2:-light}"  # light or dark

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}📱 Generating screenshots for: ${device_name}${NC}"
    echo -e "${GREEN}🎨 Appearance: ${appearance}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Clean device name for folder (remove spaces and special chars)
    local device_folder=$(echo "$device_name" | tr ' ' '-' | tr '(' '-' | tr ')' '-' | sed 's/--/-/g')

    # Boot the simulator if not already booted
    echo -e "${YELLOW}🚀 Booting simulator: $device_name${NC}"
    xcrun simctl boot "$device_name" 2>/dev/null || true
    sleep 2

    # Set appearance mode
    if [ "$appearance" == "dark" ]; then
        echo -e "${YELLOW}🌙 Setting dark mode${NC}"
        xcrun simctl ui "$device_name" appearance dark
    else
        echo -e "${YELLOW}☀️  Setting light mode${NC}"
        xcrun simctl ui "$device_name" appearance light
    fi
    sleep 1

    # Build and run tests
    echo -e "${YELLOW}🔨 Building and running screenshot tests...${NC}"

    xcodebuild \
        -project "$PROJECT_DIR/Molten.xcodeproj" \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,name=$device_name" \
        -derivedDataPath "$DERIVED_DATA_DIR" \
        -only-testing:ScreenshotAutomation/ScreenshotAutomation/testGenerateMarketingScreenshots \
        test \
        | grep -E "📸|Test Case|Test Suite" || true

    echo ""
    echo -e "${GREEN}✅ Screenshots generated for $device_name ($appearance mode)${NC}"
    echo ""
}

# Function to extract screenshots from test results
extract_screenshots() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}📦 Extracting screenshots from test results...${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Find the test results
    local attachments_dir=$(find "$DERIVED_DATA_DIR" -type d -name "Attachments" | head -1)

    if [ -z "$attachments_dir" ]; then
        echo -e "${RED}❌ Could not find screenshot attachments${NC}"
        return 1
    fi

    echo -e "${GREEN}Found attachments at: $attachments_dir${NC}"

    # Copy screenshots to output directory
    local screenshot_count=0
    while IFS= read -r -d '' screenshot; do
        local filename=$(basename "$screenshot")
        cp "$screenshot" "$OUTPUT_DIR/"
        screenshot_count=$((screenshot_count + 1))
    done < <(find "$attachments_dir" -type f -name "*.png" -print0)

    echo -e "${GREEN}✅ Extracted $screenshot_count screenshots to $OUTPUT_DIR${NC}"
    echo ""
}

# Function to optimize screenshots for web
optimize_screenshots() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}🎨 Optimizing screenshots for web...${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Check if ImageMagick is installed
    if command -v convert &> /dev/null; then
        local optimized_count=0
        for screenshot in "$OUTPUT_DIR"/*.png; do
            if [ -f "$screenshot" ]; then
                # Resize to max width 1200px and optimize
                convert "$screenshot" -resize '1200>' -quality 85 "$screenshot"
                optimized_count=$((optimized_count + 1))
            fi
        done
        echo -e "${GREEN}✅ Optimized $optimized_count screenshots${NC}"
    else
        echo -e "${YELLOW}⚠️  ImageMagick not installed - skipping optimization${NC}"
        echo -e "${YELLOW}   Install with: brew install imagemagick${NC}"
    fi
    echo ""
}

# Main execution
main() {
    echo -e "${YELLOW}Starting screenshot generation...${NC}"
    echo ""

    # Clean derived data
    if [ -d "$DERIVED_DATA_DIR" ]; then
        echo -e "${YELLOW}🧹 Cleaning previous build artifacts...${NC}"
        rm -rf "$DERIVED_DATA_DIR"
    fi

    # Generate screenshots for primary device (iPhone 15 Pro)
    run_screenshots_for_device "iPhone 15 Pro" "light"

    # Extract screenshots
    extract_screenshots

    # Optimize for web
    optimize_screenshots

    # Summary
    echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                                                   ║${NC}"
    echo -e "${BLUE}║              ✅ GENERATION COMPLETE ✅             ║${NC}"
    echo -e "${BLUE}║                                                   ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}Screenshots saved to: $OUTPUT_DIR${NC}"
    echo -e "${GREEN}Total screenshots: $(find "$OUTPUT_DIR" -name "*.png" | wc -l | tr -d ' ')${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo -e "  1. Review screenshots in: $OUTPUT_DIR"
    echo -e "  2. Select best shots for website and App Store"
    echo -e "  3. Add to your website at https://moltenglass.app"
    echo ""
}

# Run main function
main

# Clean up
echo -e "${YELLOW}🧹 Cleaning up...${NC}"
rm -rf "$DERIVED_DATA_DIR"

echo -e "${GREEN}✨ Done!${NC}"

#!/bin/bash

# Molten Screenshot Generation & WordPress Publishing
# Complete workflow: Run tests → Extract screenshots → Publish to WordPress

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SIMULATOR_NAME="iPhone 17 Pro Max"

echo "🎬 MOLTEN SCREENSHOT & PUBLISHING WORKFLOW"
echo "=========================================="
echo ""

# Step 0: Check simulator status and boot if needed
echo "📱 STEP 0/3: Checking Simulator"
echo "----------------------------------------"
SIMULATOR_UUID=$(xcrun simctl list devices | grep "$SIMULATOR_NAME" | grep -v "unavailable" | head -1 | grep -o "[0-9A-F-]\{36\}")

if [ -z "$SIMULATOR_UUID" ]; then
    echo "❌ Could not find $SIMULATOR_NAME simulator"
    exit 1
fi

echo "Found simulator: $SIMULATOR_NAME ($SIMULATOR_UUID)"

SIMULATOR_STATE=$(xcrun simctl list devices | grep "$SIMULATOR_UUID" | grep -o "Booted\|Shutdown")
if [ "$SIMULATOR_STATE" != "Booted" ]; then
    echo "Booting simulator..."
    xcrun simctl boot "$SIMULATOR_UUID"
    echo "Waiting for simulator to be ready..."
    sleep 5
else
    echo "Simulator already booted"
fi

# Step 1: Run Screenshot Tests
echo ""
echo "📸 STEP 1/3: Running Screenshot Tests"
echo "----------------------------------------"
cd "$PROJECT_DIR"

xcodebuild test \
  -project Molten.xcodeproj \
  -scheme Molten \
  -testPlan Screenshots \
  -destination "platform=iOS Simulator,name=$SIMULATOR_NAME"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Screenshot tests completed!"
else
    echo ""
    echo "❌ Screenshot tests failed!"
    exit 1
fi

# Step 2: Extract Screenshots
echo ""
echo "📸 STEP 2/3: Extracting Screenshots"
echo "----------------------------------------"
cd "$SCRIPT_DIR"
./extract_screenshots.py

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Screenshot extraction completed!"
else
    echo ""
    echo "❌ Screenshot extraction failed!"
    exit 1
fi

# Step 3: Publish to WordPress
echo ""
echo "🌐 STEP 3/3: Publishing to WordPress"
echo "----------------------------------------"
cd "$SCRIPT_DIR"
./publish_to_wordpress.py

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ COMPLETE WORKFLOW FINISHED!"
    echo "=========================================="
    echo ""
    echo "Your screenshots and pages are now published to:"
    echo "  https://moltenglass.app"
    echo ""
    echo "⏰ Note: WordPress.com cache may take 5-10 minutes to update"
else
    echo ""
    echo "❌ WordPress publishing failed!"
    exit 1
fi

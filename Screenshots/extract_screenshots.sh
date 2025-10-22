#!/bin/bash

# Extract screenshots from the latest xcresult bundle
# Saves them to the Screenshots directory for WordPress publishing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR"

echo "📸 Screenshot Extraction Tool"
echo "================================"
echo ""

# Find the most recent xcresult bundle
XCRESULT=$(find ~/Library/Developer/Xcode/DerivedData/Molten-*/Logs/Test -name "*.xcresult" -type d -mtime -1 2>/dev/null | head -1)

if [ -z "$XCRESULT" ]; then
    echo "❌ No recent test results found!"
    echo "   Run the screenshot tests first:"
    echo "   xcodebuild test -project Molten.xcodeproj -scheme Molten \\"
    echo "     -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \\"
    echo "     -only-testing:ScreenshotAutomation/ScreenshotAutomation/testGenerateMarketingScreenshots"
    exit 1
fi

echo "Found test results:"
echo "  $XCRESULT"
echo ""

# List all attachments in the xcresult
echo "Extracting screenshots..."
xcrun xcresulttool attachments list --path "$XCRESULT" 2>&1 | while read -r line; do
    # Look for PNG files with our naming pattern
    if [[ $line == *".png"* ]] && [[ $line =~ ([0-9]{2}-[a-z0-9-]+\.png) ]]; then
        FILENAME="${BASH_REMATCH[1]}"

        # Find the attachment ID for this file
        ATTACHMENT_ID=$(xcrun xcresulttool get --legacy --format json --path "$XCRESULT" 2>/dev/null | \
            python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    def find_id(obj, name):
        if isinstance(obj, dict):
            if obj.get('name', {}).get('_value') == '$FILENAME':
                return obj.get('payloadRef', {}).get('id', {}).get('_value')
            for v in obj.values():
                result = find_id(v, name)
                if result: return result
        elif isinstance(obj, list):
            for item in obj:
                result = find_id(item, name)
                if result: return result
    print(find_id(data, '$FILENAME') or '')
except: pass
" || echo "")

        if [ -n "$ATTACHMENT_ID" ]; then
            OUTPUT_PATH="$OUTPUT_DIR/$FILENAME"
            echo "  📤 $FILENAME"

            xcrun xcresulttool export --legacy --type file \
                --path "$XCRESULT" \
                --id "$ATTACHMENT_ID" \
                --output-path "$OUTPUT_PATH" 2>/dev/null

            if [ -f "$OUTPUT_PATH" ]; then
                echo "     ✅ Saved"
            else
                echo "     ❌ Failed to save"
            fi
        fi
    fi
done

# Count how many screenshots we extracted
SCREENSHOT_COUNT=$(ls -1 "$OUTPUT_DIR"/*.png 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo "✅ Extraction complete!"
echo "   $SCREENSHOT_COUNT screenshots in $OUTPUT_DIR"
echo ""
echo "Next step: Run ./publish_to_wordpress.py to upload to WordPress"

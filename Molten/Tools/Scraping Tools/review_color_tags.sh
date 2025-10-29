#!/bin/bash
#
# Color Tag Review Workflow Script
#
# This script automates the complete color tagging workflow:
# 1. Generate tag suggestions from product database
# 2. Launch web interface for human review
# 3. Merge approved tags back to database
# 4. Optionally deploy to app
#
# Usage:
#   ./review_color_tags.sh              # Show help
#   ./review_color_tags.sh --all        # Full workflow
#   ./review_color_tags.sh --analyze    # Just run analyzer
#   ./review_color_tags.sh --review     # Just open review UI
#   ./review_color_tags.sh --merge      # Just merge approved tags
#

set -e  # Exit on error

# Get the real directory where this script lives (resolves symlinks)
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"

# Always work from script directory
cd "$SCRIPT_DIR"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Port for web server
PORT=8080

# Trap to ensure we kill the web server on exit
WEB_SERVER_PID=""
cleanup() {
    if [ -n "$WEB_SERVER_PID" ]; then
        echo -e "\n${YELLOW}Stopping web server...${NC}"
        kill $WEB_SERVER_PID 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

#
# Step 1: Analyze products and generate suggestions
#
analyze() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Step 1: Analyzing Products & Generating Tag Suggestions      ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Build analyzer command
    ANALYZER_CMD="python3 color_tag_analyzer.py"

    # Add limit flag if specified
    if [ -n "$LIMIT_FLAG" ]; then
        ANALYZER_CMD="$ANALYZER_CMD --limit $LIMIT_FLAG"
    fi

    # Add unapproved flag if specified
    if [ -n "$UNAPPROVED_FLAG" ]; then
        ANALYZER_CMD="$ANALYZER_CMD --unapproved"
    fi

    # Check if suggestions file exists
    if [ -f "color_tag_suggestions.json" ]; then
        # If limit or unapproved is specified, skip the prompt
        if [ -n "$LIMIT_FLAG" ] || [ -n "$UNAPPROVED_FLAG" ]; then
            if [ -n "$UNAPPROVED_FLAG" ]; then
                echo -e "${YELLOW}Running analyzer in UNAPPROVED mode (re-analyzing unapproved products)...${NC}"
            else
                echo -e "${YELLOW}Running analyzer in TEST mode (limit=$LIMIT_FLAG)...${NC}"
            fi
            $ANALYZER_CMD
        else
            echo "Found existing suggestions file."
            read -p "Re-analyze all products? (y/n, default=n - only new/changed): " REANALYZE
            if [ "$REANALYZE" = "y" ] || [ "$REANALYZE" = "Y" ]; then
                echo -e "${YELLOW}Running analyzer in FORCE mode...${NC}"
                python3 color_tag_analyzer.py --force
            else
                echo -e "${YELLOW}Running analyzer for new/changed products only...${NC}"
                python3 color_tag_analyzer.py
            fi
        fi
    else
        echo -e "${YELLOW}Running analyzer for first time...${NC}"
        $ANALYZER_CMD
    fi

    echo ""
    echo -e "${GREEN}✓ Analysis complete!${NC}"
    echo ""
}

#
# Step 2: Launch web interface for review
#
review() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Step 2: Web Review Interface                                  ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Check if suggestions exist
    if [ ! -f "color_tag_suggestions.json" ]; then
        echo -e "${RED}Error: color_tag_suggestions.json not found!${NC}"
        echo "Run with --analyze first to generate suggestions."
        exit 1
    fi

    # Count products
    PRODUCT_COUNT=$(python3 -c "import json; print(len(json.load(open('color_tag_suggestions.json'))['products']))")
    echo "Found $PRODUCT_COUNT products to review"
    echo ""

    # Create symlink to images if it doesn't exist
    if [ ! -L "product-images" ]; then
        echo "Creating symlink to product images..."
        ln -s "../../Sources/Resources/product-images" ./product-images
    fi

    # Start web server (from script directory with symlink to images)
    echo -e "${YELLOW}Starting web server on port $PORT...${NC}"
    python3 -m http.server $PORT > /dev/null 2>&1 &
    WEB_SERVER_PID=$!

    # Wait a moment for server to start
    sleep 1

    # Open browser
    echo -e "${GREEN}Opening web interface in browser...${NC}"
    echo ""
    open "http://localhost:$PORT/color_tag_review.html"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}Web interface is now running!${NC}"
    echo ""
    echo "Instructions:"
    echo "  1. Review each product and check/uncheck color tags"
    echo "  2. Add custom tags if needed"
    echo "  3. Click 'Approve Tags' for each product when ready"
    echo "  4. Click 'Save All Approvals' when done reviewing"
    echo "  5. The file will download - save it to this directory"
    echo "  6. Come back here and press ENTER to continue"
    echo ""
    echo "URL: http://localhost:$PORT/color_tag_review.html"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    read -p "Press ENTER when you've saved your approvals and are ready to merge..."

    # Stop web server
    echo ""
    echo -e "${YELLOW}Stopping web server...${NC}"
    kill $WEB_SERVER_PID 2>/dev/null || true
    WEB_SERVER_PID=""

    echo ""
}

#
# Step 3: Merge approved tags to database
#
merge() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Step 3: Merge Approved Tags to Database                      ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Check if approvals exist
    if [ ! -f "color_tag_approvals.json" ]; then
        echo -e "${RED}Error: color_tag_approvals.json not found!${NC}"
        echo "Make sure you saved your approvals from the web interface."
        exit 1
    fi

    # Preview changes
    echo -e "${YELLOW}Previewing changes (dry run)...${NC}"
    echo ""
    python3 merge_approved_tags.py --dry-run
    echo ""

    read -p "Apply these changes? (y/n): " APPLY
    if [ "$APPLY" != "y" ] && [ "$APPLY" != "Y" ]; then
        echo "Merge cancelled."
        exit 0
    fi

    echo ""
    read -p "Automatically commit to git? (y/n): " COMMIT
    if [ "$COMMIT" = "y" ] || [ "$COMMIT" = "Y" ]; then
        echo ""
        echo -e "${YELLOW}Merging and committing...${NC}"
        python3 merge_approved_tags.py --commit
    else
        echo ""
        echo -e "${YELLOW}Merging without commit...${NC}"
        python3 merge_approved_tags.py
    fi

    echo ""
    echo -e "${GREEN}✓ Tags merged to database!${NC}"
    echo ""
}

#
# Step 4: Deploy to app (optional)
#
deploy() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Step 4: Deploy to App (Optional)                             ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    APP_RESOURCES="$SCRIPT_DIR/../../Sources/Resources"

    if [ ! -d "$APP_RESOURCES" ]; then
        echo -e "${RED}Error: App Resources directory not found at:${NC}"
        echo "$APP_RESOURCES"
        return
    fi

    read -p "Copy updated catalog to app? (y/n): " DEPLOY
    if [ "$DEPLOY" != "y" ] && [ "$DEPLOY" != "Y" ]; then
        echo "Skipping deployment."
        return
    fi

    echo ""
    echo -e "${YELLOW}Copying glass_database_export.json to app...${NC}"
    cp glass_database_export.json "$APP_RESOURCES/glass_catalog.json"

    echo -e "${GREEN}✓ Catalog copied to app!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Rebuild the app in Xcode"
    echo "  2. Test the new color tags in the app"
    echo ""
}

#
# Show help text
#
show_help() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                                ║${NC}"
    echo -e "${GREEN}║           Color Tag Review Workflow                           ║${NC}"
    echo -e "${GREEN}║                                                                ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Automates the complete color tagging workflow for glass products."
    echo ""
    echo "Usage:"
    echo "  $0 [OPTION] [--limit N]"
    echo ""
    echo "Options:"
    echo "  --all          Run complete workflow (analyze → review → merge → deploy)"
    echo "  --analyze      Just run analyzer (generate tag suggestions)"
    echo "  --review       Just open review UI (web interface)"
    echo "  --merge        Just merge approved tags (apply to database)"
    echo "  --limit N      Limit analysis to N products (test mode)"
    echo "  --unapproved   Re-analyze only unapproved products (after bug fixes)"
    echo "  --help, -h     Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 --all                     # Complete workflow"
    echo "  $0 --analyze                 # Only generate suggestions"
    echo "  $0 --analyze --limit 10      # Test with 10 products"
    echo "  $0 --analyze --unapproved    # Re-analyze unapproved products"
    echo "  $0 --review                  # Only open review interface"
    echo ""
    echo "Notes:"
    echo "  - When --limit or --unapproved is specified, skips the 're-analyze all?' prompt"
    echo "  - Use --unapproved after fixing bugs to re-run only unreviewed products"
    echo "  - This script can be run from anywhere (via symlink or direct path)"
    echo ""
    echo "Working directory: $SCRIPT_DIR"
    echo ""
}

#
# Main workflow
#
main() {
    # Parse command line arguments
    LIMIT_FLAG=""
    UNAPPROVED_FLAG=""
    ACTION=""

    # Parse all arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --limit)
                if [ -z "$2" ] || [[ "$2" == --* ]]; then
                    echo -e "${RED}Error: --limit requires a number${NC}"
                    exit 1
                fi
                LIMIT_FLAG="$2"
                shift 2
                ;;
            --unapproved)
                UNAPPROVED_FLAG="1"
                shift
                ;;
            --all|--analyze|--review|--merge|--help|-h)
                ACTION="$1"
                shift
                ;;
            "")
                # Empty argument, show help
                ACTION="--help"
                shift
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                echo ""
                echo "Run with --help for usage information"
                exit 1
                ;;
        esac
    done

    # Default to help if no action specified
    if [ -z "$ACTION" ]; then
        ACTION="--help"
    fi

    # Execute the action
    case "$ACTION" in
        --all)
            echo ""
            echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${GREEN}║                                                                ║${NC}"
            echo -e "${GREEN}║           Color Tag Review Workflow                           ║${NC}"
            echo -e "${GREEN}║                                                                ║${NC}"
            echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
            echo ""

            # Full workflow
            analyze
            review
            merge
            deploy

            echo ""
            echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${GREEN}║                                                                ║${NC}"
            echo -e "${GREEN}║                    All Done! 🎉                                ║${NC}"
            echo -e "${GREEN}║                                                                ║${NC}"
            echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
            echo ""
            ;;
        --analyze)
            analyze
            ;;
        --review)
            review
            ;;
        --merge)
            merge
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
    esac
}

# Run main
main "$@"

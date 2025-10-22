# Molten WordPress Publishing System

This directory contains the screenshot automation and WordPress publishing system for the Molten app website.

## Directory Structure

```
Screenshots/
├── Content/                    # WordPress page content (editable)
│   ├── pages/                 # Individual page markdown files
│   │   ├── home.md
│   │   ├── features.md
│   │   ├── screenshots.md
│   │   ├── getting-started.md
│   │   ├── catalog.md
│   │   ├── inventory.md
│   │   ├── shopping.md
│   │   └── purchases.md
│   └── config.json            # Site structure configuration
├── *.png                      # Generated screenshots
├── publish_to_wordpress.py    # WordPress publishing script
└── .wp-credentials            # WordPress password (gitignored)
```

## Workflow

### Quick Start: Complete Automation

The workflow has two steps because xcodebuild has issues with test target isolation:

**Step 1: Run Screenshot Tests in Xcode**
```bash
cd Screenshots
./generate_and_publish.sh
```

This will show instructions for running the tests in Xcode:
1. Open Molten.xcodeproj in Xcode
2. Press ⌘6 to open Test Navigator
3. Find: ScreenshotAutomation → ScreenshotAutomation → testGenerateMarketingScreenshots
4. Click the ▶ button to run the test
5. Wait for completion (2-3 minutes)

**Step 2: Extract and Publish**
```bash
./generate_and_publish.sh go
```

This will automatically:
1. Extract screenshots from test results
2. Publish everything to WordPress

**That's it!** The workflow requires one manual step in Xcode, then automates the rest.

---

### Manual Workflow (Advanced)

If you need more control over individual steps:

#### 1. Generate Screenshots

Run the screenshot automation tests:
```bash
cd "/Users/binde/Library/Mobile Documents/com~apple~CloudDocs/Molten"
xcodebuild test \
  -project Molten.xcodeproj \
  -scheme Molten \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:ScreenshotAutomation/ScreenshotAutomation/testGenerateMarketingScreenshots
```

Note: The automated script (`generate_and_publish.sh`) will check simulator status and boot it if needed.

#### 2. Extract Screenshots

Extract screenshots from the test results:
```bash
cd Screenshots
./extract_screenshots.py
```

Screenshots will be saved to the Screenshots directory.

#### 3. Edit Page Content (Optional)

Update any page content by editing the markdown files in `Content/pages/`:
- `home.md` - Home page content
- `features.md` - Features overview
- `screenshots.md` - Screenshots gallery page
- `getting-started.md` - Getting started guide
- `catalog.md` - Catalog feature detail
- `inventory.md` - Inventory feature detail
- `shopping.md` - Shopping lists feature detail
- `purchases.md` - Purchase tracking feature detail

**These files persist across screenshot runs** - edit them to update your website content.

#### 4. Publish to WordPress

```bash
cd Screenshots
./publish_to_wordpress.py
```

The publishing script will:
1. Upload all PNG screenshots to WordPress media library
2. Create/update pages from markdown content
3. Insert screenshots in appropriate locations
4. Set up page hierarchy
5. Configure menu structure

## Configuration

### WordPress Credentials

Create `.wp-credentials` file with your WordPress password:
```bash
echo "your-wordpress-password" > .wp-credentials
```

Or set environment variable:
```bash
export WP_PASSWORD="your-wordpress-password"
```

### Site Structure

Edit `Content/config.json` to:
- Add/remove pages
- Change page hierarchy
- Modify menu structure
- Map screenshots to pages

### Screenshot Mapping

In `config.json`, the `screenshot_mapping` section controls which screenshots appear on each page:

```json
"screenshot_mapping": {
  "home": ["01-catalog-browse", "09b-catalog-overview"],
  "screenshots": ["*"],  // All screenshots
  "catalog": ["01-catalog-browse", "02-glass-detail", ...],
}
```

In your markdown files, use:
```markdown
**SCREENSHOTS: catalog-browse, search-results**
```

And the script will insert the actual screenshot images.

## Updating Content

### When You Add a New Feature

1. **Update the relevant page markdown**:
   ```bash
   # Edit the appropriate file in Content/pages/
   nano Content/pages/inventory.md
   ```

2. **Re-run the complete workflow**:
   ```bash
   cd Screenshots
   ./generate_and_publish.sh
   ```

That's it! The script will regenerate screenshots and publish everything.

**Or, if you only updated content (no new screenshots needed)**:
   ```bash
   cd Screenshots
   ./publish_to_wordpress.py
   ```

### Adding a New Page

1. **Create page content**:
   ```bash
   # Create new markdown file
   nano Content/pages/new-feature.md
   ```

2. **Add to config.json**:
   ```json
   {
     "slug": "new-feature",
     "title": "New Feature",
     "template": "pages/new-feature.md",
     "menu_order": 5,
     "in_menu": true
   }
   ```

3. **Publish**:
   ```bash
   ./publish_to_wordpress.py
   ```

## Benefits of This System

✅ **Content Persists** - Page content doesn't get regenerated each time
✅ **Easy Updates** - Edit markdown files, not WordPress admin
✅ **Version Controlled** - All content is in git
✅ **Automated** - One command publishes everything
✅ **Screenshot Integration** - Screenshots automatically inserted
✅ **Menu Management** - Menu structure defined in config

## Troubleshooting

### "Permission Denied" when running script
```bash
chmod +x publish_to_wordpress.py
```

### "WordPress password not found"
Create `.wp-credentials` file or set `WP_PASSWORD` environment variable

### Screenshots not appearing
Check `screenshot_mapping` in `config.json` matches actual screenshot filenames

### Page not found on website
Check `config.json` has correct slug and the script ran successfully

## Advanced

### Custom CSS

Add custom CSS for screenshot galleries in your WordPress theme:

```css
.molten-screenshot-gallery {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 2rem;
  margin: 2rem 0;
}

.molten-screenshot {
  width: 100%;
  height: auto;
  border-radius: 8px;
  box-shadow: 0 4px 6px rgba(0,0,0,0.1);
}
```

### Menu Customization

Edit `config.json` menu section to control WordPress menu structure.

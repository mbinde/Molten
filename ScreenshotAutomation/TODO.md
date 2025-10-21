# Screenshot Automation & Website Publishing - TODO

## 🎯 Current Tasks

### Screenshot Generation - READY TO TEST! ✨
- [ ] Add ScreenshotAutomation files to Xcode project
  - [ ] `ScreenshotAutomation.swift` (verify it's in target)
  - [ ] `README.md` (optional, for reference)
  - [ ] `generate_screenshots.sh` (optional, for reference)
- [x] **Demo Data System** - COMPLETE! ✅
  - [x] Created demo-data.json with 489 items (EF + DH + GA)
  - [x] Updated JSONDataLoader to support -DemoDataMode
  - [x] Updated ScreenshotAutomation to use demo mode
  - [x] Documented in DEMO_DATA.md
  - **NOTE**: Demo data loads automatically when running screenshot tests!
- [ ] Run screenshot tests in Xcode to verify they work
  - [ ] Test with `testGenerateMarketingScreenshots()` (8 screenshots)
  - [ ] Test with `testGenerateAppStoreScreenshots()` (5 screenshots)
  - [ ] Optionally test `testGenerateDarkModeScreenshots()` (4 screenshots)
  - [ ] Verify all screenshots are captured
  - [ ] Check screenshot quality and content
- [ ] Generate initial screenshot set
  - [ ] Run `./generate_screenshots.sh` OR use Xcode directly
  - [ ] Review generated screenshots in `../Screenshots/` folder
  - [ ] Select best shots for website

### ✅ COMPLETED - Screenshot System Enhancements
- [x] Enhanced screenshot automation with better composition
- [x] Added robust navigation helpers
- [x] Added onboarding skip logic
- [x] Better timing and waits for content to load
- [x] Improved error handling (graceful failures)
- [x] Better console output for debugging
- [x] Smart cell selection (picks 3rd cell for variety)

### WordPress Publication Pipeline
- [ ] **INVESTIGATE**: Determine best approach for WordPress automation
  - [ ] WordPress REST API (programmatic upload)
  - [ ] FTP/SFTP automation (direct file upload)
  - [ ] WordPress CLI (command-line management)
  - [ ] GitHub Actions + WordPress plugin (automated deploy)
- [ ] Research WordPress hosting setup at https://moltenglass.app
  - [ ] Hosting provider (self-hosted vs managed)
  - [ ] Access credentials available (FTP, API, SSH)
  - [ ] Current theme/page builder (may affect update method)
- [ ] Decide on automation strategy
- [ ] Implement automated screenshot upload
- [ ] Create/update website pages with new screenshots

### Website Content Updates
- [ ] Update homepage with new screenshots
- [ ] Create features page with detailed screenshots
- [ ] Build help/documentation section
- [ ] Add App Store submission screenshots
- [ ] Update marketing copy to reflect current features

## 💡 Ideas for WordPress Automation

### Option 1: WordPress REST API
**Pros:**
- Direct API access to WordPress
- Can upload media and update pages programmatically
- No manual FTP needed

**Cons:**
- Requires API authentication setup
- Need to enable WordPress REST API

**Implementation:**
```bash
# Upload image via REST API
curl -X POST https://moltenglass.app/wp-json/wp/v2/media \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "file=@screenshot.png"

# Update page content
curl -X POST https://moltenglass.app/wp-json/wp/v2/pages/PAGE_ID \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d "content=<img src='...'/>"
```

### Option 2: FTP/SFTP Upload
**Pros:**
- Simple and direct
- Works with any WordPress hosting
- Can automate with shell script

**Cons:**
- Still need to update page content manually (unless using file-based includes)
- Less integrated

**Implementation:**
```bash
# SFTP upload
lftp -u username,password sftp://moltenglass.app << EOF
cd public_html/wp-content/uploads/screenshots
mput Screenshots/*.png
bye
EOF
```

### Option 3: WordPress CLI (WP-CLI)
**Pros:**
- Command-line WordPress management
- Very powerful for bulk operations
- Can create/update posts and pages

**Cons:**
- Requires SSH access to server
- May need hosting provider support

**Implementation:**
```bash
# Upload media
wp media import screenshot.png --title="Catalog View"

# Update page
wp post update 123 --post_content="<img src='...'/>"
```

### Option 4: Git + WordPress Plugin
**Pros:**
- Version control for website content
- Automated deployment via GitHub Actions
- Modern workflow

**Cons:**
- Requires WordPress plugin setup (e.g., WP Pusher, Git Updater)
- More complex initial setup

**Implementation:**
- Push screenshots to GitHub repo
- WordPress plugin auto-syncs changes
- Pages update automatically

## 📋 Questions to Answer

1. **What WordPress hosting provider are you using?**
   - WordPress.com, Bluehost, SiteGround, self-hosted, other?

2. **Do you have access to:**
   - [ ] WordPress admin panel
   - [ ] FTP/SFTP credentials
   - [ ] SSH/terminal access to server
   - [ ] WordPress REST API (can enable if needed)

3. **What page builder/editor are you using?**
   - [ ] Classic WordPress editor
   - [ ] Gutenberg (block editor)
   - [ ] Elementor, Divi, or other page builder
   - [ ] Custom HTML/theme

4. **How frequently will you update screenshots?**
   - [ ] Often (weekly/monthly) → Automation critical
   - [ ] Occasionally (quarterly/yearly) → Manual might be OK
   - [ ] Major releases only → Semi-automated

5. **Do you want fully automated deployment or just simplified upload?**
   - [ ] Fully automated (run script, site updates automatically)
   - [ ] Semi-automated (script uploads, you arrange on page)
   - [ ] Just simplify upload (no manual download/upload)

## 🎯 Recommended Approach (TBD)

_To be determined based on answers to questions above._

## ✅ Completed Tasks

- [x] Create ScreenshotAutomation test target
- [x] Write screenshot generation test suite
- [x] Create automation shell script
- [x] Write comprehensive README documentation
- [x] Set up Screenshots output directory with gitignore
- [x] Create TODO tracking file (this file!)

---

**Last Updated**: October 21, 2025
**Status**: Planning Phase - Need WordPress hosting details

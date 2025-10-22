#!/usr/bin/env python3
"""
WordPress Publisher for Molten App
Publishes screenshots and page content to WordPress site
"""

import os
import json
import sys
import re
from pathlib import Path
import requests
from requests.auth import HTTPBasicAuth
import mimetypes
from datetime import datetime

# WordPress configuration
WP_URL = "https://moltenglass.app"
WP_API_URL = f"{WP_URL}/wp-json/wp/v2"
WP_USERNAME = "mbinde@gmail.com"

# Get password from environment or credentials file
def get_wp_password():
    # Try environment variable first
    password = os.environ.get('WP_PASSWORD')
    if password:
        return password

    # Try credentials file
    creds_file = Path(__file__).parent / '.wp-credentials'
    if creds_file.exists():
        with open(creds_file) as f:
            return f.read().strip()

    print("ERROR: WordPress password not found!")
    print("Set WP_PASSWORD environment variable or create .wp-credentials file")
    sys.exit(1)

WP_PASSWORD = get_wp_password()
WP_AUTH = HTTPBasicAuth(WP_USERNAME, WP_PASSWORD)

# Directories
SCRIPT_DIR = Path(__file__).parent
SCREENSHOTS_DIR = SCRIPT_DIR
CONTENT_DIR = SCRIPT_DIR / "Content"
PAGES_DIR = CONTENT_DIR / "pages"
CONFIG_FILE = CONTENT_DIR / "config.json"


class WordPressPublisher:
    def __init__(self):
        self.config = self.load_config()
        self.uploaded_media = {}  # Cache of uploaded media IDs
        self.page_ids = {}  # Cache of page IDs

    def load_config(self):
        """Load configuration from config.json"""
        with open(CONFIG_FILE) as f:
            return json.load(f)

    def upload_screenshot(self, screenshot_path):
        """Upload a screenshot to WordPress media library"""
        screenshot_name = screenshot_path.name

        # Check if already uploaded in this session
        if screenshot_name in self.uploaded_media:
            print(f"  ✓ Already cached: {screenshot_name}")
            return self.uploaded_media[screenshot_name]

        # Check if already exists in WordPress
        print(f"  🔍 Checking: {screenshot_name}")
        search_response = requests.get(
            f"{WP_API_URL}/media",
            auth=WP_AUTH,
            params={'search': screenshot_name, 'per_page': 100}
        )

        if search_response.status_code == 200:
            existing_media = search_response.json()
            # Look for exact filename match
            for media in existing_media:
                if media.get('source_url', '').endswith(screenshot_name):
                    media_id = media['id']
                    print(f"    🔄 Found existing (ID {media_id}), deleting to re-upload...")

                    # Delete the old media
                    delete_response = requests.delete(
                        f"{WP_API_URL}/media/{media_id}",
                        auth=WP_AUTH,
                        params={'force': True}  # Permanently delete
                    )

                    if delete_response.status_code == 200:
                        print(f"    🗑️  Deleted old version")
                    else:
                        print(f"    ⚠️  Could not delete (will upload new anyway)")

                    # Continue to upload new version
                    break

        # Not found, upload new
        print(f"    📤 Uploading new...")

        # Prepare file upload
        mime_type = mimetypes.guess_type(screenshot_path)[0] or 'image/png'

        with open(screenshot_path, 'rb') as f:
            files = {
                'file': (screenshot_name, f, mime_type)
            }
            headers = {
                'Content-Disposition': f'attachment; filename="{screenshot_name}"'
            }

            response = requests.post(
                f"{WP_API_URL}/media",
                auth=WP_AUTH,
                files=files,
                headers=headers
            )

        if response.status_code in [200, 201]:
            media_data = response.json()
            media_id = media_data['id']
            media_url = media_data['source_url']

            # Get the portrait-small size URL if available (300x400 - matches carousel)
            display_url = media_url  # Default to full size
            if 'media_details' in media_data and 'sizes' in media_data['media_details']:
                sizes = media_data['media_details']['sizes']
                # Try portrait-small first (300x400), then fall back to medium
                if 'newspack-article-block-portrait-small' in sizes:
                    display_url = sizes['newspack-article-block-portrait-small'].get('source_url', media_url)
                elif 'medium' in sizes:
                    display_url = sizes['medium'].get('source_url', media_url)

            self.uploaded_media[screenshot_name] = {
                'id': media_id,
                'url': display_url
            }
            print(f"    ✅ Uploaded as ID {media_id}")
            return self.uploaded_media[screenshot_name]
        else:
            print(f"    ❌ Upload failed: {response.status_code}")
            print(f"       {response.text}")
            return None

    def upload_all_screenshots(self):
        """Upload all PNG screenshots from Screenshots directory"""
        print("\n📸 Uploading Screenshots...")
        print("=" * 50)

        screenshots = list(SCREENSHOTS_DIR.glob("*.png"))
        print(f"Found {len(screenshots)} screenshots")

        for screenshot in screenshots:
            self.upload_screenshot(screenshot)

        print(f"\n✅ Uploaded {len(self.uploaded_media)} screenshots")

    def convert_markdown_to_html(self, markdown_text, page_slug):
        """Convert markdown to HTML with screenshot placeholders replaced"""
        # Add title-hiding CSS to every page
        title_hiding_css = '''<style>
.entry-title,
.page-title,
h1.title,
.wp-block-post-title,
header.entry-header h1,
article h1:first-of-type,
.site-main > article > h1,
.entry-content > h1:first-child,
main h1:first-child,
h1.wp-block-post-title {
    display: none !important;
    visibility: hidden !important;
    height: 0 !important;
    overflow: hidden !important;
}
</style>

'''
        html = title_hiding_css + markdown_text

        # IMPORTANT: Process screenshot placeholders BEFORE converting bold text
        # Otherwise **SCREENSHOTS:** becomes <strong>SCREENSHOTS:</strong> and regex won't match
        def replace_screenshot_placeholder(match):
            screenshot_names = match.group(1).strip()

            if screenshot_names == '*':
                # All screenshots
                screenshot_names = list(self.uploaded_media.keys())
            else:
                # Specific screenshots
                screenshot_names = [name.strip() for name in screenshot_names.split(',')]

            # Find matching screenshots
            screenshots = []
            for name in screenshot_names:
                # First check uploaded_media cache
                matching_shots = [k for k in self.uploaded_media.keys()
                                if k.endswith(f"-{name}.png") or k == f"{name}.png"]
                for shot_key in matching_shots:
                    if shot_key in self.uploaded_media:
                        screenshots.append(self.uploaded_media[shot_key])

                # If not found in cache, search WordPress
                if not matching_shots:
                    search_name = f"{name}.png"
                    search_response = requests.get(
                        f"{WP_API_URL}/media",
                        auth=WP_AUTH,
                        params={'search': search_name, 'per_page': 50}
                    )
                    if search_response.status_code == 200:
                        existing_media = search_response.json()
                        for media in existing_media:
                            if media.get('source_url', '').endswith(search_name):
                                # Get the portrait-small size if available (300x400 - matches carousel)
                                display_url = media['source_url']
                                if 'media_details' in media and 'sizes' in media['media_details']:
                                    sizes = media['media_details']['sizes']
                                    # Try portrait-small first (300x400), then fall back to medium
                                    if 'newspack-article-block-portrait-small' in sizes:
                                        display_url = sizes['newspack-article-block-portrait-small'].get('source_url', media['source_url'])
                                    elif 'medium' in sizes:
                                        display_url = sizes['medium'].get('source_url', media['source_url'])

                                media_info = {
                                    'id': media['id'],
                                    'url': display_url
                                }
                                screenshots.append(media_info)
                                # Cache it for future use
                                self.uploaded_media[search_name] = media_info
                                break

            # If only one screenshot, show it centered (match carousel size)
            if len(screenshots) == 1:
                media = screenshots[0]
                # Add cache-busting parameter
                cache_bust = f"?v={int(datetime.now().timestamp())}"
                return f'<div style="display: flex; justify-content: center; margin: 2rem 0;"><img src="{media["url"]}{cache_bust}" alt="" style="max-width: 280px; height: auto; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.15);" /></div>\n'

            # If 2+ screenshots, create carousel HTML (JavaScript goes in footer via plugin)
            carousel_html = '''
<style>
    .molten-carousel-container {
        position: relative;
        max-width: 280px;
        margin: 2rem auto;
        overflow: visible;
    }
    .molten-carousel-wrapper {
        overflow: hidden;
        padding: 40px 0;
    }
    .molten-carousel {
        display: flex;
        transition: transform 0.5s ease;
        align-items: center;
    }
    .molten-carousel > div {
        flex: 0 0 100%;
        width: 100%;
        padding: 0 8px;
        box-sizing: border-box;
        transition: transform 0.5s ease, opacity 0.5s ease;
    }
    .molten-carousel img {
        width: 100%;
        height: auto;
        border-radius: 12px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.15);
    }
    .molten-carousel-btn {
        position: absolute;
        top: 50%;
        transform: translateY(-50%);
        background: rgba(255,255,255,0.9);
        border: none;
        border-radius: 50%;
        width: 40px;
        height: 40px;
        cursor: pointer;
        font-size: 20px;
        box-shadow: 0 2px 8px rgba(0,0,0,0.2);
        z-index: 10;
    }
    .molten-carousel-btn:hover {
        background: rgba(255,255,255,1);
    }
    @media (min-width: 768px) {
        .molten-carousel-container {
            max-width: 1100px;
        }
        .molten-carousel > div {
            flex: 0 0 20%;
            width: 20%;
        }
    }
</style>

<div class="molten-carousel-container">
    <div class="molten-carousel-wrapper">
        <div class="molten-carousel" id="moltenCarousel">
'''
            # Add cache-busting parameter for carousel images
            cache_bust = f"?v={int(datetime.now().timestamp())}"
            for media in screenshots:
                carousel_html += f'            <div><img src="{media["url"]}{cache_bust}" alt="Molten App Screenshot" /></div>\n'

            carousel_html += '''        </div>
    </div>
    <button class="molten-carousel-btn" id="moltenCarouselPrev" style="left: 10px;">‹</button>
    <button class="molten-carousel-btn" id="moltenCarouselNext" style="right: 10px;">›</button>
    <div style="text-align: center; margin-top: 1rem;">
'''
            for i in range(len(screenshots)):
                active_color = '#333' if i == 0 else '#ccc'
                carousel_html += f'        <span class="molten-dot" data-slide="{i}" style="display: inline-block; width: 10px; height: 10px; margin: 0 5px; background: {active_color}; border-radius: 50%; cursor: pointer;"></span>\n'

            carousel_html += '''    </div>
</div>
'''
            return carousel_html

        html = re.sub(r'\*\*SCREENSHOTS:\s*(.+?)\*\*', replace_screenshot_placeholder, html)

        # Convert horizontal rules
        html = re.sub(r'^---+$', r'<hr style="border: none; border-top: 2px solid #e0e0e0; margin: 3rem 0;" />', html, flags=re.MULTILINE)

        # Convert headers
        html = re.sub(r'^# (.+)$', r'<h1>\1</h1>', html, flags=re.MULTILINE)
        html = re.sub(r'^## (.+)$', r'<h2>\1</h2>', html, flags=re.MULTILINE)
        html = re.sub(r'^### (.+)$', r'<h3>\1</h3>', html, flags=re.MULTILINE)
        html = re.sub(r'^#### (.+)$', r'<h4>\1</h4>', html, flags=re.MULTILINE)

        # Convert bold and italic
        html = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', html)
        html = re.sub(r'\*(.+?)\*', r'<em>\1</em>', html)

        # Convert lists
        html = re.sub(r'^\- (.+)$', r'<li>\1</li>', html, flags=re.MULTILINE)
        html = re.sub(r'(<li>.*</li>\n)+', r'<ul>\n\g<0></ul>\n', html)

        # Convert links
        html = re.sub(r'\[(.+?)\]\((.+?)\)', r'<a href="\2">\1</a>', html)

        # Convert paragraphs
        lines = html.split('\n')
        in_list = False
        result = []
        current_p = []

        for line in lines:
            line = line.strip()
            if line.startswith('<h') or line.startswith('<ul') or line.startswith('</ul') or line.startswith('<div') or line.startswith('<hr'):
                if current_p:
                    result.append('<p>' + ' '.join(current_p) + '</p>')
                    current_p = []
                result.append(line)
            elif line:
                current_p.append(line)
            else:
                if current_p:
                    result.append('<p>' + ' '.join(current_p) + '</p>')
                    current_p = []

        if current_p:
            result.append('<p>' + ' '.join(current_p) + '</p>')

        html = '\n'.join(result)

        return html

    def get_or_create_page(self, page_config):
        """Get existing page or create new one"""
        slug = page_config['slug']
        title = page_config['title']

        # Check if page exists
        response = requests.get(
            f"{WP_API_URL}/pages",
            auth=WP_AUTH,
            params={'slug': slug}
        )

        if response.status_code == 200 and response.json():
            page_id = response.json()[0]['id']
            print(f"  ✓ Found existing page: {title} (ID: {page_id})")
            return page_id

        # Create new page
        print(f"  📄 Creating new page: {title}")

        page_data = {
            'title': title,
            'slug': slug,
            'status': 'publish',
            'content': ''  # Will be updated later
        }

        response = requests.post(
            f"{WP_API_URL}/pages",
            auth=WP_AUTH,
            json=page_data
        )

        if response.status_code in [200, 201]:
            page_id = response.json()['id']
            print(f"    ✅ Created page ID: {page_id}")
            return page_id
        else:
            print(f"    ❌ Failed to create page: {response.status_code}")
            print(f"       {response.text}")
            return None

    def update_page_content(self, page_id, page_config):
        """Update page content from markdown file"""
        template_path = PAGES_DIR / page_config['template']

        if not template_path.exists():
            print(f"    ⚠️  Template not found: {template_path}")
            return False

        with open(template_path) as f:
            markdown_content = f.read()

        html_content = self.convert_markdown_to_html(markdown_content, page_config['slug'])

        # Add cache-busting timestamp (invisible div that changes content hash)
        timestamp = datetime.now().isoformat()
        cache_buster = f'\n<!-- Updated: {timestamp} -->\n<div style="display:none" data-updated="{timestamp}"></div>'
        html_content += cache_buster

        page_data = {
            'content': html_content,
            'status': 'publish'  # Ensure page is published
        }

        # Set parent if specified
        if 'parent' in page_config:
            parent_slug = page_config['parent']
            if parent_slug in self.page_ids:
                page_data['parent'] = self.page_ids[parent_slug]

        # Set menu order
        if 'menu_order' in page_config:
            page_data['menu_order'] = page_config['menu_order']

        print(f"    📝 Updating {page_config['title']} (content length: {len(html_content)} chars)")

        response = requests.post(
            f"{WP_API_URL}/pages/{page_id}",
            auth=WP_AUTH,
            json=page_data
        )

        if response.status_code == 200:
            print(f"    ✅ Updated content for: {page_config['title']}")
            return True
        else:
            print(f"    ❌ Failed to update content: {response.status_code}")
            print(f"       {response.text}")
            return False

    def publish_all_pages(self):
        """Publish all pages defined in config"""
        print("\n📄 Publishing Pages...")
        print("=" * 50)

        # First pass: create/get all pages
        for page_config in self.config['pages']:
            page_id = self.get_or_create_page(page_config)
            if page_id:
                self.page_ids[page_config['slug']] = page_id

        # Second pass: update content (needed so parent relationships work)
        for page_config in self.config['pages']:
            if page_config['slug'] in self.page_ids:
                page_id = self.page_ids[page_config['slug']]
                self.update_page_content(page_id, page_config)

        print(f"\n✅ Published {len(self.page_ids)} pages")

    def set_front_page(self):
        """Set the home page as front page"""
        print("\n🏠 Setting Front Page...")
        print("=" * 50)

        # Find home page
        home_page = next((p for p in self.config['pages'] if p.get('is_front_page')), None)
        if not home_page:
            print("  ⚠️  No front page configured")
            return

        page_id = self.page_ids.get(home_page['slug'])
        if not page_id:
            print("  ⚠️  Front page not found")
            return

        # Try to update site settings via WordPress API
        # This requires the WP REST API settings endpoint (may need plugin)
        settings_data = {
            'show_on_front': 'page',
            'page_on_front': page_id
        }

        try:
            response = requests.post(
                f"{WP_URL}/wp-json/wp/v2/settings",
                auth=WP_AUTH,
                json=settings_data
            )

            if response.status_code == 200:
                print(f"  ✅ Front page set to: {home_page['title']} (ID: {page_id})")
                return
            else:
                print(f"  ⚠️  Could not auto-set front page (status {response.status_code})")
        except Exception as e:
            print(f"  ⚠️  API endpoint not available: {str(e)}")

        # Fallback to manual instruction
        print(f"  ✓ Front page should be set to: {home_page['title']} (ID: {page_id})")
        print("  ℹ️  Manual step: Set this as front page in WordPress admin")
        print("     Settings → Reading → Homepage displays → A static page → Home")

    def publish(self):
        """Main publishing workflow"""
        print("\n" + "=" * 50)
        print("  MOLTEN WORDPRESS PUBLISHER")
        print("=" * 50)

        # 1. Upload screenshots
        self.upload_all_screenshots()

        # 2. Publish pages
        self.publish_all_pages()

        # 3. Set front page
        self.set_front_page()

        print("\n" + "=" * 50)
        print("  ✅ PUBLISHING COMPLETE!")
        print("=" * 50)
        print(f"\n  📊 Summary:")
        print(f"     - Screenshots: {len(self.uploaded_media)}")
        print(f"     - Pages: {len(self.page_ids)}")
        print(f"\n  🌐 Visit: {WP_URL}")
        print("\n")


def main():
    """Main entry point"""
    try:
        publisher = WordPressPublisher()
        publisher.publish()
    except KeyboardInterrupt:
        print("\n\n⚠️  Publishing cancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
